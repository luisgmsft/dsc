Configuration ClusterNode2
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
                    $Ping = Test-Connection 'sqlao1' -quiet
                }
                Until ($Ping -contains "True")
            }
            TestScript = {
                return $false
            }
            GetScript = { @{ Result = '' } }
        }
        
        Script EnableAvailabilityGroupOnSecondary
        {
            SetScript = {
                Enable-SqlAlwaysOn -Path "SQLSERVER:\SQL\localhost\DEFAULT" -Force
            }
            TestScript = {
                return $false
            }
            GetScript = { @{ Result = (Get-Cluster | Format-List) } }
            PsDscRunAsCredential = $AdminCreds
            DependsOn = '[Script]WaitForPingToKickIn'
        }
    }
}