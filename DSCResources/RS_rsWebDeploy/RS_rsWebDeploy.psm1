#############################################################################################################################################
# rsWebDeploy module is for Importing/Exporting IIS content/configuration using the web deploy custom IIS extension. This resource assumes that WebDeploy extension
# is installed and enabled in IIS.
#############################################################################################################################################


#############################################################################################################################################
# Get-TargetResource ([string]$PackagePath, [string]$ContentPath) : given the package and IIS website name or content path, determine whether
# the details provided would allow for successful deployment
#############################################################################################################################################

function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $PackagePath,
        [parameter(Mandatory = $true)]
        [System.String]
        $ContentPath
    )

    $appCmd = "$env:PROGRAMFILES\IIS\Microsoft Web Deploy V3\msdeploy.exe"
    $ensure = "Absent"
    Write-Verbose -Message "Calling msdeploy.exe to retrieve the site content from a zip package file"
    $packageFiles = & $appCmd -verb:dump "-source:package=$PackagePath"
    Write-Verbose -Message "Calling msdeploy.exe to retrieve the site content from the site path"
    if($ContentPath.contains("\") -and $ContentPath.contains(":")){$destination = $ContentPath}
    else{$destination = (Get-ItemProperty -Path "IIS:\Sites\$ContentPath" -ErrorAction SilentlyContinue).PhysicalPath}

    # $ContentPath in this case points to physical path of the website.
    if((Test-Path $PackagePath) -and (Test-Path $destination))
    {
        $ensure = "Present"
    }
    else
    {
        $ensure = "Absent"
    }

    $returnValue = @{
        PackagePath = $PackagePath
        ContentPath = $ContentPath
        Ensure = $ensure
        }

    $returnValue
}

#########################################################################################################################################
# Set-TargetResource ([string]$PackagePath, [string]$ContentPath, [string]$Ensure) : given the package and IIS website name or content path, deploy/remove
# the website content
#########################################################################################################################################

function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $PackagePath,
        [parameter(Mandatory = $true)]
        [System.String]
        $ContentPath,
        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure = "Present"
    )
    
    Write-Verbose -Message "Calling msdeploy.exe to sync the site content from a zip package"
    
    $appCmd = "$env:PROGRAMFILES\IIS\Microsoft Web Deploy V3\msdeploy.exe"
    $appCmd = "& '$appCmd'"   
        
    if($Ensure -eq "Present")
    {
        #sync the given package content into iis inetpub
        if($ContentPath.contains("\") -and $ContentPath.contains(":"))
        {
            #this is the case when iis site content path is specified
            $appCmd += "-verb:sync -source:package=$PackagePath -dest:contentPath=$ContentPath"
        }
        else
        {
            #this is the case when iis site name is specified (no spaces allowed)
            $appCmd += "-verb:sync -source:package=$PackagePath -dest:iisApp=$ContentPath"           
        }
        Write-Verbose -Message "Appcmd command run: $appCmd"

    }
    else
    {
        #delete the website content    
        if($ContentPath.contains("\") -and $ContentPath.contains(":"))
        {
            # $ContentPath in this case points to physical path of the website.
            Remove-Item -Path $ContentPath -Recurse -ErrorAction SilentlyContinue 
        }
        else
        {
            # this is the case where $ContentPath points to IIS website name and not the actual path
            $site = Get-ItemProperty -Path "IIS:\Sites\$ContentPath" -ErrorAction SilentlyContinue
            if ($site -ne $null)
            {
                $path = $site.physicalPath
                $files = Get-Item -Path $path -ErrorAction SilentlyContinue           
                Remove-Item -Path $files -Recurse -ErrorAction SilentlyContinue 
            }
        }
    }
}

#########################################################################################################################################
# Test-TargetResource ([string]$PackagePath, [string]$ContentPath, [string]$Ensure) : given the package and IIS website name or content path, 
# determine whether the package is deployed or not.
#########################################################################################################################################

function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $PackagePath,
        [parameter(Mandatory = $true)]
        [System.String]
        $ContentPath,
        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure = "Present"
    )

    $result = $false    
    $appCmd = "$env:PROGRAMFILES\IIS\Microsoft Web Deploy V3\msdeploy.exe"

    #get all the files from a given package
    $packageFiles = & $appCmd -verb:dump "-source:package=$PackagePath"

    if($Ensure -eq "Present")
    {
        #find all the files for a given (Present) site
        if($ContentPath.contains("\") -and $ContentPath.contains(":"))
        {
            $siteFiles = & $appCmd -verb:dump "-source:contentPath=$ContentPath"
        }
        else
        {
            $siteFiles = & $appCmd -verb:dump "-source:iisApp=$ContentPath"
        }
        # the packages exported using webdeploy tool, content has 2 extra redundant entries for site name.
        #compare
        if(($siteFiles.Count -gt ($packageFiles.Count -2)) -and ($siteFiles.Count -lt ($packageFiles.Count +2)))
        {
            $result = $true
        }
    }
    else
    {

        #find all the files for a given (Absent) site
        if($ContentPath.contains("\") -and $ContentPath.contains(":"))
        {
            $siteFiles = & $appCmd -verb:dump "-source:contentPath=$ContentPath"
        }
        else
        {
            $siteFiles = & $appCmd -verb:dump "-source:iisApp=$ContentPath"
        }
        # the packages exported using webdeploy tool, content has 2 extra redundant entries for site name.
        #compare
        if(($packageFiles.Count -eq $siteFiles.Count) -or (($packageFiles.Count -2) -eq $siteFiles.Count) -or (($packageFiles.Count +2) -eq $siteFiles.Count))
        {
            $result = $false
        }
    }
    Return $result
}
