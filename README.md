## Install
MacOS: 
```bash
  brew tap Gavin-Barham/homebrew-docker-hotreload
  brew install docker-hotreload
```
Not yet supported:
```
Windows 10+ installer
Linux installer
```
For temporary fix dowload the file, add to your path in your bashrc or zshrc and alias as dhr

## Usage

```bash
dhr [-b build_command] [-w watch_path]
```

### Options:

- `-b build_command`  
  Specify a custom build command (default: `'docker-compose up --build -d'`).

- `-w watch_path`  
  Specify a custom watch path (default: `'./src'`).

### Example:

```bash
dhr -b 'docker build -t my-custom-image .' -w '/path/to/watch'
```

### Dependencies:

Valid dependencies are required for file watching on your system:
- **Linux:** `inotify-tools`
- **MacOS:** `fswatch`
- **Windows:** PowerShell 7+

Other operating systems are not supported.
