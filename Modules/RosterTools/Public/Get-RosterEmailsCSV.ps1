function Get-RosterEmailsCSV {
    [CmdletBinding(DefaultParameterSetName = 'None')]
    [OutputType([System.Collections.Generic.HashSet[string]])]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,

        [Parameter(Mandatory)]
        [string]$EmailColumnName,

        # CSV options (optional)
        [string]$Delimiter = ',',
        [ValidateSet("Unicode", "UTF7", "UTF8", "ASCII", "UTF32", "BigEndianUnicode", "Default", "OEM")]
        [string]$Encoding = "UTF8",

        # Generic optional row filter (most flexible)
        [Parameter(ParameterSetName = 'FilterScript')]
        [scriptblock]$Filter,

        # Convenience: job-series filter (matches your Where-Object example)
        [Parameter(ParameterSetName = 'JobSeries')]
        [string]$JobSeriesColumnName,

        [Parameter(ParameterSetName = 'JobSeries')]
        [string[]]$TargetJobSeries
    )

    if (-not (Test-Path -Path $FilePath)) {
        throw "File '$FilePath' not found."
    }

    $fileType = [System.IO.Path]::GetExtension($FilePath).ToLowerInvariant()
    if ($fileType -ne '.csv') {
        throw "Unsupported file type '$fileType'. Only .csv files are supported."
    }

    $targetEmails = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    # Prebuild set for fast membership checks when using JobSeries parameter set
    $targetJobSeriesSet = $null
    if ($PSCmdlet.ParameterSetName -eq 'JobSeries') {
        if ([string]::IsNullOrWhiteSpace($JobSeriesColumnName)) {
            throw "JobSeriesColumnName is required when using -TargetJobSeries."
        }
        if (-not $TargetJobSeries -or $TargetJobSeries.Count -eq 0) {
            throw "TargetJobSeries must contain at least one value."
        }

        $targetJobSeriesSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($s in $TargetJobSeries) {
            if (-not [string]::IsNullOrWhiteSpace($s)) { [void]$targetJobSeriesSet.Add($s.Trim()) }
        }
    }

    try {
        $rows = Import-Csv -Path $FilePath -Delimiter $Delimiter -Encoding $Encoding

        foreach ($row in $rows) {

            if (-not ($rows[0].PSObject.Properties.Name -contains $EmailColumnName)) {
                throw "CSV is missing required column '$EmailColumnName'."
            }

            # ----- Optional filtering -----
            if ($PSCmdlet.ParameterSetName -eq 'FilterScript') {
                # Filter must return $true to keep the row
                if (-not (& $Filter $row)) { continue }
            }
            elseif ($PSCmdlet.ParameterSetName -eq 'JobSeries') {
                $jsVal = $row.PSObject.Properties[$JobSeriesColumnName].Value
                if ($null -eq $jsVal) { continue }

                $js = $jsVal.ToString().Trim()
                if (-not $targetJobSeriesSet.Contains($js)) { continue }
            }

            # ----- Extract email safely (supports spaces in column names) -----
            $emailVal = $row.PSObject.Properties[$EmailColumnName].Value
            if ($null -eq $emailVal) { continue }

            $email = $emailVal.ToString().Trim()
            if ([string]::IsNullOrWhiteSpace($email)) { continue }

            [void]$targetEmails.Add($email)
        }
    }
    catch {
        throw "Failed to import CSV file '$FilePath': $($_.Exception.Message)"
    }

    return $targetEmails
}