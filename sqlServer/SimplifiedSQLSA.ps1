Configuration SimplifiedSQLSA
{
     Import-DscResource -ModuleName PSDesiredStateConfiguration, xStorage, xSQLServer
     node localhost
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
            ImagePath   = 'C:\SQLInstall\[use-correct-name:sqlsetup.iso]'
            DriveLetter = 'F'
        }

        xWaitForVolume WaitForISO
        {
            DriveLetter      = 'F'
            RetryIntervalSec = 5
            RetryCount       = 10
        }  
        
        WindowsFeature 'NetFramework45'
          {
               Name = 'NET-Framework-45-Core'
               Ensure = 'Present'
          }

          xSQLServerSetup 'InstallDefaultInstance'
          {
               InstanceName = 'MSSQLSERVER'
               Features = 'SQLENGINE'
               SourcePath = 'F:\'
               SQLSysAdminAccounts = @('Administrators')
               DependsOn = '[WindowsFeature]NetFramework45'
          }
     }
}

SimplifiedSQLSA
Start-DscConfiguration -Path .\SimplifiedSQLSA -Verbose -Wait -Force