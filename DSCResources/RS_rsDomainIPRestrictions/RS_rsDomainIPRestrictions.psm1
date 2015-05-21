Import-Module WebAdministration
if(!([System.Diagnostics.EventLog]::SourceExists("RS_rsDomainIPRestrictions"))){
    New-EventLog -LogName DevOps -Source "RS_rsDomainIPRestrictions"
}
function LocateEntry{
    param(
        $entryType,
        $ipAddress,
        $mask,
        $SiteName
    )

    if((Get-TargetResource @PSBoundParameters).AllowUnlisted){$ipAccessState = $false}
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
        $entry   
    )

    if(($entry.Contains(".")) -and ($entry.Contains("/"))){
        try{[ipaddress]$ipAddress = $entry.Split("/")[0].Trim()}
        catch{Write-Verbose "Address from $($entry) could not be parsed as an IP Address. Please check entry.";$ipAddress = $null}
        try{[int]$mask = $entry.Split("/")[1].Trim()}
        catch{Write-Verbose "Mask from $($entry) could not be parsed as integer. Please check entry";$mask = $null}
        if(($ipAddress -ne $null) -and ($mask -ne $null)){
            $entryType = "Range";$ipAddress = $ipAddress.IPAddressToString
            Return $entryType,$ipAddress,$mask
        }
        else{$entryType = "Invalid"}
    }
    else{
        try{[ipaddress]$ipAddress = $entry}
        catch{Write-Verbose "Address from $($entry) could not be parsed as an IP Address. Checking if domain entries are permitted.";$ipAddress = $null}
        if($ipAddress -ne $null){
            $entryType = "SingleIP"
        }
        elseif((Get-TargetResource @PSBoundParameters).EnableReverseDNS){$entryType = "Domain"}
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
    
    $gtResults = (Get-TargetResource @PSBoundParameters);$configDrift = @{}
    if($AllowUnlisted){$ipAccessState = $false}
    else{$ipAccessState = $true}
    if($gtResults.SiteName -eq $null){
        Write-EventLog -LogName DevOps -Source RS_rsDomainIPRestrictions -EntryType Error -EventId 1280 -Message "Site $($SiteName) not present in IIS, cannot implement configuration. Exiting..."
        Return
    }
    elseif($gtResults.AllowUnlisted -ne $AllowUnlisted){$configDrift.Add("AllowUnlisted",$AllowUnlisted)}
    elseif($gtResults.DenyAction -ne $DenyAction){$configDrift.Add("DenyAction",$DenyAction)}
    elseif($gtResults.EnableReverseDNS -ne $EnableReverseDNS){$configDrift.Add("EnableReverseDNS",$EnableReverseDNS)}

    Set-WebConfiguration -Filter system.webserver/security/ipsecurity -Location $SiteName -InputObject $configDrift -Verbose

    foreach($entry in $EntryList){
        $entryResults = ParseEntryList -entry $entry
        $entryType = $entryResults[0]
        switch($entryType){
            Range{
                if(-not (LocateEntry -entryType $entryResults[0] -ipAddress $entryResults[1] -mask $entryResults[2])){
                    Add-WebConfiguration -Filter system.webserver/security/ipsecurity -Location $SiteName -Value @{"ipAddress"=$entryResults[1];"subnetMask"=$entryResults[2];"allowed"=$ipAccessState} -Verbose
                }
            }
            SingleIP{
                if(-not (LocateEntry -entryType $entryResults[0] -ipAddress $entryResults[1] -mask $entryResults[2])){
                    Add-WebConfiguration -Filter system.webserver/security/ipsecurity -Location $SiteName -Value @{"ipAddress"=$entry;"allowed"=$ipAccessState} -Verbose
                }
            }
            Domain{
                if(-not (LocateEntry -entryType $entryResults[0] -ipAddress $entryResults[1] -mask $entryResults[2])){
                    Add-WebConfiguration -Filter system.webserver/security/ipsecurity -Location $SiteName -Value @{"domainName"=$entry;"allowed"=$ipAccessState} -Verbose
                }
            }
            Invalid{
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
    
    $gtResults = (Get-TargetResource @PSBoundParameters);$notFoundCounter = 0
    if($gtResults.SiteName -eq $null){Return $false}
    elseif($gtResults.AllowUnlisted -ne $AllowUnlisted){Return $false}
    elseif($gtResults.DenyAction -ne $DenyAction){Return $false}
    elseif($gtResults.EnableReverseDNS -ne $EnableReverseDNS){Return $false}

    foreach($entry in $EntryList){
        $entryResults = ParseEntryList -entry $entry
        if($entryResults.count -gt 2){
            if(-not (LocateEntry -SiteName $SiteName -entryType $entryResults[0] -ipAddress $entryResults[1] -mask $entryResults[2])){$notFoundCounter++}
        }
        else{
            if(-not (LocateEntry -SiteName $SiteName -entryType $entryResults[0] -ipAddress $entry)){$notFoundCounter++}
        }
    }

    if($notFoundCounter -gt 0){Return $false}
    else{Return $true}
}
Export-ModuleMember -Function *-TargetResource