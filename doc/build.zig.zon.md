# build.zig.zon Documentation

This is the manifest file for build.zig scripts. It is named build.zig.zon in
order to make it clear that it is metadata specifically pertaining to
build.zig.

- **build root** - the directory that contains `build.zig`

## Top-Level Fields

### `name`

Enum literal. Required.

This is the default name used by packages depending on this one. For example,
when a user runs `zig fetch --save <url>`, this field is used as the key in the
`dependencies` table. Although the user can choose a different name, most users
will stick with this provided value.

It is redundant to include "zig" in this name because it is already within the
Zig package namespace.

Must be a valid bare Zig identifier (don't `@` me), limited to 32 bytes.

Together with `nonce`, this represents a globally unique package identifier.

### `nonce`

Together with `name`, this represents a globally unique package identifier. This
field is auto-initialized by the toolchain when the package is first created,
and then *never changes*. This allows Zig to unambiguously detect when one
package is an updated version of another.

When forking a Zig project, this nonce should be regenerated if the upstream
project is still maintained. Otherwise, the fork is *hostile*, attempting to
take control over the original project's identity. The nonce can be regenerated
by deleting the field and running `zig build`.

This 64-bit integer is the combination of a 32-bit id component and a 32-bit
checksum.

The id component within the nonce has these restrictions:

`0x00000000` is reserved for legacy packages.

`0xffffffff` is reserved to represent "naked" packages.

The checksum is computed from `name` and serves to protect Zig users from
accidental id collisions.

### `version`

String. Required.

[semver](https://semver.org/)

Limited to 32 bytes.

### `minimum_zig_version`

String. Optional.

[semver](https://semver.org/)

This is currently advisory only; the compiler does not yet do anything
with this version.

### `dependencies`

Struct.

Each dependency must either provide a `url` and `hash`, or a `path`.

#### `url`

String. 

When updating this field to a new URL, be sure to delete the corresponding
`hash`, otherwise you are communicating that you expect to find the old hash at
the new URL. If the contents of a URL change this will result in a hash mismatch
which will prevent zig from using it.

#### `hash`

String. 

[multihash](https://multiformats.io/multihash/)

This is computed from the file contents of the directory of files that is
obtained after fetching `url` and applying the inclusion rules given by
`paths`.

This field is the source of truth; packages do not come from a `url`; they
come from a `hash`. `url` is just one of many possible mirrors for how to
obtain a package matching this `hash`.

#### `path`

String.

When this is provided, the package is found in a directory relative to the
build root. In this case the package's hash is irrelevant and therefore not
computed. This field and `url` are mutually exclusive.

#### `lazy`

Boolean.

When this is set to `true`, a package is declared to be lazily fetched. This
makes the dependency only get fetched if it is actually used.

### `paths`

List. Required.

Specifies the set of files and directories that are included in this package.
Paths are relative to the build root. Use the empty string (`""`) to refer to
the build root itself.

Only files included in the package are used to compute a package's `hash`.
