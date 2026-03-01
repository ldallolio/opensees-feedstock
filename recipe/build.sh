#!/bin/bash
set -ex

# Configure
# We use CMAKE_ARGS which contains many of the cross-platform 
# paths and flags provided by conda-forge.
cmake ${CMAKE_ARGS} \
      -DCMAKE_BUILD_TYPE=Release \
      -DMUMPS_DIR=$PREFIX/lib \
      -DOPENMPI=TRUE \
      -DCMAKE_CXX_FLAGS="$CXXFLAGS -fpermissive -isystem $PREFIX/include/eigen3" \
      -S . -B build

# Build all targets
cmake --build ./build --config Release --target OpenSees   --parallel $CPU_COUNT
cmake --build ./build --config Release --target OpenSeesPy --parallel $CPU_COUNT
cmake --build ./build --config Release --target OpenSeesSP --parallel $CPU_COUNT
cmake --build ./build --config Release --target OpenSeesMP --parallel $CPU_COUNT

# Install
cmake --install ./build --verbose

# Handle the Python module renaming
# We use the built-in $SHLIB_EXT to find what CMake produced (.so or .dylib)
# But we ALWAYS name the output opensees.so for the Python loader on Unix
if [ -f "./build/OpenSeesPy${SHLIB_EXT}" ]; then
    cp "./build/OpenSeesPy${SHLIB_EXT}" "$SP_DIR/opensees.so"
elif [ -f "./build/lib/OpenSeesPy${SHLIB_EXT}" ]; then
    cp "./build/lib/OpenSeesPy${SHLIB_EXT}" "$SP_DIR/opensees.so"
fi

# Ensure parallel executables are in bin
cp ./build/OpenSeesSP $PREFIX/bin/
cp ./build/OpenSeesMP $PREFIX/bin/