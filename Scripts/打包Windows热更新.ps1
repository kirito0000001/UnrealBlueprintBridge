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

if ([string]::IsNullOrWhiteSpace($Version)) {
    $Version = Get-PubspecVersion
}
$Version = Assert-VersionText -Value $Version

if ([string]::IsNullOrWhiteSpace($ReleaseAssetRoot)) {
    $ReleaseAssetRoot = Join-Path $repoRoot "ReleaseAssets"
}

$releaseDir = [System.IO.Path]::GetFullPath($ReleaseAssetRoot)
New-Item -ItemType Directory -Force -Path $releaseDir | Out-Null

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

$zipName = "UnrealBlueprintBridge-v$Version-win-x64.zip"
$zipPath = Join-Path $releaseDir $zipName
$shaPath = Join-Path $releaseDir "UnrealBlueprintBridge-v$Version-win-x64.sha256.txt"
$manifestPath = Join-Path $releaseDir "blueprint-bridge-update.json"
if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }

Compress-Archive -LiteralPath $programDir -DestinationPath $zipPath -Force
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
Write-Host "  Zip:      $zipPath"
Write-Host "  SHA-256:  $shaPath"
Write-Host "  Manifest: $manifestPath"
