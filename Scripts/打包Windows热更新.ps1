param(
    [string]$Version = "",
    [string]$Channel = "stable",
    [string]$ReleaseAssetRoot = "",
    [string]$DownloadBaseUrl = ""
)

$ErrorActionPreference = "Stop"
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$pubspecPath = Join-Path $repoRoot "pubspec.yaml"

function Get-PubspecVersion {
    $text = Get-Content -LiteralPath $pubspecPath -Raw -Encoding UTF8
    $match = [regex]::Match($text, '(?m)^version:\s*(?<version>[^\+]+)(?:\+\d+)?\s*$')
    if (!$match.Success) { throw "pubspec.yaml 缺少 version 字段。" }
    return $match.Groups["version"].Value.Trim()
}

function Assert-VersionText {
    param([string]$Value)
    if ($Value -notmatch '^v?\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$') {
        throw "版本号格式无效：$Value。请使用 1.0.1 或 1.0.1-beta.1。"
    }
    return $Value.Trim().TrimStart('v', 'V')
}

function Assert-Inside {
    param([string]$BasePath, [string]$ChildPath)
    $baseFull = [System.IO.Path]::GetFullPath($BasePath).TrimEnd('\') + '\'
    $childFull = [System.IO.Path]::GetFullPath($ChildPath)
    if (!$childFull.StartsWith($baseFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "路径越界：$childFull"
    }
}

function Copy-DirectoryContents {
    param([string]$SourceDir, [string]$DestinationDir)
    $sourceFull = [System.IO.Path]::GetFullPath($SourceDir).TrimEnd('\')
    $files = @(Get-ChildItem -LiteralPath $SourceDir -Recurse -Force)
    foreach ($item in $files) {
        $relative = $item.FullName.Substring($sourceFull.Length).TrimStart('\')
        $target = Join-Path $DestinationDir $relative
        Assert-Inside -BasePath $DestinationDir -ChildPath $target
        if ($item.PSIsContainer) {
            New-Item -ItemType Directory -Force -Path $target | Out-Null
        } else {
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
            Copy-Item -LiteralPath $item.FullName -Destination $target -Force
        }
    }
}

if ([string]::IsNullOrWhiteSpace($Version)) {
    $Version = Get-PubspecVersion
}
$Version = Assert-VersionText -Value $Version

if ([string]::IsNullOrWhiteSpace($ReleaseAssetRoot)) {
    $ReleaseAssetRoot = Join-Path "D:\DabaoV" "虚幻蓝图连结V$Version"
}

$releaseDir = [System.IO.Path]::GetFullPath($ReleaseAssetRoot)
New-Item -ItemType Directory -Force -Path $releaseDir | Out-Null
$publishProgramDir = Join-Path $releaseDir "虚幻蓝图连结"
Assert-Inside -BasePath $releaseDir -ChildPath $publishProgramDir

Push-Location $repoRoot
try {
    flutter build windows --build-name $Version --dart-define "APP_VERSION=$Version"
} finally {
    Pop-Location
}

$programDir = Join-Path $repoRoot "build\windows\x64\runner\Release"
$entryExe = "unreal_blueprint_bridge.exe"
if (!(Test-Path -LiteralPath (Join-Path $programDir $entryExe) -PathType Leaf)) {
    throw "没有找到 Windows Release 主程序。"
}

$packageManifest = [ordered]@{
    schemaVersion = 1
    toolboxStableKey = "UnrealBlueprintBridge"
    version = $Version
    runtime = "win-x64"
    entryExe = $entryExe
    createdAt = (Get-Date).ToString("o")
}
$packageManifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $programDir "update-package.json") -Encoding UTF8

if (Test-Path -LiteralPath $publishProgramDir) {
    Remove-Item -LiteralPath $publishProgramDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $publishProgramDir | Out-Null
Copy-DirectoryContents -SourceDir $programDir -DestinationDir $publishProgramDir

$zipName = "UnrealBlueprintBridge-v$Version-win-x64.zip"
$zipPath = Join-Path $releaseDir $zipName
$shaPath = Join-Path $releaseDir "UnrealBlueprintBridge-v$Version-win-x64.sha256.txt"
$manifestPath = Join-Path $releaseDir "blueprint-bridge-update.json"
if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }

Compress-Archive -LiteralPath $publishProgramDir -DestinationPath $zipPath -Force
$sha = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
"$sha  $zipName" | Set-Content -LiteralPath $shaPath -Encoding ASCII
$zipSize = (Get-Item -LiteralPath $zipPath).Length

$downloadUrl = if ([string]::IsNullOrWhiteSpace($DownloadBaseUrl)) {
    $zipName
} else {
    $DownloadBaseUrl.TrimEnd('/') + "/" + $zipName
}

$manifest = [ordered]@{
    schemaVersion = 1
    productKey = "unreal-blueprint-bridge"
    displayName = "虚幻：蓝图连结"
    version = $Version
    channel = $Channel
    releaseNotes = "本次更新包含最新的蓝图连结工具功能与修复。"
    releaseNotesUrl = ""
    assets = @(
        [ordered]@{
            runtime = "win-x64"
            fileName = $zipName
            sha256 = $sha
            sizeBytes = $zipSize
            downloadUrl = $downloadUrl
        }
    )
}
$manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

Write-Host "Windows 热更新包已生成："
Write-Host "  Program:  $publishProgramDir"
Write-Host "  Zip:      $zipPath"
Write-Host "  SHA-256:  $shaPath"
Write-Host "  Manifest: $manifestPath"
