function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $fileExtension
    )

    $mimeMapEntry = Get-WebConfiguration -filter "/system.webServer/staticContent/mimeMap[@fileExtension='$fileExtension']"
    if($mimeMapEntry -eq $null)
    {
         return @{
             Ensure = "Absent"
             fileExtension = $fileExtension
        }
    }
    else
    {
    return @{
        Ensure = "Present"
        fileExtension = $mimeMapEntry.fileExtension
        mimeType = $mimeMapEntry.mimeType
        }
    }
}


function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $fileExtension,

        [System.String]
        $mimeType,

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure = "Present"
    )

    $mimeMapEntry = Get-WebConfiguration -filter "/system.webServer/staticContent/mimeMap[@fileExtension='$fileExtension']"

    if($Ensure -eq "Present")
    {
        if(!$mimeMapEntry)
        {
            Add-WebConfigurationProperty "/system.webserver/staticContent" -name collection -value @{fileExtension=$fileExtension;mimeType=$mimeType} -Force
        }
        else
        {
            Set-WebConfigurationProperty "/system.webserver/staticContent" -name collection -value @{fileExtension=$fileExtension;mimeType=$mimeType} -Force
        }
    }
    elseif($mimeMapEntry -ne $null)
    {
        Remove-WebConfigurationProperty "/system.webServer/staticContent" -name collection -AtElement @{fileExtension=$fileExtension} -Force
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
        $fileExtension,

        [System.String]
        $mimeType,

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure = "Present"
    )

    $mimeMapEntry = Get-WebConfiguration -filter "/system.webServer/staticContent/mimeMap[@fileExtension='$fileExtension']"

    if(!$mimeMapEntry -or ($mimeMapEntry -eq $mimeType))
    {
        $IsValid = $false
    }
    else
    {
        $IsValid = $true
    }
    Return $IsValid
}