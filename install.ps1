param(
    [switch]$Install
)

$ErrorActionPreference = "Stop"

$Repo = "ymendozaapp/ai-workstation"
$RepoPath = Join-Path $HOME "AI-Lab\ai-workstation"
$WindowsApps = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps"

function Refresh-Path {
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")

    $env:Path = "$machinePath;$userPath"
}

function Test-CommandExists {
    param([string]$Command)

    return [bool](Get-Command $Command -ErrorAction SilentlyContinue)
}

function Add-WindowsAppsToPath {
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $entries = @($userPath -split ";" | Where-Object { $_ })

    if ($entries -notcontains $WindowsApps) {
        $newPath = (($entries + $WindowsApps) | Select-Object -Unique) -join ";"
        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    }

    Refresh-Path
}

function Ensure-WinGet {
    if (Test-CommandExists "winget") {
        return $true
    }

    $wingetAlias = Join-Path $WindowsApps "winget.exe"

    if (Test-Path $wingetAlias) {
        Write-Host "[FOUND]   WinGet exists but WindowsApps is missing from PATH"

        if ($Install) {
            Add-WindowsAppsToPath
        }

        return (Test-CommandExists "winget")
    }

    $appInstaller = Get-AppxPackage Microsoft.DesktopAppInstaller -ErrorAction SilentlyContinue

    if ($appInstaller) {
        Write-Host "[FOUND]   App Installer is present but WinGet is not registered"

        if ($Install) {
            try {
                Add-AppxPackage `
                    -RegisterByFamilyName `
                    -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe `
                    -ErrorAction Stop

                Add-WindowsAppsToPath
            }
            catch {
                Write-Host "[WARNING] Could not re-register App Installer"
                Write-Host "          $($_.Exception.Message)"
            }
        }

        return (Test-CommandExists "winget")
    }

    Write-Host "[MISSING] WinGet / Microsoft App Installer"
    Write-Host ""
    Write-Host "Install Microsoft App Installer from Microsoft Store,"
    Write-Host "then run this script again."

    return $false
}

function Ensure-Package {
    param(
        [string]$Name,
        [string]$Command,
        [string]$PackageId
    )

    if (Test-CommandExists $Command) {
        Write-Host "[PRESENT] $Name"
        return $true
    }

    if (-not $Install) {
        Write-Host "[MISSING] $Name"
        Write-Host "          winget install --id $PackageId --exact"
        return $false
    }

    Write-Host "[INSTALL] $Name"

    & winget install `
        --id $PackageId `
        --exact `
        --source winget `
        --accept-source-agreements `
        --accept-package-agreements `
        --silent

    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR]   Installation failed: $Name"
        return $false
    }

    Refresh-Path

    if (Test-CommandExists $Command) {
        Write-Host "[OK]      $Name"
        return $true
    }

    Write-Host "[WARNING] $Name was installed but is not visible in this session yet"
    Write-Host "          Open a new terminal and run this script again."

    return $false
}

Write-Host ""
Write-Host "AI WORKSTATION RECOVERY"
Write-Host "======================="

if ($Install) {
    Write-Host "Mode: INSTALL"
}
else {
    Write-Host "Mode: CHECK"
}

Write-Host ""

Write-Host "=== WINDOWS PACKAGE MANAGER ==="

$wingetReady = Ensure-WinGet

if (-not $wingetReady) {
    Write-Host ""
    Write-Host "Recovery cannot continue until WinGet is available."
    exit 1
}

Write-Host "[READY]   WinGet $(& winget --version)"

Write-Host ""
Write-Host "=== BOOTSTRAP PREREQUISITES ==="

$pwshReady = Ensure-Package `
    "PowerShell 7" `
    "pwsh" `
    "Microsoft.PowerShell"

$gitReady = Ensure-Package `
    "Git" `
    "git" `
    "Git.Git"

$ghReady = Ensure-Package `
    "GitHub CLI" `
    "gh" `
    "GitHub.cli"

$chezmoiReady = Ensure-Package `
    "chezmoi" `
    "chezmoi" `
    "twpayne.chezmoi"

Write-Host ""
Write-Host "=== GITHUB ==="

$githubReady = $false

if ($ghReady -and (Test-CommandExists "gh")) {

    & gh auth status *> $null

    if ($LASTEXITCODE -eq 0) {
        Write-Host "[READY]   GitHub authenticated"
        $githubReady = $true
    }
    elseif ($Install) {
        Write-Host "[LOGIN]   Opening GitHub authentication"
        Write-Host ""

        & gh auth login `
            -h github.com `
            --git-protocol https `
            --web

        if ($LASTEXITCODE -eq 0) {
            & gh auth status *> $null

            if ($LASTEXITCODE -eq 0) {
                Write-Host "[READY]   GitHub authenticated"
                $githubReady = $true
            }
        }
    }
    else {
        Write-Host "[LOGIN]   GitHub authentication required"
    }
}
else {
    Write-Host "[PENDING] GitHub CLI is not ready"
}

Write-Host ""
Write-Host "=== PRIVATE WORKSTATION REPOSITORY ==="

if (Test-Path (Join-Path $RepoPath ".git")) {
    Write-Host "[PRESENT] $RepoPath"
}
elseif ($Install -and $githubReady) {

    $parent = Split-Path $RepoPath -Parent

    if (-not (Test-Path $parent)) {
        New-Item `
            -ItemType Directory `
            -Path $parent `
            -Force | Out-Null
    }

    Write-Host "[CLONE]   $Repo"

    & gh repo clone $Repo $RepoPath

    if (Test-Path (Join-Path $RepoPath ".git")) {
        Write-Host "[OK]      Private workstation repository cloned"
    }
    else {
        Write-Host "[ERROR]   Repository clone failed"
    }
}
else {
    Write-Host "[PENDING] $Repo must be cloned"
}

Write-Host ""
Write-Host "=== HANDOFF ==="

$bootstrap = Join-Path $RepoPath "bootstrap.ps1"

if (
    $pwshReady -and
    $gitReady -and
    $ghReady -and
    $chezmoiReady -and
    (Test-Path $bootstrap)
) {
    Write-Host "[READY]   Workstation bootstrap is available"
    Write-Host ""
    Write-Host "Next:"
    Write-Host ""
    Write-Host "  cd `"$RepoPath`""
    Write-Host "  pwsh -NoProfile -File .\bootstrap.ps1 -Plan"
}
else {
    Write-Host "[PENDING] Recovery prerequisites are incomplete"
}

Write-Host ""

if ($Install) {
    Write-Host "RECOVERY STAGE COMPLETE"
}
else {
    Write-Host "CHECK ONLY"
    Write-Host ""
    Write-Host "Run:"
    Write-Host "  .\install.ps1 -Install"
    Write-Host ""
    Write-Host "to perform the recovery stage."
}
