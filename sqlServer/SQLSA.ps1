#requires -Version 5

[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingConvertToSecureStringWithPlainText", "")]
param ()

Configuration SQLSA
{
    Import-DscResource -Module 'PSDesiredStateConfiguration', 'xStorage', 'xSQLServer'
    
#    xMountImage ISO
#    {
#        ImagePath   = 'c:\dsc\sql_server_2016_developer_with_sp1_x64.iso'
#        DriveLetter = 'F'
#    }

#    xWaitForVolume WaitForISO
#    {
#        DriveLetter      = 'F'
#        RetryIntervalSec = 5
#        RetryCount       = 10
#    }
    
    Node $AllNodes.NodeName
    {
        LocalConfigurationManager
        {
            DebugMode = "ForceModuleImport"
            RebootNodeIfNeeded = $true
        }

        WindowsFeature "NET-Framework-Core"
        {
            Ensure = "Present"
            Name = "NET-Framework-Core"
        }

        # Install SQL Instances
        foreach($SQLServer in $Node.SQLServers)
        {
            $SQLInstanceName = $SQLServer.InstanceName

            # $Features = "SQLENGINE,FULLTEXT,RS,AS,IS"
            $Features = "SQLENGINE,FULLTEXT"

            xSqlServerSetup ($Node.NodeName + $SQLInstanceName)
            {
                DependsOn = "[WindowsFeature]NET-Framework-Core"
                SourcePath = $Node.SourcePath
                InstanceName = $SQLInstanceName
                Features = $Features
                SQLSysAdminAccounts = $Node.AdminAccount
                InstallSharedDir = "C:\Program Files\Microsoft SQL Server"
                InstallSharedWOWDir = "C:\Program Files (x86)\Microsoft SQL Server"
                InstanceDir = "C:\Program Files\Microsoft SQL Server"
                InstallSQLDataDir = "C:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\Data"
                SQLUserDBDir = "C:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\Data"
                SQLUserDBLogDir = "C:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\Data"
                SQLTempDBDir = "C:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\Data"
                SQLTempDBLogDir = "C:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\Data"
                SQLBackupDir = "C:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\Data"
                ASDataDir = "C:\Program Files\Microsoft SQL Server\MSAS11.MSSQLSERVER\OLAP\Data"
                ASLogDir = "C:\Program Files\Microsoft SQL Server\MSAS11.MSSQLSERVER\OLAP\Log"
                ASBackupDir = "C:\Program Files\Microsoft SQL Server\MSAS11.MSSQLSERVER\OLAP\Backup"
                ASTempDir = "C:\Program Files\Microsoft SQL Server\MSAS11.MSSQLSERVER\OLAP\Temp"
                ASConfigDir = "C:\Program Files\Microsoft SQL Server\MSAS11.MSSQLSERVER\OLAP\Config"
            }

            xSqlServerFirewall ($Node.NodeName + $SQLInstanceName)
            {
                DependsOn = ("[xSqlServerSetup]" + $Node.NodeName + $SQLInstanceName)
                SourcePath = $Node.SourcePath
                InstanceName = $SQLInstanceName
                Features = $Features
            }
        }

#        xSqlServerSetup "SQLMT"
#        {
#            DependsOn = "[WindowsFeature]NET-Framework-Core"
#            SourcePath = $Node.SourcePath
#            InstanceName = "NULL"
#            Features = "SSMS,ADV_SSMS"
#        }
    } 
}

$LocalSystemAccount = $InstallerServiceAccount = Get-Credential "superuser"

$ConfigurationData = @{
    AllNodes = @(
        @{
            NodeName = "localhost"
            PSDscAllowPlainTextPassword = $true

            SourcePath = "F:\"
            InstallerServiceAccount = $InstallerServiceAccount
            LocalSystemAccount = $LocalSystemAccount

            AdminAccount = "superuser"
            #######################
            SQLServers = @(
                @{
                    InstanceName = "MSSQLSERVER"
                }
            )
            Roles = @("SQL Server 2012 Management Tools")
        }
    )
}

#foreach($Node in $ConfigurationData.AllNodes)
#{
#    if($Node.NodeName -ne "*")
#    {
#        Start-Process -FilePath "robocopy.exe" -ArgumentList ("`"C:\Program Files\WindowsPowerShell\Modules`" `"\\" + $Node.NodeName + "\c$\Program Files\WindowsPowerShell\Modules`" /e /purge /xf") -NoNewWindow -Wait
#    }
#}

SQLSA -ConfigurationData $ConfigurationData
# Set-DscLocalConfigurationManager -Path .\SQLSA -Verbose
Start-DscConfiguration -Path .\SQLSA -Verbose -Wait -Force