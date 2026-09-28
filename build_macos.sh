#!/bin/bash
# -----------------------------------------------------------------------
# build_macos.sh
# Compila primes_omp_macos.c em macOS (Intel ou Apple Silicon).
#
# Pré-requisitos:
#   1) Xcode Command Line Tools:
#        xcode-select --install
#   2) Homebrew (https://brew.sh), se ainda não tiver:
#        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
#   3) libomp via Homebrew:
#        brew install libomp
#
# Uso:
#   chmod +x build_macos.sh
#   ./build_macos.sh
# -----------------------------------------------------------------------

set -e

echo "== Verificando Homebrew =="
if ! command -v brew &> /dev/null; then
    echo "ERRO: Homebrew nao encontrado. Instale em https://brew.sh e rode este script novamente."
    exit 1
fi

echo "== Verificando libomp =="
if ! brew list libomp &> /dev/null; then
    echo "libomp nao encontrado. Instalando..."
    brew install libomp
else
    echo "libomp ja instalado."
fi

# Descobre o prefixo do Homebrew (difere entre Apple Silicon e Intel):
#   Apple Silicon: /opt/homebrew
#   Intel:         /usr/local
BREW_PREFIX=$(brew --prefix)
LIBOMP_PREFIX=$(brew --prefix libomp)

echo "== Homebrew prefix: $BREW_PREFIX =="
echo "== libomp prefix:   $LIBOMP_PREFIX =="

echo "== Compilando primes_omp_macos.c =="
clang \
    -Xpreprocessor -fopenmp \
    -I"${LIBOMP_PREFIX}/include" \
    -L"${LIBOMP_PREFIX}/lib" \
    -lomp \
    -O2 \
    -Wall \
    -o primes_omp_macos \
    primes_omp_macos.c \
    -lm

echo ""
echo "== Compilacao concluida: ./primes_omp_macos =="
echo ""
echo "Para rodar, pode ser necessario indicar onde esta a libomp em tempo de execucao:"
echo "  export DYLD_LIBRARY_PATH=\"${LIBOMP_PREFIX}/lib:\$DYLD_LIBRARY_PATH\""
echo ""
echo "Teste rapido:"
echo "  ./primes_omp_macos 1000000 seq 0 1 3 resultados.csv"
echo "  ./primes_omp_macos 1000000 dynamic 1000 4 3 resultados.csv"
