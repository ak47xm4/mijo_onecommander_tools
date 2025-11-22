# 1 - 1 Get the current directory
# $CURRENT_DIR is environment variable for onecommander

# 2 - 1 select how many levels up to go

# 2 - 2 save the folder hierarchy structure as a variable: $folder_path_4_same_hierarchy

# 3 - 1 get the directories name

# 3 - 2 list the directories for selection

# 3 - 3 select the directory to go to

# 4 - 1 go to the directory

# 4 - 2 error handling: if the directory does not exist, show a message and exit

# 5 - 1 command: oc "final_path"


# code start

# 1 - 1 Get the current directory
if (-not $env:CURRENT_DIR) {
    Write-Host "Error: CURRENT_DIR environment variable is not set." -ForegroundColor Red
    exit 1
}

$currentDir = $env:CURRENT_DIR
Write-Host "Current directory: $currentDir" -ForegroundColor Cyan

# 2 - 1 select how many levels up to go
Write-Host "`nHow many levels up do you want to go?" -ForegroundColor Yellow
$levelsUp = Read-Host "Enter number (default: 1)"

if ([string]::IsNullOrWhiteSpace($levelsUp)) {
    $levelsUp = 1
}
else {
    try {
        $levelsUp = [int]$levelsUp
        if ($levelsUp -lt 1) {
            Write-Host "Error: Levels must be at least 1." -ForegroundColor Red
            exit 1
        }
    }
    catch {
        Write-Host "Error: Invalid number." -ForegroundColor Red
        exit 1
    }
}

# Navigate up the specified levels
$parentPath = $currentDir
for ($i = 0; $i -lt $levelsUp; $i++) {
    $parentPath = Split-Path -Path $parentPath -Parent
    if ([string]::IsNullOrWhiteSpace($parentPath)) {
        Write-Host "Error: Cannot go up $levelsUp levels from current directory." -ForegroundColor Red
        exit 1
    }
}

Write-Host "Base path: $parentPath" -ForegroundColor Green

# 2 - 2 save the folder hierarchy structure as a variable
$folderPath4SameHierarchy = $currentDir.Substring($parentPath.Length).TrimStart('\')
Write-Host "Hierarchy structure: $folderPath4SameHierarchy" -ForegroundColor Cyan

# 3 - 1 get the directories name
$baseDir = Split-Path -Path $parentPath -Leaf
Write-Host "Base directory name: $baseDir" -ForegroundColor Cyan

# 3 - 2 list the directories for selection
$grandParentPath = Split-Path -Path $parentPath -Parent
if ([string]::IsNullOrWhiteSpace($grandParentPath)) {
    Write-Host "Error: Cannot find parent directory to search for similar structures." -ForegroundColor Red
    exit 1
}

Write-Host "`nSearching for directories in: $grandParentPath" -ForegroundColor Yellow
$siblingDirs = Get-ChildItem -Path $grandParentPath -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne $baseDir }

if ($null -eq $siblingDirs -or $siblingDirs.Count -eq 0) {
    Write-Host "No sibling directories found." -ForegroundColor Yellow
    exit 0
}

# Prepare directory list for GUI
$dirList = @()
foreach ($dir in $siblingDirs) {
    $targetPath = Join-Path $dir.FullName $folderPath4SameHierarchy
    $exists = Test-Path -Path $targetPath -PathType Container
    $dirList += [PSCustomObject]@{
        Name       = $dir.Name
        FullPath   = $dir.FullName
        TargetPath = $targetPath
        Status     = if ($exists) { "EXISTS" } else { "NOT FOUND" }
        Exists     = $exists
    }
}

# 3 - 3 select the directory to go to (GUI)
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# 視窗寬度變數（Window width variable）
[int]$windowWidth = 1280


# Create form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Select Directory - Same Hierarchy Navigator"
$form.Size = New-Object System.Drawing.Size($windowWidth, 600)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.MinimizeBox = $false

# Create label for hierarchy info
$labelInfo = New-Object System.Windows.Forms.Label
$labelInfo.Location = New-Object System.Drawing.Point(10, 10)
$labelInfo.Size = New-Object System.Drawing.Size([int]($windowWidth - 20), 40)
$labelInfo.Text = "Hierarchy Structure: $folderPath4SameHierarchy`nSearching in: $grandParentPath"
$labelInfo.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 9)
$form.Controls.Add($labelInfo)

# Create ListView
$listView = New-Object System.Windows.Forms.ListView
$listView.Location = New-Object System.Drawing.Point(10, 55)
$listView.Size = New-Object System.Drawing.Size([int]($windowWidth - 20), 450)
$listView.View = [System.Windows.Forms.View]::Details
$listView.FullRowSelect = $true
$listView.GridLines = $true
$listView.MultiSelect = $false
$listView.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 9)

# Add columns
$listView.Columns.Add("Name", 150) | Out-Null
$listView.Columns.Add("Full Path", 400) | Out-Null
$listView.Columns.Add("Target Path", 400) | Out-Null
# $listView.Columns.Add("Status", 100) | Out-Null

# Add items to ListView
foreach ($dir in $dirList) {
    $item = New-Object System.Windows.Forms.ListViewItem($dir.Name)
    $item.SubItems.Add($dir.FullPath) | Out-Null
    $item.SubItems.Add($dir.TargetPath) | Out-Null
    # $item.SubItems.Add($dir.Status) | Out-Null
    
    # Color code: Green for exists, Gray for not found
    if ($dir.Exists) {
        $item.ForeColor = [System.Drawing.Color]::DarkGreen
    }
    else {
        $item.ForeColor = [System.Drawing.Color]::Gray
    }
    
    $listView.Items.Add($item) | Out-Null
}

$form.Controls.Add($listView)

# Variable to track if new tab was selected
$script:openInNewTab = $false

# Create buttons
$btnOK = New-Object System.Windows.Forms.Button
$btnOK.Location = New-Object System.Drawing.Point(540, 515)
$btnOK.Size = New-Object System.Drawing.Size(100, 30)
$btnOK.Text = "OK"
$btnOK.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 9, [System.Drawing.FontStyle]::Bold)
$btnOK.Add_Click({
    $script:openInNewTab = $false
    $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Close()
})
$form.Controls.Add($btnOK)

$btnNewTab = New-Object System.Windows.Forms.Button
$btnNewTab.Location = New-Object System.Drawing.Point(650, 515)
$btnNewTab.Size = New-Object System.Drawing.Size(100, 30)
$btnNewTab.Text = "New Tab"
$btnNewTab.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 9)
$btnNewTab.Add_Click({
    $script:openInNewTab = $true
    $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Close()
})
$form.Controls.Add($btnNewTab)

$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Location = New-Object System.Drawing.Point(760, 515)
$btnCancel.Size = New-Object System.Drawing.Size(100, 30)
$btnCancel.Text = "Cancel"
$btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$btnCancel.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 9)
$form.Controls.Add($btnCancel)

# Double-click to select (opens in current tab)
$listView.Add_DoubleClick({
    $script:openInNewTab = $false
    $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Close()
})

# Show form
$result = $form.ShowDialog()

if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
    if ($listView.SelectedItems.Count -gt 0) {
        $selectedIndex = $listView.SelectedItems[0].Index
        $selectedDir = $dirList[$selectedIndex]
    }
    else {
        Write-Host "No directory selected. Cancelled." -ForegroundColor Yellow
        exit 0
    }
}
else {
    Write-Host "Cancelled." -ForegroundColor Yellow
    exit 0
}

# 4 - 1 go to the directory
$finalPath = $selectedDir.TargetPath

# 4 - 2 error handling: if the directory does not exist, show a message and exit
if (-not $selectedDir.Exists) {
    $msgResult = [System.Windows.Forms.MessageBox]::Show(
        "Target directory does not exist:`n`n$finalPath`n`nDo you want to create it?",
        "Directory Not Found",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
    
    if ($msgResult -eq [System.Windows.Forms.DialogResult]::Yes) {
        try {
            New-Item -Path $finalPath -ItemType Directory -Force | Out-Null
            [System.Windows.Forms.MessageBox]::Show(
                "Directory created successfully!",
                "Success",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            ) | Out-Null
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show(
                "Error: Failed to create directory.`n`n$_",
                "Error",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            ) | Out-Null
            exit 1
        }
    }
    else {
        Write-Host "Cancelled." -ForegroundColor Yellow
        exit 0
    }
}

# 5 - 1 command: oc "final_path" or oc "final_path" -newtab
if ($script:openInNewTab) {
    Write-Host "`nOpening in new tab: $finalPath" -ForegroundColor Green
    & oc $finalPath -newtab
}
else {
    Write-Host "`nNavigating to: $finalPath" -ForegroundColor Green
    & oc $finalPath
}

# code end