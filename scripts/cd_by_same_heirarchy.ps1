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

# 3 - 3 select the directory to go to
Write-Host "`nAvailable directories:" -ForegroundColor Yellow
$dirList = @()
$index = 1
foreach ($dir in $siblingDirs) {
    $targetPath = Join-Path $dir.FullName $folderPath4SameHierarchy
    $exists = Test-Path -Path $targetPath -PathType Container
    $status = if ($exists) { "[EXISTS]" } else { "[NOT FOUND]" }
    Write-Host "$index. $($dir.Name) $status" -ForegroundColor $(if ($exists) { "Green" } else { "Gray" })
    $dirList += @{
        Index      = $index
        Name       = $dir.Name
        FullPath   = $dir.FullName
        TargetPath = $targetPath
        Exists     = $exists
    }
    $index++
}

Write-Host "`nSelect directory number (or press Enter to exit):" -ForegroundColor Yellow
$selection = Read-Host

if ([string]::IsNullOrWhiteSpace($selection)) {
    Write-Host "Cancelled." -ForegroundColor Yellow
    exit 0
}

try {
    $selectedIndex = [int]$selection
    if ($selectedIndex -lt 1 -or $selectedIndex -gt $dirList.Count) {
        Write-Host "Error: Invalid selection." -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host "Error: Invalid number." -ForegroundColor Red
    exit 1
}

$selectedDir = $dirList[$selectedIndex - 1]

# 4 - 1 go to the directory
$finalPath = $selectedDir.TargetPath

# 4 - 2 error handling: if the directory does not exist, show a message and exit
if (-not $selectedDir.Exists) {
    Write-Host "`nWarning: Target directory does not exist: $finalPath" -ForegroundColor Yellow
    Write-Host "Do you want to create it? (Y/N)" -ForegroundColor Yellow
    $create = Read-Host
    if ($create -eq "Y" -or $create -eq "y") {
        try {
            New-Item -Path $finalPath -ItemType Directory -Force | Out-Null
            Write-Host "Directory created successfully." -ForegroundColor Green
        }
        catch {
            Write-Host "Error: Failed to create directory. $_" -ForegroundColor Red
            exit 1
        }
    }
    else {
        Write-Host "Cancelled." -ForegroundColor Yellow
        exit 0
    }
}

# 5 - 1 command: oc "final_path"
Write-Host "`nNavigating to: $finalPath" -ForegroundColor Green
& oc $finalPath

# code end