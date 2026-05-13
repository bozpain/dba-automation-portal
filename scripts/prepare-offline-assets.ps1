param(
    [string]$SemaphoreVersion = "2.17.26",
    [string]$Architecture = "amd64",
    [string]$SourceRoot,
    [switch]$SkipSemaphoreDownload
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PortalRoot = (Resolve-Path (Join-Path $ScriptDir "..")).Path
if (-not $SourceRoot) {
    $SourceRoot = (Resolve-Path (Join-Path $PortalRoot "..")).Path
}

$AssetsDir = Join-Path $PortalRoot "assets"
$RepoAssetsDir = Join-Path $AssetsDir "repos"
$ChecksumDir = Join-Path $AssetsDir "checksums"
New-Item -ItemType Directory -Force -Path $AssetsDir, $RepoAssetsDir, $ChecksumDir | Out-Null

if (-not $SkipSemaphoreDownload) {
    $FileName = "semaphore_${SemaphoreVersion}_linux_${Architecture}.tar.gz"
    $Url = "https://github.com/semaphoreui/semaphore/releases/download/v${SemaphoreVersion}/${FileName}"
    $Output = Join-Path $AssetsDir $FileName

    Write-Host "Downloading Semaphore UI $SemaphoreVersion ($Architecture)"
    Write-Host $Url
    Invoke-WebRequest -Uri $Url -OutFile $Output

    $Hash = Get-FileHash -Algorithm SHA256 -Path $Output
    $HashLine = "$($Hash.Hash.ToLower())  $FileName"
    $HashPath = Join-Path $ChecksumDir "$FileName.sha256"
    Set-Content -Path $HashPath -Value $HashLine -Encoding ascii
    Write-Host "Checksum written to $HashPath"
}

$Projects = @(
    "oracle-install-replication-framework",
    "oracle-replication-framework",
    "oracle-patch-framework"
)

foreach ($Project in $Projects) {
    $ProjectPath = Join-Path $SourceRoot $Project
    if (-not (Test-Path (Join-Path $ProjectPath ".git"))) {
        Write-Warning "Skipping $Project because $ProjectPath is not a git repository."
        continue
    }

    $BundlePath = Join-Path $RepoAssetsDir "$Project.bundle"
    $SnapshotPath = Join-Path $RepoAssetsDir "$Project.worktree.tar.gz"
    Write-Host "Creating bundle $BundlePath"
    & git -c "safe.directory=$ProjectPath" -C $ProjectPath bundle create $BundlePath --all
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create git bundle for $Project"
    }

    $Hash = Get-FileHash -Algorithm SHA256 -Path $BundlePath
    Set-Content -Path (Join-Path $ChecksumDir "$Project.bundle.sha256") -Value "$($Hash.Hash.ToLower())  $Project.bundle" -Encoding ascii

    Write-Host "Creating worktree snapshot $SnapshotPath"
    & tar `
        --exclude=.git `
        --exclude=__pycache__ `
        --exclude=.pytest_cache `
        --exclude=.mypy_cache `
        --exclude=.ruff_cache `
        --exclude=runtime `
        --exclude=repo `
        --exclude=sources `
        --exclude=source `
        --exclude=staging `
        --exclude=tmp `
        --exclude=temp `
        --exclude='tmp*' `
        --exclude='temp*' `
        --exclude='tmpl*' `
        -czf $SnapshotPath `
        -C $ProjectPath `
        .
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create worktree snapshot for $Project"
    }

    $SnapshotHash = Get-FileHash -Algorithm SHA256 -Path $SnapshotPath
    Set-Content -Path (Join-Path $ChecksumDir "$Project.worktree.tar.gz.sha256") -Value "$($SnapshotHash.Hash.ToLower())  $Project.worktree.tar.gz" -Encoding ascii
}

Write-Host "Offline assets are ready under $AssetsDir"
