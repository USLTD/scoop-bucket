#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Verify accessibility of aseprite-builds repository and its releases

.DESCRIPTION
    This script checks whether the private aseprite-builds repository
    is accessible and whether its releases can be downloaded.

.EXAMPLE
    .\verify-aseprite-access.ps1
    Run basic accessibility checks

.EXAMPLE
    .\verify-aseprite-access.ps1 -Verbose
    Run with detailed output
#>

[CmdletBinding()]
param()

# Configuration
$RepositoryOwner = "USLTD"
$RepositoryName = "aseprite-builds"
$ManifestPath = Join-Path $PSScriptRoot "..\bucket\aseprite.json"

# ANSI color codes for output
$Red = "`e[31m"
$Green = "`e[32m"
$Yellow = "`e[33m"
$Blue = "`e[34m"
$Reset = "`e[0m"

function Write-Status {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Type = 'Info'
    )

    $color = switch ($Type) {
        'Info'    { $Blue }
        'Success' { $Green }
        'Warning' { $Yellow }
        'Error'   { $Red }
    }

    $prefix = switch ($Type) {
        'Info'    { '[i]' }
        'Success' { '[✓]' }
        'Warning' { '[!]' }
        'Error'   { '[✗]' }
    }

    Write-Host "$color$prefix $Message$Reset"
}

function Test-UrlAccessibility {
    param(
        [string]$Url,
        [string]$Description
    )

    Write-Status "Testing: $Description" -Type Info
    Write-Verbose "URL: $Url"

    try {
        $response = Invoke-WebRequest -Uri $Url -Method Head -MaximumRedirection 5 -ErrorAction Stop

        if ($response.StatusCode -eq 200 -or $response.StatusCode -eq 302) {
            Write-Status "✓ Accessible (HTTP $($response.StatusCode))" -Type Success
            return $true
        } else {
            Write-Status "? Unexpected status code: $($response.StatusCode)" -Type Warning
            return $false
        }
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode.Value__

        if ($statusCode -eq 404) {
            Write-Status "✗ Not Found (HTTP 404) - Repository or release is private/inaccessible" -Type Error
        }
        elseif ($statusCode -eq 403) {
            Write-Status "✗ Forbidden (HTTP 403) - Authentication required" -Type Error
        }
        else {
            Write-Status "✗ Error: $($_.Exception.Message)" -Type Error
        }

        Write-Verbose "Full error: $_"
        return $false
    }
}

# Main execution
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Aseprite Repository Access Verification" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Check if manifest exists
if (-not (Test-Path $ManifestPath)) {
    Write-Status "Manifest not found at: $ManifestPath" -Type Error
    exit 1
}

# Read manifest
Write-Status "Reading manifest from: $ManifestPath" -Type Info
$manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json

# Extract version and URLs
$version = $manifest.version
$url64 = $manifest.architecture.'64bit'.url
$url32 = $manifest.architecture.'32bit'.url

Write-Host "`nManifest Information:" -ForegroundColor Cyan
Write-Host "  Version: $version"
Write-Host "  64-bit URL: $url64"
Write-Host "  32-bit URL: $url32"
Write-Host ""

# Test repository page
Write-Host "`n1. Testing Repository Page" -ForegroundColor Yellow
Write-Host "----------------------------------------"
$repoUrl = "https://github.com/$RepositoryOwner/$RepositoryName"
$repoAccessible = Test-UrlAccessibility -Url $repoUrl -Description "Repository home page"

# Test releases page
Write-Host "`n2. Testing Releases Page" -ForegroundColor Yellow
Write-Host "----------------------------------------"
$releasesUrl = "$repoUrl/releases"
$releasesAccessible = Test-UrlAccessibility -Url $releasesUrl -Description "Releases page"

# Test specific release assets
Write-Host "`n3. Testing Release Assets" -ForegroundColor Yellow
Write-Host "----------------------------------------"
$asset64Accessible = Test-UrlAccessibility -Url $url64 -Description "64-bit release asset ($version)"
$asset32Accessible = Test-UrlAccessibility -Url $url32 -Description "32-bit release asset ($version)"

# Test GitHub API access
Write-Host "`n4. Testing GitHub API Access" -ForegroundColor Yellow
Write-Host "----------------------------------------"

$apiUrl = "https://api.github.com/repos/$RepositoryOwner/$RepositoryName"
Write-Status "Testing: GitHub API repository endpoint" -Type Info

$headers = @{
    'Accept' = 'application/vnd.github.v3+json'
}

# Add token if available
$token = $env:GITHUB_TOKEN
if ($token) {
    $headers['Authorization'] = "token $token"
    Write-Verbose "Using GITHUB_TOKEN from environment"
}

try {
    $apiResponse = Invoke-RestMethod -Uri $apiUrl -Headers $headers -ErrorAction Stop
    Write-Status "✓ API accessible - Repository exists" -Type Success
    Write-Host "  Repository: $($apiResponse.full_name)"
    Write-Host "  Private: $($apiResponse.private)"
    Write-Host "  Visibility: $($apiResponse.visibility)"
    $apiAccessible = $true
}
catch {
    $statusCode = $_.Exception.Response.StatusCode.Value__

    if ($statusCode -eq 404) {
        Write-Status "✗ Repository not found or not accessible via API" -Type Error
    }
    elseif ($statusCode -eq 403) {
        Write-Status "✗ API access forbidden - Token may lack permissions" -Type Error
    }
    else {
        Write-Status "✗ API Error: $($_.Exception.Message)" -Type Error
    }

    $apiAccessible = $false
}

# Test release API
Write-Status "Testing: GitHub API releases endpoint" -Type Info

$releasesApiUrl = "https://api.github.com/repos/$RepositoryOwner/$RepositoryName/releases"

try {
    $releasesResponse = Invoke-RestMethod -Uri $releasesApiUrl -Headers $headers -ErrorAction Stop
    Write-Status "✓ Releases API accessible - Found $($releasesResponse.Count) releases" -Type Success

    if ($releasesResponse.Count -gt 0) {
        Write-Host "`n  Latest releases:"
        $releasesResponse | Select-Object -First 5 | ForEach-Object {
            Write-Host "    - $($_.tag_name) (published: $($_.published_at))"
        }

        # Check if our version exists
        $targetRelease = $releasesResponse | Where-Object { $_.tag_name -eq $version }
        if ($targetRelease) {
            Write-Status "✓ Found release for version $version" -Type Success
            Write-Host "    Assets:"
            $targetRelease.assets | ForEach-Object {
                Write-Host "      - $($_.name) ($([math]::Round($_.size/1MB, 2)) MB)"
            }
        }
        else {
            Write-Status "✗ Version $version not found in releases" -Type Warning
        }
    }

    $releasesApiAccessible = $true
}
catch {
    $statusCode = $_.Exception.Response.StatusCode.Value__
    Write-Status "✗ Releases API error (HTTP $statusCode)" -Type Error
    $releasesApiAccessible = $false
}

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$results = @(
    @{ Name = "Repository Page"; Status = $repoAccessible }
    @{ Name = "Releases Page"; Status = $releasesAccessible }
    @{ Name = "64-bit Asset"; Status = $asset64Accessible }
    @{ Name = "32-bit Asset"; Status = $asset32Accessible }
    @{ Name = "GitHub API"; Status = $apiAccessible }
    @{ Name = "Releases API"; Status = $releasesApiAccessible }
)

$successCount = ($results | Where-Object { $_.Status -eq $true }).Count
$totalCount = $results.Count

foreach ($result in $results) {
    $status = if ($result.Status) { "${Green}✓ PASS${Reset}" } else { "${Red}✗ FAIL${Reset}" }
    Write-Host "  $($result.Name): $status"
}

Write-Host "`nOverall: $successCount/$totalCount checks passed" -ForegroundColor $(if ($successCount -eq $totalCount) { "Green" } else { "Yellow" })

# Recommendations
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Recommendations" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

if (-not $asset64Accessible -or -not $asset32Accessible) {
    Write-Host "❌ Release assets are NOT accessible"
    Write-Host ""
    Write-Host "To fix this issue, choose one of the following options:"
    Write-Host ""
    Write-Host "  Option 1 (Recommended): Make releases public"
    Write-Host "    • Go to: https://github.com/$RepositoryOwner/$RepositoryName/settings"
    Write-Host "    • Ensure releases are accessible even if repository is private"
    Write-Host "    • GitHub allows public release assets in private repositories"
    Write-Host ""
    Write-Host "  Option 2: Configure authentication"
    Write-Host "    • Set up GITHUB_TOKEN with repository access"
    Write-Host "    • Add token to: https://github.com/$env:GITHUB_REPOSITORY/settings/secrets/actions"
    Write-Host "    • Update workflows to pass token to Scoop"
    Write-Host ""
    Write-Host "  Option 3: Use GitHub Actions artifacts"
    Write-Host "    • Use nightly.link service for automated builds"
    Write-Host "    • See: fiddler-everywhere-patched.json for example"
    Write-Host ""
    Write-Host "For detailed instructions, see: ASEPRITE_ACCESS_SETUP.md"
}
else {
    Write-Host "✅ All release assets are accessible!"
    Write-Host ""
    Write-Host "The manifest should work correctly for users."
}

# Exit with appropriate code
exit $(if ($asset64Accessible -and $asset32Accessible) { 0 } else { 1 })
