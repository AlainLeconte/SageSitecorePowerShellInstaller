function Start-Browser([string]$url)
{
    if ([string]::IsNullOrEmpty($url))
    {
        $url = Get-SiteUrl
    }
    Write-Message "`nLaunching site in browser: $url" -WriteToLog $FALSE -HostConsoleAvailable $hostScreenAvailable
    <#
    $ie = new-object -comobject "InternetExplorer.Application" 
    $ie.visible = $true
    $ie.navigate($url)
    #>
    Initialize-SitecoreApplication
    START $url -Wait
}



function New-ConfigSettingsForModules([xml]$config)
{
    $sitecoreModulesPath = $config.InstallSettings.SitecoreModulesPath
    if (!([string]::IsNullOrEmpty($sitecoreModulesPath)))
    {
        $sitecoreModulesPath = $sitecoreModulesPath.Trim()
    }
    

    #region Modules
    $modules = New-Object 'System.Collections.Generic.List[PSObject]'
    if (($config.InstallSettings.SitecoreModulesToInstall.ChildNodes | Where-Object {$_.Name -ne "#comment"}).Length -gt 0)
    {
        foreach ($moduleName in ($config.InstallSettings.SitecoreModulesToInstall.name))
        {
            if ($moduleName -ne "#comment") {
                $module = New-Object -TypeName PSObject

                $name = $moduleName
                if (!([string]::IsNullOrEmpty($name)))
                {
                    $name = $name.Trim()
                }

                $module | Add-Member -MemberType NoteProperty -Name Name -Value $name
                $modules.Add($module)
            }
        }
    }	

	$script:configSettings | Add-Member -MemberType NoteProperty -Name SitecoreModulesPath -Value $sitecoreModulesPath
    $script:configSettings | Add-Member -MemberType NoteProperty -Name SitecoreModulesToInstall -Value $modules
}


function Initialize-SitecoreApplication()
{
    Write-Message "Warming up Sitecore..." "White" -WriteToLog $TRUE -HostConsoleAvailable $hostScreenAvailable

    $pagePath = "sitecore"

    # Request the page
    $baseUrl = [System.Uri](Get-SiteUrl)
    $combinedUrl = New-Object System.Uri($baseUrl, $pagePath)
    $result = Invoke-WebRequest $combinedUrl.ToString()

    if ($result.StatusCode -eq 200)
    {
        Write-Message "Sitecore started" "White" -WriteToLog $FALSE -HostConsoleAvailable $hostScreenAvailable
    }

    else 
    {
        Write-Message "Some problem while initializing, skipping warmup" "White" -WriteToLog $FALSE -HostConsoleAvailable $hostScreenAvailable
    }
}

function Run-ModuleInstallPostSteps([string]$moduleFileName)
{
    if ($moduleFileName -like "*Web Forms for Marketers*")
    {
        Write-Message "   Running post installation steps for $moduleFileName" "White" -WriteToLog $FALSE -HostConsoleAvailable $hostScreenAvailable

        # Run SQL script on reporting database and add proper elements to Web.config

        $server = $script:configSettings.Database.SqlServerName
        $dbName = $script:configSettings.Database.DatabaseNamePrefix + "Reporting"
        $sqlFilename = $script:configSettings.WebServer.SitecoreInstallPath + "\Website\Data\WFFM_Analytics.sql"
        Invoke-Sqlcmd -ServerInstance $server -Database $dbName -InputFile $sqlFilename

        $webConfig = $script:configSettings.WebServer.SitecoreInstallPath + "\Website\Web.config"
        $doc = (Get-Content $webConfig) -as [Xml]
        
        $newCaptchaImageSetting = $doc.CreateElement("add")
        $newCaptchaAudioSetting = $doc.CreateElement("add")
        $doc.configuration.'system.webServer'.handlers.AppendChild($newCaptchaImageSetting) > $null
        $doc.configuration.'system.webServer'.handlers.AppendChild($newCaptchaAudioSetting) > $null
        $newCaptchaImageSetting.SetAttribute("name","CaptchaImage")
        $newCaptchaImageSetting.SetAttribute("verb","*")
        $newCaptchaImageSetting.SetAttribute("path","CaptchaImage.axd")
        $newCaptchaImageSetting.SetAttribute("type","Sitecore.Form.Core.Pipeline.RequestProcessor.CaptchaResolver, Sitecore.Forms.Core")
        $newCaptchaAudioSetting.SetAttribute("name","CaptchaAudio")
        $newCaptchaAudioSetting.SetAttribute("verb","*")
        $newCaptchaAudioSetting.SetAttribute("path","CaptchaAudio.axd")
        $newCaptchaAudioSetting.SetAttribute("type","Sitecore.Form.Core.Pipeline.RequestProcessor.CaptchaResolver, Sitecore.Forms.Core")

        $doc.Save($webConfig)
    }

    elseif ($moduleFileName -like "*Sitecore Commerce Connect*")
    {
        Write-Message "   Running post installation steps for $moduleFileName" "White" -WriteToLog $FALSE -HostConsoleAvailable $hostScreenAvailable

        # Move Solr configs to zzz folder to make sure they are loaded as the last

        $installPath = Join-Path $script:configSettings.WebServer.SitecoreInstallRoot -ChildPath $script:configSettings.WebServer.SitecoreInstallFolder
        $configsPath = Join-Path $installPath -ChildPath "Website\App_Config\Include"
        $destinationPath = Join-Path $configsPath -ChildPath "zzz"
        
        $configsToMove = Get-ChildItem "$configsPath\Sitecore.Commerce.Products.Solr.*" | sort -Property name

        if(!(Test-Path $destinationPath))
        {
            New-Item -Path $destinationPath -ItemType Directory -Force | Out-Null
        }

        $configsToMove| Foreach-Object { Move-Item $_ -destination "$destinationPath\$($_.Name)" }
    }
}

function Install-SitecoreModules()
{
    Write-Message "Installing modules" "Green" -WriteToLog $FALSE -HostConsoleAvailable $hostScreenAvailable

    $fromFolder = $script:configSettings.SitecoreModulesPath
    $toFolder = $script:configSettings.WebServer.SitecoreInstallPath

    foreach ($module in $script:configSettings.SitecoreModulesToInstall)
    {
        $name = $module.Name
        Copy-Item "$fromFolder\$name" "$toFolder\Data\packages"
    }

    $rootPath = $script:configSettings.WebServer.SitecoreInstallPath
    #$updatePackagesPath = [io.path]::combine($rootPath, 'Website', 'sitecore', 'admin', 'Packages')
    $zipPackagesPath = [io.path]::combine($rootPath, 'Data', 'packages')

	# Prepare installer service file
	$html = "<%@ WebService Language=`"C#`" Class=`"PackageInstaller`" %>`r`n"
	$html += "using System;`r`n"
	$html += "using System.Configuration;`r`n"
	$html += "using System.IO;`r`n"
	$html += "using System.Web.Services;`r`n"
	$html += "using System.Xml;`r`n"
	$html += "using Sitecore.Data.Proxies;`r`n"
	$html += "using Sitecore.Data.Engines;`r`n"
	$html += "using Sitecore.Install.Files;`r`n"
	$html += "using Sitecore.Install.Framework;`r`n"
	$html += "using Sitecore.Install.Items;`r`n"
	$html += "using Sitecore.SecurityModel;`r`n"
	$html += "using Sitecore.Update;`r`n"
	$html += "using Sitecore.Update.Installer;`r`n"
	$html += "using Sitecore.Update.Installer.Utils;`r`n"
	$html += "using Sitecore.Update.Utils;`r`n"
	$html += "using log4net;`r`n"
	$html += "using log4net.Config;`r`n"
	$html += "`r`n"
	$html += "/// <summary>`r`n"
	$html += "/// Summary description for UpdatePackageInstaller`r`n"
	$html += "/// </summary>`r`n"
	$html += "[WebService(Namespace = `"http://tempuri.org/`")]`r`n"
	$html += "[WebServiceBinding(ConformsTo = WsiProfiles.BasicProfile1_1)]`r`n"
	$html += "[System.ComponentModel.ToolboxItem(false)]`r`n"
	$html += "// To allow this Web Service to be called from script, using ASP.NET AJAX, uncomment the following line. `r`n"
	$html += "// [System.Web.Script.Services.ScriptService]`r`n"
	$html += "public class PackageInstaller : System.Web.Services.WebService`r`n"
	$html += "{`r`n"
	$html += "  /// <summary>`r`n"
	$html += "  /// Installs a Sitecore Update Package.`r`n"
	$html += "  /// </summary>`r`n"
	$html += "  /// <param name=`"path`">A path to a package that is reachable by the web server</param>`r`n"
	$html += "  [WebMethod(Description = `"Installs a Sitecore Update Package.`")]`r`n"
	$html += "  public void InstallUpdatePackage(string path)`r`n"
	$html += "  {`r`n"
	$html += "    // Use default logger`r`n"
	$html += "    var log = LogManager.GetLogger(`"root`");`r`n"
	$html += "    XmlConfigurator.Configure((XmlElement)ConfigurationManager.GetSection(`"log4net`"));`r`n"
	$html += "`r`n"
	$html += "    var file = new FileInfo(path);  `r`n"
	$html += "    if (!file.Exists)  `r`n"
	$html += "      throw new ApplicationException(string.Format(`"Cannot access path '{0}'.`", path)); `r`n"
	$html += "        `r`n"
	$html += "    using (new SecurityDisabler())`r`n"
	$html += "    {`r`n"
	$html += "      var installer = new DiffInstaller(UpgradeAction.Upgrade);`r`n"
	$html += "      var view = UpdateHelper.LoadMetadata(path);`r`n"
	$html += "`r`n"
	$html += "      //Get the package entries`r`n"
	$html += "      bool hasPostAction;`r`n"
	$html += "      string historyPath;`r`n"
	$html += "      var entries = installer.InstallPackage(path, InstallMode.Install, log, out hasPostAction, out historyPath);`r`n"
	$html += "`r`n"
	$html += "      installer.ExecutePostInstallationInstructions(path, historyPath, InstallMode.Install, view, log, ref entries);`r`n"
	$html += "`r`n"
	#$html += "      UpdateHelper.SaveInstallationMessages(entries, historyPath);`r`n"
	$html += "    }`r`n"
	$html += "  }`r`n"
	$html += " `r`n"
	$html += "  /// <summary>`r`n"
	$html += "  /// Installs a Sitecore Zip Package.`r`n"
	$html += "  /// </summary>`r`n"
	$html += "  /// <param name=`"path`">A path to a package that is reachable by the web server</param>`r`n"
	$html += "  [WebMethod(Description = `"Installs a Sitecore Zip Package.`")]`r`n"
	$html += "  public void InstallZipPackage(string path)`r`n"
	$html += "  {`r`n"
	$html += "    // Use default logger`r`n"
	$html += "    var log = LogManager.GetLogger(`"root`");`r`n"
	$html += "    XmlConfigurator.Configure((XmlElement)ConfigurationManager.GetSection(`"log4net`"));`r`n"
	$html += "`r`n"
	$html += "    var file = new FileInfo(path);  `r`n"
	$html += "    if (!file.Exists)  `r`n"
	$html += "      throw new ApplicationException(string.Format(`"Cannot access path '{0}'.`", path)); `r`n"
	$html += "   `r`n"
	$html += "    Sitecore.Context.SetActiveSite(`"shell`");  `r`n"
	$html += "    using (new SecurityDisabler())  `r`n"
	$html += "    {  `r`n"
	$html += "      using (new ProxyDisabler())  `r`n"
	$html += "      {  `r`n"
	$html += "        using (new SyncOperationContext())  `r`n"
	$html += "        {  `r`n"
	$html += "          IProcessingContext context = new SimpleProcessingContext(); //   `r`n"
	$html += "          IItemInstallerEvents events =  `r`n"
	$html += "            new DefaultItemInstallerEvents(new Sitecore.Install.Utils.BehaviourOptions(Sitecore.Install.Utils.InstallMode.Overwrite, Sitecore.Install.Utils.MergeMode.Undefined));  `r`n"
	$html += "          context.AddAspect(events);  `r`n"
	$html += "          IFileInstallerEvents events1 = new DefaultFileInstallerEvents(true);  `r`n"
	$html += "          context.AddAspect(events1);  `r`n"
	$html += "          var installer = new Sitecore.Install.Installer();  `r`n"
	$html += "          installer.InstallPackage(Sitecore.MainUtil.MapPath(path), context);  `r`n"
	$html += "        }  `r`n"
	$html += "      }  `r`n"
	$html += "    }  `r`n"
	$html += "  }`r`n"
	$html += "}`r`n"
    
    $pagePath = "\PackageInstaller.asmx"
    $filePath = Join-Path $script:configSettings.WebServer.SitecoreInstallPath -ChildPath "Website"
    $filePath = Join-Path $filePath -ChildPath $pagePath
    $html | out-file -FilePath $filePath
	

    $siteUrl = Get-SiteUrl

    $proxy = New-WebServiceProxy -uri "$siteUrl/PackageInstaller.asmx?WSDL"
    $proxy.Timeout = 1800000
    
    Write-Message "Installing .zip packages located at: $zipPackagesPath" "White" -WriteToLog $TRUE -HostConsoleAvailable $hostScreenAvailable

    foreach ($module in $script:configSettings.SitecoreModulesToInstall)
    {
        $packageName = $module.Name
        $modulePath = Join-Path $zipPackagesPath -ChildPath $packageName

        Write-Message "-> Installing package $packageName" "White" -WriteToLog $TRUE -HostConsoleAvailable $hostScreenAvailable
	    $proxy.InstallZipPackage($modulePath)
        Run-ModuleInstallPostSteps($packageName)

        Initialize-SitecoreApplication
    }

    #Get-ChildItem $zipPackagesPath -Filter *.zip | `
    #Foreach-Object {
    #    $packageName = $_.FullName
    #    Write-Message "-> Installing package $packageName" "White" -WriteToLog $TRUE -HostConsoleAvailable $hostScreenAvailable
	#    $proxy.InstallZipPackage($_.FullName)
    #    Run-ModuleInstallPostSteps($packageName)
    #}
	
    Remove-Item -Path $filePath
}



