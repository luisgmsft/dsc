<#
.EXAMPLE
    In this example, we will create a failover cluster with two servers. No need for Active Directory.
#>

Configuration SimplifiedSQLSA
{
    Param(
        [string]$safeModePassword = "test$!Passw0rd111"
    )
    Import-DscResource -ModuleName PSDesiredStateConfiguration, xStorage, xSQLServer, xNetworking

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

        LocalConfigurationManager 
        {
            RebootNodeIfNeeded = $true
        }
    }

    Node localhost
    {
        if ($env:COMPUTERNAME -eq 'sqlao1') {
            $pw = convertto-securestring $safeModePassword -AsPlainText -Force
            $cred = new-object -typename System.Management.Automation.PSCredential -argumentlist "sqlao1\testadminuser",$pw

            Script CreateWindowsCluster
            {
                PsDscRunAsCredential = $cred
                SetScript =
                {
                    New-Cluster -Name 'SQLAOAG' -Node $env:COMPUTERNAME, 'sqlao2' -StaticAddress '172.18.0.100' -AdministrativeAccessPoint Dns
                }
                TestScript = {
                    Start-Sleep -s 90
                    return $false
                }
                GetScript = { @{ Result = '' } }
                #DependsOn = '[WindowsFeature]AddRemoteServerAdministrationToolsClusteringCmdInterfaceFeature'
            }
    
            Script EnableAvailabilityGroupOnPrimary
            {
                SetScript =
                {
                    Enable-SqlAlwaysOn -Path "SQLSERVER:\SQL\localhost\DEFAULT" -Force
                }
                TestScript = {
                    return $false
                }
                GetScript = { @{ Result = (Get-Cluster | Format-List) } }
                DependsOn = '[Script]CreateWindowsCluster'
            }
        }

        Script GetPrimaryCert 
        { 
            SetScript = 
            { 
                $webClient = New-Object System.Net.WebClient 
                $uri = New-Object System.Uri "https://lugizidscstorage.blob.core.windows.net/isos/SQLAO_VM1_cert.cer" 
                $webClient.DownloadFile($uri, "C:\SQLAO_VM1_cert.cer") 
            } 
            TestScript = { Test-Path "C:\SQLAO_VM1_cert.cer" } 
            GetScript = { @{ Result = (Get-Content "C:\SQLAO_VM1_cert.cer") } } 
        }
        
        Script GetSecondaryCert 
        { 
            SetScript = 
            { 
                $webClient = New-Object System.Net.WebClient 
                $uri = New-Object System.Uri "https://lugizidscstorage.blob.core.windows.net/isos/SQLAO_VM2_cert.cer" 
                $webClient.DownloadFile($uri, "C:\SQLAO_VM2_cert.cer") 
            } 
            TestScript = { Test-Path "C:\SQLAO_VM2_cert.cer" } 
            GetScript = { @{ Result = (Get-Content "C:\SQLAO_VM2_cert.cer") } } 
        }

        Script GetPrimaryCertKey
        { 
            SetScript = 
            { 
                $webClient = New-Object System.Net.WebClient 
                $uri = New-Object System.Uri "https://lugizidscstorage.blob.core.windows.net/isos/SQLAO_VM1_key.pvk" 
                $webClient.DownloadFile($uri, "C:\SQLAO_VM1_key.pvk") 
            } 
            TestScript = { Test-Path "C:\SQLAO_VM1_key.pvk" } 
            GetScript = { @{ Result = (Get-Content "C:\SQLAO_VM1_key.pvk") } } 
        }
        
        Script GetSecondaryCertKey 
        { 
            SetScript = 
            { 
                $webClient = New-Object System.Net.WebClient 
                $uri = New-Object System.Uri "https://lugizidscstorage.blob.core.windows.net/isos/SQLAO_VM2_key.pvk" 
                $webClient.DownloadFile($uri, "C:\SQLAO_VM2_key.pvk") 
            } 
            TestScript = { Test-Path "C:\SQLAO_VM2_key.pvk" } 
            GetScript = { @{ Result = (Get-Content "C:\SQLAO_VM2_key.pvk") } } 
        }

        Script GetDbBackup 
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
    }

    Node localhost
    {
        if ($env:COMPUTERNAME -eq 'sqlao1') {
            
        }
        
        if ($env:COMPUTERNAME -eq 'sqlao2') {
            Script JoinSecondary
            {
                SetScript =
                {
                    #Add-ClusterNode -Name 'sqlao2' -Cluster 'SQLAOAG'
                }
                TestScript = {
                    Start-Sleep -s 120
                    return $true
                }
                GetScript = { @{ Result = (Get-ClusterNode | Format-List) } }
                #DependsOn = '[Script]CreateWindowsCluster'
            }

            Script EnableAvailabilityGroupOnSecondary
            {
                SetScript =
                {
                    Enable-SqlAlwaysOn -Path "SQLSERVER:\SQL\localhost\DEFAULT" -Force
                }
                TestScript = {
                    return $false
                }
                GetScript = { @{ Result = (Get-Cluster | Format-List) } }
                DependsOn = '[Script]JoinSecondary'
            }
        }
    }
}

SimplifiedSQLSA -ConfigurationData .\ConfigData.psd1
Start-DscConfiguration -Path .\SimplifiedSQLSA -Verbose -Wait -Force