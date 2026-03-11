# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2024-2025 wealdly
# Build script for JustLoot distribution package
# Run: .\build.ps1

$addonName = "JustLoot"
$version = (Get-Content "JustLoot.toc" | Select-String "## Version:" | ForEach-Object { $_ -replace "## Version:\s*", "" }).Trim()
if (-not $version) { $version = "dev" }

# Output to a "dist" folder inside the addon
$distDir = Join-Path $PSScriptRoot "dist"
$tempDir = Join-Path $env:TEMP "$addonName-build"
$outputDir = Join-Path $tempDir $addonName
$zipFile = Join-Path $distDir "$addonName-$version.zip"

# Clean previous build
if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
if (Test-Path $zipFile) { Remove-Item $zipFile -Force }

# Create directories
New-Item -ItemType Directory -Path $distDir -Force | Out-Null
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null

Write-Host "Building $addonName v$version..." -ForegroundColor Cyan

# Addon files to include
$coreFiles = @(
    "JustLoot.toc",
    "JustLoot.lua",
    "LICENSE"
)

$missingFiles = @()
foreach ($file in $coreFiles) {
    $src = Join-Path $PSScriptRoot $file
    if (-not (Test-Path $src)) {
        $missingFiles += $file
    }
}
if ($missingFiles.Count -gt 0) {
    Write-Host "`nBuild FAILED - missing files:" -ForegroundColor Red
    $missingFiles | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    exit 1
}

foreach ($file in $coreFiles) {
    $src = Join-Path $PSScriptRoot $file
    $dest = Join-Path $outputDir $file
    Copy-Item $src $dest -Force
}

# Create ZIP with forward slashes for macOS/Linux compatibility
# (Compress-Archive uses backslashes which breaks non-Windows extractors)
Write-Host "Creating ZIP archive..." -ForegroundColor Cyan
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::Open($zipFile, 'Create')
Get-ChildItem $outputDir -Recurse -File | ForEach-Object {
    $relativePath = $_.FullName.Substring($tempDir.Length + 1).Replace('\', '/')
    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
        $zip, $_.FullName, $relativePath, [System.IO.Compression.CompressionLevel]::Optimal
    ) | Out-Null
}
$zip.Dispose()

# Clean up temp folder
Remove-Item $tempDir -Recurse -Force

Write-Host "`nBuild complete!" -ForegroundColor Green
Write-Host "  ZIP: $zipFile" -ForegroundColor White

# Show package size
$size = (Get-Item $zipFile).Length / 1KB
Write-Host "  Size: $([math]::Round($size, 1)) KB" -ForegroundColor White
