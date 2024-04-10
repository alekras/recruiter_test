%% @author alexei
%% @doc @todo Add description to main.

-module(main).


-record(foodRecord,
	{
		locationId = [] :: string(),
		zipCode = [] :: string(),
		applicant = [] :: string(),
		document = #{} :: map()
	}
).
%% ====================================================================
%% API functions
%% ====================================================================
-export([start/0]).

start() ->
	inets:start(),
	ssl:start(),

%% create database ETS based on file system.
	case dets:open_file(foodDb, [{file, "../priv/food_db.bin"}, {type, duplicate_bag}, {keypos, 2}]) of
		{ok, _} ->
			true;
		{error, Reason} ->
			io:format("Cannot open foodDb dets: ~p~n", [Reason]),
			false
	end,

%% Get data from online URL
	Response = httpc:request(get, 
		{"https://data.sfgov.org/api/views/rqzj-sfat/rows.csv", []},
		[{ssl,
			[
				{verify, verify_none}
			]
		 }
		],
		[]),

%% Process data: split to lines, extract field names, split each line to fields
	case Response of
		{ok, {{_, 200, "OK"}, _Headers, Body}} ->
			io:format("Done~n"),
			file:write_file("../priv/online.csv", Body),
			[FirstLine | RestLines] = file2lines("../priv/online.csv"),
%			[FirstLine | RestLines] = file2lines("../priv/test.csv"),
			FieldNames = string:split(FirstLine, ",", all),
			[processRecord(S, FieldNames) || S <- RestLines],
			read_input();
		_ ->
			io:format("Error~n")
	end,
	
	dets:delete_all_objects(foodDb),
	dets:close(foodDb),
	file:delete("../priv/online.csv").

%% ====================================================================
%% Internal functions
%% ====================================================================
%% Interact reading user input from console and make request to DB
read_input() ->
	{ok,[ZipCodeR]} = io:fread("Type zip code ('space' to exit) : ", "~s"),
	io:format("Your input : ~p~n", [ZipCodeR]),
	case ZipCodeR of
		[] -> ok;
		_ ->
			{ok, [BrandName]} = io:fread("Type brand name (could be partial) : ", "~s"),
			io:format("Your input : ~p~n", [BrandName]),
			Find = fun(S1, S2) ->
								case string:find(S1, S2) of
									nomatch -> false;
									_ -> true
								end
						end,
			Fun =
				fun (#foodRecord{zipCode = ZipCode, applicant = Applicant, document = #{"Status" := Status}} = Object) when ZipCode =:= ZipCodeR -> 
							case Find(Applicant, BrandName) and (Status =/= "SUSPEND") of
								true -> {continue, Object};
								false -> continue
							end;
						(_) -> continue
				end,
			Req = dets:traverse(foodDb, Fun),
			[ io:format("~p:  ~p ADDRESS::~p STATUS::~p~n", [Id, Ap, Adr, Sts]) 
				|| #foodRecord{locationId = Id, applicant = Ap, document = #{"Address" := Adr, "Status" := Sts} } <- Req],
			io:format("Matched Records: ~p~n", [length(Req)]),
			read_input()
	end.	

%% process one record and save it in DB if not expired
processRecord(S, FieldNames) ->
	Fields = splitFields(",", S, []),
	Document = processRecord(Fields, FieldNames, #{}),

	#{"Status" := Status} = Document,
	case Status of
		"EXPIRED" -> skip;
		_ ->
			dets:insert(foodDb, 
							#foodRecord{
													locationId = maps:get("locationid", Document, "0"),
													zipCode = maps:get("Zip Codes", Document, "n/a"),
													applicant = maps:get("Applicant", Document, "n/a"),
													document = Document})
	end.

%% Create map from record's fields list
processRecord([F | StringList], [FN | FieldNames], Map) ->
	processRecord(StringList, FieldNames, maps:put(FN, F, Map));
processRecord(_, [], Map) ->
	Map.

%% Split file to lines list
file2lines(File) ->
	{ok, Bin} = file:read_file(File),
	string2lines(binary:bin_to_list(Bin), []).

%% Split file content to lines use '\n' as delimiter
string2lines("\n" ++ Str, []) -> string2lines(Str,[]);
string2lines("\n" ++ Str, Acc) -> [lists:reverse(Acc) | string2lines(Str,[])];
string2lines([H|T], Acc)       -> string2lines(T, [H|Acc]);
string2lines([], [])          -> [];
string2lines([], Acc)          -> [lists:reverse(Acc)].

%% Split line to field list using ',' as delimiter and skip ',' inside substring surrounded with "\""
splitFields(",", "," ++ Str, Acc) -> [lists:reverse(Acc) | splitFields(",", Str, [])];
splitFields(",", "\"" ++ Str, _) -> splitFields("\"", Str, []);
splitFields("\"", "\"" ++ Str, Acc) -> splitFields(",", Str, Acc);
%splitFields("\"", "," ++ Str, _) -> splitFields(",", Str, []);
splitFields(D, [H|T], Acc)       -> splitFields(D, T, [H|Acc]);
splitFields(_, [], Acc)          -> [lists:reverse(Acc)].
