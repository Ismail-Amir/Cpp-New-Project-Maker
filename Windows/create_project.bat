@echo off
setlocal enabledelayedexpansion

:: C++ Project Initializer for Windows
:: Creates a cross-platform C++ project with CMake, vcpkg, Clangd, and VS Code support.
:: Usage: init_cpp_project.bat

:: Colors not supported in cmd, but we can use messages.
echo Checking prerequisites...

:: Prerequisite check
set MISSING_TOOLS=
where cmake >nul 2>&1 || set MISSING_TOOLS=%MISSING_TOOLS% cmake
where g++ >nul 2>&1   || set MISSING_TOOLS=%MISSING_TOOLS% g++
where clangd >nul 2>&1 || set MISSING_TOOLS=%MISSING_TOOLS% clangd
if "%VCPKG_ROOT%"=="" set MISSING_TOOLS=%MISSING_TOOLS% VCPKG_ROOT

if not "%MISSING_TOOLS%"=="" (
    echo ERROR: The following prerequisites are missing:
    echo %MISSING_TOOLS%
    exit /b 1
)
echo All prerequisites satisfied.

:: ----------------------------------------------------------------------
:: User input
:: ----------------------------------------------------------------------
echo Please provide the following information.

:: Project name
:prompt_project_name
set /p project_name="Project name (alphanumeric, underscore, hyphen only): "
echo %project_name%| findstr /r "^[a-zA-Z0-9_-]*$" >nul
if errorlevel 1 (
    echo ERROR: Invalid project name. Use only letters, numbers, underscore, or hyphen.
    goto prompt_project_name
)

:: Project location (default current directory)
set /p location="Location (default: current directory): "
if "%location%"=="" set location=.

:: Normalize and create project directory
set project_dir=%location%\%project_name%
if not exist "%location%" (
    echo ERROR: Parent directory "%location%" does not exist.
    exit /b 1
)
mkdir "%project_dir%" 2>nul
if errorlevel 1 (
    echo ERROR: Failed to create directory "%project_dir%". Check permissions.
    exit /b 1
)
echo Directory created: %project_dir%
cd /d "%project_dir%" || exit /b 1

:: Project type
echo Select project type:
echo   1) executable
echo   2) static library
echo   3) shared library
set /p type_choice="Choose (default: executable): "
if "%type_choice%"=="2" (set project_type=static) else if "%type_choice%"=="3" (set project_type=shared) else set project_type=executable
echo Project type: %project_type%

:: C++ standard
set /p cpp_std="C++ standard (17/20/23) [20]: "
if "%cpp_std%"=="" set cpp_std=20
echo %cpp_std%| findstr /r "^17$ ^20$ ^23$" >nul
if errorlevel 1 (
    echo Warning: Invalid standard. Using 20.
    set cpp_std=20
)

:: vcpkg integration
set vcpkg_integration=no
set vcpkg_mode=
set deps=
set /p vcpkg_choice="Integrate vcpkg? (y/n) [n]: "
if /i "%vcpkg_choice%"=="y" (
    set vcpkg_integration=yes
    echo Select vcpkg mode:
    echo   1) classic (toolchain only)
    echo   2) manifest (with vcpkg.json)
    set /p vcpkg_mode_choice="Choose (default: manifest): "
    if "%vcpkg_mode_choice%"=="1" (set vcpkg_mode=classic) else set vcpkg_mode=manifest
    set /p vcpkg_deps="List vcpkg dependencies (comma-separated, e.g. fmt,spdlog): "
    if not "!vcpkg_deps!"=="" (
        set "deps_list=!vcpkg_deps!"
        :: Split and trim (simple approach)
        set "deps="
        for %%i in ("!deps_list:,=" "!") do (
            set "dep=%%~i"
            if not "!dep!"=="" (
                if "!deps!"=="" (set "deps=!dep!") else (set "deps=!deps! !dep!")
            )
        )
    )
)

:: Unit tests
set include_tests=no
set /p tests_choice="Include a tests directory with a sample test? (y/n) [n]: "
if /i "%tests_choice%"=="y" set include_tests=yes

:: Git repository
set git_init=yes
set /p git_init_choice="Initialize a git repository? (y/n) [y]: "
if /i "%git_init_choice%"=="n" set git_init=no
if "%git_init%"=="yes" (
    where git >nul 2>&1 || (
        echo Warning: git not found. Skipping repository initialization.
        set git_init=no
    )
)

:: .gitignore
set add_gitignore=yes
set /p gitignore_choice="Add a .gitignore file? (y/n) [y]: "
if /i "%gitignore_choice%"=="n" set add_gitignore=no

:: README.md
set add_readme=yes
set /p readme_choice="Add a README.md file? (y/n) [y]: "
if /i "%readme_choice%"=="n" set add_readme=no

:: License file
set add_license=no
set /p license_choice="Add a license file (MIT)? (y/n) [n]: "
if /i "%license_choice%"=="y" set add_license=yes

:: VS Code settings
set add_vscode=no
set /p vscode_choice="Add VS Code workspace settings (for clangd)? (y/n) [n]: "
if /i "%vscode_choice%"=="y" set add_vscode=yes

:: .clang-format
set add_clangformat=no
set /p clangformat_choice="Add a .clang-format file (LLVM style)? (y/n) [n]: "
if /i "%clangformat_choice%"=="y" set add_clangformat=yes

:: ----------------------------------------------------------------------
:: Create directory structure
:: ----------------------------------------------------------------------
echo Creating directory structure...
mkdir src
if not "%project_type%"=="executable" mkdir include
if "%include_tests%"=="yes" if not "%project_type%"=="executable" mkdir tests
if "%add_vscode%"=="yes" mkdir .vscode

:: ----------------------------------------------------------------------
:: Generate source files
:: ----------------------------------------------------------------------
echo Generating source files...

if "%project_type%"=="executable" (
    :: src/main.cpp
    (
        echo #include ^<iostream^>
        echo.
        echo int main^(^) {
        echo     std::cout ^<^< "Hello from %project_name%!" ^<^< std::endl;
        echo     return 0;
        echo }
    ) > src\main.cpp
) else (
    :: include/library.hpp
    set lib_guard=%project_name%
    :: Convert to uppercase and replace non-alphanumeric with _
    set lib_guard=!lib_guard:-=_!
    set lib_guard=!lib_guard:^=_!  :: This is simplistic; for complex names we can use a loop, but assume simple.
    set lib_guard=!lib_guard!__HPP
    (
        echo #ifndef !lib_guard!
        echo #define !lib_guard!
        echo.
        echo namespace %project_name% {
        echo.
        echo void hello^(^);
        echo.
        echo } // namespace %project_name%
        echo.
        echo #endif // !lib_guard!
    ) > include\library.hpp

    :: src/library.cpp
    (
        echo #include "library.hpp"
        echo #include ^<iostream^>
        echo.
        echo namespace %project_name% {
        echo.
        echo void hello^(^) {
        echo     std::cout ^<^< "Hello from %project_name% library!" ^<^< std::endl;
        echo }
        echo.
        echo } // namespace %project_name%
    ) > src\library.cpp
)

:: Sample test
if "%include_tests%"=="yes" if not "%project_type%"=="executable" (
    (
        echo #include "library.hpp"
        echo.
        echo int main^(^) {
        echo     %project_name%::hello^(^);
        echo     return 0;
        echo }
    ) > tests\test_library.cpp
)

:: ----------------------------------------------------------------------
:: Generate CMakeLists.txt
:: ----------------------------------------------------------------------
echo Generating CMakeLists.txt...

:: Build find_package lines and target link libraries
set find_packages=
set target_libs=
if "%vcpkg_integration%"=="yes" if not "%deps%"=="" (
    for %%d in (%deps%) do (
        set find_packages=!find_packages!find_package(%%d REQUIRED)
        set target_libs=!target_libs!    %%d::%%d
    )
)

:: Determine target type and source files
if "%project_type%"=="executable" (
    set target_cmd=add_executable(${PROJECT_NAME} src/main.cpp)
    if not "!target_libs!"=="" (
        set link_cmd=target_link_libraries(${PROJECT_NAME} PRIVATE
        set link_cmd=!link_cmd!!target_libs!^)
    ) else set link_cmd=
) else (
    if "%project_type%"=="shared" (set lib_type=SHARED) else set lib_type=STATIC
    set target_cmd=add_library(${PROJECT_NAME} !lib_type! src/library.cpp)
    set include_cmd=target_include_directories(${PROJECT_NAME} PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include)
    if not "!target_libs!"=="" (
        set link_cmd=target_link_libraries(${PROJECT_NAME} PRIVATE
        set link_cmd=!link_cmd!!target_libs!^)
    ) else set link_cmd=
)

:: Build tests
set tests_cmd=
if "%include_tests%"=="yes" (
    if "%project_type%"=="executable" (
        set tests_cmd=enable_testing()^
 add_test(NAME ${PROJECT_NAME}_test COMMAND $<TARGET_FILE:${PROJECT_NAME}>^)
    ) else (
        set tests_cmd=add_executable(${PROJECT_NAME}_test tests/test_library.cpp)^
 target_link_libraries(${PROJECT_NAME}_test PRIVATE ${PROJECT_NAME})^
 enable_testing()^
 add_test(NAME ${PROJECT_NAME}_test COMMAND ${PROJECT_NAME}_test^)
    )
)

:: Write CMakeLists.txt
(
    echo cmake_minimum_required(VERSION 3.15^)
    echo project(%project_name% VERSION 0.1.0 LANGUAGES CXX^)
    echo.
    echo # C++ standard
    echo set(CMAKE_CXX_STANDARD %cpp_std%^)
    echo set(CMAKE_CXX_STANDARD_REQUIRED ON^)
    echo set(CMAKE_EXPORT_COMPILE_COMMANDS ON^)
    echo.
    echo # Find dependencies
    echo %find_packages%
    echo # Main target
    echo %target_cmd%
    echo.
    if defined include_cmd echo %include_cmd%
    echo.
    if defined link_cmd echo %link_cmd%
    echo.
    echo # Tests
    echo %tests_cmd%
    echo.
    if "%add_vscode%"=="yes" (
        echo # ----------------------------------------------------------------------
        echo # Clangd support: generate .clangd file pointing to current build dir
        echo # ----------------------------------------------------------------------
        echo configure_file(${CMAKE_CURRENT_SOURCE_DIR}/.clangd.in ${CMAKE_CURRENT_SOURCE_DIR}/.clangd @ONLY^)
    )
) > CMakeLists.txt

:: ----------------------------------------------------------------------
:: Generate CMakePresets.json
:: ----------------------------------------------------------------------
echo Generating CMakePresets.json...

set base_cache={\
      "name": "base",\
      "hidden": true,\
      "binaryDir": "${sourceDir}/build/${presetName}",\
      "cacheVariables": {\
        "CMAKE_CXX_STANDARD": "%cpp_std%",\
        "CMAKE_CXX_STANDARD_REQUIRED": "ON",\
        "CMAKE_EXPORT_COMPILE_COMMANDS": "ON"

if "%vcpkg_integration%"=="yes" (
    set base_cache=!base_cache!,\
        "CMAKE_TOOLCHAIN_FILE": "$env{VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake"
)

set base_cache=!base_cache!\
      }\
    }

set configure_presets=[%base_cache%,

for %%o in (windows linux macos) do (
    for %%c in (Debug Release) do (
        if "%%o"=="windows" set condition={ "type": "equals", "lhs": "${hostSystemName}", "rhs": "Windows" }
        if "%%o"=="linux"   set condition={ "type": "equals", "lhs": "${hostSystemName}", "rhs": "Linux" }
        if "%%o"=="macos"   set condition={ "type": "equals", "lhs": "${hostSystemName}", "rhs": "Darwin" }
        set preset_name=%%o-%%c
        set preset_name=!preset_name:Debug=debug!
        set preset_name=!preset_name:Release=release!
        set configure_presets=!configure_presets!^
  {^
    "name": "!preset_name!",^
    "inherits": "base",^
    "condition": !condition!,^
    "cacheVariables": {^
      "CMAKE_BUILD_TYPE": "%%c"^
    }^
  },
    )
)
set configure_presets=%configure_presets:~0,-1%]

set build_presets=[
for %%o in (windows linux macos) do (
    for %%c in (Debug Release) do (
        set preset_name=%%o-%%c
        set preset_name=!preset_name:Debug=debug!
        set preset_name=!preset_name:Release=release!
        set build_presets=!build_presets!^
  {^
    "name": "!preset_name!",^
    "configurePreset": "!preset_name!"^
  },
    )
)
set build_presets=%build_presets:~0,-1%]

(
    echo {^^
  "version": 3,^^
  "configurePresets": %configure_presets%,^^
  "buildPresets": %build_presets%^^
}
) > CMakePresets.json

:: ----------------------------------------------------------------------
:: Generate vcpkg.json if manifest mode
:: ----------------------------------------------------------------------
if "%vcpkg_integration%"=="yes" if "%vcpkg_mode%"=="manifest" (
    echo Generating vcpkg.json...
    if not "%deps%"=="" (
        set deps_json=
        for %%d in (%deps%) do (
            set deps_json=!deps_json!    { "name": "%%d" },
        )
        set deps_json=[!deps_json:~0,-1!]
    ) else set deps_json=[]
    (
        echo {^^
  "name": "%project_name%",^^
  "version": "0.1.0",^^
  "dependencies": %deps_json%^^
}
    ) > vcpkg.json
)

:: ----------------------------------------------------------------------
:: Generate build scripts
:: ----------------------------------------------------------------------
echo Generating build scripts...

:: build.bat (Windows) - we are already in a .bat, but we generate one for user
(
    echo @echo off
    echo set os=windows
    echo for %%%%c in ^(debug release^) do ^(
    echo     echo Configuring with preset: %%os%%-%%%%c
    echo     cmake --preset %%os%%-%%%%c
    echo     echo Building %%%%c...
    echo     cmake --build --preset %%os%%-%%%%c
    echo ^)
) > build.bat

:: build.sh (Unix) - optional, but we generate it anyway
(
    echo #!/bin/bash
    echo OS=$(uname -s^)
    echo case "$OS" in
    echo     Linux^*^)     os=linux ;;
    echo     Darwin^*^)    os=macos ;;
    echo     *^)          echo "Unsupported OS: $OS"; exit 1 ;;
    echo esac
    echo.
    echo for config in debug release; do
    echo     preset="${os}-${config}"
    echo     echo "Configuring with preset: $preset"
    echo     cmake --preset $preset
    echo     echo "Building $config..."
    echo     cmake --build --preset $preset
    echo done
) > build.sh

:: ----------------------------------------------------------------------
:: Generate .gitignore
:: ----------------------------------------------------------------------
if "%add_gitignore%"=="yes" (
    echo Generating .gitignore...
    (
        echo # Build directories
        echo build/
        echo */build/
        echo CMakeFiles/
        echo CMakeCache.txt
        echo cmake_install.cmake
        echo Makefile
        echo *.cmake
        echo.
        echo # Compiled files
        echo *.o
        echo *.obj
        echo *.exe
        echo *.dll
        echo *.so
        echo *.dylib
        echo *.a
        echo *.lib
        echo.
        echo # IDE
        echo .vscode/
        echo .idea/
        echo *.swp
        echo *.swo
        echo *~
        echo.
        echo # vcpkg
        echo vcpkg_installed/
        echo.
        echo # clangd generated file
        echo .clangd
    ) > .gitignore
)

:: ----------------------------------------------------------------------
:: Generate README.md
:: ----------------------------------------------------------------------
if "%add_readme%"=="yes" (
    echo Generating README.md...
    (
        echo # %project_name%
        echo.
        echo A C++ project generated with the C++ Project Initializer.
        echo.
        echo ## Features
        echo - CMake build system
        echo - Cross-platform support (Windows, Linux, macOS^)
        echo - vcpkg for dependency management
        echo - Clangd LSP support
        echo - VS Code integration
        echo.
        echo ## Building
        echo ### Linux / macOS
        echo Run the build script:
        echo ````
        echo ./build.sh
        echo ````
        echo.
        echo ### Windows
        echo Run the batch file:
        echo ````
        echo build.bat
        echo ````
        echo.
        echo Alternatively, use CMake directly:
        echo ````
        echo cmake --preset ^<preset^>
        echo cmake --build --preset ^<preset^>
        echo ````
        echo Available presets: `windows-debug`, `windows-release`, `linux-debug`, `linux-release`, `macos-debug`, `macos-release`.
        echo.
        echo ## Dependencies
        if "%vcpkg_integration%"=="yes" (echo Managed via vcpkg.) else (echo No external dependencies (vcpkg not used^).)
        echo.
        echo ## License
        if "%add_license%"=="yes" (echo MIT License. See LICENSE file.) else (echo No license specified.)
    ) > README.md
)

:: ----------------------------------------------------------------------
:: Generate LICENSE (MIT)
:: ----------------------------------------------------------------------
if "%add_license%"=="yes" (
    echo Generating LICENSE (MIT^)...
    for /f %%i in ('wmic os get localdatetime ^| find "."') do set datetime=%%i
    set year=%datetime:~0,4%
    (
        echo MIT License
        echo.
        echo Copyright (c^) %year% %project_name%
        echo.
        echo Permission is hereby granted, free of charge, to any person obtaining a copy
        echo of this software and associated documentation files (the "Software"^), to deal
        echo in the Software without restriction, including without limitation the rights
        echo to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
        echo copies of the Software, and to permit persons to whom the Software is
        echo furnished to do so, subject to the following conditions:
        echo.
        echo The above copyright notice and this permission notice shall be included in all
        echo copies or substantial portions of the Software.
        echo.
        echo THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
        echo IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
        echo FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
        echo AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
        echo LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
        echo OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
        echo SOFTWARE.
    ) > LICENSE
)

:: ----------------------------------------------------------------------
:: Generate .clang-format
:: ----------------------------------------------------------------------
if "%add_clangformat%"=="yes" (
    echo Generating .clang-format (LLVM style^)...
    (
        echo BasedOnStyle: LLVM
        echo IndentWidth: 4
        echo UseTab: Never
        echo BreakBeforeBraces: Allman
        echo AllowShortFunctionsOnASingleLine: None
    ) > .clang-format
)

:: ----------------------------------------------------------------------
:: Generate .clangd.in template (if VS Code settings enabled)
:: ----------------------------------------------------------------------
if "%add_vscode%"=="yes" (
    echo Generating .clangd.in template...
    (
        echo # This file is generated by CMake. Do not edit manually.
        echo # It tells clangd where to find the compilation database for the current build.
        echo CompileFlags:
        echo   CompilationDatabase: @CMAKE_BINARY_DIR@
    ) > .clangd.in
)

:: ----------------------------------------------------------------------
:: Generate VS Code settings (including CMake Tools default target)
:: ----------------------------------------------------------------------
if "%add_vscode%"=="yes" (
    echo Generating .vscode\settings.json...
    (
        echo {^^
    "C_Cpp.intelliSenseEngine": "disabled",^^
    "clangd.path": "clangd",^^
    "clangd.arguments": [^^
        "--background-index",^^
        "--clang-tidy"^^
    ],^^
    "files.associations": {^^
        "*.cpp": "cpp",^^
        "*.hpp": "cpp"^^
    },^^
    "cmake.defaultTarget": "%project_name%",^^
    "cmake.buildBeforeRun": true^^
}
    ) > .vscode\settings.json
)

:: ----------------------------------------------------------------------
:: Classic mode: check if dependencies are installed and offer to install
:: ----------------------------------------------------------------------
if "%vcpkg_integration%"=="yes" if "%vcpkg_mode%"=="classic" if not "%deps%"=="" (
    echo Checking vcpkg classic mode dependencies...
    :: Locate vcpkg executable
    set VCPKG_CMD=
    if exist "%VCPKG_ROOT%\vcpkg.exe" set VCPKG_CMD="%VCPKG_ROOT%\vcpkg.exe"
    if "!VCPKG_CMD!"=="" (
        where vcpkg >nul 2>&1 && set VCPKG_CMD=vcpkg
    )
    if not defined VCPKG_CMD (
        echo Warning: vcpkg executable not found. Cannot verify dependencies.
    ) else (
        :: Get installed packages (simplified)
        set installed=
        for /f "tokens=1" %%i in ('!VCPKG_CMD! list') do set installed=!installed! %%i
        set missing_deps=
        for %%d in (%deps%) do (
            echo !installed! | findstr /i " %%d " >nul || set missing_deps=!missing_deps! %%d
        )
        if not "!missing_deps!"=="" (
            echo Warning: The following vcpkg dependencies are not installed: !missing_deps!
            set /p install_choice="Install them now? (y/n): "
            if /i "!install_choice!"=="y" (
                for %%d in (!missing_deps!) do (
                    echo Installing %%d...
                    !VCPKG_CMD! install %%d || echo ERROR: Failed to install %%d
                )
            ) else (
                echo Warning: Dependencies not installed. Build may fail.
            )
        ) else (
            echo All vcpkg dependencies are already installed.
        )
    )
)

:: ----------------------------------------------------------------------
:: Git initialization
:: ----------------------------------------------------------------------
if "%git_init%"=="yes" (
    echo Initializing git repository...
    git init >nul 2>&1
    git add . >nul 2>&1
    git commit -m "Initial commit: C++ project structure" >nul 2>&1
    echo Git repository initialized and initial commit created.
)

:: ----------------------------------------------------------------------
:: Final message
:: ----------------------------------------------------------------------
echo.
echo SUCCESS: Project '%project_name%' successfully created at: %project_dir%
echo Next steps:
echo   cd /d "%project_dir%"
if "%vcpkg_integration%"=="yes" if "%vcpkg_mode%"=="manifest" if not "%deps%"=="" (
    echo   vcpkg install (if not using manifest mode automatically^)
)
echo   build.bat   (on Windows^) or .\build.sh (on Linux/macOS^)
echo   code .       (to open in VS Code^)

endlocal
