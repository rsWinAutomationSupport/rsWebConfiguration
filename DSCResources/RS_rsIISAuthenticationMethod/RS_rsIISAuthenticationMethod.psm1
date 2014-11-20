function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $path,

        [ValidateSet("Enabled","Disabled")]
        [System.String]
        $windowsAuth,

        [ValidateSet("Enabled","Disabled")]
        [System.String]
        $basicAuth,

        [ValidateSet("Enabled","Disabled")]
        [System.String]
        $anonymousAuth
    )

    if(Test-Path $path)
    {
        $basicGet = Get-WebConfigurationProperty -Filter /system.webServer/security/authentication/basicAuthentication -Name enabled -Location $path
        $windowsGet = Get-WebConfigurationProperty -Filter /system.webServer/security/authentication/windowsAuthentication -Name enabled -Location $path
        $anonymousGet = Get-WebConfigurationProperty -Filter /system.webServer/security/authentication/anonymousAuthentication -Name enabled -Location $path

        if($windowsGet.Value){$windowsGet = "Enabled"} else{$windowsGet = "Disabled"}
        if($basicGet.Value){$basicGet = "Enabled"} else{$basicGet = "Disabled"}
        if($anonymousGet.Value){$anonymousGet = "Enabled"} else{$anonymousGet = "Disabled"} 

        return @{
            WindowsAuth = $windowsGet
            BasicAuth = $basicGet
            AnonymousAuth = $anonymousGet
            }
    }
    else
    {
        return @{path = "invalid"}
    }
}

function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $path,

        [ValidateSet("Enabled","Disabled")]
        [System.String]
        $windowsAuth,

        [ValidateSet("Enabled","Disabled")]
        [System.String]
        $basicAuth,

        [ValidateSet("Enabled","Disabled")]
        [System.String]
        $anonymousAuth
    )

        $logSource = $PSCmdlet.MyInvocation.MyCommand.ModuleName
        New-EventLog -LogName "DevOps" -Source $logSource -ErrorAction SilentlyContinue
        $message = ""

    if(Test-Path $path)
    {
        if($windowsAuth -ne $null)
        {
            $value = ($windowsAuth -eq "Enabled")
            Set-WebConfigurationProperty -Filter /system.webServer/security/authentication/windowsAuthentication -Name enabled -Value $value -Location $path
            $message = "Windows Authentication for $path set to $windowsAuth.`n"
        }
        if($basicAuth -ne $null)
        {        
            $value = ($basicAuth -eq "Enabled")
            Set-WebConfigurationProperty -Filter /system.webServer/security/authentication/basicAuthentication -Name enabled -Value $value -Location $path
            $message = $message + "Basic Authentication for $path set to $basicAuth.`n"
        }
        if($anonymousAuth -ne $null)
        {   
            $value = ($anonymousAuth -eq "Enabled")
            Set-WebConfigurationProperty -Filter /system.webServer/security/authentication/anonymousAuthentication -Name enabled -Value $value -Location $path
            $message = $message + "Anonymous Authentication for $path set to $anonymousAuth.`n"
        }
        Write-EventLog -LogName DevOps -Source $logSource -EntryType Information -EventId 1000 -Message $message
    }
    else
    {
        Write-EventLog -LogName DevOps -Source $logSource -EntryType Information -EventId 1000 -Message "Path for IIS Authentication changes is invalid:  $path"
    }
}

function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $path,

        [ValidateSet("Enabled","Disabled")]
        [System.String]
        $windowsAuth,

        [ValidateSet("Enabled","Disabled")]
        [System.String]
        $basicAuth,

        [ValidateSet("Enabled","Disabled")]
        [System.String]
        $anonymousAuth
    )

    $IsValid = $false

    if(Test-Path $path)
    {

        $basicGet = Get-WebConfigurationProperty -Filter /system.webServer/security/authentication/basicAuthentication -Name enabled -Location $path
        $windowsGet = Get-WebConfigurationProperty -Filter /system.webServer/security/authentication/windowsAuthentication -Name enabled -Location $path
        $anonymousGet = Get-WebConfigurationProperty -Filter /system.webServer/security/authentication/anonymousAuthentication -Name enabled -Location $path

        if($windowsGet.Value){$windowsGet = "Enabled"} else{$windowsGet = "Disabled"}
        if($basicGet.Value){$basicGet = "Enabled"} else{$basicGet = "Disabled"}
        if($anonymousGet.Value){$anonymousGet = "Enabled"} else{$anonymousGet = "Disabled"}

        if($windowsAuth -eq $null) { $windowsAuth = $windowsGet }
        if($basicAuth -eq $null) { $basicAuth = $windowsGet }
        if($anonymousAuth -eq $null) { $anonymousAuth = $windowsGet }

        if(($windowsAuth -eq $windowsGet) -and ($basicAuth -eq $basicGet) -and ($anonymousAuth -eq $anonymousGet))
        {
            $IsValid = $true
        }

    }
    
    Return $IsValid
}