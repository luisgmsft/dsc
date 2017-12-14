@{
    AllNodes = @(
        @{
            NodeName = 'localhost'
            PsDscAllowPlainTextPassword = $true
        }
        # Node01 - First cluster node.
        @{
            # Replace with the name of the actual target node.
            NodeName = 'sqlao1'
            
            # This is used in the configuration to know which resource to compile.
            Role     = 'FirstServerNode'
        },

        # Node02 - Second cluster node
        @{
            # Replace with the name of the actual target node.
            NodeName = 'sqlao2'

            # This is used in the configuration to know which resource to compile.
            Role     = 'AdditionalServerNode'
        }
    )
}