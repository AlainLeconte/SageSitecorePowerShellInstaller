param(
    [string]$solrInstancePath,
    [string]$solrDistPath,
    [int]$Quiet = 0,
    [int]$clearHost = 1
)

# Load functions
$stdFuntionsPath = (split-path -parent $PSCommandPath)
. "$stdFuntionsPath\..\Common\StandardFunctions.ps1"


#$cd = $(Get-Location)
$cd = $PSScriptRoot | split-path -parent

if ($clearHost -eq 1) {
    Clear-Host
}
Write-Host-H1 -Message "Create Solr Instance symLinks ($solrInstancePath to $solrDistPath)"
Write-Host-Param -ParamName "Script file root" -Value $PSScriptRoot
Write-Host-Param -ParamName "Current directory" -Value $cd
Write-Host

foreach ($key in $MyInvocation.BoundParameters.keys)
{
    $value = (get-variable $key).Value 
    Write-Host-Param -ParamName $key -Value $value
}
Write-Host


try {
    if(-not($solrInstancePath)) { Throw "You must supply a value for -solrSlaveInstancePath" }
    if(-not($solrDistPath)) { Throw "You must supply a value for -solrMasterInstancePath" }

    $answer = ProceedYN "Create SymLinks ($solrInstancePath to $solrDistPath)"
    if ($answer -eq $true)
    {
        # CreateSymLink -link $solrInstancePath -target $solrDistPath
        CreateSymLink -link $solrInstancePath\bin -target $solrDistPath\bin
        CreateSymLink -link $solrInstancePath\contrib -target $solrDistPath\contrib
        CreateSymLink -link $solrInstancePath\dist -target $solrDistPath\dist
        CreateSymLink -link $solrInstancePath\licenses -target $solrDistPath\licenses
        CreateSymLink -link $solrInstancePath\server -target $solrDistPath\server
    }
}

catch {
    Write-Error $_.Exception.Message
    Pause
}



