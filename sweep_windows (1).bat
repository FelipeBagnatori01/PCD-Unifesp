@echo off
REM -----------------------------------------------------------------------
REM sweep_windows.bat
REM
REM Equivalente ao sweep.sh, para rodar no Windows apos compilar com
REM build_windows.bat. Varre:
REM   - versao sequencial
REM   - versao paralela com 1, 2, 4, 8, 12 threads (ajuste THREAD_LIST)
REM   - politicas static, dynamic, guided
REM   - chunk sizes 1, 100, 1000, 10000
REM   - 10 repeticoes por configuracao, com 1 execucao de aquecimento
REM
REM Ajuste N, REPS e as listas abaixo conforme o hardware e o tempo
REM disponivel antes de rodar.
REM
REM Uso:
REM   sweep_windows.bat
REM -----------------------------------------------------------------------

setlocal enabledelayedexpansion

set BIN=primes_omp_windows.exe
set N=10000000
set REPS=10
set CSV_OUT=resultados_windows.csv

if not exist %BIN% (
    echo ERRO: %BIN% nao encontrado. Rode build_windows.bat primeiro.
    exit /b 1
)

if exist %CSV_OUT% del %CSV_OUT%

echo == Execucao de aquecimento ^(descartada^) ==
%BIN% %N% seq 0 1 1 _warmup_discard.csv >nul
if exist _warmup_discard.csv del _warmup_discard.csv

echo == Versao sequencial ^(baseline^) ==
%BIN% %N% seq 0 1 %REPS% %CSV_OUT%

for %%T in (1 2 4 8 12) do (
    for %%S in (dynamic guided static) do (
        for %%C in (1 100 1000 10000) do (
            echo == schedule=%%S chunk=%%C threads=%%T ==
            %BIN% %N% %%S %%C %%T %REPS% %CSV_OUT%
        )
    )
)

echo.
echo Varredura concluida. Resultados em: %CSV_OUT%
