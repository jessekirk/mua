$json = Invoke-RestMethod -Uri 'https://edgeupdates.microsoft.com/api/products?view=enterprise'

$version = $json | Where-Object { $_.product -eq 'stable' } | Select-Object -ExpandProperty releases | Select-Object | Where-Object { $_.platform -eq 'windows' -and $_.architecture -eq 'x64' } `
| Select-Object -First 1 | Select-Object -ExpandProperty productversion

$urilocation = $json | Where-Object { $_.product -eq 'stable' } | Select-Object -ExpandProperty releases | Select-Object | Where-Object { $_.platform -eq 'windows' -and $_.architecture -eq 'x64' } `
| Select-Object -First 1 | Select-Object -ExpandProperty artifacts | Select-Object -ExpandProperty location

if ($ShowVersion.IsPresent) { return Write-Host -Object "latest edge : $version" -ForegroundColor Cyan }
$path = Join-Path -Path $HOME -ChildPath "desktop/Microsoft Edge v$version" ; New-Item -Path $path -ItemType Directory | Out-Null

$filename = $urilocation | Split-Path -Leaf ; Start-BitsTransfer -Source $urilocation -Destination (Join-Path -Path $path -ChildPath $filename) ; Write-Host -Object 'done!' -ForegroundColor Cyan