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