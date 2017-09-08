param(
	[string]$mongoDbPath = ($PSScriptRoot | split-path -parent),
    [string]$mongoDbServiceName = "MongoDB347",
    [int]$mongoDbPort = 27017,
    [string]$mongoDbDNS,
    [string]$mongoDbPrefix = "Local",
    [string]$configPath,
    [int]$Quiet = 0,
    [int]$clearHost = 1
)

# Load functions
$stdFuntionsPath = (split-path -parent $PSCommandPath)
. "$stdFuntionsPath\..\Common\StandardFunctions.ps1"

# Global params
$mongoMsi = "mongodb-win32-x86_64-2008plus-ssl-v3.4-latest-signed.msi"
#$mongoMsi = "mongodb-win32-x86_64-2008plus-ssl-2.8.0-rc5-signed.msi"
$urlMsi = "http://downloads.mongodb.org/win32/$mongoMsi"
$mongoZip = "mongodb-win32-x86_64-2008plus-ssl-v3.4-latest.zip"
$urlZip = "http://downloads.mongodb.org/win32/$mongoZip"

Function InstallMongoDBMsi (
    [string]$mongoDbPath
)
{
	Write-Host
	Write-Host-H2 -Message "func InstallMongoDBMsi"
    foreach ($key in $MyInvocation.BoundParameters.keys)
    {
        $value = (get-variable $key).Value 
        Write-Host-Param -ParamName $key -Value $value
    }
	Write-Host
    
    Try {
        $msiFile =  "$mongoDbPath\$mongoMsi" 
        if (-Not (Test-Path $msiFile))
        {
            Write-Host-Info -Message "Downloading MongoDB ($mongoMsi) installer to $mongoDbPath ..."
            $webClient = New-Object System.Net.WebClient 
            $webClient.DownloadFile($urlMsi,$msiFile)
            Write-Host MongoDB downloaded -ForegroundColor Green
        }

        Write-Host-Info -Message "Installing MongoDB ($mongoMsi) to $mongoDbPath ..."
        Start-Process msiexec.exe -Wait -ArgumentList " /q /i $msiFile INSTALLLOCATION=`"$mongoDbPath`" ADDLOCAL=`"Server,Router,Client`""
        Write-Host MondoDB installed -ForegroundColor Green

        #Write-Host Remove MongoDB ($mongoMsi) installer from $mongoDbPath ... -ForegroundColor Black -BackgroundColor White
        #Remove-Item $msiFile -recurse -force 
        #Write-Host MondoDB installer removed -ForegroundColor Green
    }
    Catch
    {
        Write-Error $_.Exception.Message
        throw  
    }
}


Function InstallMongoDBZip (
    [string]$mongoDbPath
)
{
	Write-Host
	Write-Host-H2 -Message "func InstallMongoDBZip"
    foreach ($key in $MyInvocation.BoundParameters.keys)
    {
        $value = (get-variable $key).Value 
        Write-Host-Param -ParamName $key -Value $value
    }
	Write-Host
    
    Try {
        $zipDist =  "$mongoDbPath\$mongoZip" 
        if (-Not (Test-Path $zipDist))
        {
            Write-Host-Info -Message "Downloading MongoDB ($mongoZip) to $mongoDbPath ..."
            $webClient = New-Object System.Net.WebClient 
            $webClient.DownloadFile($urlZip,$zipDist)
            Write-Host MongoDB downloaded -ForegroundColor Green
        }
 
        Write-Host-Info -Message "Unzipping $zipDist to $mongoDbPath ..."
        #Expand-Archive -LiteralPath $zipDist -DestinationPath $mongoDbPath
        [Reflection.Assembly]::LoadWithPartialName('System.IO.Compression.FileSystem') | Out-Null
        [IO.Compression.ZipFile]::OpenRead($zipDist).Entries | % {
            $target = $mongoDbPath+$_.FullName.replace($_.FullName.split('/')[0],'')
            $parent = Split-Path -Parent $target
            if (-not (Test-Path -LiteralPath $parent)) {
                 New-Item -Path $parent -Type Directory | Out-Null
            }
            [IO.Compression.ZipFileExtensions]::ExtractToFile($_, $target, $true)
        }
        Write-Host $zipDist unzipped -ForegroundColor Green
    }
    Catch
    {
        Write-Error $_.Exception.Message
        throw  
    }
}

Function ConfigureMongoDB (
    [string]$mongoDbPath,
    [string]$mongoDbServiceName,
    [int]$mongodbPort,
    [string]$monboDbPrefix
)
{
	Write-Host
	Write-Host-H2 -Message "func ConfigureMongoDB"
    foreach ($key in $MyInvocation.BoundParameters.keys)
    {
        $value = (get-variable $key).Value 
        Write-Host-Param -ParamName $key -Value $value
    }
	Write-Host
    Write-Host-Info -Message "Configuring MongoDB to $mongoDbPath ..."


    Try {
        if (ServiceExists -ServiceName $mongoDbServiceName)
        {
            Write-Host
            Write-Host-Info -Message "$mongoDbServiceName service should be stopped and removed ..."
            & sc.exe stop $mongoDbServiceName
            & sc.exe delete $mongoDbServiceName
            Write-Host $mongoDbServiceName service removed -ForegroundColor Green
        }

        if (Test-Path $mongoDbPath\data)
        {
            Write-Host
            Write-Host-Info -Message "Removing existing $mongoDbPath\data folder ..."
            Remove-Item $mongoDbPath\data -Force -Recurse -ErrorAction Stop
            Write-Host $mongoDbPath\data folder removed -ForegroundColor Green
        }

        Write-Host
        Write-Host-Info -Message "Creating $mongoDbPath\data folders ..."
        New-Item $mongoDbPath\data\db -type directory -Force
        New-Item $mongoDbPath\data\log -type directory -Force
        Write-Host $mongoDbPath\data folder created -ForegroundColor Green

        $ConfigPath = "$mongoDbPath\mongod.cfg" 

        Write-Host
        Write-Host-Info -Message "Copying $PSScriptRoot\mongod.cfg configuration file to $ConfigPath ..."
        Copy-Item $PSScriptRoot\mongod.cfg $ConfigPath -Force
        Write-Host $PSScriptRoot\mongod.cfg copied to $ConfigPath -ForegroundColor Green
        
        Write-Host
        Write-Host-Info -Message "Updating $ConfigPath configuration file ..."
        (Get-Content $ConfigPath) -replace "<MongoDbPath>",$mongoDbPath | Set-Content $ConfigPath         
        (Get-Content $ConfigPath) -replace "<MongoDbPort>",$mongodbPort | Set-Content $ConfigPath         
        Write-Host $ConfigPath updated -ForegroundColor Green

        Write-Host
        Write-Host-Info -Message "Configuring $mongoDbServiceName service ..."
        & "$mongoDbPath\bin\mongod" --config $mongoDbPath\mongod.cfg --install --serviceName $mongoDbServiceName --serviceDisplayName $mongoDbServiceName
        Write-Host $mongoDbServiceName service configured -ForegroundColor Green

        if (ServiceExists -ServiceName $mongoDbServiceName)
        {
            Write-Host-Info -Message "Starting $mongoDbServiceName service ..."
            & net start $mongoDbServiceName
            Write-Host $mongoDbServiceName service started -ForegroundColor Green
        }
        Write-Host MongoDB configured and started -ForegroundColor Green

        $createSitecoreDbJsPath = "$mongoDbPath\CreateSitecoreDb.js"
        Write-Host
        Write-Host-Info -Message "Copying $PSScriptRoot\Scripts\CreateSitecoreDb.js configuration file to $createSitecoreDbJsPath ..."
        Copy-Item $PSScriptRoot\Scripts\CreateSitecoreDb.js $createSitecoreDbJsPath -Force
        Write-Host $PSScriptRoot\Scripts\CreateSitecoreDb.js copied to $createSitecoreDbJsPath -ForegroundColor Green
        
        Write-Host
        Write-Host-Info -Message "Updating $createSitecoreDbJsPath configuration file ..."
        (Get-Content $createSitecoreDbJsPath) -replace "<prefix>",$mongoDbPrefix | Set-Content $createSitecoreDbJsPath         
        Write-Host $createSitecoreDbJsPath updated -ForegroundColor Green

        Write-Host
        Write-Host-Info -Message "Configuring $mongoDbServiceName Users and Databases ..."
        . $mongoDbPath\bin\mongo.exe -port $mongoDbPort $createSitecoreDbJsPath > null
        Write-Host MongoDB Users and Databases configured -ForegroundColor Green
    }
    Catch
    {
        Write-Error $_.Exception.Message
        throw  
    }
}


if ($clearHost -eq 1){
    Clear-Host
}
#$cd = $(Get-Location)
$cd = $PSScriptRoot | split-path -parent
. "$($PSScriptRoot + "\cd.ps1")"

Write-Host-H1 -Message "Install MongoDB Service"

Write-Host-Param -ParamName "Script file root" -Value $PSScriptRoot
Write-Host-Param -ParamName "Current directory" -Value $cd

foreach ($key in $MyInvocation.BoundParameters.keys)
{
    $value = (get-variable $key).Value 
    Write-Host-Param -ParamName $key -Value $value
}
Write-Host

if ($configPath) {
    [xml]$configXml = Read-InstallConfigFile -configPath $configPath 
    if (!$configXml) {Throw "Could not find configuration file at specified path: $configPath" }
    $mongoDbPath = $configXml.InstallSettings.MongoDbPath
    Write-Host-Param -ParamName "mongoDbPath" -Value $mongoDbPath
    $mongoDbServiceName = $configXml.InstallSettings.MongoDbServiceName
    Write-Host-Param -ParamName "mongoDbServiceName" -Value $mongoDbServiceName
    $mongoDbPort = $configXml.InstallSettings.MongoDbPort
    Write-Host-Param -ParamName "mongoDbPort" -Value $mongoDbPort
    $mongoDbDNS = $configXml.InstallSettings.MongoDbDNS
    Write-Host-Param -ParamName "mongoDbDNS" -Value $mongoDbDNS
    $mongoDbPrefix = $configXml.InstallSettings.MongoDbPrefix
    Write-Host-Param -ParamName "mongoDbPrefix" -Value $mongoDbPrefix
}

try {
    $answer = ProceedYN "Install $mongoDbServiceName"
    if ($answer -eq $true) 
    {
        if ((Test-Path -path $mongoDbPath) -eq $True) 
        { 
            Write-Host
            Write-Host "Seems you already installed $mongoDbServiceName"
            $answer = ProceedYN "Remove and Re-Install"
            if ($answer -eq $true) 
            {
                if (ServiceExists -ServiceName $mongoDbServiceName)
                {
                    Write-Host
                    Write-Host-Info -Message "$mongoDbServiceName service should be stopped and removed ... "
                    & sc.exe stop $mongoDbServiceName
                    & sc.exe delete $mongoDbServiceName
                    Write-Host $mongoDbServiceName service removed -ForegroundColor Green
                }

                if (Test-Path $mongoDbPath\data)
                {
                    Write-Host
                    Write-Host-Info -Message "Removing existing $mongoDbPath\data folder ..."
                    Remove-Item $mongoDbPath\data -Force -Recurse -ErrorAction Stop
                    Write-Host $mongoDbPath\data folder removed -ForegroundColor Green
                }
            }

            else {
                Exit
            }
        }
        else {
            New-Item $mongoDbPath -type directory
        }

        #InstallMongoDBMsi -mongoDbPath $mongoDbPath 
        InstallMongoDBZip -mongoDbPath $mongoDbPath 
        ConfigureMongoDB -mongoDbPath $mongoDbPath -mongoDbServiceName $mongoDbServiceName -mongodbPort $mongoDbPort -monboDbPrefix $mongoDbPrefix
        UpdateHost -hostEntry $mongoDbDNS
        Pause
    }
}

catch {
    Write-Error $_.Exception.Message
    Pause
    Throw $_.Exception.Message
}
