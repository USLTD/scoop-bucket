# Aseprite Manifest Access Configuration

## Overview

The `aseprite` manifest in this bucket references the **intentionally private** repository `https://github.com/USLTD/aseprite-builds`. This repository remains private to comply with Aseprite's Terms of Service, which prohibit redistribution of compiled binaries.

### Build Process

The aseprite builds follow this workflow:
1. Detect new release in `aseprite/aseprite` (official public repository)
2. Execute `USLTD/aseprite-builder` (public) GitHub Action to compile from source
3. Upload compiled release to `USLTD/aseprite-builds` (private repository)

This approach complies with Aseprite's license while using GitHub's infrastructure.

### Current Status

- **Repository**: `https://github.com/USLTD/aseprite-builds` (Private - **Intentional**)
- **Access Status**: ❌ Not publicly accessible (by design)
- **Manifest Location**: `bucket/aseprite.json`
- **Authorized Users**: Bucket owner (Luka Mamukashvili / USLTD) and explicitly granted collaborators

### Public Access Test Results

Without authentication, the repository returns expected access denied errors:

```bash
# Testing repository access (expected to fail without auth)
curl -I "https://github.com/USLTD/aseprite-builds"
# Result: HTTP/1.1 404 Not Found (private repository)

# Testing release download (expected to fail without auth)
curl -I "https://github.com/USLTD/aseprite-builds/releases/download/v1.3.16/aseprite-v1.3.16-windows-x64.zip"
# Result: HTTP/1.1 404 Not Found (private repository)
```

**This is the expected and intended behavior.**

## Why Repository Must Remain Private

⚠️ **Legal Compliance**: Aseprite's Terms of Service prohibit redistribution of compiled binaries. The repository must remain private to ensure only authorized users can access the builds.

## Setup Instructions for Authorized Users

If you have been granted access to this private repository, follow these steps to configure Scoop for authenticated downloads:

### Step 1: Create a GitHub Personal Access Token (PAT)

1. Go to https://github.com/settings/tokens
2. Click **"Generate new token"** → **"Generate new token (classic)"**
3. Configure the token:
   - **Note**: `Scoop aseprite-builds access`
   - **Expiration**: Choose appropriate expiration (90 days or longer)
   - **Scopes**: Select `repo` (Full control of private repositories)
4. Click **"Generate token"**
5. **Copy the token immediately** (you won't be able to see it again)

### Step 2: Configure Git Credential Helper with Your Token

Scoop uses Git to download releases from GitHub. Configure Git to use your token for authentication:

**Option A: Using Git Credential Manager (Recommended for Windows)**

```powershell
# Install Git Credential Manager if not already installed
winget install Git.Git

# Configure git to use credential manager
git config --global credential.helper manager-core

# The next time you access the repository, you'll be prompted for credentials
# Username: your-github-username
# Password: paste-your-PAT-token
```

**Option B: Store Token in Git Config (Alternative)**

```powershell
# Store credentials in Git config (WARNING: Token stored in plain text)
git config --global credential.helper store

# Create credentials file manually
$credPath = "$env:USERPROFILE\.git-credentials"
$token = "ghp_YourTokenHere"  # Replace with your actual token
$url = "https://${token}@github.com"
Add-Content -Path $credPath -Value $url
```

**Option C: Configure URL with Embedded Token (Per-Repository)**

```powershell
# Configure git to use token for specific repository
git config --global url."https://${token}@github.com/USLTD/aseprite-builds".insteadOf "https://github.com/USLTD/aseprite-builds"
```

### Step 3: Test Authentication

Test that your authentication works:

```powershell
# Test access to private repository
git ls-remote https://github.com/USLTD/aseprite-builds

# Should list branches and tags instead of "Authentication failed"
```

### Step 4: Install Aseprite via Scoop

Once authentication is configured, you can install aseprite:

```powershell
# Add this bucket if you haven't already
scoop bucket add usltd https://github.com/USLTD/scoop-bucket

# Install aseprite (will use your configured Git credentials)
scoop install usltd/aseprite
```

### Step 5: Configure Automated Updates (Optional)

For the Excavator workflow to automatically check for updates:

1. Go to `https://github.com/USLTD/scoop-bucket/settings/secrets/actions`
2. Click **"New repository secret"**
3. **Name**: `ASEPRITE_BUILDS_TOKEN`
4. **Value**: Paste your PAT
5. Click **"Add secret"**

The Excavator workflow is already configured to use this token if available.

## Troubleshooting

### "Authentication failed" Error

If you see authentication errors:

1. Verify your PAT has the `repo` scope
2. Check that the token hasn't expired
3. Ensure you have access to the `USLTD/aseprite-builds` repository
4. Test authentication with: `git ls-remote https://github.com/USLTD/aseprite-builds`

### Downloads Still Failing

If downloads fail even with authentication configured:

1. Clear Scoop cache: `scoop cache rm aseprite`
2. Verify Git credential helper: `git config --global credential.helper`
3. Test manual download:
   ```powershell
   git clone https://github.com/USLTD/aseprite-builds test-auth
   # Should succeed without prompting if credentials are cached
   rm -r test-auth
   ```

### Token Security

**Important**: Never commit your GitHub token to version control. Use:
- Git Credential Manager (recommended)
- Environment variables
- Secure credential storage

## Testing Access

### For Authorized Users

Run the verification script with your credentials configured:

```powershell
pwsh scripts/verify-aseprite-access.ps1
```

If properly authenticated, some tests should pass (API access may still fail depending on token scope).

### For Unauthorized Users

If you don't have access to the private repository, this is intentional. The manifest includes a notice:

> "License Restriction: You may not use this package unless you are owner of this bucket, i.e. Luka Mamukashvili (USLTD)"

To request access, contact the bucket owner.

## Why Not Use nightly.link?

The `nightly.link` service (used by `fiddler-everywhere-patched` and `dnspyex-nightly` manifests) cannot be used for aseprite because:

1. **No Artifacts**: The build workflow in `USLTD/aseprite-builder` doesn't upload artifacts
2. **Direct Releases Only**: Builds are uploaded directly as releases to the private repository
3. **Intentional Design**: This prevents unauthorized access to compiled binaries

## License Compliance

This setup ensures compliance with Aseprite's Terms of Service:

- ✅ Binaries are compiled from official source code
- ✅ Binaries are not publicly distributed
- ✅ Only authorized users can access the builds
- ✅ Uses GitHub's unlimited Actions for compilation

## Additional Notes

- Aseprite is proprietary software with a paid license
- The builds are compiled from the official source repository
- Access is intentionally restricted to comply with licensing terms
- Users must have their own valid Aseprite license to use these builds

## Contact

For access requests or questions, contact the bucket maintainer: **Luka Mamukashvili (USLTD)**

