@{
    AllNodes = @(
        @{
            NodeName = 'localhost'
            PsDscAllowPlainTextPassword = $true
        },

        @{
            NodeName    = 'sqlao1'
            FeatureName = 'Always-On-Node1'
            PsDscAllowPlainTextPassword = $true
        },

        @{
            NodeName    = 'sqlao2'
            FeatureName = 'Always-On-Node2'
            PsDscAllowPlainTextPassword = $true
        }
    )
}