## Usage

```bash
./your_script.sh [-b build_command] [-w watch_path]
```

### Options:

- `-b build_command`  
  Specify a custom build command (default: `'docker-compose up --build -d'`).

- `-w watch_path`  
  Specify a custom watch path (default: `'./src'`).

### Example:

```bash
./your_script.sh -b 'docker build -t my-custom-image .' -w '/path/to/watch'
```

### Dependencies:

Valid dependencies are required for file watching on your system:
- **Linux:** `inotify-tools`
- **MacOS:** `fswatch`
- **Windows:** PowerShell 7+

Other operating systems are not supported.
