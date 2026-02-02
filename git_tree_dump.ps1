<#
.SYNOPSIS
    Git-tracked tree view OR dump file contents, driven by the Git tree (no hardcoded list).

.DESCRIPTION
    Mode Tree : Prints a directory tree using `git ls-files` as the source.
    Mode Dump : Prints the contents of every Git-tracked file under -Path.
                Respects .gitignore and an optional repo-root .git_tree_dumpignore file.

.PARAMETER Mode
    Tree  = Hierarchical view (Default)
    Dump  = File content dump
    (Case-insensitive)

.PARAMETER Path
    Starting path (must be inside the Git repo). Defaults to current directory.

.PARAMETER MaxDepth
    Max depth for both Tree and Dump. Defaults to unlimited.

.EXAMPLE
    .\git_tree_dump.ps1
    (defaults to Tree)

.EXAMPLE
    .\git_tree_dump.ps1 -Mode Dump -Path .\frontend -MaxDepth 3

.NOTES
    Script:     git_tree_dump.ps1
    Author:     MrFlooglebinder
    License:    MIT License
    Source:     https://github.com/MrFlooglebinder/git_tree_dump
    Copyright:  (c) 2026 MrFlooglebinder
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string] $Mode = 'Tree',

    [Parameter(Position=0, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
    [string] $Path = '.',

    [Parameter()]
    [int] $MaxDepth = [int]::MaxValue
)

if ([string]::IsNullOrWhiteSpace($Mode)) { $Mode = 'Tree' }
$ModeLower = $Mode.ToLowerInvariant()
switch ($ModeLower) {
    'tree' { $Mode = 'Tree' }
    'dump' { $Mode = 'Dump' }
    default {
        Write-Error "Invalid Mode '$Mode'. Valid values are: Tree or Dump."
        return
    }
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error "Git command not found. Please ensure Git is installed and in your system's PATH."
    return
}

$gitRootCmd = git rev-parse --show-toplevel 2>$null
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($gitRootCmd)) {
    Write-Error "Not a git repository (or any of the parent directories)."
    return
}
$gitRoot = $gitRootCmd.Trim().Replace('\', '/')

$ScriptIgnoreFile = ".git_tree_dumpignore"

# --- Helper Functions ---
function Get-RepoRelativePath {
    param([string] $AbsolutePath)
    if ($null -eq $AbsolutePath) { $AbsolutePath = '' }

    $p = $AbsolutePath.Replace('\', '/')
    if ($p.Length -gt $gitRoot.Length) {
        return $p.Substring($gitRoot.Length).TrimStart('/')
    }
    return ""
}

function Get-DepthFromRelativePath {
    param([string] $RelativePath)
    if ([string]::IsNullOrEmpty($RelativePath)) { return 0 }
    return ($RelativePath -split '/').Count
}

function Get-GitFiles {
    param([string] $StartPathAbs)

    $startRel = Get-RepoRelativePath -AbsolutePath $StartPathAbs

    $files = git ls-files --full-name |
        ForEach-Object { $_.Replace('\', '/') } |
        Where-Object {
            if ([string]::IsNullOrEmpty($startRel)) { $true }
            else { $_ -eq $startRel -or $_.StartsWith("$startRel/") }
        }

    [pscustomobject]@{
        Files    = @($files)
        StartRel = $startRel
    }
}

function Filter-GitIgnoredPaths {
    param([string[]] $RelativePaths)

    if (-not $RelativePaths -or $RelativePaths.Count -eq 0) { return @() }

    $ignored = New-Object System.Collections.Generic.HashSet[string]

    $out = $RelativePaths | git check-ignore --stdin 2>$null
    if ($LASTEXITCODE -eq 0 -and $out) {
        foreach ($line in $out) {
            if ($null -eq $line) { continue }
            $p = $line.Trim().Replace('\', '/')
            if (-not [string]::IsNullOrEmpty($p)) { [void]$ignored.Add($p) }
        }
    }

    $RelativePaths | Where-Object { -not $ignored.Contains($_) }
}

function Filter-ScriptIgnoredPaths {
    param(
        [string[]] $RelativePaths,
        [string]   $RepoRoot
    )

    if (-not $RelativePaths -or $RelativePaths.Count -eq 0) { return @() }

    $ignorePath = Join-Path ($RepoRoot -replace '/', '\') $ScriptIgnoreFile
    if (-not (Test-Path $ignorePath)) { return $RelativePaths }

    $rules = Get-Content $ignorePath |
        Where-Object { $_ -ne $null } |
        ForEach-Object { $_.ToString() } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Where-Object { -not $_.Trim().StartsWith('#') } |
        ForEach-Object { $_.Trim().Replace('\', '/') }

    $rules = @($rules)
    if (-not $rules -or $rules.Count -eq 0) { return $RelativePaths }

    $RelativePaths | Where-Object {
        $path = $_
        foreach ($rule in $rules) {
            if ([string]::IsNullOrWhiteSpace($rule)) { continue }

            if ($rule.EndsWith('/')) {
                if ($path.StartsWith($rule)) { return $false }
            }
            elseif ($rule -like '*[*?]*') {
                if ($path -like $rule) { return $false }
            }
            else {
                if ($path -eq $rule) { return $false }
            }
        }
        return $true
    }
}

function Build-DirsFromFiles {
    param([string[]] $RelativeFiles)

    $dirs = New-Object System.Collections.Generic.HashSet[string]
    foreach ($file in @($RelativeFiles)) {
        if ([string]::IsNullOrWhiteSpace($file)) { continue }

        $parent = Split-Path -Path $file -Parent
        while (-not [string]::IsNullOrEmpty($parent)) {
            [void]$dirs.Add($parent.Replace('\', '/'))
            $parent = Split-Path -Path $parent -Parent
        }
    }
    $dirs
}

function Apply-DepthLimit {
    param(
        [string[]] $RelativeFiles,
        [string]   $BaseRel
    )

    if ($MaxDepth -eq [int]::MaxValue) { return $RelativeFiles }

    $baseDepth = Get-DepthFromRelativePath -RelativePath $BaseRel
    $RelativeFiles | Where-Object {
        $d = (Get-DepthFromRelativePath -RelativePath $_) - $baseDepth
        $d -le $MaxDepth
    }
}

# --- Main ---
try {
    $startPathAbs = (Resolve-Path -Path $Path).ProviderPath.Replace('\', '/')

    if (-not $startPathAbs.StartsWith($gitRoot)) {
        Write-Error "The specified path '$Path' is not inside the current Git repository located at '$gitRoot'."
        return
    }

    $data = Get-GitFiles -StartPathAbs $startPathAbs
    $startRel = $data.StartRel

    $gitFiles = @($data.Files)
    $gitFiles = Filter-GitIgnoredPaths -RelativePaths $gitFiles
    $gitFiles = Filter-ScriptIgnoredPaths -RelativePaths $gitFiles -RepoRoot $gitRoot

    $gitDirs = Build-DirsFromFiles -RelativeFiles $gitFiles

    $script:gitFiles = @($gitFiles)
    $script:gitDirs = $gitDirs
    if ($null -eq $script:gitDirs) { $script:gitDirs = New-Object System.Collections.Generic.HashSet[string] }

    $dirCount = 0
    $fileCount = 0

    function Write-Tree {
        param(
            [string] $CurrentPathAbs,
            [string] $Prefix,
            [int]    $Depth
        )

        if ($Depth -ge $MaxDepth) { return }

        $relativePath = Get-RepoRelativePath -AbsolutePath $CurrentPathAbs

        $children = @($script:gitFiles) + @([string[]]$script:gitDirs) |
            Where-Object { $_ -and (Split-Path -Path $_ -Parent).Replace('\','/') -eq $relativePath } |
            Sort-Object |
            Get-Unique

        if (-not $children) { return }

        $children = @($children)
        $lastChild = $children[-1]

        foreach ($child in $children) {
            if ([string]::IsNullOrWhiteSpace($child)) { continue }

            $isLast = ($child -eq $lastChild)
            $isDir = $script:gitDirs.Contains($child)
            $connector = if ($isLast) { "L-- " } else { "+-- " }
            $childPrefix = if ($isLast) { "    " } else { "|   " }
            $displayName = Split-Path -Path $child -Leaf

            Write-Host "$($Prefix)$($connector)$displayName"

            if ($isDir) {
                $script:dirCount++
                $fullChildAbs = "$gitRoot/$child"
                Write-Tree -CurrentPathAbs $fullChildAbs -Prefix "$($Prefix)$($childPrefix)" -Depth ($Depth + 1)
            } else {
                $script:fileCount++
            }
        }
    }

    # --- Mode: Tree ---
    if ($Mode -eq 'Tree') {
        $displayRoot = if ($startPathAbs -eq $gitRoot) { "." } else { (Get-RepoRelativePath -AbsolutePath $startPathAbs) }
        Write-Host $displayRoot
        Write-Tree -CurrentPathAbs $startPathAbs -Prefix "" -Depth 0
        Write-Host ""
        Write-Host "$($dirCount) directories, $($fileCount) files"
        return
    }

    # --- Mode: Dump ---
    $dumpFiles = Apply-DepthLimit -RelativeFiles $script:gitFiles -BaseRel $startRel

    $foundFiles = @()
    $notFoundFiles = @()

    Write-Host ("`n" * 1)

    foreach ($rel in ($dumpFiles | Sort-Object)) {
        $abs = Join-Path ($gitRoot -replace '/', '\') ($rel -replace '/', '\')
        if (Test-Path $abs) {
            Write-Host "--- START OF FILE: " -ForegroundColor Blue -NoNewline
            Write-Host $rel -ForegroundColor Green -NoNewline
            Write-Host " ---" -ForegroundColor Blue

            Get-Content -Path $abs -Raw

            Write-Host "`n--- END OF FILE ---`n" -ForegroundColor Blue
            $foundFiles += $rel
        } else {
            Write-Host "--- WARNING: File not found at path: " -ForegroundColor Yellow -NoNewline
            Write-Host $rel -ForegroundColor Red -NoNewline
            Write-Host " ---`n" -ForegroundColor Yellow
            $notFoundFiles += $rel
        }
    }

    Write-Host "`n--- SUMMARY REPORT ---" -ForegroundColor Cyan
    foreach ($f in $foundFiles) {
        Write-Host "Success:--- " -ForegroundColor Blue -NoNewline
        Write-Host $f -ForegroundColor Green
    }
    foreach ($f in $notFoundFiles) {
        Write-Host "Fail:------ " -ForegroundColor Yellow -NoNewline
        Write-Host $f -ForegroundColor Red
    }
}
catch {
    $pos = $null
    if ($_.InvocationInfo -and $_.InvocationInfo.PositionMessage) { $pos = $_.InvocationInfo.PositionMessage.Trim() }
    if ($pos) {
        Write-Error "An unexpected error occurred: $($_.Exception.Message)`n$pos"
    } else {
        Write-Error "An unexpected error occurred: $($_.Exception.Message)"
    }
}
