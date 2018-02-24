Configuration Infrastructure
{
    Param(
        [string]$safeModePassword = "test$!Passw0rd111"
    )
    Import-DscResource -ModuleName PSDesiredStateConfiguration, xDnsServer

    Node localhost
    {
        $pw = convertto-securestring $safeModePassword -AsPlainText -Force
        $cred = new-object -typename System.Management.Automation.PSCredential -argumentlist ".\testadminuser",$pw

        WindowsFeature DnsFeature
        {
            Ensure = "Present" 
            Name = "DNS"
        }

        WindowsFeature DnsToolsFeature
        {
            Ensure = "Present" 
            Name = "RSAT-DNS-Server"
            DependsOn = '[WindowsFeature]DnsFeature'
        }

        xDnsServerPrimaryZone PrimaryZone
        {
            Name = 'lugizi.ao.contoso.com'
            Ensure = 'Present'
            DynamicUpdate = 'NonsecureAndSecure'
            PsDscRunAsCredential = $cred
            DependsOn = '[WindowsFeature]DnsToolsFeature'
        }

        $dnsSuffix = "lugizi.ao.contoso.com"

        Registry SetDomain #ResourceName
        {
            Key = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\'
            ValueName = 'Domain'
            Ensure = 'Present'
            Force =  $true
            DependsOn = '[xDnsServerPrimaryZone]PrimaryZone'
            ValueData = $dnsSuffix
            ValueType = 'String'
        }
        Registry SetNVDomain #ResourceName
        {
            Key = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\'
            ValueName = 'NV Domain'
            Ensure = 'Present'
            Force =  $true
            DependsOn = '[Registry]SetDomain'
            ValueData = $dnsSuffix
            ValueType = 'String'
        }

        LocalConfigurationManager
        {
            RebootNodeIfNeeded = $true
        }

        Script Reboot
        {
            TestScript = {
                return (Test-Path HKLM:\SOFTWARE\MyMainKey\RebootKey)
            }
            SetScript = {
                New-Item -Path HKLM:\SOFTWARE\MyMainKey\RebootKey -Force
                 $global:DSCMachineStatus = 1 
    
            }
            GetScript = { return @{result = 'result'}}
            DependsOn = '[Registry]SetNVDomain'
        }
    }
}