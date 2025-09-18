param (
    [string]$UsageThreshold = "2"  # Default value
)

$ErrorActionPreference = "Stop"

Write-Host "🔧 Max allowed duplicates per package: $UsageThreshold"
Write-Host "🔍 Scanning for Directory.Packages.props files..."

$allProps = Get-ChildItem -Recurse -Filter "Directory.Packages.props"
$rootProps = $allProps | Where-Object { $_.DirectoryName -eq (Get-Location).Path }
$projectProps = $allProps | Where-Object { $_.FullName -ne $rootProps.FullName }

$packageUsage = @{}

foreach ($file in $projectProps) {
    [xml]$xml = Get-Content $file.FullName

    $packages = $xml.Project.ItemGroup.PackageVersion
    foreach ($pkg in $packages) {
        $id = $pkg.Include
        if (-not $packageUsage.ContainsKey($id)) {
            $packageUsage[$id] = @()
        }
        $packageUsage[$id] += $file.FullName
    }
}

$violations = @{}

foreach ($entry in $packageUsage.GetEnumerator()) {
    if ($entry.Value.Count -gt $UsageThreshold) {
        $violations[$entry.Key] = $entry.Value
    }
}

if ($violations.Count -gt 0) {
    Write-Host "`n❌ The following packages are used in more than $UsageThreshold project-level Directory.Packages.props files:"
    foreach ($pkg in $violations.Keys) {
        Write-Host "`n🔸 Package: $pkg"
        foreach ($path in $violations[$pkg]) {
            Write-Host "   - $path"
        }
    }
    Write-Error "`n🛑 Some of the packages are used in more than $UsageThreshold project-level Directory.Packages.props files. Please move them to the root Directory.Packages.props."
    exit 1
} else {
    Write-Host "`n✅ All packages are within the allowed threshold ($UsageThreshold)."
}