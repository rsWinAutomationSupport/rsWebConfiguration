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