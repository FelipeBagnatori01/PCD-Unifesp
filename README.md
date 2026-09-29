# PCD-Unifesp
Trabalho desenvolvido com o propósito de pesquisa em programação concorrente e distribuída para a matéria ministrada na Unifesp

# Contagem de primos em OpenMP — projeto de PCD (macOS)

Script em C que conta números primos em `[2, N]` por divisões sucessivas,
com paralelização em OpenMP e coleta das métricas usadas no trabalho:
tempo, speedup, eficiência paralela, balanceamento de carga entre threads
e (via ferramenta externa) energia.

## Arquivos

| Arquivo             | Função                                                        |
|----------------------|----------------------------------------------------------------|
| `primes_omp_macos.c`       | Código-fonte principal                                        |
| `build_macos.sh`     | Instala dependências e compila no macOS                       |
| `sweep.sh`           | Roda automaticamente todas as configurações do protocolo mínimo |
| `run_with_power.sh`  | Roda uma configuração medindo potência via `powermetrics`     |

## 1. Preparar o ambiente (uma vez só)

```bash
xcode-select --install        # se ainda não tiver as CLI tools
chmod +x build_macos.sh sweep.sh run_with_power.sh
./build_macos.sh              # instala libomp via Homebrew e compila
```

Isso gera o executável `./primes_omp_macos`.

> Se `libomp` já estiver instalado, o script pula a instalação. Em Apple
> Silicon, o Homebrew usa `/opt/homebrew`; em Mac Intel, `/usr/local` — o
> script detecta isso automaticamente com `brew --prefix`.

## 2. Rodar uma configuração isolada

```bash
./primes_omp_macos <N> <schedule> <chunk> <threads> [repeticoes] [csv_out]
```

Exemplos:

```bash
# baseline sequencial, 10 repetições
./primes_omp_macos 10000000 seq 0 1 10 resultados.csv

# OpenMP, dynamic, chunk=1000, 8 threads, 10 repetições
./primes_omp_macos 10000000 dynamic 1000 8 10 resultados.csv
```

O programa imprime no terminal um resumo por repetição e acrescenta uma
linha por repetição em `resultados.csv`, com as colunas:

```
n, schedule, chunk, threads_pedidas, threads_efetivas, repeticao,
wall_time_s, prime_count, speedup, eficiencia,
tempo_max_thread_s, tempo_min_thread_s, tempo_medio_thread_s,
imbalance_ratio, total_work, work_max_thread, work_min_thread
```

- **speedup / eficiencia**: calculados em relação à última execução
  sequencial (`schedule=seq`) rodada no mesmo processo. Rode sempre a
  versão `seq` antes das paralelas na mesma sessão, ou use `sweep.sh`,
  que já faz isso na ordem certa.
- **imbalance_ratio**: `(tempo_max_thread - tempo_médio) / tempo_médio`.
  Quanto mais perto de 0, mais equilibrada a divisão de trabalho entre
  threads — útil para comparar `static` (deve ser o pior, conforme a
  hipótese do projeto) com `dynamic`/`guided`.
- **total_work / work_max_thread / work_min_thread**: número de operações
  de divisão realizadas no total e pela thread mais/menos carregada — uma
  medida de trabalho independente do relógio, complementar ao tempo.

## 3. Rodar a varredura completa do protocolo mínimo

```bash
./sweep.sh
```

Isso executa, com 10 repetições cada:
- a versão sequencial;
- as versões paralelas com 1, 2, 4 e 8 threads (ajustável no script);
- para cada uma, as políticas `static`, `dynamic` e `guided`;
- para cada política, os chunk sizes `1, 100, 1000, 10000` (ajustável).

Edite as variáveis `N`, `THREAD_LIST`, `SCHEDULES` e `CHUNKS` no topo do
`sweep.sh` conforme o hardware disponível e o tempo que você tem para
rodar os experimentos.

## 4. Medir energia (macOS não tem RAPL)

macOS não expõe contadores de energia como o RAPL do Linux. A alternativa
nativa é o `powermetrics`, que precisa rodar como root:

```bash
sudo ./run_with_power.sh 20000000 dynamic 1000 8 5 resultados.csv
```

Isso roda o `primes_omp_macos` normalmente e, em paralelo, grava a potência do
sistema em `power_dynamic_1000_8threads.log`. O script grava no log as
linhas `### INICIO_EXECUCAO` e `### FIM_EXECUCAO` imediatamente antes e
depois do programa, para que as amostras de repouso (antes e depois da
execução) fiquem de fora da média. Para extrair a potência média durante
a execução e estimar a energia:

```bash
awk '/^### INICIO_EXECUCAO/ {on=1; next} /^### FIM_EXECUCAO/ {on=0} on && /Combined Power/ {s+=$(NF-1); n++} END {print n " amostras, " s/n " mW = " s/n/1000 " W"}' power_dynamic_1000_8threads.log
```

Logs gerados antes dessas marcas existirem não têm as linhas `###`; neles,
esse comando não encontra amostras.

Energia estimada (Joules) = potência média (W) × tempo de execução (s),
usando o `wall_time_s` correspondente no CSV.

**Limitações a registrar no artigo:**
- `powermetrics` amostra em intervalos (ex.: 500 ms), então execuções
  muito curtas (< poucos segundos) não têm energia bem estimada — use
  N grande o suficiente. Mesmo com as marcas de início/fim, a primeira
  amostra após `INICIO_EXECUCAO` ainda cobre até 500 ms de repouso, e o
  trecho final da execução entra na amostra que só é gravada depois de
  `FIM_EXECUCAO` (e por isso fica de fora).
- Em Apple Silicon, "Combined Power" inclui CPU + GPU + Neural Engine;
  não é possível isolar apenas os núcleos usados pelo OpenMP.
- Núcleos de performance e eficiência (P-cores/E-cores) em Apple Silicon
  são geridos pelo macOS; não há uma forma simples equivalente a
  `pthread_setaffinity_np` do Linux para fixar threads em núcleos
  específicos, o que deve ser citado como ameaça à validade.

## 5. Analisando os dados

O `resultados.csv` pode ser aberto diretamente no Google Colab (pandas)
para calcular médias/medianas, desvio padrão e gerar os gráficos de
speedup, eficiência e imbalance por configuração — por exemplo:

```python
import pandas as pd
df = pd.read_csv("resultados.csv")
resumo = df.groupby(["schedule", "chunk", "threads_pedidas"]).agg(
    tempo_medio=("wall_time_s", "mean"),
    tempo_std=("wall_time_s", "std"),
    speedup_medio=("speedup", "mean"),
    eficiencia_media=("eficiencia", "mean"),
    imbalance_medio=("imbalance_ratio", "mean"),
).reset_index()
print(resumo.sort_values("tempo_medio"))
```
