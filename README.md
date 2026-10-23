# Clean Architecture Generator

A small Bash script that creates a ready-to-build .NET solution using a basic Clean Architecture layout.

## What it creates

- **Domain** — core models and business rules
- **Application** — use cases and application logic
- **Infrastructure** — external services and data access
- **API** — an ASP.NET Core Web API with controllers

The script adds the projects to one solution, configures their references, creates a `.gitignore`, and builds the solution. This saves setup time and gives new .NET projects a consistent starting structure.

## Requirements

- .NET SDK
- Bash and `sed` (for example, Git Bash, Linux, or macOS)

## Usage

```bash
chmod +x create-clean-architecture.sh
./create-clean-architecture.sh
```

Enter a project name when prompted. The generated solution is created in a new directory with that name.
