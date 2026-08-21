# MultiGen

MultiGen is a configuration-driven file generation tool that automates the creation of large numbers of files from a template and a set of parameter combinations.

Instead of manually creating hundreds or thousands of similar files, MultiGen reads an INI configuration file, expands parameter combinations, computes derived values, and generates a structured output directory containing fully populated files.

Typical use cases include:

- Simulation input generation
- Parameter sweep studies
- Engineering workflows
- Scientific computing
- Automated test generation
- Configuration file creation

---

# Features

- Template-based file generation
- INI configuration format
- Cartesian expansion of parameter lists
- Derived parameter calculations
- Multiple generation methods
- Custom run naming
- Configurable output folder hierarchy
- Detailed logging
- Windows launcher script included
- Buildable as a standalone executable
- Cross-platform support through PowerShell 7

---

# Repository Structure

```text
MultiGen/
│
├── src/
│   ├── multigen.cmd
│   └── scripts/
│       └── _buildFiles.ps1
│
├── config.ini
├── README.md
└── output/
```

---

# Components

## `src/scripts/_buildFiles.ps1`

The main MultiGen engine.

Responsibilities:

- Reading configuration files
- Parsing template definitions
- Expanding parameter loops
- Evaluating derived expressions
- Building output paths
- Generating files
- Logging execution progress

---

## `src/multigen.cmd`

Windows launcher script.

It automatically:

- Locates the repository directory
- Loads `config.ini`
- Creates files in the `output` directory
- Executes the PowerShell generator

Example:

```cmd
@echo off
setlocal EnableExtensions

set "HERE=%~dp0"
set "CONFIG=%HERE%config.ini"
set "OUTDIR=%HERE%output"

powershell -NoProfile -ExecutionPolicy Bypass ^
  -File "%HERE%scripts\_buildFiles.ps1" ^
  -ConfigFile "%CONFIG%" ^
  -OutputRoot "%OUTDIR%"
```

---

# Running MultiGen

## Windows

From the repository root:

```cmd
src\multigen.cmd
```

Or run PowerShell directly:

```powershell
powershell -ExecutionPolicy Bypass `
    -File src\scripts\_buildFiles.ps1 `
    -ConfigFile config.ini `
    -OutputRoot output
```

---

## macOS / Linux

Install PowerShell 7:

```bash
pwsh --version
```

Run:

```bash
pwsh ./src/scripts/_buildFiles.ps1 \
    -ConfigFile config.ini \
    -OutputRoot output
```

---

# Command Line Options

```text
-ConfigFile    Path to configuration file
-OutputRoot    Output directory
-LogFile       Optional custom log path
-Help          Display help
```

Example:

```powershell
pwsh ./src/scripts/_buildFiles.ps1 `
    -ConfigFile config.ini `
    -OutputRoot output `
    -LogFile logs/multigen.log
```

---

# Configuration File

MultiGen uses a standard INI file.

Example:

```ini
[Template]
TemplateFile=main_template.xmf
OutputFileName=main.xmf
PlaceholderPrefix=___
PlaceholderSuffix=___
```

---

## Template Section

Defines:

- Source template file
- Output filename
- Placeholder delimiters

Example:

```ini
[Template]
TemplateFile=main_template.xmf
OutputFileName=main.xmf
PlaceholderPrefix=___
PlaceholderSuffix=___
```

Placeholder example:

```text
___DEG___
```

---

## GlobalFixed

Parameters that never change.

```ini
[GlobalFixed]
PROBECONFIG=port
RUN=test
```

---

## GlobalLoops

Parameters expanded as Cartesian products.

```ini
[GlobalLoops]
DEG=30,45,60
PERIOD=3,4,5
```

Generated combinations:

```text
DEG=30 PERIOD=3
DEG=30 PERIOD=4
DEG=30 PERIOD=5
DEG=45 PERIOD=3
...
```

---

## Derived

Values calculated from existing variables.

```ini
[Derived]
DT=PERIOD / DT_DIV
```

Example:

```text
PERIOD = 4
DT_DIV = 2

DT = 2
```

---

## NameFormat

Defines how a run name is generated.

```ini
[NameFormat]
1=angle___DEG___
2=dt___DT___
3=method___METHOD___
NameSeparator=_
```

Generated:

```text
angle30_dt2_methodvbm
```

---

## OutputStructure

Defines generated folder hierarchy.

```ini
[OutputStructure]
1=___PROBECONFIG___
2=___METHOD___
3=___RUN_NAME___
```

Generated output:

```text
output/
└── port/
    └── vbm/
        └── angle30_dt2_methodvbm/
```

---

## Methods

List all generation methods.

```ini
[Methods]
List=anysim,vbm
```

---

## Method Fixed Values

```ini
[Methods.vbm.Fixed]
WAVEZ=-1e-6
```

---

## Method Loops

Optional method-specific loops.

```ini
[Methods.vbm.Loops]
AMPLITUDE=1,2,3
```

---

# Example Configuration

```ini
[Template]
TemplateFile=main_template.xmf
OutputFileName=main.xmf
PlaceholderPrefix=___
PlaceholderSuffix=___

[GlobalFixed]
PROBECONFIG=port
DT_DIV=2

[GlobalLoops]
DEG=30,45
PERIOD=4,6

[Derived]
DT=PERIOD / DT_DIV

[NameFormat]
1=angle___DEG___
2=dt___DT___
NameSeparator=_

[OutputStructure]
1=___PROBECONFIG___
2=___RUN_NAME___

[Methods]
List=vbm

[Methods.vbm.Fixed]
WAVEZ=-1e-6
```

---

# Example Template

Template:

```xml
<simulation>
    <angle>___DEG___</angle>
    <period>___PERIOD___</period>
    <dt>___DT___</dt>
    <method>___METHOD___</method>
</simulation>
```

Generated file:

```xml
<simulation>
    <angle>30</angle>
    <period>4</period>
    <dt>2</dt>
    <method>vbm</method>
</simulation>
```

---

# Logging

By default logs are stored at:

```text
%USERPROFILE%\.multigen\multigen.log
```

Example:

```text
[2026-01-01 10:00:00] MultiGen started
[2026-01-01 10:00:01] Generated: angle30_dt2
[2026-01-01 10:00:02] MultiGen completed successfully
```

Custom log file:

```powershell
pwsh ./src/scripts/_buildFiles.ps1 `
    -ConfigFile config.ini `
    -OutputRoot output `
    -LogFile logs/multigen.log
```

---

# Building a Standalone Executable

MultiGen can be distributed as a single executable using the PowerShell Pro Tools Packager or PS2EXE.

## Using PS2EXE

Install:

```powershell
Install-Module ps2exe -Scope CurrentUser
```

Generate executable:

```powershell
Invoke-PS2EXE `
    .\src\scripts\_buildFiles.ps1 `
    .\multigen.exe
```

Run:

```powershell
multigen.exe `
    -ConfigFile config.ini `
    -OutputRoot output
```

---

# Cross-Platform Packaging

Because MultiGen is written in PowerShell, it naturally runs on:

- Windows
- Linux
- macOS

using PowerShell 7.

## Linux Wrapper

Create:

```bash
#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

pwsh "$SCRIPT_DIR/src/scripts/_buildFiles.ps1" \
  -ConfigFile "$SCRIPT_DIR/config.ini" \
  -OutputRoot "$SCRIPT_DIR/output"
```

Save as:

```text
multigen.sh
```

Make executable:

```bash
chmod +x multigen.sh
```

Run:

```bash
./multigen.sh
```

---

## macOS Wrapper

Create:

```bash
#!/bin/zsh

DIR="$(cd "$(dirname "$0")" && pwd)"

pwsh "$DIR/src/scripts/_buildFiles.ps1" \
  -ConfigFile "$DIR/config.ini" \
  -OutputRoot "$DIR/output"
```

Run:

```bash
chmod +x multigen.sh
./multigen.sh
```

---

# Exit Codes

| Code | Meaning |
|--------|----------|
| 0 | Success |
| 1 | Error during generation |

---

# Future Improvements

Potential roadmap items:

- JSON configuration support
- YAML configuration support
- Parallel generation
- GUI configuration editor
- Containerized Docker distribution
- File generation statistics
- Validation schema for configuration files

---

# Author

**Lorenzo Zambelli**

---

# Version

**Current Version:** 1.0.0