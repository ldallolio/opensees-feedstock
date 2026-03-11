:: Remove read-only attributes natively on Windows
attrib -R SRC\*.* /S

:: Safely patch Fortran files with strict F77 sequence compliance
echo import os, re, sys > patch.py
echo for root, dirs, files in os.walk('SRC'): >> patch.py
echo     for file in files: >> patch.py
echo         if file.lower().endswith(('.f', '.f90', '.f77', '.for')): >> patch.py
echo             f_path = os.path.join(root, file) >> patch.py
echo             with open(f_path, 'r', encoding='latin1') as f: >> patch.py
echo                 lines = f.readlines() >> patch.py
echo             modified = False >> patch.py
echo             for i in range(len(lines)): >> patch.py
echo                 if re.search(r'(?i)implicit\s+none', lines[i]): >> patch.py
echo                     lines[i] = re.sub(r'(?i)implicit\s+none', '             ', lines[i]) >> patch.py
echo                     modified = True >> patch.py
echo                 if re.search(r'(?i)implicit\s+undefined', lines[i]): >> patch.py
echo                     lines[i] = re.sub(r'(?i)implicit\s+undefined', '                  ', lines[i]) >> patch.py
echo                     modified = True >> patch.py
echo             if file.lower() == 'c14-sk-m.f' and not any('integer mlsval' in l.lower() for l in lines): >> patch.py
echo                 in_sub = False >> patch.py
echo                 for i in range(len(lines)): >> patch.py
echo                     low = lines[i].lower() >> patch.py
echo                     if 'subroutine nlu014' in low: >> patch.py
echo                         in_sub = True >> patch.py
echo                     if in_sub: >> patch.py
echo                         if not low.strip() or low.startswith('c') or low.startswith('*') or low.strip().startswith('!'): >> patch.py
echo                             continue >> patch.py
echo                         if 'subroutine' in low: >> patch.py
echo                             continue >> patch.py
echo                         if len(low) ^> 5 and low[5] not in ' 0\t\n\r': >> patch.py
echo                             continue >> patch.py
echo                         if low.strip().startswith('implicit'): >> patch.py
echo                             continue >> patch.py
echo                         ending = '\r\n' if lines[i].endswith('\r\n') else '\n' >> patch.py
echo                         lines.insert(i, '      integer mlsval' + ending) >> patch.py
echo                         modified = True >> patch.py
echo                         break >> patch.py
echo             if modified: >> patch.py
echo                 with open(f_path, 'w', encoding='latin1') as f: >> patch.py
echo                     f.writelines(lines) >> patch.py
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