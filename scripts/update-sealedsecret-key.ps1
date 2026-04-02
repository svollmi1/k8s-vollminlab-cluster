#Requires -Version 5.1
<#
.SYNOPSIS
  Updates one or more keys in a Kubernetes Secret and re-seals the result. All other keys are preserved.

.DESCRIPTION
  Fetches the current secret from the cluster, replaces only the specified key(s) with new value(s),
  then re-seals with kubeseal and overwrites the SealedSecret YAML file in the repo.
  Contains no secrets or API keys; all sensitive values are passed at runtime via -KeyValues.
  Controller name/namespace match clusters/vollminlab-cluster/sealed-secrets/ in this repo.
  Requires: kubectl, kubeseal, and cluster access.
  Use -WhatIf to report what would be written without modifying the repo.

.EXAMPLE
  # Update a single key (e.g. Radarr API key in homepage-env-vars)
  .\scripts\update-sealedsecret-key.ps1 `
    -SecretName homepage-env-vars `
    -Namespace homepage `
    -KeyValues @{ RADARR_API_KEY = "your-new-key-from-radarr-settings" } `
    -SealedSecretPath "clusters\vollminlab-cluster\homepage\homepage\app\homepage-env-vars-sealedsecret.yaml"

.EXAMPLE
  # WhatIf: validate without writing
  .\scripts\update-sealedsecret-key.ps1 -SecretName homepage-env-vars -Namespace homepage `
    -KeyValues @{ RADARR_API_KEY = "key" } -SealedSecretPath "clusters\...\homepage-env-vars-sealedsecret.yaml" -WhatIf

.EXAMPLE
  # Update multiple keys in one run
  .\scripts\update-sealedsecret-key.ps1 `
    -SecretName my-secret `
    -Namespace my-ns `
    -KeyValues @{ KEY1 = "val1"; KEY2 = "val2" } `
    -SealedSecretPath "path\to\my-secret-sealedsecret.yaml"
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Name of the Secret in the cluster")]
    [string]$SecretName,

    [Parameter(Mandatory = $true, HelpMessage = "Namespace of the Secret")]
    [string]$Namespace,

    [Parameter(Mandatory = $true, HelpMessage = "Hashtable of key name(s) to new plaintext value(s). Only these keys are changed; all others preserved.")]
    [hashtable]$KeyValues,

    [Parameter(Mandatory = $true, HelpMessage = "Path to the SealedSecret YAML file in the repo (relative to repo root or absolute)")]
    [string]$SealedSecretPath,

    [Parameter(HelpMessage = "Sealed-secrets controller name (must match Helm releaseName in repo)")]
    [string]$ControllerName = "sealed-secrets-controller",

    [Parameter(HelpMessage = "Sealed-secrets controller namespace")]
    [string]$ControllerNamespace = "sealed-secrets",

    [Parameter(HelpMessage = "Run without writing to repo: sealed output goes to a temp file; use to validate the script.")]
    [switch]$DryRun,

    [Parameter(HelpMessage = "Allow adding keys that do not yet exist in the secret (in addition to updating existing ones).")]
    [switch]$AllowNewKeys,

    [Parameter(HelpMessage = "List of key names to remove from the secret entirely.")]
    [string[]]$RemoveKeys = @()
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
if (-not [System.IO.Path]::IsPathRooted($SealedSecretPath)) {
    $SealedSecretPath = Join-Path $RepoRoot $SealedSecretPath
}

$KeysToUpdate = @($KeyValues.Keys)
if ($KeysToUpdate.Count -eq 0) {
    Write-Error "KeyValues must contain at least one key."
}

# Never log or echo secret values
Write-Host "Fetching current secret '$SecretName' from namespace '$Namespace' (only $($KeysToUpdate -join ', ') will be changed)..."
$secretYamlRaw = kubectl get secret $SecretName -n $Namespace -o yaml 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to get secret. Is the cluster reachable and does the secret exist?"
}
$secretYaml = if ($secretYamlRaw -is [string]) { $secretYamlRaw } else { $secretYamlRaw | Out-String }
$secretYaml = $secretYaml -replace "`r`n", "`n" -replace "`r", "`n"

# Require data section and extract it (so we only consider secret data keys, not metadata keys like creationTimestamp)
$lines = $secretYaml -split "`n"
$inDataSection = $false
$dataSectionLines = [System.Collections.ArrayList]::new()
foreach ($line in $lines) {
    if ($line.Trim() -eq "data:") {
        $inDataSection = $true
        continue
    }
    if ($inDataSection) {
        # Data section entries are indented; stop at next top-level key (no leading space) or empty line
        if ($line -match "^\S" -or ($line -eq "" -and $dataSectionLines.Count -gt 0)) {
            break
        }
        if ($line -match "^\s+([A-Za-z0-9_]+)\s*:") {
            [void]$dataSectionLines.Add($line)
        }
    }
}
$dataSectionYaml = $dataSectionLines -join "`n"
if ($dataSectionLines.Count -eq 0) {
    Write-Error "Secret YAML has no 'data:' section or no keys under it; aborting."
}

# Discover keys present in secret data only (not metadata)
$dataLinePattern = "(?m)^\s+([A-Za-z0-9_]+)\s*:"
$keysBefore = [regex]::Matches($dataSectionYaml, $dataLinePattern) | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique
$newKeys = @()
foreach ($key in $KeysToUpdate) {
    if ($key -notin $keysBefore) {
        if (-not $AllowNewKeys) {
            Write-Error "Secret does not contain key '$key'. Use -AllowNewKeys to add new keys. Aborting."
        }
        $newKeys += $key
    }
}
foreach ($key in $KeysToUpdate) {
    if ($key -in $newKeys) { continue }  # new keys don't exist yet, skip count check
    $count = ([regex]::Matches($secretYaml, "(?m)^\s+$([regex]::Escape($key))\s*:")).Count
    if ($count -ne 1) {
        Write-Error "Expected exactly one line for key '$key'; found $count. Aborting."
    }
}

# Strip cluster-specific metadata only
$lines = $secretYaml -split "`n"
$out = [System.Collections.ArrayList]::new()
$skipKeys = @("resourceVersion", "uid", "creationTimestamp", "selfLink", "managedFields")
$inManagedFields = $false
foreach ($line in $lines) {
    if ($line -match "^\s+managedFields:\s*$") { $inManagedFields = $true; continue }
    if ($inManagedFields) {
        if ($line -match "^\s+\w" -and $line -notmatch "^\s{6,}") { $inManagedFields = $false }
        else { continue }
    }
    $shouldSkip = $false
    foreach ($k in $skipKeys) {
        if ($line -match "^\s+$([regex]::Escape($k))\s*:") { $shouldSkip = $true; break }
        if ($k -eq "managedFields" -and $line -match "^\s+managedFields") { $shouldSkip = $true; break }
    }
    if (-not $shouldSkip) { [void]$out.Add($line) }
}
$secretYaml = $out -join "`n"

# Verify no data keys were dropped by metadata strip (re-extract data section from stripped YAML)
$linesAfter = $secretYaml -split "`n"
$inDataSectionAfter = $false
$dataSectionLinesAfter = [System.Collections.ArrayList]::new()
foreach ($line in $linesAfter) {
    if ($line.Trim() -eq "data:") { $inDataSectionAfter = $true; continue }
    if ($inDataSectionAfter) {
        if ($line -match "^\S" -or ($line -eq "" -and $dataSectionLinesAfter.Count -gt 0)) { break }
        if ($line -match "^\s+([A-Za-z0-9_]+)\s*:") { [void]$dataSectionLinesAfter.Add($line) }
    }
}
$dataSectionYamlAfter = $dataSectionLinesAfter -join "`n"
$keysAfterStrip = [regex]::Matches($dataSectionYamlAfter, $dataLinePattern) | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique
foreach ($key in $keysBefore) {
    if ($key -notin $keysAfterStrip) {
        Write-Error "After stripping metadata, key '$key' is missing. Aborting to avoid breaking the secret."
    }
}

# Remove requested keys from the data section
foreach ($key in $RemoveKeys) {
    if ($key -notin $keysBefore) {
        Write-Warning "Key '$key' not found in secret — skipping removal."
        continue
    }
    $secretYaml = $secretYaml -replace "(?m)^\s+$([regex]::Escape($key))\s*:[^\n]*\n?", ""
    Write-Host "Removing key: $key"
}

# Append new keys to the data section (values never logged)
foreach ($key in $newKeys) {
    $newVal = $KeyValues[$key]
    $newB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($newVal))
    $secretYaml = $secretYaml -replace "(?m)^(data:)", "`$1`n  ${key}: $newB64"
    Write-Host "Adding new key: $key"
}

# Replace only the requested keys (values never logged)
foreach ($key in $KeysToUpdate) {
    if ($key -in $newKeys) { continue }  # already handled above
    $newVal = $KeyValues[$key]
    $newB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($newVal))
    $secretYaml = $secretYaml -replace "(?m)^(\s+$([regex]::Escape($key))\s*)[A-Za-z0-9+/=]+", "`${1}$newB64"
    $countAfter = ([regex]::Matches($secretYaml, "(?m)^\s+$([regex]::Escape($key))\s*:")).Count
    if ($countAfter -ne 1) {
        Write-Error "After replacing key '$key', line count is $countAfter (expected 1). Aborting."
    }
}


# Write to temp file for kubeseal (use .NET so -WhatIf does not skip this; only the repo write is gated)
$tempSecret = Join-Path $env:TEMP "sealedsecret-update-$([Guid]::NewGuid().ToString('N').Substring(0,8)).yaml"
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($tempSecret, $secretYaml, $utf8NoBom)

try {
    Write-Host "Re-sealing with kubeseal (controller: $ControllerNamespace/$ControllerName)..."
    $sealed = kubeseal --format yaml --controller-name=$ControllerName --controller-namespace=$ControllerNamespace -f $tempSecret 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "kubeseal failed: $sealed"
    }

    if ($DryRun) {
        $outPath = Join-Path $env:TEMP "sealedsecret-dryrun-$([Guid]::NewGuid().ToString('N').Substring(0,8)).yaml"
        Write-Host "[DryRun] Output will go to temp file (repo file unchanged): $outPath"
        $sealed | Set-Content -Path $outPath -Encoding utf8NoBOM
        Write-Host "[DryRun] Sealed output written to: $outPath (only $($KeysToUpdate -join ', ') would be changed; repo unchanged)."
    } elseif ($PSCmdlet.ShouldProcess($SealedSecretPath, "Write sealed secret")) {
        $sealed | Set-Content -Path $SealedSecretPath -Encoding utf8NoBOM
        Write-Host "Updated: $SealedSecretPath (only $($KeysToUpdate -join ', ') changed; all other keys unchanged)."
    } else {
        Write-Host "What if: Would write sealed secret to $SealedSecretPath (only $($KeysToUpdate -join ', ') would be changed)."
    }
}
finally {
    # Always remove temp file (use .NET so -WhatIf doesn't skip cleanup; avoid leaving secret on disk)
    try {
        if ([System.IO.File]::Exists($tempSecret)) { [System.IO.File]::Delete($tempSecret) }
    } catch { /* ignore */ }
}

if ($DryRun) {
    Write-Host "Dry run complete. No repo files were modified."
} elseif (-not $WhatIfPreference) {
    Write-Host "Done. Commit and push the file; after Flux applies it, restart any workload that uses this secret to pick up the new value(s)."
}
