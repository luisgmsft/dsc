Configuration ClusterSqls1
{
    Param(
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$AdminCreds
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration, SqlServerDsc

    Node localhost
    {
        SqlScript 'Primary-Step-3' {
            ServerInstance = 'sqlao1'
            SetFilePath = 'c:\TempDSCAssets\node1-step-3.sql'
            TestFilePath = 'c:\TempDSCAssets\dummy-for-all-tests.sql'
            GetFilePath = 'c:\TempDSCAssets\dummy-for-all-tests.sql'

            PsDscRunAsCredential = $AdminCreds
        }
    }
}