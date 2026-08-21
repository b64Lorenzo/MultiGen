param(
    [string]$ConfigFile,
    [string]$OutputRoot,
    [string]$LogFile,
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ------------------------------------------------
# MultiGen metadata
# ------------------------------------------------
$MultiGenName    = "MultiGen"
$MultiGenVersion = "1.0.0"
$MultiGenAuthor  = "Lorenzo Zambelli"
$MultiGenDesc    = "Config-driven multi-file generator"

# ------------------------------------------------
# Help
# ------------------------------------------------
if ($Help -or -not $ConfigFile -or -not $OutputRoot) {
@"
$MultiGenName v$MultiGenVersion
$MultiGenDesc
Author: $MultiGenAuthor

--------------------------------------------------
USAGE
--------------------------------------------------
  multigen.exe -ConfigFile <config.ini> -OutputRoot <output_dir> [options]

OPTIONS
--------------------------------------------------
  -ConfigFile   Path to INI configuration file (required)
  -OutputRoot   Directory where generated files will be created (required)
  -LogFile      Optional log file path
                Default: %USERPROFILE%\.multigen\multigen.log
  -Help         Show this help message

--------------------------------------------------
CONFIG.INI STRUCTURE
--------------------------------------------------

[Template]
--------------------------------------------------
Defines which template is used and how placeholders
are written.

  TemplateFile       Path to the template file
  OutputFileName     Name of the generated file
  PlaceholderPrefix  Text before a variable name
  PlaceholderSuffix  Text after a variable name

Example:
  TemplateFile=main_template.xmf
  OutputFileName=main.xmf
  PlaceholderPrefix=___
  PlaceholderSuffix=___

Template placeholder example:
  ___DEG___

--------------------------------------------------
[GlobalFixed]
--------------------------------------------------
Parameters that never change.

Example:
  PROBECONFIG=port
  BEAM=0
  RUN=ft

--------------------------------------------------
[GlobalLoops]
--------------------------------------------------
Parameters that should be expanded as a Cartesian
product. Lists are comma-separated.

Example:
  DEG=30,45,60
  PERIOD=3,4,5

--------------------------------------------------
[Derived]
--------------------------------------------------
Parameters computed from other values.
Expressions are evaluated by PowerShell.

Example:
  DT=PERIOD / DT_DIV

--------------------------------------------------
[NameFormat]
--------------------------------------------------
Defines how the run name is built.
Uses ordered numeric keys.

Example:
  1=angle___DEG___
  2=dx___DX___
  3=dt___DT___

NameSeparator=_

--------------------------------------------------
[OutputStructure]
--------------------------------------------------
Controls directory hierarchy for generated files.

Example:
  1=___PROBECONFIG___
  2=___METHOD___
  3=___RUN_NAME___

--------------------------------------------------
[Methods]
--------------------------------------------------
Defines multiple variants or modes.
Each method can have its own Fixed and Loops section.

Example:
  List=anysim,vbm

--------------------------------------------------
[Methods.<name>.Fixed]
--------------------------------------------------
Parameters specific to one method.

Example:
  WAVEZ=-1e-6

--------------------------------------------------
[Methods.<name>.Loops]
--------------------------------------------------
Optional method-specific loops.
Leave empty if not needed.

--------------------------------------------------
EXAMPLE RUN
--------------------------------------------------
  multigen.exe -ConfigFile config.ini -OutputRoot generated

--------------------------------------------------
EXIT CODES
--------------------------------------------------
  0  Success
  1  Error during generation

--------------------------------------------------
"@
    exit 0
}


# ------------------------------------------------
# Resolve default log location
# ------------------------------------------------
if (-not $LogFile) {
    $logDir = Join-Path $HOME ".multigen"
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    }
    $LogFile = Join-Path $logDir "multigen.log"
}

# ------------------------------------------------
# Logging
# ------------------------------------------------
function Write-Log {
    param([string]$Message)

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] $Message"

    Write-Host $line
    Add-Content -Path $LogFile -Value $line
}

# Initialize log
"========================================" | Set-Content $LogFile
Write-Log "MultiGen started"
Write-Log "ConfigFile : $ConfigFile"
Write-Log "OutputRoot : $OutputRoot"
Write-Log "LogFile    : $LogFile"
"========================================" | Add-Content $LogFile

# ------------------------------------------------
# INI reader
# ------------------------------------------------
function Read-Ini {
    param([string]$Path)

    $ini = @{}
    $section = $null

    foreach ($line in Get-Content $Path) {
        $l = $line.Trim()
        if (!$l -or $l.StartsWith(";")) { continue }

        if ($l -match '^\[(.+)\]$') {
            $section = $matches[1]
            $ini[$section] = @{}
            continue
        }

        if ($l -match '^(.*?)=(.*)$' -and $section) {
            $ini[$section][$matches[1].Trim()] = $matches[2].Trim()
        }
    }
    return $ini
}

# ------------------------------------------------
# Helpers
# ------------------------------------------------
function Split-List($s) { if ($s) { $s -split ',' | % { $_.Trim() } } else { @() } }

function Expand-Parameters($map) {
    $out = @(@{})
    foreach ($k in $map.Keys) {
        $out = foreach ($r in $out) {
            foreach ($v in (Split-List $map[$k])) {
                $n = $r.Clone()
                $n[$k] = $v
                $n
            }
        }
    }
    return $out
}

function Eval-Derived($vals, $der) {
    foreach ($k in $der.Keys) {
        $expr = $der[$k]
        foreach ($v in $vals.Keys) {
            $expr = $expr -replace "\b$v\b", $vals[$v]
        }
        $vals[$k] = Invoke-Expression $expr
    }
}

function ToSafe($s) {
    if (-not $s) { return "" }
    ($s -replace '[^A-Za-z0-9._-]', '').Trim('. ')
}

function Expand-Template($text, $vals, $prefix, $suffix) {
    foreach ($k in $vals.Keys) {
        $text = $text.Replace("$prefix$k$suffix", [string]$vals[$k])
    }
    return $text
}

# ------------------------------------------------
# LOAD CONFIG
# ------------------------------------------------
if (-not (Test-Path $ConfigFile)) {
    Write-Log "ERROR: Config file not found"
    exit 1
}

$config = Read-Ini $ConfigFile
$tconf  = $config["Template"]

$templateText = Get-Content $tconf["TemplateFile"] -Raw
$outputFile   = $tconf["OutputFileName"]
$prefix       = $tconf["PlaceholderPrefix"]
$suffix       = $tconf["PlaceholderSuffix"]

# ------------------------------------------------
# PREPARE STRUCTURES
# ------------------------------------------------
$globals  = Expand-Parameters $config["GlobalLoops"]
$methods  = Split-List $config["Methods"]["List"]

$nameFmt = ($config["NameFormat"].GetEnumerator() | ? { $_.Key -match '^\d+$' } | sort { [int]$_.Key }).Value
$outFmt  = ($config["OutputStructure"].GetEnumerator() | ? { $_.Key -match '^\d+$' } | sort { [int]$_.Key }).Value

# ------------------------------------------------
# GENERATION LOOP
# ------------------------------------------------
foreach ($method in $methods) {
    foreach ($g in $globals) {

        $vals = @{}
        $vals += $config["GlobalFixed"]
        $vals += $g
        $vals += $config["Methods.$method.Fixed"]
        $vals["METHOD"] = $method

        Eval-Derived $vals $config["Derived"]

        $vals["RUN_NAME"] =
            ($nameFmt | % { Expand-Template $_ $vals $prefix $suffix }) -join
            $config["NameFormat"]["NameSeparator"]

        $segments = @()
        foreach ($p in $outFmt) {
            $seg = ToSafe (Expand-Template $p $vals $prefix $suffix)
            if ($seg) { $segments += $seg }
        }

        $dir = Join-Path $OutputRoot ($segments -join '\')
        New-Item -ItemType Directory -Force $dir | Out-Null

        $outTxt = Expand-Template $templateText $vals $prefix $suffix
        Set-Content (Join-Path $dir $outputFile) $outTxt

        Write-Log "Generated: $($vals['RUN_NAME'])"
    }
}

Write-Log "MultiGen completed successfully"
exit 0

