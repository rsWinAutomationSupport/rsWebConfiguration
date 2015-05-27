Import-Module WebAdministration
if(!([System.Diagnostics.EventLog]::SourceExists("RS_rsWebConfigLock"))){
    New-EventLog -LogName DevOps -Source "RS_rsWebConfigLock"
}
function BuildandExecute{
    param(
        [string]$psPath,
        [string]$location,
        [bool]$locked=$false,
        [string]$filter,
        [string]$type,
        [ValidateSet("Get","Remove","Add")]
        $CommandVerb
	)
    
    if($location -eq ""){$PSBoundParameters.Remove("location") | Out-Null}
    if($psPath -eq ""){$PSBoundParameters.Remove("pspath") | Out-Null}
    if(($type -eq "") -or (@("Get","Remove") -contains $CommandVerb)){$PSBoundParameters.Remove("type") | Out-Null}

    if($locked -and ($type -eq "")){
        Write-EventLog -LogName DevOps -Source RS_rsWebConfigLock -EntryType Error -EventId 1000 -Message "Could not complete configuration because Locked = True and Type is set to null. Type must have a value set to continue."
        throw "Could not complete configuration because Locked = True and Type is set to null. Type must have a value set to continue."
    }

    $command = $CommandVerb + "-WebConfigurationLock"
    foreach($param in $PSBoundParameters.Keys){
        if(@("verbose","debug","locked","CommandVerb") -notcontains $param){
            $command += " "
            $command += "-$($param) " + $PSBoundParameters.($param)
        }
    }
    $commandScript = [scriptblock]::Create($command)
    Write-Verbose "Executing the following command: $($commandScript)"
    try{
        $commandResult = Invoke-Command -ScriptBlock $commandScript
    }
    catch{
        Write-EventLog -LogName DevOps -Source RS_rsWebConfigLock -EntryType Error -EventId 1000 -Message "Could not $($CommandVerb) web configuration lock because PSPath $($psPath) did not exist.`n $_.Exception.Message"
        throw "Could not $($CommandVerb) web configuration lock because PSPath $($psPath) did not exist."
    }
    Return $commandResult
}
function Get-TargetResource{
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	param(
        [string]$psPath,
        [string]$location,
        [bool]$locked=$false,
        [Parameter(Mandatory=$true)]
        [string]$filter,
        [ValidateSet("inclusive","exclusive")]
        [string]$type
	)
    
    $commandResult = BuildandExecute -psPath $psPath -locked $locked -filter $filter -location $location -type $type -CommandVerb Get
    if($commandResult -ne $null){
        return @{
            "PSPath" = $commandResult.pspath
            "Filter" = $filter
            "Location" = $commandResult.location
            "Type" = $type
            "Locked" = $commandResult.value
        }
    }
    else{
        return @{
            "Locked" = $false
        }
    }
}
function Set-TargetResource{
	[CmdletBinding()]
	param(
        [string]$psPath,
        [string]$location,
        [bool]$locked=$false,
        [Parameter(Mandatory=$true)]
        [string]$filter,
        [ValidateSet("inclusive","exclusive")]
        [string]$type
	)

    Switch($locked){
        True{
            BuildandExecute -psPath $psPath -locked $locked -filter $filter -location $location -type $type -CommandVerb Add
        }
        False{
            BuildandExecute -psPath $psPath -locked $locked -filter $filter -location $location -type $type -CommandVerb Remove
        }
    }
}
function Test-TargetResource{
	[CmdletBinding()]
	[OutputType([System.Boolean])]
	param(
        [string]$psPath,
        [string]$location,
        [bool]$locked=$false,
        [Parameter(Mandatory=$true)]
        [string]$filter,
        [ValidateSet("inclusive","exclusive")]
        [string]$type
	)

    $commandResult = BuildandExecute -psPath $psPath -locked $locked -filter $filter -location $location -type $type -CommandVerb Get
    Write-Verbose "The command returned: $($commandResult)"
    switch($locked){
        True{
            if($commandResult -eq $null){Write-Verbose "Configuration should be locked but query did not return results. Test failed!";Return $false}
            else{Write-Verbose "Configuration should be locked and query returned expected results. Test passed!";Return $true}
        }
        False{
            if($commandResult -eq $null){Write-Verbose "Configuration should not be locked and query did not return results. Test passed!";Return $true}
            else{Write-Verbose "Configuration should not be locked but query did not return expected results. Test failed!";Return $false}
        }
    }
}
Export-ModuleMember -Function *-TargetResource