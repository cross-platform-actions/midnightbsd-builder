# AGENTS.md — midnightbsd-builder

## Project Overview

This is a **Packer-based VM image builder for MidnightBSD**. It produces
qcow2 disk images used by the
[cross-platform-actions/action](https://github.com/cross-platform-actions/action)
GitHub Action. The build boots the MidnightBSD installer ISO via QEMU, runs an
automated installation via `bsdinstall` with a fetched `installerconfig`, then
provisions the VM over SSH.

**Languages:** HCL2 (Packer), Shell (sh/bash), YAML (CI)
**No compiled source code** — this is an infrastructure/DevOps project.

## Build Commands

### Prerequisites

- [HashiCorp Packer](https://www.packer.io/) >= 1.15.1 (CI uses 1.15.1)
- [QEMU](https://www.qemu.org/)

### Build an Image

```sh
./build.sh <version> <architecture> [extra-packer-args...]

# Examples:
./build.sh 4.0.4 x86-64

# Headless (no GUI window, used in CI):
./build.sh 4.0.4 x86-64 -var 'headless=true'
```

The script runs `packer init .` then `packer build` with layered variable files.
Output goes to `output/midnightbsd-<version>-<architecture>.qcow2`.

### Run a Built Image Locally

```sh
# Edit run.sh to point at the correct image, then:
./run.sh
```

### Validate Packer Template

```sh
packer init .
packer validate \
  -var os_version="4.0.4" \
  -var-file var_files/x86-64.pkrvars.hcl \
  -var-file var_files/4.0.4/x86-64.pkrvars.hcl \
  -var-file var_files/4.0.4/common.pkrvars.hcl \
  main.pkr.hcl
```

### Format HCL Files

```sh
packer fmt main.pkr.hcl
packer fmt var_files/
```

## Testing

There is **no unit test framework**. Testing is done entirely via CI:

1. The built qcow2 image is served over HTTP
2. `cross-platform-actions/action@midnight-bsd` boots the VM
3. Shell assertions verify: `uname` output, hostname, working directory, file sync

There is no way to run a single test locally. To verify changes, either build and
manually test the image with `run.sh`, or push to a branch to trigger CI.

## CI/CD (.github/workflows/build.yml)

- **Triggers:** push to any branch, tags `v*`, PRs to `master`
- **Runner:** `ubuntu-latest`
- **Matrix:** versions (4.0.4) x architectures (x86-64)
- **Release:** on `v*` tags, creates a draft GitHub release with built images

## Project Structure

```
midnightbsd-builder/
├── main.pkr.hcl                # Main Packer template (variables, source, build)
├── build.sh                    # Build entry point
├── run.sh                      # Manual VM runner (for local testing)
├── resources/
│   ├── installerconfig         # bsdinstall configuration (partitioning, install, config)
│   ├── provision.sh            # Main provisioner (packages, sudo, boot config)
│   ├── cleanup.sh              # Disk minimization
│   └── custom.sh               # Empty placeholder for custom provisioning
├── var_files/
│   ├── x86-64.pkrvars.hcl     # x86-64 architecture config
│   └── <version>/
│       ├── common.pkrvars.hcl  # Version-specific settings
│       └── x86-64.pkrvars.hcl # Version+arch ISO checksum
├── .github/workflows/build.yml # CI/CD
├── changelog.md
└── readme.md
```

### Variable File Layering (applied in order)

1. `var_files/<arch>.pkrvars.hcl` — architecture-specific (qemu arch, image arch)
2. `var_files/<version>/<arch>.pkrvars.hcl` — version+arch specific (ISO checksum)
3. `var_files/<version>/common.pkrvars.hcl` — version-specific settings

## Code Style Guidelines

### Shell Scripts (resources/*.sh, build.sh)

- Use `#!/bin/sh` (POSIX sh) for provisioning scripts; `#!/usr/bin/env sh` for build.sh
- Always set `set -eux` or `set -exu` at the top of every script
- Functions use `snake_case` naming
- Define all functions before calling them; place all calls at the bottom of the file
- Use double quotes around variable expansions: `"$variable"`
- Use heredocs (`cat <<EOF`) for multi-line file content
- Keep scripts minimal and focused on a single responsibility

### HCL2 (Packer Templates)

- Variables use `snake_case` naming
- Every variable must have `type` and `description` fields
- Use `locals` block for computed/derived values
- Annotate `boot_steps` entries with inline comments describing each installer step:
  ```hcl
  ["2<wait30s>", "Boot single user mode"]
  ```
- Separate architecture-specific and version-specific config into layered var files

### File Naming

- All filenames are lowercase
- Use underscores for shell scripts: `provision.sh`, `cleanup.sh`
- Use hyphens for architecture names: `x86-64`
- Documentation files are lowercase: `readme.md`, `changelog.md`

### Changelog

- Follow [Keep a Changelog](https://keepachangelog.com/) format
- Follow [Semantic Versioning](https://semver.org/)
- Group changes under: Added, Changed, Fixed, Removed

## Architecture Notes

### Installation Approach

MidnightBSD is FreeBSD-derived, so this builder uses `bsdinstall` with a
preconfigured `installerconfig` file (similar to the FreeBSD builder):

1. Boot the MidnightBSD installer ISO
2. Select single-user mode from the boot menu
3. Create a memory-backed tmpfs for working files
4. Configure networking via DHCP
5. Fetch `installerconfig` from Packer's HTTP server
6. Run `bsdinstall script /tmp/installerconfig` which handles: automatic disk
   partitioning (GPT with mnbsd-ufs/mnbsd-swap types), UFS filesystem creation,
   base system and kernel extraction, network/SSH/timezone configuration
7. Reboot into the installed system
8. Packer connects via SSH for provisioning

### Provisioning Pipeline (after SSH is available)

1. `provision.sh` — installs packages via `mport` (bash, curl, rsync, sudo),
   creates secondary user, configures sudo, sets boot timeout, configures boot
   scripts for authorized_keys, sets hostname, disables sendmail
2. `custom.sh` — empty placeholder for downstream customization
3. `cleanup.sh` — fills disks with zeros for better compression

### Package Management

MidnightBSD uses `mport` (not `pkg`) as its package manager. `mport` is
included in the base system and does not require bootstrapping.

### Adding a New MidnightBSD Version

1. Create `var_files/<version>/` directory
2. Add `common.pkrvars.hcl` with version-specific settings
3. Add `x86-64.pkrvars.hcl` with ISO checksum
4. Add the version to the CI matrix in `.github/workflows/build.yml`
5. Test the build: `./build.sh <version> x86-64`
6. Update `changelog.md`
