# Git Tree Dump

A PowerShell script that displays a Git-tracked directory tree **or** dumps the contents of Git-tracked files.  
It is driven entirely by `git ls-files`, ensuring only files tracked in the current Git branch are included.

This project started as **git_treeview** (tree-only). It has since been expanded to support file dumping and script-specific ignore rules.

---

## Features

- Displays a clean, hierarchical view of Git-tracked files and directories (**Tree mode**).
- Dumps the contents of Git-tracked files to the terminal (**Dump mode**).
- Supports custom starting paths within the repository.
- Allows limiting output depth with `MaxDepth`.
- Respects `.gitignore` automatically.
- Supports an additional script-specific ignore file: `.git_tree_dumpignore`.
- Counts and summarizes directories and files (Tree mode).
- Cross-platform path handling (Windows / Linux / macOS).

---

## Prerequisites

- Git installed and available in `PATH`.
- PowerShell 5.1 or later.

---

## Installation

1. Clone the repository:

   ```powershell
   git clone https://github.com/your-username/git_tree_dump.git
   ```

2. Navigate to the repository folder:

   ```powershell
   cd git_tree_dump_
   ```

3. Ensure `git_tree_dump.ps1` is accessible in your working directory.

## Usage

### Tree mode (default)

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

### Dump mode

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

`.gitignore`

All Git ignore rules are respected automatically via `git check-ignore`.

`.git_tree_dumpignore`

You may optionally define a script-specific ignore file at the repository root:

```powershell
.git_tree_dumpignore
```

This allows excluding files and folders without modifying `.gitignore`.

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

Rules are evaluated after Git ignore rules.

## Parameters

- `-Mode`
  - `Tree` (default) or `Dump`
- `-Path`
  - Starting path for tree or dump (default: .)
- `-MaxDepth`
  - Maximum depth to display or dump (default: unlimited)

## Notes  

- Must be run from within a Git repository.
- Output reflects the current branch only.
- The script is read-only and never modifies repository contents.
- Tags are used for versioning; releases are optional.

## Contributing

Contributions are welcome! Please:

1. Fork the repository.
2. Create a feature branch (`git checkout -b feature/your-feature`).
3. Commit your changes (`git commit -m 'Add your feature'`).
4. Push to the branch (`git push origin feature/your-feature`).
5. Open a pull request.

## License

This project is licensed under the GPL-3.0 license. See the [LICENSE](LICENSE) file for details.

## Author

Mrflooglebinder
