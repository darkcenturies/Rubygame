# Free local deploy - run after: git push
# Requires: copy .deploy.env.example -> .deploy.env and fill in credentials
# Uses WinSCP if installed, otherwise OpenSSH scp (password prompted)

$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
$EnvFile = Join-Path $Root '.deploy.env'

if (-not (Test-Path $EnvFile)) {
    Write-Error "Missing .deploy.env - copy .deploy.env.example to .deploy.env and add your Shockbyte SFTP details."
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
Open Shockbyte panel -> Files -> SFTP Connect and copy the real username.
Use your Shockbyte control panel password for SFTP_PASSWORD.
"@
}

$pluginsLocal = Join-Path $Root 'plugins'
if (-not (Test-Path $pluginsLocal)) {
    Write-Error "plugins folder not found at $pluginsLocal"
}

$winScp = @(
    "${env:ProgramFiles}\WinSCP\WinSCP.com",
    "${env:ProgramFiles(x86)}\WinSCP\WinSCP.com"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($winScp) {
    $scriptFile = Join-Path $env:TEMP "rubygame-deploy-winscp.txt"
    $lines = @(
        'option batch abort',
        'option confirm off',
        "open sftp://${SFTP_USER}@${SFTP_HOST}:${SFTP_PORT}/ -hostkey=`"ssh-rsa 2048 RsvkKfFn1JlKW34Lqs8lqeyCIQC8JveU8JvuOH6ctc8=`" -password=$($SFTP_PASSWORD -replace '"','""')",
        'cd /Rubygame',
        "synchronize remote `"$pluginsLocal`" /plugins -delete=none",
        'exit'
    )
    $lines | Set-Content -Path $scriptFile -Encoding ASCII

    Write-Host 'Deploying with WinSCP to /Rubygame/plugins ...'
    & $winScp /ini=nul /script=$scriptFile
    $code = $LASTEXITCODE
    Remove-Item $scriptFile -Force
    if ($code -ne 0) { exit $code }
    Write-Host 'Done. Restart the server in Shockbyte if needed.'
    exit 0
}

Write-Host 'WinSCP not found. Using scp (you may be prompted for password)...'
$dest = "${SFTP_USER}@${SFTP_HOST}:Rubygame/plugins/"
& scp -P $SFTP_PORT -r "$pluginsLocal\*" $dest
Write-Host 'Done. Restart the server in Shockbyte if needed.'
