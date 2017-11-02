Configuration SimplifiedSQLSA
{
    Import-DscResource -ModuleName PSDesiredStateConfiguration, xStorage, xSQLServer

    #Finding the next avaiable disk letter for Add disk
    $NewDiskLetter = Get-ChildItem function:[f-z]: -n | Where-Object{ !(test-path $_) } | Select-Object -First 1 

    $NextAvailableDiskLetter = $NewDiskLetter[0]

    #Step by step to reverse
    #https://www.mssqltips.com/sqlservertip/4991/implement-a-sql-server-2016-availability-group-without-active-directory-part-1/
    #
    #2.1-Create a Windows Failover Cluster thru Powershell
    #    https://docs.microsoft.com/en-us/sql/database-engine/availability-groups/windows/enable-and-disable-always-on-availability-groups-sql-server
    #    https://docs.microsoft.com/en-us/powershell/module/failoverclusters/new-cluster?view=win10-ps
    #    New-Cluster -Name “WSFCSQLCluster” -Node sqlao-vm1,sqlao-vm2 -AdministrativeAccessPoint DNS

    #per node config must be passed externally here as there're
    #common but also specialized tasks
    node localhost
    {
        Script GetISO
        {
            SetScript =
            {
                $webClient = New-Object System.Net.WebClient
                $uri = New-Object System.Uri "https://[storageaccount].blob.core.windows.net/isos/SQLServer2016SP1-FullSlipstream-x64-ENU.iso"
                $webClient.DownloadFile($uri, "C:\sqlsetup.iso")
            }
            TestScript = { Test-Path "C:\sqlsetup.iso" }
            GetScript = { @{ Result = (Get-Content "C:\sqlsetup.iso") } }
        }

        xMountImage ISO
        {
            ImagePath   = 'C:\sqlsetup.iso'
            DriveLetter = 'F'
        }

        xWaitForVolume WaitForISO
        {
            DriveLetter      = 'F'
            RetryIntervalSec = 5
            RetryCount       = 10
        }  
        
        WindowsFeature 'NetFramework45'
        {
            Name = 'NET-Framework-45-Core'
            Ensure = 'Present'
            IncludeAllSubFeature = $true
        }

        WindowsFeature FC
        {
            Name = "Failover-Clustering"
            Ensure = "Present"
        }

        WindowsFeature FailoverClusterTools 
        { 
            Ensure = "Present" 
            Name = "RSAT-Clustering-Mgmt"
            DependsOn = "[WindowsFeature]FC"
        } 

        WindowsFeature FCPS
        {
            Name = "RSAT-Clustering-PowerShell"
            Ensure = "Present"
        }

        xSQLServerSetup 'InstallDefaultInstance'
        {
            InstanceName = 'MSSQLSERVER'
            Features = 'SQLENGINE'
            SourcePath = $NextAvailableDiskLetter + ':\'
            SQLSysAdminAccounts = @('Administrators')
            DependsOn = '[WindowsFeature]NetFramework45'
        }

        LocalConfigurationManager 
        {
            RebootNodeIfNeeded = $True
        }
     }
}