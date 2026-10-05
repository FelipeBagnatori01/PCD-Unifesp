# Execução em Windows + WSL2 (Ubuntu)

Este arquivo documenta como o experimento de contagem de primos com OpenMP
foi executado em um notebook Windows, usando WSL2, e o que foi necessário
adaptar em relação à versão macOS. O README principal descreve a versão macOS.

## Resumo

O **código-fonte do experimento não foi alterado**: `primes_omp_macos.c` é o
mesmo arquivo usado no macOS. Mudaram apenas o modo de compilar e executar
(scripts novos) e o ambiente. Os resultados estão em `resultados_wsl.csv`,
com o mesmo esquema de colunas do `resultados.csv`.

## Arquivos desta versão

| Arquivo | Função |
|---|---|
| `build_linux.sh` | Compila `primes_omp_macos.c` com `gcc -fopenmp` e gera `primes_omp_linux` |
| `sweep_linux.sh` | Cópia do `sweep.sh` com 4 linhas ajustadas (ver abaixo) |
| `resultados_wsl.csv` | Resultados da varredura completa (610 execuções) |

O binário `primes_omp_linux` não é versionado: é gerado pelo `build_linux.sh`.

## Ambiente

| Item | Valor |
|---|---|
| Processador | Intel Core i7-13620H (13ª geração), 16 threads lógicas |
| Sistema | Windows 11, build 26200.9457 |
| WSL | WSL 3.0.1.0 (WSL2), kernel 6.18.40.1-microsoft-standard-WSL2 |
| Distribuição | Ubuntu 26.04.1 LTS |
| Compilador | gcc 15.2.0 (`-O2 -Wall -fopenmp -lm`) |
| Memória visível ao Linux | 7,6 GiB |

Condições da execução: notebook na tomada, modo de energia "Melhor
desempenho", suspensão desativada e programas pesados fechados. O antivírus permaneceu ativo.

## Como reproduzir

1. Instalar o WSL2 (PowerShell como administrador) e reiniciar:
```powershell
   wsl --install
```
2. No Ubuntu, instalar as ferramentas:
```bash
   sudo apt update
   sudo apt install -y build-essential git
```
3. Clonar o repositório **dentro do Linux** (`~`, não em `/mnt/c`) e entrar na branch:
```bash
   cd ~
   git clone https://github.com/FelipeBagnatori01/PCD-Unifesp
   cd PCD-Unifesp
   git checkout Versao-WSL
```
4. Compilar e executar a varredura:
```bash
   ./build_linux.sh
   chmod +x sweep_linux.sh
   nohup ./sweep_linux.sh > sweep.log 2>&1 &
```
5. Acompanhar o andamento:
```bash
   tail -n 3 sweep.log
   wc -l resultados_wsl.csv
```

O script apaga o `resultados_wsl.csv` ao iniciar. Os resultados só aparecem
no arquivo ao fim de cada configuração (10 repetições).

## Validação

O experimento foi conferido contra os resultados do macOS em tudo o que não
depende da máquina:

- 611 linhas no CSV (1 cabeçalho + 610 execuções, 10 repetições por configuração);
- `prime_count` = 5761455 e `total_work` = 23285621701 em todas as linhas;
- número de threads efetivas igual ao pedido em todas as execuções;
- trabalho por thread (`total_work`, `work_max_thread`, `work_min_thread`) no
  `static` com 1, 2, 4 e 8 threads idêntico ao do macOS.

Para repetir a conferência:

```bash
awk -F, 'NR>1 {pc[$8]++; tw[$15]++} END {for(k in pc) print "prime_count", k, pc[k]; for(k in tw) print "total_work", k, tw[k]}' resultados_wsl.csv
```

## Limitações e observações

- **Energia:** o `powermetrics` só existe no macOS. Nesta versão a energia não
  foi medida diretamente; ficam os indicadores indiretos do CSV (tempo,
  `imbalance_ratio`, `total_work`).
- **Baseline sequencial:** a média no sweep foi de aproximadamente 58,7 s, com
  variação de cerca de 5%, enquanto o paralelo com 1 thread levou cerca de
  49,4 s. Isso infla os speedups medidos contra essa baseline, e deve ser
  considerado na análise.
- **Virtualização:** a execução é dentro do WSL2, sobre o hypervisor do Windows.
  O escalonador do Windows decide onde cada thread roda, e a topologia de
  núcleos exibida pelo `lscpu` é a virtualizada.
- **Processador híbrido:** as 16 threads lógicas não correspondem a 16 núcleos
  idênticos, o que pode afetar a escalabilidade a partir de 8 threads.
- **Threads:** o macOS foi testado com 12 e o WSL com 16, então só 1, 2, 4 e 8
  são diretamente comparáveis.
