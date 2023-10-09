//! Corresponds to something that Zig source code can `@import`.
//! Not to be confused with src/Module.zig which should be renamed
//! to something else. https://github.com/ziglang/zig/issues/14307

/// Only files inside this directory can be imported.
root: Package.Path,
/// Relative to `root`. May contain path separators.
root_src_path: []const u8,
/// Name used in compile errors. Looks like "root.foo.bar".
fully_qualified_name: []const u8,
/// The dependency table of this module. Shared dependencies such as 'std',
/// 'builtin', and 'root' are not specified in every dependency table, but
/// instead only in the table of `main_mod`. `Module.importFile` is
/// responsible for detecting these names and using the correct package.
deps: Deps = .{},

pub const Deps = std.StringHashMapUnmanaged(*Module);

pub const Tree = struct {
    /// Each `Package` exposes a `Module` with build.zig as its root source file.
    build_module_table: std.AutoArrayHashMapUnmanaged(MultiHashHexDigest, *Module),
};

pub fn create(allocator: Allocator, m: Module) Allocator.Error!*Module {
    const new = try allocator.create(Module);
    new.* = m;
    return new;
}

const Module = @This();
const Package = @import("../Package.zig");
const std = @import("std");
const Allocator = std.mem.Allocator;
const MultiHashHexDigest = Package.Manifest.MultiHashHexDigest;
