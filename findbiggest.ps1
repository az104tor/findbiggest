# psys.ps1 - Unified system & network monitor for Windows
# Author: Salvatore Cristaudo
# Copyright (c) 2026 - MIT License
# Link: https://github.com/az104tor/findbiggest
# Post: https://netoncloud.com/findbiggets-ps1-finding-your-biggest-files-fast-with-powershell/
<#
.SYNOPSIS
    Finds the top N largest files in a directory (defaults to the current user's
    profile folder), using robocopy for fast enumeration, and exports the results
    (with directory, size, created, and last-accessed info) to a text file.

.PARAMETER Path
    Root folder to scan. Defaults to the current user's profile folder.

.PARAMETER Top
    How many largest files to report. Defaults to 10.

.PARAMETER OutputFile
    Where to save the report. Defaults to Desktop\LargestFiles.txt.

.PARAMETER ExcludeDirs
    Folder names/paths to skip (speeds up the scan and cuts noise).

.NOTES
    Uses robocopy in "list only" mode (/L) as a fast file enumerator — it never
    copies anything, it just walks the tree and prints what it finds, which is
    noticeably faster than Get-ChildItem -Recurse on large trees.
#>

param(
    [string]   $Path        = $env:USERPROFILE,
    [int]      $Top         = 10,
    [string]   $OutputFile  = "$env:USERPROFILE\Desktop\LargestFiles.txt",
    [string[]] $ExcludeDirs = @(
        "$env:USERPROFILE\AppData\Local\Temp",
        "$env:USERPROFILE\AppData\Local\Packages",
        "$env:USERPROFILE\AppData\Local\Microsoft\Windows\INetCache",
        "$env:USERPROFILE\AppData\Local\CrashDumps",
        "node_modules",
        ".git"
    )
)

# ----------- Helper: human-readable size -----------
function Format-Size {
    param([long]$Bytes)
    switch ($Bytes) {
        { $_ -ge 1TB } { return "{0:N2} TB" -f ($Bytes / 1TB) }
        { $_ -ge 1GB } { return "{0:N2} GB" -f ($Bytes / 1GB) }
        { $_ -ge 1MB } { return "{0:N2} MB" -f ($Bytes / 1MB) }
        { $_ -ge 1KB } { return "{0:N2} KB" -f ($Bytes / 1KB) }
        default        { return "$Bytes B" }
    }
}

Write-Host "Scanning $Path ..." -ForegroundColor Cyan
Write-Host "Excluding: $($ExcludeDirs -join ', ')" -ForegroundColor DarkGray

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

# ----------- Fast enumeration via robocopy -----------
# The destination folder must exist (even though nothing is ever copied there),
# otherwise robocopy can hang retrying "Accessing Destination Directory" errors.
$dummyDest = Join-Path $env:TEMP ("robocopy_dummy_" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $dummyDest -Force | Out-Null

# /L        = list only, never actually copies anything
# /S        = recurse into subdirectories (skips empty ones)
# /NJH /NJS = no job header / no job summary
# /NP       = no per-file percentage indicator (keeps output easy to parse)
# /FP       = print full path of each file
# /BYTES    = print sizes in bytes (not rounded KB)
# /R:0 /W:0 = don't retry on errors, don't wait between retries (avoids hangs)
# /XD       = exclude these directories (by name or full path)
$robocopyArgs = @($Path, $dummyDest, "/L", "/S", "/NJH", "/NJS", "/NP", "/FP", "/BYTES", "/R:0", "/W:0", "/XD") + $ExcludeDirs

$fileCounter = 0
$parsedFiles = New-Object System.Collections.Generic.List[PSObject]

# Robocopy prefixes each listed line with a tag (New File, *EXTRA File, etc.)
# since the dummy destination is empty. We don't anchor on the start of the
# line — just look for "<number> <whitespace> <drive-letter path>" anywhere.
$lineRegex = '(\d+)\s+([A-Za-z]:\\.+)$'

Write-Progress -Activity "Scanning $Path for files (via robocopy)" -Status "Starting..." -PercentComplete -1

robocopy @robocopyArgs | ForEach-Object {
    if ($_ -match $lineRegex) {
        $size     = [long]$Matches[1]
        $fullPath = $Matches[2].Trim()

        $parsedFiles.Add([PSCustomObject]@{
            FullName = $fullPath
            Length   = $size
        })

        $fileCounter++
        if ($fileCounter % 20 -eq 0) {
            Write-Progress -Activity "Scanning $Path for files (via robocopy)" `
                            -Status "Files found so far: $fileCounter" `
                            -CurrentOperation $fullPath `
                            -PercentComplete -1
        }
    }
}

Write-Progress -Activity "Scanning $Path for files (via robocopy)" -Completed
Remove-Item -Path $dummyDest -Force -Recurse -ErrorAction SilentlyContinue
$stopwatch.Stop()

Write-Host "Scan complete. Files found: $fileCounter | Elapsed: $($stopwatch.Elapsed.ToString('hh\:mm\:ss'))" -ForegroundColor Green

if ($fileCounter -eq 0) {
    Write-Warning "No files were found. Check that '$Path' exists and is accessible."
    return
}

Write-Host "Sorting and selecting the top $Top largest files..." -ForegroundColor Cyan

# ----------- Sort, take top N, pull extra metadata -----------
$topFiles = $parsedFiles | Sort-Object Length -Descending | Select-Object -First $Top

$results = foreach ($f in $topFiles) {
    $item = Get-Item -LiteralPath $f.FullName -ErrorAction SilentlyContinue
    if ($item) {
        [PSCustomObject][ordered]@{
            Name          = $item.Name
            Directory     = $item.DirectoryName
            Size          = Format-Size $item.Length
            Created       = $item.CreationTime
            LastAccessed  = $item.LastAccessTime
        }
    }
}

# ----------- Write report -----------
$header = @(
    "Top $Top Largest Files in: $Path"
    "Generated: $(Get-Date)"
    "Total files scanned: $fileCounter"
    "Scan duration: $($stopwatch.Elapsed.ToString('hh\:mm\:ss'))"
    ("-" * 60)
)

$header -join [Environment]::NewLine | Out-File -FilePath $OutputFile -Encoding UTF8
$results | Format-Table -AutoSize | Out-String -Width 300 | Out-File -FilePath $OutputFile -Append -Encoding UTF8

Write-Host "Done! Results saved to: $OutputFile" -ForegroundColor Green

notepad.exe $OutputFile
