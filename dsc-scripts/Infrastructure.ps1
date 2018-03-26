Configuration Infrastructure
{
    Param(
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$AdminCreds,

        [Parameter(Mandatory)]
        [string]$DomainName
    )

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
            PsDscRunAsCredential = $AdminCreds
            DependsOn = '[WindowsFeature]DnsToolsFeature'
        }

        Registry SetDomain #ResourceName
        {
            Key = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\'
            ValueName = 'Domain'
            Ensure = 'Present'
            Force =  $true
            DependsOn = '[xDnsServerPrimaryZone]PrimaryZone'
            ValueData = $DomainName
            ValueType = 'String'
        }
        Registry SetNVDomain #ResourceName
        {
            Key = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\'
            ValueName = 'NV Domain'
            Ensure = 'Present'
            Force =  $true
            DependsOn = '[Registry]SetDomain'
            ValueData = $DomainName
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
            ActionAfterReboot = "ContinueConfiguration"
        }
    }
}