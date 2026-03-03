#!/bin/bash
set -ex

export CXXFLAGS="${CXXFLAGS} -Wno-write-strings -Wno-strict-aliasing -Wno-error=narrowing"

# 1. Handle SDK paths for macOS to prevent "header not found" errors
if [[ "$target_platform" == osx-* ]]; then
    export CMAKE_ARGS="${CMAKE_ARGS} -DCMAKE_OSX_SYSROOT=${CONDA_BUILD_SYSROOT}"
fi

# 2. Configure
cmake ${CMAKE_ARGS} \
      -DCMAKE_BUILD_TYPE=Release \
      -DMUMPS_DIR=$PREFIX \
      -DTCL_LIBRARY=$PREFIX/lib/libtcl8.6${SHLIB_EXT} \
      -DTCL_INCLUDE_PATH=$PREFIX/include \      
      -DOpenSees_ENABLE_MPI=ON \
      -DOpenSees_ENABLE_MUMPS=ON \
      -DCMAKE_CXX_FLAGS="$CXXFLAGS -fpermissive -isystem $PREFIX/include/eigen3" \
      -S . -B build

# 3. Build
cmake --build ./build --config Release --target OpenSees   --parallel $CPU_COUNT
cmake --build ./build --config Release --target OpenSeesPy --parallel $CPU_COUNT
cmake --build ./build --config Release --target OpenSeesSP --parallel $CPU_COUNT
cmake --build ./build --config Release --target OpenSeesMP --parallel $CPU_COUNT

# 4. Install
cmake --install ./build --verbose

# 5. Rename Python Module (OpenSeesPy -> opensees.so)
# We use SHLIB_EXT which is .dylib on Mac and .so on Linux
if [ -f "./build/OpenSeesPy${SHLIB_EXT}" ]; then
    cp "./build/OpenSeesPy${SHLIB_EXT}" "$SP_DIR/opensees.so"
elif [ -f "./build/lib/OpenSeesPy${SHLIB_EXT}" ]; then
    cp "./build/lib/OpenSeesPy${SHLIB_EXT}" "$SP_DIR/opensees.so"
fi

# 6. Ensure executables are in the bin folder
cp ./build/OpenSeesSP $PREFIX/bin/ || true
cp ./build/OpenSeesMP $PREFIX/bin/ || true