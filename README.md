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

The memory handed to XNU is one window of `/chosen/darwinboot-memory-size` bytes (256 MiB by default). Without
further properties it is a single run of free memory. With `/chosen/darwinboot-memory-excluded`, a property of
empty 16-byte pairs, the window may span gaps between DRAM banks and memory the firmware keeps: the loader picks
the start with the most usable memory, allocates only the head (the loaded image plus the larger of 1/64 of the
window and 32 MiB for the tables XNU places behind it), and writes the ranges XNU must not use into the property
as ascending `(base, size)` pairs from the memory map that `ExitBootServices` accepts. Free and loader memory are
usable; boot services memory stays excluded. `boot_args.memSize` is the window and `memSizeActual` the usable
bytes. If the window has more excluded ranges than the property holds, neighbours with the least usable memory
between them are joined. The kernel must read the property: only an OS profile whose XNU carries that support
may request it. Before the hand-off every usable range leaves the data cache, as the single-run window does, so
the firmware must keep free memory mapped; excluded ranges are never touched. With 4 KiB pages XNU's bootstrap
tables map at most 6 GiB, which bounds the window. The excluded-range hand-off has not run on hardware.

Host checks: `Test/test-memory-window.py` (window selection and the table on synthetic memory maps),
`Test/test-adt-window.py` (the device tree properties), `Test/test-kernel-parser.py`,
`Test/test-packed-ramdisk.py` and `Test/window-size.c`.

Build and interface details: [documentation](https://unixnu.com/reference/components).
Sources and dependencies: [catalog](https://unixnu.com/reference/components).

The optional `kernel.macho.vroot` sidecar carries up to 128 MiB of signed root
policies. The loader checks its envelope and supplies its physical range as
`/chosen/memory-map/RootPolicies`. XNU authenticates the policies using an owner
anchor compiled into the source storage runtime. This handoff is independent
of the Data RAM disk, GPU addon and Apple trust cache. The new handoff has not
yet been built or exercised.
