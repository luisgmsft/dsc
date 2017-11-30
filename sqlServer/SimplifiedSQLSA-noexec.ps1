Configuration SimplifiedSQLSA
{
    Import-DscResource -ModuleName PSDesiredStateConfiguration, xStorage, xSQLServer, xNetworking

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
        $Path = $env:TEMP; $Installer = "chrome_installer.exe"; Invoke-WebRequest "http://dl.google.com/chrome/install/375.126/chrome_installer.exe" -OutFile $Path\$Installer; Start-Process -FilePath $Path\$Installer -Args "/silent /install" -Verb RunAs -Wait; Remove-Item $Path\$Installer
        
        xFirewall SQLAGRuleIn
        {
            Name                  = 'SQLAG-In'
            DisplayName           = 'SQLAG-In'
            Group                 = 'SQLAG Firewall Rule Group'
            Ensure                = 'Present'
            Enabled               = 'True'
            Profile               = ('Domain', 'Private', 'Public')
            Action                = 'Allow'
            Direction             = 'Inbound'
            LocalPort            = ('5022')
            Protocol              = 'TCP'
            Description           = 'Firewall Rule for allowing incoming traffic on SQL Availability Group'
        }

        xFirewall SQLAGRuleOut
        {
            Name                  = 'SQLAG-Out'
            DisplayName           = 'SQLAG-Out'
            Group                 = 'SQLAG Firewall Rule Group'
            Ensure                = 'Present'
            Enabled               = 'True'
            Profile               = ('Domain', 'Private', 'Public')
            Action                = 'Allow'
            Direction             = 'Outbound'
            RemotePort            = ('5022')
            Protocol              = 'TCP'
            Description           = 'Firewall Rule for allowing outgoing traffic on SQL Availability Group'
        }
        
        Script GetISO
        {
            SetScript =
            {
                $webClient = New-Object System.Net.WebClient
                $uri = New-Object System.Uri "https://lugizidscstorage.blob.core.windows.net/isos/SQLServer2016SP1-FullSlipstream-x64-ENU.iso"
                $webClient.DownloadFile($uri, "C:\sqlsetup.iso")
            }
            TestScript = { Test-Path "C:\sqlsetup.iso" }
            GetScript = { @{ Result = (Get-Content "C:\sqlsetup.iso") } }
        }

        Script GetNorthwindBackup
        {
            SetScript =
            {
                $webClient = New-Object System.Net.WebClient
                $uri = New-Object System.Uri "https://lugizidscstorage.blob.core.windows.net/isos/Northwind.bak"
                $webClient.DownloadFile($uri, "C:\Northwind.bak")
            }
            TestScript = { Test-Path "C:\Northwind.bak" }
            GetScript = { @{ Result = (Get-Content "C:\Northwind.bak") } }
        }

        xMountImage ISO
        {
            ImagePath   = 'C:\sqlsetup.iso'
            DriveLetter = $NextAvailableDiskLetter
        }

        xWaitForVolume WaitForISO
        {
            DriveLetter      = $NextAvailableDiskLetter
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
            RebootNodeIfNeeded = $true
        }

        Script CreateWindowsCluster
        {
            SetScript =
            {
                try {
                    New-Cluster -Name SQLAOAG -Node sqlao-vm1, sqlao-vm2 -StaticAddress 172.18.0.100 -AdministrativeAccessPoint Dns
                } catch
                {
                    $ErrorMsg = $_.Exception.Message
                    Write-Verbose -Verbose $ErrorMsg
                }
            }
            TestScript = {
                try {
                    $cluster = Get-Cluster | Format-List
                    if ($cluster -eq 'Name : SQLAOAG')
                    {
                        return $true
                    }
                } catch
                {
                    $ErrorMsg = $_.Exception.Message
                    Write-Verbose -Verbose $ErrorMsg
                }
                return $false
            }
            GetScript = { @{ Result = '' } }
            DependsOn = '[WindowsFeature]FailoverClusterTools', '[WindowsFeature]FCPS'
        }

        # Script EnableAvailabilityGroup
        # {
        #     SetScript =
        #     {
        #         Enable-SqlAlwaysOn -Path "SQLSERVER:\SQL\localhost\DEFAULT" -Force
        #     }
        #     TestScript = {
        #         return $false
        #     }
        #     GetScript = { @{ Result = (Get-Cluster | Format-List) } }
        #     DependsOn = '[Script]CreateWindowsCluster'
        # }
     }
}