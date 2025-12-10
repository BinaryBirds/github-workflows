# GitHub Actions Workflows

This repository contains a reusable workflow and various bash scripts designed to streamline tasks in a Swift project.

The workflow utilizes the official [swiftlang/github-workflows](https://github.com/swiftlang/github-workflows) to perform checks and run Swift tests on the repository.

## Install

No installation required.

## Workflows

This section details the reusable workflows provided by the repository.

### 1. Extra Soundness Workflow (`extra_soundness.yml`)

This workflow provides configurable, robust checks and testing:

* **Optional Local Swift Dependency Checks**: Checks for accidental `.package(path:)` usage.
* **Optional Swift Test Execution**: Runs tests using **`.build` caching** for efficiency.
* **Multi-Version Support**: Tests across multiple Swift versions, configurable via input (defaulting to `["6.0", "6.1"]`).
* **SSH Support**: Includes steps to set up **SSH credentials** (via the `SSH_PRIVATE_KEY` secret) for projects relying on private Git dependencies.

**Example Usage (Caller Repository):**

```yaml
jobs:
  soundness:
    uses: BinaryBirds/github-workflows/.github/workflows/extra_soundness.yml@main
    with:
      local_swift_dependencies_check_enabled: true
      run_tests_with_cache_enabled: true
      run_tests_swift_versions: '["6.0","6.1"]'
```

### 2\. DocC Deploy Workflow (`docc_deploy.yml`)

This workflow handles the generation and deployment of DocC documentation:

* **Builds DocC Documentation**: Uses a Swift Docker image (default version "6.2") to build the documentation.
* **Deploys to GitHub Pages**: Uses `actions/deploy-pages@v4` to publish the results.
* **Note on Stability**: This workflow is currently configured to fetch its core script (`generate-docc.sh`) from the **`feature/docc`** branch.

**Example Usage (Caller Repository):**

```yaml
jobs:
  create-docc-and-deploy:
    uses: BinaryBirds/github-workflows/.github/workflows/docc_deploy.yml@main
    permissions:
      contents: read
      pages: write
      id-token: write
    with:
      docc_swift_version: "6.1"
```

-----

## Makefile Usage

A **Makefile** is included to simplify the execution of all automation tasks by converting long `curl | bash` commands into short, memorable `make` targets.

### Combined Makefile Commands

The `check` target is a composite command that executes several core quality checks sequentially.

* `check`: Executes `make symlinks` -\> `make language` -\> `make deps` -\> `make lint`.

### Benefits

* **Standardizes script usage** and ensures consistent options.
* **Shortens long commands** into memorable tasks.
* Supports composite commands and reduces human error.

-----

## Available Scripts Documentation

The `Makefile` uses the variable `baseUrl` which points to the source of all scripts:
`https://raw.githubusercontent.com/BinaryBirds/github-workflows/refs/heads/main/scripts`

### check-api-breakage.sh

**Purpose**: Detects API-breaking changes compared to the latest Git tag using the `swift package diagnose-api-breaking-changes` command.

**Makefile Command**:

```sh
make breakage
```

**Raw curl Command**:

```sh
curl -s $(baseUrl)/check-api-breakage.sh | bash
```

-----

### check-broken-symlinks.sh

**Purpose**: Runs a search to find and report **broken symbolic links** within the repository.

**Makefile Command**:

```sh
make symlinks
```

**Raw curl Command**:

```sh
curl -s $(baseUrl)/check-broken-symlinks.sh | bash
```

-----

### check-docc-warnings.sh

**Purpose**: Executes DocC documentation analysis with the **`--warnings-as-errors`** flag to enforce strict quality standards.

**Makefile Command**:

```sh
make docc-warnings
```

**Raw curl Command**:

```sh
curl -s $(baseUrl)/check-docc-warnings.sh | bash
```

-----

### check-local-swift-dependencies.sh

**Purpose**: Checks for accidental local Swift package dependencies by scanning for **`.package(path:)`** usage in `Package.swift` files.

**Makefile Command**:

```sh
make deps
```

**Raw curl Command**:

```sh
curl -s $(baseUrl)/check-local-swift-dependencies.sh | bash
```

-----

### check-openapi-security.sh

**Purpose**: Runs a **security analysis** on the OpenAPI specification using **OWASP ZAP** inside a Docker container.

**Makefile Command**:

```sh
make openapi-security
```

**Raw curl Command**:

```sh
curl -s $(baseUrl)/check-openapi-security.sh | bash
```

-----

### check-openapi-validation.sh

**Purpose**: Validates the `openapi.yaml` file for compliance with the OpenAPI standard using the `openapi-spec-validator` tool in a Docker container.

**Makefile Command**:

```sh
make openapi-validation
```

**Raw curl Command**:

```sh
curl -s $(baseUrl)/check-openapi-validation.sh | bash
```

-----

### check-swift-headers.sh

**Purpose**: Checks and optionally fixes Swift source file headers to ensure they follow a consistent 5-line format.
**Configuration**: Respects the **`.swiftheaderignore`** file, which lists file paths, directories, or glob patterns to exclude from header validation.

**Parameters**:

* `--fix`: Automatically inserts or updates headers in-place.
* `--author <name>`: Overrides the default author name (`"Binary Birds"`).

**Makefile Command (Check)**:

```sh
make headers
```

**Raw curl Command (Check)**:

```sh
curl -s $(baseUrl)/check-swift-headers.sh | bash
```

**Makefile Command (Fix)**:

```sh
make fix-headers
```

**Raw curl Command (Fix with Author Example)**:

```sh
curl -s $(baseUrl)/check-swift-headers.sh | bash -s -- --fix --author "John Doe"
```

-----

### check-unacceptable-language.sh

**Purpose**: Searches the codebase for unacceptable language patterns (e.g., `master`, `blacklist`).
**Configuration**: Respects the **`.unacceptablelanguageignore`** file, which allows you to ignore specific files or directories when scanning for unacceptable language.

**Makefile Command**:

```sh
make language
```

**Raw curl Command**:

```sh
curl -s $(baseUrl)/check-unacceptable-language.sh | bash
```

-----

### generate-contributors-list.sh

**Purpose**: Generates a list of contributors for the repository into a **`CONTRIBUTORS.txt`** file from Git commit history.

**Makefile Command**:

```sh
make contributors
```

**Raw curl Command**:

```sh
curl -s $(baseUrl)/generate-contributors-list.sh | bash
```

-----

### generate-docc.sh

**Purpose**: Generates DocC documentation to the `docs/` directory.
**Configuration**: Looks for the **`.doccTargetList`** file, which, if present, explicitly defines the Swift targets for documentation generation.

**Parameters**:

* `--local`: Enables local mode (no hosting transforms).
* `--name <value>`: Sets the hosting base path for GitHub Pages.

**Makefile Command**:

```sh
make docc-generate
```

**Raw curl Command (GitHub Pages Example)**:

```sh
curl -s $(baseUrl)/generate-docc.sh | bash -s -- --name MyRepoName
```

-----

### install-swift-format.sh

**Purpose**: Installs the **Swift Format** tool binary.

**Makefile Command**:

```sh
make install-format
```

**Raw curl Command**:

```sh
curl -s $(baseUrl)/install-swift-format.sh | bash
```

-----

### install-swift-openapi-generator.sh

**Purpose**: Installs the **Swift OpenAPI Generator** tool.

**Parameters**:

* `-v <X.Y.Z>`: Specifies the version to install.

**Makefile Command**:

```sh
make install-openapi
```

**Raw curl Command (Version Example)**:

```sh
curl -s $(baseUrl)/install-swift-openapi-generator.sh | bash -s -- -v 1.2.2
```

-----

### run-clean.sh

**Purpose**: Cleans up build artifacts and other temporary files (e.g., `.build`, `.swiftpm`).

**Makefile Command**:

```sh
make run-clean
```

**Raw curl Command**:

```sh
curl -s $(baseUrl)/run-clean.sh | bash
```

-----

### run-docc-docker.sh

**Purpose**: Serves the generated DocC documentation using a Docker container running Nginx.

**Parameters**:

* `-n <name>`: Adds a custom identifier for the container.
* `-p <host:container>`: Adds a custom port mapping (default: `8000:80`).

**Makefile Command**:

```sh
make run-docc
```

**Raw curl Command (Custom Port Example)**:

```sh
curl -s $(baseUrl)/run-docc-docker.sh | bash -s -- -p 8800:80
```

-----

### run-openapi-docker.sh

**Purpose**: Serves the OpenAPI documentation using a Docker container running Nginx.

**Parameters**:

* `-n <name>`: Adds a custom identifier for the container.
* `-p <host:container>`: Adds a custom port mapping (default: `8888:80`).

**Makefile Command**:

```sh
make run-openapi
```

**Raw curl Command (Custom Name Example)**:

```sh
curl -s $(baseUrl)/run-openapi-docker.sh | bash -s -- -n new-name
```

-----

### run-swift-format.sh

**Purpose**: Checks/formats Swift code using the `swift-format` tool. If configuration is missing, it downloads defaults.
**Configuration**: Uses the **`.swift-format`** file for format rules and the **`.swiftformatignore`** file to exclude files/directories from the process.

**Parameters**:

* `--fix`: Automatically applies formatting instead of checking.

**Makefile Command (Check)**:

```sh
make lint
```

**Raw curl Command (Fix)**:

```sh
curl -s $(baseUrl)/run-swift-format.sh | bash -s -- --fix
```
