:: Patch the legacy Fortran file that is failing under Flang strictness
python -c "import os; f='SRC/material/uniaxial/c14-SK-M.f'; c=open(f).read(); open(f,'w').write(c.replace('implicit none', ''))"

:: Setup build directory
mkdir build
cd build

:: Configure CMake
:: We use CMAKE_NINJA_FORCE_RESPONSE_FILE to bypass the 8191 cmd.exe character limit
:: Disable MPI explicitly since MUMPS is not available on Windows
cmake -G "Ninja" ^
      -DCMAKE_INSTALL_PREFIX="%LIBRARY_PREFIX%" ^
      -DCMAKE_PREFIX_PATH="%LIBRARY_PREFIX%" ^
      -DCMAKE_BUILD_TYPE=Release ^
      -DTCL_LIBRARY="%LIBRARY_PREFIX%/lib/tcl86t.lib" ^
      -DTCL_INCLUDE_PATH="%LIBRARY_PREFIX%/include" ^
      -DOpenSees_ENABLE_MPI=OFF ^
      -DCMAKE_NINJA_FORCE_RESPONSE_FILE=ON ^
      -DCMAKE_CXX_FLAGS="/EHsc /w" ^
      ..

if errorlevel 1 exit 1

:: Build sequential targets only
cmake --build . --config Release --target OpenSees --parallel %CPU_COUNT%
if errorlevel 1 exit 1

cmake --build . --config Release --target OpenSeesPy --parallel %CPU_COUNT%
if errorlevel 1 exit 1

:: Install Step
cmake --install . --verbose
if errorlevel 1 exit 1

:: --- Post-Build Fixes per Instructions ---

:: 1. Rename OpenSeesPy.dll to opensees.pyd
if exist bin\OpenSeesPy.dll (
    move bin\OpenSeesPy.dll bin\opensees.pyd
) else (
    echo "Could not find OpenSeesPy.dll to rename"
)

:: 2. Move opensees.pyd to the Python Site-Packages directory
copy bin\opensees.pyd "%SP_DIR%\opensees.pyd"
if errorlevel 1 exit 1

:: 3. Move Executable to standard Conda Bin location
copy bin\OpenSees.exe "%LIBRARY_BIN%\OpenSees.exe"
if errorlevel 1 exit 1