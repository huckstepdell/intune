# PackageGenerator

A PowerShell-based tool for creating Microsoft Intune packages (`.intunewin` files) from source installers. This tool provides an interactive menu system to select applications and versions for packaging.

## Prerequisites

### Required Files

**⚠️ IMPORTANT:** You must add `IntuneWinAppUtil.exe` to this folder before using the script.

1. **IntuneWinAppUtil.exe** - The Microsoft Intune Win32 App Packaging Tool
   - Download from: [Microsoft/Microsoft-Win32-Content-Prep-Tool](https://github.com/Microsoft/Microsoft-Win32-Content-Prep-Tool)
   - Place the executable in: `PackageGenerator\IntuneWinAppUtil.exe`
   - This tool converts application source files into the `.intunewin` format for Intune deployment

### Directory Structure

The script uses relative paths and can be located anywhere on your system. It expects the following structure within the repository:
```
intune\                      # Repository root (can be anywhere)
├── installers\              # Source installer files
│   ├── Microsoft\RSAT\      # (tracked in Git)
│   ├── Template\            # (tracked in Git)
│   ├── winget\              # (tracked in Git)
│   └── YourApps\            # You add your own apps here (not tracked)
└── PackageGenerator\
    ├── Create-IntunePackage.ps1
    ├── IntuneWinAppUtil.exe  # ← ADD THIS FILE (not tracked in Git)
    └── config\
        ├── winget-package.json
        └── ...              # You add config files for your apps
```

## Usage

### Running the Script

1. Open PowerShell
2. Navigate to the PackageGenerator folder:
   ```powershell
   cd <path-to-repo>\PackageGenerator
   ```
3. Run the packaging script:
   ```powershell
   .\Create-IntunePackage.ps1
   ```

### Interactive Menu

The script will guide you through the packaging process:

1. **Select Application**: Choose from a list of configured applications
2. **Select Version**: Choose the version to package (e.g., latest, v8, v9, v10)
3. **Packaging**: The script automatically packages the selected installer
4. **Output**: The `.intunewin` package is created in the application's `package` folder

### Example Workflow

```
Select an application:
1. Winget Package Manager
2. Your Application
3. Another App
...
Enter the number of your selection (1-3) [default: 1]: 1

Selected app: Winget Package Manager

Select a version for Winget Package Manager:
1. latest
Enter the number of your selection (1-1) [default: 1]: 1

Installer path: <repo-root>\installers\winget\source\install-winget-package.ps1
Source directory: <repo-root>\installers\winget\source
Package output directory: <repo-root>\installers\winget\package

Creating package for Winget Package Manager version latest...
Running packager...
Package created successfully!
Package file: <repo-root>\installers\winget\package\install-winget-package.intunewin
```

## Configuration Files

Configuration files are stored in the `config\` folder as JSON files. Each file defines an application and its available versions for packaging.

### Configuration Format

```json
{
  "name": "Application Name",
  "downloadUrl": "https://vendor.com/download/",
  "versions": {
    "version-name": "relative\\path\\to\\installer\\source\\setup.exe"
  }
}
```

### Fields

- **name** (required): Display name of the application
- **downloadUrl** (optional): URL where the installer can be downloaded
- **versions** (required): Object mapping version names to installer paths
  - Keys: Version identifiers (e.g., "latest", "v8", "v9")
  - Values: Relative paths from the `installers\` directory to the setup file

### Example Configurations

#### Generic Winget Package (Included in Repo)
```json
{
  "name": "Winget Package Manager",
  "downloadUrl": "",
  "versions": {
    "latest": "winget\\source\\install-winget-package.ps1"
  }
}
```

#### Single Version Application
```json
{
  "name": "Your Application",
  "downloadUrl": "https://vendor.com/download/",
  "versions": {
    "latest": "YourApp\\source\\setup.exe"
  }
}
```

#### Multi-Version Application
```json
{
  "name": "Your Multi-Version App",
  "downloadUrl": "https://vendor.com/download/",
  "versions": {
    "3.0": "YourApp\\3.0\\source\\setup.exe",
    "2.5": "YourApp\\2.5\\source\\setup.exe",
    "2.0": "YourApp\\2.0\\source\\setup.exe"
  }
}
```

## Adding New Applications

To add a new application to the packaging system:

1. Create the installer directory structure:
   ```
   installers\
   └── YourApp\
       ├── package\      # Output folder (auto-created)
       └── source\       # Place installer files here
           └── setup.exe
   ```

2. Create a configuration file in `PackageGenerator\config\`:
   ```powershell
   # config\yourapp.json
   {
     "name": "Your Application",
     "downloadUrl": "https://example.com/download",
     "versions": {
       "latest": "YourApp\\source\\setup.exe"
     }
   }
   ```

3. Run `Create-IntunePackage.ps1` and select your new application

## How It Works

1. **Configuration Loading**: Reads all JSON files from the `config\` folder
2. **User Selection**: Presents an interactive menu for application and version selection
3. **Path Resolution**: Constructs full paths to source files and output directories
4. **Packaging**: Invokes `IntuneWinAppUtil.exe` with the following parameters:
   - `-c`: Source directory containing the installer
   - `-s`: Setup file name (installer executable)
   - `-o`: Output directory for the `.intunewin` package
   - `-q`: Quiet mode (minimal output)
5. **Validation**: Confirms the `.intunewin` file was created successfully

## Output

Packaged files are created in the corresponding `package\` folder for each application:

```
installers\
└── winget\                  # Example: the winget package
    ├── package\
    │   └── install-winget-package.intunewin  # ← Created here
    └── source\
        ├── install-winget-package.ps1
        └── uninstall-winget-package.ps1
```

**Note**: `.intunewin` packages are not tracked in Git (excluded by `.gitignore`).

## Troubleshooting

### IntuneWinAppUtil.exe not found
```
Error: IntuneWinAppUtil.exe not found at: <repo-root>\PackageGenerator\IntuneWinAppUtil.exe
```
**Solution**: Download and place `IntuneWinAppUtil.exe` in the PackageGenerator folder.

### Configuration directory not found
```
Error: Configuration directory not found: <repo-root>\PackageGenerator\config
```
**Solution**: Ensure the `config\` folder exists with at least one valid JSON configuration file.

### Installer not found
```
Error: Installer not found at: <repo-root>\installers\...
```
**Solution**: Verify the path in the configuration file matches the actual location of the installer.

### No .intunewin file found
```
No .intunewin file found in output directory.
```
**Solution**: Check that IntuneWinAppUtil.exe ran successfully. Review the packager output for errors.

## Requirements

- **PowerShell 5.1+** or **PowerShell 7+**
- **Windows** operating system
- **IntuneWinAppUtil.exe** (must be downloaded separately)
- Source installer files in the `installers\` directory

## Script Details

- **Script**: `Create-IntunePackage.ps1`
- **Language**: PowerShell
- **Error Handling**: Stops on all errors (`$ErrorActionPreference = "Stop"`)
- **Input**: Interactive menu selection
- **Output**: `.intunewin` packages in application-specific `package\` folders

## Related Tools

- [Microsoft Win32 Content Prep Tool](https://github.com/Microsoft/Microsoft-Win32-Content-Prep-Tool)
- [Microsoft Intune Documentation](https://docs.microsoft.com/en-us/mem/intune/)
- [PSAppDeployToolkit](https://psappdeploytoolkit.com/)

## License

See [LICENSE](../LICENSE) in the root directory.
