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

    Node $AllNodes.Where{$_.Role -eq 'FirstServerNode' }.NodeName
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

        Script CreateWindowsCluster
        {
            SetScript =
            {
                try {
                    # New-Cluster -Name 'SQLAOAG' -Node sqlao-vm1, sqlao-vm2 -StaticAddress '172.18.0.100/24' -AdministrativeAccessPoint Dns
                    New-Cluster -Name  -Node $env:COMPUTERNAME -StaticAddress '172.18.0.100/24' -AdministrativeAccessPoint Dns
                } catch
                {
                    $ErrorMsg = $_.Exception.Message
                    Write-Verbose -Verbose $ErrorMsg
                }
            }
            TestScript = {
                $returnValue = $false
                try
                {
                    $Name = 'SQLAOAG'
                    $cluster = Get-Cluster -Name $Name
            
                    Write-Verbose -Message ('Checking if cluster {0} is present.' -f $Name)
            
                    if ($cluster)
                    {
                        $targetNodeName = $env:COMPUTERNAME
            
                        Write-Verbose -Message ('Checking if the node {0} is a member of the cluster {1}, and so that node status is Up.' -f $targetNodeName, $Name)
            
                        $allNodes = Get-ClusterNode -Cluster $Name
            
                        foreach ($node in $allNodes)
                        {
                            if ($node.Name -eq $targetNodeName)
                            {
                                if ($node.State -eq 'Up')
                                {
                                    $returnValue = $true
                                }
                                else
                                {
                                    Write-Verbose -Message ('Node {0} is in the cluster {1} but the status is not Up. Node will be treated as NOT being a member of the cluster {1}.' -f $targetNodeName, $Name)
                                }
            
                                break
                            }
                        }
            
                        if ($returnValue)
                        {
                            Write-Verbose -Message ('Cluster {0} is present.' -f $targetNodeName, $Name)
                        }
                        else
                        {
                            Write-Verbose -Message ('Cluster {0} is NOT present.' -f $targetNodeName, $Name)
                        }
                    }
                }
                catch
                {
                    Write-Verbose -Message ('Cluster {0} is NOT present with error: {1}' -f $Name, $_.Message)
                }

                return $returnValue
            }
            GetScript = { @{ Result = '' } }
            DependsOn = '[WindowsFeature]AddRemoteServerAdministrationToolsClusteringCmdInterfaceFeature'
        }

        Script EnableAvailabilityGroup
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

    Node $AllNodes.Where{ $_.Role -eq 'AdditionalServerNode' }.NodeName
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

        Script WaitForCluster
        {
            SetScript = {
                $Name = 'SQLAOAG'
                $RetryIntervalSec = 10
                $RetryCount = 50
                
                $clusterFound = $false
                
                    Write-Verbose -Message ('Checking if cluster {0} is present.' -f $Name)

                    for ($count = 0; $count -lt $RetryCount; $count++)
                    {
                        try
                        {
                            $computerObject = Get-CimInstance -ClassName Win32_ComputerSystem
                            if ($null -eq $computerObject)
                            {
                                Write-Verbose -Message 'Cannot find the target node name.'
                                break
                            }

                            $cluster = Get-Cluster -Name $Name

                            if ($null -ne $cluster)
                            {
                                Write-Verbose -Message ('Cluster {0} is present.' -f $Name)
                                $clusterFound = $true
                                break
                            }
                        }
                        catch
                        {
                            Write-Verbose -Message ('Cluster {0} is NOT present. Will retry again after {1} seconds.' -f $Name, $RetryIntervalSec)
                        }

                        Write-Verbose -Message ('Cluster {0} is NOT present. Will retry again after {1} seconds.' -f $Name, $RetryIntervalSec)
                        Start-Sleep -Seconds $RetryIntervalSec
                    }

                    if (-not $clusterFound)
                    {
                        $errorMessage = 'Failover cluster {0} was not found after {1} attempts with {2} seconds interval.' -f $Name, $count, $RetryIntervalSec
                        New-InvalidOperationException -Message $errorMessage
                    }
            }
            TestScript = {
                $Name = 'SQLAOAG'

                Write-Verbose -Message ('Evaluating if cluster {0} is present.' -f $Name)
                
                    $testTargetResourceReturnValue = $false
                
                    try
                    {
                        $computerObject = Get-CimInstance -ClassName Win32_ComputerSystem
                        if ($null -eq $computerObject)
                        {
                            Write-Verbose -Message ' Cannot find the target node.'
                        }
                        else
                        {
                            $cluster = Get-Cluster -Name $Name
                            if ($null -eq $cluster)
                            {
                                Write-Verbose -Message ('Cluster {0} is NOT present.' -f $Name)
                            }
                            else
                            {
                                Write-Verbose -Message ('Cluster {0} is present.' -f $Name)
                                $testTargetResourceReturnValue = $true
                            }
                        }
                    }
                    catch
                    {
                        Write-Verbose -Message ('Cluster {0} is NOT present with error: {1}.' -f $Name, $_.Message)
                    }
                
                    return $testTargetResourceReturnValue
            }
            GetScript = { @{ Result = (Get-Cluster | Format-List) } }
            DependsOn = '[WindowsFeature]AddRemoteServerAdministrationToolsClusteringCmdInterfaceFeature'
        }

        Script JoinSecondNodeToCluster
        {
            SetScript =
            {
                try {
                    # New-Cluster -Name 'SQLAOAG' -Node sqlao-vm1, sqlao-vm2 -StaticAddress '172.18.0.100/24' -AdministrativeAccessPoint Dns
                    New-Cluster -Name 'SQLAOAG' -Node $env:COMPUTERNAME -StaticAddress '172.18.0.100/24' -AdministrativeAccessPoint Dns
                } catch
                {
                    $ErrorMsg = $_.Exception.Message
                    Write-Verbose -Verbose $ErrorMsg
                }
            }
            TestScript = {
                $returnValue = $false
                try
                {
                    $Name = 'SQLAOAG'
                    $cluster = Get-Cluster -Name $Name
            
                    Write-Verbose -Message ('Checking if cluster {0} is present.' -f $Name)
            
                    if ($cluster)
                    {
                        $targetNodeName = $env:COMPUTERNAME
            
                        Write-Verbose -Message ('Checking if the node {0} is a member of the cluster {1}, and so that node status is Up.' -f $targetNodeName, $Name)
            
                        $allNodes = Get-ClusterNode -Cluster $Name
            
                        foreach ($node in $allNodes)
                        {
                            if ($node.Name -eq $targetNodeName)
                            {
                                if ($node.State -eq 'Up')
                                {
                                    $returnValue = $true
                                }
                                else
                                {
                                    Write-Verbose -Message ('Node {0} is in the cluster {1} but the status is not Up. Node will be treated as NOT being a member of the cluster {1}.' -f $targetNodeName, $Name)
                                }
            
                                break
                            }
                        }
            
                        if ($returnValue)
                        {
                            Write-Verbose -Message ('Cluster {0} is present.' -f $targetNodeName, $Name)
                        }
                        else
                        {
                            Write-Verbose -Message ('Cluster {0} is NOT present.' -f $targetNodeName, $Name)
                        }
                    }
                }
                catch
                {
                    Write-Verbose -Message ('Cluster {0} is NOT present with error: {1}' -f $Name, $_.Message)
                }

                return $returnValue
            }
            GetScript = { @{ Result = (Get-Cluster | Format-List) } }
            DependsOn                     = '[Script]WaitForCluster'
        }

        Script EnableAvailabilityGroup
        {
            SetScript =
            {
                Enable-SqlAlwaysOn -Path "SQLSERVER:\SQL\localhost\DEFAULT" -Force
            }
            TestScript = {
                return $false
            }
            GetScript = { @{ Result = (Get-Cluster | Format-List) } }
            DependsOn = '[Script]JoinSecondNodeToCluster'
        }
    }
}

SimplifiedSQLSA -ConfigurationData .\ConfigData.psd1
Start-DscConfiguration -Path .\SimplifiedSQLSA -Verbose -Wait -Force