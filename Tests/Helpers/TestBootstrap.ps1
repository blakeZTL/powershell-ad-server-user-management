Set-StrictMode -Version Latest

$here = Split-Path -Parent $PSCommandPath
$repoRoot = Resolve-Path (Join-Path $here "..\..") | Select-Object -ExpandProperty Path

function Import-ProjectModule {
    param(
        [Parameter(Mandatory)]
        [string] $ModuleName
    )

    $moduleFolder = Join-Path $repoRoot "Modules\$ModuleName"
    if (-not (Test-Path $moduleFolder)) {
        throw "Module folder not found: $moduleFolder"
    }

    $manifest = Join-Path $moduleFolder "$ModuleName.psd1"
    $psm1 = Join-Path $moduleFolder "$ModuleName.psm1"

    $importPath =
    if (Test-Path $manifest) { $manifest }
    elseif (Test-Path $psm1) { $psm1 }
    else { throw "Neither manifest nor psm1 found for module '$ModuleName' in $moduleFolder" }

    # Remove already-loaded module with same name
    Remove-Module $ModuleName -Force -ErrorAction SilentlyContinue

    # Import local module by path
    Import-Module $importPath -Force -ErrorAction Stop

    # Sanity check: ensure the module name matches what tests expect
    if (-not (Get-Module $ModuleName)) {
        $loaded = Get-Module | Where-Object { $_.Path -eq $importPath } | Select-Object -First 1
        if ($loaded) {
            throw "Module imported from path, but loaded as '$($loaded.Name)'. Your tests should use InModuleScope '$($loaded.Name)' instead of '$ModuleName'."
        }

        throw "Module import completed but module '$ModuleName' is not in Get-Module output. ImportPath: $importPath"
    }
}

$script:RepoRoot = $repoRoot