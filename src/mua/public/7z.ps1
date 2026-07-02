$ProgressPreference = 'SilentlyContinue'
$w = Invoke-WebRequest -Uri 'https://github.com/ip7z/7zip/releases' -UseBasicParsing ; $links = $w.Links.href
$latest = $links | Where-Object { $_ -match '/releases/tag/' } | Sort-Object -Descending | Select-Object -First 1 ; $latest = $latest.Remove(0, 1)
$version = $latest | Split-Path -Leaf ; $urilocation = "https://github.com/$($latest.Replace('tag','download'))/7z$($version.Replace('.',$null))-x64.exe"
if ($showVersion.IsPresent) { return Write-Host -Object "Latest version is $version" -ForegroundColor Cyan }
Write-Verbose -Message "verifiying url: $urilocation" -Verbose
try { $w = Invoke-WebRequest -Uri $urilocation -UseBasicParsing -ErrorAction Stop } catch { Write-Host -Object 'invalid url!' -ForegroundColor Red ; return }
if ($w.StatusCode -eq 200) { Write-Verbose -Message 'statuscode 200, OK.' -Verbose }
$path = "$($HOME)\desktop\7-Zip v$version" ; New-Item -Path $path -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
$filename = $urilocation | Split-Path -Leaf ; Write-Verbose -Message "Downloading $filename" -Verbose ; Start-Sleep -Milliseconds 250
Start-BitsTransfer -Source $urilocation -Destination $path\$filename -TransferType Download ; Write-Host -Object "done! download completed for $filename" -ForegroundColor Cyan