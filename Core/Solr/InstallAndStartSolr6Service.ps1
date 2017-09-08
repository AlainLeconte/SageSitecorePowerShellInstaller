param(
    [string]$serviceName = "Solr6",
    [string]$serviceDisplayName = "Solr6 Service",
    [int]$servicePort = 8983,
    [string]$solrPath,
    [string]$solrHomeSuffix,
    [int]$isSlave = 0,
    [string]$solrMasterDNS="localhost:8983",
    [string]$configPath,
    [int]$Quiet = 0,
    [int]$clearHost = 1
)

# Load functions
$stdFuntionsPath = (split-path -parent $PSCommandPath)
. "$stdFuntionsPath\..\Common\StandardFunctions.ps1"
. "$stdFuntionsPath\SolrFunctions.ps1"

function SolrInstallService (
    [string]$serviceName,
    [string]$serviceDisplayName, 
    [string]$serviceFullDisplayName, 
    [int]$servicePort,
    [string]$solrPath,
    [string]$solrHome
) 
{
    Write-Host
	Write-Host-H2 -Message "func SolrInstallService"
    foreach ($key in $MyInvocation.BoundParameters.keys)
    {
        $value = (get-variable $key).Value 
        Write-Host-Param -ParamName $key -Value $value
    }
	Write-Host

    [string]$serviceFullName = $serviceName+$servicePort
    Write-Host-Param -ParamName serviceFullName -Value $serviceFullName        
	Write-Host

    [bool]$Return = $false

    Try {
        if (-not(Test-Path $solrPath) -or -not(Test-Path "$solrPath\Setup")) {
            $zipDist = "$cd\Solr\SolrFor" + $solrHomeSuffix + "Dist-6.6.0.zip"
            if (-not(Test-Path $zipDist)) {
                $zipDist = "C:\Sage\SitecoreSites\SitecoreInstallation\Solr\SolrFor" + $solrHomeSuffix + "Dist-6.6.0.zip"
            }
            Write-Host-Info -Message "Unzipping $zipDist to $solrPath ..."
            Expand-Archive -LiteralPath $zipDist -DestinationPath $solrPath
            Write-Host $zipDist unzipped -ForegroundColor Green
        }

        if (-not(Test-Path $solrPath\$solrInstance\bin\solr.cmd)) {
            Invoke-Expression "$PSScriptRoot\CreateSymLinks.ps1 -solrInstancePath `"$solrPath\$solrInstance`" -solrDistPath `"$solrPath\SolrDist`" -clearHost 0"
        }
    
        #if ($(SolrRemoveService -serviceName $serviceName -servicePort $servicePort) -eq $true)
        #{
            & $exeNSSM install $serviceFullName `"$solrPath\$solrInstance\bin\solr.cmd`" `"start -f -p $servicePort -s $solrPath\$solrHome`"
            & $exeNSSM set $serviceFullName DisplayName `"$serviceFullDisplayName`"
            & $exeNSSM set $serviceFullName Description `"Script to start and stop $serviceFullDisplayName`"
            $answer = ProceedYN -Message "Edit $serviceFullDisplayName"
            if ($answer -eq $true) 
            {
                & $exeNSSM edit $serviceFullName
            }
            $Return=($(ServiceExists -ServiceName $serviceFullName) -eq $true)
            #$Return=($(SolrStartService -serviceName $serviceName -servicePort $servicePort) -eq $true)
        #}
        
        #else 
        #{
        #}
    }
    Catch
    {

        Write-Error $_.Exception.Message
        throw  
    }

    Write-Host "SolrInstallService(...): $Return" -ForegroundColor $(if ($Return) {"Green"} else {"Red"})
    return $Return
}

function SolrConfigure(
    [string]$solrPath,
    [string]$solrHome,
    [int]$isSlave = 0,
    [string]$solrMasterDNS
)
{
    Write-Host
	Write-Host-H2 -Message "func SolrConfigure"
    foreach ($key in $MyInvocation.BoundParameters.keys)
    {
        $value = (get-variable $key).Value 
        Write-Host-Param -ParamName $key -Value $value
    }
	Write-Host

    [bool]$Return = $false

    Try {
        $SitecoreIndexNames | % {
	        Write-host-Param -ParamName ConfigSetName -Value ($_)
            #Create-SitecoreConfigSet -solrHomePath $solrPath\$solrHome -baseConfigSet "sitecore_configs_$(if ($isSlave) {"slave"} else {"master"})" -sitecoreConfigSetName ($_)
            Create-SitecoreConfigSet -solrHomePath $solrPath\$solrHome -isSlave $isSlave -solrMasterDNS $solrMasterDNS -sitecoreConfigSetName ($_)
        }
        $Return = $true
    }
    Catch
    {
        Write-Error $_.Exception.Message
        throw  
    }

    Write-Host "SolrConfigure(...): $Return" -ForegroundColor $(if ($Return) {"Green"} else {"Red"})
    return $Return
}


if ($clearHost -eq 1) {
    Clear-Host
}

#$cd = $(Get-Location)
$cd = $PSScriptRoot | split-path -parent
. "$($PSScriptRoot + "\cd.ps1")"

Write-Host-H1 -Message "Install $serviceName - $serviceFullDisplayName"

Write-Host-Param -ParamName "Script file root" -Value $PSScriptRoot
Write-Host-Param -ParamName "Current directory (cd)" -Value $cd
Write-Host

foreach ($key in $MyInvocation.BoundParameters.keys)
{
    $value = (get-variable $key).Value 
    Write-Host-Param -ParamName $key -Value $value
}
Write-Host

try {
    if ($configPath) {
        [xml]$configXml = Read-InstallConfigFile -configPath $configPath 
        if (!$configXml) {Throw "Could not find configuration file at specified path: $configPath" }
        
        $installMaster = $(Get-ConfigOption -config $configXml -optionName "MasterSettings/enabled" -isAttribute $TRUE)
        Write-Host-Param -ParamName installMaster -Value $installMaster 
        $installSlave = $(Get-ConfigOption -config $configXml -optionName "SlaveSettings/enabled" -isAttribute $TRUE)
        Write-Host-Param -ParamName installSlave -Value $installSlave        
        if ($installMaster -eq "true") {
            $settings = $configXml.InstallSettings.MasterSettings
        }
        else {
            if ($installSlave -eq "true") {
                $settings = $configXml.InstallSettings.SlaveSettings
            }
        }
        if ($settings) {
            $serviceName = $settings.ServiceName
            Write-Host-Param -ParamName "serviceName" -Value $serviceName
            $serviceDisplayName = $settings.ServiceDisplayName
            Write-Host-Param -ParamName "serviceDisplayName" -Value $serviceDisplayName
            $servicePort = [int]$settings.ServicePort
            Write-Host-Param -ParamName "servicePort" -Value $servicePort
            $solrPath = $settings.SolrPath
            Write-Host-Param -ParamName "solrPath" -Value $solrPath
            $solrHomeSuffix = $settings.SolrHomeSuffix
            Write-Host-Param -ParamName "solrHomeSuffix" -Value $solrHomeSuffix
            $isSlave = $(if ($installMaster -eq "true") {0} else {1})
            Write-Host-Param -ParamName "isSlave" -Value $isSlave
            if($isSlave -eq 1) {
                $solrMasterDNS="$settings.SolrMasterHostname:$settings.SolrMasterPort"
                Write-Host-Param -ParamName "solrMasterDNS" -Value $solrMasterDNS
            }
        }

        if (!$SitecoreIndexNames) {
            $SitecoreIndexNames = $configXml.InstallSettings.ConfigSets.ConfigSet
        }
    
        Write-Host
    }

    if(-not($serviceDisplayName)) { 
        $serviceDisplayName = $serviceName + "Service" 
        Write-Host-Param -ParamName "serviceDisplayName" -Value $serviceDisplayName
    }
    $serviceFullDisplayName = "$serviceDisplayName [$servicePort]"
    Write-Host-Param -ParamName "serviceFullDisplayName" -Value $serviceFullDisplayName
    $solrInstance = "Solr"+$(if ($isSlave -eq 1) {"Slave"} else {"Master"}) + "Instance"
    Write-Host-Param -ParamName "solrInstance" -Value $solrInstance
    $solrHome = "Solr"+$(if ($isSlave -eq 1) {"Slave"} else {"Master"}) + "Home" + $solrHomeSuffix
    Write-Host-Param -ParamName "solrHome" -Value $solrHome
    $exeNSSM = "$solrPath\Setup\nssm.exe"
    if (-Not(Test-Path($exeNSSM))) {
        $exeNSSM = "$PSScriptRoot\nssm.exe"
    }
    Write-Host-Param -ParamName "exeNSSM" -Value $exeNSSM
    Write-Host

    if(-not($serviceName)) { Throw "You must supply a value for -serviceName" }
    if(-not($servicePort)) { Throw "You must supply a value for -servicePort" }
    if(-not($solrPath)) { Throw "You must supply a value for -solrPath" }
    if(-not($solrHomeSuffix)) { Throw "You must supply a value for -solrHomeSuffix" }

    if(-not($SitecoreIndexNames)) { Throw "You must supply a value for -configPath" }

    if ($(SolrRemoveService -serviceName $serviceName -servicePort $servicePort) -eq $true)
    {
        $answer = ProceedYN -Message "Install $serviceFullDisplayName"
        if ($answer -eq $true) 
        {
            if ($(SolrInstallService -serviceName $serviceName -serviceDisplayName $serviceDisplayName -serviceFullDisplayName $serviceFullDisplayName -servicePort $servicePort -solrPath $solrPath -solrHome $solrHome) -eq $true) {
                if ($(SolrConfigure -solrPath $solrPath -solrHome $solrHome -isSlave $isSlave -solrMasterDNS $solrMasterDNS) -eq $true)
                {
                    if ($(SolrStartService -serviceName $serviceName -servicePort $servicePort) -eq $true) {
                        Write-Host "Opening Solr admin page in 10 seconds."
                        Start-Sleep -m 10000
                        $SolrBaseUrl= "http://localhost:$servicePort/solr"
                        START $SolrBaseUrl
                    }
                    else {
                    }
                }
                else {
                }
            }
            else {
            }
        }
        else {
        }
    }
    Pause
}

catch {
    Write-Error $_.Exception.Message
    Pause
    Throw $_.Exception.Message
}