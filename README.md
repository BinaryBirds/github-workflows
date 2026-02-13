# GitHub Actions Workflows

This repository contains reusable GitHub Actions workflows and a collection of Bash scripts designed to streamline quality checks, documentation, formatting, and maintenance tasks in Swift projects.

The workflows build on the official [swiftlang/github-workflows](https://github.com/swiftlang/github-workflows) and extend them with additional soundness, documentation, and tooling checks.

These workflows and scripts are designed to be used within GitHub Actions. A basic working knowledge of GitHub Actions is required to configure workflows, understand job execution, and troubleshoot CI failures.

If you are not familiar with GitHub Actions, refer to the official documentation before using or customizing these workflows:
[GitHub Actions documentation](https://docs.github.com/en/actions)

## Install

No installation required.

All scripts are executed directly via `curl | bash` or through the provided `Makefile`.

## Workflows

This section details the reusable workflows provided by the repository.

### 1. Extra Soundness Workflow (`extra_soundness.yml`)

This workflow provides configurable, robust checks and testing:

* **Optional Local Swift Dependency Checks**: Checks for accidental `.package(path:)` usage.
* **Optional Swift Headers Check**: Validates Swift source file headers using a strict 5-line format and respects `.swiftheaderignore`.
* **Optional DocC Warnings Check**: Runs DocC analysis with `--warnings-as-errors` and fails on warnings.
* **Optional Swift Test Execution**: Runs tests using **`.build` caching** for efficiency.
* **Optional Swift Package Validation**: Validates Swift package structure, settings, and conventions to ensure consistency.
* **Multi-Version Support**: Tests across multiple Swift versions, configurable via input (defaulting to `["6.0", "6.1"]`).
* **SSH Support**: Includes steps to set up **SSH credentials** (via the `SSH_PRIVATE_KEY` secret) for projects relying on private Git dependencies.

#### Workflow Inputs

| Input | Description | Default |
| ------ | ------------ | --------- |
| `local_swift_dependencies_check_enabled` | Enables local Swift dependency check | `false` |
| `headers_check_enabled` | Enables Swift headers validation | `false` |
| `docc_warnings_check_enabled` | Enables DocC warnings check | `false` |
| `run_tests_with_cache_enabled` | Enables Swift tests with `.build` cache | `false` |
| `run_tests_swift_versions` | Swift versions to test | `["6.1","6.2"]` |
| `swift_package_validation_enabled` | Runs Swift package validation in the repository. | `false` |

#### Example Usage (Caller Repository)

```yaml
jobs:
  soundness:
    uses: BinaryBirds/github-workflows/.github/workflows/extra_soundness.yml@main
    with:
      local_swift_dependencies_check_enabled: true
      headers_check_enabled: true
      docc_warnings_check_enabled: true
      run_tests_with_cache_enabled: true
      run_tests_swift_versions: '["6.1","6.2"]'
      swift_package_validation_enabled: true
```

### 2. DocC Deploy Workflow (`docc_deploy.yml`)

This workflow handles the generation and deployment of DocC documentation:

* **Builds DocC Documentation**: Uses a Swift 6.2 Docker image to build the documentation.
* **Deploys to GitHub Pages**: Uses `actions/deploy-pages@v6` to publish the results.
* **Target Configuration**: Respects `.docctargetlist` if present.

#### Example Usage (Caller Repository)

```yaml
jobs:
  create-docc-and-deploy:
    uses: BinaryBirds/github-workflows/.github/workflows/docc_deploy.yml@main
    permissions:
      contents: read
      pages: write
      id-token: write
```

### 3. API Breaking Changes Workflow (`api_breakage.yml`)

This workflow checks for API breaking changes in the repository:

* Runs API Breakage Checks: Executes the Binary Birds API breakage checking script.
* Swift-based Environment: Runs inside a swift:latest Docker container.
* Full Git History Available: Checks out the repository with complete history for accurate comparison.

#### Example Usage (Caller Repository)

```yaml
jobs:
  check-api-breakage:
    uses: BinaryBirds/github-workflows/.github/workflows/api_breakage.yml@main
```

-----

## Makefile Usage

A **Makefile** is included to simplify the execution of all automation tasks by converting long `curl | bash` commands into short, memorable `make` targets.

### Combined Makefile Commands

Some Makefile targets group multiple related checks into a single command.
These combined commands run several scripts in sequence to provide a quick, consistent way to verify overall project quality. For a concrete reference, see the `make check` target in the `Makefile`, which combines several core checks into one command.

### Benefits

* Standardizes script usage and ensures consistent options.
* Shortens long commands into memorable tasks.
* Supports composite commands and reduces human error.

-----

## Available Scripts Documentation

The `Makefile` uses the variable `baseUrl` which points to the source of all scripts:
`https://raw.githubusercontent.com/BinaryBirds/github-workflows/refs/heads/main/scripts`

### DocC dependency placeholder requirement

DocC-related scripts rely on a placeholder inside `Package.swift` to safely inject the `swift-docc-plugin` dependency when needed.

Your `Package.swift` must contain a top-level `dependencies` section (even if empty) and include the following comment:

```swift
// [docc-plugin-placeholder]
```

This placeholder defines the only supported injection point. If either the dependencies section or the placeholder is missing, DocC scripts will fail intentionally.

```swift
dependencies: [
    // [docc-plugin-placeholder]
]
```

The placeholder itself has no effect on builds and does not modify target-level dependencies.

### check-api-breakage.sh

#### Purpose

Detects source- and binary-level API breaking changes in Swift packages to prevent unintended public API regressions.

#### Behavior

* Uses `swift package diagnose-api-breaking-changes`
* Pull requests: fetches `${GITHUB_BASE_REF}` into a local `pull-base-ref` and compares against that ref
* Other contexts: fetches tags and compares against the latest Git tag
* If no tags exist, exits successfully with a warning
* Fails when breaking changes are detected

#### Parameters

_None_

#### Ignore files

_None_

#### Raw curl example

```sh
curl -s $(baseUrl)/check-api-breakage.sh | bash
```

---

### check-broken-symlinks.sh

#### Purpose

Ensures all git-tracked symbolic links resolve to valid targets.

#### Behavior

* Inspects only symbolic links
* Ignores regular missing files
* Reports each broken symlink explicitly
* Exits non-zero if any broken symlink is found

#### Parameters

_None_

#### Ignore files

_None_

#### Raw curl example

```sh
curl -s $(baseUrl)/check-broken-symlinks.sh | bash
```

---

### check-docc-warnings.sh

#### Purpose

Runs DocC documentation analysis in strict mode, treating warnings as errors.

#### Behavior

* Uses `.docctargetlist` when present, otherwise auto-detects targets
* Temporarily injects `swift-docc-plugin` if missing
* Requires a clean git working tree locally
* Restores git state after execution

#### Parameters

_None_

#### Ignore files

* `.docctargetlist` – explicitly defines documented targets

#### Raw curl example

```sh
curl -s $(baseUrl)/check-docc-warnings.sh | bash
```

---

### check-local-swift-dependencies.sh

#### Purpose

Prevents accidental usage of local Swift package dependencies.

#### Behavior

* Scans git-tracked `Package.swift` files only (ignores untracked files)
* Detects `.package(path:)`
* Fails immediately on detection

#### Parameters

_None_

#### Ignore files

_None_

#### Raw curl example

```sh
curl -s $(baseUrl)/check-local-swift-dependencies.sh | bash
```

---

### check-openapi-security.sh

#### Purpose

Runs a security scan of an OpenAPI specification using OWASP ZAP.

#### Behavior

* Executes inside Docker
* Accepts an OpenAPI file or directory (default: `openapi`)
* Relative `-f` paths are resolved from the git repository root (fallback: current working directory)
* For file paths, supports `.yml`/`.yaml` extension fallback
* Skips execution if no OpenAPI specification can be resolved

#### Parameters

* `-f <path>` – OpenAPI file or directory path

#### Ignore files

_None_

#### Raw curl examples

```sh
curl -s $(baseUrl)/check-openapi-security.sh | bash
```

```sh
curl -s $(baseUrl)/check-openapi-security.sh | bash -s -- -f openapi/openapi.yml
```

---

### check-openapi-validation.sh

#### Purpose

Validates an OpenAPI specification for schema correctness.

#### Behavior

* Runs the OpenAPI validator in Docker
* Accepts an OpenAPI file or directory (default: `openapi`)
* Relative `-f` paths are resolved from the git repository root (fallback: current working directory)
* For file paths, supports `.yml`/`.yaml` extension fallback
* Skips execution if no OpenAPI specification can be resolved

#### Parameters

* `-f <path>` – OpenAPI file or directory path

#### Ignore files

_None_

#### Raw curl examples

```sh
curl -s $(baseUrl)/check-openapi-validation.sh | bash
```

```sh
curl -s $(baseUrl)/check-openapi-validation.sh | bash -s -- -f openapi/openapi.yaml
```

```sh
# Monorepo/nested project example (path relative to git root)
curl -s $(baseUrl)/check-openapi-validation.sh | bash -s -- -f mail-examples/mail-example-openapi/openapi/openapi.yaml
```

---

### check-swift-headers.sh

#### Purpose

Ensures Swift source files contain a consistent, standardized header.

#### Behavior

* Enforces a strict 5-line header format
* Can optionally insert or update headers in-place
* Processes only git-tracked Swift files
* Skips `Package.swift` explicitly
* Accepts `Created by ... on YYYY. MM. DD.` and legacy `..` suffix
* In `--fix` mode, normalizes legacy `..` to `.`
* When repairing malformed headers, preserves extracted author and date when possible

#### Parameters

* `--fix` – insert or update headers automatically
* `--author <name>` – override default author name

#### Ignore files

* `.swiftheaderignore` – excludes paths from header validation (replaces default exclusions when present)

#### Raw curl examples

_Check only:_

```sh
curl -s $(baseUrl)/check-swift-headers.sh | bash
```

_Fix headers with custom author:_

```sh
curl -s $(baseUrl)/check-swift-headers.sh | bash -s -- --fix --author "John Doe"
```

---

### check-unacceptable-language.sh

#### Purpose

Detects discouraged or outdated terminology to promote inclusive language.

#### Behavior

* Case-insensitive, whole-word matching
* Scans git-tracked files only
* Lines containing `ignore-unacceptable-language` are excluded from failures

#### Parameters

_None_

#### Ignore files

* `.unacceptablelanguageignore` – excludes paths from scanning

#### Raw curl example

```sh
curl -s $(baseUrl)/check-unacceptable-language.sh | bash
```

---

### generate-contributors-list.sh

#### Purpose

Generates a CONTRIBUTORS.txt file from git commit history.

#### Behavior

* Uses `git shortlog -es HEAD`
* Respects `.mailmap`
* Overwrites the file deterministically
* Writes to repository root even when run from a subdirectory
* If the repository has no commits, exits successfully and does not create `CONTRIBUTORS.txt`

#### Parameters

_None_

#### Ignore files

_None_

#### Raw curl example

```sh
curl -s $(baseUrl)/generate-contributors-list.sh | bash
```

---

### generate-docc.sh

#### Purpose

Generates DocC documentation into the `docs/` directory.

#### Behavior

* Supports multiple Swift targets
* Enables combined documentation automatically
* Can transform output for static hosting

#### Parameters

* `--local` – disable static hosting transform
* `--name <value>` – set hosting base path

#### Ignore files

* `.docctargetlist` – explicitly defines documented targets

#### Raw curl examples

_GitHub Pages output:_

```sh
curl -s $(baseUrl)/generate-docc.sh | bash -s -- --name MyRepo
```

_Local preview:_

```sh
curl -s $(baseUrl)/generate-docc.sh | bash -s -- --local
```

---

### install-swift-format.sh

#### Purpose

Installs the `swift-format` binary.

#### Behavior

* Builds from source
* Installs into `/usr/local/bin`

#### Parameters

_None_

#### Ignore files

_None_

#### Raw curl example

```sh
curl -s $(baseUrl)/install-swift-format.sh | bash
```

---

### install-swift-openapi-generator.sh

#### Purpose

Installs the Swift OpenAPI Generator CLI tool.

#### Behavior

* Builds from source
* Supports version pinning

#### Parameters

* `-v <version>` – install a specific version

#### Ignore files

_None_

#### Raw curl examples

_Latest version:_

```sh
curl -s $(baseUrl)/install-swift-openapi-generator.sh | bash
```

_Specific version:_

```sh
curl -s $(baseUrl)/install-swift-openapi-generator.sh | bash -s -- -v 1.2.2
```

---

### run-clean.sh

#### Purpose

Removes generated build artifacts and temporary files. ⚠️ Irreversible operation.

#### Behavior

* Deletes `.build/` and `.swiftpm/`
* Deletes `openapi/openapi.yaml`, `db.sqlite`, and `migration-entries.json`
* Intended for local development use



#### Parameters

_None_

#### Ignore files

_None_

#### Raw curl example

```sh
curl -s $(baseUrl)/run-clean.sh | bash
```

---

### run-docc-docker.sh

#### Purpose

Serves generated DocC documentation locally using Docker.

#### Behavior

* Runs Nginx in the foreground
* Exposes documentation over HTTP

#### Parameters

* `-n <name>` – container name
* `-p <host:container>` – port mapping

#### Ignore files

_None_

#### Raw curl example

```sh
curl -s $(baseUrl)/run-docc-docker.sh | bash -s -- -p 8800:80
```

---

### run-openapi-docker.sh

#### Purpose

Serves OpenAPI documentation locally using Docker.

#### Behavior

* Accepts an OpenAPI file or directory (default: `openapi`)
* Relative `-f` paths are resolved from the git repository root (fallback: current working directory)
* If a file is provided, mounts its parent directory
* For file paths, supports `.yml`/`.yaml` extension fallback
* Runs Nginx in the foreground
* Exposes documentation over HTTP

#### Parameters

* `-n <name>` – container name
* `-p <host:container>` – port mapping
* `-f <path>` – OpenAPI file or directory path

#### Ignore files

_None_

#### Raw curl examples

```sh
curl -s $(baseUrl)/run-openapi-docker.sh | bash -s -- -n openapi-preview
```

```sh
curl -s $(baseUrl)/run-openapi-docker.sh | bash -s -- -n openapi-preview -f openapi/openapi.yaml
```

---

### run-swift-format.sh

#### Purpose

Runs `swift-format` to lint or format Swift source files.

#### Behavior

* Downloads default configuration if missing
* Respects ignore rules
* Supports parallel execution

#### Parameters

* `--fix` – format files in-place

#### Ignore files

* `.swiftformatignore` – excludes files from formatting

#### Raw curl examples

_Lint only:_

```sh
curl -s $(baseUrl)/run-swift-format.sh | bash
```

_Fix formatting:_

```sh
curl -s $(baseUrl)/run-swift-format.sh | bash -s -- --fix
```

---

### run-actionlint.sh

#### Purpose

Runs `actionlint` to validate GitHub Actions workflows.

#### Behavior

* Verifies `actionlint` is installed before running
* Runs from repository root for consistent workflow path resolution
* Passes through optional CLI arguments to `actionlint`

#### Parameters

* `<actionlint args...>` – optional arguments passed to `actionlint`

#### Ignore files

_None_

#### Raw curl example

```sh
curl -s $(baseUrl)/run-actionlint.sh | bash
```

---

### script-format.sh

#### Purpose

Runs `shfmt` to check or fix formatting for tracked shell-related files.

#### Behavior

* Verifies `shfmt` is installed before running
* Targets tracked `*.sh`, `*.bash`, and `*.bats` files
* Default mode checks formatting and fails on drift
* `--fix` mode applies formatting in-place

#### Parameters

* `--fix` – apply formatting in-place

#### Ignore files

_None_

#### Raw curl examples

_Check only:_

```sh
curl -s $(baseUrl)/script-format.sh | bash
```

_Fix formatting:_

```sh
curl -s $(baseUrl)/script-format.sh | bash -s -- --fix
```

---

### check-swift-package.sh

#### Purpose

Validates Swift package structure and configuration to enforce project-wide conventions.

#### Behavior

* Verifies Package.swift presence and Swift tools version
* Ensures Swift tools version is 6.1 or newer
* Requires defaultSwiftSettings usage on all targets
* Enforces presence of the NonisolatedNonsendingByDefault Swift 6 concurrency feature
* Validates top-level dependencies section and DocC placeholder
* Checks required directory structure (Sources/, Tests/)
* Ensures required repository files exist
* Verifies LICENSE contains the current year
* Aggregates all violations and fails once at the end

#### Parameters

_None_

#### Ignore files

_None_

#### Raw curl examples

```sh
curl -s $(baseUrl)/check-swift-package.sh | bash
```
