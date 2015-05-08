import-module WebAdministration

function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
     param
    (
        [parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][System.String]$path,
        [Boolean]$InitAfterRestart,
        [Boolean]$skipManagedModules,
        [System.String]$staticPage,
        [System.String]$initializationPage,
        [System.String]$initializationHost
    )


    if(Test-Path "IIS:\Sites\$path") {
        $filter = "/system.webServer/applicationInitialization" 
        $webconfig = Get-WebConfiguration -Location "$path" -Filter "$filter"

        return = @{
            "path"                   = $path;
            "initAfterRestart"       = $webConfig.doAppInitAfterRestart;
            "skipManagedModules"     = $webConfig.skipManagedModules;
            "remapManagedRequestsTo" = $webConfig.remapManagedRequestsTo;
            "initializationPage"     = $webConfig.collection.initializationPage;
            "initializationHost"     = $webConfig.Collection.hostname
        }

    }else{
        return @{path = "invalid"}
    }
}

function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][System.String]$path,
        [Boolean]$InitAfterRestart = $false,
        [Boolean]$skipManagedModules = $false,
        [System.String]$staticPage = '',
        [System.String]$initializationPage,
        [System.String]$initializationHost = "localhost"
    )

        $logSource = $PSCmdlet.MyInvocation.MyCommand.ModuleName
        New-EventLog -LogName "DevOps" -Source $logSource -ErrorAction SilentlyContinue
        $message = "IIS Application Initialization Configuration`n`n"

    if(Test-Path "IIS:\Sites\$path"){

        $filter = "/system.webServer/applicationInitialization" 
        
        Set-WebConfigurationProperty -location "$path" -filter "$filter" -name "doAppInitAfterRestart" -value $InitAfterRestart
        $message += "Configuring doAppInitAfterRestart for $path to $InitAfterRestart.`n"
        
        Set-WebConfigurationProperty -location "$path" -filter "$filter" -name "skipManagedModules" -value $skipManagedModules
        $message += "Configuring skipManagedModules for $path to $skipManagedModules.`n"
        
        Set-WebConfigurationProperty -location "$path" -filter "$filter" -name "remapManagedRequestsTo" -value $staticPage
        $message += "Configuring remapManagedRequestsTo for $path to $staticPage.`n"

        if($initializationPage -ne ''){
            Set-WebConfigurationProperty -location $path -filter $filter -name "." -value (@{initializationPage="$initializationPage";hostName="$initializationHost"})
            $message += "Configuring initializationPage for $path  to $initializationPage.`n"
            $message += "Configuring hostname for $path to $initializationHost.`n"
        } elseIf((Get-WebConfiguration -Location "$path" -Filter "$filter").Collection){
            Remove-WebConfigurationProperty -location "$path" -filter "$filter" -name "."
            $message += "Removed initializationPage and hostname configuration.`n"
        }
        $message += "`nConfiguration Complete."
        Write-EventLog -LogName DevOps -Source $logSource -EntryType Information -EventId 1000 -Message $message
    } else {
        Write-EventLog -LogName DevOps -Source $logSource -EntryType Information -EventId 1000 -Message "Path for IIS Authentication changes is invalid:  $path"
    }
}

function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][System.String]$path,
        [Boolean]$InitAfterRestart,
        [Boolean]$skipManagedModules,
        [System.String]$staticPage,
        [System.String]$initializationPage,
        [System.String]$initializationHost
    )

    $IsValid = $false

    if(Test-Path "IIS:\Sites\$path")
    {

        $filter = "/system.webServer/applicationInitialization" 
        $webconfig = Get-WebConfiguration -Location "$path" -Filter "$filter"

        $isValid = (
            ($initAfterRestart      -eq $webConfig.doAppInitAfterRestart) -and
            ($skipManagedModules     -eq $webConfig.skipManagedModules) -and
            ($staticPage -eq $webConfig.remapManagedRequestsTo) -and
            ($initializationPage     -eq $webConfig.collection.initializationPage) -and
            ($initializationHost     -eq $webConfig.Collection.hostname)
        )

    }
    
    Return $IsValid
}