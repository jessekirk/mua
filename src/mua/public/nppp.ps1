$ProgressPreference = 'SilentlyContinue'
$w = Invoke-WebRequest -Uri 'https://notepad-plus-plus.org/downloads/' -UseBasicParsing  ; $links = $w.Links.href | Where-Object { $_ -match 'notepad-plus-plus.org' }
$latest = $links | Select-Object -First 1 ; $w = Invoke-WebRequest -Uri $latest -UseBasicParsing
$fileversion = [version]($latest | Split-Path -Leaf).Remove(0, 1)

if ($showVersion.IsPresent) { return Write-Host -Object "Latest version is $($latest | Split-Path -Leaf)" -ForegroundColor Cyan }
if ($xml.xml.win10.value -eq $true)
{
    $urilocation = $w.Links.href | Where-Object { $_ -match 'installer.x64.exe' -and $_ -notmatch 'installer.x64.exe.sig' }
    if ($urilocation.Count -gt 1) { $urilocation = $urilocation | Sort-Object -Descending | Select-Object -First 1 }
    $path = "$($HOME)\desktop" ; $filename = $urilocation | Split-Path -Leaf
    Write-Verbose -Message "downloading $filename..." -Verbose ; Start-Sleep -Milliseconds 250
    Start-BitsTransfer -Source $urilocation -Destination $path\$filename -TransferType Download ; Start-Sleep -Milliseconds 250
    $name = "Notepad++ v$fileversion" ; New-Item -Path $path\$name -ItemType Directory -Force -Verbose | Out-Null
    Move-Item -Path $path\$filename -Destination $path\$name -Force -Verbose ; Write-Host -Object "done! build completed for $name" -ForegroundColor Cyan ; return
}

$urilocation = $w.Links.href | Where-Object { $_ -match 'portable.x64.zip' -and $_ -notmatch 'portable.x64.zip.sig' }
$path = "$($HOME)\desktop" ; $filename = $urilocation | Split-Path -Leaf ; Write-Verbose -Message "downloading $filename..." -Verbose ; Start-Sleep -Milliseconds 250
Start-BitsTransfer -Source $urilocation -Destination $path\$filename -TransferType Download ; Start-Sleep -Milliseconds 250 ; $npp = $filename
$w = Invoke-WebRequest -Uri 'https://github.com/pnedev/comparePlus/' -UseBasicParsing ; $links = $w.Links.href
$latest = $links | Where-Object { $_ -match '/releases/tag/' -and $_ -match '/tag/cp' } | Sort-Object -Descending | Select-Object -First 1 ; $latest = $latest.Remove(0, 1)
$version = $latest | Split-Path -Leaf ; $urilocation = "https://github.com/$($latest.Replace('tag','download'))/ComparePlus_$($version)_x64.zip"

Write-Verbose -Message "verifiying url: $urilocation" -Verbose
try { $w = Invoke-WebRequest -Uri $urilocation -UseBasicParsing -ErrorAction Stop } catch { Write-Host -Object 'invalid url!' -ForegroundColor Red ; return }
if ($w.StatusCode -eq 200) { Write-Verbose -Message 'statuscode 200, OK.' -Verbose }
$filename = $version.ToString() + '.zip' ; $filenamecpp = $filename ; Write-Verbose -Message "downloading $filename..." -Verbose ; Start-Sleep -Milliseconds 250 ; Start-BitsTransfer -Source $urilocation -Destination $path\$filename -TransferType Download

Write-Host -Object "building package for $npp..." -ForegroundColor Cyan ; Start-Sleep -Milliseconds 250
$path = (Resolve-Path -Path "$path\npp*portable*x64*.zip").Path ; $filename = $path | Split-Path -Leaf ; $path = $path | Split-Path -Parent
$leaf = "$($filename.Replace('.zip', $null)).w.compare.plus"
Expand-Archive -Path $path\$filename -DestinationPath $path\$leaf -Force -Verbose ; Remove-Item -Path $path\$filename -Force -Verbose
New-Item -Path "$path\$leaf\plugins" -Name 'ComparePlus' -ItemType Directory -Force -Verbose | Out-Null
Expand-Archive -Path $path\$filenamecpp -DestinationPath "$path\$leaf\plugins\ComparePlus" -Force -Verbose ; Remove-Item -Path $path\$filenamecpp -Force -Verbose
Compress-Archive -Path $path\$leaf\* -DestinationPath "$path\$leaf.zip" -CompressionLevel Optimal -Force -Verbose
Write-Host -Object "done! $leaf compressed." -ForegroundColor Cyan
$name = "Notepad++ v$fileversion" ; New-Item -Path $path -Name $name -ItemType Directory -Force -Verbose | Out-Null ; Move-Item -Path "$path\$leaf.zip" -Destination $path\$name -Force -Verbose
Remove-Item -Path $path\$leaf -Recurse -Force -Verbose ; Write-Host -Object "done! build completed for $name" -ForegroundColor Cyan