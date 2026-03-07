# Modules/RosterTools/RosterTools.psm1

# Dot-source all public functions
Get-ChildItem -Path $PSScriptRoot\Public -Filter *.ps1 -File | ForEach-Object {
    . $_.FullName
}

# Dot-source all private helpers (optional)
if (Test-Path "$PSScriptRoot\Private") {
    Get-ChildItem -Path $PSScriptRoot\Private -Filter *.ps1 -File | ForEach-Object {
        . $_.FullName
    }
}

# Export only the public functions
Export-ModuleMember -Function (Get-ChildItem -Path $PSScriptRoot\Public -Filter *.ps1 -File |
    ForEach-Object { $_.BaseName })

