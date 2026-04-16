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
- *Access to local maven repository/* Usually, when I'm running a reproducer, I'll want to run it against a `999-SNAPSHOT` version of the open source project, and continue editing that project locally. But I don't want to mount my maven repository into the isolated VM, or I lose all the isolation. Overlay filesystems are the answer. The scripts mount my maven repo into the sandbox, so it can see my patched dependencies, but any changes made by the isolated VM go onto an overlay filesystem

