#!/bin/bash
set -ex

# Conda-build defines SHLIB_EXT (.so for Linux, .dylib for MacOS)
# However, Python modules on both MUST end in .so

# 1. Configure
# We add -DEIGEN3_INCLUDE_DIR to fix the Mac header issue mentioned in the instructions
cmake ${CMAKE_ARGS} \
      -DCMAKE_BUILD_TYPE=Release \
      -DMUMPS_DIR=$PREFIX \
      -DOPENMPI=TRUE \
      -DEIGEN3_INCLUDE_DIR=$PREFIX/include/eigen3 \
      -DCMAKE_CXX_FLAGS="$CXXFLAGS -fpermissive" \
      -S . -B build

# 2. Build
cmake --build ./build --config Release --target OpenSees   --parallel $CPU_COUNT
cmake --build ./build --config Release --target OpenSeesPy --parallel $CPU_COUNT

# 3. Install
cmake --install ./build

# 4. Manual Move/Rename per OpenSees Instructions
# The build results are usually in ./build/ or ./build/lib/
if [ -f "./build/OpenSeesPy${SHLIB_EXT}" ]; then
    cp "./build/OpenSeesPy${SHLIB_EXT}" "$SP_DIR/opensees.so"
elif [ -f "./build/lib/OpenSeesPy${SHLIB_EXT}" ]; then
    cp "./build/lib/OpenSeesPy${SHLIB_EXT}" "$SP_DIR/opensees.so"
fi