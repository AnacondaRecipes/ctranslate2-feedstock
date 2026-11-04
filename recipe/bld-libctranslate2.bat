@echo off
setlocal EnableDelayedExpansion

REM Unvendor nlohmann/json: build and install against the nlohmann_json package
rmdir /s /q include\nlohmann
if exist include\nlohmann exit 1

set CMAKE_ARGS_EXTRA=

REM --- GPU selection ---
if "%gpu_variant:~0,5%"=="cuda-" (
    set CMAKE_ARGS_EXTRA=!CMAKE_ARGS_EXTRA! -DWITH_CUDA=ON -DWITH_CUDNN=ON -DCUDA_DYNAMIC_LOADING=ON
    REM CCCL 2.x headers use complex variadic macros requiring MSVC conformant preprocessor
    set "CXXFLAGS=!CXXFLAGS! /Zc:preprocessor /DNOMINMAX"
    REM Upstream's default CUDA_ARCH_LIST=Auto builds only the CI worker's GPU; see build-libctranslate2.sh
    if "%cuda_compiler_version:~0,3%"=="12." (
        set "CT2_CUDA_ARCHS=5.0;6.0;6.1;7.0;7.5;8.0;8.6;8.9;9.0+PTX"
    ) else (
        set "CT2_CUDA_ARCHS=7.5;8.0;8.6;8.9;9.0+PTX"
    )
    set "CT2_NVCC_FLAGS=-Xcompiler=/Zc:preprocessor;-Xfatbin=-compress-all;-gencode=arch=compute_100,code=sm_100;-gencode=arch=compute_120,code=sm_120"
    REM FindCUDA links the static CUDA runtime by default; use the shared one from cuda-cudart
    set CMAKE_ARGS_EXTRA=!CMAKE_ARGS_EXTRA! "-DCUDA_ARCH_LIST=!CT2_CUDA_ARCHS!" "-DCUDA_NVCC_FLAGS=!CT2_NVCC_FLAGS!" -DCUDA_USE_STATIC_CUDA_RUNTIME=OFF
) else (
    set CMAKE_ARGS_EXTRA=!CMAKE_ARGS_EXTRA! -DWITH_CUDA=OFF -DWITH_CUDNN=OFF
)

REM --- BLAS selection ---
if "%blas_impl%"=="mkl" (
    set "MKLROOT=%LIBRARY_PREFIX%"
    set CMAKE_ARGS_EXTRA=!CMAKE_ARGS_EXTRA! -DWITH_MKL=ON -DWITH_OPENBLAS=OFF -DWITH_ACCELERATE=OFF
    set CMAKE_ARGS_EXTRA=!CMAKE_ARGS_EXTRA! -DOPENMP_RUNTIME=INTEL
) else if "%blas_impl%"=="openblas" (
    set CMAKE_ARGS_EXTRA=!CMAKE_ARGS_EXTRA! -DWITH_MKL=OFF -DWITH_OPENBLAS=ON -DWITH_ACCELERATE=OFF
    set CMAKE_ARGS_EXTRA=!CMAKE_ARGS_EXTRA! -DOPENMP_RUNTIME=COMP
) else if "%blas_impl%"=="cublas" (
    set CMAKE_ARGS_EXTRA=!CMAKE_ARGS_EXTRA! -DWITH_MKL=OFF -DWITH_OPENBLAS=OFF -DWITH_ACCELERATE=OFF
    set CMAKE_ARGS_EXTRA=!CMAKE_ARGS_EXTRA! -DOPENMP_RUNTIME=COMP
) else (
    set CMAKE_ARGS_EXTRA=!CMAKE_ARGS_EXTRA! -DWITH_MKL=OFF -DWITH_OPENBLAS=OFF -DWITH_ACCELERATE=OFF
    set CMAKE_ARGS_EXTRA=!CMAKE_ARGS_EXTRA! -DOPENMP_RUNTIME=COMP
)

cmake -S . -B build ^
    -G Ninja ^
    %CMAKE_ARGS% ^
    -DCMAKE_INSTALL_PREFIX=%LIBRARY_PREFIX% ^
    -DCMAKE_PREFIX_PATH=%LIBRARY_PREFIX% ^
    -DCMAKE_LIBRARY_PATH=%LIBRARY_LIB% ^
    -DCMAKE_BUILD_TYPE=Release ^
    -DBUILD_SHARED_LIBS=ON ^
    -DBUILD_CLI=OFF ^
    -DBUILD_TESTS=OFF ^
    -DENABLE_CPU_DISPATCH=ON ^
    -DWITH_DNNL=OFF ^
    -DWITH_RUY=OFF ^
    !CMAKE_ARGS_EXTRA!
if errorlevel 1 exit 1

cmake --build build --config Release --parallel %CPU_COUNT% --verbose
if errorlevel 1 exit 1

cmake --install build
if errorlevel 1 exit 1
