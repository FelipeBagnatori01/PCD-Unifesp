#!/bin/bash
# -----------------------------------------------------------------------
# run_with_power.sh
#
# Roda o primes_omp_macos coletando, em paralelo, a potência do sistema via
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
: > "$POWER_LOG"
# Amostra a cada 500 ms; roda até ser encerrado com kill.
# Tanto o powermetrics quanto as marcas abaixo escrevem com >> (O_APPEND) e
# -b 1 (buffer de linha); com > as escritas do powermetrics sobrescreveriam
# as marcas, e com buffer cheio elas cairiam fora de ordem.
powermetrics --samplers cpu_power -i 500 -b 1 >> "$POWER_LOG" 2>/dev/null &
PM_PID=$!

# Pequena pausa para o powermetrics estabilizar antes de medir.
sleep 1

echo "== Executando primes_omp_macos =="
# Se o binário foi compilado por um usuário sem sudo, pode ser necessário
# rodar com o caminho completo e preservar DYLD_LIBRARY_PATH:
#   sudo -E ./primes_omp_macos ...
echo "### INICIO_EXECUCAO $(date '+%Y-%m-%d %H:%M:%S') N=$N schedule=$SCHED chunk=$CHUNK threads=$THREADS reps=$REPS" >> "$POWER_LOG"
STATUS=0
./primes_omp_macos "$N" "$SCHED" "$CHUNK" "$THREADS" "$REPS" "$CSV_OUT" || STATUS=$?
echo "### FIM_EXECUCAO $(date '+%Y-%m-%d %H:%M:%S') status=$STATUS" >> "$POWER_LOG"

echo "== Encerrando powermetrics =="
kill "$PM_PID" 2>/dev/null || true
wait "$PM_PID" 2>/dev/null || true

if [ "$STATUS" -ne 0 ]; then
    echo "ERRO: primes_omp_macos terminou com status $STATUS."
    exit "$STATUS"
fi

echo ""
echo "Execução concluída."
echo "  Métricas de tempo/speedup: $CSV_OUT"
echo "  Log de potência (bruto):   $POWER_LOG"
echo ""
echo "Para extrair a potência média apenas durante a execução (entre as marcas"
echo "### INICIO_EXECUCAO e ### FIM_EXECUCAO do log):"
echo "  awk '/^### INICIO_EXECUCAO/ {on=1; next} /^### FIM_EXECUCAO/ {on=0} on && /Combined Power/ {s+=\$(NF-1); n++} END {print n \" amostras, \" s/n \" mW = \" s/n/1000 \" W\"}' \"$POWER_LOG\""
echo ""
echo "Para estimar a energia total (J), multiplique a potência média (W)"
echo "pelo tempo de execução (wall_time_s do CSV): E = P_media_W * tempo_s"
