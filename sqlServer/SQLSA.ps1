#requires -Version 5

[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingConvertToSecureStringWithPlainText", "")]
param ()

Configuration SQLSA
{
    Import-DscResource -Module 'PSDesiredStateConfiguration', 'xStorage', 'xSQLServer'

    Node $AllNodes.NodeName
    {
        Script GetISO
        {
            SetScript =
            {
                $webClient = New-Object System.Net.WebClient
                $uri = New-Object System.Uri "https://raw.githubusercontent.com/luisgmsft/dsc/master/isos/setup.txt.iso"
                $webClient.DownloadFile($uri, "C:\SQLInstall\sqlsetup.iso")
            }
            TestScript = { Test-Path "C:\SQLInstall\sqlsetup.iso" }
            GetScript = { @{ Result = (Get-Content "C:\SQLInstall\sqlsetup.iso") } }
        }

        xMountImage ISO
        {
            ImagePath   = 'C:\SQLInstall\[replace:sqlsetup.iso]'
            DriveLetter = 'F'
        }

        xWaitForVolume WaitForISO
        {
            DriveLetter      = 'F'
            RetryIntervalSec = 5
            RetryCount       = 10
        }

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

SQLSA -ConfigurationData $ConfigurationData
Start-DscConfiguration -Path .\SQLSA -Verbose -Wait -Force