#
# Module manifest for module 'LogApe'
#

@{

    # Script module or binary module file associated with this manifest
    RootModule           = 'LogApe.psm1'

    # Version number of this module
    ModuleVersion        = '1.0.0'

    # ID used to uniquely identify this module
    GUID                 = 'ea285917-17d8-4cbf-aa7f-ce3e9714c50e'

    # Author of this module
    Author               = 'Schuster, Claudiu (ClaudiuSchuster)'

    # Company or vendor of this module
    CompanyName          = 'claudiuschuster.de'

    # Copyright statement for this module
    Copyright            = 'GPL v3'

    # Description of the functionality provided by this module
    Description          = 'LogApe - Provides advanced logging functionalities with ease of use'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion    = '7.0'

    # Supported PSEditions
    CompatiblePSEditions = 'Core'

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport    = @( 'New-LogApe' )

    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport      = @()

    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport      = @()

    # Variables to export from this module
    VariablesToExport    = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData          = @{ PSData = @{} }

}
