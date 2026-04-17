# Regenerate all winget detection scripts from the template

$templatePath = "C:\Users\colin\repos\intune\installers\winget\_detect-winget-package.ps1"
$wingetFolder = "C:\Users\colin\repos\intune\installers\winget"

# Read the template
$template = Get-Content $templatePath -Raw

# Get all detect scripts (excluding the template itself)
$detectScripts = Get-ChildItem $wingetFolder -Filter "detect-*.ps1" | 
    Where-Object { $_.Name -ne '_detect-winget-package.ps1' }

Write-Host "Found $($detectScripts.Count) detection scripts to regenerate`n" -ForegroundColor Cyan

foreach ($script in $detectScripts) {
    Write-Host "Processing $($script.Name)..." -NoNewline
    
    try {
        $content = Get-Content $script.FullName -Raw
        
        # Extract parameters using regex
        $packageIdMatch = [regex]::Match($content, '\[string\]\$PackageId\s*=\s*"([^"]+)"')
        $versionMatch = [regex]::Match($content, '\[string\]\$RequiredVersion\s*=\s*"([^"]*)"')
        $sourceMatch = [regex]::Match($content, '\[string\]\$Source\s*=\s*"([^"]*)"')
        $contextMatch = [regex]::Match($content, '\[string\]\$InstallContext\s*=\s*"([^"]+)"')
        
        # Extract array parameters
        $pathsMatch = [regex]::Match($content, '\[string\[\]\]\$UserContextPaths\s*=\s*@\(((?:[^)]*|\([^)]*\))*)\)', [System.Text.RegularExpressions.RegexOptions]::Singleline)
        $regKeysMatch = [regex]::Match($content, '\[string\[\]\]\$UserContextRegistryKeys\s*=\s*@\(((?:[^)]*|\([^)]*\))*)\)', [System.Text.RegularExpressions.RegexOptions]::Singleline)
        
        if (-not $packageIdMatch.Success) {
            Write-Host " SKIP (couldn't parse PackageId)" -ForegroundColor Red
            continue
        }
        
        # Get values
        $packageId = $packageIdMatch.Groups[1].Value
        $version = if ($versionMatch.Success) { $versionMatch.Groups[1].Value } else { "Latest" }
        $source = if ($sourceMatch.Success) { $sourceMatch.Groups[1].Value } else { "winget" }
        $context = if ($contextMatch.Success) { $contextMatch.Groups[1].Value } else { "System" }
        
        # Get array values (clean up whitespace but preserve content)
        $paths = if ($pathsMatch.Success) { 
            $pathsMatch.Groups[1].Value.Trim() 
        } else { 
            "" 
        }
        
        $regKeys = if ($regKeysMatch.Success) { 
            $regKeysMatch.Groups[1].Value.Trim() 
        } else { 
            "" 
        }
        
        # Create the new script from template
        $newContent = $template -replace '\[string\]\$PackageId\s*=\s*"[^"]*"', "[string]`$PackageId       = `"$packageId`""
        $newContent = $newContent -replace '\[string\]\$RequiredVersion\s*=\s*"[^"]*"', "[string]`$RequiredVersion = `"$version`""
        $newContent = $newContent -replace '\[string\]\$Source\s*=\s*"[^"]*"', "[string]`$Source          = `"$source`""
        $newContent = $newContent -replace '\[string\]\$InstallContext\s*=\s*"[^"]*"', "[string]`$InstallContext  = `"$context`""
        
        # Replace array parameters
        $newContent = $newContent -replace '\[string\[\]\]\$UserContextPaths\s*=\s*@\([^)]*\)', "[string[]]`$UserContextPaths = @($paths)"
        $newContent = $newContent -replace '\[string\[\]\]\$UserContextRegistryKeys\s*=\s*@\([^)]*\)', "[string[]]`$UserContextRegistryKeys = @($regKeys)"
        
        # Write the new content
        $newContent | Set-Content $script.FullName -NoNewline
        
        Write-Host " OK" -ForegroundColor Green
        Write-Host "    PackageId: $packageId" -ForegroundColor Gray
        Write-Host "    Context: $context" -ForegroundColor Gray
        
    } catch {
        Write-Host " ERROR: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`nRegeneration complete!" -ForegroundColor Green
