# Zig GNU C Library ("glibc") Support

*Date*: October, 2023

Zig supports building binaries that will dynamically link against the
[GNU C Library ("glibc")](https://www.gnu.org/software/libc/) when run.
This support extends across a range of glibc versions.

Zig binaries, by default, will not depend on any external C library.
Also, Zig binaries can be built against the
[musl C library](https://musl.libc.org/) (which will be linked in
statically).  Or they can depend on glibc, which will create a run-time
linking dependency.  Use the `-lc` option ask to Zig to link to a C
runtime.

A specific C library version can be chosen with an appropriate `-target`.
For example, `-target native-native-gnu.2.19` will use the default CPU and
OS targets, but will link in a run-time dependency on glibc v2.19 (or
later).  The `zig env` command will show the default target and version.

See `src/glibc.zig` for how Zig will build the glibc components.  The core
C library is sufficient only for compile-time linking (it is a stub
library just needs to say the symbol will be present at run-time, it
doesn't actually have to implement said symbol).

Glibc symbols are defined in the `std.c.` namespace in Zig, though the
`std.os.` namespace is generally what should be used to access C-library
APIs in Zig code (it is defined depending on the linked C library).

## Targets

The GNU C Library supports a very wide set of platforms and architectures.
The current Zig support for glibc only supports Linux.  Extend
`src/glibc.zig` to support additional platforms.

## Glibc stubs

The file `lib/libc/glibc/abilist` is a Zig-specific binary blob that
defines the supported glibc versions and the set of symbols each version
must define.  See https://github.com/ziglang/glibc-abi-tool for the
tooling to generate this blob.  The code in `glibc.zig` parses the abilist
to build version-specific stub libraries.

This generated stub library is used for compile-time linking, with the
expectation that at run-time the real glibc library will provide the
actual symbol implementations.

### Public Headers

The glibc headers are in `lib/libc/include/generic-glibc/`.  These are
customized and have a couple Zig-specific `#ifdef` to make the single set
of headers represent any of the supported glibc versions.  There are
currently a handful of patches to these headers to represent new features
(e.g. `reallocarray`) or changes in implementation (e.g., the `stat()`
family of functions).

## Glibc static C-Runtime object files and libraries

Linking against glibc also implies linking against several, generally
"invisible" glibc C Runtime libraries: `crti.o`, `crtn.o`, `Scrt1.o` and
`libc_nonshared.a`.  These objects are linked into generated binaries and
are not run-time linking dependencies.  Generally they provide
bootstrapping, initialization, and mapping of un-versioned public APIs to
glibc-private versioned APIs.

Like the public headers, these files contain a couple customiziations for
Zig to be able to build for any supported glibc version.  E.g., for glibc
versions before v2.32, `libc_nonshared.a` contained stubs that directed
the `fstat()` call to a versioned `__fxstat()` call.

These files used for these objects are in `lib/libc/glibc`.  See the
`tools/update_glibc.zig` tool for updating content in here from the
upstream glibc.

# More Information

See
https://github.com/jacobly0/zig/commit/2314051acaad37dd5630dd7eca08571d620d6496
for an example commit that updates glibc (to v2.38).

See https://github.com/ziglang/universal-headers for a project designed to
more robustly build multi-version header files suitable for compliation
across a variety of target C library versions.
