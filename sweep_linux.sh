#!/bin/bash
# -----------------------------------------------------------------------
# sweep.sh
#
# Varre automaticamente as configurações mínimas pedidas no protocolo
# experimental do trabalho de PCD:
#   - versão sequencial
#   - versão paralela com 1, 2, 4, 8, N threads (N = núcleos lógicos)
#   - políticas static, dynamic, guided
#   - alguns chunk sizes de exemplo
#   - 10 repetições por configuração, com 1 execução de aquecimento
#
# Ajuste as listas abaixo (THREAD_LIST, SCHEDULES, CHUNKS, N) conforme
# a capacidade da sua máquina antes de rodar.
#
# Uso:
#   chmod +x sweep.sh
#   ./sweep.sh
# -----------------------------------------------------------------------

set -e

BIN=./primes_omp_linux
N=100000000                 # tamanho do problema (ajuste conforme o tempo desejado)
REPS=10                    # repetições por configuração (protocolo pede >= 10)
CSV_OUT=NOVO_resultado_wsl.csv
SCHEDULES=("dynamic" "guided" "static")
CHUNKS=(1 100 1000 10000)
THREAD_LIST=(1 2 4 8 12 16)      # adicione mais valores se sua máquina tiver mais núcleos

if [ ! -x "$BIN" ]; then
    echo "ERRO: $BIN não encontrado ou não executável. Rode ./build_linux.sh primeiro."
    exit 1
fi

# Remove CSV anterior para não misturar execuções de dias diferentes
# (comente esta linha se quiser acumular resultados)
rm -f "$CSV_OUT"

echo "== Execução de aquecimento (descartada) =="
"$BIN" "$N" seq 0 1 1 /tmp/warmup_discard.csv > /dev/null
rm -f /tmp/warmup_discard.csv

echo "== Versão sequencial (baseline) =="
"$BIN" "$N" seq 0 1 "$REPS" "$CSV_OUT"

for T in "${THREAD_LIST[@]}"; do
    for SCHED in "${SCHEDULES[@]}"; do
        for CHUNK in "${CHUNKS[@]}"; do
            echo "== schedule=$SCHED chunk=$CHUNK threads=$T =="
            "$BIN" "$N" "$SCHED" "$CHUNK" "$T" "$REPS" "$CSV_OUT"
        done
    done
done

echo ""
echo "Varredura concluída. Resultados em: $CSV_OUT"
echo "Linhas geradas:"
wc -l "$CSV_OUT"
