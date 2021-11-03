C:\apps\vasm\vasm6502_oldstyle.exe .\src\main.asm -chklabels -L "build\out.txt" -Fbin -o "out\main.prg"
if not "%errorlevel%"=="0" goto fail
c:\apps\c64debugger\C64Debugger.exe .\out\main.prg
:fail