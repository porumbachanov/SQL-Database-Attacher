$ErrorActionPreference = "Stop"

Write-Host "Installing dbatools..." -ForegroundColor Cyan

Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

if (-not (Get-Module -ListAvailable -Name dbatools)) {
    Install-Module dbatools -Scope CurrentUser -Force -AllowClobber
    Write-Host "✓ dbatools installed" -ForegroundColor Green
} else {
    Update-Module dbatools -Force
    Write-Host "✓ dbatools updated" -ForegroundColor Green
}

Write-Host "Installation complete! dbatools is ready to use." -ForegroundColor Green