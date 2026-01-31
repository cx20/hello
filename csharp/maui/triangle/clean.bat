dotnet clean -c Release -p:Platform=x64
dotnet clean -c Debug  -p:Platform=x64
rmdir /s /q bin
rmdir /s /q obj
