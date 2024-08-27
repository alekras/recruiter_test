defmodule FoodRecord do
  defstruct locationId: "0",
            zipCode: "n/a",
            applicant: "n/a",
            document: %{}
end

defmodule Main do

def start() do
	:inets.start()
	:ssl.start()

# create database ETS based on file system.
	opts = [{:file, ~c"../priv/food_db.bin"}, {:type, :duplicate_bag}, {:keypos, 2}]
	case :dets.open_file(:foodDb, opts) do
		{:ok, _} ->
			true
		{:error, reason} ->
			IO.puts("Cannot open foodDb dets: #{reason}")
			false
	end

# Get data from online URL
	response = :httpc.request(:get, 
		{~c"https://data.sfgov.org/api/views/rqzj-sfat/rows.csv", []},
		[{:ssl,
			[
				{:verify, :verify_none}
			]
		 }
		],
		[])
# Process data: split to lines, extract field names, split each line to fields
	case response do
		{:ok, {{_, 200, ~c"OK"}, _, body}} ->
			:file.write_file(~c"../priv/online.csv", body)

			[firstLine | restLines] = file2lines(~c"../priv/online.csv")

			fieldNames = :string.split(firstLine, ~c",", :all)
			for s <- restLines do
				processRecord(s, fieldNames)
			end
			read_input()
		_ ->
			IO.puts("Error: #{response}")
	end
	
	:dets.delete_all_objects(:foodDb)
	:dets.close(:foodDb)
	:file.delete(~c"../priv/online.csv")
end

# Interact reading user input from console and make request to DB
def read_input() do
	zipCodeR = String.trim(IO.gets("Type zip code ('.' to exit) : "))
	IO.puts("Your input : #{zipCodeR}")
	case zipCodeR do
		"." -> :exit
		_ ->
			brandName = String.trim(IO.gets("Type brand name (could be partial) : "))
			IO.puts("Your input : #{brandName}")
			find1 = fn(s1, s2) ->
								case :string.find(s1, s2) do
									:nomatch -> false;
									_ -> true
								end
						end

			req = :dets.traverse(:foodDb, 
				fn({:FoodRecord, _locId, zipCode, applicant, %{~c"Status" => status}} = object) -> 
							case (find1.(applicant, brandName) and (status != ~c"SUSPEND") and (zipCode == String.to_charlist(zipCodeR))) do
								true -> {:continue, object}
								false -> :continue
							end
				end)

			for {:FoodRecord, id, zipCode, applicant, %{~c"Address" => adr, ~c"Status" => sts} } <- req do
				IO.puts("#{id}: #{applicant} ZIPCODE: #{zipCode} ADDRESS::#{adr} STATUS::#{sts}")
			end
			IO.puts("Matched Records: #{length(req)}")
			read_input()
	end
end	

# process one record and save it in DB if not expired
def processRecord(s, fieldNames) do
	fields = splitFields(?, , s, [])
	document = processRecord(fields, fieldNames, %{})

	%{~c"Status" => status} = document
	case status do
		~c"EXPIRED" -> :skip;
		_ ->
			:dets.insert(:foodDb, 
						{ :FoodRecord,
							:maps.get(~c"locationid", document, ~c"0"),
							:maps.get(~c"Zip Codes", document, ~c"n/a"),
							:maps.get(~c"Applicant", document, ~c"n/a"),
							document})
	end
end

# Create map from record's fields list
def processRecord([f | stringList], [fN | fieldNames], map) do
	processRecord(stringList, fieldNames, :maps.put(fN, f, map))
end
def processRecord(_, [], map) do
	map
end

# Split file to lines list
def file2lines(file) do
	{:ok, bin} = :file.read_file(file)
	string2lines(String.to_charlist(bin), [])
end

# Split file content to lines use '\n' as delimiter
def string2lines([10 | str], [])  do string2lines(str,[]) end
def string2lines([10 | str], acc) do [:lists.reverse(acc) | string2lines(str,[])] end
def string2lines([h|t], acc)       do string2lines(t, [h | acc]) end
def string2lines([], [])           do [] end
def string2lines([], acc)          do [:lists.reverse(acc)] end

# Split line to field list using ',' as delimiter and skip ',' inside substring surrounded with '\"'
def splitFields(?, , [?, | str], acc)   do [:lists.reverse(acc) | splitFields(?, , str, [])] end
def splitFields(?, , [?" | str], _)    do splitFields(?", str, []) end
def splitFields(?", [?" | str], acc) do splitFields(?, , str, acc) end
def splitFields(d, [h | t], acc)        do splitFields(d, t, [h | acc]) end
def splitFields(_, [], acc)             do [:lists.reverse(acc)] end

end