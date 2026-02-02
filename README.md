# Git Tree Dump

A PowerShell script that displays a Git-tracked directory tree **or** dumps the contents of Git-tracked files.  
It is driven entirely by `git ls-files`, ensuring only files tracked in the current Git branch are included.

This project started as **git_treeview** (tree-only). It has since been expanded to support file dumping and script-specific ignore rules.

---

## Features

* **Tree Mode:** Displays a clean, hierarchical view of Git-tracked files and directories.
* **Dump Mode:** Dumps the contents of Git-tracked files to the terminal (great for LLM context).
* Supports custom starting paths within the repository.
* Allows limiting output depth with `MaxDepth`.

* **Git-Aware:** Respects `.gitignore` automatically.
* **Custom Ignore:** Supports an additional script-specific ignore file: `.git_tree_dumpignore`.
* Counts and summarizes directories and files (Tree mode).
* **Flexible:** Supports custom starting paths and depth limits (`MaxDepth`).
* **Cross-Platform:** Handles paths correctly on Windows, Linux, and macOS.

---

## Prerequisites

* Git installed and available in `PATH`.
* PowerShell 5.1 or later.


## Installation

1. Clone the repository:

   ```powershell
   git clone https://github.com/Mrflooglebinder/git_tree_dump.git
   ```

2. Navigate to the repository folder:

    ```powershell
    cd .\path\to\git_tree_dump
    ```

3. Ensure `git_tree_dump.ps1` is accessible in your working directory.

## Usage

### Tree Mode (Default)

Displays a Git-tracked directory tree.

```powershell
.\git_tree_dump.ps1
```

   ```powershell
   .\git_tree_dump.ps1 -Path .\src
   ```

   ```powershell
   .\git_tree_dump.ps1 -MaxDepth 2
```

### Dump Mode

Prints the content of all tracked files that are not being filtered by `.gitignore` or `.git_tree_dumpignore`  

```powershell
.\git_tree_dump.ps1 -Mode Dump
```

```powershell
.\git_tree_dump.ps1 -Mode Dump -Path .\frontend -MaxDepth 3
```

Mode values are case-insensitive (`Tree`, `tree`, `Dump`, `dump`).

## Example Tree Output

```powershell
.
+-- .gitignore
+-- src
|   +-- main.py
|   L-- utils.py
+-- tests
|   L-- test_main.py
L-- README.md

2 directories, 4 files
```

## Ignore Behavior

**1. Standard `.gitignore`**
All Git ignore rules are respected automatically via `git check-ignore`.

**2. Custom `.git_tree_dumpignore`**
You may optionally define a script-specific ignore file at the repository root:

```powershell
.git_tree_dumpignore
```

This allows excluding files from the dump (like large assets or documentation) without modifying your actual `.gitignore`.

### Example

```powershell
# Local tooling
todo.md
setup.ps1

# Generated output
frontend/dist/

# Asset files
*.png
*.mp4
```

> Rules are evaluated after Git ignore rules.

## Parameters

| Parameter | Description | Default |
| :--- | :--- | :--- |
| `-Mode` | `Tree` or `Dump` | `Tree` |
| `-Path` | Starting path for tree or dump | `.` (Current Dir) |
| `-MaxDepth` | Maximum depth to display or dump | Unlimited |

## Notes  

* Must be run from within a Git repository.
* Output reflects the current branch only.
* The script is read-only and never modifies repository contents.
* Tags are used for versioning; releases are optional.

## Contributing

Contributions are welcome! Please:  

1. Fork the repository.
2. Create a feature branch (`git checkout -b feature/your-feature`).
3. Commit your changes (`git commit -m 'Add your feature'`).
4. Push to the branch (`git push origin feature/your-feature`).
5. Open a pull request.

> Focus on clear, well-documented changes. All PRs require maintainer approval.  

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Author

[**Mrflooglebinder**](https://github.com/Mrflooglebinder)
