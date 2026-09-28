#!/bin/bash
# -----------------------------------------------------------------------
# run_with_power.sh
#
# Roda o primes_omp coletando, em paralelo, a potência do sistema via
# `powermetrics` (ferramenta nativa do macOS). Isso substitui o RAPL do
# Linux, que não existe no macOS.
#
# IMPORTANTE:
#   - powermetrics exige sudo.
#   - Em Apple Silicon (M1/M2/M3), powermetrics reporta a potência do
#     pacote (CPU + GPU + ANE) via "-s cpu_power" ou o resumo "Combined
#     Power". Em Mac Intel, reporta pacote via sensores do SMC/RAPL.
#   - A amostragem do powermetrics tem overhead (ainda que pequeno) e
#     resolução temporal limitada (por padrão a cada 1000 ms); para
#     execuções muito curtas o resultado pode não ser confiável.
#     Recomenda-se usar N grande o bastante para a execução durar pelo
#     menos alguns segundos.
#
# Uso:
#   chmod +x run_with_power.sh
#   ./run_with_power.sh <N> <schedule> <chunk> <threads> <repeticoes> <csv_out>
#
# Exemplo:
#   sudo ./run_with_power.sh 20000000 dynamic 1000 8 5 resultados.csv
#
# Saída:
#   - resultados.csv           -> métricas de tempo/speedup/eficiência
#   - power_<schedule>_<chunk>_<threads>threads.log -> log bruto do powermetrics
# -----------------------------------------------------------------------

set -e

if [ "$EUID" -ne 0 ]; then
    echo "Este script precisa rodar com sudo (powermetrics exige privilégios de root)."
    echo "Uso: sudo ./run_with_power.sh <N> <schedule> <chunk> <threads> <repeticoes> <csv_out>"
    exit 1
fi

N=$1
SCHED=$2
CHUNK=$3
THREADS=$4
REPS=${5:-1}
CSV_OUT=${6:-resultados.csv}

if [ -z "$N" ] || [ -z "$SCHED" ] || [ -z "$CHUNK" ] || [ -z "$THREADS" ]; then
    echo "Uso: sudo ./run_with_power.sh <N> <schedule> <chunk> <threads> [repeticoes] [csv_out]"
    exit 1
fi

POWER_LOG="power_${SCHED}_${CHUNK}_${THREADS}threads.log"

echo "== Iniciando powermetrics em background (log: $POWER_LOG) =="
# Amostra a cada 500 ms; roda até ser encerrado com kill.
powermetrics --samplers cpu_power -i 500 > "$POWER_LOG" 2>/dev/null &
PM_PID=$!

# Pequena pausa para o powermetrics estabilizar antes de medir.
sleep 1

echo "== Executando primes_omp =="
# Se o binário foi compilado por um usuário sem sudo, pode ser necessário
# rodar com o caminho completo e preservar DYLD_LIBRARY_PATH:
#   sudo -E ./primes_omp ...
./primes_omp "$N" "$SCHED" "$CHUNK" "$THREADS" "$REPS" "$CSV_OUT"

echo "== Encerrando powermetrics =="
kill "$PM_PID" 2>/dev/null || true
wait "$PM_PID" 2>/dev/null || true

echo ""
echo "Execução concluída."
echo "  Métricas de tempo/speedup: $CSV_OUT"
echo "  Log de potência (bruto):   $POWER_LOG"
echo ""
echo "Para extrair a potência média (mW) do log:"
echo "  grep 'Combined Power' \"$POWER_LOG\" | awk '{print \$NF}'"
echo ""
echo "Para estimar a energia total (J), multiplique a potência média (W)"
echo "pelo tempo de execução (wall_time_s do CSV): E = P_media_W * tempo_s"
