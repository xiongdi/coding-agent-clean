#Requires -Version 5.1
<#
.SYNOPSIS
    Reset coding agents to a "just installed" state by wiping local config/cache/auth/state.

.DESCRIPTION
    Reads agents.json (same directory) and deletes the local state of every coding agent
    found on this machine. Supports -DryRun (default), -Backup, project-local cleanup,
    and per-agent / per-category filtering.

    Safety: the default mode is DryRun. Pass -Apply to actually delete anything.

.PARAMETER Apply
    Actually delete/backup. Without this, only a dry-run is shown.

.PARAMETER Backup
    Move state to a timestamped backup directory instead of deleting.

.PARAMETER BackupDir
    Root directory for backups. Default: ./backups/<timestamp>/

.PARAMETER Agents
    Comma-separated list of agent ids to target (e.g. claude-code,cursor). Default: all.

.PARAMETER CloudToo
    Also list cloud-only agents (they are skipped by default).

.PARAMETER IncludeProjectLocal
    Also wipe project-local config (.clinerules, .cursor/rules, .continue, etc.) found
    under -ProjectRoots. Off by default because project-local files are often git-tracked.

.PARAMETER ProjectRoots
    Roots to scan for project-local config when -IncludeProjectLocal is set.
    Default: current directory.

.PARAMETER JsonPath
    Path to agents.json. Default: same directory as this script.

.EXAMPLE
    .\clean-agents.ps1                          # dry run, all agents
    .\clean-agents.ps1 -Apply                   # actually wipe everything found
    .\clean-agents.ps1 -Backup -Apply           # backup then wipe
    .\clean-agents.ps1 -Agents claude-code,cursor -Apply
    .\clean-agents.ps1 -IncludeProjectLocal -ProjectRoots C:\Users\ixion\workspace -Apply
#>
[CmdletBinding()]
param(
    [switch]$Apply,
    [switch]$Backup,
    [string]$BackupDir,
    [string[]]$Agents = @(),
    [switch]$CloudToo,
    [switch]$IncludeProjectLocal,
    [string[]]$ProjectRoots = @((Get-Location).Path),
    [string]$JsonPath = ''
)

$ErrorActionPreference = 'Stop'

# --- locate agents.json ---
if (-not $JsonPath) {
    $JsonPath = Join-Path $PSScriptRoot 'agents.json'
}
if (-not (Test-Path $JsonPath)) {
    Write-Error "agents.json not found at $JsonPath. Use -JsonPath to specify."
    exit 1
}
$scriptDir = Split-Path $JsonPath -Parent

$manifest = Get-Content $JsonPath -Raw | ConvertFrom-Json
$allAgents = $manifest.agents

# --- resolve env-var style paths on windows ---
function Expand-Path($template) {
    if ($null -eq $template) { return $null }
    $s = $template
    $s = $s -replace '%USERPROFILE%', $env:USERPROFILE
    $s = $s -replace '%APPDATA%', $env:APPDATA
    $s = $s -replace '%LOCALAPPDATA%', $env:LOCALAPPDATA
    if ($s.StartsWith('~/')) {
        $s = Join-Path $env:USERPROFILE ($s.Substring(2))
    } elseif ($s -eq '~') {
        $s = $env:USERPROFILE
    }
    return $s
}

# glob-aware existence check (returns matching paths or empty)
function Find-Paths($template) {
    $expanded = Expand-Path $template
    if ($null -eq $expanded) { return @() }
    $parent = Split-Path $expanded -Parent
    $leaf = Split-Path $expanded -Leaf
    if ($leaf -like '*`*' -or $leaf -like '*?*' -or $leaf -like '*[*]*') {
        if (-not (Test-Path $parent)) { return @() }
        $matches = Get-ChildItem -Path $parent -Filter $leaf -ErrorAction SilentlyContinue
        return @($matches | ForEach-Object { $_.FullName })
    } else {
        if (Test-Path $expanded) { return @($expanded) } else { return @() }
    }
}

# --- filter agents ---
$selected = $allAgents
if ($Agents.Count -gt 0) {
    # flatten in case someone passes "a,b" and "c" — split each on commas
    $ids = $Agents | ForEach-Object { $_.Split(',') } | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
    $selected = $allAgents | Where-Object { $ids -contains $_.id }
    $missing = $ids | Where-Object { $_ -notin $selected.id }
    if ($missing) {
        Write-Warning "Unknown agent id(s): $($missing -join ', ')"
    }
}

# --- banner ---
$mode = if ($Apply) { 'APPLY (changes will be made)' } else { 'DRY RUN (no changes)' }
$backupMsg = if ($Backup) { "  BACKUP: $BackupDir" } else { '' }
Write-Host ''
Write-Host '=========================================' -ForegroundColor Cyan
Write-Host " coding-agent-clean  ($mode)" -ForegroundColor Cyan
Write-Host " platform: Windows (PowerShell)" -ForegroundColor Cyan
Write-Host " agents.json: $JsonPath" -ForegroundColor Cyan
Write-Host '=========================================' -ForegroundColor Cyan
Write-Host ''

if (-not $Apply) {
    Write-Host 'Pass -Apply to actually delete. Showing what would be removed.' -ForegroundColor Yellow
    Write-Host ''
}

# --- backup root ---
$backupRoot = $null
if ($Apply -and $Backup) {
    if (-not $BackupDir) {
        $BackupDir = Join-Path $scriptDir ('backups\{0:yyyyMMdd_HHmmss}' -f (Get-Date))
    }
    $backupRoot = $BackupDir
    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
    Write-Host "Backup root: $backupRoot" -ForegroundColor Green
    Write-Host ''
}

function Remove-State($paths, $label) {
    foreach ($p in $paths) {
        if (-not (Test-Path $p)) { continue }
        $item = Get-Item $p -Force
        if ($backupRoot) {
            $dest = Join-Path $backupRoot ($label + '\' + ($item.Name))
            $destParent = Split-Path $dest -Parent
            New-Item -ItemType Directory -Path $destParent -Force | Out-Null
            try {
                Move-Item -Path $p -Destination $dest -Force
                Write-Host "  [moved] $p" -ForegroundColor Green
            } catch {
                Write-Host "  [ERROR] $p : $_" -ForegroundColor Red
            }
        } else {
            try {
                Remove-Item -Path $p -Recurse -Force
                Write-Host "  [removed] $p" -ForegroundColor Green
            } catch {
                Write-Host "  [ERROR] $p : $_" -ForegroundColor Red
            }
        }
    }
}

# --- process each agent ---
$summary = @()
$grandFound = 0
$grandRemoved = 0

foreach ($agent in $selected) {
    $id = $agent.id
    $name = $agent.name
    $isCloud = [bool]$agent.cloud_only

    if ($isCloud -and -not $CloudToo) {
        $summary += [pscustomobject]@{ Agent = $name; Id = $id; Status = 'cloud-only (skipped)' }
        continue
    }
    if ($isCloud -and $CloudToo) {
        $summary += [pscustomobject]@{ Agent = $name; Id = $id; Status = 'cloud-only (no local state)' }
        continue
    }

    $cats = $agent.categories
    $catStr = if ($cats) { $cats -join ', ' } else { '(none)' }

    Write-Host "[$name]" -ForegroundColor White
    Write-Host "  id: $id   categories: $catStr" -ForegroundColor Gray
    if ($agent.notes) { Write-Host "  note: $($agent.notes)" -ForegroundColor DarkGray }

    $foundPaths = @()

    # global paths for this platform
    $platformPaths = $agent.paths.windows
    if ($platformPaths) {
        foreach ($tpl in $platformPaths) {
            $foundPaths += Find-Paths $tpl
        }
    }

    # project-local paths
    if ($IncludeProjectLocal -and $agent.project_local) {
        foreach ($pr in $agent.project_local) {
            foreach ($root in $ProjectRoots) {
                $tpl = Join-Path $root $pr.path
                $foundPaths += Find-Paths $tpl
            }
        }
    }

    if ($foundPaths.Count -eq 0) {
        Write-Host "  -> not found on this machine" -ForegroundColor DarkGray
        $summary += [pscustomobject]@{ Agent = $name; Id = $id; Status = 'not found' }
        Write-Host ''
        continue
    }

    $grandFound += $foundPaths.Count
    Write-Host "  found $($foundPaths.Count) path(s):" -ForegroundColor Yellow
    foreach ($fp in $foundPaths) { Write-Host "    - $fp" -ForegroundColor DarkYellow }

    if ($Apply) {
        Remove-State -paths $foundPaths -label $id
        $grandRemoved += $foundPaths.Count
    }
    $summary += [pscustomobject]@{ Agent = $name; Id = $id; Status = "found $($foundPaths.Count)" }
    Write-Host ''
}

# --- summary ---
Write-Host '=========================================' -ForegroundColor Cyan
Write-Host ' summary' -ForegroundColor Cyan
Write-Host '=========================================' -ForegroundColor Cyan
$summary | Format-Table -AutoSize
if (-not $Apply) {
    Write-Host "Dry run complete. $grandFound path(s) would be removed. Pass -Apply to execute." -ForegroundColor Yellow
} else {
    Write-Host "Done. $grandRemoved path(s) removed." -ForegroundColor Green
    if ($backupRoot) { Write-Host "Backed up to: $backupRoot" -ForegroundColor Green }
}
