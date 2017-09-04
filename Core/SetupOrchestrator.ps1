param(
    [string]$configPath, 
    [int]$Quiet = 0
)

# Load functions
$stdFuntionsPath = (split-path -parent $PSCommandPath)
. "$stdFuntionsPath\Common\StandardFunctions.ps1"
#. "$stdFuntionsPath\Common\VSFunctions.ps1"

Clear-Host
#$cd = $(Get-Location)
$cd = $PSScriptRoot | split-path -parent


Write-Host-H1 -Message "Install Sitecore using $configPath"

Write-Host-Param -ParamName "Script file root" -Value $PSScriptRoot
Write-Host-Param -ParamName "Current directory (cd)" -Value $cd
Write-Host

foreach ($key in $MyInvocation.BoundParameters.keys)
{
    $value = (get-variable $key).Value 
    Write-Host-Param -ParamName $key -Value $value
}


try {
    if(-not($configPath)) { Throw "You must supply a value for -configPath" }
    
    Write-Host Reading $configPath -ForegroundColor White -BackgroundColor Black
    [xml]$configXml = Read-InstallConfigFile -configPath $configPath  
    if (!$configXml) {Throw "Could not find configuration file at specified path: $configPath" }
    
    $answer = ProceedYN "Procceed Setup Orchestrator"
    if ($answer -ne $true) 
    {
        Write-Host Sitecore installation aborted -ForegroundColor Red
        Start-Sleep -s 1
        Return
    }
    
    # Manage $DatabaseInstallPath exists
    $DatabaseType = $(Get-ConfigValue -config $configXml -optionName "Database/type" -isAttribute $TRUE)
    $DatabaseEnabled = $(Get-ConfigOption -config $configXml -optionName "Database/enabled" -isAttribute $TRUE)
    $DatabaseInstallPath = $configXml.InstallSettings.Database.DatabaseInstallPath.DataFiles.Local 
    Write-Host "DatabaseType=$DatabaseType"
    Write-Host "DatabaseEnabled=$DatabaseEnabled"
    Write-Host "DatabaseInstallPath=$DatabaseInstallPath"
    if ($DatabaseEnabled -eq "True" -and  $DatabaseType -eq "Local") {
        if (-not (Test-Path $DatabaseInstallPath)) {
            Write-Host "Creating $DatabaseInstallPath..."  -ForegroundColor Black -BackgroundColor White
            New-Item $DatabaseInstallPath -type directory
            Write-Host $DatabaseInstallPath created -ForegroundColor Green
        } 
        else {
            Write-Host $DatabaseInstallPath already exists -ForegroundColor Green
        }
    }
    Start-Sleep -s 1
    
    # Sitecore installation 
    $answer = ProceedYN "Install Sitecore"
    if ($answer -eq $true) 
    {
        Write-Host Launching $PSScriptRoot\SageSitecoreSetup.ps1 -ConfigPath $configPath ... 
        Invoke-Expression "$PSScriptRoot\Sitecore\SageSitecoreSetup.ps1 -ConfigPath $configPath"
        Write-Host Sitecore installed successfully -ForegroundColor Green
        Write-Host 
    }


    # MongoDB stuff for sitecore 8.0
    if ($true) {
        # Get Sitecore.kernel.dll version
        $installPath= Join-Path $configXml.InstallSettings.WebServer.SitecoreInstallRoot -ChildPath $configXml.InstallSettings.WebServer.SitecoreInstallFolder
        [decimal]$sitecoreVersion = Get-DllVersion -DllPath $(Join-Path $installPath -ChildPath "WebSite\Bin\Sitecore.kernel.dll")
        $sitecoreFullVersion = Get-DllVersion -DllPath $(Join-Path $installPath -ChildPath "WebSite\Bin\Sitecore.kernel.dll") -GetFullVersion
        Write-Host "SitecoreVersion: $sitecoreVersion / $sitecoreFullVersion"
        if ($sitecoreVersion -eq 8.0) {
            if(-Not(Test-Path $installPath)) {
                Throw "Error, could not find $installPath !"
            }

            # Get MongoDB.Driver.dll version
            Write-Host Checking Sitecore MongoDB driver... -ForegroundColor Black -BackgroundColor White
            [decimal]$mongoVersion = Get-DllVersion -DllPath $(Join-Path $installPath -ChildPath "WebSite\Bin\MongoDB.Driver.dll")
            $mongoFullVersion = Get-DllVersion -DllPath $(Join-Path $installPath -ChildPath "WebSite\Bin\MongoDB.Driver.dll") -GetFullVersion
            Write-Host "MongoDB Driver version: $mongoVersion / $mongoFullVersion"
            # Copy DLL
            If ($mongoVersion -eq 1.8) {
                Write-Host Copying Dll files from $PSScriptRoot\MongoDB\dlls to $installPath\Website\Bin ... 
                Get-ChildItem $PSScriptRoot\MongoDB\dlls\* -Include *.dll, *.xml | ForEach{
                    Write-Host Copying $_.fullName
                    Copy-Item -Path $_.fullName -Destination "$installPath\Website\Bin"
                }
                Write-Host Sitecore MongoDB driver updated -ForegroundColor Green
            }

            # Update WebConfig dependentAssembly
            $webConfigPath = Join-Path $installPath -ChildPath "Website\web.config"
            $webConfig = [xml](Get-Content $webConfigPath)

            [bool] $MongoDBBson = $false
            $dependentAssemblies = $webConfig.configuration.runtime.assemblyBinding.dependentAssembly
            if (!$dependentAssemblies) {
                Write-Host "Warning: dependentAssemblies is Empty" -ForegroundColor Yellow
            }

            $dependentAssemblies | ForEach {
                Write-Host $_.assemblyIdentity.GetAttribute("name").Trim()
                if ($_.assemblyIdentity.GetAttribute("name").Trim() -eq "MongoDB.Bson") {
                    $MongoDBBson = $true
                }
            }

            if (-Not($MongoDBBson -eq $true)) {
                Write-Host Updating $webConfigPath ...
                $currentDate = (Get-Date).ToString("yyyyMMdd_hh-mm-s")
                $backup = $webConfigPath + "__$currentDate"
                Write-Host "Backing up Web.config" 
                $webconfig.Save($backup)
                $dependentAssembly = $webConfig.CreateElement("dependentAssembly", "urn:schemas-microsoft-com:asm.v1")
                $dependentAssembly.InnerXml='<assemblyIdentity name="MongoDB.Bson" publicKeyToken="f686731cfb9cc103" culture="Neutral" xmlns="urn:schemas-microsoft-com:asm.v1"/><bindingRedirect oldVersion="1.8.3.9" newVersion="1.10.0.62" xmlns="urn:schemas-microsoft-com:asm.v1"/>'
                $webConfig.configuration.runtime.assemblyBinding.AppendChild($dependentAssembly)
                $dependentAssembly = $webConfig.CreateElement("dependentAssembly","urn:schemas-microsoft-com:asm.v1")
                $dependentAssembly.InnerXml='<assemblyIdentity name="MongoDB.Driver" publicKeyToken="f686731cfb9cc103" culture="Neutral" xmlns="urn:schemas-microsoft-com:asm.v1"/><bindingRedirect oldVersion="1.8.3.9" newVersion="1.10.0.62" xmlns="urn:schemas-microsoft-com:asm.v1"/>'
                $webConfig.configuration.runtime.assemblyBinding.AppendChild($dependentAssembly)
                Write-Host "Saving changes to Web.config" 
                $webconfig.Save($webConfigPath)
                Write-Host $webConfigPath updated -ForegroundColor Green
            }
        }
    
        # Copy License.xml from Data\License to Data folfer
        $sourceLicenceFile = Join-Path $installPath -ChildPath "Data\License\License.xml"
        $targetLicenceFile = Join-Path $installPath -ChildPath "Data\License.xml"
        if(-not (Test-Path targetLicenceFile)) {
            if(-not (Test-Path $sourceLicenceFile)) {
                Throw "Error, could not find $sourceLicenceFile !"
            }
            Write-Host Coying $sourceLicenceFile to $targetLicenceFile... 
            Copy-Item -Path $sourceLicenceFile -Destination $targetLicenceFile
            Write-Host $sourceLicenceFile copied updated -ForegroundColor Green
        }
    
        # Build Unity.Master.sln 
        $solutionPath = "C:\Sage\TFS\Global Web Development\Unity\Source\Main\Unity.Master.sln"
        if (Test-Path $solutionPath) {
            $answer = ProceedYN "Build $solutionPath"
            if ($answer -eq $true) 
            {
                #buildVS -path "C:\Sage\TFS\Global Web Development\Unity\Source\Main\Unity.Master.sln" -nuget $true -clean $true
                Invoke-Expression "$PSScriptRoot\Common\VSFunctions.ps1 -solutionPath `"$solutionPath`""    
            }
        }
    }

    Pause
}

catch {
    Write-Error $_.Exception.Message
    Pause
}