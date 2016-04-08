rsWebConfiguration
==================
```PoSh

#rsMimeType will add if none exist or replace a current mapping with values given for the specific extension.

rsMimeType AddExtZZZ
{
	Ensure = "Present"
	fileExtension = ".zzz"
	mimeType = "image/gif"
}

rsMimeType RemoveExtZZZ
{
	Ensure = "Absent"
	fileExtension = ".zzz"
	mimeType = "image/gif"
}



#rsIISAuthenticationMethod will enabled or disable Windows, Basic, and/or Anonymous Authentication in IIS for a Site or Application.

rsIISAuthenticationMethod DefaultSite
    {
    Path = "IIS:\Sites\Default Web Site"
    WindowsAuth = Enabled
    BasicAuth = Disabled
    AnonymousAuth = Disabled
    }
    
    
#rsWebsiteSettings currently only supports changing logging path for website
   
rsWebSiteSettings api_rackspacedevops_com
   {
   	SiteName = "api.rackspacedevops.com"
   	LogPath = "C:\IISLogs"
   }
  
#rsWebDeploy will deploy a zipped site configuration or content to the folder or site configured. Can be set to Site Path, Site Name, or Site Application.

rsWebDeploy Websites
{
    PackagePath = "https://github.com/rsWinAutomationSupport/Websites/archive/master.zip"
    ContentPath = "C:\Inetpub\websites"
    Ensure = "Present"
}

#rsIISApplicationInitialization requires the Web-Server and Web-AppInit features.
#
#
#
#foreach ($Feature in @("Web-Server","Web-AppInit")) {
#    WindowsFeature "$Feature" {
#        Ensure = $Ensure
#        Name = $Feature
#    }
#}
#rsIISApplicationInitialization reset site to default settings
rsIISApplicationInitialization IISAppInit
{
    path = "Default Web Site"
            
}

#rsIISApplicationInitialization set Application to settings as desired
rsIISApplicationInitialization IISAppInit2
{
    path = "Default Web Site/TestApp"
    InitAfterRestart = $true
    skipManagedModules = $false
    staticPage = "load.gif"
    initializationPage = "default.aspx"
    initializationHost = "localhost"
}
```
## rsDomainIPRestrictions - 
Resource added to enabled DSC to configure Domain and IP Restrictions for Websites
```Posh
configuration Sample{
    Import-DscResource -modulename rsWebConfiguration
    Node $env:COMPUTERNAME{
        rsDomainIPRestrictions setIPRestrictions{
            SiteName = "Default Web Site"
            AllowUnlisted = $false
            DenyAction = "Forbidden"
            EnableReverseDNS = $true
            EntryList = @("192.168.1.0/24","127.0.0.1","sandbox","apps.google.com")
        }
    }
}

Stop-Process -Name WmiPrvSE -Force -Verbose
Sample -OutputPath C:\Windows\Temp
Start-DscConfiguration -Path C:\Windows\Temp -Verbose -Wait -Force
```
## rsWebConfigLock -
Resource added to enable DSC to configure Configuration locks in the apphost config of the IIS Server and specified sites
```Posh
Configuration New{
    Import-DscResource -ModuleName rsWebConfiguration
    node $env:COMPUTERNAME{
        rsWebConfigLock unlockDefaultPaths{
            filter = "system.webServer/httpErrors/@defaultPath"
            pspath = 'MACHINE/WEBROOT/APPHOST'
            locked = $true
            type = "inclusive" #Required if locked is set to true
			location = #<optional paramter>
        }
    }
}

Stop-Process -Name WmiPrvSE -Force -Verbose
New -OutputPath C:\Windows\Temp
Start-DscConfiguration -Path C:\Windows\Temp -Wait -Force -Verbose
```

##rsSiteUpdate -
Will recycle the app pool of a site when the content has been updated.  Also has a Slack notification option.
````Posh
rsSiteUpdate Sample{
     RepoPath = "" #Path to site content repo
     CommitIDFile = "" #Filename for the commit ID (site name is probably best)
     SiteName = "" #Name of site in IIS
   #All optional below
     SlackNotify = $true #Default is false
     NotifyUrl = "" #Slack notification URL
     Message = "" #Message to be displayed in Slack
     Username = "" #Username to display in Slack (default Rackspace-Powershell-DSC)
     Channel = "" #Slack channel name
     IconUrl = "" #Icon URL to display in Slack (default is a powershell icon)
}
```