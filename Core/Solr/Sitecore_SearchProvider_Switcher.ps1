param (
    [string]$sitecoreAppWebRoot,
    [string]$provider,
    [int]$Quiet = 0,
    [int]$clearHost = 1
)

# Load functions
$stdFuntionsPath = (split-path -parent $PSCommandPath)
. "$stdFuntionsPath\StandardFunctions.ps1"

function Get-ConfigFileFilter([string]$providerName)
{
    Write-Host
	Write-Host-H2 -Message "func Get-ConfigFileFilter"
    foreach ($key in $MyInvocation.BoundParameters.keys)
    {
        $value = (get-variable $key).Value 
        Write-Host-Param -ParamName $key -Value $value
    }
	Write-Host

	return "^.*\." + $providerName + "\.(.+\.)?config.*$"
}

function Set-ScSearchProvider (
    [string] $sitecoreAppWebRoot, 
    [string] $provider = "solr"
)
{
    Write-Host
	Write-Host-H2 -Message "func Set-ScSearchProvider"
    foreach ($key in $MyInvocation.BoundParameters.keys)
    {
        $value = (get-variable $key).Value 
        Write-Host-Param -ParamName $key -Value $value
    }
	Write-Host
	$configsPath = Join-Path $sitecoreAppWebRoot -ChildPath "App_Config"
    Write-Host-Param -ParamName configsPath -Value $configsPath
	Write-Host
	
	$solrChoice = "Solr"
	$luceneChoice = "Lucene"

    $validInput = $true;
	
    #test that path is valid
    if (!(Test-Path -Path $configsPath))
    {
        Write-Host "Sitecore configs path povided was invalid or inaccessible ($configsPath)." -ForegroundColor Red;
        $validInput = $false;
    }
    #test that choice is valid
    elseif (($provider -ne $luceneChoice) -and ($provider -ne $solrChoice))
    {
        Write-Host "You must choose Lucene or Solr." -ForegroundColor Red;
        $validInput = $false;
    }
    
    if ($validInput)
    {
        If (($provider -eq $luceneChoice))
        {
            Write-Host "Set Sitecore configuration to $luceneChoice" -ForegroundColor Green
            $selectedProvider = $luceneChoice;
            $deselectedProvider = $solrChoice;
        }
        ElseIf (($provider -eq $solrChoice))
        {
            Write-Host "Set Sitecore configuration to $solrChoice" -ForegroundColor Green
            $selectedProvider = $solrChoice;
            $deselectedProvider = $luceneChoice;
        }

        #enumerate all config files to be enabled        
        $regexp = Get-ConfigFileFilter $selectedProvider
        $filesToEnable = Get-ChildItem -Recurse -File -Path $configsPath | Where-Object { $_.FullName -match $regexp }
        foreach ($file in $filesToEnable)
        {
            Write-Host $file.Name;
            if (($file.Extension -ne ".config"))
            {
                $newFileName = [io.path]::GetFileNameWithoutExtension($file.FullName);
                $newFile = Rename-Item -Path $file.FullName -NewName $newFileName -PassThru;
                Write-Host "-> " $newFile.Name -ForegroundColor Green;
            }
        }

        #enumerate all config files to be disabled
        $regexp = Get-ConfigFileFilter $deselectedProvider
        $filesToDisable = Get-ChildItem -Recurse -File -Path $configsPath | Where-Object { $_.FullName -match $regexp }
        foreach ($file in $filesToDisable)
        {
            Write-Host $file.Name -ForegroundColor Gray;
            if ($file.Extension -eq ".config")
            {
                $newFileName = $file.Name + ".disabled";
                $newFile = Rename-Item -Path $file.FullName -NewName $newFileName -PassThru;
                Write-Host "-> " $newFile.Name -ForegroundColor Yellow
            }
        }
    }
}

if ($clearHost -eq 1) {
    Clear-Host
}

$cd = $PSScriptRoot | split-path -parent

Write-Host-H1 -Message "Sitecore Switch Provider"
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
    if (-Not($sitecoreAppWebRoot)) {
        Throw "Sitecore application web root not supplied"
    }

    if (-Not($provider)) {
        Throw "Provider need to be supplied (Solr or Lucene)"
    }
  
    $answer = ProceedYN "Switch Sitecore Search provider to $provider"
    if ($answer -ne $true) 
    {
        Write-Host Switch Sitecore Search provider to $provider aborted -ForegroundColor Red
        Start-Sleep -s 1
        Return
    }

    Set-ScSearchProvider -sitecoreAppWebRoot $sitecoreAppWebRoot -provider $provider
    Pause
}

catch {
    Write-Error $_.Exception.Message
    Pause
    Throw $_.Exception.Message
}