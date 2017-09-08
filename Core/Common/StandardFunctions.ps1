Function Pause (
    $Message = "(PS) Press any key to continue . . . "
){
    if ((Test-Path variable:psISE) -and $psISE) {
        $Shell = New-Object -ComObject "WScript.Shell"
        $Button = $Shell.Popup("Click OK to continue.", 0, "Script Paused", 0)
    }
    else {
        Write-Host
        Write-Host -NoNewline $Message
        [void][System.Console]::ReadKey($true)
        Write-Host
    }
}


Function Write-Host-H1(
    [string]$Message
){
    Write-Host "$Message" -ForegroundColor Green
}


Function Write-Host-H2(
    [string]$Message
){
    Write-Host "$Message >>" -ForegroundColor DarkGreen
}

Function Write-Host-Param(
    [string]$ParamName,
    [string]$Value
){
    Write-Host -NoNewline " .$ParamName->" -ForegroundColor Gray 
    Write-Host $Value -ForegroundColor White
}

Function Write-Host-Info(
    [string]$Message
){
    Write-Host "$Message" -ForegroundColor Cyan
}

Function ProceedYN (
    [string]$Message
) {
    if ($Quiet -eq 1) {return $true}
    Write-Host
    Write-Host -NoNewline "$Message ?" -ForegroundColor Blue -BackgroundColor White
    #$answer = Read-Host "$Message ?(y/n)" 
    $answer = Read-Host "(y/n)"
    return ($answer -eq 'y')
}

# Determines if a Service exists with a name as defined in $ServiceName.
# Returns a boolean $True or $False.
Function ServiceExists(
    [Parameter(mandatory=$true)]
    [string] $ServiceName
) {
	Write-Host
	Write-Host-H2 -Message "func ServiceExists"
    foreach ($key in $MyInvocation.BoundParameters.keys)
    {
        $value = (get-variable $key).Value 
        Write-Host-Param -ParamName $key -Value $value
    }
	Write-Host

    [bool] $Return = $False
    # If you use just "Get-Service $ServiceName", it will return an error if 
    # the service didn't exist.  Trick Get-Service to return an array of 
    # Services, but only if the name exactly matches the $ServiceName.  
    # This way you can test if the array is emply.
    if ( Get-Service "$ServiceName*" -Include $ServiceName ) {
        $Return = $True
    }
    Write-Host "ServiceExists($ServiceName): $Return" -ForegroundColor $(if ($Return) {"Green"} else {"Red"})
    Return $Return
}

# Determines if a Service exists with a name as defined in $ServiceName.
# Returns a boolean $True or $False.
Function GetServiceStatus(
    [Parameter(mandatory=$true)]
    [string] $ServiceName
) {
	Write-Host
	Write-Host-H2 -Message "func GetServiceStatus"
    foreach ($key in $MyInvocation.BoundParameters.keys)
    {
        $value = (get-variable $key).Value 
        Write-Host-Param -ParamName $key -Value $value
    }
	Write-Host

    [string] $Return = $null
    # If you use just "Get-Service $ServiceName", it will return an error if 
    # the service didn't exist.  Trick Get-Service to return an array of 
    # Services, but only if the name exactly matches the $ServiceName.  
    # This way you can test if the array is emply.
    if ( Get-Service "$ServiceName*" -Include $ServiceName ) {
        $service = Get-Service -Name "$ServiceName"
        $Return = $service.Status
    }
    Write-Host "GetServiceStatus($ServiceName): $Return" -ForegroundColor Green
    Return $Return
}



function Read-InstallConfigFile(
    [Parameter(mandatory=$true)]
    [string]$configPath
){
	Write-Host
	Write-Host-H2 -Message "func Read-InstallConfigFile"
    foreach ($key in $MyInvocation.BoundParameters.keys)
    {
        $value = (get-variable $key).Value 
        Write-Host-Param -ParamName $key -Value $value
    }
	Write-Host

    if (Test-Path $configPath)
    {
        [xml]$configXml = Get-Content ($configPath)
    }
    else
    {
        Write-Host "Could not find configuration file at specified path: $configPath" -ForegroundColor Red
        Throw "Could not find configuration file at specified path: $configPath"
    }

    return $configXml
}

function Get-ConfigValue([xml]$config, [string]$optionName, [bool]$isAttribute=$FALSE)
{
	Write-Host
	Write-Host-H2 -Message "func Get-ConfigValue"
    foreach ($key in $MyInvocation.BoundParameters.keys)
    {
        $value = (get-variable $key).Value 
        Write-Host-Param -ParamName $key -Value $value
    }
	Write-Host

    $configValue = $null

    if ($isAttribute)
    {
        $attributeName = Split-Path -Leaf $optionName
        $optionName = Split-Path $optionName
        $optionName = $optionName.Replace("\", "//")
        $node = $config.InstallSettings.SelectSingleNode($optionName)

        if ($node -ne $null)
        {
            $attributeValue = $node.GetAttribute($attributeName).Trim()
            if (!([string]::IsNullOrEmpty($attributeValue)))
            {
                $configValue = $attributeValue
            }
        }
    }
    else
    {
        $nodeValue = $config.InstallSettings.SelectSingleNode($optionName).InnerText.Trim()
        if (!([string]::IsNullOrEmpty($nodeValue)))
        {
            $configValue = $nodeValue
        }
    }

    return $configValue
}

function Get-ConfigOption([xml]$config, [string]$optionName, [bool]$isAttribute=$FALSE)
{
	Write-Host
	Write-Host-H2 -Message "func Get-ConfigOption"
    foreach ($key in $MyInvocation.BoundParameters.keys)
    {
        $value = (get-variable $key).Value 
        Write-Host-Param -ParamName $key -Value $value
    }
	Write-Host

    $optionValue = $FALSE

    if ($isAttribute)
    {
        $attributeName = Split-Path -Leaf $optionName
        $optionName = Split-Path $optionName
        $optionName = $optionName.Replace("\", "//")
        $node = $config.InstallSettings.SelectSingleNode($optionName)

        if ($node -ne $null)
        {
            $attributeValue = $node.GetAttribute($attributeName).Trim()
            if (!([string]::IsNullOrEmpty($attributeValue)))
            {
                $optionValue = [System.Convert]::ToBoolean($attributeValue)
            }
        }
    }
    else
    {
        $nodeValue = $config.InstallSettings.SelectSingleNode($optionName).InnerText.Trim()
        if (!([string]::IsNullOrEmpty($nodeValue)))
        {
            $optionValue = [System.Convert]::ToBoolean($nodeValue)
        }
    }

    return $optionValue
}


function Get-DllVersion
{
    [CmdletBinding()]
    param
    (
        [parameter(Position=0, mandatory=$true)]
        [string]$DllPath,
        [parameter(Position=1)]
        [switch]$GetFullVersion
    )
    process
    {
        Write-Host
	    Write-Host-H2 -Message "func Get-DllVersion"
        foreach ($key in $MyInvocation.BoundParameters.keys)
        {
            $value = (get-variable $key).Value 
            Write-Host-Param -ParamName $key -Value $value
        }
	    Write-Host

        # Returns the version of the dll
        If (-Not( Test-Path $DllPath)) {
            Write-Host "Could not find target $DllPath !" -ForegroundColor red
            Throw "Could not find target $DllPath !"
        }
        
        $fullVersion = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($DllPath).FileVersion

        $versionInfo = $fullVersion
        if (!$GetFullVersion)
        {
            $verArr = $fullVersion.Split(".")
            $versionInfo = "{0}.{1}" -f $verArr[0],$verArr[1]
        }

        return $versionInfo
    }
}

Function CreateSymLink (
    [Parameter(mandatory=$true)]
    [string]$link,
    [Parameter(mandatory=$true)]
    [string]$target
)
{
	Write-Host
	Write-Host-H2 -Message "func CreateSymLink"
    foreach ($key in $MyInvocation.BoundParameters.keys)
    {
        $value = (get-variable $key).Value 
        Write-Host-Param -ParamName $key -Value $value
    }
	Write-Host
    
    Try {
       if (-Not(Test-Path $target))
       {
            Write-Host "Could not find target $target !" -ForegroundColor red
            Throw "Could not find target $target !"
       } elseif (Test-Path $link){
            Write-Host "Link $link path already exists !" -ForegroundColor red
            Throw "Link $link path already exists !"
       } else {
            Write-Host Creating SymLink $link to $target... -ForegroundColor Black -BackgroundColor White
            New-Item -Path $link -ItemType SymbolicLink -Value $target
            Write-Host SymLink created -ForegroundColor Green
       }
    }
    Catch
    {
        Write-Error $_.Exception.Message
        Throw $_.Exception.Message
    }
}

function UpdateHost (
    [string]$hostEntry,
    [switch]$remove,
    [switch]$comment
)
{
	Write-Host
	Write-Host-H2 -Message "func UpdateHost"
    foreach ($key in $MyInvocation.BoundParameters.keys)
    {
        $value = (get-variable $key).Value 
        Write-Host-Param -ParamName $key -Value $value
    }
	Write-Host
    
    Try {
        $wd=$($env:windir)+'\system32\Drivers\etc\hosts'

        if ($remove.IsPresent -or -$comment.IsPresent) {
            If ((Get-Content $wd ) -contains "127.0.0.1	$hostEntry")
            {
                Write-Host
                Write-Host-Info -Message "$(if ($comment) {'Comment'} else {'Removing'}) entry $hostEntry from Host file  ..."
                (Get-Content $wd) -replace ("^\s*127.0.0.1\s+$hostEntry",$(if ($comment) {"#127.0.0.1	$hostEntry"} else {""})) | Out-File $wd -Force
                Write-Host $hostEntry entry $(if ($comment) {"commented"} else {"removed"}) in Host file -ForegroundColor Green
            }
            else {
                Write-Host Could not find $hostEntry entry -ForegroundColor Green
            }
        }
        else {
            If ((Get-Content $wd ) -notcontains "127.0.0.1	$hostEntry")
            {
                Write-Host
                Write-Host-Info -Message "Adding $hostEntry entry to Host file ..."
                ac -Encoding UTF8  $wd "`r`n`r`n127.0.0.1	$hostEntry";
                Write-Host $hostEntry entry added to Host file -ForegroundColor Green
            }
            else {
                Write-Host $hostEntry entry already exists -ForegroundColor Green
            }
        }
    }
    
    Catch
    {
        Write-Error $_.Exception.Message
        throw ($_) 
    }
}



# https://gallery.technet.microsoft.com/scriptcenter/Set-FolderIcon-0bd56629
function Set-FolderIcon 
{ 
    [CmdletBinding()] 
    param 
    (     
        [Parameter(Mandatory=$True, 
        Position=0)] 
        [string[]]$Icon, 
        [Parameter(Mandatory=$True, 
        Position=1)] 
        [string]$Path, 
        [Parameter(Mandatory=$False)] 
        [switch]$Recurse     
    ) 
    BEGIN 
    { 
        $originallocale = $PWD 
        #Creating content of the DESKTOP.INI file. 
        $ini = '[.ShellClassInfo] 
                IconFile=folder.ico 
                IconIndex=0 
                ConfirmFileOp=0' 
        Set-Location $Path 
        Set-Location ..     
        Get-ChildItem | Where-Object {$_.FullName -eq "$Path"} | ForEach {$_.Attributes = 'Directory, System'} 
    }     
    PROCESS 
    { 
        $ini | Out-File $Path\DESKTOP.INI 
        If ($Recurse -eq $True) 
        { 
            Copy-Item -Path $Icon -Destination $Path\FOLDER.ICO     
            $recursepath = Get-ChildItem $Path -r | Where-Object {$_.Attributes -match "Directory"} 
            ForEach ($folder in $recursepath) 
            { 
                Set-FolderIcon -Icon $Icon -Path $folder.FullName 
            } 
         
        } 
        else 
        { 
            Copy-Item -Path $Icon -Destination $Path\FOLDER.ICO 
        }     
    }     
    END 
    { 
        $inifile = Get-Item $Path\DESKTOP.INI 
        $inifile.Attributes = 'Hidden' 
        $icofile = Get-Item $Path\FOLDER.ICO 
        $icofile.Attributes = 'Hidden' 
        Set-Location $originallocale         
    } 
} 
<# 
 
#> 
function Remove-SetIcon 
{ 
    [CmdletBinding()] 
    param 
    (     
        [Parameter(Mandatory=$True, 
        Position=0)] 
        [string]$Path 
    ) 
    BEGIN 
    { 
        $originallocale = $PWD 
        $iconfiles = Get-ChildItem $Path -Recurse -Force | Where-Object {$_.Name -like "FOLDER.ICO"} 
        $iconfiles = $iconfiles.FullName 
        $inifiles = Get-ChildItem $Path -Recurse -Force | where-Object {$_.Name -like "DESKTOP.INI"} 
        $inifiles = $inifiles.FullName 
    } 
    PROCESS 
    { 
        Remove-Item $iconfiles -Force 
        Remove-Item $inifiles -Force 
        Set-Location $Path 
        Set-Location .. 
        Get-ChildItem | Where-Object {$_.FullName -eq "$Path"} | ForEach {$_.Attributes = 'Directory'}     
    } 
    END 
    { 
        Set-Location $originallocale 
    } 
}