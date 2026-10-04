#!/bin/bash
# Compila primes_omp_macos.c no Linux/WSL (gcc + OpenMP). Gera ./primes_omp_linux
set -e
gcc -O2 -Wall -fopenmp -o primes_omp_linux primes_omp_macos.c -lm
echo "Compilacao concluida: ./primes_omp_linux"
