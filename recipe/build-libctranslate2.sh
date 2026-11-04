#!/bin/bash
set -ex

# Unvendor nlohmann/json: build and install against the nlohmann_json package
rm -rf include/nlohmann

CMAKE_ARGS_EXTRA=""

# --- GPU selection ---
if [[ ${gpu_variant:0:5} = "cuda-" ]]; then
    CMAKE_ARGS_EXTRA="${CMAKE_ARGS_EXTRA} -DWITH_CUDA=ON -DWITH_CUDNN=ON -DCUDA_DYNAMIC_LOADING=ON"
    # Upstream's default CUDA_ARCH_LIST=Auto builds only the CI worker's GPU. FindCUDA's list parser
    # takes single-digit majors only, so Blackwell SASS is added as raw -gencode; 9.0+PTX JITs forward.
    if [[ ${cuda_compiler_version} == 12.* ]]; then
        CT2_CUDA_ARCHS="5.0;6.0;6.1;7.0;7.5;8.0;8.6;8.9;9.0+PTX"
    else
        # nvcc 13 dropped Maxwell, Pascal and Volta
        CT2_CUDA_ARCHS="7.5;8.0;8.6;8.9;9.0+PTX"
    fi
    CT2_NVCC_FLAGS="-Xfatbin=-compress-all;-gencode=arch=compute_100,code=sm_100;-gencode=arch=compute_120,code=sm_120"
    # FindCUDA links the static CUDA runtime by default; use the shared one from cuda-cudart
    CMAKE_ARGS_EXTRA="${CMAKE_ARGS_EXTRA} -DCUDA_ARCH_LIST=${CT2_CUDA_ARCHS} -DCUDA_NVCC_FLAGS=${CT2_NVCC_FLAGS} -DCUDA_USE_STATIC_CUDA_RUNTIME=OFF"
    # cuda-compat provided libcuda.so.1
    LDFLAGS="$LDFLAGS -Wl,-rpath-link,${PREFIX}/cuda-compat/"
    # cicc (NVCC internal compiler) lives in nvvm/bin, not on PATH by default
    if [[ -d "${BUILD_PREFIX}/nvvm/bin" ]]; then
        export PATH="${PATH}:${BUILD_PREFIX}/nvvm/bin"
    fi
else
    CMAKE_ARGS_EXTRA="${CMAKE_ARGS_EXTRA} -DWITH_CUDA=OFF -DWITH_CUDNN=OFF"
fi

# --- BLAS selection (mutually exclusive) ---
if [[ ${blas_impl:-} = "mkl" ]]; then
    CMAKE_ARGS_EXTRA="${CMAKE_ARGS_EXTRA} -DWITH_MKL=ON -DWITH_OPENBLAS=OFF -DWITH_ACCELERATE=OFF"
    CMAKE_ARGS_EXTRA="${CMAKE_ARGS_EXTRA} -DOPENMP_RUNTIME=INTEL"
elif [[ ${blas_impl:-} = "openblas" ]]; then
    CMAKE_ARGS_EXTRA="${CMAKE_ARGS_EXTRA} -DWITH_MKL=OFF -DWITH_OPENBLAS=ON -DWITH_ACCELERATE=OFF"
    CMAKE_ARGS_EXTRA="${CMAKE_ARGS_EXTRA} -DOPENMP_RUNTIME=COMP"
elif [[ ${blas_impl:-} = "accelerate" ]]; then
    CMAKE_ARGS_EXTRA="${CMAKE_ARGS_EXTRA} -DWITH_MKL=OFF -DWITH_OPENBLAS=OFF -DWITH_ACCELERATE=ON"
    CMAKE_ARGS_EXTRA="${CMAKE_ARGS_EXTRA} -DOPENMP_RUNTIME=COMP"
elif [[ ${blas_impl:-} = "cublas" ]]; then
    # CUDA provides cublas; no separate BLAS needed
    CMAKE_ARGS_EXTRA="${CMAKE_ARGS_EXTRA} -DWITH_MKL=OFF -DWITH_OPENBLAS=OFF -DWITH_ACCELERATE=OFF"
    CMAKE_ARGS_EXTRA="${CMAKE_ARGS_EXTRA} -DOPENMP_RUNTIME=COMP"
else
    CMAKE_ARGS_EXTRA="${CMAKE_ARGS_EXTRA} -DWITH_MKL=OFF -DWITH_OPENBLAS=OFF -DWITH_ACCELERATE=OFF"
    CMAKE_ARGS_EXTRA="${CMAKE_ARGS_EXTRA} -DOPENMP_RUNTIME=COMP"
fi

cmake -S . -B build \
    -G Ninja \
    ${CMAKE_ARGS} \
    -DCMAKE_INSTALL_PREFIX=${PREFIX} \
    -DCMAKE_PREFIX_PATH=${PREFIX} \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=ON \
    -DBUILD_CLI=OFF \
    -DBUILD_TESTS=OFF \
    -DENABLE_CPU_DISPATCH=ON \
    -DWITH_DNNL=OFF \
    -DWITH_RUY=OFF \
    ${CMAKE_ARGS_EXTRA}

cmake --build build --config Release --parallel ${CPU_COUNT} --verbose
cmake --install build
