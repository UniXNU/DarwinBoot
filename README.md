# DarwinBoot

UEFI XNU loader with packed RAM disk handoff support.

The Mach-O parser accepts arm64 and arm64e MH_EXECUTE kernels, including
the capability bits in the arm64e CPU subtype. XNU initializes pointer
authentication and applies its own chained fixups. MH_FILESET input is
still unsupported by this loader.

UniXNU passes the selected boot entry's arguments to DarwinBoot, which copies
them into XNU's command line and prints `DARWINBOOT: command line:` before
handoff. The top green bar marks `DarwinEnter` before cache maintenance,
MMU shutdown and the branch to XNU. Follow the
[boot argument workflow](https://unixnu.com/xnu/boot-arguments#apply-arguments)
and [green-bar diagnosis](https://unixnu.com/guide/debugging#green-bar).

Before the branch DarwinBoot draws the hand-off facts on the framebuffer when a
display is available: the kernel's link and physical addresses, the entry point,
the window handed over, the first words at that entry and the video geometry. A
board with no serial console can then be photographed instead of guessed at, and
those lines stay visible until the kernel draws over them.

DarwinBoot also installs its own `VBAR_EL1` for the window between the branch and
the kernel's own vectors. A fault there paints the top sixteenth of the
framebuffer red and encodes `ESR`, `ELR` and `FAR` as 64-bit bar codes underneath,
which is the only report available when the firmware's handlers are gone.

Build and interface details: [documentation](https://unixnu.com/reference/components).
Sources and dependencies: [catalog](https://unixnu.com/reference/components).

The optional `kernel.macho.vroot` sidecar carries up to 128 MiB of signed root
policies. The loader checks its envelope and supplies its physical range as
`/chosen/memory-map/RootPolicies`. XNU authenticates the policies using an owner
anchor compiled into the source storage runtime. This handoff is independent
of the Data RAM disk, GPU addon and Apple trust cache. The new handoff has not
yet been built or exercised.
