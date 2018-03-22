Configuration ClusterSqls2
{
    Param(
        [String]$safeModePassword = "test$!Passw0rd111"
    )

    $pw = ConvertTo-SecureString $safeModePassword -AsPlainText -Force
    [System.Management.Automation.PSCredential]$cred = New-Object System.Management.Automation.PSCredential (".\testadminuser",$pw)
    
    Import-DscResource -ModuleName PSDesiredStateConfiguration, SqlServerDsc

    Node localhost
    {
        SqlScript 'Secondary-Step-3' {
            ServerInstance = 'sqlao2'
            SetFilePath = 'c:\TempDSCAssets\node2-step-3.sql'
            TestFilePath = 'c:\TempDSCAssets\dummy-for-all-tests.sql'
            GetFilePath = 'c:\TempDSCAssets\dummy-for-all-tests.sql'

            PsDscRunAsCredential = $cred
            #DependsOn = '[SqlScript]Secondary-Step-2'
        }
    }
}