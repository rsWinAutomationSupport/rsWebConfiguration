﻿function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $RepoPath,

        [parameter(Mandatory = $true)]
        [System.String]
        $CommitIDFile
    )

    return @{
        RepoPath = $RepoPath
        CommitIDFile = $CommitIDFile
    }
}


function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $RepoPath,

        [parameter(Mandatory = $true)]
        [System.String]
        $CommitIDFile,

        [parameter(Mandatory = $true)]
        [System.String]
        $SiteName,

        [parameter(Mandatory = $false)]
        [System.Boolean]
        $SlackNotify = $false,

        [parameter(Mandatory = $false)]
        [System.String]
        $NotifyUrl,

        [parameter(Mandatory = $false)]
        [System.String]
        $Message,

        [parameter(Mandatory = $false)]
        [System.String]
        $Username = "Rackspace-Powershell-DSC",

        [parameter(Mandatory = $false)]
        [System.String]
        $Channel,

        [parameter(Mandatory = $false)]
        [System.String]
        $IconUrl = "https://github.com/rsWinAutomationSupport/rsWebConfiguration/tree/master/DSCResources/RS_rsSiteUpdate/powershell.png"
    )

    $AppPool = (Get-Item "IIS:\Sites\$SiteName").applicationPool
    Restart-WebAppPool -Name $AppPool

    Set-Location $RepoPath
    Out-File -FilePath $CommitIDFile -InputObject (Invoke-Expression "git rev-parse HEAD") -Force

    if ($SlackNotify -eq $true)
    {
        $BodyObject = @{
            text = $Message
            icon_url = $IconUrl
            username = $Username
            channel = $Channel
        }
        Invoke-RestMethod -Method Post -Uri $NotifyUrl -Body (ConvertTo-Json $BodyObject)
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
        $RepoPath,

        [parameter(Mandatory = $true)]
        [System.String]
        $CommitIDFile
    )

    Set-Location $RepoPath
    $currentID = Invoke-Expression "git rev-parse HEAD"
    $storedID  = Get-Content $CommitIDFile -ErrorAction SilentlyContinue
    if ($currentID -eq $storedID)
    {
        return $true
    }
    else
    {
        return $false
    }
}