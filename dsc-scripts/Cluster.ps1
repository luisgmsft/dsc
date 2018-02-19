Configuration Cluster
{
    Param(
        [string]$safeModePassword = "test$!Passw0rd111"
    )
    Import-DscResource -ModuleName PSDesiredStateConfiguration, xStorage, xNetworking, SqlServerDsc, xComputerManagement

    #Step by step to reverse
    #https://www.mssqltips.com/sqlservertip/4991/implement-a-sql-server-2016-availability-group-without-active-directory-part-1/
    #
    #2.1-Create a Windows Failover Cluster thru Powershell
    #    https://docs.microsoft.com/en-us/sql/database-engine/availability-groups/windows/enable-and-disable-always-on-availability-groups-sql-server
    #    https://docs.microsoft.com/en-us/powershell/module/failoverclusters/new-cluster?view=win10-ps
    #    New-Cluster -Name “WSFCSQLCluster” -Node sqlao-vm1,sqlao-vm2 -AdministrativeAccessPoint DNS

    Node localhost
    {
        # $Path = $env:TEMP; $Installer = "chrome_installer.exe"; Invoke-WebRequest "http://dl.google.com/chrome/install/375.126/chrome_installer.exe" -OutFile $Path\$Installer; Start-Process -FilePath $Path\$Installer -Args "/silent /install" -Verb RunAs -Wait; Remove-Item $Path\$Installer
        # https://go.microsoft.com/fwlink/?LinkId=708343&clcid=0x409

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
        
        WindowsFeature 'NetFramework45'
        {
            Name = 'NET-Framework-45-Core'
            Ensure = 'Present'
            IncludeAllSubFeature = $true
        }
        
        WindowsFeature AddFailoverFeature
        {
            Ensure = 'Present'
            Name   = 'Failover-clustering'
        }

        WindowsFeature AddRemoteServerAdministrationToolsClusteringPowerShellFeature
        {
            Ensure    = 'Present'
            Name      = 'RSAT-Clustering-PowerShell'
            DependsOn = '[WindowsFeature]AddFailoverFeature'
        }

        WindowsFeature AddRemoteServerAdministrationToolsClusteringCmdInterfaceFeature
        {
            Ensure    = 'Present'
            Name      = 'RSAT-Clustering-CmdInterface'
            DependsOn = '[WindowsFeature]AddRemoteServerAdministrationToolsClusteringPowerShellFeature'
        }

        WindowsFeature AddRemoteServerAdministrationToolsClusteringServerToolsFeature
        {
            Ensure    = 'Present'
            Name      = 'RSAT-Clustering-Mgmt'
            DependsOn = '[WindowsFeature]AddRemoteServerAdministrationToolsClusteringCmdInterfaceFeature'
        }

        LocalConfigurationManager 
        {
            RebootNodeIfNeeded = $true
        }
    }

    Node localhost
    {
        $pw = convertto-securestring $safeModePassword -AsPlainText -Force
        $cred = new-object -typename System.Management.Automation.PSCredential -argumentlist ".\testadminuser",$pw
        # https://github.com/PowerShell/SqlServerDsc#sqlserviceaccount
        SqlServiceAccount SetServiceAccount_User
        {
            ServerName     = $env:COMPUTERNAME
            InstanceName   = 'MSSQLSERVER'
            ServiceType    = 'DatabaseEngine'
            ServiceAccount = $cred
            RestartService = $true
            PsDscRunAsCredential = $cred
        }

        # Script SetDNSSuffix
        # {
        #     SetScript = {
        #         $adapter=Get-WmiObject Win32_NetworkAdapterConfiguration -filter 'IPEnabled=True'
        #         $adapter.SetDNSDomain('lugizi.ao.contoso.com')
        #     }
        #     TestScript = {
        #         return $false
        #     }
        #     GetScript = { @{ Result = '' }}
        #     PsDscRunAsCredential = $cred
        # }

        LocalConfigurationManager 
        {
            RebootNodeIfNeeded = $true
        }

        Script EnableLocalAccountForWindowsCluster
        {
            SetScript = {
                Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System -Name LocalAccountTokenFilterPolicy -Value 1
            }
            TestScript = {
                return $false
            }
            GetScript = { @{ Result = '' }}
            PsDscRunAsCredential = $cred
        }
    }

    Node localhost
    {
        # if ($env:COMPUTERNAME -eq 'sqlao1') {
        #     $pw = convertto-securestring $safeModePassword -AsPlainText -Force
        #     $cred = new-object -typename System.Management.Automation.PSCredential -argumentlist "sqlao1\testadminuser",$pw

        #     Script CreateWindowsCluster
        #     {
        #         PsDscRunAsCredential = $cred
        #         SetScript =
        #         {
        #             New-Cluster -Name 'sqlaocl' -Node 'sqlao1','sqlao2' -StaticAddress 172.18.0.100 -AdministrativeAccessPoint Dns
        #         }
        #         TestScript = {
        #             Start-Sleep -s 120
        #             return $false
        #         }
        #         GetScript = { @{ Result = '' } }
        #         DependsOn = '[Script]EnableLocalAccountForWindowsCluster'
        #     }
    
        #     Script EnableAvailabilityGroupOnPrimary
        #     {
        #         SetScript =
        #         {
        #             Enable-SqlAlwaysOn -Path "SQLSERVER:\SQL\localhost\DEFAULT" -Force
        #         }
        #         TestScript = {
        #             return $false
        #         }
        #         GetScript = { @{ Result = (Get-Cluster | Format-List) } }
        #         DependsOn = '[Script]CreateWindowsCluster'
        #         PsDscRunAsCredential = $cred
        #     }
        # }

        File DirectoryTemp
        {
            Ensure = "Present"  # You can also set Ensure to "Absent"
            Type = "Directory" # Default is "File".
            Recurse = $false
            DestinationPath = "C:\TempDSCAssets"
        }

        Script GetCerts
        { 
            SetScript = 
            { 
                $webClient = New-Object System.Net.WebClient 
                $uri = New-Object System.Uri "https://lugizidscstorage.blob.core.windows.net/isos/certs.zip" 
                $webClient.DownloadFile($uri, "C:\TempDSCAssets\certs.zip") 
            } 
            TestScript = { Test-Path "C:\TempDSCAssets\certs.zip" } 
            GetScript = { @{ Result = (Get-Content "C:\TempDSCAssets\certs.zip") } } 
            DependsOn = '[File]DirectoryTemp'
        }

        archive CertZipFile
        {
            Path = 'C:\TempDSCAssets\certs.zip'
            Destination = 'c:\TempDSCAssets\'
            Ensure = 'Present'
            DependsOn = '[Script]GetCerts'
        }

        Script GetTScripts 
        { 
            SetScript = 
            { 
                $webClient = New-Object System.Net.WebClient 
                $uri = New-Object System.Uri "https://lugizidscstorage.blob.core.windows.net/isos/tscripts.zip" 
                $webClient.DownloadFile($uri, "C:\TempDSCAssets\tscripts.zip") 
            } 
            TestScript = { Test-Path "C:\TempDSCAssets\tscripts.zip" } 
            GetScript = { @{ Result = (Get-Content "C:\TempDSCAssets\tscripts.zip") } } 
            DependsOn = '[File]DirectoryTemp'
        }

        archive ZipFile
        {
            Path = 'C:\TempDSCAssets\tscripts.zip'
            Destination = 'c:\TempDSCAssets\'
            Ensure = 'Present'
            DependsOn = '[Script]GetTScripts'
        }
    }

    Node localhost
    {
        # if ($env:COMPUTERNAME -eq 'sqlao1') {
            
        # }
        
        # if ($env:COMPUTERNAME -eq 'sqlao2') {
        #     Script JoinSecondary
        #     {
        #         SetScript =
        #         {
        #             #Add-ClusterNode -Name 'sqlao2' -Cluster 'SQLAOAG'
        #         }
        #         TestScript = {
        #             Start-Sleep -s 180
        #             return $true
        #         }
        #         GetScript = { @{ Result = (Get-ClusterNode | Format-List) } }
        #         #DependsOn = '[Script]CreateWindowsCluster'
        #     }

        #     Script EnableAvailabilityGroupOnSecondary
        #     {
        #         SetScript =
        #         {
        #             Enable-SqlAlwaysOn -Path "SQLSERVER:\SQL\localhost\DEFAULT" -Force
        #         }
        #         TestScript = {
        #             return $false
        #         }
        #         GetScript = { @{ Result = (Get-Cluster | Format-List) } }
        #         # DependsOn = '[Script]JoinSecondary'
        #     }
        # }
    }

    # Node localhost
    # {
    #     Script WaitForAG
    #         {
    #             SetScript =
    #             {
    #                 #Add-ClusterNode -Name 'sqlao2' -Cluster 'SQLAOAG'
    #             }
    #             TestScript = {
    #                 Start-Sleep -s 240
    #                 return $true
    #             }
    #             GetScript = { @{ Result = (Get-ClusterNode | Format-List) } }
    #         }
        
    #     if ($env:COMPUTERNAME -eq 'sqlao1')
    #     {
    #         SqlScript 'Primary-Step-1' {
    #             ServerInstance = 'sqlao1'
    #             SetFilePath = 'c:\TempDSCAssets\vm1-step1.sql'
    #             TestFilePath = 'c:\TempDSCAssets\dummy-for-all-tests.sql'
    #             GetFilePath = 'c:\TempDSCAssets\dummy-for-all-tests.sql'

    #             PsDscRunAsCredential = $cred
    #             DependsOn = '[Script]WaitForAG'
    #         }
    #     }

    #     if ($env:COMPUTERNAME -eq 'sqlao2')
    #     {
    #         SqlScript 'Secondary-Step-1' {
    #             ServerInstance = 'sqlao2'
    #             SetFilePath = 'c:\TempDSCAssets\vm2-step1.sql'
    #             TestFilePath = 'c:\TempDSCAssets\dummy-for-all-tests.sql'
    #             GetFilePath = 'c:\TempDSCAssets\dummy-for-all-tests.sql'

    #             PsDscRunAsCredential = $cred
    #             DependsOn = '[Script]WaitForAG'
    #         }

    #     }
    # }

    # Node localhost
    # {
    #     Script WaitForStep1
    #         {
    #             SetScript =
    #             {
    #                 #Add-ClusterNode -Name 'sqlao2' -Cluster 'SQLAOAG'
    #             }
    #             TestScript = {
    #                 Start-Sleep -s 280
    #                 return $true
    #             }
    #             GetScript = { @{ Result = (Get-ClusterNode | Format-List) } }
    #         }
        
    #     if ($env:COMPUTERNAME -eq 'sqlao1')
    #     {
    #         SqlScript 'Primary-Step-2' {
    #             ServerInstance = 'sqlao1'
    #             SetFilePath = 'c:\TempDSCAssets\vm1-step2.sql'
    #             TestFilePath = 'c:\TempDSCAssets\dummy-for-all-tests.sql'
    #             GetFilePath = 'c:\TempDSCAssets\dummy-for-all-tests.sql'

    #             PsDscRunAsCredential = $cred
    #             DependsOn = '[Script]WaitForStep1'
    #         }
    #     }

    #     if ($env:COMPUTERNAME -eq 'sqlao2')
    #     {
    #         SqlScript 'Secondary-Step-2' {
    #             ServerInstance = 'sqlao2'
    #             SetFilePath = 'c:\TempDSCAssets\vm2-step2.sql'
    #             TestFilePath = 'c:\TempDSCAssets\dummy-for-all-tests.sql'
    #             GetFilePath = 'c:\TempDSCAssets\dummy-for-all-tests.sql'

    #             PsDscRunAsCredential = $cred
    #             DependsOn = '[Script]WaitForStep1'
    #         }

    #     }
    # }
}