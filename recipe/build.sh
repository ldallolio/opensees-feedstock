#!/bin/bash
set -ex

export CXXFLAGS="${CXXFLAGS} -Wno-write-strings -Wno-strict-aliasing -Wno-error=narrowing"

# Force the linker to globally search the Conda environment's lib directory
# This natively resolves the hardcoded "-ltcl8.6" OpenSees linker error
export LIBRARY_PATH="$PREFIX/lib:$LIBRARY_PATH"

export SHARED_LDFLAGS="${LDFLAGS}"

# 1. Handle SDK paths for macOS and exact library names
if [[ "$target_platform" == osx-* ]]; then
    export CMAKE_ARGS="${CMAKE_ARGS} -DCMAKE_OSX_SYSROOT=${CONDA_BUILD_SYSROOT}"
    export TCL_LIB_PATH="${PREFIX}/lib/libtcl8.6.dylib"
    export SCALAPACK_LIB_PATH="${PREFIX}/lib/libscalapack.dylib"
    export EXT=".dylib"
    
    # macOS requires undefined dynamic lookup for Python C-extensions
    export SHARED_LDFLAGS="${LDFLAGS} -undefined dynamic_lookup"
else
    export TCL_LIB_PATH="${PREFIX}/lib/libtcl8.6.so"
    export SCALAPACK_LIB_PATH="${PREFIX}/lib/libscalapack.so"
    export EXT=".so"
fi

# 2. Fix OpenSees hardcoded static MUMPS paths and Python double-linking
for mumps_lib in libdmumps libmumps_common libpord libsmumps libcmumps libzmumps; do
    if [[ "$target_platform" == osx-* ]]; then
        find . -type f -name "CMakeLists.txt" -exec sed -i '' "s/${mumps_lib}\.a/${mumps_lib}${EXT}/g" {} +
        # Fix macOS Python segfault by using the Module target instead of full Python
        find . -type f -name "CMakeLists.txt" -exec sed -i '' 's/Python3::Python/Python3::Module/g' {} +
    else
        find . -type f -name "CMakeLists.txt" -exec sed -i "s/${mumps_lib}\.a/${mumps_lib}${EXT}/g" {} +
        find . -type f -name "CMakeLists.txt" -exec sed -i 's/Python3::Python/Python3::Module/g' {} +
    fi
done

# 3. Configure
cmake ${CMAKE_ARGS} \
      -DCMAKE_BUILD_TYPE=Release \
      -DMUMPS_DIR=$PREFIX/lib \
      -DTCL_LIBRARY=$TCL_LIB_PATH \
      -DTCL_INCLUDE_PATH=$PREFIX/include \
      -DSCALAPACK_LIBRARIES=$SCALAPACK_LIB_PATH \
      -DCMAKE_CXX_FLAGS="$CXXFLAGS -fpermissive -isystem $PREFIX/include/eigen3" \
      -DCMAKE_EXE_LINKER_FLAGS="${LDFLAGS}" \
      -DCMAKE_SHARED_LINKER_FLAGS="${SHARED_LDFLAGS}" \
      -DCMAKE_MODULE_LINKER_FLAGS="${SHARED_LDFLAGS}" \
      -S . -B build

# 4. Build
cmake --build ./build --config Release --target OpenSees   --parallel $CPU_COUNT
cmake --build ./build --config Release --target OpenSeesPy --parallel $CPU_COUNT
cmake --build ./build --config Release --target OpenSeesSP --parallel $CPU_COUNT
cmake --build ./build --config Release --target OpenSeesMP --parallel $CPU_COUNT

# 5. Install
cmake --install ./build --verbose

# 6. Rename Python Module (OpenSeesPy -> opensees.so)
if [ -f "./build/OpenSeesPy.dylib" ]; then
    cp "./build/OpenSeesPy.dylib" "$SP_DIR/opensees.so"
elif [ -f "./build/OpenSeesPy.so" ]; then
    cp "./build/OpenSeesPy.so" "$SP_DIR/opensees.so"
elif [ -f "./build/lib/OpenSeesPy.dylib" ]; then
    cp "./build/lib/OpenSeesPy.dylib" "$SP_DIR/opensees.so"
elif [ -f "./build/lib/OpenSeesPy.so" ]; then
    cp "./build/lib/OpenSeesPy.so" "$SP_DIR/opensees.so"
fi

# 7. Ensure executables are in the bin folder
cp ./build/OpenSeesSP $PREFIX/bin/ || true
cp ./build/OpenSeesMP $PREFIX/bin/ || true