Configuration Cluster
{
    Param(
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$AdminCreds,

        [Parameter(Mandatory)]
        [string]$DomainName
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

        File DirectoryTemp
        {
            Ensure = "Present"  # You can also set Ensure to "Absent"
            Type = "Directory" # Default is "File".
            Recurse = $false
            DestinationPath = "C:\TempDSCAssets"
            DependsOn = '[WindowsFeature]AddRemoteServerAdministrationToolsClusteringServerToolsFeature'
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

        Archive CertZipFile
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
            DependsOn = '[Archive]CertZipFile'
        }

        Archive TScriptsZipFile
        {
            Path = 'C:\TempDSCAssets\tscripts.zip'
            Destination = 'c:\TempDSCAssets\'
            Ensure = 'Present'
            DependsOn = '[Script]GetTScripts'
        }

        # https://github.com/PowerShell/SqlServerDsc#sqlserviceaccount
        SqlServiceAccount SetServiceAccount_User
        {
            ServerName     = $env:COMPUTERNAME
            InstanceName   = 'MSSQLSERVER'
            ServiceType    = 'DatabaseEngine'
            ServiceAccount = $AdminCreds
            RestartService = $true
            PsDscRunAsCredential = $AdminCreds
            DependsOn = '[Archive]TScriptsZipFile'
        }

        Registry EnableLocalAccountForWindowsCluster #ResourceName
        {
            Key = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\'
            ValueName = 'LocalAccountTokenFilterPolicy'
            Ensure = 'Present'
            Force =  $true
            ValueData = 1
            ValueType = 'Dword'
            DependsOn = '[SqlServiceAccount]SetServiceAccount_User'
        }

        Registry SetDomain #ResourceName
        {
            Key = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\'
            ValueName = 'Domain'
            Ensure = 'Present'
            Force =  $true
            DependsOn = '[Registry]EnableLocalAccountForWindowsCluster'
            ValueData = $DomainName
            ValueType = 'String'
        }
        Registry SetNVDomain #ResourceName
        {
            Key = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\'
            ValueName = 'NV Domain'
            Ensure = 'Present'
            Force =  $true
            DependsOn = '[Registry]SetDomain'
            ValueData = $DomainName
            ValueType = 'String'
        }

        Script DNSReboot
        {
            TestScript = {
                return (Test-Path HKLM:\SOFTWARE\MyMainKey\RebootKey)
            }
            SetScript = {
                New-Item -Path HKLM:\SOFTWARE\MyMainKey\RebootKey -Force
                 $global:DSCMachineStatus = 1
            }
            GetScript = { return @{result = 'result'}}
            DependsOn = '[Registry]SetNVDomain'
        }

        LocalConfigurationManager
        {
            RebootNodeIfNeeded = $true
            ActionAfterReboot = "ContinueConfiguration"
        }
    }
}