:: Remove read-only attributes natively on Windows
attrib -R SRC\*.* /S

:: Safely patch Fortran files
echo import os, re > patch.py
echo for root, dirs, files in os.walk('SRC'): >> patch.py
echo     for file in files: >> patch.py
echo         if file.lower().endswith(('.f', '.f90', '.f77', '.for')): >> patch.py
echo             f_path = os.path.join(root, file) >> patch.py
echo             with open(f_path, 'r', encoding='latin1') as f: >> patch.py
echo                 c = f.read() >> patch.py
echo             c_new = re.sub(r'(?i)implicit\s+none', '             ', c) >> patch.py
echo             c_new = re.sub(r'(?i)implicit\s+undefined', '                  ', c_new) >> patch.py
echo             if file.lower() == 'c14-sk-m.f': >> patch.py
echo                 if 'integer mlsval' not in c_new.lower(): >> patch.py
echo                     # Find the LAST implicit statement, or fallback to subroutine >> patch.py
echo                     idx = c_new.lower().rfind('implicit ') >> patch.py
echo                     if idx == -1: >> patch.py
echo                         idx = c_new.lower().find('subroutine ') >> patch.py
echo                     if idx != -1: >> patch.py
echo                         idx_nl = c_new.find('\n', idx) >> patch.py
echo                         # Skip over any Fortran 77 multi-line continuations (character in column 6) >> patch.py
echo                         while idx_nl != -1: >> patch.py
echo                             chars = c_new[idx_nl+1:idx_nl+7] >> patch.py
echo                             if len(chars) == 6 and chars.startswith('     ') and chars[5] not in ' \r\n0': >> patch.py
echo                                 idx_nl = c_new.find('\n', idx_nl+1) >> patch.py
echo                             else: >> patch.py
echo                                 break >> patch.py
echo                         if idx_nl != -1: >> patch.py
echo                             c_new = c_new[:idx_nl+1] + '      integer mlsval\n' + c_new[idx_nl+1:] >> patch.py
echo             if c != c_new: >> patch.py
echo                 with open(f_path, 'w', encoding='latin1') as f: >> patch.py
echo                     f.write(c_new) >> patch.py
echo                 print('Patched', f_path) >> patch.py

:: Execute the patch
python patch.py
if errorlevel 1 exit 1

:: Setup build directory
mkdir build
cd build

:: Configure CMake
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

:: Build parallel targets again for speed
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