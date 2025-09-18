$ErrorActionPreference = "Stop"

Write-Host "🔍 Scanning for unused NuGet packages..."

# Path to the exception list file
$exceptionFilePath = ".github/scripts/unused-packages-exceptions.txt"

# Read the exception list
$exceptionPackages = @()
if (Test-Path $exceptionFilePath) {
    $exceptionPackages = Get-Content $exceptionFilePath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    Write-Host "ℹ️  Loaded exception list from $exceptionFilePath"
} else {
    Write-Host "⚠️  Exception file not found. No packages will be excluded."
}

$propsFiles = Get-ChildItem -Recurse -Filter 'Directory.Packages.props'
$allProjects = Get-ChildItem -Recurse -Include *.csproj, Directory.Build.props

$hasUnused = $false

foreach ($propsFile in $propsFiles) {
    Write-Host "`n📂 Checking: $($propsFile.FullName)"

    [xml]$xml = Get-Content $propsFile.FullName
    $declaredPackages = @()

    if ($xml.Project.ItemGroup.PackageVersion) {
        $declaredPackages = $xml.Project.ItemGroup.PackageVersion | ForEach-Object {
            $_.Include
        }
    }

    if ($declaredPackages.Count -eq 0) {
        Write-Host "  ℹ️  No PackageVersion entries found."
        continue
    }

    $baseDir = Split-Path $propsFile.FullName -Parent
    $projectsInScope = $allProjects | Where-Object {
        $_.FullName.StartsWith($baseDir)
    }

    $usedPackages = @{}
    foreach ($proj in $projectsInScope) {
        try {
            [xml]$projXml = Get-Content $proj.FullName
            $projXml.Project.ItemGroup.PackageReference | ForEach-Object {
                if ($_.Include) {
                    $usedPackages[$_.Include] = $true
                }
            }
        } catch {
            Write-Host "  ⚠️ Skipping unreadable project: $($proj.FullName)"
        }
    }

    $unusedPackages = $declaredPackages | Where-Object {
        -not $usedPackages.ContainsKey($_) -and -not $exceptionPackages.Contains($_)
    }

    if ($unusedPackages.Count -eq 0) {
        Write-Host "  ✅ All packages are used or excluded."
    } else {
        Write-Host "  ❌ Unused packages detected:"
        $unusedPackages | ForEach-Object { Write-Host "    - $_" }
        $hasUnused = $true
    }
}

if ($hasUnused) {
    throw "❌ One or more unused packages found."
} else {
    Write-Host "`n✅ No unused packages found in any Directory.Packages.props file."
}