param(
    [parameter(Mandatory=$false)]
    [string]$solutionPath = "C:\Sage\TFS\Global Web Development\Unity\Source\Main\Unity.Master.sln",
    [parameter(Mandatory=$false)]
    [bool] $nuget = $true,
    [parameter(Mandatory=$false)]
    [bool] $clean = $true,
    [parameter(Mandatory=$false)]
    [bool] $build = $true
)

# http://knightcodes.com/miscellaneous/2016/09/05/build-solutions-and-projects-with-powershell.html
function buildVS
{
    param
    (
        [parameter(Mandatory=$true)]
        [String] $path,

        [parameter(Mandatory=$false)]
        [bool] $nuget = $true,
        
        [parameter(Mandatory=$false)]
        [bool] $clean = $true,

        [parameter(Mandatory=$false)]
        [bool] $build = $true
    )
    process
    {
        Write-Host
	    Write-Host-H2 -Message "func buildVS"
        foreach ($key in $MyInvocation.BoundParameters.keys)
        {
            $value = (get-variable $key).Value 
            Write-Host-Param -ParamName $key -Value $value
        }
	    Write-Host        

        $msBuildExe = 'C:\Program Files (x86)\MSBuild\14.0\Bin\msbuild.exe'
        Write-Host-Param -ParamName msBuildExe -Value $msBuildExe
        $nugetExe = "$PSScriptRoot\nuget.exe"
        Write-Host-Param -ParamName nugetExe -Value $nugetExe

        Try {
            If(-Not(Test-Path $msBuildExe)) {
                Write-Host "Could not find target $msBuildExe !" -ForegroundColor red
                Throw "Could not find $msBuildExe !"
            }
            If(-Not(Test-Path $nugetExe)) {
                Write-Host "Could not find target $nugetExe !" -ForegroundColor red
                Throw "Could not find $nugetExe !"
            }

            if ($nuget) {
                Write-Host "Restoring NuGet packages" -foregroundcolor green
                #nuget restore "$($path)"
                & "$nugetExe" restore "$($path)"
            }

            if ($clean) {
                Write-Host "Cleaning $($path)" -foregroundcolor green
                & "$($msBuildExe)" "$($path)" /t:Clean /m
            }
        
            if ($build) {
                Write-Host "Building $($path)" -foregroundcolor green
                & "$($msBuildExe)" "$($path)" /t:Build /m
            }
        }
        Catch
        {
            Write-Warning $_.Exception.Message
            throw  
        }
    }
}

buildVS -path $solutionPath -nuget $nuget -clean $clean -build $build