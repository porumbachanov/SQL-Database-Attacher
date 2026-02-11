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

$databases = foreach ($db in $groupedDatabases) {
    [pscustomobject]@{
        Name  = $db.Name
        Files = $db.Group.Path
    }
}

Write-Output $databases

# $dbCount = $databases.Count

# if ($dbCount -eq 0) {
#     Write-Output "No free databases were found."
# } else {
#     Write-Output "Found $dbCount free databases"
#     foreach ($db in $databases) {
#         Mount-DbaDatabase -SqlInstance $SqlInstance -Database $db.Name -FileStructure $db.Files
#     }
# }