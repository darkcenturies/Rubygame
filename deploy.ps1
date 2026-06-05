# Free local deploy — run after: git push
# Requires: copy .deploy.env.example -> .deploy.env and fill in credentials
# Uses WinSCP if installed, otherwise OpenSSH scp (password prompted)

$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
$EnvFile = Join-Path $Root '.deploy.env'

if (-not (Test-Path $EnvFile)) {
    Write-Error "Missing .deploy.env — copy .deploy.env.example to .deploy.env and add your Shockbyte SFTP details."
}

Get-Content $EnvFile | ForEach-Object {
    if ($_ -match '^\s*([^#=]+)=(.*)$') {
        Set-Variable -Name $matches[1].Trim() -Value $matches[2].Trim() -Scope Script
    }
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
    @"
option batch abort
option confirm off
open sftp://${SFTP_USER}@${SFTP_HOST}:${SFTP_PORT}/ -password=${SFTP_PASSWORD}
cd /
synchronize remote "$pluginsLocal" /plugins -delete=none
exit
"@ | Set-Content -Path $scriptFile -Encoding ASCII

    Write-Host "Deploying with WinSCP..."
    & $winScp /ini=nul /script=$scriptFile
    Remove-Item $scriptFile -Force
    Write-Host "Done. Restart the server in Shockbyte if needed."
    exit $LASTEXITCODE
}

Write-Host "WinSCP not found. Using scp (you may be prompted for password)..."
$dest = "${SFTP_USER}@${SFTP_HOST}:/plugins/"
& scp -P $SFTP_PORT -r "$pluginsLocal\*" $dest
Write-Host "Done. Restart the server in Shockbyte if needed."
