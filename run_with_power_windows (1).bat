@echo off
REM -----------------------------------------------------------------------
REM run_with_power_windows.bat
REM
REM Windows nao tem um equivalente direto ao powermetrics do macOS (nao
REM ha RAPL exposto de forma simples por padrao). A abordagem aqui e:
REM
REM   1. Voce inicia o log de potencia de uma ferramenta de monitoramento
REM      ANTES de rodar este script (ver README_windows.md para como
REM      configurar o HWiNFO64 em modo de logging continuo).
REM   2. Este script imprime marcadores de INICIO/FIM com timestamp num
REM      arquivo .log, igual ao run_with_power.sh do Mac faz dentro do
REM      proprio log do powermetrics.
REM   3. Depois, voce alinha esses timestamps com o CSV gerado pelo
REM      HWiNFO64 (que tambem tem coluna de tempo) para isolar as
REM      amostras de potencia que caem dentro da janela de execucao.
REM
REM Uso:
REM   run_with_power_windows.bat <N> <schedule> <chunk> <threads> [reps] [csv_out]
REM
REM Exemplo:
REM   run_with_power_windows.bat 20000000 dynamic 1000 8 5 resultados_windows.csv
REM -----------------------------------------------------------------------

set BIN=primes_omp_windows.exe
set LOG=power_markers_%2_%3_%4threads.log

echo ### INICIO_EXECUCAO %date% %time% >> %LOG%
%BIN% %1 %2 %3 %4 %5 %6
echo ### FIM_EXECUCAO %date% %time% >> %LOG%

echo.
echo Marcadores salvos em: %LOG%
echo Alinhe estes timestamps com o CSV de log do HWiNFO64 (ou ferramenta
echo equivalente) para calcular a potencia media durante a execucao.
echo Energia estimada (J) = potencia media (W) x wall_time_s (do CSV de resultados).
