Configuration ClusterSqls
{
    Param(
        [String]$safeModePassword = "test$!Passw0rd111"
    )

    $pw = ConvertTo-SecureString $safeModePassword -AsPlainText -Force
    [System.Management.Automation.PSCredential]$cred = New-Object System.Management.Automation.PSCredential (".\testadminuser",$pw)
    
    Import-DscResource -ModuleName PSDesiredStateConfiguration, SqlServerDsc

    Node localhost
    {
        if ($env:COMPUTERNAME -eq 'sqlao1')
        {
            SqlScript 'Primary-Step-1' {
                ServerInstance = 'sqlao1'
                SetFilePath = 'c:\TempDSCAssets\node1-step-1.sql'
                TestFilePath = 'c:\TempDSCAssets\dummy-for-all-tests.sql'
                GetFilePath = 'c:\TempDSCAssets\dummy-for-all-tests.sql'

                PsDscRunAsCredential = $cred
            }
        }

        if ($env:COMPUTERNAME -eq 'sqlao2')
        {
            SqlScript 'Secondary-Step-1' {
                ServerInstance = 'sqlao2'
                SetFilePath = 'c:\TempDSCAssets\node2-step-1.sql'
                TestFilePath = 'c:\TempDSCAssets\dummy-for-all-tests.sql'
                GetFilePath = 'c:\TempDSCAssets\dummy-for-all-tests.sql'

                PsDscRunAsCredential = $cred
            }
        }
    }

    Node localhost
    {
        if ($env:COMPUTERNAME -eq 'sqlao1')
        {
            SqlScript 'Primary-Step-2' {
                ServerInstance = 'sqlao1'
                SetFilePath = 'c:\TempDSCAssets\node1-step-2.sql'
                TestFilePath = 'c:\TempDSCAssets\dummy-for-all-tests.sql'
                GetFilePath = 'c:\TempDSCAssets\dummy-for-all-tests.sql'

                PsDscRunAsCredential = $cred
                DependsOn = '[SqlScript]Primary-Step-1'
            }
        }

        if ($env:COMPUTERNAME -eq 'sqlao2')
        {
            SqlScript 'Secondary-Step-2' {
                ServerInstance = 'sqlao2'
                SetFilePath = 'c:\TempDSCAssets\node2-step-2.sql'
                TestFilePath = 'c:\TempDSCAssets\dummy-for-all-tests.sql'
                GetFilePath = 'c:\TempDSCAssets\dummy-for-all-tests.sql'

                PsDscRunAsCredential = $cred
                DependsOn = '[SqlScript]Secondary-Step-1'
            }
        }
    }
}