$global:x = Get-Module -ListAvailable -Refresh mua ; [xml]$global:xml = Get-Content -Path (Join-Path -Path $x.ModuleBase -ChildPath settings.xml) ; $global:invalidSettingsXmlFoundErrorMessage = 'The settings.xml has conflicting data. Verify these properties are set correctly for both win10 and win11 values.'

function gtdomain { return ((Get-CimInstance -ClassName win32_computersystem).Domain).ToLower().Split('.')[0] }

function gt7zip { param([parameter(ParameterSetName = 'show')][switch]$showVersion) & $(Join-Path -Path $x.ModuleBase -ChildPath $xml.xml.public.sevenzip.script -Resolve) }

function gtedge { param([parameter(ParameterSetName = 'show')][switch]$showVersion) & $(Join-Path -Path $x.ModuleBase -ChildPath $xml.xml.public.edge.script -Resolve) }

function gtavdefinitions { param([parameter(Mandatory)][string]$destinationPath)  & $(Join-Path -Path $x.ModuleBase -ChildPath $xml.xml.public.winDefend.script -Resolve) }

function gtnpp { param([parameter(ParameterSetName = 'show')][switch]$showVersion) & $(Join-Path -Path $x.ModuleBase -ChildPath $xml.xml.public.nppp.script -Resolve) }

function gttimeutc
{
    param([parameter(ParameterSetName = 'log')][switch]$loggingFormat)
    if ($loggingFormat.IsPresent) { return (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ') }
    return (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmZ') #ISO 8601 formatting
}

$script:gttimeutc = gttimeutc ; $script:domain = gtdomain

function gtxml
{
    [cmdletbinding(DefaultParameterSetName = 'default')]
    param([parameter(ParameterSetName = 'workspace')][validateset('win10', 'win11')]$setWorkspace, [parameter(ParameterSetName = 'null')][switch]$outNull)

    $xmlPath = Join-Path -Path $x.ModuleBase -ChildPath settings.xml -Resolve
    switch ($PSCmdlet.ParameterSetName)
    {
        default
        {
            if (($xml.xml.win10.value -eq $true -and $xml.xml.win11.value -eq $true) -or ($xml.xml.win10.value -eq $false -and $xml.xml.win11.value -eq $false)) { throw $invalidSettingsXmlFoundErrorMessage } ; if ($outNull.IsPresent) { return $null } ; return [pscustomobject]@{win10 = $xml.xml.win10.value ; win11 = $xml.xml.win11.value }
        }
        'workspace'
        {
            if ($setWorkspace -eq 'win10') { $xml.xml.win10.value = 'true' ; $xml.xml.win11.value = 'false' } ; if ($setWorkspace -eq 'win11') { $xml.xml.win11.value = 'true' ; $xml.xml.win10.value = 'false' }
            $xml.Save($xmlPath) ; Start-Sleep -Milliseconds 50 ; Write-Host -Object "The settings.xml file has been successfully updated for $setWorkspace." -ForegroundColor Cyan
        }
    }
}

function tegit
{
    gtxml -outNull
    if ($xml.xml.win10.value -eq $true) { if ($script:gitPath = (Resolve-Path -Path $xml.xml.win10.git -ErrorAction SilentlyContinue).Path) { if ($null -ne $gitpath) { return } } }
    if ($xml.xml.win11.value -eq $true) { if ($script:gitPath = (Resolve-Path -Path $xml.xml.win11.git -ErrorAction SilentlyContinue).Path) { if ($null -ne $gitpath) { return } } }
    if (-not(Test-Path -Path "$gitPath\.git")) { throw 'This requires a Git repository. Verify path to only 1 valid repo.' }
}

function gtbuildtime
{
    $endtime = [datetime]::Now ; $t = $endtime - $starttime
    Write-Host -Object '' ; Write-Host -Object "BuildTime : $([System.Math]::Round($t.TotalMinutes,2))m" -ForegroundColor Cyan ; Write-Host -Object ''
}

function rnreleasable
{
    Get-ChildItem -Path $fullyqualifieddestinationpath | Where-Object { $_.Name -eq 'Release' } | Rename-Item -NewName 'Output' -Force -Verbose
    Move-Item -Path "$fullyqualifieddestinationpath\Output\*" -Destination $fullyqualifieddestinationpath -Force -Verbose ; Remove-Item -Path "$fullyqualifieddestinationpath\Output" -Force -Verbose ; gtbuildtime
}

function rmupdates
{
    $path = Get-ChildItem -Path $fullyqualifieddestinationpath -Recurse | Where-Object { $_.Name -ne 'Release' }
    if ($keep -eq $true) { $path | ForEach-Object { Write-Host -Object "Keep file/folder '$_'" -ForegroundColor Cyan } ; rnreleasable ; return }
    Get-ChildItem -Path $fullyqualifieddestinationpath | Where-Object { $_.Name -ne 'Release' } | Remove-Item -Recurse -Force -Verbose ; rnreleasable
}

function hash256sums
{
    [cmdletbinding()]
    param([parameter(ParameterSetName = 'path')][string]$path)

    switch ($PSCmdlet.ParameterSetName)
    {
        default
        {
            $array = @()
            (Get-ChildItem -Path $fullyqualifieddestinationpath -Recurse -File).FullName | ForEach-Object {
                Write-Verbose -Message "Hashing $_ " -Verbose ; $i = Get-FileHash -Path $_ -Algorithm SHA256
                $h = [pscustomobject]@{ name = $i.Path | Split-Path -Leaf ; hash = $i.Hash.ToLower() ; algorithm = $i.algorithm }
                $array += $h
            }
            $logfilepath = (Get-ChildItem -Path $fullyqualifieddestinationpath -Recurse -File -Filter '*.7z').FullName.Replace('.7z', '.7z.sha256sums.txt') ; $array | Format-List | Out-File -FilePath $logfilepath
            Get-ChildItem -Path "$fullyqualifieddestinationpath\Release" -Recurse -Force | Unblock-File -Verbose ; rmupdates
        }
        'path'
        {
            $array = @()
            (Get-ChildItem -Path $path -Recurse -File).FullName | ForEach-Object {
                Write-Verbose -Message "Hashing $_ " -Verbose ; $i = Get-FileHash -Path $_ -Algorithm SHA256
                $h = [pscustomobject]@{ name = $i.Path | Split-Path -Leaf ; hash = $i.Hash.ToLower() ; algorithm = $i.algorithm }
                $array += $h
            }
            $logfilepath = (Get-ChildItem -Path $path -Recurse -File -Filter '*.7z').FullName.Replace('.7z', '.7z.sha256sums.txt') ; $array | Format-List | Out-File -FilePath $logfilepath ; Get-ChildItem -Path $path -Recurse -Force | Unblock-File -Verbose
        }
    }
}

function mkreleasable
{
    $fullyqualifieddestinationpath = $fullyqualifieddestinationpath | Split-Path -Parent ; $fullyqualifieddestinationpath = $fullyqualifieddestinationpath += '\'
    New-Item -Path $fullyqualifieddestinationpath -Name 'Release' -ItemType Directory -Force -Verbose | Out-Null
    Move-Item -Path $(Join-Path -Path $fullyqualifieddestinationpath -ChildPath '*.7z') -Destination $(Join-Path -Path $fullyqualifieddestinationpath -ChildPath 'Release') -Verbose
    if ($domain -eq $xml.xml.domain) { & $xml.xml.sevenZ.install $xml.xml.iargs $(Join-Path -Path $fullyqualifieddestinationpath -ChildPath "Release\$($xml.xml.includes.filename)") $(Join-Path -Path $x.ModuleBase -ChildPath $xml.xml.includes.folder -Resolve) }
    else { & (Join-Path -Path $x.ModuleBase -ChildPath $xml.xml.sevenZ.relative -Resolve) $xml.xml.iargs $(Join-Path -Path $fullyqualifieddestinationpath -ChildPath "Release\$($xml.xml.includes.filename)") $(Join-Path -Path $x.ModuleBase -ChildPath $xml.xml.includes.folder -Resolve) }
    (Get-ChildItem -Path "$gitPath\monthly updates" -Recurse | Where-Object { $_.Name -match 'monthly_updates.cmd' }).FullName | Copy-Item -Destination $(Join-Path -Path $fullyqualifieddestinationpath -ChildPath 'Release') -Container -Verbose
    $path = $(Join-Path -Path $fullyqualifieddestinationpath -ChildPath 'Release\apply_monthly_updates.cmd')
    if ($path -match $xml.xml.win10.majorVersion ) { (Get-Content -Path $path) -replace $xml.xml.win10.placeholder, $($fullyqualifieddestinationpath | Split-Path -Leaf) | Set-Content -Path $path -PassThru -Force }
    if ($path -match $xml.xml.win11.majorVersion ) { (Get-Content -Path $path) -replace $xml.xml.win11.placeholder, $($fullyqualifieddestinationpath | Split-Path -Leaf) -replace $($xml.xml.win11.placeholder.Remove(0, 9)), $($fullyqualifieddestinationpath | Split-Path -Leaf).Remove(0, 9) | Set-Content -Path $path -PassThru -Force }
    mkcmd ; hash256sums
}

function mkpatchtuesfolder
{
    [cmdletbinding()]
    param([parameter(Mandatory)][string]$destinationPath, [parameter(ParameterSetName = 'month')][validateset('01-Jan', '02-Feb', '03-Mar', '04-Apr', '05-May', '06-Jun', '07-Jul', '08-Aug', '09-Sep', '10-Oct', '11-Nov', '12-Dec')]$month)

    gtxml -outNull ; tegit
    switch ($PSCmdlet.ParameterSetName)
    {
        default
        {
            $d = Get-Date -Day 1 ; $first = $d ; while ($first.DayOfWeek -ne 'Tuesday') { $first = $first.AddDays(1) } ; $second = $first.AddDays(7) ; $yyyyMMdd = $second.ToString('yyyyMMdd')
        }
        'month'
        {
            $d = Get-Date -Month $($month.Remove(2)) -Day 1 ; $first = $d ; while ($first.DayOfWeek -ne 'Tuesday') { $first = $first.AddDays(1) } ; $second = $first.AddDays(7) ; $yyyyMMdd = $second.ToString('yyyyMMdd')
        }
    }

    if ((Resolve-Path -Path "$destinationPath\Security Updates for Microsoft Windows and Office_*" -ErrorAction SilentlyContinue).Path.Count -ge 1) { throw "$destinationPath has a Windows and Office Updates folder structure." }
    if ($xml.xml.win10.value -eq $true -and $destinationPath -match $xml.xml.win10.majorVersion) { New-Item -Path "$destinationPath\Security Updates for Microsoft Windows and Office_$($yyyyMMdd)" -ItemType Directory -Force -Verbose | Out-Null }
    elseif ($xml.xml.win11.value -eq $true -and $destinationPath -match $xml.xml.win11.majorVersion) { New-Item -Path "$destinationPath\Security Updates for Microsoft Windows and Office_$($yyyyMMdd)\Cumulative" -ItemType Directory -Force -Verbose | Out-Null }
    else { throw $invalidSettingsXmlFoundErrorMessage }

    (Get-ChildItem -Path "$gitPath\monthly updates" -Recurse | Where-Object { $_.Name -match 'windows updates.ps1' }).FullName | Copy-Item -Destination "$($(Resolve-Path -Path "$destinationPath\Security Updates for Microsoft Windows and Office_*\").Path)" -Container -Force -Verbose
}

function mkavfolder
{
    [cmdletbinding()]
    param([parameter(Mandatory)][string]$destinationPath)

    gtxml -outNull ; tegit
    if (-not(Test-Path -Path $destinationPath -ErrorAction SilentlyContinue)) { throw "The source path $destinationPath does not exist." } ; if ($xml.xml.win11.value -ne $true ) { throw "This function is only applicable to Windows 11 (e.g.:$($xml.xml.win11.placeholder))" }
    tegit ; New-Item -Path "$destinationPath\Security Definitions for Windows Defender AV\Latest" -ItemType Directory -Force -Verbose | Out-Null ; (Get-ChildItem -Path "$gitPath\monthly updates\_windefend\" | Where-Object { $_.Extension -eq '.ps1' }).FullName | Copy-Item -Destination $(Join-Path -Path $destinationPath -ChildPath 'Security Definitions for Windows Defender AV') -Container -Force -Verbose
}

function mkcmd
{
    [cmdletbinding(DefaultParameterSetName = 'default')]
    param([parameter(ParameterSetName = 'script')][string]$sourceScript, [parameter(ParameterSetName = 'script')][switch]$noExit)

    switch ($PSCmdlet.ParameterSetName)
    {
        default
        {
            $fullyqualifiedcmdpath | Get-ChildItem -Recurse -Filter *.ps1 -Exclude 'apply_monthly_updates.ps1' | ForEach-Object {
                $path = $_.FullName | Split-Path -Parent
                $name = $_.Name.Replace('.ps1', '.cmd')
                $file = ($_.Name | Split-Path -Leaf).Replace('.ps1', $null)
                $value = @"
@echo off
setlocal enabledelayedexpansion
title %~n0
color 80
net session >nul 2>&1
if %errorlevel% neq 0 (
    color 0C
    cls
    echo This file requires elevated administrator rights.
    echo Right-click on "%~nx0" and choose "Run as administrator".
    timeout /t -1
    exit /b
)
cls
pushd %~dp0
powershell.exe -nologo -file "%~dp0$($file).ps1"
"@ ; New-Item -Path $path -Name $name -ItemType File -Value $value -Force -Verbose | Out-Null
            }
        }
        'script'
        {
            if (-not($sourceScript.EndsWith('.ps1'))) { throw "The source PowerShell script $sourceScript does not have a '.ps1' extension." }
            if (-not(Test-Path -Path $sourceScript -ErrorAction SilentlyContinue)) { throw "The source PowerShell script $sourceScript does not exist." }
            $file = ($sourceScript | Split-Path -Leaf).Replace('.ps1', $null) ; $name = ($sourceScript | Split-Path -Leaf).Replace('.ps1', '.cmd')
            $value = @"
@echo off
setlocal enabledelayedexpansion
title %~n0
color 80
net session >nul 2>&1
if %errorlevel% neq 0 (
    color 0C
    cls
    echo This file requires elevated administrator rights.
    echo Right-click on "%~nx0" and choose "Run as administrator".
    timeout /t -1
    exit /b
)
cls
pushd %~dp0
powershell.exe -nologo -file "%~dp0$($file).ps1"
"@  ; if ($noExit.IsPresent) { $value = $value -replace 'powershell.exe -nologo -file', 'powershell.exe -noexit -nologo -file' } ; New-Item -Path $($sourceScript | Split-Path -Parent) -Name $name -ItemType File -Value $value -Force -Verbose | Out-Null
        }
    }
}

function mkupdatefolder
{
    [cmdletbinding()]
    param([parameter(Mandatory)][string]$destinationPath, [parameter(Mandatory)][version]$samsVersion)

    gtxml -outNull
    if ($xml.xml.win10.value -eq $true -and $samsVersion -match $xml.xml.win10.majorVersion) { New-Item -Path $destinationPath -Name "$($xml.xml.win10.placeholder.Remove(9))$($samsVersion.ToString())" -ItemType Directory -Verbose | Out-Null }
    elseif ($xml.xml.win11.value -eq $true -and $samsVersion -match $xml.xml.win11.majorVersion) { New-Item -Path $destinationPath -Name "$($xml.xml.win11.placeholder.Remove(9))$($samsVersion.ToString())" -ItemType Directory -Verbose | Out-Null }
    else { throw $invalidSettingsXmlFoundErrorMessage }
}

function mkupdate
{
    [cmdletbinding()]
    param([parameter(Mandatory)][string]$sourcePath, [parameter()][switch]$keepUpdates)

    gtxml -outNull ; tegit ; $script:starttime = [datetime]::Now ; $global:fullyqualifiedcmdpath = $sourcePath

    if ($keepUpdates.IsPresent) { $script:keep = $true } else { $keep = $false }
    if (-not(Test-Path -Path $sourcePath -ErrorAction SilentlyContinue)) { throw "The source path $sourcePath does not exist." }
    if (-not($sourcePath.EndsWith('\'))) { $sourcePath += '\' }
    if ($xml.xml.win10.value -eq $true -and $sourcePath -notmatch $xml.xml.win10.majorVersion) { Write-Host -Object "Error : Mismatch between provided path and XML value : $sourcePath" -ForegroundColor Red ; Write-Host -Object "win10 : $($xml.xml.win10.value)`nwin11 : $($xml.xml.win11.value)" ; return Write-Host -Object 'Set correct workspace : gtxml -setWorkspace win11' -ForegroundColor Yellow }
    if ($xml.xml.win11.value -eq $true -and $sourcePath -notmatch $xml.xml.win11.majorVersion) { Write-Host -Object "Error : Mismatch between provided path and XML value : $sourcePath" -ForegroundColor Red ; Write-Host -Object "win11 : $($xml.xml.win11.value)`nwin10 : $($xml.xml.win10.value)" ; return Write-Host -Object 'Set correct workspace : gtxml -setWorkspace win10' -ForegroundColor Yellow }

    (Get-ChildItem -Path "$gitPath\monthly updates" -Recurse | Where-Object { $_.Name -match 'monthly_updates.ps1' }).FullName | Copy-Item -Destination $sourcePath -Container -Force -Verbose

    New-Item -Path $sourcePath -Name 'branding for Monthly Updates' -ItemType Directory -Force -Verbose | Out-Null
    if ($xml.xml.win11.value -eq $true)
    {
        (Get-ChildItem -Path "$gitPath\monthly updates\*branding" -Recurse | Where-Object { $_.Name -notmatch 'showapps' }).FullName, (Get-ChildItem -Path "$gitPath\baseline" -Recurse -Filter 'wallpaper_*.zip').FullName | Copy-Item -Destination $(Join-Path -Path $sourcePath -ChildPath 'branding for Monthly Updates') -Container -Force -Verbose | Copy-Item -Destination $(Join-Path -Path $sourcePath -ChildPath 'branding') -Container -Force -Verbose
    }
    if ($xml.xml.win10.value -eq $true)
    {
        (Get-ChildItem -Path "$gitPath\monthly updates\*branding" -Recurse).FullName | Copy-Item -Destination $(Join-Path -Path $sourcePath -ChildPath 'branding for Monthly Updates') -Container -Force -Verbose | Copy-Item -Destination $(Join-Path -Path $sourcePath -ChildPath 'branding') -Container -Force -Verbose
    }

    mkcmd ; $destinationpath = ($sourcePath | Split-Path -Leaf) + '_' + $gttimeutc + '.7z' ; $fullyqualifieddestinationpath = $sourcePath + $destinationpath
    $files = Get-ChildItem -Path $sourcePath -Recurse ; $files | Unblock-File -Verbose ; $files | ForEach-Object { Write-Verbose -Message "Adding $_ to $destinationpath" -Verbose }

    if ($domain -eq $xml.xml.domain) { & $xml.xml.sevenZ.install $xml.xml.args $fullyqualifieddestinationpath $sourcePath }
    else { & (Join-Path -Path $x.ModuleBase -ChildPath $xml.xml.sevenZ.relative -Resolve) $xml.xml.args $fullyqualifieddestinationpath $sourcePath }
    mkreleasable
}