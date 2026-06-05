# Deploy plugins to Shockbyte after git push. Requires WinSCP + .deploy.env
# Usage:  git push   then   .\deploy.ps1

$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
$EnvFile = Join-Path $Root '.deploy.env'

if (-not (Test-Path $EnvFile)) {
    Write-Error "Missing .deploy.env — copy .deploy.env.example to .deploy.env and add Shockbyte SFTP details."
}

Get-Content $EnvFile | ForEach-Object {
    if ($_ -match '^\s*([^#=]+)=(.*)$') {
        Set-Variable -Name $matches[1].Trim() -Value $matches[2].Trim() -Scope Script
    }
}

$placeholders = @(
    'your_username_from_shockbyte_sftp_connect_page',
    'your_shockbyte_panel_password'
)
if ($placeholders -contains $SFTP_USER -or $placeholders -contains $SFTP_PASSWORD) {
    Write-Error @"
.deploy.env still has example placeholders.
Shockbyte panel -> Files -> SFTP Connect: copy the username and use your panel password.
"@
}

$pluginsLocal = Join-Path $Root 'plugins'
if (-not (Test-Path $pluginsLocal)) {
    Write-Error "plugins folder not found at $pluginsLocal"
}

# Full remote plugins path. Override if WinSCP shows a different folder at SFTP root
# (e.g. REMOTE_PLUGINS_PATH=/1. Rubygame/plugins if the root entry is "1. Rubygame").
if (-not $REMOTE_PLUGINS_PATH) {
    $REMOTE_PLUGINS_PATH = '/Rubygame/plugins'
}
$remotePlugins = $REMOTE_PLUGINS_PATH.TrimEnd('/')

$winScp = @(
    "${env:ProgramFiles}\WinSCP\WinSCP.com",
    "${env:ProgramFiles(x86)}\WinSCP\WinSCP.com"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $winScp) {
    Write-Error @"
WinSCP is required. Install from https://winscp.net/eng/download.php
Then run this script again.
"@
}

$escapedPassword = $SFTP_PASSWORD -replace '"', '""'
$scriptFile = Join-Path $env:TEMP "rubygame-deploy-winscp.txt"
$lines = @(
    'option batch abort',
    'option confirm off',
    "open sftp://${SFTP_USER}@${SFTP_HOST}:${SFTP_PORT}/ -hostkey=`"ssh-rsa 2048 RsvkKfFn1JlKW34Lqs8lqeyCIQC8JveU8JvuOH6ctc8=`" -password=$escapedPassword",
    "synchronize remote `"$pluginsLocal`" `"$remotePlugins`" -delete=none",
    'exit'
)
$lines | Set-Content -Path $scriptFile -Encoding ASCII

Write-Host "Deploying plugins -> $remotePlugins (WinSCP)..."
& $winScp /ini=nul /script=$scriptFile
$code = $LASTEXITCODE
Remove-Item $scriptFile -Force -ErrorAction SilentlyContinue
if ($code -ne 0) {
    Write-Error @"
WinSCP deploy failed (exit $code).
In WinSCP, open SFTP and note the exact server folder name at root (e.g. ""1. Rubygame"").
Set in .deploy.env:  REMOTE_PLUGINS_PATH=/ThatFolder/plugins
"@
}
Write-Host 'Done. Restart the Minecraft server in the Shockbyte panel if needed.'
