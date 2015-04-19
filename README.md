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