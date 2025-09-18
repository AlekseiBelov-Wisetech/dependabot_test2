param (
    [string]$UsageThreshold = "2"  # Default value
)

$ErrorActionPreference = "Stop"

Write-Host "🔍 Analyzing root Directory.Packages.props..."
Write-Host "🔧 UsageThreshold for root packages: $usageThreshold"

# Load root Directory.Packages.props
$rootPath = Join-Path $PWD "Directory.Packages.props"
if (-not (Test-Path $rootPath)) {
    Write-Error "❌ Root Directory.Packages.props not found!"
    exit 1
}

[xml]$rootXml = Get-Content $rootPath
$rootPackages = $rootXml.Project.ItemGroup.PackageVersion | ForEach-Object { $_.Include }

if (-not $rootPackages) {
    Write-Host "✅ No packages defined in root. Nothing to check."
    exit 0
}

# Map each root package to a set of project folders
$usageMap = @{}
foreach ($pkg in $rootPackages) {
    $usageMap[$pkg] = New-Object System.Collections.Generic.HashSet[string]
}

# Find all folders containing Build.xml
$buildXmlFiles = Get-ChildItem -Recurse -Filter Build.xml
if ($buildXmlFiles.Count -eq 0) {
    Write-Error "❌ No Build.xml files found. Cannot determine project folders."
    exit 1
}

# Map Build.xml folder paths to their relative names
$repoRoot = (Get-Location).Path
$projectFolders = @{}
foreach ($buildFile in $buildXmlFiles) {
    $projectPath = $buildFile.Directory.FullName
    $relativeProjectPath = $projectPath.Substring($repoRoot.Length + 1).TrimStart('\')
    $projectFolders[$projectPath] = $relativeProjectPath
}

# Scan all .csproj files and map to deepest matching Build.xml folder
$csprojFiles = Get-ChildItem -Recurse -Filter *.csproj

foreach ($file in $csprojFiles) {
    $csprojDir = $file.Directory.FullName
    $matchedFolder = $null
    $longestMatchLength = -1

    foreach ($projectPath in $projectFolders.Keys) {
        if ($csprojDir.StartsWith($projectPath, [System.StringComparison]::OrdinalIgnoreCase)) {
            $matchLength = $projectPath.Length
            if ($matchLength -gt $longestMatchLength) {
                $longestMatchLength = $matchLength
                $matchedFolder = $projectFolders[$projectPath]
            }
        }
    }

    if (-not $matchedFolder) {
        continue  # Skip csproj files not under any known Build.xml folder
    }

    [xml]$csprojXml = Get-Content $file.FullName
    $packageRefs = $csprojXml.Project.ItemGroup.PackageReference | ForEach-Object { $_.Include }

    foreach ($pkg in $rootPackages) {
        if ($packageRefs -contains $pkg) {
            $null = $usageMap[$pkg].Add($matchedFolder)
        }
    }
}

# Find root packages used in <= usageThreshold project folders
$recommendations = @{}
foreach ($pkg in $rootPackages) {
    $folders = $usageMap[$pkg]
    $folderCount = $folders.Count

    if ($folderCount -gt 0 -and $folderCount -le [int]$usageThreshold) {
        $recommendations[$pkg] = $folders
    }
}

# Output recommendations
if ($recommendations.Count -eq 0) {
    Write-Host "`n✅ All root packages are widely used. No recommendations."
} else {
    Write-Host "`n🔔 The following packages are defined in the root Directory.Packages.props but are only used in $usageThreshold or fewer project folders:"
    foreach ($pkg in $recommendations.Keys) {
        $folders = $recommendations[$pkg]
        Write-Host "`n🔹 Package: $pkg"
        foreach ($folder in $folders) {
            Write-Host "   - Used in project folder: $folder"
        }
        Write-Host "   👉 Consider moving '$pkg' to that project's Directory.Packages.props file instead."
    }

    Write-Error "`n❌ Action failed: One or more packages should be moved out of the root Directory.Packages.props file."
    exit 1
}