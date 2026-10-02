@echo off
REM -----------------------------------------------------------------------
REM build_windows.bat
REM
REM Compila primes_omp_windows.c usando MinGW-w64 (gcc com suporte a
REM OpenMP embutido). Equivalente ao build_macos.sh do lado Mac.
REM
REM Pre-requisito: ter o MinGW-w64 instalado e o "gcc" disponivel no PATH.
REM Jeito mais simples de instalar:
REM   1. Baixe e instale o MSYS2:  https://www.msys2.org/
REM   2. Abra o terminal "MSYS2 MinGW64" (nao o MSYS2 normal)
REM   3. Rode:  pacman -S mingw-w64-x86_64-gcc
REM   4. Adicione C:\msys64\mingw64\bin ao PATH do Windows (ou rode este
REM      .bat de dentro do terminal MSYS2 MinGW64, onde o PATH ja esta ok)
REM
REM Uso:
REM   build_windows.bat
REM -----------------------------------------------------------------------

where gcc >nul 2>nul
if %errorlevel% neq 0 (
    echo ERRO: gcc nao encontrado no PATH.
    echo Instale o MinGW-w64 via MSYS2 ^(https://www.msys2.org/^) e rode:
    echo     pacman -S mingw-w64-x86_64-gcc
    echo Depois adicione C:\msys64\mingw64\bin ao PATH, ou rode este
    echo script de dentro do terminal "MSYS2 MinGW64".
    exit /b 1
)

echo Compilando primes_omp_windows.c ...
gcc -fopenmp -O2 -o primes_omp_windows.exe primes_omp_windows.c -lm

if %errorlevel% neq 0 (
    echo ERRO na compilacao.
    exit /b 1
)

echo.
echo OK: gerado primes_omp_windows.exe
echo Teste rapido:
echo     primes_omp_windows.exe 1000000 dynamic 1000 4 3
