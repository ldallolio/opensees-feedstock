:: Remove read-only attributes natively on Windows
attrib -R SRC\*.* /S

:: Safely patch Fortran files with strict F77 sequence compliance
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
echo                 lines = c_new.splitlines() >> patch.py
echo                 insert_idx = -1 >> patch.py
echo                 for i in range(len(lines)): >> patch.py
echo                     line = lines[i] >> patch.py
echo                     # Skip comments and blank lines >> patch.py
echo                     if len(line) ^< 6 or line[0] in 'cC*!' or not line.strip(): continue >> patch.py
echo                     # Skip Fortran multi-line continuations >> patch.py
echo                     if len(line) ^>= 6 and line[5] not in ' 0\t': continue >> patch.py
echo                     stmt = line[6:].strip().lower() >> patch.py
echo                     # Skip headers and implicit statements to obey F77 sequence rules >> patch.py
echo                     if stmt.startswith('implicit'): continue >> patch.py
echo                     if stmt.startswith('subroutine') or stmt.startswith('function') or stmt.startswith('program'): continue >> patch.py
echo                     # The very first non-implicit statement found is our safe injection point >> patch.py
echo                     insert_idx = i >> patch.py
echo                     break >> patch.py
echo                 if insert_idx != -1 and 'integer mlsval' not in c_new.lower(): >> patch.py
echo                     lines.insert(insert_idx, '      integer mlsval') >> patch.py
echo                     c_new = '\n'.join(lines) + '\n' >> patch.py
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