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

$currentDir = $env:CURRENT_DIR.Trim()

# Validate current directory
if ([string]::IsNullOrWhiteSpace($currentDir)) {
    Write-Host "Error: CURRENT_DIR is empty." -ForegroundColor Red
    exit 1
}

# Check if current directory exists
if (-not (Test-Path -Path $currentDir -PathType Container)) {
    Write-Host "Error: Current directory does not exist: $currentDir" -ForegroundColor Red
    exit 1
}

Write-Host "Current directory: $currentDir" -ForegroundColor Cyan

# Store current directory for use in functions
$script:currentDirForGUI = $currentDir

# Configuration file path
$configDir = Join-Path $env:USERPROFILE "Documents\mijo_oc_tools"
$configFile = Join-Path $configDir "mijo_oc_tools_config.json"

# Function to load configuration
function Load-Config {
    if (Test-Path -Path $configFile) {
        try {
            $configContent = Get-Content -Path $configFile -Raw -ErrorAction Stop
            if ([string]::IsNullOrWhiteSpace($configContent)) {
                Write-Host "Warning: Config file is empty. Using defaults." -ForegroundColor Yellow
                return @{
                    LevelsUp = 1
                    SubLevels = 0
                    ColumnWidths = @(150, 400, 400, 100)
                }
            }
            
            $config = $configContent | ConvertFrom-Json -ErrorAction Stop
            
            # Validate and sanitize values
            $levelsUp = 1
            $subLevels = 0
            $columnWidths = @(150, 400, 400, 100)  # Default column widths: Name, Full Path, Target Path, Status
            
            if ($config.LevelsUp) {
                try {
                    $levelsUp = [int]$config.LevelsUp
                    if ($levelsUp -lt 1 -or $levelsUp -gt 20) {
                        Write-Host "Warning: Invalid LevelsUp value ($levelsUp). Using default (1)." -ForegroundColor Yellow
                        $levelsUp = 1
                    }
                }
                catch {
                    Write-Host "Warning: Invalid LevelsUp format. Using default (1)." -ForegroundColor Yellow
                    $levelsUp = 1
                }
            }
            
            if ($config.SubLevels) {
                try {
                    $subLevels = [int]$config.SubLevels
                    if ($subLevels -lt 0 -or $subLevels -gt 10) {
                        Write-Host "Warning: Invalid SubLevels value ($subLevels). Using default (0)." -ForegroundColor Yellow
                        $subLevels = 0
                    }
                }
                catch {
                    Write-Host "Warning: Invalid SubLevels format. Using default (0)." -ForegroundColor Yellow
                    $subLevels = 0
                }
            }
            
            # Load column widths if available
            if ($config.ColumnWidths) {
                try {
                    $loadedWidths = @()
                    if ($config.ColumnWidths -is [System.Array]) {
                        foreach ($width in $config.ColumnWidths) {
                            $w = [int]$width
                            if ($w -gt 0 -and $w -lt 10000) {
                                $loadedWidths += $w
                            }
                            else {
                                throw "Invalid width value: $w"
                            }
                        }
                        if ($loadedWidths.Count -eq 4) {
                            $columnWidths = $loadedWidths
                        }
                    }
                }
                catch {
                    Write-Host "Warning: Invalid ColumnWidths format. Using defaults." -ForegroundColor Yellow
                }
            }
            
            return @{
                LevelsUp = $levelsUp
                SubLevels = $subLevels
                ColumnWidths = $columnWidths
            }
        }
        catch {
            Write-Host "Warning: Failed to load config file ($($_.Exception.Message)). Using defaults." -ForegroundColor Yellow
            return @{
                LevelsUp = 1
                SubLevels = 0
                ColumnWidths = @(150, 400, 400, 100)
            }
        }
    }
    return @{
        LevelsUp = 1
        SubLevels = 0
        ColumnWidths = @(150, 400, 400, 100)
    }
}

# Function to save configuration
function Save-Config {
    param(
        [int]$levelsUp,
        [int]$subLevels,
        [int[]]$columnWidths = $null
    )
    
    # Validate input values
    if ($levelsUp -lt 1 -or $levelsUp -gt 20) {
        Write-Host "Error: LevelsUp must be between 1 and 20." -ForegroundColor Red
        return $false
    }
    
    if ($subLevels -lt 0 -or $subLevels -gt 10) {
        Write-Host "Error: SubLevels must be between 0 and 10." -ForegroundColor Red
        return $false
    }
    
    # Validate column widths if provided
    if ($null -ne $columnWidths) {
        if ($columnWidths.Count -ne 4) {
            Write-Host "Warning: ColumnWidths should have 4 values. Using provided values or defaults." -ForegroundColor Yellow
        }
        foreach ($width in $columnWidths) {
            if ($width -le 0 -or $width -ge 10000) {
                Write-Host "Warning: Invalid column width ($width). Using defaults." -ForegroundColor Yellow
                $columnWidths = $null
                break
            }
        }
    }
    
    # Use default column widths if not provided or invalid
    if ($null -eq $columnWidths -or $columnWidths.Count -ne 4) {
        $columnWidths = @(150, 400, 400, 100)
    }
    
    # Ensure directory exists
    try {
        if (-not (Test-Path -Path $configDir)) {
            $null = New-Item -Path $configDir -ItemType Directory -Force -ErrorAction Stop
        }
    }
    catch {
        Write-Host "Error: Cannot create config directory: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
    
    try {
        $config = @{
            LevelsUp = $levelsUp
            SubLevels = $subLevels
            ColumnWidths = $columnWidths
        } | ConvertTo-Json -ErrorAction Stop
        
        Set-Content -Path $configFile -Value $config -Encoding UTF8 -ErrorAction Stop
        return $true
    }
    catch {
        Write-Host "Error: Failed to save config: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to calculate paths based on levels up
function Calculate-Paths {
    param([int]$levelsUp, [int]$subLevels = 0)
    
    $currentDirToUse = $script:currentDirForGUI
    
    # Validate input parameters
    if ($levelsUp -lt 1 -or $levelsUp -gt 20) {
        return @{
            Success = $false
            Message = "LevelsUp must be between 1 and 20."
        }
    }
    
    if ($subLevels -lt 0 -or $subLevels -gt 10) {
        return @{
            Success = $false
            Message = "SubLevels must be between 0 and 10."
        }
    }
    
    # Validate current directory
    if ([string]::IsNullOrWhiteSpace($currentDirToUse)) {
        return @{
            Success = $false
            Message = "Current directory is not set."
        }
    }
    
    # Normalize path
    try {
        $currentDirToUse = [System.IO.Path]::GetFullPath($currentDirToUse)
    }
    catch {
        return @{
            Success = $false
            Message = "Invalid path format: $($_.Exception.Message)"
        }
    }
    
    # Navigate up the specified levels
    $parentPath = $currentDirToUse
    $levelsNavigated = 0
    
    for ($i = 0; $i -lt $levelsUp; $i++) {
        if ([string]::IsNullOrWhiteSpace($parentPath)) {
            return @{
                Success = $false
                Message = "Cannot go up $levelsUp levels. Only reached $levelsNavigated level(s)."
            }
        }
        
        try {
            $newPath = Split-Path -Path $parentPath -Parent -ErrorAction Stop
        }
        catch {
            return @{
                Success = $false
                Message = "Error navigating up: $($_.Exception.Message)"
            }
        }
        
        if ([string]::IsNullOrWhiteSpace($newPath) -or $newPath -eq $parentPath) {
            return @{
                Success = $false
                Message = "Cannot go up $levelsUp levels. Reached root at level $levelsNavigated."
            }
        }
        
        $parentPath = $newPath
        $levelsNavigated++
    }
    
    # Validate parent path exists
    if (-not (Test-Path -Path $parentPath -PathType Container)) {
        return @{
            Success = $false
            Message = "Parent path does not exist: $parentPath"
        }
    }
    
    # Save the folder hierarchy structure (from parent path)
    try {
        if ($currentDirToUse.Length -le $parentPath.Length) {
            return @{
                Success = $false
                Message = "Invalid path calculation. Current directory path is shorter than parent path."
            }
        }
        $folderPath4SameHierarchy = $currentDirToUse.Substring($parentPath.Length).TrimStart('\', '/')
    }
    catch {
        return @{
            Success = $false
            Message = "Error calculating hierarchy structure: $($_.Exception.Message)"
        }
    }
    
    # Split the hierarchy structure to get the part after subLevels
    $hierarchyParts = $folderPath4SameHierarchy -split '[\\/]' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    
    if ($subLevels -gt 0 -and $hierarchyParts.Count -gt $subLevels) {
        # Get the remaining path after subLevels
        $remainingPath = ($hierarchyParts[$subLevels..($hierarchyParts.Count - 1)] -join '\')
    }
    elseif ($subLevels -gt 0 -and $hierarchyParts.Count -le $subLevels) {
        return @{
            Success = $false
            Message = "SubLevels ($subLevels) exceeds available hierarchy levels ($($hierarchyParts.Count))."
        }
    }
    else {
        $remainingPath = $folderPath4SameHierarchy
    }
    
    # Get the directories name
    try {
        $baseDir = Split-Path -Path $parentPath -Leaf
        if ([string]::IsNullOrWhiteSpace($baseDir)) {
            return @{
                Success = $false
                Message = "Cannot determine base directory name from path: $parentPath"
            }
        }
    }
    catch {
        return @{
            Success = $false
            Message = "Error getting base directory: $($_.Exception.Message)"
        }
    }
    
    # Get grand parent path
    try {
        $grandParentPath = Split-Path -Path $parentPath -Parent -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($grandParentPath)) {
            return @{
                Success = $false
                Message = "Cannot determine grand parent path. Reached root directory."
            }
        }
        
        # Validate grand parent path exists
        if (-not (Test-Path -Path $grandParentPath -PathType Container)) {
            return @{
                Success = $false
                Message = "Grand parent path does not exist: $grandParentPath"
            }
        }
    }
    catch {
        return @{
            Success = $false
            Message = "Error getting grand parent path: $($_.Exception.Message)"
        }
    }
    
    # Get all directories (including current directory) to list all scenes
    try {
        $siblingDirs = Get-ChildItem -Path $grandParentPath -Directory -ErrorAction Stop | Where-Object {
            # Filter out system directories and ensure we can access them
            try {
                $null = $_.FullName
                return $true
            }
            catch {
                return $false
            }
        }
    }
    catch {
        return @{
            Success = $false
            Message = "Error accessing directories in $grandParentPath : $($_.Exception.Message)"
        }
    }
    
    if ($null -eq $siblingDirs -or $siblingDirs.Count -eq 0) {
        return @{
            Success = $false
            Message = "No accessible directories found in: $grandParentPath"
        }
    }
    
    # Prepare directory list
    $dirList = @()
    $errorCount = 0
    $maxErrors = 10
    
    foreach ($dir in $siblingDirs) {
        try {
            # Start with the sibling directory
            $baseTargetPath = $dir.FullName
            
            # Validate base target path
            if ([string]::IsNullOrWhiteSpace($baseTargetPath) -or -not (Test-Path -Path $baseTargetPath -PathType Container)) {
                $errorCount++
                if ($errorCount -ge $maxErrors) {
                    Write-Host "Warning: Too many errors processing directories. Stopping." -ForegroundColor Yellow
                    break
                }
                continue
            }
        
        # Navigate down subLevels if specified
        if ($subLevels -gt 0 -and $hierarchyParts.Count -gt $subLevels) {
            # Get the first subLevels parts from the original hierarchy
            $subPathParts = $hierarchyParts[0..($subLevels - 1)]
            
            # Extract pattern suffix from the first subPath part (e.g., "_A" from "VFX_scene_0001_A")
            $firstPart = $subPathParts[0]
            $patternSuffix = ""
            if ($firstPart -match [regex]::Escape($baseDir)) {
                # Extract the suffix pattern (e.g., "_A" from "VFX_scene_0001_A")
                $patternSuffix = $firstPart -replace [regex]::Escape($baseDir), ""
            }
            else {
                # Try to extract suffix pattern (e.g., "_A" from names ending with "_A")
                if ($firstPart -match '_(.)$') {
                    $patternSuffix = "_$($matches[1])"
                }
            }
            
            # Get all subdirectories in the current directory
            $allSubDirs = Get-ChildItem -Path $baseTargetPath -Directory -ErrorAction SilentlyContinue
            
            if ($patternSuffix -ne "" -and $allSubDirs) {
                # Find all subdirectories that match the suffix pattern (e.g., all ending with "_A", "_B", "_C")
                # Extract all unique suffixes from subdirectories
                $allSuffixes = $allSubDirs | ForEach-Object { 
                    if ($_.Name -match '_(.)$') { "_$($matches[1])" }
                } | Where-Object { $_ -ne $null } | Select-Object -Unique
                
                # Filter subdirectories that have matching suffix pattern
                $matchingSubDirs = $allSubDirs | Where-Object {
                    $subDirName = $_.Name
                    # Check if it matches any of the suffix patterns found
                    foreach ($suffix in $allSuffixes) {
                        if ($subDirName -like "*$suffix") {
                            return $true
                        }
                    }
                    return $false
                }
            }
            else {
                # If no pattern or no subdirectories, get all subdirectories
                $matchingSubDirs = $allSubDirs
            }
            
            # Create entries for each matching subdirectory
            if ($matchingSubDirs -and $matchingSubDirs.Count -gt 0) {
                foreach ($subDir in $matchingSubDirs) {
                    $targetPath = $subDir.FullName
                    
                    # Navigate down remaining subLevels if any
                    if ($subPathParts.Count -gt 1) {
                        $remainingSubParts = $subPathParts[1..($subPathParts.Count - 1)]
                        foreach ($part in $remainingSubParts) {
                            # Replace baseDir in the part name
                            $patternPart = $part -replace [regex]::Escape($baseDir), $dir.Name
                            $targetPath = Join-Path $targetPath $patternPart
                        }
                    }
                    
                    # Add the remaining path
                    if (-not [string]::IsNullOrWhiteSpace($remainingPath)) {
                        $targetPath = Join-Path $targetPath $remainingPath
                    }
                    
                    $exists = Test-Path -Path $targetPath -PathType Container
                    $displayName = "$($dir.Name)\$($subDir.Name)"
                    $dirList += [PSCustomObject]@{
                        Name       = $displayName
                        FullPath   = $subDir.FullName
                        TargetPath = $targetPath
                        Status     = if ($exists) { "EXISTS" } else { "NOT FOUND" }
                        Exists     = $exists
                    }
                }
            }
            else {
                # No matching subdirectories found, create entry with expected path
                $expectedName = $firstPart -replace [regex]::Escape($baseDir), $dir.Name
                $targetPath = Join-Path $baseTargetPath $expectedName
                if (-not [string]::IsNullOrWhiteSpace($remainingPath)) {
                    $targetPath = Join-Path $targetPath $remainingPath
                }
                
                $exists = Test-Path -Path $targetPath -PathType Container
                $dirList += [PSCustomObject]@{
                    Name       = "$($dir.Name)\$expectedName"
                    FullPath   = Join-Path $baseTargetPath $expectedName
                    TargetPath = $targetPath
                    Status     = if ($exists) { "EXISTS" } else { "NOT FOUND" }
                    Exists     = $exists
                }
            }
        }
        else {
            # No subLevels or subLevels covers all hierarchy, use the full hierarchy structure
            $targetPath = $baseTargetPath
            if (-not [string]::IsNullOrWhiteSpace($folderPath4SameHierarchy)) {
                $targetPath = Join-Path $targetPath $folderPath4SameHierarchy
            }
            
            $exists = Test-Path -Path $targetPath -PathType Container
            $dirList += [PSCustomObject]@{
                Name       = $dir.Name
                FullPath   = $dir.FullName
                TargetPath = $targetPath
                Status     = if ($exists) { "EXISTS" } else { "NOT FOUND" }
                Exists     = $exists
            }
        }
        }
        catch {
            $errorCount++
            Write-Host "Warning: Error processing directory $($dir.Name): $($_.Exception.Message)" -ForegroundColor Yellow
            if ($errorCount -ge $maxErrors) {
                Write-Host "Too many errors. Stopping directory processing." -ForegroundColor Yellow
                break
            }
            continue
        }
    }
    
    # Check if we have any valid directories
    if ($dirList.Count -eq 0) {
        return @{
            Success = $false
            Message = "No valid directories found after processing. There may be permission issues or invalid paths."
        }
    }
    
    return @{
        Success                  = $true
        ParentPath               = $parentPath
        FolderPath4SameHierarchy = $folderPath4SameHierarchy
        BaseDir                  = $baseDir
        GrandParentPath          = $grandParentPath
        DirList                  = $dirList
    }
}

# Initialize with saved config or defaults
try {
    $savedConfig = Load-Config
    $script:levelsUp = $savedConfig.LevelsUp
    $script:subLevels = $savedConfig.SubLevels
    $script:columnWidths = $savedConfig.ColumnWidths
    
    # Validate loaded config
    if ($script:levelsUp -lt 1 -or $script:levelsUp -gt 20) {
        Write-Host "Warning: Invalid LevelsUp in config ($script:levelsUp). Using default (1)." -ForegroundColor Yellow
        $script:levelsUp = 1
    }
    
    if ($script:subLevels -lt 0 -or $script:subLevels -gt 10) {
        Write-Host "Warning: Invalid SubLevels in config ($script:subLevels). Using default (0)." -ForegroundColor Yellow
        $script:subLevels = 0
    }
    
    # Validate column widths
    if ($null -eq $script:columnWidths -or $script:columnWidths.Count -ne 4) {
        $script:columnWidths = @(150, 400, 400, 100)
    }
    
    $pathData = Calculate-Paths -levelsUp $script:levelsUp -subLevels $script:subLevels
    
    if ($null -eq $pathData -or -not $pathData.Success) {
        if ($pathData -and $pathData.Message) {
            Write-Host $pathData.Message -ForegroundColor Yellow
            # Try with default values if initial calculation fails
            if ($script:levelsUp -ne 1 -or $script:subLevels -ne 0) {
                Write-Host "Trying with default values (LevelsUp=1, SubLevels=0)..." -ForegroundColor Yellow
                $script:levelsUp = 1
                $script:subLevels = 0
                $pathData = Calculate-Paths -levelsUp $script:levelsUp -subLevels $script:subLevels
            }
        }
        
        if ($null -eq $pathData -or -not $pathData.Success) {
            if ($pathData -and $pathData.Message) {
                Write-Host "Error: $($pathData.Message)" -ForegroundColor Red
            }
            else {
                Write-Host "Error: Cannot calculate paths. Please check the directory structure." -ForegroundColor Red
            }
            exit 0
        }
    }
}
catch {
    Write-Host "Error during initialization: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
}

$parentPath = $pathData.ParentPath
$folderPath4SameHierarchy = $pathData.FolderPath4SameHierarchy
$baseDir = $pathData.BaseDir
$grandParentPath = $pathData.GrandParentPath
$dirList = $pathData.DirList

# 3 - 3 select the directory to go to (GUI)
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# 視窗寬度變數（Window width variable）
[int]$windowWidth = 1280

# Create form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Select Directory - Same Hierarchy Navigator"
$form.Size = New-Object System.Drawing.Size($windowWidth, 650)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.MinimizeBox = $false

# Create label for current directory
$labelCurrentDir = New-Object System.Windows.Forms.Label
$labelCurrentDir.Location = New-Object System.Drawing.Point(10, 10)
$labelCurrentDir.Size = New-Object System.Drawing.Size([int]($windowWidth - 20), 20)
$labelCurrentDir.Text = "Current Directory: $currentDir"
$labelCurrentDir.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 8, [System.Drawing.FontStyle]::Italic)
$labelCurrentDir.ForeColor = [System.Drawing.Color]::DarkGray
$form.Controls.Add($labelCurrentDir)

# Create level selector
$labelLevel = New-Object System.Windows.Forms.Label
$labelLevel.Location = New-Object System.Drawing.Point(10, 35)
$labelLevel.Size = New-Object System.Drawing.Size(100, 25)
$labelLevel.Text = "Levels Up:"
$labelLevel.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 9)
$labelLevel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
$form.Controls.Add($labelLevel)

# Use ComboBox instead of NumericUpDown for better compatibility
$comboLevels = New-Object System.Windows.Forms.ComboBox
$comboLevels.Location = New-Object System.Drawing.Point(115, 32)
$comboLevels.Size = New-Object System.Drawing.Size(80, 30)
$comboLevels.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$comboLevels.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 10)
for ($i = 1; $i -le 20; $i++) {
    $comboLevels.Items.Add($i) | Out-Null
}
$comboLevels.SelectedIndex = $script:levelsUp - 1
$form.Controls.Add($comboLevels)

# Create sub level selector
$labelSubLevel = New-Object System.Windows.Forms.Label
$labelSubLevel.Location = New-Object System.Drawing.Point(205, 35)
$labelSubLevel.Size = New-Object System.Drawing.Size(100, 25)
$labelSubLevel.Text = "Sub Levels:"
$labelSubLevel.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 9)
$labelSubLevel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
$form.Controls.Add($labelSubLevel)

$comboSubLevels = New-Object System.Windows.Forms.ComboBox
$comboSubLevels.Location = New-Object System.Drawing.Point(310, 32)
$comboSubLevels.Size = New-Object System.Drawing.Size(80, 30)
$comboSubLevels.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$comboSubLevels.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 10)
for ($i = 0; $i -le 10; $i++) {
    $comboSubLevels.Items.Add($i) | Out-Null
}
$comboSubLevels.SelectedIndex = $script:subLevels
$form.Controls.Add($comboSubLevels)

$btnRefresh = New-Object System.Windows.Forms.Button
$btnRefresh.Location = New-Object System.Drawing.Point(400, 32)
$btnRefresh.Size = New-Object System.Drawing.Size(90, 30)
$btnRefresh.Text = "Refresh"
$btnRefresh.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 9)
$form.Controls.Add($btnRefresh)

$btnSave = New-Object System.Windows.Forms.Button
$btnSave.Location = New-Object System.Drawing.Point(500, 32)
$btnSave.Size = New-Object System.Drawing.Size(120, 30)
$btnSave.Text = "Save GUI Config"
$btnSave.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 9)
$form.Controls.Add($btnSave)

# Create label for hierarchy info
$labelInfo = New-Object System.Windows.Forms.Label
$labelInfo.Location = New-Object System.Drawing.Point(10, 65)
$labelInfo.Size = New-Object System.Drawing.Size([int]($windowWidth - 20), 40)
$labelInfo.Text = "Hierarchy Structure: $folderPath4SameHierarchy`nSearching in: $grandParentPath"
$labelInfo.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 9)
$form.Controls.Add($labelInfo)

# Create ListView
$listView = New-Object System.Windows.Forms.ListView
$listView.Location = New-Object System.Drawing.Point(10, 110)
$listView.Size = New-Object System.Drawing.Size([int]($windowWidth - 20), 450)
$listView.View = [System.Windows.Forms.View]::Details
$listView.FullRowSelect = $true
$listView.GridLines = $true
$listView.MultiSelect = $false
$listView.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 9)

# Add columns with saved widths or defaults
$listView.Columns.Add("Name", $script:columnWidths[0]) | Out-Null
$listView.Columns.Add("Full Path", $script:columnWidths[1]) | Out-Null
$listView.Columns.Add("Target Path", $script:columnWidths[2]) | Out-Null
$listView.Columns.Add("Status", $script:columnWidths[3]) | Out-Null

# Function to refresh the list
function Refresh-ListView {
    param($listView, $dirList, $labelInfo, $grandParentPath, $folderPath4SameHierarchy)
    
    $listView.Items.Clear()
    
    foreach ($dir in $dirList) {
        $item = New-Object System.Windows.Forms.ListViewItem($dir.Name)
        $item.SubItems.Add($dir.FullPath) | Out-Null
        $item.SubItems.Add($dir.TargetPath) | Out-Null
        $item.SubItems.Add($dir.Status) | Out-Null
        
        # Color code: Green for exists, Gray for not found
        if ($dir.Exists) {
            $item.ForeColor = [System.Drawing.Color]::DarkGreen
        }
        else {
            $item.ForeColor = [System.Drawing.Color]::Gray
        }
        
        $listView.Items.Add($item) | Out-Null
    }
    
    $labelInfo.Text = "Hierarchy Structure: $folderPath4SameHierarchy`nSearching in: $grandParentPath"
}

# Initial population
Refresh-ListView -listView $listView -dirList $dirList -labelInfo $labelInfo -grandParentPath $grandParentPath -folderPath4SameHierarchy $folderPath4SameHierarchy

$form.Controls.Add($listView)

# Refresh button click handler
$btnRefresh.Add_Click({
        try {
            # Validate selections
            if ($comboLevels.SelectedItem -eq $null) {
                [System.Windows.Forms.MessageBox]::Show(
                    "Please select a value for Levels Up.",
                    "Invalid Selection",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Warning
                ) | Out-Null
                return
            }
            
            if ($comboSubLevels.SelectedItem -eq $null) {
                [System.Windows.Forms.MessageBox]::Show(
                    "Please select a value for Sub Levels.",
                    "Invalid Selection",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Warning
                ) | Out-Null
                return
            }
            
            $script:levelsUp = [int]$comboLevels.SelectedItem
            $script:subLevels = [int]$comboSubLevels.SelectedItem
            
            # Validate values
            if ($script:levelsUp -lt 1 -or $script:levelsUp -gt 20) {
                [System.Windows.Forms.MessageBox]::Show(
                    "Levels Up must be between 1 and 20.",
                    "Invalid Value",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Warning
                ) | Out-Null
                return
            }
            
            if ($script:subLevels -lt 0 -or $script:subLevels -gt 10) {
                [System.Windows.Forms.MessageBox]::Show(
                    "Sub Levels must be between 0 and 10.",
                    "Invalid Value",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Warning
                ) | Out-Null
                return
            }
            
            $pathData = Calculate-Paths -levelsUp $script:levelsUp -subLevels $script:subLevels
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show(
                "Error processing selection: $($_.Exception.Message)",
                "Error",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            ) | Out-Null
            return
        }
    
        if ($null -eq $pathData -or -not $pathData.Success) {
            if ($pathData -and $pathData.Message) {
                [System.Windows.Forms.MessageBox]::Show(
                    $pathData.Message,
                    "Information",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information
                ) | Out-Null
            }
            else {
                $errorMsg = "Error: Cannot go up $($script:levelsUp) level(s)"
                if ($script:subLevels -gt 0) {
                    $errorMsg += " and navigate $($script:subLevels) sub-level(s)"
                }
                $errorMsg += " from current directory."
                [System.Windows.Forms.MessageBox]::Show(
                    $errorMsg,
                    "Error",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Error
                ) | Out-Null
            }
            return
        }
    
        $script:parentPath = $pathData.ParentPath
        $script:folderPath4SameHierarchy = $pathData.FolderPath4SameHierarchy
        $script:baseDir = $pathData.BaseDir
        $script:grandParentPath = $pathData.GrandParentPath
        $script:dirList = $pathData.DirList
    
        Refresh-ListView -listView $listView -dirList $script:dirList -labelInfo $labelInfo -grandParentPath $script:grandParentPath -folderPath4SameHierarchy $script:folderPath4SameHierarchy
})

# Save button click handler
$btnSave.Add_Click({
    try {
        # Validate selections
        if ($comboLevels.SelectedItem -eq $null) {
            [System.Windows.Forms.MessageBox]::Show(
                "Please select a value for Levels Up before saving.",
                "Invalid Selection",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            ) | Out-Null
            return
        }
        
        if ($comboSubLevels.SelectedItem -eq $null) {
            [System.Windows.Forms.MessageBox]::Show(
                "Please select a value for Sub Levels before saving.",
                "Invalid Selection",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            ) | Out-Null
            return
        }
        
        $currentLevelsUp = [int]$comboLevels.SelectedItem
        $currentSubLevels = [int]$comboSubLevels.SelectedItem
        
        # Get current column widths from ListView
        $currentColumnWidths = @()
        foreach ($column in $listView.Columns) {
            $currentColumnWidths += $column.Width
        }
        
        $success = Save-Config -levelsUp $currentLevelsUp -subLevels $currentSubLevels -columnWidths $currentColumnWidths
        
        if ($success) {
            $columnWidthsInfo = "Column Widths: " + ($currentColumnWidths -join ", ")
            [System.Windows.Forms.MessageBox]::Show(
                "Configuration saved successfully!`n`nLevels Up: $currentLevelsUp`nSub Levels: $currentSubLevels`n$columnWidthsInfo`n`nLocation: $configFile",
                "Configuration Saved",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            ) | Out-Null
        }
        else {
            [System.Windows.Forms.MessageBox]::Show(
                "Failed to save configuration.`n`nPlease check:`n- Write permissions to:`n  $configFile`n- Valid values (LevelsUp: 1-20, SubLevels: 0-10)",
                "Save Failed",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            ) | Out-Null
        }
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show(
            "Error saving configuration: $($_.Exception.Message)",
            "Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
})

# Store variables in script scope for refresh functionality
$script:parentPath = $parentPath
$script:folderPath4SameHierarchy = $folderPath4SameHierarchy
$script:baseDir = $baseDir
$script:grandParentPath = $grandParentPath
$script:dirList = $dirList

# Variable to track if new tab was selected
$script:openInNewTab = $false

# Create buttons
$btnOK = New-Object System.Windows.Forms.Button
$btnOK.Location = New-Object System.Drawing.Point(540, 570)
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
$btnNewTab.Location = New-Object System.Drawing.Point(650, 570)
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
$btnCancel.Location = New-Object System.Drawing.Point(760, 570)
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
        $selectedDir = $script:dirList[$selectedIndex]
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
try {
    # Validate final path
    if ([string]::IsNullOrWhiteSpace($finalPath)) {
        Write-Host "Error: Final path is empty." -ForegroundColor Red
        exit 1
    }
    
    # Normalize path
    $finalPath = [System.IO.Path]::GetFullPath($finalPath)
    
    # Check if path exists (if it was supposed to exist)
    if ($selectedDir.Exists -and -not (Test-Path -Path $finalPath -PathType Container)) {
        Write-Host "Warning: Target path does not exist: $finalPath" -ForegroundColor Yellow
    }
    
    if ($script:openInNewTab) {
        Write-Host "`nOpening in new tab: $finalPath" -ForegroundColor Green
        & oc $finalPath -newtab
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Warning: OneCommander command returned error code $LASTEXITCODE" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "`nNavigating to: $finalPath" -ForegroundColor Green
        & oc $finalPath
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Warning: OneCommander command returned error code $LASTEXITCODE" -ForegroundColor Yellow
        }
    }
}
catch {
    Write-Host "Error executing OneCommander command: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Path: $finalPath" -ForegroundColor Red
    exit 1
}

# code end