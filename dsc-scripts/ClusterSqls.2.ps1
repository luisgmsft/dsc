Configuration ClusterSqls2
{
    Param(
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$AdminCreds
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration, SqlServerDsc

    Node localhost
    {
        SqlScript 'Secondary-Step-3' {
            ServerInstance = 'sqlao2'
            SetFilePath = 'c:\TempDSCAssets\node2-step-3.sql'
            TestFilePath = 'c:\TempDSCAssets\dummy-for-all-tests.sql'
            GetFilePath = 'c:\TempDSCAssets\dummy-for-all-tests.sql'

            PsDscRunAsCredential = $AdminCreds
        }
    }
}