Configuration ClusterNode1
{
    Param(
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$AdminCreds
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration, xStorage, xNetworking, SqlServerDsc, xComputerManagement
    
    Node localhost
    {
        Script WaitForPingToKickIn
        {
            PsDscRunAsCredential = $AdminCreds
            SetScript =
            {
                DO
                {
                    start-sleep 10
                    $Ping = Test-Connection 'sqlao2' -quiet
                }
                Until ($Ping -contains "True")
            }
            TestScript = {
                return $false
            }
            GetScript = { @{ Result = '' } }
        }
        
        Script CreateWindowsCluster
        {
            PsDscRunAsCredential = $AdminCreds
            SetScript =
            {
                New-Cluster -Name 'sqlaocl' -Node 'sqlao1','sqlao2' -StaticAddress '172.18.0.100' -AdministrativeAccessPoint Dns
            }
            TestScript = {
                return $false
            }
            GetScript = { @{ Result = '' } }
            DependsOn = '[Script]WaitForPingToKickIn'
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
            PsDscRunAsCredential = $AdminCreds
        }
    }
}