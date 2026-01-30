<#
.SYNOPSIS
    Displays a graphical directory tree of files and folders tracked by Git.

.DESCRIPTION
    The git_treeview.ps1 script replicates the 'tree' command but uses 'git ls-files' as its data source.
    It shows only files and folders tracked in the current Git branch, ignoring untracked files,
    .gitignore entries, and artifacts from other branches.

.PARAMETER Path
    Specifies the starting path for the tree view. Defaults to the current directory.
    Must be within the Git repository.

.PARAMETER MaxDepth
    Sets the maximum depth of the directory tree to display. Defaults to unlimited.

.EXAMPLE
    .\git_treeview.ps1
    Shows the complete Git-tracked tree for the entire repository.

.EXAMPLE
    .\git_treeview.ps1 -Path .\src
    Shows the Git-tracked tree starting from the 'src' subfolder.

.EXAMPLE
    .\git_treeview.ps1 -MaxDepth 2
    Shows the Git-tracked tree for the repository, limited to two levels deep.

.NOTES
    Author: Mrflooglebinder
    Requires: Git must be installed and accessible in your system's PATH.
    Repository: https://github.com/Mrflooglebinder/git_treeview
#>
[CmdletBinding()]
param(
    [Parameter(Position=0, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
    [string]
    $Path = '.',

    [Parameter()]
    [int]
    $MaxDepth = [int]::MaxValue
)

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error "Git command not found. Please ensure Git is installed and in your system's PATH."
    return
}

$gitRootCmd = git rev-parse --show-toplevel 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Not a git repository (or any of the parent directories)."
    return
}
$gitRoot = $gitRootCmd.Trim()


try {
    $startPath = (Resolve-Path -Path $Path).ProviderPath.Replace('\', '/')

    if (-not $startPath.StartsWith($gitRoot)) {
        Write-Error "The specified path '$Path' is not inside the current Git repository located at '$gitRoot'."
        return
    }

    $gitFiles = git ls-files --full-name | ForEach-Object { $_.Replace('\', '/') }

    $gitDirs = New-Object System.Collections.Generic.HashSet[string]
    foreach ($file in $gitFiles) {
        $parent = Split-Path -Path $file -Parent
        while (-not [string]::IsNullOrEmpty($parent)) {
            [void]$gitDirs.Add($parent)
            $parent = Split-Path -Path $parent -Parent
        }
    }

    $dirCount = 0
    $fileCount = 0

    function Write-Tree {
        param(
            [string]$CurrentPath,
            [string]$Prefix,
            [int]$Depth
        )

        if ($Depth -ge $MaxDepth) {
            return
        }

        $relativePath = if ($CurrentPath.Length -gt $gitRoot.Length) {
            $CurrentPath.Substring($gitRoot.Length).TrimStart('/')
        } else {
            ""
        }
        
        $children = $gitFiles + $gitDirs |
                    Where-Object { (Split-Path -Path $_ -Parent) -eq $relativePath } |
                    Sort-Object |
                    Get-Unique

        if (-not $children) { return }

        $lastChild = $children[-1]

        foreach ($child in $children) {
            $isLast = ($child -eq $lastChild)
            $isDir = $gitDirs.Contains($child)
            $connector = if ($isLast) { "L-- " } else { "+-- " }
            $childPrefix = if ($isLast) { "    " } else { "|   " }
            $displayName = Split-Path -Path $child -Leaf
            Write-Host "$($Prefix)$($connector)$displayName"

            if ($isDir) {
                $script:dirCount++
                $fullChildPath = "$gitRoot/$child"
                Write-Tree -CurrentPath $fullChildPath -Prefix "$($Prefix)$($childPrefix)" -Depth ($Depth + 1)
            } else {
                $script:fileCount++
            }
        }
    }

    $displayRoot = if ($startPath -eq $gitRoot) { "." } else { $startPath.Substring($gitRoot.Length).TrimStart('/') }
    Write-Host $displayRoot
    
    Write-Tree -CurrentPath $startPath -Prefix "" -Depth 0

    Write-Host ""
    Write-Host "$($dirCount) directories, $($fileCount) files"

}
catch {
    Write-Error "An unexpected error occurred: $($_.Exception.Message)"
}
