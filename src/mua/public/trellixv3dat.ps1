$ProgressPreference = 'SilentlyContinue'
$uri = 'https://download.nai.com/products/datfiles/V3DAT' ; $w = Invoke-WebRequest -Uri $uri -UseBasicParsing
$urilocation = $w.links.href | Where-Object { $_ -notmatch 'epo' -and $_ -match '.exe' } | Sort-Object -Descending | Select-Object -First 1
$version = $urilocation | Split-Path -Leaf ; $source = 'https://download.nai.com/products/datfiles/' + $urilocation
if ($showVersion.IsPresent) { return Write-Host -Object "Latest version is $version" -ForegroundColor Cyan }
$path = "$($HOME)\desktop" ; Write-Verbose -Message "Downloading $version" -Verbose ; Start-Sleep -Seconds 3
Start-BitsTransfer -Source $source -Destination $path\$version -TransferType Download
Compress-Archive -Path $path\$version -DestinationPath "$path\$($version.Replace('.exe', $null)).zip" -CompressionLevel Optimal -Force -Verbose
Remove-Item -Path $path\$version -Force -Verbose ; Write-Host -Object "done! Trellix $version compressed." -ForegroundColor Cyan