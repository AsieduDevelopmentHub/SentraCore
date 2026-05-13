#Requires -Version 5.1
<#
.SYNOPSIS
  Authenticode-sign SentraCore Windows binaries and the Inno Setup installer.

.DESCRIPTION
  Use after building the engine (dist\SentraCoreEngine.exe), the Flutter Windows
  release (dashboard\build\windows\x64\runner\Release\sentracore_dashboard.exe),
  and optionally after ISCC produces dist\SentraCore_Setup_v*.exe.

  Signing requires a code-signing certificate trusted by Windows (public CA).
  Self-signed certificates will NOT remove SmartScreen warnings for end users.

.PARAMETER PfxPath
  Path to a .pfx (PKCS#12) file containing the signing certificate and private key.

.PARAMETER PfxPassword
  Password for the PFX file. Avoid passing on the command line in shared logs;
  prefer environment variable WINDOWS_CODESIGN_PFX_PASSWORD.

.PARAMETER TimestampServer
  RFC3161 timestamp authority (SHA-256). Default: DigiCert public TSA.

.EXAMPLE
  .\scripts\sign-windows-artifacts.ps1 -PfxPath C:\certs\codesign.pfx

.EXAMPLE
  $env:WINDOWS_CODESIGN_PFX_PASSWORD = '***'
  .\scripts\sign-windows-artifacts.ps1 -PfxPath C:\certs\codesign.pfx -SignInstaller

.EXAMPLE
  .\scripts\sign-windows-artifacts.ps1 -PfxPath C:\certs\codesign.pfx -InstallerOnly
#>
param(
  [Parameter(Mandatory = $true)]
  [string] $PfxPath,

  [string] $PfxPassword = "",

  [string] $TimestampServer = "http://timestamp.digicert.com",

  [string] $Description = "SentraCore",

  [string] $RepoRoot = "",

  [switch] $SignInstaller,

  [switch] $InstallerOnly
)

$ErrorActionPreference = "Stop"

if (-not $RepoRoot) {
  $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

$pfxPasswordEffective = $PfxPassword
if (-not $pfxPasswordEffective -and $env:WINDOWS_CODESIGN_PFX_PASSWORD) {
  $pfxPasswordEffective = $env:WINDOWS_CODESIGN_PFX_PASSWORD
}
if (-not (Test-Path -LiteralPath $PfxPath)) {
  throw "PFX not found: $PfxPath"
}

function Find-SignTool {
  $roots = @(
    "${env:ProgramFiles(x86)}\Windows Kits\10\bin",
    "${env:ProgramFiles}\Windows Kits\10\bin"
  )
  foreach ($root in $roots) {
    if (-not (Test-Path $root)) { continue }
    $candidates = Get-ChildItem -Path $root -Recurse -Filter "signtool.exe" -ErrorAction SilentlyContinue |
      Where-Object { $_.FullName -match '\\x64\\signtool\.exe$' } |
      Sort-Object { $_.DirectoryName } -Descending
    if ($candidates) {
      return $candidates[0].FullName
    }
  }
  throw "signtool.exe not found. Install the Windows SDK (Desktop development with C++ / Windows SDK)."
}

function Invoke-SignFile {
  param(
    [string] $SignTool,
    [string] $FilePath,
    [string] $Pfx,
    [string] $Pass,
    [string] $Tsa,
    [string] $Desc
  )
  if (-not (Test-Path -LiteralPath $FilePath)) {
    Write-Warning "Skip (missing): $FilePath"
    return
  }
  $full = (Resolve-Path -LiteralPath $FilePath).Path
  Write-Host "Signing: $full"
  $argList = @(
    "sign",
    "/f", $Pfx,
    "/tr", $Tsa,
    "/td", "sha256",
    "/fd", "sha256",
    "/d", $Desc
  )
  if ($Pass) {
    $argList += @("/p", $Pass)
  }
  $argList += $full
  & $SignTool @argList
  if ($LASTEXITCODE -ne 0) {
    throw "signtool failed with exit $LASTEXITCODE for $full"
  }
}

$signTool = Find-SignTool
Write-Host "Using: $signTool"

$engine = Join-Path $RepoRoot "dist\SentraCoreEngine.exe"
$dashboard = Join-Path $RepoRoot "dashboard\build\windows\x64\runner\Release\sentracore_dashboard.exe"

if (-not $InstallerOnly) {
  Invoke-SignFile -SignTool $signTool -FilePath $engine -Pfx $PfxPath -Pass $pfxPasswordEffective -Tsa $TimestampServer -Desc $Description
  Invoke-SignFile -SignTool $signTool -FilePath $dashboard -Pfx $PfxPath -Pass $pfxPasswordEffective -Tsa $TimestampServer -Desc $Description
}

if ($SignInstaller -or $InstallerOnly) {
  $setup = Get-ChildItem -Path (Join-Path $RepoRoot "dist") -Filter "SentraCore_Setup_v*.exe" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
  if ($setup) {
    Invoke-SignFile -SignTool $signTool -FilePath $setup.FullName -Pfx $PfxPath -Pass $pfxPasswordEffective -Tsa $TimestampServer -Desc "$Description Installer"
  }
  else {
    Write-Warning "No dist\SentraCore_Setup_v*.exe found to sign."
  }
}

Write-Host "Done."
