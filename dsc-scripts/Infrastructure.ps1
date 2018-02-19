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

        # Script SetDNSSuffix
        # {
        #     SetScript = {
        #         $adapter=Get-WmiObject Win32_NetworkAdapterConfiguration -filter 'index=0'
        #         $adapter.SetDNSDomain('lugizi.ao.contoso.com')
        #     }
        #     TestScript = {
        #         return $false
        #     }
        #     GetScript = { @{ Result = '' }}
        #     PsDscRunAsCredential = $cred
        #     DependsOn = '[xDnsServerPrimaryZone]PrimaryZone'
        # }
    }
}