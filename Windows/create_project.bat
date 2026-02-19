@echo off
setlocal enabledelayedexpansion

rem Use ANSI colors if supported (Windows 10+)
for /F "tokens=1,2 delims=#" %%a in ('"prompt #$H#$E# & echo on & for %%b in (1) do rem"') do set "ESC=%%b"
if defined ESC (
    set "RED=!ESC![31m"
    set "GREEN=!ESC![32m"
    set "YELLOW=!ESC![33m"
    set "NC=!ESC![0m"
) else (
    rem fallback: no colors
    set "RED="
    set "GREEN="
    set "YELLOW="
    set "NC="
)

echo %YELLOW%Checking prerequisites...%NC%

set missing=0

rem Check cmake
where cmake >nul 2>nul
if errorlevel 1 (
    echo %RED%Error: cmake not found in PATH.%NC%
    set missing=1
)

rem Check clangd
where clangd >nul 2>nul
if errorlevel 1 (
    echo %RED%Error: clangd not found in PATH.%NC%
    set missing=1
)

rem Check g++
where g++ >nul 2>nul
if errorlevel 1 (
    echo %RED%Error: g++ not found in PATH.%NC%
    set missing=1
)

rem Check VCPKG_ROOT
if not defined VCPKG_ROOT (
    echo %RED%Error: VCPKG_ROOT environment variable is not set.%NC%
    set missing=1
) else (
    if not exist "%VCPKG_ROOT%" (
        echo %RED%Error: VCPKG_ROOT points to a non-existent directory.%NC%
        set missing=1
    )
)

if %missing% neq 0 (
    echo %RED%Missing one or more prerequisites. Aborting.%NC%
    exit /b 1
)
echo %GREEN%All prerequisites satisfied.%NC%
echo.

rem Get project name
set /p project_name="Enter the name of the new project: "
if "%project_name%"=="" (
    echo %RED%Project name cannot be empty.%NC%
    exit /b 1
)

rem Get project location
set /p project_location="Enter the location for the project (press Enter for current directory): "
if "%project_location%"=="" set project_location=.

rem Create target directory if it doesn't exist
if not exist "%project_location%" mkdir "%project_location%" 2>nul
if errorlevel 1 (
    echo %RED%Cannot create or access directory '%project_location%'.%NC%
    exit /b 1
)

pushd "%project_location%" || exit /b 1
set "project_path=%CD%\%project_name%"

if exist "%project_path%" (
    echo %RED%A file or folder named '%project_name%' already exists in this location.%NC%
    popd
    exit /b 1
)

mkdir "%project_path%"
if errorlevel 1 (
    echo %RED%Failed to create project directory (permission denied?).%NC%
    popd
    exit /b 1
)

cd "%project_path%"
echo %GREEN%Project directory created at %CD%%NC%

rem Create src\main.cpp
mkdir src
> src\main.cpp (
echo #include ^<iostream^>
echo.
echo int main^(^) {
echo     std::cout ^<^< "Hello, World!" ^<^< std::endl;
echo     return 0;
echo }
)

rem Create CMakeLists.txt (using ${PROJECT_NAME} for the executable)
> CMakeLists.txt (
echo cmake_minimum_required(VERSION 3.23^)
echo.
echo project(%project_name% LANGUAGES CXX^)
echo.
echo # Enforced already by preset, but good practice:
echo set(CMAKE_CXX_STANDARD 20^)
echo set(CMAKE_CXX_STANDARD_REQUIRED ON^)
echo.
echo # Add executable
echo add_executable(${PROJECT_NAME}
echo     src/main.cpp
echo ^)
echo.
echo # Link wxWidgets - using the imported target
echo # target_link_libraries(${PROJECT_NAME} PRIVATE wx::core^)
)

rem Create CMakePresets.json (unchanged)
> CMakePresets.json (
echo {^
    "version": 6,^
    "cmakeMinimumRequired": {^
        "major": 3,^
        "minor": 23,^
        "patch": 0^
    },^
    "configurePresets": [^
        {^
            "name": "base-release",^
            "hidden": true,^
            "binaryDir": "${sourceDir}/out/build/${presetName}",^
            "cacheVariables": {^
                "CMAKE_BUILD_TYPE": "Release",^
                "CMAKE_CXX_STANDARD": "20",^
                "CMAKE_CXX_STANDARD_REQUIRED": "ON",^
                "CMAKE_CXX_EXTENSIONS": "OFF",^
                "CMAKE_EXPORT_COMPILE_COMMANDS": "ON",^
                "CMAKE_INSTALL_PREFIX": "${sourceDir}/out/install/${presetName}",^
                "CMAKE_TOOLCHAIN_FILE": "$penv{VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake"^
            }^
        },^
        {^
            "name": "windows-release",^
            "inherits": "base-release",^
            "displayName": "Windows MSVC Release (Static)",^
            "condition": {^
                "type": "equals",^
                "lhs": "${hostSystemName}",^
                "rhs": "Windows"^
            },^
            "cacheVariables": {^
                "CMAKE_C_COMPILER": "cl",^
                "CMAKE_CXX_COMPILER": "cl",^
                "VCPKG_TARGET_TRIPLET": "x64-windows-static",^
                "BUILD_SHARED_LIBS": "OFF",^
                "CMAKE_MSVC_RUNTIME_LIBRARY": "MultiThreaded",^
                "CMAKE_C_FLAGS_RELEASE": "/O2 /GL",^
                "CMAKE_CXX_FLAGS_RELEASE": "/O2 /GL",^
                "CMAKE_EXE_LINKER_FLAGS_RELEASE": "/LTCG /OPT:REF /OPT:ICF",^
                "CMAKE_SHARED_LINKER_FLAGS_RELEASE": "/LTCG /OPT:REF /OPT:ICF"^
            }^
        },^
        {^
            "name": "linux-release",^
            "inherits": "base-release",^
            "displayName": "Linux GCC Release (Dynamic)",^
            "condition": {^
                "type": "equals",^
                "lhs": "${hostSystemName}",^
                "rhs": "Linux"^
            },^
            "cacheVariables": {^
                "CMAKE_C_COMPILER": "gcc",^
                "CMAKE_CXX_COMPILER": "g++",^
                "VCPKG_TARGET_TRIPLET": "x64-linux",^
                "BUILD_SHARED_LIBS": "ON",^
                "CMAKE_C_FLAGS_RELEASE": "-O3 -DNDEBUG -ffunction-sections -fdata-sections",^
                "CMAKE_CXX_FLAGS_RELEASE": "-O3 -DNDEBUG -ffunction-sections -fdata-sections",^
                "CMAKE_EXE_LINKER_FLAGS_RELEASE": "-Wl,--gc-sections",^
                "CMAKE_SHARED_LINKER_FLAGS_RELEASE": "-Wl,--gc-sections"^
            }^
        }^
    ],^
    "buildPresets": [^
        {^
            "name": "windows",^
            "configurePreset": "windows-release"^
        },^
        {^
            "name": "linux",^
            "configurePreset": "linux-release"^
        }^
    ]^
}
)

rem Create .clangd
> .clangd (
echo CompileFlags:^
  CompilationDatabase: out/build/linux-release
)

rem Build script for Windows (build.bat)
> build.bat (
echo @echo off
echo cmake --preset windows-release
echo cmake --build --preset windows
)

rem Build script for Linux (build.sh)
> build.sh (
echo #!/bin/bash
echo cmake --preset linux-release
echo cmake --build --preset linux
)

rem Step 5: Initialize Git repository if Git is available
where git >nul 2>nul
if not errorlevel 1 (
    git init >nul 2>&1
    echo %GREEN%Git repository initialized.%NC%
) else (
    echo %YELLOW%Git not found, skipping repository initialization.%NC%
)

echo %GREEN%Project files created successfully.%NC%
echo %YELLOW%You can now cd into %CD% and run build.bat (Windows) or build.sh (Linux) to build.%NC%
popd
