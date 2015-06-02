Import-Module WebAdministration
if(!([System.Diagnostics.EventLog]::SourceExists("RS_rsDomainIPRestrictions"))){
    New-EventLog -LogName DevOps -Source "RS_rsDomainIPRestrictions"
}
function LocateEntry{
    param(
        $entryType,
        $ipAddress,
        $mask,
        $SiteName,
        $AllowUnlisted
    )

    if($AllowUnlisted){$ipAccessState = $false}
    else{$ipAccessState = $true}

    switch($entryType){
        Range{
            $entryState = Get-WebConfigurationProperty -Filter system.webserver/security/ipsecurity -Location $SiteName -Name .collection | where{$_.ipaddress -eq $ipAddress -and $_.subnetmask -eq $mask -and $_.allowed -eq $ipAccessState}
        }
        SingleIP{
            $entryState = Get-WebConfigurationProperty -Filter system.webserver/security/ipsecurity -Location $SiteName -Name .collection | where{$_.ipaddress -eq $ipAddress -and $_.allowed -eq $ipAccessState}
        }
        Domain{
            $entryState = Get-WebConfigurationProperty -Filter system.webserver/security/ipsecurity -Location $SiteName -Name .collection | where{$_.domainName -eq $ipAddress -and $_.allowed -eq $ipAccessState}
        }
        Invalid{
            $entryState = $null
        }
    }
    if($entryState -ne $null){Return $true}
    else{Return $false}
}
function ParseEntryList{
    param(
        $entry,
        $EnableReverseDNS
    )

    if(($entry.Contains(".")) -and ($entry.Contains("/"))){
        try{[ipaddress]$ipAddress = $entry.Split("/")[0].Trim()}
        catch{Write-Verbose "Address from $($entry) could not be parsed as an IP Address. Please check entry.";$ipAddress = $null}
        try{[int]$mask = $entry.Split("/")[1].Trim()}
        catch{Write-Verbose "Mask from $($entry) could not be parsed as integer. Please check entry";$mask = $null}
        if(($ipAddress -ne $null) -and ($mask -ne $null)){
            $entryType = "Range";$ipAddress = $ipAddress.IPAddressToString
            Return $entryType,$ipAddress.IPAddressToString,$mask
        }
        else{$entryType = "Invalid"}
    }
    else{
        try{[ipaddress]$ipAddress = $entry}
        catch{Write-Verbose "Address from $($entry) could not be parsed as an IP Address. Checking if domain entries are permitted.";$ipAddress = $null}
        if($ipAddress -ne $null){
            $entryType = "SingleIP"
        }
        elseif($EnableReverseDNS){$entryType = "Domain"}
        else{$entryType = "Invalid"}
    }
    Return $entryType
}
function Get-TargetResource{
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	param(
		[bool]$AllowUnlisted = $true,
        [ValidateSet("Forbidden","NotFound","Unauthorized","AbortRequest")]
        $DenyAction = "Forbidden",
        [bool]$EnableReverseDNS = $false,
        [Parameter(Mandatory = $true)]
        [string[]]$EntryList,
        [parameter(Mandatory = $true)]
		[string]$SiteName
	)

    if((Get-Website $SiteName) -ne $null){	
        $domConfig = Get-WebConfiguration /system.webServer/security/ipsecurity -Location $SiteName
    }
    else{$SiteName = $null}
    
    @{
        "SiteName" = $SiteName
        "AllowUnlisted" = $domConfig.allowUnlisted
        "DenyAction" = $domConfig.denyAction
        "EnableReverseDNS" = $domConfig.enableReverseDns
        "EntryList" = $EntryList
    }
}
function Set-TargetResource{
	[CmdletBinding()]
	param(
		[bool]$AllowUnlisted = $true,
        [ValidateSet("Forbidden","NotFound","Unauthorized","AbortRequest")]
        $DenyAction = "Forbidden",
        [bool]$EnableReverseDNS = $false,
        [Parameter(Mandatory = $true)]
        [string[]]$EntryList,
        [parameter(Mandatory = $true)]
		[string]$SiteName
	)
    
    $gtResults = (Get-TargetResource @PSBoundParameters);
    $configDrift = @{}
    if($AllowUnlisted){$ipAccessState = $false}
    else{$ipAccessState = $true}
    if($gtResults.SiteName -eq $null){
        Write-Verbose "Site $($SiteName) could not be located in IIS. The configuration cannot be processed in this state, this event has been logged to the DevOps Event Log."
        Write-EventLog -LogName DevOps -Source RS_rsDomainIPRestrictions -EntryType Error -EventId 1280 -Message "Site $($SiteName) not present in IIS, cannot implement configuration. Exiting..."
        Return
    }
    if($gtResults.AllowUnlisted -ne $AllowUnlisted){$configDrift.Add("AllowUnlisted",$AllowUnlisted)}
    if($gtResults.DenyAction -ne $DenyAction){$configDrift.Add("DenyAction",$DenyAction)}
    if($gtResults.EnableReverseDNS -ne $EnableReverseDNS){$configDrift.Add("EnableReverseDNS",$EnableReverseDNS)}

    if($configDrift.Count -ne 0){
        Set-WebConfiguration -Filter system.webserver/security/ipsecurity -Location $SiteName -InputObject $configDrift -Verbose
    }

    foreach($entry in $EntryList){
        $entryResults = ParseEntryList -EnableReverseDNS $EnableReverseDNS -entry $entry
        if($entryResults.count -gt 1){$entryType = $entryResults[0]}
        else{$entryType = $entryResults}
        switch($entryType){
            Range{
                if(-not (LocateEntry -SiteName $SiteName -AllowUnlisted $AllowUnlisted -entryType $entryType -ipAddress $entryResults[1] -mask $entryResults[2])){
                    Add-WebConfigurationProperty -Filter system.webserver/security/ipsecurity -Name .collection -Location $SiteName -Value @{ipAddress="$($entryResults[1])";subnetMask="$($entryResults[2])";allowed="$ipAccessState"} -Verbose
                }
                else{Write-Verbose "Located entry $($entry) in IIS"}
            }
            SingleIP{
                if(-not (LocateEntry -SiteName $SiteName -AllowUnlisted $AllowUnlisted -entryType $entryType -ipAddress $entry)){
                    Add-WebConfigurationProperty -Filter system.webserver/security/ipsecurity -Name .collection -Location $SiteName -Value @{"ipAddress"=$entry;"allowed"=$ipAccessState} -Verbose
                }
                else{Write-Verbose "Located entry $($entry) in IIS"}
            }
            Domain{
                if(-not (LocateEntry -SiteName $SiteName -AllowUnlisted $AllowUnlisted -entryType $entryType -ipAddress $entry)){
                    Add-WebConfigurationProperty -Filter system.webserver/security/ipsecurity -Name .collection -Location $SiteName -Value @{domainName="$entry";allowed="$ipAccessState"} -Verbose
                }
                else{Write-Verbose "Located entry $($entry) in IIS"}
            }
            Invalid{
                Write-Verbose "Entry $($entry) could not be added to configuration because it could not be parsed as IP, IP Range, or Domain, or Reverse DNS is not Enabled. This event has been logged to the DevOps Log"
                Write-EventLog -LogName DevOps -Source RS_rsDomainIPRestrictions -EntryType Error -EventId 1290 -Message "Domain & IP Restriction entry: $($entry)`ncould not be added, because it could not be parsed as a Domain, IP, or IP Range."
            }
        }
    }
}
function Test-TargetResource{
	[CmdletBinding()]
	[OutputType([System.Boolean])]
	param(
		[bool]$AllowUnlisted = $true,
        [ValidateSet("Forbidden","NotFound","Unauthorized","AbortRequest")]
        $DenyAction = "Forbidden",
        [bool]$EnableReverseDNS = $false,
        [Parameter(Mandatory = $true)]
        [string[]]$EntryList,
        [parameter(Mandatory = $true)]
		[string]$SiteName
	)
    
    $gtResults = (Get-TargetResource @PSBoundParameters);
    $notFoundCounter = 0
    if($gtResults.SiteName -eq $null){Return $false}
    elseif($gtResults.AllowUnlisted -ne $AllowUnlisted){Return $false}
    elseif($gtResults.DenyAction -ne $DenyAction){Return $false}
    elseif($gtResults.EnableReverseDNS -ne $EnableReverseDNS){Return $false}

    foreach($entry in $EntryList){
        $entryResults = ParseEntryList -EnableReverseDNS $EnableReverseDNS -entry $entry
        if($entryResults.count -gt 1){$entryType = $entryResults[0]}
        else{$entryType = $entryResults}
        if($entryResults.count -gt 2){
            if(-not (LocateEntry -AllowUnlisted $AllowUnlisted -SiteName $SiteName -entryType $entryType -ipAddress $entryResults[1] -mask $entryResults[2])){Write-Verbose "Entry $($entry) Not Found";$notFoundCounter++}
            else{Write-Verbose "Located entry $($entry) in IIS"}
        }
        else{
            if(-not (LocateEntry -AllowUnlisted $AllowUnlisted -SiteName $SiteName -entryType $entryType -ipAddress $entry)){Write-Verbose "Entry $($entry) Not Found";$notFoundCounter++}
            else{Write-Verbose "Located entry $($entry) in IIS"}
        }
    }

    if($notFoundCounter -gt 0){Return $false}
    else{Return $true}
}
Export-ModuleMember -Function *-TargetResource