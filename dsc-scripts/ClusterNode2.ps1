Configuration ClusterNode2
{
    Param(
        [String]$safeModePassword = "test$!Passw0rd111"
    )

    $pw = ConvertTo-SecureString $safeModePassword -AsPlainText -Force
    [System.Management.Automation.PSCredential]$cred = New-Object System.Management.Automation.PSCredential (".\testadminuser",$pw)
    $dnsSuffix = "lugizi.ao.contoso.com"

    Import-DscResource -ModuleName PSDesiredStateConfiguration, xStorage, xNetworking, SqlServerDsc, xComputerManagement

    Node localhost
    {
        #if ($env:COMPUTERNAME -eq 'sqlao2') {
            # WaitForAll ClusterSetup
            # {
            #     ResourceName      = '[Script]CreateWindowsCluster'
            #     NodeName          = 'sqlao1'
            #     RetryIntervalSec  = 15
            #     RetryCount        = 30
            # }
            
            Script EnableAvailabilityGroupOnSecondary
            {
                SetScript = {
                    Enable-SqlAlwaysOn -Path "SQLSERVER:\SQL\localhost\DEFAULT" -Force
                }
                TestScript = {
                    return $false
                }
                GetScript = { @{ Result = (Get-Cluster | Format-List) } }
                PsDscRunAsCredential = $cred
                DependsOn = '[WaitForAll]ClusterSetup'
            }
        # }
    }
}