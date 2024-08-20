# Zig GNU C Library ("glibc") Support

Zig supports building binaries that will dynamically link against the
[GNU C Library ("glibc")](https://www.gnu.org/software/libc/) when run.
This support extends across a range of glibc versions.

By default, Zig binaries will not depend on any external C library, but
they can be linked against one with the `-lc` option.  The target ABI defines
which C library: `musl` for the [musl C library](https://musl.libc.org/) or
`gnu` for the GNU C library.

A specific GNU C library version can be chosen with an appropriate
`-target`.  For example, `-target native-native-gnu.2.19` will use the
default CPU and OS targets, but will link in a run-time dependency on
glibc v2.19 (or later).  Use `zig env` to show the default target and
version.

Glibc symbols are defined in the `std.c.` namespace in Zig, though the
`std.os.` namespace is generally what should be used to access C-library
APIs in Zig code (it is defined depending on the linked C library).

See `src/glibc.zig` for how Zig will build the glibc components.  The
generated shared object files are sufficient only for compile-time
linking. They are stub libraries that only indicate that which symbols
will be present at run-time, along with their type and size.  The symbols
do not reference an actual implementation.

## Targets

The GNU C Library supports a very wide set of platforms and architectures.
The current Zig support for glibc only includes Linux.

Zig supports glibc versions back to v2.17 (2012) as the Zig standard
library depends on symbols that were introduced in 2.17. When used as a C
or C++ compiler (i.e., `zig cc`) zig supports glibc versions back to
v2.2.5.

## Glibc stubs

The file `lib/libc/glibc/abilist` is a Zig-specific binary blob that
defines the supported glibc versions and the set of symbols each version
must define.  See https://github.com/ziglang/glibc-abi-tool for the
tooling to generate this blob.  The code in `glibc.zig` parses the abilist
to build version-specific stub libraries on demand.

The generated stub library is used for compile-time linking, with the
expectation that at run-time the real glibc library will provide the
actual symbol implementations.

### Public Headers

The glibc headers are in `lib/libc/include/generic-glibc/`.  These are
customized and have a couple Zig-specific `#ifdef`s to make the single set
of headers represent any of the supported glibc versions.  There are
currently a handful of patches to these headers to represent new features
(e.g. `reallocarray`) or changes in implementation (e.g., the `stat()`
family of functions).

The related Zig https://github.com/ziglang/universal-headers is a project
designed to more robustly build multi-version header files suitable for
compilation across a variety of target C library versions.

## Glibc static C-Runtime object files and libraries

Linking against glibc also implies linking against several, generally
"invisible" glibc C Runtime libraries: `crti.o`, `crtn.o`, `Scrt1.o` and
`libc_nonshared.a`.  These objects are linked into generated Zig binaries
and are not run-time linking dependencies.  Generally they provide
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
https://github.com/ziglang/zig/commit/2314051acaad37dd5630dd7eca08571d620d6496
for an example commit that updates glibc (to v2.38).
