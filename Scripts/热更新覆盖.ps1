param(
    [Parameter(Mandatory = $true)][string]$AppProcessId,
    [Parameter(Mandatory = $true)][string]$InstallDir,
    [Parameter(Mandatory = $true)][string]$PackagePath,
    [Parameter(Mandatory = $true)][string]$ExpectedSha256,
    [Parameter(Mandatory = $true)][string]$ExeRelativePath,
    [Parameter(Mandatory = $true)][string]$ToolboxStableKey,
    [Parameter(Mandatory = $true)][string]$TargetVersion
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([int]$Percent, [string]$Message)
    Write-Progress -Activity "虚幻：蓝图连结热更新" -Status $Message -PercentComplete $Percent
    Write-Host ("[{0,3}%] {1}" -f $Percent, $Message)
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
    $files = @(Get-ChildItem -LiteralPath $SourceDir -Recurse -File -Force)
    $total = [Math]::Max($files.Count, 1)

    for ($index = 0; $index -lt $files.Count; $index++) {
        $file = $files[$index]
        $relative = $file.FullName.Substring($sourceFull.Length).TrimStart('\')
        $target = Join-Path $DestinationDir $relative
        Assert-Inside -BasePath $DestinationDir -ChildPath $target
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
        $percent = 58 + [int]([Math]::Floor((($index + 1) / $total) * 32))
        Write-Progress -Activity "虚幻：蓝图连结热更新" -Status "正在替换文件" -CurrentOperation $relative -PercentComplete $percent
        Copy-Item -LiteralPath $file.FullName -Destination $target -Force
    }
}

function Resolve-PackageSourceRoot {
    param([string]$StagingRoot, [string]$ToolboxStableKey, [string]$TargetVersion, [string]$EntryExe)
    $manifests = @(Get-ChildItem -LiteralPath $StagingRoot -Recurse -File -Filter "update-package.json")
    foreach ($manifestFile in $manifests) {
        Assert-Inside -BasePath $StagingRoot -ChildPath $manifestFile.FullName
        $manifest = Get-Content -LiteralPath $manifestFile.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($manifest.toolboxStableKey -ne $ToolboxStableKey) { continue }
        if ($manifest.version -ne $TargetVersion) { continue }
        $sourceRoot = Split-Path -Parent $manifestFile.FullName
        $entry = if ([string]::IsNullOrWhiteSpace($manifest.entryExe)) { $EntryExe } else { [string]$manifest.entryExe }
        if (Test-Path -LiteralPath (Join-Path $sourceRoot $entry) -PathType Leaf) {
            return $sourceRoot
        }
    }
    throw "更新包内没有找到匹配 $ToolboxStableKey / $TargetVersion 的程序目录。"
}

try {
    $installFull = [System.IO.Path]::GetFullPath($InstallDir)
    $packageFull = [System.IO.Path]::GetFullPath($PackagePath)
    if (!(Test-Path -LiteralPath $installFull -PathType Container)) { throw "程序目录不存在：$installFull" }
    if (!(Test-Path -LiteralPath $packageFull -PathType Leaf)) { throw "更新包不存在：$packageFull" }

    $logRoot = Join-Path $env:LOCALAPPDATA (Join-Path $ToolboxStableKey "UpdateLogs")
    New-Item -ItemType Directory -Force -Path $logRoot | Out-Null
    Start-Transcript -LiteralPath (Join-Path $logRoot ("Update-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))) | Out-Null

    Write-Step 10 "校验更新包 SHA-256"
    $actualSha = (Get-FileHash -LiteralPath $packageFull -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualSha -ne $ExpectedSha256.ToLowerInvariant()) { throw "SHA-256 不一致：$actualSha" }

    $stagingRoot = Join-Path $env:LOCALAPPDATA (Join-Path $ToolboxStableKey "UpdateStaging")
    if (Test-Path -LiteralPath $stagingRoot) { Remove-Item -LiteralPath $stagingRoot -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $stagingRoot | Out-Null

    Write-Step 28 "解压更新包"
    Expand-Archive -LiteralPath $packageFull -DestinationPath $stagingRoot -Force
    $sourceRoot = Resolve-PackageSourceRoot -StagingRoot $stagingRoot -ToolboxStableKey $ToolboxStableKey -TargetVersion $TargetVersion -EntryExe $ExeRelativePath

    Write-Step 48 "等待主程序退出"
    $process = Get-Process -Id ([int]$AppProcessId) -ErrorAction SilentlyContinue
    if ($null -ne $process) { $process.WaitForExit(30000) }
    if ($null -ne (Get-Process -Id ([int]$AppProcessId) -ErrorAction SilentlyContinue)) {
        throw "主程序未能在 30 秒内退出。"
    }

    Write-Step 58 "覆盖程序文件"
    Copy-DirectoryContents -SourceDir $sourceRoot -DestinationDir $installFull

    Write-Step 92 "清理临时文件"
    Remove-Item -LiteralPath $stagingRoot -Recurse -Force

    Write-Step 100 "更新完成"
    $exePath = Join-Path $installFull $ExeRelativePath
    Start-Process -FilePath $exePath -WorkingDirectory $installFull
}
catch {
    Write-Host "更新失败：$($_.Exception.Message)" -ForegroundColor Red
    Write-Host "按 Enter 关闭。"
    try { [void][System.Console]::ReadLine() } catch {}
    exit 1
}
finally {
    try { Stop-Transcript | Out-Null } catch {}
}
