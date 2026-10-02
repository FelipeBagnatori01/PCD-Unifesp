/*
 * primes_omp_windows.c
 * -----------------------------------------------------------------------
 * Versão para Windows (MinGW-w64) do contador de números primos em
 * paralelo com OpenMP, usado no trabalho de Programação Concorrente e
 * Distribuída (PCD). É a mesma lógica de primes_omp_macos.c; a única
 * mudança relevante é o timer, trocado de clock_gettime(CLOCK_MONOTONIC)
 * para omp_get_wtime(), que é parte do próprio padrão OpenMP e funciona
 * de forma idêntica em macOS, Linux e Windows — evita qualquer dúvida
 * sobre suporte de CLOCK_MONOTONIC no MinGW.
 *
 * -----------------------------------------------------------------------
 * ADAPTAÇÕES PARA WINDOWS (vs. a versão macOS)
 * -----------------------------------------------------------------------
 * 1) Timer: omp_get_wtime() no lugar de clock_gettime(). Tem resolução
 *    de microssegundos ou melhor, suficiente para este experimento, e é
 *    portável entre os SOs usados no trabalho (Mac e Windows).
 *
 * 2) Compilação: usar MinGW-w64 (gcc), que já traz suporte a OpenMP
 *    embutido — não precisa de nada equivalente ao libomp do Homebrew.
 *    Ver build_windows.bat.
 *
 * 3) Medição de energia: Windows não tem powermetrics nem RAPL exposto
 *    de forma simples como no macOS/Linux. Ver run_with_power_windows.bat
 *    e README_windows.md para a abordagem usada (log externo via
 *    ferramenta de monitoramento, com marcadores de início/fim).
 *
 * 4) Afinidade de thread: assim como no Mac, o agendador do Windows
 *    decide em qual núcleo cada thread roda; isso deve ser citado como
 *    limitação/ameaça à validade no artigo, igual já é feito para o Mac.
 * -----------------------------------------------------------------------
 *
 * Compilação (ver também build_windows.bat):
 *   gcc -fopenmp -O2 -o primes_omp_windows.exe primes_omp_windows.c -lm
 *
 * Uso:
 *   primes_omp_windows.exe <N> <schedule> <chunk> <threads> [repeticoes] [csv_out]
 *
 *   N          : limite superior do intervalo [2, N]
 *   schedule   : static | dynamic | guided | seq  (seq = versão sequencial)
 *   chunk      : tamanho do bloco de iterações (ignorado se schedule=seq)
 *   threads    : número de threads OpenMP (ignorado se schedule=seq)
 *   repeticoes : quantas vezes repetir a medição (default = 1)
 *   csv_out    : caminho do arquivo CSV de saída (default = resultados.csv)
 *
 * Exemplo:
 *   primes_omp_windows.exe 10000000 dynamic 1000 8 10 resultados_windows.csv
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <math.h>

#ifdef _OPENMP
#include <omp.h>
#endif

/* ------------------------------------------------------------------ */
/* Timer portável. Usa omp_get_wtime() quando OpenMP está disponível  */
/* (caso normal); se o binário for compilado sem _OPENMP, cai para    */
/* clock() do <time.h> como último recurso (menor resolução).         */
/* ------------------------------------------------------------------ */
#ifndef _OPENMP
#include <time.h>
static double get_wtime(void) {
    return (double)clock() / (double)CLOCKS_PER_SEC;
}
#else
static double get_wtime(void) {
    return omp_get_wtime();
}
#endif

/* ------------------------------------------------------------------ */
/* Teste de primalidade por divisões sucessivas.                      */
/* Retorna 1 se n for primo, 0 caso contrário.                        */
/* work_out recebe o número de operações de divisão realizadas.       */
/* ------------------------------------------------------------------ */
static inline int is_prime(int64_t n, int64_t *work_out) {
    int64_t work = 0;
    if (n < 2) { *work_out = work; return 0; }
    if (n == 2) { *work_out = 1; return 1; }
    if (n % 2 == 0) { *work_out = 1; return 0; }

    int64_t limit = (int64_t)sqrtl((long double)n);
    for (int64_t i = 3; i <= limit; i += 2) {
        work++;
        if (n % i == 0) { *work_out = work; return 0; }
    }
    *work_out = work;
    return 1;
}

/* ------------------------------------------------------------------ */
/* Estrutura para acumular métricas de uma execução                   */
/* ------------------------------------------------------------------ */
typedef struct {
    double   wall_time_s;
    long     prime_count;
    int      num_threads;
    double  *thread_time;
    int64_t *thread_work;
} run_result_t;

static void free_result(run_result_t *r) {
    free(r->thread_time);
    free(r->thread_work);
    r->thread_time = NULL;
    r->thread_work = NULL;
}

/* ------------------------------------------------------------------ */
/* Versão sequencial (baseline)                                       */
/* ------------------------------------------------------------------ */
static run_result_t run_sequential(int64_t n) {
    run_result_t r;
    memset(&r, 0, sizeof(r));
    r.num_threads = 1;
    r.thread_time = calloc(1, sizeof(double));
    r.thread_work = calloc(1, sizeof(int64_t));

    double t0 = get_wtime();

    long count = 0;
    int64_t total_work = 0;
    for (int64_t i = 2; i <= n; i++) {
        int64_t w = 0;
        if (is_prime(i, &w)) count++;
        total_work += w;
    }

    double t1 = get_wtime();
    r.wall_time_s = t1 - t0;
    r.prime_count = count;
    r.thread_time[0] = r.wall_time_s;
    r.thread_work[0] = total_work;
    return r;
}

/* ------------------------------------------------------------------ */
/* Versão paralela OpenMP com escalonamento e chunk configuráveis.    */
/* ------------------------------------------------------------------ */
static run_result_t run_parallel(int64_t n, omp_sched_t kind, int chunk, int nthreads) {
    run_result_t r;
    memset(&r, 0, sizeof(r));
    r.num_threads = nthreads;
    r.thread_time = calloc(nthreads, sizeof(double));
    r.thread_work = calloc(nthreads, sizeof(int64_t));

    omp_set_num_threads(nthreads);
    omp_set_schedule(kind, chunk);

    long count = 0;
    double t0 = get_wtime();

    #pragma omp parallel reduction(+:count)
    {
        int tid = omp_get_thread_num();
        double ts0 = get_wtime();

        int64_t local_work = 0;

        /* nowait: sem ele, a barreira implícita do 'for' faria toda thread
           esperar a mais lenta antes de ts1, zerando o imbalance medido. */
        #pragma omp for schedule(runtime) nowait
        for (int64_t i = 2; i <= n; i++) {
            int64_t w = 0;
            if (is_prime(i, &w)) count++;
            local_work += w;
        }

        double ts1 = get_wtime();
        r.thread_time[tid] = ts1 - ts0;
        r.thread_work[tid] = local_work;
    }

    double t1 = get_wtime();
    r.wall_time_s = t1 - t0;
    r.prime_count = count;
    return r;
}

/* ------------------------------------------------------------------ */
/* Métricas derivadas: desbalanceamento entre threads                 */
/* ------------------------------------------------------------------ */
static void thread_balance_stats(const run_result_t *r, double *max_t, double *min_t,
                                  double *mean_t, double *imbalance) {
    double sum = 0.0, mx = -1.0, mn = 1e18;
    for (int i = 0; i < r->num_threads; i++) {
        double t = r->thread_time[i];
        sum += t;
        if (t > mx) mx = t;
        if (t < mn) mn = t;
    }
    *mean_t = sum / r->num_threads;
    *max_t = mx;
    *min_t = mn;
    *imbalance = (*mean_t > 0.0) ? (mx - *mean_t) / (*mean_t) : 0.0;
}

static const char *sched_name(omp_sched_t kind) {
    switch (kind) {
        case omp_sched_static:  return "static";
        case omp_sched_dynamic: return "dynamic";
        case omp_sched_guided:  return "guided";
        default: return "unknown";
    }
}

int main(int argc, char **argv) {
    if (argc < 5) {
        fprintf(stderr,
            "Uso: %s <N> <schedule: static|dynamic|guided|seq> <chunk> <threads> "
            "[repeticoes] [csv_out]\n", argv[0]);
        return 1;
    }

    int64_t n         = atoll(argv[1]);
    const char *sched_arg = argv[2];
    int chunk         = atoi(argv[3]);
    int nthreads      = atoi(argv[4]);
    int repetitions   = (argc >= 6) ? atoi(argv[5]) : 1;
    const char *csv_path = (argc >= 7) ? argv[6] : "resultados_windows.csv";

    int is_sequential = (strcmp(sched_arg, "seq") == 0);
    omp_sched_t kind = omp_sched_static;
    if (strcmp(sched_arg, "dynamic") == 0) kind = omp_sched_dynamic;
    else if (strcmp(sched_arg, "guided") == 0) kind = omp_sched_guided;
    else if (strcmp(sched_arg, "static") == 0) kind = omp_sched_static;
    else if (!is_sequential) {
        fprintf(stderr, "schedule invalido: %s (use static|dynamic|guided|seq)\n", sched_arg);
        return 1;
    }

#ifdef _OPENMP
    int max_available = omp_get_max_threads();
#else
    int max_available = 1;
    fprintf(stderr, "AVISO: binario compilado sem suporte a OpenMP "
                     "(defina _OPENMP corretamente). Rodando sequencial.\n");
    is_sequential = 1;
#endif
    if (!is_sequential && nthreads < 1) {
        fprintf(stderr, "ERRO: numero de threads invalido (%d). Use um valor >= 1.\n", nthreads);
        return 1;
    }
    if (!is_sequential && nthreads > max_available) {
        fprintf(stderr, "AVISO: pedidas %d threads, mas apenas %d disponiveis no sistema.\n",
                nthreads, max_available);
    }

    FILE *csv = fopen(csv_path, "a");
    if (!csv) { perror("fopen csv"); return 1; }

    fseek(csv, 0, SEEK_END);
    long fsize = ftell(csv);
    if (fsize == 0) {
        fprintf(csv,
            "n,schedule,chunk,threads_pedidas,threads_efetivas,repeticao,"
            "wall_time_s,prime_count,speedup,eficiencia,"
            "tempo_max_thread_s,tempo_min_thread_s,tempo_medio_thread_s,"
            "imbalance_ratio,total_work,work_max_thread,work_min_thread\n");
    }

    printf("=== Contagem de primos ate N=%lld (Windows) ===\n", (long long)n);
    printf("Schedule: %s | chunk: %d | threads pedidas: %d | repeticoes: %d\n",
           sched_arg, chunk, nthreads, repetitions);
    printf("threads disponiveis no sistema: %d\n\n", max_available);

    /* IMPORTANTE: assim como na versao macOS, speedup/eficiencia aqui so
       tem valor dentro da MESMA invocacao do binario. Como sweep roda
       cada configuracao como um processo separado, essas duas colunas
       devem ser recalculadas depois em pandas usando a media da linha
       schedule=seq como baseline — nao confie nestas colunas no CSV cru. */
    double seq_time_ref = -1.0;

    for (int rep = 1; rep <= repetitions; rep++) {
        run_result_t r;

        if (is_sequential) {
            r = run_sequential(n);
            seq_time_ref = r.wall_time_s;
        } else {
            r = run_parallel(n, kind, chunk, nthreads);
        }

        double max_t, min_t, mean_t, imbalance;
        thread_balance_stats(&r, &max_t, &min_t, &mean_t, &imbalance);

        int64_t total_work = 0, work_max = 0, work_min = (r.thread_work[0]);
        for (int i = 0; i < r.num_threads; i++) {
            total_work += r.thread_work[i];
            if (r.thread_work[i] > work_max) work_max = r.thread_work[i];
            if (r.thread_work[i] < work_min) work_min = r.thread_work[i];
        }

        double speedup = -1.0, efficiency = -1.0;
        if (seq_time_ref > 0.0 && r.wall_time_s > 0.0) {
            speedup = seq_time_ref / r.wall_time_s;
            efficiency = speedup / r.num_threads;
        }

        printf("[rep %2d] tempo=%.6fs  primos=%ld  ", rep, r.wall_time_s, r.prime_count);
        if (speedup > 0) {
            printf("speedup=%.3f  eficiencia=%.3f  ", speedup, efficiency);
        }
        printf("imbalance=%.3f\n", imbalance);

        char speedup_str[32] = "";
        char efficiency_str[32] = "";
        if (speedup > 0)   snprintf(speedup_str, sizeof(speedup_str), "%.6f", speedup);
        if (efficiency > 0) snprintf(efficiency_str, sizeof(efficiency_str), "%.6f", efficiency);

        fprintf(csv, "%lld,%s,%d,%d,%d,%d,%.6f,%ld,%s,%s,%.6f,%.6f,%.6f,%.6f,%lld,%lld,%lld\n",
            (long long)n,
            is_sequential ? "seq" : sched_name(kind),
            chunk, nthreads, r.num_threads, rep,
            r.wall_time_s, r.prime_count,
            speedup_str, efficiency_str,
            max_t, min_t, mean_t, imbalance,
            (long long)total_work, (long long)work_max, (long long)work_min);

        free_result(&r);
    }

    fclose(csv);
    printf("\nResultados salvos em: %s\n", csv_path);
    return 0;
}
