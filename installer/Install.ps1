param(
    [ValidateSet('Install','Restore','Check')][string]$Action = 'Install',
    [string]$GamePath,
    [string]$PackageRoot = (Split-Path -Parent $PSScriptRoot),
    [switch]$NoUi,
    [switch]$InspectUi
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'InstallerCore.psm1') -Force -DisableNameChecking

if (-not $GamePath) {
    $candidates = @(Find-WotRGame)
    if ($candidates.Count -eq 1) { $GamePath = $candidates[0] }
}
if ($NoUi) {
    try {
        if ($Action -eq 'Check') { $result = Get-WotRStatus -GamePath $GamePath -PackageRoot $PackageRoot }
        else { $result = Invoke-WotRTranslation -Action $Action -GamePath $GamePath -PackageRoot $PackageRoot }
        [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
        $result | ConvertTo-Json -Depth 4
        exit 0
    } catch {
        [Console]::Error.WriteLine($_.Exception.Message)
        exit 1
    }
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
$form = [Windows.Forms.Form]::new()
$form.Text = 'Pathfinder WotR 日本語翻訳MOD'
$form.ClientSize = [Drawing.Size]::new(760, 375)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.Font = [Drawing.Font]::new('Meiryo UI', 10)

$title = [Windows.Forms.Label]::new()
$title.Text = '日本語翻訳MODの導入・復元'
$title.Font = [Drawing.Font]::new('Meiryo UI', 15)
$title.SetBounds(20, 15, 720, 35)
$form.Controls.Add($title)
$intro = [Windows.Forms.Label]::new()
$intro.Text = "ゲームを終了してから実行してください。元の翻訳ファイルは自動で保存します。"
$intro.SetBounds(20, 62, 720, 30)
$form.Controls.Add($intro)
$folderLabel = [Windows.Forms.Label]::new()
$folderLabel.Text = 'ゲームのフォルダ'
$folderLabel.SetBounds(20, 101, 600, 22)
$form.Controls.Add($folderLabel)
$pathBox = [Windows.Forms.TextBox]::new()
$pathBox.ReadOnly = $true
$pathBox.SetBounds(20, 126, 590, 28)
$pathBox.Text = $GamePath
$form.Controls.Add($pathBox)
$browse = [Windows.Forms.Button]::new()
$browse.Text = '選択...'
$browse.SetBounds(625, 123, 115, 32)
$form.Controls.Add($browse)
$statusLabel = [Windows.Forms.Label]::new()
$statusLabel.BorderStyle = 'FixedSingle'
$statusLabel.BackColor = [Drawing.Color]::WhiteSmoke
$statusLabel.Padding = [Windows.Forms.Padding]::new(10)
$statusLabel.SetBounds(20, 172, 720, 75)
$form.Controls.Add($statusLabel)
$installButton = [Windows.Forms.Button]::new()
$installButton.Text = '日本語を導入'
$installButton.SetBounds(20, 263, 190, 42)
$form.Controls.Add($installButton)
$restoreButton = [Windows.Forms.Button]::new()
$restoreButton.Text = '導入前に戻す'
$restoreButton.SetBounds(225, 263, 190, 42)
$form.Controls.Add($restoreButton)
$close = [Windows.Forms.Button]::new()
$close.Text = '閉じる'
$close.SetBounds(625, 263, 115, 42)
$close.Add_Click({ $form.Close() })
$form.Controls.Add($close)
$note = [Windows.Forms.Label]::new()
$note.Text = '導入後はゲームの言語を「简体中文」にしてください。日本語フォント設定は別途必要です。'
$note.SetBounds(20, 326, 720, 44)
$form.Controls.Add($note)
$script:Busy = $false

function Update-InstallStatus {
    $installButton.Enabled = $false
    $restoreButton.Enabled = $false
    if (-not $pathBox.Text) {
        $statusLabel.Text = 'ゲームのフォルダを選んでください。Steam版は自動で検出します。'
        return
    }
    try {
        $state = Get-WotRStatus -GamePath $pathBox.Text -PackageRoot $PackageRoot
        if ($state.Running) { $statusLabel.Text = 'ゲームを終了してから、フォルダを選び直してください。'; return }
        if (-not $state.CurrentRecognized) {
            $statusLabel.Text = '導入後に別の変更が見つかりました。その変更を保護するため上書きしません。'
            return
        }
        $installButton.Enabled = $state.Compatible -and $state.PackageValid -and -not $state.Installed
        $restoreButton.Enabled = $state.CanRestore
        if (-not $state.Compatible) {
            $statusLabel.Text = 'この翻訳が対応するゲーム版と異なります。対応版の翻訳を用意してください。'
        } elseif (-not $state.PackageValid) {
            $statusLabel.Text = '翻訳ファイルが不足しているか壊れています。ZIPを展開し直してください。'
            if ($state.CanRestore) { $statusLabel.Text += ' バックアップからの復元は利用できます。' }
        } elseif ($state.Installed) {
            $statusLabel.Text = 'すでにこの版の日本語翻訳MODが入っています。'
            if (-not $state.BackupAvailable) { $statusLabel.Text += ' このツールの復元用バックアップはありません。' }
        } else {
            $statusLabel.Text = '導入できます。「日本語を導入」を押してください。初回のファイルはバックアップに残します。'
        }
    } catch { $statusLabel.Text = $_.Exception.Message }
}

function Invoke-InstallAction([string]$Mode) {
    $script:Busy = $true
    $installButton.Enabled = $false
    $restoreButton.Enabled = $false
    $browse.Enabled = $false
    $close.Enabled = $false
    $form.UseWaitCursor = $true
    $statusLabel.Text = '処理しています...'
    $form.Refresh()
    try {
        $result = Invoke-WotRTranslation -Action $Mode -GamePath $pathBox.Text -PackageRoot $PackageRoot
        $message = switch ($result.Status) {
            'Installed' { '日本語翻訳MODを導入しました。ゲームの言語を「简体中文」にして起動してください。' }
            'Restored' { '初回導入前のファイルに戻しました。バックアップは保持しています。' }
            'AlreadyInstalled' { 'すでにこの版の日本語翻訳MODが入っています。' }
            'AlreadyRestored' { 'すでに初回導入前のファイルに戻っています。' }
        }
        [void][Windows.Forms.MessageBox]::Show($form, $message, '完了', 'OK', 'Information')
    } catch {
        [void][Windows.Forms.MessageBox]::Show($form, $_.Exception.Message, '処理を中止しました', 'OK', 'Warning')
    } finally {
        $script:Busy = $false
        $form.UseWaitCursor = $false
        $browse.Enabled = $true
        $close.Enabled = $true
        Update-InstallStatus
    }
}

$browse.Add_Click({
    $dialog = [Windows.Forms.FolderBrowserDialog]::new()
    $dialog.Description = 'Wrath.exeが入っているゲーム本体のフォルダを選んでください。'
    $dialog.ShowNewFolderButton = $false
    if ($pathBox.Text) { $dialog.SelectedPath = $pathBox.Text }
    try {
        if ($dialog.ShowDialog($form) -eq [Windows.Forms.DialogResult]::OK) {
            $pathBox.Text = $dialog.SelectedPath
            Update-InstallStatus
        }
    } finally { $dialog.Dispose() }
})
$installButton.Add_Click({ Invoke-InstallAction 'Install' })
$restoreButton.Add_Click({ Invoke-InstallAction 'Restore' })
$form.Add_FormClosing({ param($sender, $eventArgs); if ($script:Busy) { $eventArgs.Cancel = $true } })
$form.AcceptButton = if ($Action -eq 'Restore') { $restoreButton } else { $installButton }
$form.CancelButton = $close
Update-InstallStatus
try {
    if ($InspectUi) {
        $form.PerformLayout()
        [pscustomobject]@{ UiConstructed=$true; Visible=$form.Visible; Controls=$form.Controls.Count } | ConvertTo-Json
    } else { [void]$form.ShowDialog() }
} finally { $form.Dispose() }
