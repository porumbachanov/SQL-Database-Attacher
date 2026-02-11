Import-Module dbatools

$SqlInstance = 'localhost'
$FilePath = 'D:\Work\Microinvest\DB\BAZI'

$orphanedFiles = Find-DbaOrphanedFile -SqlInstance $SqlInstance -Path $FilePath

$normalizedFiles = foreach ($file in $orphanedFiles) {
    $fileNameNoExt = [System.IO.Path]::GetFileNameWithoutExtension($file.Filename)
    $baseName = $fileNameNoExt -replace '_log$', ''

    [pscustomobject]@{
        BaseName = $baseName
        FileType = [System.IO.Path]::GetExtension($file.Filename)
        Path = $file.Filename
    }
}

$groupedDatabases = $normalizedFiles | Group-Object BaseName

$dbCount = $groupedDatabases.Count

if ($dbCount -eq 0) {
    Write-Output "No free databases were found."
} else {
    Write-Output "Found $dbCount free databases"
    foreach ($db in $groupedDatabases) {
        Write-Output "Attaching $($db.Name)"
        Mount-DbaDatabase -SqlInstance $SqlInstance -Database $db.Name -FileStructure $db.Group.Path
    }
}