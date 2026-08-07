param(
    [string]$ProjectDir = "$env:USERPROFILE\PlaywrightRPA"
)

$ErrorActionPreference = "Stop"

$nodeVersion = "v20.11.1"
$nodeZipUrl = "https://nodejs.org/dist/$nodeVersion/node-$nodeVersion-win-x64.zip"
$zipPath = "$env:TEMP\nodejs.zip"
$installDir = "$env:LOCALAPPDATA\NodeJS"

# 离线包路径（与 setup.ps1 同级，由 NSIS 释放到 $INSTDIR）
$localNodeZip      = Join-Path $PSScriptRoot "node-v20.11.1-win-x64.zip"
$localPlaywrightTgz= Join-Path $PSScriptRoot "playwright-1.45.0.tgz"
$localChromiumZip  = Join-Path $PSScriptRoot "chromium-win64.zip"

function Test-NodeVersion {
    param([string]$RequiredVersion = "18.0.0")
    try {
        $raw = (node --version) -replace '\x1b\[[0-9;]*m','' -replace '^v',''
        $raw = ($raw -split '\s+')[0]
        $current = [Version]$raw
        $required = [Version]$RequiredVersion
        return $current -ge $required
    } catch {
        return $false
    }
}

function Install-NodeJS {
    if (Test-Path $localNodeZip) {
        Write-Host "[->] Using local Node.js package..."
        Copy-Item $localNodeZip $zipPath -Force
    } else {
        Write-Host "[->] Downloading Node.js $nodeVersion..."
        try {
            Invoke-WebRequest -Uri $nodeZipUrl -OutFile $zipPath -UseBasicParsing
        } catch {
            throw "Download Node.js failed: $_"
        }
    }

    if (Test-Path $installDir) {
        $backupDir = "$installDir.bak.$(Get-Date -Format 'yyyyMMddHHmmss')"
        Write-Host "[->] Backing up old dir to $backupDir"
        try {
            Rename-Item $installDir $backupDir -Force
        } catch {
            Write-Host "[!] Cannot backup, trying force delete..."
            Remove-Item $installDir -Recurse -Force
            if (Test-Path $installDir) {
                throw "Cannot clean old Node.js dir, please manually delete $installDir and retry"
            }
        }
    }

    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
    Expand-Archive -Path $zipPath -DestinationPath $installDir -Force

    $innerDir = Get-ChildItem $installDir -Force | Where-Object { 
        $_.PSIsContainer -and $_.Name -like "node-*-win-x64" 
    } | Select-Object -First 1

    if (-not $innerDir) {
        throw "Extract failed: node-*-win-x64 dir not found"
    }

    foreach ($item in (Get-ChildItem $innerDir.FullName -Force)) {
        $dest = Join-Path $installDir $item.Name
        if (Test-Path $dest) {
            Remove-Item $dest -Recurse -Force
        }
        Move-Item $item.FullName -Destination $installDir -Force
    }
    Remove-Item $innerDir.FullName -Force

    $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
    if ($userPath -notlike "*$installDir*") {
        if ([string]::IsNullOrWhiteSpace($userPath)) {
            [System.Environment]::SetEnvironmentVariable("Path", $installDir, "User")
        } else {
            [System.Environment]::SetEnvironmentVariable("Path", "$installDir;$userPath", "User")
        }
    }

    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
    Write-Host "[OK] Node.js installed"
}

$existingNode = Get-Command node -ErrorAction SilentlyContinue
$nodeExe = $null
$npmCmd = $null
$npxCmd = $null

if ($existingNode -and (Test-NodeVersion)) {
    Write-Host "[OK] Node.js already installed: $(node --version)" -ForegroundColor Green
    $nodeExe = $existingNode.Source
    $npmCmd = Get-Command npm -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
    $npxCmd = Get-Command npx -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
} else {
    if ($existingNode) {
        Write-Host "[!] Node.js version too old: $(node --version), need >= v18.0.0" -ForegroundColor Yellow
    }
    Install-NodeJS
    $nodeExe = "$installDir\node.exe"
    $npmCmd = "$installDir\npm.cmd"
    $npxCmd = "$installDir\npx.cmd"
}

if (-not (Test-Path $nodeExe)) {
    throw "Node.js path invalid: $nodeExe"
}
if (-not $npmCmd -or -not (Test-Path $npmCmd)) {
    throw "npm not found"
}
if (-not $npxCmd -or -not (Test-Path $npxCmd)) {
    throw "npx not found"
}

if (-not (Test-Path $ProjectDir)) {
    New-Item -ItemType Directory -Path $ProjectDir -Force | Out-Null
}
Set-Location $ProjectDir

Write-Host "[->] Initializing npm project..."
& $npmCmd init -y
if ($LASTEXITCODE -ne 0) { throw "npm init failed (exit: $LASTEXITCODE)" }

# Playwright 安装（优先本地离线包）
$playwrightVersion = "1.45.0"
if (Test-Path $localPlaywrightTgz) {
    Write-Host "[->] Installing Playwright from local package..."
    & $npmCmd install $localPlaywrightTgz
} else {
    Write-Host "[->] Installing Playwright@$playwrightVersion from npm..."
    & $npmCmd install "playwright@$playwrightVersion"
}
if ($LASTEXITCODE -ne 0) { throw "npm install playwright failed (exit: $LASTEXITCODE)" }

# Chromium 安装（优先本地离线包）
if (Test-Path $localChromiumZip) {
    Write-Host "[->] Installing Chromium from local package..."
    $playwrightCache = "$env:LOCALAPPDATA\ms-playwright"
    if (-not (Test-Path $playwrightCache)) {
        New-Item -ItemType Directory -Path $playwrightCache -Force | Out-Null
    }
    Expand-Archive -Path $localChromiumZip -DestinationPath $playwrightCache -Force
} else {
    Write-Host "[->] Installing Chromium browser from network..."
    & $npxCmd playwright install chromium
}
if ($LASTEXITCODE -ne 0) { throw "Playwright Chromium install failed (exit: $LASTEXITCODE)" }

Write-Host "[->] Verifying environment..."
& $nodeExe -e "const p = require('playwright'); console.log('Playwright version:', require('playwright/package.json').version)"
if ($LASTEXITCODE -ne 0) { throw "Playwright verification failed" }

# 生成英文名的启动脚本，彻底避免中文编码问题
$batPath = Join-Path $ProjectDir "run.bat"
$batContent = @"
@echo off
cd /d "$ProjectDir"
"$nodeExe" rpa.js
pause
"@
Set-Content -Path $batPath -Value $batContent -Encoding Default
Write-Host "[OK] Launch script generated: $batPath"

Write-Host "[OK] Setup complete: $ProjectDir" -ForegroundColor Green