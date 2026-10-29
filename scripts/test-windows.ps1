# Windows check of the WSL rootfs tarball. Uses the tar.exe shipped with Windows.
param(
  [Parameter(Mandatory = $true)][string]$Tar
)
$ErrorActionPreference = "Stop"
if (-not (Test-Path $Tar)) { throw "missing $Tar" }
$names = & tar.exe -tzf $Tar
if ($LASTEXITCODE -ne 0) { throw "tar list failed" }
$need = @("etc/wsl.conf", "etc/os-release", "usr/bin/bash")
foreach ($path in $need) {
  $hit = $names | Where-Object { $_ -eq $path -or $_ -eq "./$path" }
  if (-not $hit) { throw "missing $path" }
}
Write-Output "windows tar ok"
