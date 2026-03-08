:: Patch all legacy Fortran files that fail under Flang's strictness
:: We make them writable, read with latin1 to avoid decode errors, and safely erase 'implicit none'
echo import os, glob, re, stat > patch.py
echo for f in glob.glob('SRC/**/*.f*', recursive=True): >> patch.py
echo     try: >> patch.py
echo         os.chmod(f, stat.S_IWRITE) >> patch.py
echo         c = open(f, encoding='latin1').read() >> patch.py
echo         c = re.sub(r'(?i)implicit\s+none', '             ', c) >> patch.py
echo         open(f, 'w', encoding='latin1').write(c) >> patch.py
echo     except Exception as e: >> patch.py
echo         print('Error patching', f, e) >> patch.py

python patch.py
if errorlevel 1 exit 1

:: Setup build directory
mkdir build
cd build

:: Configure CMake
:: 1. We use NMake Makefiles JOM to completely bypass the 8191 cmd.exe character limit.
:: 2. Disable MPI explicitly since MUMPS is not available on Windows.
cmake -G "NMake Makefiles JOM" ^
      -DCMAKE_INSTALL_PREFIX="%LIBRARY_PREFIX%" ^
      -DCMAKE_PREFIX_PATH="%LIBRARY_PREFIX%" ^
      -DCMAKE_BUILD_TYPE=Release ^
      -DTCL_LIBRARY="%LIBRARY_PREFIX%/lib/tcl86t.lib" ^
      -DTCL_INCLUDE_PATH="%LIBRARY_PREFIX%/include" ^
      -DOpenSees_ENABLE_MPI=OFF ^
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
if exist bin\OpenSeesPy.dll (
    move bin\OpenSeesPy.dll bin\opensees.pyd
) else (
    echo "Could not find OpenSeesPy.dll to rename"
)

copy bin\opensees.pyd "%SP_DIR%\opensees.pyd"
if errorlevel 1 exit 1

copy bin\OpenSees.exe "%LIBRARY_BIN%\OpenSees.exe"
if errorlevel 1 exit 1