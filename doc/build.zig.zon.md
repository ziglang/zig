# build.zig.zon Documentation

This is the manifest file for build.zig scripts. It is named build.zig.zon in
order to make it clear that it is metadata specifically pertaining to
build.zig.

- **build root** - the directory that contains `build.zig`

## Top-Level Fields

### `name`

String. Required.

### `version`

String. Required.

[semver](https://semver.org/)

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
the new URL.

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
