# recruiter_test

## Steps to run test application

1. Make sure your computer has installed Erlang/OTP platform.
2. Clone the repository from GitHub
3. Make directory recruiter_test/src current: cd <your base dir>/recruiter_test/src
4. Run Erlang shell: erl
5. compile source file: c(main).
6. run application: main:start().
   (make sure your computer connected to internet)
7. Type zipcode and brand name as promted
8. You will get something like this:

```erlang
1> c(main).     
{ok,main}
2> main:start().
Done
Type zip code ('space' to exit) : 28854
Your input : "28854"
Type brand name (could be partial) : LLC
Your input : "LLC"
"1416733":  "Off the Grid Services, LLC" ADDRESS::"1 BUSH ST" STATUS::"REQUESTED"
"1042438":  "Ruru Juice LLC" ADDRESS::"80 SUTTER ST" STATUS::"REQUESTED"
"1733728":  "MOMO INNOVATION LLC" ADDRESS::"351 CALIFORNIA ST" STATUS::"APPROVED"
"1744305":  "BOWL'D ACAI, LLC." ADDRESS::"451 MONTGOMERY ST" STATUS::"APPROVED"
"1733786":  "MOMO INNOVATION LLC" ADDRESS::"1 BUSH ST" STATUS::"APPROVED"
"1744302":  "BOWL'D ACAI, LLC." ADDRESS::"111 BATTERY ST" STATUS::"APPROVED"
Matched Records: 6
Type zip code ('space' to exit) :  
Your input : []
ok
```
