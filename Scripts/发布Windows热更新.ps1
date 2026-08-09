param(
    [Parameter(Mandatory = $true)]
    [string]$Version,
    [string]$ReleaseNotes = ""
)

$ErrorActionPreference = "Stop"
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$normalizedVersion = $Version.Trim().TrimStart('v', 'V')
if ($normalizedVersion -notmatch '^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$') {
    throw "版本号格式无效：$Version。请使用 1.2.3 或 1.2.3-beta.1。"
}

$repository = "kirito0000001/UnrealBlueprintBridge"
$tag = "v$normalizedVersion"
$releaseRoot = Join-Path "D:\DabaoV" "虚幻蓝图连结V$normalizedVersion"
$downloadBaseUrl = "https://github.com/$repository/releases/download/$tag"

function Update-SourceVersion {
    $pubspecPath = Join-Path $repoRoot "pubspec.yaml"
    $pubspec = Get-Content -LiteralPath $pubspecPath -Raw -Encoding UTF8
    $current = [regex]::Match($pubspec, '(?m)^version:\s*[^\+\r\n]+(?:\+(?<build>\d+))?\s*$')
    if (!$current.Success) {
        throw "pubspec.yaml 缺少 version 字段。"
    }
    $nextBuild = if ([string]::IsNullOrWhiteSpace($current.Groups["build"].Value)) {
        1
    } else {
        [int]$current.Groups["build"].Value + 1
    }
    $pubspecVersionRegex = [regex]'(?m)^version:\s*[^\r\n]+$'
    $updatedPubspec = $pubspecVersionRegex.Replace(
        $pubspec,
        "version: $normalizedVersion+$nextBuild",
        1
    )
    [System.IO.File]::WriteAllText($pubspecPath, $updatedPubspec, [System.Text.UTF8Encoding]::new($false))

    $updateServicePath = Join-Path $repoRoot "lib\core\update\app_update_service.dart"
    $updateService = Get-Content -LiteralPath $updateServicePath -Raw -Encoding UTF8
    $appVersionRegex = [regex]"(?s)(String\.fromEnvironment\(\s*'APP_VERSION',\s*defaultValue:\s*')[^']+(')"
    $appVersionReplacement = '${1}' + $normalizedVersion + '${2}'
    $updatedService = $appVersionRegex.Replace(
        $updateService,
        $appVersionReplacement,
        1
    )
    [System.IO.File]::WriteAllText($updateServicePath, $updatedService, [System.Text.UTF8Encoding]::new($false))
}

Push-Location $repoRoot
try {
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & gh release view $tag --repo $repository *> $null
        $releaseExists = $LASTEXITCODE -eq 0
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    if ($releaseExists) {
        throw "GitHub Release $tag 已存在。请使用新的版本号。"
    }

    & (Join-Path $PSScriptRoot "打包Windows热更新.ps1") `
        -Version $normalizedVersion `
        -DownloadBaseUrl $downloadBaseUrl
    if ($LASTEXITCODE -ne 0) {
        throw "Windows 热更新包构建失败。"
    }

    $assets = @(
        (Join-Path $releaseRoot "blueprint-bridge-update.json"),
        (Join-Path $releaseRoot "UnrealBlueprintBridge-v$normalizedVersion-win-x64.sha256.txt"),
        (Join-Path $releaseRoot "UnrealBlueprintBridge-v$normalizedVersion-win-x64.zip")
    )
    foreach ($asset in $assets) {
        if (!(Test-Path -LiteralPath $asset -PathType Leaf)) {
            throw "发布资产不存在：$asset"
        }
    }

    $notes = if ([string]::IsNullOrWhiteSpace($ReleaseNotes)) {
        "虚幻蓝图连结 $normalizedVersion 更新。"
    } else {
        $ReleaseNotes.Trim()
    }
    & gh release create $tag @assets `
        --repo $repository `
        --title $tag `
        --notes $notes
    if ($LASTEXITCODE -ne 0) {
        throw "GitHub Release 上传失败。请确认 gh 已登录且当前代码已推送。"
    }

    Update-SourceVersion
    Write-Host "发布完成：$tag"
    Write-Host "发布目录：$releaseRoot"
} finally {
    Pop-Location
}
