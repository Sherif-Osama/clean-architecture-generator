
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

# Prevent overwriting an existing directory.
if [[ -e "$PROJECT_NAME" || -L "$PROJECT_NAME" ]]; then
    echo "Error: Directory '$PROJECT_NAME' already exists."
    exit 1
fi

# Remove the partially generated project if any later command fails.
PROJECT_DIR_CREATED=false
cleanup_on_failure() {
    local exit_code=$?
    if [[ $exit_code -ne 0 && $PROJECT_DIR_CREATED == true ]]; then
        cd ..
        rm -rf -- "$PROJECT_NAME"
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
echo

# ==========================================
# Create the solution directory.
# ==========================================

mkdir "$PROJECT_NAME"
PROJECT_DIR_CREATED=true
cd "$PROJECT_NAME"

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
