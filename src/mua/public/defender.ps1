<#
.NOTES
    Requires manual check & download of file
    Update for Microsoft Defender Antivirus antimalware platform - KB4052623 - Current Channel (Broad) Url : https://www.catalog.update.microsoft.com/Search.aspx?q=KB4052623
#>

$ProgressPreference = 'SilentlyContinue' ; $path = $destinationPath
$uri = 'https://go.microsoft.com/fwlink/?LinkId=197094' # Network Real-time Inspection definitions | nis_full.exe
$filename = 'nis_full.exe' ; Write-Verbose -Message "Downloading $filename..." -Verbose
Start-BitsTransfer -Source $uri -Destination $(Join-Path -Path $path -ChildPath $filename)-TransferType Download ; Write-Host -Object "done! downloaded $filename to $path." -ForegroundColor Cyan
$uri = 'https://go.microsoft.com/fwlink/?LinkID=121721&arch=x64' # Definitions | mpam-fe.exe
$filename = 'mpam-fe.exe' ; Write-Verbose -Message "Downloading $filename..." -Verbose
Start-BitsTransfer -Source $uri -Destination $(Join-Path -Path $path -ChildPath $filename)-TransferType Download ; Write-Host -Object "done! downloaded $filename to $path." -ForegroundColor Cyan