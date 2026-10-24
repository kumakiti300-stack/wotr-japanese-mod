Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$script:RelativeTarget = 'Wrath_Data\StreamingAssets\Localization\zhCN.json'

function Get-FileDigest([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Assert-PlainPath([string]$Path) {
    if (Test-Path -LiteralPath $Path) {
        $item = Get-Item -LiteralPath $Path -Force
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw 'リンク先のフォルダは使えません。ゲームの実体フォルダを選んでください。'
        }
    }
}

function Get-GamePaths([string]$GamePath) {
    if ([string]::IsNullOrWhiteSpace($GamePath)) { throw 'ゲームのフォルダを選んでください。' }
    $root = [IO.Path]::GetFullPath($GamePath).TrimEnd([char[]]'\/')
    foreach ($part in @('', 'Wrath_Data', 'Wrath_Data\StreamingAssets',
        'Wrath_Data\StreamingAssets\Localization', 'Wrath.exe',
        $script:RelativeTarget, 'Wrath_Data\StreamingAssets\Localization\enGB.json')) {
        $path = if ($part) { Join-Path $root $part } else { $root }
        Assert-PlainPath $path
        if (-not (Test-Path -LiteralPath $path)) {
            throw 'ゲーム本体のフォルダを選んでください（Wrath.exeがある場所です）。'
        }
    }
    $backup = Join-Path $root 'WotR-Japanese-Backup'
    foreach ($path in @($backup, (Join-Path $backup 'original.zhCN.json'), (Join-Path $backup 'state.json'))) {
        Assert-PlainPath $path
    }
    return [pscustomobject]@{
        Root=$root; Target=(Join-Path $root $script:RelativeTarget)
        English=(Join-Path $root 'Wrath_Data\StreamingAssets\Localization\enGB.json')
        Backup=$backup; Original=(Join-Path $backup 'original.zhCN.json')
        State=(Join-Path $backup 'state.json')
    }
}

function Get-PackageInfo([string]$PackageRoot) {
    $root = [IO.Path]::GetFullPath($PackageRoot)
    $config = Join-Path $root 'installer\package.json'
    if (Test-Path -LiteralPath $config -PathType Leaf) {
        $info = Get-Content -LiteralPath $config -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($info.product -ne 'wotr-japanese' -or $info.schema_version -ne 1) {
            throw '導入ファイルの情報が正しくありません。ZIPを展開し直してください。'
        }
    } else {
        # The source-code ZIP also works, without Python.
        $project = Get-Content -LiteralPath (Join-Path $root 'metadata\project.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        $info = [pscustomobject]@{
            game_version=$project.game_version; translation_sha256=$project.artifact_sha256
            english_sha256=$project.official_english_sha256
        }
    }
    foreach ($value in @($info.translation_sha256, $info.english_sha256)) {
        if ($value -notmatch '^[a-f0-9]{64}$') { throw '導入ファイルの検証情報が正しくありません。' }
    }
    $payload = Join-Path $root 'translations\zhCN.json'
    $payloadValid = (Test-Path -LiteralPath $payload -PathType Leaf) -and
        (Get-FileDigest $payload) -eq $info.translation_sha256
    return [pscustomobject]@{
        Payload=$payload; Hash=$info.translation_sha256; PayloadValid=[bool]$payloadValid
        EnglishHash=$info.english_sha256; GameVersion=$info.game_version
    }
}

function Read-BackupState($Paths) {
    if (-not (Test-Path -LiteralPath $Paths.State -PathType Leaf)) {
        if ((Test-Path -LiteralPath $Paths.Backup) -and
            @(Get-ChildItem -LiteralPath $Paths.Backup -Force).Count -gt 0) {
            throw '未完了または別形式のバックアップがあります。元のファイルを保護するため中止しました。'
        }
        return $null
    }
    $state = Get-Content -LiteralPath $Paths.State -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($state.product -ne 'wotr-japanese-backup' -or $state.schema_version -ne 1 -or
        $state.target -ne $script:RelativeTarget -or $state.original_sha256 -notmatch '^[a-f0-9]{64}$' -or
        $state.english_sha256 -notmatch '^[a-f0-9]{64}$') {
        throw 'バックアップ情報を確認できません。ファイルを保護するため中止しました。'
    }
    foreach ($hash in @($state.recognized_sha256)) {
        if ($hash -notmatch '^[a-f0-9]{64}$') { throw 'バックアップの履歴情報が正しくありません。' }
    }
    if (-not (Test-Path -LiteralPath $Paths.Original -PathType Leaf) -or
        (Get-FileDigest $Paths.Original) -ne $state.original_sha256) {
        throw '導入前のバックアップが不足しているか壊れています。上書きせず中止しました。'
    }
    return $state
}

function Test-GameRunning($Paths) {
    $exe = Join-Path $Paths.Root 'Wrath.exe'
    foreach ($process in @(Get-Process -Name Wrath -ErrorAction SilentlyContinue)) {
        try { $location = $process.Path } catch { $location = $null }
        if (-not $location -or [string]::Equals($location, $exe, [StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }
    return $false
}

function Get-WotRStatus {
    param([Parameter(Mandatory=$true)][string]$GamePath,
          [Parameter(Mandatory=$true)][string]$PackageRoot)
    $paths = Get-GamePaths $GamePath
    $info = Get-PackageInfo $PackageRoot
    $state = Read-BackupState $paths
    $currentHash = Get-FileDigest $paths.Target
    $englishHash = Get-FileDigest $paths.English
    $known = -not $state -or $currentHash -eq $state.original_sha256 -or
        @($state.recognized_sha256) -contains $currentHash
    return [pscustomobject]@{
        GamePath=$paths.Root; Compatible=($englishHash -eq $info.EnglishHash)
        Installed=($currentHash -eq $info.Hash); PackageValid=$info.PayloadValid; BackupAvailable=[bool]$state
        CurrentRecognized=[bool]$known; Running=(Test-GameRunning $paths)
        CanRestore=[bool]($state -and $known -and $englishHash -eq $state.english_sha256)
    }
}

function Write-AtomicBytes([string]$Path, [byte[]]$Bytes) {
    $temporary = $Path + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
    try {
        [IO.File]::WriteAllBytes($temporary, $Bytes)
        if ([IO.File]::Exists($Path)) { [IO.File]::Replace($temporary, $Path, [NullString]::Value) }
        else { [IO.File]::Move($temporary, $Path) }
    } finally {
        if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) }
    }
}

function Write-BackupState($Paths, $State) {
    $text = ($State | ConvertTo-Json -Depth 6) + [Environment]::NewLine
    Write-AtomicBytes $Paths.State ([Text.UTF8Encoding]::new($false).GetBytes($text))
}

function Invoke-WotRTranslation {
    param([Parameter(Mandatory=$true)][ValidateSet('Install','Restore')][string]$Action,
          [Parameter(Mandatory=$true)][string]$GamePath,
          [Parameter(Mandatory=$true)][string]$PackageRoot)
    $paths = Get-GamePaths $GamePath
    $info = $null
    if ($Action -eq 'Install') {
        $info = Get-PackageInfo $PackageRoot
        if (-not $info.PayloadValid) { throw '翻訳ファイルが不足しているか壊れています。ZIPを展開し直してください。' }
    }
    if (Test-GameRunning $paths) { throw 'ゲームを終了してから実行してください。' }
    $hashTool = [Security.Cryptography.SHA256]::Create()
    try {
        $lockHash = [BitConverter]::ToString($hashTool.ComputeHash(
            [Text.Encoding]::UTF8.GetBytes($paths.Root.ToUpperInvariant()))).Replace('-', '')
    } finally { $hashTool.Dispose() }
    $mutex = [Threading.Mutex]::new($false, ('Local\WotRJapanese-' + $lockHash.Substring(0, 24)))
    $locked = $false
    try {
        try { $locked = $mutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $locked = $true }
        if (-not $locked) { throw '別の導入・復元処理が動いています。終了してから実行してください。' }
        $state = Read-BackupState $paths
        $beforeHash = Get-FileDigest $paths.Target
        $englishHash = Get-FileDigest $paths.English
        if ($Action -eq 'Install' -and $englishHash -ne $info.EnglishHash) {
            throw 'この翻訳が対応するゲーム版と異なります。適用せず中止しました。'
        }
        if ($state -and $englishHash -ne $state.english_sha256) {
            throw 'バックアップ作成後にゲーム版が変わっています。自動での上書き・復元を中止しました。'
        }
        if ($state -and $beforeHash -ne $state.original_sha256 -and
            @($state.recognized_sha256) -notcontains $beforeHash) {
            throw '導入後に別の変更が見つかりました。その変更を保護するため中止しました。'
        }
        if ($Action -eq 'Install' -and $beforeHash -eq $info.Hash) {
            return [pscustomobject]@{ Status='AlreadyInstalled'; BackupAvailable=[bool]$state }
        }
        if ($Action -eq 'Restore') {
            if (-not $state) { throw 'このツールで作成したバックアップがありません。自動では元に戻せません。' }
            if ($beforeHash -eq $state.original_sha256) {
                return [pscustomobject]@{ Status='AlreadyRestored'; BackupAvailable=$true }
            }
            $source = $paths.Original
            $expected = $state.original_sha256
        } else {
            $source = $info.Payload
            $expected = $info.Hash
        }
        $oldState = if ([IO.File]::Exists($paths.State)) { [IO.File]::ReadAllBytes($paths.State) } else { $null }
        if (-not $state) {
            [void][IO.Directory]::CreateDirectory($paths.Backup)
            [IO.File]::Copy($paths.Target, $paths.Original, $false)
            if ((Get-FileDigest $paths.Original) -ne $beforeHash) { throw 'バックアップの照合に失敗しました。' }
            $state = [pscustomobject]@{
                product='wotr-japanese-backup'; schema_version=1
                target=$script:RelativeTarget; original_sha256=$beforeHash
                english_sha256=$englishHash; recognized_sha256=@()
                last_action='Prepared'; updated_at=[DateTime]::UtcNow.ToString('o')
            }
        }
        if ($Action -eq 'Install') {
            $state.recognized_sha256 = @(@($state.recognized_sha256) + $info.Hash | Select-Object -Unique)
        }
        $state.last_action = 'Prepared'
        Write-BackupState $paths $state
        $token = [guid]::NewGuid().ToString('N')
        $prepared = $paths.Target + '.japanese-' + $token + '.tmp'
        $rollback = Join-Path $paths.Backup ('rollback-' + $token + '.tmp')
        $replaced = $false
        $completed = $false
        try {
            [IO.File]::Copy($source, $prepared, $false)
            if ((Get-FileDigest $prepared) -ne $expected -or (Get-FileDigest $paths.Target) -ne $beforeHash) {
                throw '処理中にファイルが変わりました。適用せず中止しました。'
            }
            if (Test-GameRunning $paths) { throw 'ゲームを終了してから実行してください。' }
            [IO.File]::Replace($prepared, $paths.Target, $rollback)
            $replaced = $true
            if ((Get-FileDigest $rollback) -ne $beforeHash) { throw '処理中に別の変更が見つかりました。適用を取り消します。' }
            if ((Get-FileDigest $paths.Target) -ne $expected) { throw '適用後の照合に失敗しました。' }
            $state.last_action = $Action
            $state.updated_at = [DateTime]::UtcNow.ToString('o')
            Write-BackupState $paths $state
            $completed = $true
        } catch {
            $failure = $_
            if ($replaced -and [IO.File]::Exists($rollback)) {
                $rollbackHash = Get-FileDigest $rollback
                [IO.File]::Replace($rollback, $paths.Target, [NullString]::Value)
                if ((Get-FileDigest $paths.Target) -ne $rollbackHash) { throw '処理を戻せませんでした。バックアップを保持して中止しました。' }
            }
            if ($null -ne $oldState) { Write-AtomicBytes $paths.State $oldState }
            throw $failure
        } finally {
            if ([IO.File]::Exists($prepared)) { [IO.File]::Delete($prepared) }
            # Preserve a recovery copy if rollback itself failed.
            if ($completed -and [IO.File]::Exists($rollback)) { [IO.File]::Delete($rollback) }
        }
        return [pscustomobject]@{
            Status=$(if ($Action -eq 'Install') { 'Installed' } else { 'Restored' })
            BackupAvailable=$true
        }
    } finally {
        if ($locked) { $mutex.ReleaseMutex() }
        $mutex.Dispose()
    }
}

function Find-WotRGame {
    $steamRoots = @()
    foreach ($registry in @('HKCU:\Software\Valve\Steam', 'HKLM:\SOFTWARE\Valve\Steam',
        'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam')) {
        $entry = Get-ItemProperty -LiteralPath $registry -ErrorAction SilentlyContinue
        if ($entry) {
            foreach ($key in @('SteamPath','InstallPath')) {
                if ($entry.PSObject.Properties[$key] -and $entry.$key) { $steamRoots += [string]$entry.$key }
            }
        }
    }
    $programFiles86 = [Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
    if ($programFiles86) { $steamRoots += (Join-Path $programFiles86 'Steam') }
    if ($env:ProgramFiles) { $steamRoots += (Join-Path $env:ProgramFiles 'Steam') }
    $libraries = @($steamRoots)
    foreach ($steamRoot in @($steamRoots | Select-Object -Unique)) {
        $file = Join-Path $steamRoot 'steamapps\libraryfolders.vdf'
        if (Test-Path -LiteralPath $file -PathType Leaf) {
            $data = [IO.File]::ReadAllText($file)
            foreach ($match in [regex]::Matches($data, '"path"\s*"((?:\\.|[^"\\])*)"')) {
                $libraries += $match.Groups[1].Value.Replace('\\', '\')
            }
        }
    }
    $found = @()
    foreach ($library in @($libraries | Select-Object -Unique)) {
        $manifest = Join-Path $library 'steamapps\appmanifest_1184370.acf'
        if (-not (Test-Path -LiteralPath $manifest -PathType Leaf)) { continue }
        $match = [regex]::Match([IO.File]::ReadAllText($manifest), '"installdir"\s*"([^"]+)"')
        if (-not $match.Success) { continue }
        $relative = $match.Groups[1].Value
        if ($relative -match '[:\\/]|\.\.') { continue }
        $candidate = Join-Path (Join-Path $library 'steamapps\common') $relative
        try { $found += (Get-GamePaths $candidate).Root } catch { }
    }
    return @($found | Select-Object -Unique)
}

Export-ModuleMember -Function Find-WotRGame,Get-WotRStatus,Invoke-WotRTranslation
