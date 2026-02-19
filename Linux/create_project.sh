#!/bin/bash

# Colors for vibrant output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

error() { echo -e "${RED}Error: $1${NC}" >&2; }
success() { echo -e "${GREEN}$1${NC}"; }
info() { echo -e "${YELLOW}$1${NC}"; }

# Step 1: Check prerequisites
info "Checking prerequisites..."

missing=0
check_tool() {
    if ! command -v "$1" &> /dev/null; then
        error "$1 not found in PATH."
        missing=1
    fi
}

check_tool cmake
check_tool clangd
check_tool g++

if [ -z "$VCPKG_ROOT" ] || [ ! -d "$VCPKG_ROOT" ]; then
    error "VCPKG_ROOT environment variable is not set or points to a non-existent directory."
    missing=1
fi

if [ $missing -ne 0 ]; then
    error "Missing one or more prerequisites. Aborting."
    exit 1
fi
success "All prerequisites satisfied.\n"

# Step 2: Get project name
read -p "Enter the name of the new project: " project_name
if [ -z "$project_name" ]; then
    error "Project name cannot be empty."
    exit 1
fi

# Step 3: Get project location (default current directory)
read -p "Enter the location for the project (press Enter for current directory): " project_location
if [ -z "$project_location" ]; then
    project_location="."
fi

# Resolve full path
mkdir -p "$project_location" 2>/dev/null || {
    error "Cannot create or access directory '$project_location'."
    exit 1
}
cd "$project_location" || exit 1
project_path="$(pwd)/$project_name"

# Check if target directory already exists
if [ -e "$project_path" ]; then
    error "A file or folder named '$project_name' already exists in this location."
    exit 1
fi

# Create project directory
mkdir "$project_path" || {
    error "Failed to create project directory (permission denied?)."
    exit 1
}
cd "$project_path" || exit 1
success "Project directory created at $project_path\n"

# Step 4: Create files

# src/main.cpp
mkdir src
cat > src/main.cpp << 'EOF'
#include <iostream>

int main() {
    std::cout << "Hello, World!" << std::endl;
    return 0;
}
EOF

# CMakeLists.txt (using ${PROJECT_NAME} for the executable)
cat > CMakeLists.txt << EOF
cmake_minimum_required(VERSION 3.23)

project($project_name LANGUAGES CXX)

# Enforced already by preset, but good practice:
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Add executable
add_executable(\${PROJECT_NAME}
    src/main.cpp
)

# Link wxWidgets - using the imported target
# target_link_libraries(\${PROJECT_NAME} PRIVATE wx::core)
EOF

# CMakePresets.json (unchanged, exactly as you requested)
cat > CMakePresets.json << 'EOF'
{
    "version": 6,
    "cmakeMinimumRequired": {
        "major": 3,
        "minor": 23,
        "patch": 0
    },
    "configurePresets": [
        {
            "name": "base-release",
            "hidden": true,
            "binaryDir": "${sourceDir}/out/build/${presetName}",
            "cacheVariables": {
                "CMAKE_BUILD_TYPE": "Release",
                "CMAKE_CXX_STANDARD": "20",
                "CMAKE_CXX_STANDARD_REQUIRED": "ON",
                "CMAKE_CXX_EXTENSIONS": "OFF",
                "CMAKE_EXPORT_COMPILE_COMMANDS": "ON",
                "CMAKE_INSTALL_PREFIX": "${sourceDir}/out/install/${presetName}",
                "CMAKE_TOOLCHAIN_FILE": "$penv{VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake"
            }
        },

        {
            "name": "windows-release",
            "inherits": "base-release",
            "displayName": "Windows MSVC Release (Static)",
            "condition": {
                "type": "equals",
                "lhs": "${hostSystemName}",
                "rhs": "Windows"
            },
            "cacheVariables": {
                "CMAKE_C_COMPILER": "cl",
                "CMAKE_CXX_COMPILER": "cl",
                "VCPKG_TARGET_TRIPLET": "x64-windows-static",
                "BUILD_SHARED_LIBS": "OFF",
                "CMAKE_MSVC_RUNTIME_LIBRARY": "MultiThreaded",
                "CMAKE_C_FLAGS_RELEASE": "/O2 /GL",
                "CMAKE_CXX_FLAGS_RELEASE": "/O2 /GL",
                "CMAKE_EXE_LINKER_FLAGS_RELEASE": "/LTCG /OPT:REF /OPT:ICF",
                "CMAKE_SHARED_LINKER_FLAGS_RELEASE": "/LTCG /OPT:REF /OPT:ICF"
            }
        },

        {
            "name": "linux-release",
            "inherits": "base-release",
            "displayName": "Linux GCC Release (Dynamic)",
            "condition": {
                "type": "equals",
                "lhs": "${hostSystemName}",
                "rhs": "Linux"
            },
            "cacheVariables": {
                "CMAKE_C_COMPILER": "gcc",
                "CMAKE_CXX_COMPILER": "g++",
                "VCPKG_TARGET_TRIPLET": "x64-linux",
                "BUILD_SHARED_LIBS": "ON",
                "CMAKE_C_FLAGS_RELEASE": "-O3 -DNDEBUG -ffunction-sections -fdata-sections",
                "CMAKE_CXX_FLAGS_RELEASE": "-O3 -DNDEBUG -ffunction-sections -fdata-sections",
                "CMAKE_EXE_LINKER_FLAGS_RELEASE": "-Wl,--gc-sections",
                "CMAKE_SHARED_LINKER_FLAGS_RELEASE": "-Wl,--gc-sections"
            }
        }
    ],

    "buildPresets": [
        {
            "name": "windows",
            "configurePreset": "windows-release"
        },
        {
            "name": "linux",
            "configurePreset": "linux-release"
        }
    ]
}
EOF

# .clangd
cat > .clangd << 'EOF'
CompileFlags:
  CompilationDatabase: out/build/linux-release
EOF

# Build script for Linux (build.sh)
cat > build.sh << 'EOF'
#!/bin/bash
cmake --preset linux-release
cmake --build --preset linux
EOF
chmod +x build.sh

# Build script for Windows (build.bat)
cat > build.bat << 'EOF'
@echo off
cmake --preset windows-release
cmake --build --preset windows
EOF

# Step 5: Initialize Git repository if Git is available
if command -v git &> /dev/null; then
    git init > /dev/null 2>&1
    success "Git repository initialized."
else
    info "Git not found, skipping repository initialization."
fi

success "Project files created successfully."
info "You can now cd into $project_path and run ./build.sh (Linux) or build.bat (Windows) to build."
