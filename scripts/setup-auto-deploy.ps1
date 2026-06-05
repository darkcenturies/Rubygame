# One-time: enable local deploy after every git push (uses your PC IP — works with Shockbyte)
$repoRoot = Split-Path $PSScriptRoot -Parent
Set-Location $repoRoot

if (-not (Test-Path ".deploy.env")) {
    Copy-Item ".deploy.env.example" ".deploy.env"
    Write-Host "Created .deploy.env — edit it with your Shockbyte SFTP user/password, then run this script again."
    notepad ".deploy.env"
    exit 1
}

git config core.hooksPath .githooks
Write-Host "Git hooks enabled. After 'git push', plugins will upload via WinSCP automatically."
Write-Host "Test now: git push (or run .\\deploy.ps1 manually)"
