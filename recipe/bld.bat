:: Setup build directory
mkdir build
cd build

:: Configure CMake
:: We use Ninja for faster builds on Windows
:: We point MUMPS and TCL to the Conda Library Prefix
cmake -G "Ninja" ^
      -DCMAKE_INSTALL_PREFIX=%LIBRARY_PREFIX% ^
      -DCMAKE_PREFIX_PATH=%LIBRARY_PREFIX% ^
      -DCMAKE_BUILD_TYPE=Release ^
      -DTCL_LIBRARY=%LIBRARY_PREFIX%/lib/tcl86t.lib ^
      -DTCL_INCLUDE_PATH=%LIBRARY_PREFIX%/include ^
      -DOPENMPI=FALSE ^
      -DMSMPI=TRUE ^
      -DOpenSees_ENABLE_MUMPS=OFF ^
      -DCMAKE_CXX_FLAGS="/EHsc /w" ^
      ..

if errorlevel 1 exit 1

:: Build targets
cmake --build . --config Release --target OpenSees   --parallel %CPU_COUNT%
if errorlevel 1 exit 1

cmake --build . --config Release --target OpenSeesPy --parallel %CPU_COUNT%
if errorlevel 1 exit 1

cmake --build . --config Release --target OpenSeesSP --parallel %CPU_COUNT%
if errorlevel 1 exit 1

cmake --build . --config Release --target OpenSeesMP --parallel %CPU_COUNT%
if errorlevel 1 exit 1

:: Install Step
cmake --install . --verbose
if errorlevel 1 exit 1

:: --- Post-Build Fixes per Instructions ---

:: 1. Rename OpenSeesPy.dll to opensees.pyd
:: The build likely placed it in bin/ or lib/; we must find it.
if exist bin\OpenSeesPy.dll (
    move bin\OpenSeesPy.dll bin\opensees.pyd
) else (
    echo "Could not find OpenSeesPy.dll to rename"
)

:: 2. Move opensees.pyd to the Python Site-Packages directory
:: This allows 'import opensees' to work without PYTHONPATH hacks
copy bin\opensees.pyd %SP_DIR%\opensees.pyd
if errorlevel 1 exit 1

:: 3. Move Executables to standard Conda Bin location
:: (CMake install usually handles this, but ensuring they are in Scripts or Library/bin)
copy bin\OpenSees.exe %LIBRARY_BIN%\OpenSees.exe
copy bin\OpenSeesSP.exe %LIBRARY_BIN%\OpenSeesSP.exe
copy bin\OpenSeesMP.exe %LIBRARY_BIN%\OpenSeesMP.exe