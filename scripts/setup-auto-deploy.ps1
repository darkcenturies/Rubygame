# One-time: enable local deploy after every git push (uses your PC IP — works with Shockbyte)
$repoRoot = Split-Path $PSScriptRoot -Parent
Set-Location $repoRoot

if (-not (Test-Path ".deploy.env")) {
    Copy-Item ".deploy.env.example" ".deploy.env"
    Write-Host "Created .deploy.env - edit with real SFTP user from Shockbyte Files -> SFTP Connect (not the example text)."
    notepad ".deploy.env"
    exit 1
}

$envText = Get-Content ".deploy.env" -Raw
if ($envText -match 'your_username_from_shockbyte|your_shockbyte_panel_password') {
    Write-Host ".deploy.env still has placeholders - fill SFTP_USER and SFTP_PASSWORD, then run this script again."
    notepad ".deploy.env"
    exit 1
}

git config core.hooksPath .githooks
Write-Host "Git hooks enabled. After 'git push', plugins will upload via WinSCP automatically."
Write-Host "Test now: git push (or run .\\deploy.ps1 manually)"
