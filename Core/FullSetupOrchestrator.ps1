param(
    [string]$configPathSitecore, 
    [string]$configPathMongoDb, 
    [string]$configPathSolr, 
    [int]$Quiet = 0
)

# Load functions
$stdFuntionsPath = (split-path -parent $PSCommandPath)
. "$stdFuntionsPath\Common\StandardFunctions.ps1"
#. "$stdFuntionsPath\Common\VSFunctions.ps1"

Clear-Host
#$cd = $(Get-Location)
$cd = $PSScriptRoot | split-path -parent
. "$($PSScriptRoot + "\cd.ps1")"


Write-Host-H1 -Message "Install MongoDB using $configPathMongoDB"
Write-Host-H1 -Message "Install Solr using $configPathSolr"
Write-Host-H1 -Message "Install Sitecore using $configPathSitecore"

Write-Host-Param -ParamName "Script file root" -Value $PSScriptRoot
Write-Host-Param -ParamName "Current directory (cd)" -Value $cd
Write-Host

foreach ($key in $MyInvocation.BoundParameters.keys)
{
    $value = (get-variable $key).Value 
    Write-Host-Param -ParamName $key -Value $value
}
Write-Host


[bool]$installThirPartyPathEnvVariable = $false
[bool]$installMaxWebConfigFileSize = $false
[bool]$installPDFFilter = $false
[bool]$installUrlRewrite = $false
[bool]$installMongoDb = $false
[bool]$installSolr = $false
[bool]$installSitecore = $false

try {
    if(-not($configPathSitecore)) { Throw "You must supply a value for -configPathSitecore" }

    Write-Host-Info -Message "Reading $configPathSitecore ..."
    [xml]$configXmlSitecore = Read-InstallConfigFile -configPath $configPathSitecore  
    if (!$configXmlSitecore) {Throw "Could not find configuration file at specified path: $configPathSitecore" }
    
    $answer = ProceedYN "Continue"
    if ($answer -ne $true) 
    {
        Write-Host Full Sitecore installation aborted -ForegroundColor Red
        Start-Sleep -s 1
        Return
    }
    
    # ThirPartyPathEnvVariable
    $answer = ProceedYN "Add ThirdParty environment variable"
    if ($answer -eq $true)
    {
        $thirPartyPath = "C:\Sage\TFS\Global Web Development\ThirdParty"
        $currentValue=[Environment]::GetEnvironmentVariable("ThirdPartyPath","machine")
        if (!$currentValue -or ($currentValue -ne $thirPartyPath)) {
            Write-Host-Info -Message "Adding ThirdPartyPath machine environment variable, please wait ..."
            [Environment]::SetEnvironmentVariable("ThirdPartyPath","C:\Sage\TFS\Global Web Development\ThirdParty","Machine")
            Write-Host ThirdPartyPath environment variable added successfully -ForegroundColor Green
            Write-Host 
        }
        else {
            Write-Host ThirdPartyPath environment variable alredy exists -ForegroundColor Green
        }
        $installThirPartyPathEnvVariable = $true
    }
    
    # MaxWebConfigFileSize
    $answer = ProceedYN "Register MaxWebConfigFileSize"
    if ($answer -eq $true) 
    {
        Write-Host-Info -Message "Registering MaxWebConfigFileSize ..."
        $process = Start-Process reg -ArgumentList "import `"C:\Sage\SitecoreSites\SitecoreInstallation\ThirdParty\MaxWebConfigFileSize\MaxWebConfigFileSizeInKB.reg`"" -PassThru -Wait
        if ($process.ExitCode -ne 0) {Throw "Register MaxWebConfigFileSize generate an error !"}
        Write-Host MaxWebConfigFileSize registered -ForegroundColor Green
        
        <#
        $result=(Invoke-Command -ScriptBlock { 
            Try {
                regedit /i "C:\Sage\SitecoreSites\SitecoreInstallation\ThirdParty\MaxWebConfigFileSize\MaxWebConfigFileSizeInKB.rg"
            }
            catch {
                return $_
            }
        }) 

        if ($result) { 
            Write-Host "Application generated error" -ForegroundColor Red 
            PAUSE
        }
        #>

        $installMaxWebConfigFileSize = $true
    }

    # PDFFilter
    $answer = ProceedYN "Install PDDFilter"
    if ($answer -eq $true) 
    {
        # Step 1 install PDFFilter
        $pdfFilterMsi = "C:\Sage\SitecoreSites\SitecoreInstallation\ThirdParty\PDFFilter\PDFFilter64Setup.msi"
        Write-Host-Info -Message "Installing PDFFilter ($pdfFilterMsi) ..."
        Start-Process msiexec.exe -Wait -ArgumentList " /q /i $pdfFilterMsi" -PassThru
        if ($process.ExitCode -ne 0) {Throw "Install PDFFilter generate an error !"}
        Write-Host PDFFilter installed -ForegroundColor Green
        
        # Step 2 Copy Dlls, Unity Sitecore 8.0-r4 only see below after Sitecore install in Unity section 
        # 

        $installPDFFilter = $true
    }


    # UrlRewrite
    $answer = ProceedYN "Install UrlRewrite 2 & UrlRewrite Extensibility"
    if ($answer -eq $true) 
    {
        #$urlRewriteExe = "C:\Sage\SitecoreSites\SitecoreInstallation\ThirdParty\UrlRewrite\urlrewrite2.exe"
        $webPiCmd="C:\Sage\SitecoreSites\SitecoreInstallation\ThirdParty\UrlRewrite\WebPI\WebpiCmd.exe"
        Write-Host-Info -Message "Installing UrlRewrite ..."
        Start-Process $webPiCmd -ArgumentList " /Install /Products:'UrlRewrite2' /AcceptEULA" -PassThru -Wait -Verb runas
        if ($process.ExitCode -ne 0) {Throw "Install URLRewrite2 generate an error !"}
        <#
        Invoke-Command -ScriptBlock {
            "C:\Sage\SitecoreSites\SitecoreInstallation\ThirdParty\UrlRewrite\WebPI\WebpiCmd.exe /Install /Products:'UrlRewrite2' /AcceptEULA"
        }
        #>
        Write-Host UrlRewrite installed -ForegroundColor Green
        Write-Host
        
        $urlRewriteMsi = "C:\Sage\SitecoreSites\SitecoreInstallation\ThirdParty\UrlRewrite\RewriteExtensibility.msi"
        Write-Host-Info -Message "Installing UrlRewrite Extensibility($urlRewriteMsi) ..."
        Start-Process msiexec.exe -ArgumentList " /q /i $urlRewriteMsi" -Wait -PassThru
        if ($process.ExitCode -ne 0) {Throw "Install UrlRewrite Extensibility generate an error !"}
        Write-Host UrlRewrite Extensibility installed -ForegroundColor Green

        $installUrlRewrite = $true
    }
    
    # MongoDB
    $answer = ProceedYN "Install MongoDB"
    if ($answer -eq $true) 
    {
        if(-not($configPathMongoDB)) { Throw "You must supply a value for -configPathMongoDB" }
        Write-Host-Info -Message "Reading $configPathMongoDB ..."
        [xml]$configXmlMongoDB = Read-InstallConfigFile -configPath $configPathMongoDB  
        if (!$configXmlMongoDB) {Throw "Could not find configuration file at specified path: $configPathMongoDB" }

        Copy-Item -Path $PSScriptRoot\cd.ps1 -Destination $PSScriptRoot\MongoDB\cd.ps1 -Force
        Write-Host-Info -Message "Launching $PSScriptRoot\MongoDB\InstallAndStartMongoDB.ps1 -configPath $configPathMongoDB ..."
        Invoke-Expression "& '$PSScriptRoot\MongoDB\InstallAndStartMongoDB.ps1' -ConfigPath '$configPathMongoDB' -clearHost 0"
        Write-Host MongoDb installed successfully -ForegroundColor Green
        Write-Host 
        Remove-Item -Path $PSScriptRoot\MongoDB\cd.ps1

        $installMongoDb = $true
    }


    # Solr
    $answer = ProceedYN "Install Solr"
    if ($answer -eq $true) 
    {
        if(-not($configPathSolr)) { Throw "You must supply a value for -configPathSolr" }
        Write-Host-Info -Message "Reading $configPathSolr ..."
        [xml]$configXmlSolr = Read-InstallConfigFile -configPath $configPathSolr  
        if (!$configXmlSolr) {Throw "Could not find configuration file at specified path: $configPathSolr" }

        Copy-Item -Path $PSScriptRoot\cd.ps1 -Destination $PSScriptRoot\Solr\cd.ps1 -Force
        Write-Host-Info -Message "Launching $PSScriptRoot\Solr\SolrOrchestrator.ps1 -configPath $configPathSolr ... "
        Invoke-Expression "& '$PSScriptRoot\Solr\SolrOrchestrator.ps1' -ConfigPath '$configPathSolr' -clearHost 0"
        Write-Host Solr installed successfully -ForegroundColor Green
        Write-Host 
        Remove-Item -Path $PSScriptRoot\Solr\cd.ps1

        $installSolr = $true
    }
    
   
    # Sitecore installation 
    $answer = ProceedYN "Install Sitecore"
    if ($answer -eq $true) 
    {
        # Manage $DatabaseInstallPath exists
        $DatabaseType = $(Get-ConfigValue -config $configXmlSitecore -optionName "Database/type" -isAttribute $TRUE)
        $DatabaseEnabled = $(Get-ConfigOption -config $configXmlSitecore -optionName "Database/enabled" -isAttribute $TRUE)
        $DatabaseInstallPath = $configXmlSitecore.InstallSettings.Database.DatabaseInstallPath.DataFiles.Local 
        Write-Host-Param -ParamName DatabaseType -Value $DatabaseType
        Write-Host-Param -ParamName DatabaseEnabled -Value $DatabaseEnabled
        Write-Host-Param -ParamName DatabaseInstallPath -Value $DatabaseInstallPath
        if ($DatabaseEnabled -eq "True" -and  $DatabaseType -eq "Local") {
            if (-not (Test-Path $DatabaseInstallPath)) {
                Write-Host-Info -Message "Creating $DatabaseInstallPath ..."
                New-Item $DatabaseInstallPath -type directory
                Write-Host $DatabaseInstallPath created -ForegroundColor Green
            } 
            else {
                Write-Host $DatabaseInstallPath already exists -ForegroundColor Green
            }
        }
        Start-Sleep -s 1

        # Install Sitecore
        Write-Host-Info -Message "Launching $PSScriptRoot\SageSitecoreSetup.ps1 -ConfigPath $configPathSitecore ..."
        Invoke-Expression "& '$PSScriptRoot\Sitecore\SageSitecoreSetup.ps1' -ConfigPath '$configPathSitecore'"
        Write-Host Sitecore installed successfully -ForegroundColor Green

        $installSitecore = $true
    }
    Write-Host 


    # Get Sitecore.kernel.dll version
    $installPath = Join-Path $configXmlSitecore.InstallSettings.WebServer.SitecoreInstallRoot -ChildPath $configXmlSitecore.InstallSettings.WebServer.SitecoreInstallFolder
    if (Test-Path $(Join-Path $installPath -ChildPath "WebSite\Bin\Sitecore.kernel.dll")) {
        Write-Host-Info -Message "Checking Sitecore version ... "
        [decimal]$sitecoreVersion = Get-DllVersion -DllPath $(Join-Path $installPath -ChildPath "WebSite\Bin\Sitecore.kernel.dll")
        $sitecoreFullVersion = Get-DllVersion -DllPath $(Join-Path $installPath -ChildPath "WebSite\Bin\Sitecore.kernel.dll") -GetFullVersion
        Write-Host "SitecoreVersion: $sitecoreVersion / $sitecoreFullVersion"
        Write-Host 
    }


    # Unity ?
    if ($sitecoreVersion -and $sitecoreVersion -eq 8.0) {
        if(-Not(Test-Path $installPath)) {
            Throw "Error, could not find $installPath !"
        }

        # MongoDB stuff for sitecore 8.0-r4(150621) using old MongoDB 1.8.3.9 Driver  
        # Get MongoDB.Driver.dll version
        Write-Host-Info -Message "Checking Sitecore MongoDB driver ..."
        [decimal]$mongoVersion = Get-DllVersion -DllPath $(Join-Path $installPath -ChildPath "WebSite\Bin\MongoDB.Driver.dll")
        $mongoFullVersion = Get-DllVersion -DllPath $(Join-Path $installPath -ChildPath "WebSite\Bin\MongoDB.Driver.dll") -GetFullVersion
        Write-Host "MongoDB Driver version: $mongoVersion / $mongoFullVersion"
        Write-Host

        # Copy DLL
        If ($mongoVersion -eq 1.8) {
            $source = "$PSScriptRoot\MongoDB\dlls\1.10.0.62"
            $target = "$installPath\Website\Bin"
            Write-Host-Info -Message "Copying Dll files from $source to $target ..."
            Get-ChildItem $source\* -Include *.dll, *.xml | ForEach{
                Write-Host Copying $_.fullName
                Copy-Item -Path $_.fullName -Destination $target -Force
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
            #Write-Host $_.assemblyIdentity.GetAttribute("name").Trim()
            if ($_.assemblyIdentity.GetAttribute("name").Trim() -eq "MongoDB.Bson") {
                $MongoDBBson = $true
            }
        }

        if (-Not($MongoDBBson -eq $true)) {
            Write-Host-Info -Message "Updating $webConfigPath ..."
            $currentDate = (Get-Date).ToString("yyyyMMdd_hh-mm-s")
            $backup = $webConfigPath + "__$currentDate"
            Write-Host-Info -Message "Backing up Web.config ..." 
            $webconfig.Save($backup)
            $dependentAssembly = $webConfig.CreateElement("dependentAssembly", "urn:schemas-microsoft-com:asm.v1")
            $dependentAssembly.InnerXml='<assemblyIdentity name="MongoDB.Bson" publicKeyToken="f686731cfb9cc103" culture="Neutral" xmlns="urn:schemas-microsoft-com:asm.v1"/><bindingRedirect oldVersion="1.8.3.9" newVersion="1.10.0.62" xmlns="urn:schemas-microsoft-com:asm.v1"/>'
            $webConfig.configuration.runtime.assemblyBinding.AppendChild($dependentAssembly)
            $dependentAssembly = $webConfig.CreateElement("dependentAssembly","urn:schemas-microsoft-com:asm.v1")
            $dependentAssembly.InnerXml='<assemblyIdentity name="MongoDB.Driver" publicKeyToken="f686731cfb9cc103" culture="Neutral" xmlns="urn:schemas-microsoft-com:asm.v1"/><bindingRedirect oldVersion="1.8.3.9" newVersion="1.10.0.62" xmlns="urn:schemas-microsoft-com:asm.v1"/>'
            $webConfig.configuration.runtime.assemblyBinding.AppendChild($dependentAssembly)
            Write-Host-Info -Message "Saving changes to Web.config ..." 
            $webconfig.Save($webConfigPath)
            Write-Host $webConfigPath updated -ForegroundColor Green
        }
    
        
        # Copy License.xml from Data\License to Data folfer
        $sourceLicenceFile = Join-Path $installPath -ChildPath "Data\License\License.xml"
        $targetLicenceFile = Join-Path $installPath -ChildPath "Data\License.xml"
        if(-not (Test-Path $targetLicenceFile)) {
            if(-not (Test-Path $sourceLicenceFile)) {
                Throw "Error, could not find $sourceLicenceFile !"
            }
            Write-Host-Info -Message "Coying $sourceLicenceFile to $targetLicenceFile ..."
            Copy-Item -Path $sourceLicenceFile -Destination $targetLicenceFile
            Write-Host $sourceLicenceFile copied updated -ForegroundColor Green
        }

        # PDDFilter copy Dlls
        if ( -not(Test-Path ("C:\Windows\System32\inetsrv\PDFFilter.dll"))) {
            $source = "C:\Sage\SitecoreSites\SitecoreInstallation\ThirdParty\PDFFilter\dlls"
            $target = "C:\Windows\System32\inetsrv"
            Write-Host-Info -Message "Copying Dll files from $source to $target ..."
            Get-ChildItem $source\* -Include *.dll, *.xml | ForEach{
                Write-Host Copying $_.fullName
                Copy-Item -Path $_.fullName -Destination $target -Force
            }
            Write-Host PDDFilter Dlls copied -ForegroundColor Green
        }
        
    
        # Build Unity.Master.sln 
        $solutionPath = "C:\Sage\TFS\Global Web Development\Unity\Source\Main\Unity.Master.sln"
        if (Test-Path $solutionPath) {
            $answer = ProceedYN "Build $solutionPath"
            if ($answer -eq $true) 
            {
                Write-Host-Info -Message "Building $solutionPath ..."
                #buildVS -path "C:\Sage\TFS\Global Web Development\Unity\Source\Main\Unity.Master.sln" -nuget $true -clean $true
                Invoke-Expression "& '$PSScriptRoot\Common\VSFunctions.ps1' -solutionPath `"$solutionPath`""    
                Write-Host Building $solutionPath builded -ForegroundColor Green
            }
        }

        # MongoDB stuff for sitecore 8.0-r4(150621) using old MongoDB 1.8.3.9 Driver  
        # Get MongoDB.Driver.dll version
        Write-Host-Info -Message "Checking Sitecore MongoDB driver ..."
        [decimal]$mongoVersion = Get-DllVersion -DllPath $(Join-Path $installPath -ChildPath "WebSite\Bin\MongoDB.Driver.dll")
        $mongoFullVersion = Get-DllVersion -DllPath $(Join-Path $installPath -ChildPath "WebSite\Bin\MongoDB.Driver.dll") -GetFullVersion
        Write-Host "MongoDB Driver version: $mongoVersion / $mongoFullVersion"
        Write-Host

        # Switch to old 1.8.3.9 MongoDB Driver DLLs
        If ($mongoVersion -eq 1.10) {
            Write-Host-Info -Message "Rolling back Dll files from $PSScriptRoot\MongoDB\dlls\1.8.3.9 to $installPath\Website\Bin ..."
            Get-ChildItem $PSScriptRoot\MongoDB\dlls\1.8.3.9\* -Include *.dll, *.xml | ForEach{
                Write-Host Copying $_.fullName
                Copy-Item -Path $_.fullName -Destination "$installPath\Website\Bin" -Force
            }
            Write-Host Sitecore MongoDB driver rolled back -ForegroundColor Green
        }

        # Comment MongoDb host entry 
        if ($configXmlMongoDB) {
            if ($configXmlMongoDB.InstallSettings.MongoDbDNS) {
                UpdateHost -hostEntry $configXmlMongoDB.InstallSettings.MongoDbDNS -comment
            }
        }

        # Drop standard original Sitecore databases
        # to be done .. 

    }

    Pause
}

catch {
    Write-Error $_.Exception.Message
    Pause
}