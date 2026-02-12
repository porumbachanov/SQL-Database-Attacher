Add-Type -AssemblyName System.Windows.Forms
Import-Module dbatools

# --- Form Setup ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "SQL Database Attach Tool"
$form.ClientSize = '500, 300'
$form.StartPosition = "CenterScreen"

# --- SQL Instance Input ---
$lblSql = New-Object System.Windows.Forms.Label
$lblSql.Text = "SQL Instance:"
$lblSql.Location = '10, 20'
$form.Controls.Add($lblSql)

$txtSql = New-Object System.Windows.Forms.TextBox
$txtSql.Text = 'localhost'
$txtSql.Location = '120, 18'
$txtSql.Size = '340, 20'
$form.Controls.Add($txtSql)

# --- Folder Path ---
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

# --- Status Box ---
$txtStatus = New-Object System.Windows.Forms.TextBox
$txtStatus.Location = '10, 130'
$txtStatus.Size = '450, 140'
$txtStatus.Multiline = $true
$txtStatus.ScrollBars = "Vertical"
$form.Controls.Add($txtStatus)

# --- Buttons ---
$btnCheck = New-Object System.Windows.Forms.Button
$btnCheck.Text = "Check Databases"
$btnCheck.Location = '120, 95'
$form.Controls.Add($btnCheck)

$btnRun = New-Object System.Windows.Forms.Button
$btnRun.Text = "Attach Databases"
$btnRun.Location = '250, 95'
$btnRun.Enabled = $false
$form.Controls.Add($btnRun)

# --- Folder Browser Dialog ---
$folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
$btnBrowse.Add_Click({
    if ($folderDialog.ShowDialog() -eq 'OK') {
        $txtPath.Text = $folderDialog.SelectedPath
    }
})

$btnCheck.Add_Click({
    $txtStatus.Clear()
    $SqlInstance = $txtSql.Text
    $folderPath = $txtPath.Text

    if (-not (Test-Path $folderPath)) {
        $txtStatus.AppendText("Folder path does not exist.`r`n")
        return
    }

    $txtStatus.AppendText("Checking for unattached databases...`r`n")

    # --- Find orphaned files ---
    $orphanedFiles = Find-DbaOrphanedFile -SqlInstance $SqlInstance -Path $folderPath

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

    if ($groupedDatabases.Count -eq 0) {
        $txtStatus.AppendText("No free databases were found.")
        $btnRun.Enabled = $false
    } else {
        $txtStatus.AppendText("Found $($groupedDatabases.Count) unattached databases.`r`n")
        $btnRun.Enabled = $true
        $form.Tag = $groupedDatabases
    }
})

# --- Attach Databases Button ---
$btnRun.Add_Click({
    $SqlInstance = $txtSql.Text
    $groupedDatabases = $form.Tag

    if($null -ne $groupedDatabases) {
        $txtStatus.AppendText("Attaching databases...`r`n")
        foreach ($db in $groupedDatabases) {
            $txtStatus.AppendText("Attaching $($db.Name)...`r`n")
            $errors = @()
            $warnings = @()
            $result = Mount-DbaDatabase -SqlInstance $SqlInstance -Database $db.Name -FileStructure $db.Group.Path 3>&1 2>&1
            
            foreach ($item in $result) {
                if ($item -is [System.Management.Automation.ErrorRecord]) {
                    $errors += $item.Exception.Message
                }
                elseif ($item -is [System.Management.Automation.WarningRecord]) {
                    $warnings += $item.Message
                }
            }
            
            if ($errors.Count -gt 0) {
                $txtStatus.AppendText("Failed to attach $($db.Name): ERRORS - $($errors -join '; ')`r`n")
            }
            elseif ($warnings.Count -gt 0) {
                $txtStatus.AppendText("Failed to attach $($db.Name): WARNINGS - $($warnings -join '; ')`r`n")
            } else {
                $txtStatus.AppendText("Attached $($db.Name) successfully.`r`n")
            }
        }
    }
})

$form.ShowDialog()
$form.Dispose()