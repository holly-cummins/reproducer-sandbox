# Reproducer Sandbox
Scripts to support running bug reproducers in an isolated environment.

Open source projects often receive reproducers with bug reports. Maintainers will download the reproducers onto their local machine to try and fix the problem. 
Unfortunately, reproducers can contain malicious payloads. These payloads can be well-disguised in dependencies or maven wrappers, so just inspecting repository contents before downloading isn't enough to stay safe. 

But open source maintainers have a lot to do! Making it too hard to run reproducers doesn't help anyone. 

These scripts had the following goals: 

- Trivial to use, ideally just one or two lines with no advance setup
- A bot could paste the command to run the sandbox onto GitHub issues with a reproducer, so that it was easier to run sandboxed than not
- A comfy 'local-first' development experience
- Cross-platform

(I haven't come near to achieving those goals yet, but this is a starting step!)

The solution has the following elements:

- *A VM for isolation*. I'm using [Tart](https://tart.run/) since I'm on Mac, but I'll need to extend this to go cross-platform. Base images can be quickly cloned, and then thrown away once the bug is fixed.
- *Local IDE*. [JetBrains Gateway](https://www.jetbrains.com/remote-development/gateway/) allows local editing against a remote machine. 
- *Access to local maven repository.* Usually, when I'm running a reproducer, I'll want to run it against a `999-SNAPSHOT` version of the open source project, and continue editing that project locally. But I don't want to mount my maven repository into the isolated VM, or I lose all the isolation. Overlay filesystems are the answer. The scripts mount my maven repo into the sandbox, so it can see my patched dependencies, but any changes made by the isolated VM go onto an overlay filesystem.

## Prerequisites

- macOS with Apple Silicon
- [Tart](https://tart.run/) — lightweight VMs using Apple's Virtualization.framework
- [JetBrains Gateway](https://www.jetbrains.com/remote-development/gateway/) — remote IDE access
- An SSH key (defaults to `~/.ssh/id_ed25519.pub`)

Install Tart:

```bash
brew install cirruslabs/cli/tart
```

## One-time setup: create a base VM image

Create a base image with the JDK and build tools pre-installed. This image gets cloned for each reproducer, so you only do this once.

```bash
tart clone ghcr.io/cirruslabs/ubuntu:latest reproducer-base
tart run reproducer-base
```
We use ubuntu because Gateway is designed to run against remote Linux systems.
Inside the VM, install what you need:

```bash
sudo apt-get update
sudo apt-get install -y openjdk-21-jdk maven git
sudo shutdown -h now
```

## Usage

Without downloading anything:

```bash
bash <(curl -s https://raw.githubusercontent.com/holly-cummins/reproducer-sandbox/main/sandbox-reproducer) https://github.com/someone/their-reproducer.git
```

Or, if you have the script locally:

```bash
./sandbox-reproducer https://github.com/someone/their-reproducer.git
```

Be a bit patient, as launching can take a minute or so. Gateway will show a confirmation dialog — click **Confirm Connection**.
If macOS asks whether to give IDEA access to your keychain, click **Deny** (the reproducer doesn't need access to your local credentials).

You get a full IntelliJ experience — code completion, debugging, refactoring — with all code and builds running safely inside the VM.

The script will:

1. Clone the base VM image to create an isolated, disposable copy
2. Boot the VM headless
3. Copy your SSH key into the VM
4. Mount your local `~/.m2` as a read-only overlay (the VM can see your cached artifacts and snapshots, but can't modify your host `.m2`)
5. Download and install the IntelliJ IDEA backend inside the VM (Gateway does this automatically when connecting interactively, but [not when launched via a URL scheme](https://youtrack.jetbrains.com/projects/TBX/issues/TBX-14811/Support-Launching-Remote-IDE-via-URL-Scheme-in-Toolbox))
6. Clone the reproducer repo inside the VM
7. Open JetBrains Gateway connected to the project


### Cleanup

When you're done, the script prints the commands to stop and delete the VM:

```bash
kill <pid> && tart delete <vm-name>
```

### Configuration

| Environment variable | Default | Description |
|---|---|---|
| `TART_BASE_IMAGE` | `reproducer-base` | Name of the Tart base image to clone |
| `SSH_KEY` | `~/.ssh/id_ed25519.pub` | SSH public key to install in the VM |
