Add-Type -AssemblyName System.Windows.Forms

Import-Module dbatools

# --- Form ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "SQL Database Attach Tool"
$form.ClientSize = '500, 260'
$form.StartPosition = "CenterScreen"

# --- SQL Instance input ---
$lblSql = New-Object System.Windows.Forms.Label
$lblSql.Text = "SQL Instance:"
$lblSql.Location = '10, 20'
$form.Controls.Add($lblSql)

$txtSql = New-Object System.Windows.Forms.TextBox
$txtSql.Text = 'localhost'
$txtSql.Location = '120, 18'
$txtSql.Size = '340, 20'
$form.Controls.Add($txtSql)

# --- File Path ---
$lblPath = New-Object System.Windows.Forms.Label
$lblPath.Text = "Data Folder:"
$lblPath.Location = '10, 60'
$form.Controls.Add($lblPath)

$txtPath = New-Object System.Windows.Forms.TextBox
$txtPath.Location = '120, 58'
$txtPath.Size = '260, 20'
$form.Controls.Add($txtPath)

$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Text = "Browse"
$btnBrowse.Location = '390, 56'
$form.Controls.Add($btnBrowse)

#  --- Status Box ---
$txtStatus = New-Object System.Windows.Forms.TextBox
$txtStatus.Location = '10, 130'
$txtStatus.Size = '450, 80'
$txtStatus.Multiline = $true
$txtStatus.ScrollBars = "Vertical"
$form.Controls.Add($txtStatus)

# --- Check Button ---
$btnCheck = New-Object System.Windows.Forms.Button
$btnCheck.Text = "Check Databases"
$btnCheck.Location = '120, 95'
$form.Controls.Add($btnCheck)

# --- Run Button ---
$btnRun = New-Object System.Windows.Forms.Button
$btnRun.Text = "Attach Databases"
$btnRun.Location = '200, 95'
$btnRun.Enabled = $false
$form.Controls.Add($btnRun)

# --- Folder Browser ---
$folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog

$btnBrowse.Add_Click({
    if ($folderDialog.ShowDialog() -eq 'OK') {
        $txtPath.Text = $folderDialog.SelectedPath
    }
})

# --- Run Logic ---
function Get-OrphanedDatabases {
    param (
        [string]$SqlInstance,
        [string]$FilePath,
        [System.Windows.Forms.TextBox]$StatusBox
    )

    $StatusBox.AppendText("Scanning orphaned files... `r`n")

    $orphanedFiles = Find-DbaOrphanedFile -SqlInstance $SqlInstance -Path $FilePath
    if (-not $orphanedFiles) { return @() }

    $normalizedFiles = foreach ($file in $orphanedFiles) {
        $fileNameNoExt = [System.IO.Path]::GetFileNameWithoutExtension($file.Filename)
        $baseName = $fileNameNoExt -replace '_log$', ''

        [pscustomobject]@{
            BaseName = $baseName
            Path = $file.Filename
        }
    }

    $normalizedFiles | Group-Object BaseName | ForEach-Object {
        [pscustomobject]@{
            Name  = $_.Name
            Files = $_.Group.Path
        }
    }
}

$script:Databases = @()

$btnCheck.Add_Click({
    try {
        $txtStatus.Clear()
        $btnRun.Enabled = $false

        $script:Databases = Get-OrphanedDatabases -SqlInstance $txtSql.Text -FilePath $txtPath.Text -StatusBox $txtStatus

        if ($script:Databases.Count -eq 0) {
            $txtStatus.AppendText("No free databases were found.`r`n")
            return
        }
        $txtStatus.AppendText("Found $($script:Databases.Count) free databases.`r`n")
        $btnRun.Enabled = $true
    }
    catch {
        $txtStatus.AppendText("ERROR: $_)`r`n")
        $btnRun.Enabled = $false
    }
})

$btnRun.Add_Click({
    try {
        if (-not $script:Databases -or $script:Databases.Count -eq 0) {
            $txtStatus.AppendText("No free databases were found. Run Check first.`r`n")
            return
        }

        $btnRun.Enabled = $false
        $txtStatus.AppendText("Attaching $($script:Databases.Count) databases...`r`n")

        foreach ($db in $script:Databases) {
            Mount-DbaDatabase -SqlInstance $txtSql.Text -Database $db.Name -FileStructure $db.Files

            $txtStatus.AppendText("Attached $($db.Name)`r`n")
        }
        $txtStatus.AppendText("Done.")
    }
    catch {
        $txtStatus.AppendText("ERROR: $_`r`n")
        $btnRun.Enabled = $true
    }
})

$form.ShowDialog()

$form.Dispose()