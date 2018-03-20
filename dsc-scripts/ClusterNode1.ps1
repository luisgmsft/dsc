Configuration ClusterNode1
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
        #if ($env:COMPUTERNAME -eq 'sqlao1') {
            # WaitForAll Reboot
            # {
            #     ResourceName      = '[Script]DNSReboot'
            #     NodeName          = 'sqlao1','sqlao2'
            #     RetryIntervalSec  = 15
            #     RetryCount        = 30
            # }
            
            Script CreateWindowsCluster
            {
                PsDscRunAsCredential = $cred
                SetScript =
                {
                    New-Cluster -Name 'sqlaocl' -Node 'sqlao1','sqlao2' -StaticAddress '172.18.0.100' -AdministrativeAccessPoint Dns
                }
                TestScript = {
                    return $false
                }
                GetScript = { @{ Result = '' } }
                # DependsOn = '[WaitForAll]Reboot'
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
                PsDscRunAsCredential = $cred
            }
        # }
    }
}