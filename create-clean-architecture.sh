#!/usr/bin/env bash

set -Eeuo pipefail

# ==========================================
# Clean Architecture Project Generator
# ==========================================

echo "=========================================="
echo "  Clean Architecture Project Generator"
echo "=========================================="
echo

# Check if .NET SDK is installed.
if ! command -v dotnet >/dev/null 2>&1; then
    echo "Error: .NET SDK is not installed or not in PATH."
    exit 1
fi

# Ask for the project name.
read -r -p "Enter project name: " PROJECT_NAME

# Trim whitespace and replace spaces with underscores.
PROJECT_NAME="$(
    printf '%s' "$PROJECT_NAME" |
        sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//; s/[[:space:]]+/_/g'
)"

# Validate that the name is not empty.
if [[ -z "$PROJECT_NAME" ]]; then
    echo "Error: Project name cannot be empty."
    exit 1
fi

# Validate the project name format.
if [[ ! "$PROJECT_NAME" =~ ^[a-zA-Z][a-zA-Z0-9_]*$ ]]; then
    echo "Error: Invalid project name."
    echo "Use letters, numbers, and underscores."
    echo "The name must start with a letter."
    exit 1
fi

# Prevent C# reserved keywords from being used as the root name.
case "$PROJECT_NAME" in
    abstract|as|base|bool|break|byte|case|catch|char|checked|class|const|continue|decimal|default|delegate|do|double|else|enum|event|explicit|extern|false|finally|fixed|float|for|foreach|goto|if|implicit|in|int|interface|internal|is|lock|long|namespace|new|null|object|operator|out|override|params|private|protected|public|readonly|ref|return|sbyte|sealed|short|sizeof|stackalloc|static|string|struct|switch|this|throw|true|try|typeof|uint|ulong|unchecked|unsafe|ushort|using|virtual|void|volatile|while)
        echo "Error: '$PROJECT_NAME' is a reserved C# keyword."
        echo "Choose another project name."
        exit 1
        ;;
esac

# Ask where to create the project. The current directory is the default.
DEFAULT_PARENT_DIR="$(pwd -P)"
read -r -p "Enter parent directory path [$DEFAULT_PARENT_DIR]: " TARGET_PARENT_DIR
TARGET_PARENT_DIR="${TARGET_PARENT_DIR:-$DEFAULT_PARENT_DIR}"

# Expand the current user's home-directory shorthand without evaluating input.
case "$TARGET_PARENT_DIR" in
    "~")
        TARGET_PARENT_DIR="${HOME:?Error: HOME is not set.}"
        ;;
    "~/"*)
        TARGET_PARENT_DIR="${HOME:?Error: HOME is not set.}/${TARGET_PARENT_DIR:2}"
        ;;
esac

# Accept native Windows paths when running in Git Bash or another Cygwin shell.
if command -v cygpath >/dev/null 2>&1; then
    case "$TARGET_PARENT_DIR" in
        [A-Za-z]:\\*|[A-Za-z]:/*)
            TARGET_PARENT_DIR="$(cygpath -u "$TARGET_PARENT_DIR")"
            ;;
    esac
fi

if [[ -L "$TARGET_PARENT_DIR" && ! -e "$TARGET_PARENT_DIR" ]]; then
    echo "Error: The selected path is a broken symbolic link."
    exit 1
fi

if [[ ! -e "$TARGET_PARENT_DIR" ]]; then
    echo "Error: Directory '$TARGET_PARENT_DIR' does not exist."
    echo "Enter an existing directory path and try again."
    exit 1
fi

if [[ ! -d "$TARGET_PARENT_DIR" ]]; then
    echo "Error: '$TARGET_PARENT_DIR' is not a directory."
    exit 1
fi

if [[ ! -w "$TARGET_PARENT_DIR" || ! -x "$TARGET_PARENT_DIR" ]]; then
    echo "Error: No write permission for directory '$TARGET_PARENT_DIR'."
    exit 1
fi

if ! TARGET_PARENT_DIR="$(cd -- "$TARGET_PARENT_DIR" && pwd -P)"; then
    echo "Error: Could not access directory '$TARGET_PARENT_DIR'."
    exit 1
fi

PROJECT_OUTPUT_PATH="${TARGET_PARENT_DIR%/}/$PROJECT_NAME"

# Do not replace an existing directory, file, or symbolic link.
if [[ -e "$PROJECT_OUTPUT_PATH" || -L "$PROJECT_OUTPUT_PATH" ]]; then
    echo "Error: '$PROJECT_OUTPUT_PATH' already exists."
    echo "Choose a different project name or parent directory."
    exit 1
fi

# Remove the partially generated project if any later command fails.
PROJECT_DIR_CREATED=false
cleanup_on_failure() {
    local exit_code=$?
    if [[ $exit_code -ne 0 && $PROJECT_DIR_CREATED == true ]]; then
        rm -rf -- "$PROJECT_OUTPUT_PATH"
    fi
    return "$exit_code"
}
trap cleanup_on_failure EXIT

# ==========================================
# Define project names.
# ==========================================

DOMAIN_PROJECT="${PROJECT_NAME}.Domain"
APPLICATION_PROJECT="${PROJECT_NAME}.Application"
INFRASTRUCTURE_PROJECT="${PROJECT_NAME}.Infrastructure"
API_PROJECT="${PROJECT_NAME}.Api"

SOLUTION_FILE="${PROJECT_NAME}.sln"

echo
echo "Project name: $PROJECT_NAME"
echo "Parent directory: $TARGET_PARENT_DIR"
echo

# ==========================================
# Create the solution directory.
# ==========================================

mkdir -- "$PROJECT_OUTPUT_PATH"
PROJECT_DIR_CREATED=true
cd -- "$PROJECT_OUTPUT_PATH"

# ==========================================
# Create the solution.
# ==========================================

echo "[1/7] Creating solution..."

dotnet new sln \
    --format sln \
    --name "$PROJECT_NAME"

# ==========================================
# Create Domain.
# ==========================================

echo
echo "[2/7] Creating Domain project..."

dotnet new classlib \
    --name "$DOMAIN_PROJECT" \
    --output "$DOMAIN_PROJECT"

# ==========================================
# Create Application.
# ==========================================

echo
echo "[3/7] Creating Application project..."

dotnet new classlib \
    --name "$APPLICATION_PROJECT" \
    --output "$APPLICATION_PROJECT"

# ==========================================
# Create Infrastructure.
# ==========================================

echo
echo "[4/7] Creating Infrastructure project..."

dotnet new classlib \
    --name "$INFRASTRUCTURE_PROJECT" \
    --output "$INFRASTRUCTURE_PROJECT"

# ==========================================
# Create API with Controllers.
# ==========================================

echo
echo "[5/7] Creating API project..."

dotnet new webapi \
    --use-controllers \
    --name "$API_PROJECT" \
    --output "$API_PROJECT"

# ==========================================
# Add projects to the solution.
# Add API FIRST to make it the default
# startup candidate in a fresh Visual Studio
# solution, unless a saved user setting overrides it.
# ==========================================

echo
echo "[6/7] Adding projects to solution..."

dotnet sln "$SOLUTION_FILE" add \
    "$API_PROJECT/$API_PROJECT.csproj" \
    "$DOMAIN_PROJECT/$DOMAIN_PROJECT.csproj" \
    "$APPLICATION_PROJECT/$APPLICATION_PROJECT.csproj" \
    "$INFRASTRUCTURE_PROJECT/$INFRASTRUCTURE_PROJECT.csproj"

# ==========================================
# Configure project references.
# ==========================================

echo
echo "[7/7] Configuring project references..."

# Application -> Domain
dotnet add \
    "$APPLICATION_PROJECT/$APPLICATION_PROJECT.csproj" \
    reference \
    "$DOMAIN_PROJECT/$DOMAIN_PROJECT.csproj"

# Infrastructure -> Application + Domain
dotnet add \
    "$INFRASTRUCTURE_PROJECT/$INFRASTRUCTURE_PROJECT.csproj" \
    reference \
    "$APPLICATION_PROJECT/$APPLICATION_PROJECT.csproj" \
    "$DOMAIN_PROJECT/$DOMAIN_PROJECT.csproj"

# API -> Application + Infrastructure
dotnet add \
    "$API_PROJECT/$API_PROJECT.csproj" \
    reference \
    "$APPLICATION_PROJECT/$APPLICATION_PROJECT.csproj" \
    "$INFRASTRUCTURE_PROJECT/$INFRASTRUCTURE_PROJECT.csproj"

# ==========================================
# Add .gitignore.
# ==========================================

echo
echo "Creating .gitignore..."

dotnet new gitignore

# ==========================================
# Build the solution.
# ==========================================

echo
echo "Building solution..."

dotnet build "$SOLUTION_FILE"

# ==========================================
# Display the result.
# ==========================================

echo
echo "=========================================="
echo " Project created successfully!"
echo "=========================================="
echo
echo "Project:    $PROJECT_NAME"
echo "Solution:   $SOLUTION_FILE"
echo "Location:   $(pwd)"
echo
echo "Projects:"
echo "  - $API_PROJECT       (Startup candidate)"
echo "  - $DOMAIN_PROJECT"
echo "  - $APPLICATION_PROJECT"
echo "  - $INFRASTRUCTURE_PROJECT"
echo
echo "Open the solution in Visual Studio."
echo "=========================================="
