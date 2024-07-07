#!/bin/bash

# Default values for optional arguments
build_cmd="docker-compose up --build -d"
stop_cmd="docker-compose down"
watch_path="./src"

# Display usage instructions
usage() {
  echo "Usage: ./your_script.sh [-b build_command] [-s stop_command] [-w watch_path]"
  echo "Options:"
  echo "  -b build_command   Specify a custom build command (default: 'docker-compose up --build -d')"
  echo "  -s stop_command    Specify a custom stop command (default: 'docker-compose down')"
  echo "  -w watch_path      Specify a custom watch path (default: './src')"
  echo
  echo "Example:"
  echo "  ./your_script.sh -b 'docker build -t my-custom-image .' -s 'docker stop my-custom-image' -w '/path/to/watch'"
  echo
  echo "Dependencies:"
  echo "  Valid dependencies are required for file watching on your system."
  echo "  Linux: inotify-tools."
  echo "  MacOS: fswatch."
  echo "  Windows: PowerShell 7+"
  echo "  Other operating systems are not supported."
  check_dependencies
  exit 0
}

# Ensure file watching dependencies for users OS are installed or supported
check_dependencies() {
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux
    if ! command -v inotifywait &> /dev/null; then
      echo "  It appears you are using Linux, please install inotify-tools via:"
      echo "    sudo apt-get install inotify-tools"
    fi
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    # MacOS
    if ! command -v fswatch &> /dev/null; then
      echo "  It appears you are using macOS, please install fswatch via:"
      echo "    brew install fswatch"
    fi
  elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    # Windows using Powershell (assuming PowerShell 7+)
    if ! command -v pwsh &> /dev/null; then
      echo "  It appears you are using Windows, please install PowerShell 7+ via:"
      echo "    https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell"
    fi
  else
    echo "  Unsupported operating system."
  fi
}

# Parse optional arguments
while getopts "b:s:w:h" opt; do
  case ${opt} in
    b )
      build_cmd=$OPTARG
      ;;
    s )
      stop_cmd=$OPTARG
      ;;
    w )
      watch_path=$OPTARG
      ;;
    h )
      usage
      ;;
    \? )
      echo "Invalid option: -$OPTARG"
      usage
      ;;
  esac
done

# Ensure build_cmd contains the -d flag if it is docker or docker-compose command
if [[ "$build_cmd" == *"docker-compose"* || "$build_cmd" == *"docker"* ]]; then
  if [[ "$build_cmd" != *"-d"* ]]; then
    build_cmd="$build_cmd -d"
  fi
elif [[ -z "$stop_cmd" ]]; then
  echo "Error: -s stop_command is required if build_command is not a Docker or docker-compose command"
  usage
fi

# Function to start and build the containers
start_containers() {
  if [[ "$build_cmd" == *"docker-compose"* ]]; then
    container_names=$(docker-compose ps --services)
    echo "Starting containers:"

    for container in ${container_names[@]}; do
      echo "    $container"
    done

  else
    echo "Running build command: $build_cmd"
  fi
  eval $build_cmd
}

# Function to stop the containers or processes
stop_containers() {
  if [[ "$stop_cmd" == *"docker-compose"* ]]; then
    container_names=$(docker-compose ps --services)
    echo "Stopping containers:"

    for container in ${container_names[@]}; do
      echo "    $container"
    done

  else
    echo "Running stop command: $stop_cmd"
  fi
  eval $stop_cmd
}

# Function to write containers logs to terminal window without blocking script execution
tail_logs() {
  if [[ "$build_cmd" == *"docker-compose"* ]]; then
    container_names=$(docker-compose ps --services)
    echo "Tailing logs from containers:"

    for container in ${container_names[@]}; do
      echo "    $container"
    done

    docker-compose logs -f &
    LOG_PID=$!
  fi
}

# Determine OS and select appropriate file watching library
  # Linux
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  if command -v inotifywait &> /dev/null; then
    WATCH_COMMAND="inotifywait -e close_write -r $watch_path"
  else
    echo "Error: inotifywait is required but not installed. Please install it and try again."
    check_dependencies
    exit 1
  fi

# macOS
elif [[ "$OSTYPE" == "darwin"* ]]; then
  if command -v fswatch &> /dev/null; then
    WATCH_COMMAND="fswatch -1 -r $watch_path"
  else
    echo "Error: fswatch is required but not installed. Please install it with 'brew install fswatch' and try again."
    check_dependencies
    exit 1
  fi

# Windows
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
  if command -v pwsh &> /dev/null; then
    WATCH_COMMAND="pwsh -Command while (\$true) { Wait-FileSystemEvent -Path '$watch_path' -Recursive; Stop-Service docker; Start-Service docker; }"
  else
    echo "Error: PowerShell (pwsh) is required but not installed. Please install PowerShell 7+ and try again."
    check_dependencies
    exit 1
  fi

else
  echo "Error: Unsupported operating system."
  exit 1
fi

# Initial start
start_containers
tail_logs

# Trap SIGINT (Ctrl+C) to gracefully exit
trap "echo ''; echo 'Exiting...'; exit 0" SIGINT

# Function to debounce container restart
debounce_restart() {
  if [[ -n $DEBOUNCE_PID ]]; then
    kill $DEBOUNCE_PID 2>/dev/null
    sleep 3
  fi
  (
    if [[ -n $BUILD_PID ]]; then
      kill $BUILD_PID 2>/dev/null
      sleep 3
    fi
    (
      stop_containers
      sleep 5
      start_containers
      tail_logs
    ) &
    BUILD_PID=$!
  ) &
  DEBOUNCE_PID=$!
}

# Watch for changes using selected command
echo "Watching $watch_path for changes..."
while true; do
  eval "$WATCH_COMMAND" | while IFS= read -r line; do
    echo "Detected change in: $line"
    debounce_restart
  done
done

