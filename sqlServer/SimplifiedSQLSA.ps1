<#
.EXAMPLE
    In this example, we will create a failover cluster with two servers. No need for Active Directory.
#>

Configuration SimplifiedSQLSA
{
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
        if ($env:COMPUTERNAME -eq 'sqlao-vm1') {
            Script CreateWindowsCluster
            {
                SetScript =
                {
                    try {
                        # New-Cluster -Name 'SQLAOAG' -Node sqlao-vm1, sqlao-vm2 -StaticAddress '172.18.0.100/24' -AdministrativeAccessPoint Dns
                        New-Cluster -Name 'SQLAOAG' -Node $env:COMPUTERNAME -StaticAddress '172.18.0.100' -AdministrativeAccessPoint Dns
                    } catch
                    {
                        $ErrorMsg = $_.Exception.Message
                        Write-Verbose -Verbose $ErrorMsg
                    }
                }
                TestScript = {
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
    }

    Node localhost
    {
        if ($env:COMPUTERNAME -eq 'sqlao-vm1') {
            
        }
        
        if ($env:COMPUTERNAME -eq 'sqlao-vm2') {
            Script JoinSecondary
            {
                SetScript =
                {
                    Add-ClusterNode -Name 'sqlao-vm2' -Cluster 'SQLAOAG'
                }
                TestScript = {
                    Start-Sleep -s 60
                    return $false
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