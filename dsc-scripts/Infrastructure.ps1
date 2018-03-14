Configuration Infrastructure
{
    Param(
        [string]$safeModePassword = "test$!Passw0rd111"
    )

    $pw = ConvertTo-SecureString $safeModePassword -AsPlainText -Force
    [System.Management.Automation.PSCredential]$cred = New-Object System.Management.Automation.PSCredential (".\testadminuser",$pw)
    $dnsSuffix = "lugizi.ao.contoso.com"

    Import-DscResource -ModuleName PSDesiredStateConfiguration, xDnsServer

    Node localhost
    {
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

        LocalConfigurationManager
        {
            RebootNodeIfNeeded = $true
        }
    }
}