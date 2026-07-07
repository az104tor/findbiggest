# findbiggets

A PowerShell script that quickly finds the largest files in a folder (or an entire drive) and exports a clean, sorted report — including file name, location, size, creation date, and last access date.

Built to be fast on large folder trees by using `robocopy` in list-only mode instead of `Get-ChildItem -Recurse`.

## Features

- **Fast scanning** — uses `robocopy /L` for enumeration, which is significantly faster than native PowerShell recursion on large   directory trees
- **Smart defaults** — scans your user profile folder out of the box, since that's usually where disk space disappears
- **Noise filtering** — skips common bloat folders like `AppData\Local\Temp`, `node_modules`, and `.git` by default
- **Human-readable sizes** — automatically scales output to B, KB, MB, GB, or TB
- **Live progress + timing** — shows scan progress as it runs and reports total elapsed time
- **Clean report file** — writes an ordered, readable report to a text file and opens it automatically

## Requirements

- Windows with PowerShell 7+
- `robocopy` (included by default on all modern Windows systems)

## Installation

Clone the repo or just download the script directly:

git clone https://github.com/az104tor/findbiggest.git
cd findbiggets


Or download `findbiggest.ps1` on its own and save it anywhere.

## Usage

Run with no arguments to scan your user profile folder and report the top 10 largest files:

.\findbiggest.ps1


Scan a specific folder or drive, change how many results to return, and set a custom output location:

.\findbiggest.ps1 -Path "D:\Projects" -Top 20 -OutputFile "D:\big-files-report.txt"

> **Note:** If your system blocks unsigned scripts, run PowerShell as Administrator and allow the script for the current session:
> Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass


### Parameters

| Parameter      | Type       | Default                                   | Description                                              |
|----------------|------------|--------------------------------------------|-----------------------------------------------------------|
| `-Path`        | `string`   | `$env:USERPROFILE`                        | Folder to scan                                            |
| `-Top`         | `int`      | `10`                                       | Number of largest files to report                         |
| `-OutputFile`  | `string`   | `$env:USERPROFILE\Desktop\LargestFiles.txt`| Path to save the report                                   |
| `-ExcludeDirs` | `string[]` | Temp, Packages, INetCache, CrashDumps, `node_modules`, `.git` | Folders to skip during the scan |

## Example output

```
Top 10 Largest Files in: C:\Users\jdoe
Generated: 07/06/2026 14:32:10
Total files scanned: 48213
Scan duration: 00:00:42
------------------------------------------------------------

Name                Directory                                   Size     Created              LastAccessed
----                ---------                                   ----     -------              ------------
backup_2024.zip      C:\Users\jdoe\Documents\Backups              14.20 GB 03/12/2024 09:15:22  07/01/2026 18:40:11
project_export.mp4   C:\Users\jdoe\Videos                          8.75 GB 11/22/2025 20:03:44  01/15/2026 10:12:03
disk_image.vhdx       C:\Users\jdoe\VMs                            6.10 GB 05/09/2025 13:27:55  06/30/2026 21:05:37
...
```

## How it works

The script shells out to `robocopy` with the `/L` flag (list only — nothing is ever copied) to enumerate files quickly, parses the size and path out of its output, sorts everything by file size, and pulls extra metadata (creation and last access time) for just the top results before writing the final report.

## License

MIT — feel free to use, modify, and share.

## Contributing

Issues and pull requests are welcome. If you have ideas for additional filters (file type, minimum size, multiple drives), feel free to open an issue.
