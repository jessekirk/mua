$ProgressPreference = 'SilentlyContinue' ; $json = Invoke-RestMethod -Uri 'https://edgeupdates.microsoft.com/api/products?view=enterprise'

$version = $json | Where-Object { $_.product -eq 'stable' } | Select-Object -ExpandProperty releases | Select-Object | Where-Object { $_.platform -eq 'windows' -and $_.architecture -eq 'x64' } `
| Select-Object -First 1 | Select-Object -ExpandProperty productversion

$previousversion = $json | Where-Object { $_.product -eq 'stable' } | Select-Object -ExpandProperty releases | Select-Object | Where-Object { $_.platform -eq 'windows' -and $_.architecture -eq 'x64' } `
| Select-Object -First 2 | Select-Object -Last 1 | Select-Object -ExpandProperty productversion

$urilocation = $json | Where-Object { $_.product -eq 'stable' } | Select-Object -ExpandProperty releases | Select-Object | Where-Object { $_.platform -eq 'windows' -and $_.architecture -eq 'x64' } `
| Select-Object -First 1 | Select-Object -ExpandProperty artifacts | Select-Object -ExpandProperty location

if ($showVersion.IsPresent) { return Write-Host -Object "latest v$version (prev. v$previousversion)" -ForegroundColor Cyan }
$path = "$($HOME)\desktop\Microsoft Edge v$version" ; New-Item -Path $path -ItemType Directory -ErrorAction SilentlyContinue | Out-Null

$filename = $urilocation | Split-Path -Leaf ; Write-Verbose -Message "Downloading $filename v$version" -Verbose ; Start-Sleep -Milliseconds 250
Start-BitsTransfer -Source $urilocation -Destination $path\$filename -TransferType Download ; Write-Host -Object "done! download completed for $filename" -ForegroundColor Cyan