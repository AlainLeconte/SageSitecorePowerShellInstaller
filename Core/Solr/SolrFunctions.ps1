function SolrStopService (
	[string]$serviceName,
    [int]$servicePort
)
{
    Write-Host
	Write-Host-H2 -Message "func SolrStopService"
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

    if (ServiceExists -ServiceName $serviceFullName  ) 
    {
        $svStatus = (GetServiceStatus -ServiceName $serviceFullName)
        if ($svStatus -eq "Running") 
        {
            $answer = ProceedYN -Message "Stop $serviceFullName"
            if ($answer -eq $true) 
            {
                & $exeNSSM stop $serviceFullName 
                $svStatus = (GetServiceStatus -ServiceName $serviceFullName)
                $Return = ($svStatus -eq "Stopped")
                Write-Host "$serviceFullName status: $svStatus" -ForegroundColor $(if ($Return) {"Green"} else {"Red"})
            }
        }
        else 
        {
            Write-Host "$serviceFullName is NOT Running ($svStatus)" -ForegroundColor Green
            $Return = $true
        }
    }
    else
    {
        Write-Host $serviceFullName does NOT exists -ForegroundColor Green
        $Return = $true
    }

    Write-Host "SolrStopService($serviceFullName): $Return" -ForegroundColor  $(if ($Return) {"Green"} else {"Red"})
    return $Return
}

function SolrStartService (
	[string]$serviceName,
    [int]$servicePort
)
{
    Write-Host
	Write-Host-H2 -Message "func SolrStartService"
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

    if (ServiceExists -ServiceName $serviceFullName  ) 
    {
        $svStatus = (GetServiceStatus -ServiceName $serviceFullName )
        if ($svStatus -ne "Running") 
        {
            $answer = ProceedYN -Message "Start $serviceFullDisplayName"
            if ($answer -eq $true) 
            {
                & $exeNSSM start $serviceFullName 
                $svStatus = (GetServiceStatus -ServiceName $serviceFullName )
                $Return = ($svStatus -eq "Running")
                Write-Host "$serviceFullName status: $svStatus" -ForegroundColor $(if ($Return) {"Green"} else {"Red"})
                if($Return -eq $false) {Throw "Could not start $serviceFullName"}
            }
        }
        else 
        {
            Write-Host "$serviceFullName is already started ($svStatus)" -ForegroundColor Green
            $Return = $true
        }
    }
    else
    {
        Write-Host $serviceFullName does NOT exists -ForegroundColor Red
    }

    Write-Host "SolrStartService($serviceFullName): $Return" -ForegroundColor $(if ($Return) {"Green"} else {"Red"})
    return $Return
}

function SolrRemoveService (
	[string]$serviceName,
    [int]$servicePort
)
{
    Write-Host
	Write-Host-H2 -Message "func SolrRemoveService"
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
    if (ServiceExists -ServiceName $serviceFullName  ) 
    {
        $answer = ProceedYN -Message "Remove $serviceFullName"
        if ($answer -eq $true) 
        {
            if ($(SolrStopService -serviceName $serviceName -servicePort $servicePort) -eq $true) {
                & $exeNSSM remove $serviceFullName confirm
                $Return = $true
                Write-Host $serviceFullName removed -ForegroundColor $(if ($Return) {"Green"} else {"Red"})
            }
        }
    }
    else
    {
        Write-Host $serviceFullName does NOT exists -ForegroundColor Green
        $Return = $true
    }
    Write-Host "SolrRemoveService($serviceFullName): $Return" -ForegroundColor $(if ($Return) {"Green"} else {"Red"})
    return $Return
}


function Create-SitecoreConfigSet(
    [string]$solrHomePath, 
    [int]$isSlave,
    [string]$solrMasterDNS,
    [string]$sitecoreConfigSetName
) {

    Write-Host
	Write-Host-H2 -Message "func Create-SitecoreConfigSet"
    foreach ($key in $MyInvocation.BoundParameters.keys)
    {
        $value = (get-variable $key).Value 
        Write-Host-Param -ParamName $key -Value $value
    }
	Write-Host
    

    $baseConfigSet = "sitecore_configs_$(if ($isSlave -eq 1) {"slave"} else {"master"})"
	$baseSetPath = Join-Path $solrHomePath "configsets\$baseConfigSet" -Resolve
	$targetSetPath = Join-Path $solrHomePath "SitecoreIndex\$sitecoreConfigSetName"
    Write-Host-Param -ParamName baseConfigSet -Value $baseConfigSet
    Write-Host-Param -ParamName baseSetPath -Value $baseSetPath
    Write-Host-Param -ParamName targetSetPath -Value $targetSetPath
	Write-Host


	# Copy the base config set and add updated core.properties file
	if(-not (Test-Path $targetSetPath)) {
        #$answer = ProceedYN -Message "Create $sitecoreConfigSetName Solr config set"
        #if ($answer -eq $true) 
        #{
		    Copy-Item $baseSetPath $targetSetPath -force -recurse

            $corePropertiesPath = "$targetSetPath\core.properties" 
            
            Write-Host
            Write-Host Copying $targetSetPath\core.properties.disabled file to $corePropertiesPath... -ForegroundColor Black -BackgroundColor White
            Copy-Item $targetSetPath\core.properties.disabled $corePropertiesPath -Force
            Write-Host $targetSetPath\core.properties.disabled copied to $corePropertiesPath -ForegroundColor Green
        
            Write-Host
            Write-Host Updating $corePropertiesPath file... -ForegroundColor Black -BackgroundColor White
            (Get-Content $corePropertiesPath) -replace "<#coreName>",$sitecoreConfigSetName | Set-Content $corePropertiesPath         
            #(Get-Content $corePropertiesPath) -replace "<#coreName>",$sitecoreConfigSetName | Set-Content $corePropertiesPath         
            Write-Host $corePropertiesPath updated -ForegroundColor Green

            if ($isSlave -eq 1) {            
                $solrConfigPath = "$targetSetPath\conf\solrconfig.xml" 

                Write-Host
                Write-Host Updating $solrConfigPath file... -ForegroundColor Black -BackgroundColor White
                (Get-Content $solrConfigPath) -replace "#SolrMasterDNS",$solrMasterDNS | Set-Content $solrConfigPath         
                Write-Host $solrConfigPath updated -ForegroundColor Green
            }

            Write-Host
		    Write-Host "Created $sitecoreConfigSetName Solr config set."
        #}
	} 
    else {
		Write-Warning "Solr Config Set $sitecoreConfigSetName already existed. Leaving it alone."
	}
}