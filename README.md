# C++ New Project Maker

This repository provides a script to quickly scaffold a new directory for C++ application development. It sets up a basic project structure with CMake, vcpkg for dependency management, and configuration for Clangd LSP.

## Prerequisites

### A. For Windows OS
- **MSVC compiler** (Visual Studio Build Tools or Visual Studio)
- **CMake** (latest version recommended)
- **vcpkg** in classic mode, with the environment variable `VCPKG_ROOT` set in system settings
- **Clangd LSP** (for editor integration)
- **Git** (optional but recommended)

### B. For Linux OS
- **GNU g++ compiler** (and associated build tools)
- **CMake**
- **vcpkg** in classic mode, with the environment variable `VCPKG_ROOT` set in `~/.bashrc` (or your shell's config file)
- **Clangd LSP**
- **Git** (optional but recommended)

## Build Configuration

The generated project is pre-configured to produce:
- A **release build** with symbols stripped.
- **Static linking** on Windows.
- **Dynamic linking** on Linux.

## How to Use This Project

### On Windows
Simply download and run the batch file:

```batch
create_project.bat
```

### On Linux
1. Move the script to your local binaries directory:
   ```bash
   mv create_project.sh ~/.local/bin/
   ```
2. Make the script executable:
   ```bash
   chmod u+x ~/.local/bin/create_project.sh
   ```
3. (Optional) To integrate with your desktop environment, move the application launcher:
   ```bash
   mv new_cpp_project.desktop ~/.local/share/applications/
   ```
4. (Optional) Move the icon image:
   ```bash
   mv cpp_logo.svg ~/.local/share/icons/
   ```

After these steps, you can run the script from the copied application launcher.
