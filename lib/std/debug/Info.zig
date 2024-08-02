//! Cross-platform abstraction for loading debug information into an in-memory
//! format that supports queries such as "what is the source location of this
//! virtual memory address?"
//!
//! Unlike `std.debug.SelfInfo`, this API does not assume the debug information
//! in question happens to match the host CPU architecture, OS, or other target
//! properties.

const std = @import("../std.zig");
const Allocator = std.mem.Allocator;
const Path = std.Build.Cache.Path;
const Dwarf = std.debug.Dwarf;
const page_size = std.mem.page_size;
const assert = std.debug.assert;

const Info = @This();

/// Sorted by key, ascending.
address_map: std.AutoArrayHashMapUnmanaged(u64, Dwarf.ElfModule),

pub const LoadError = Dwarf.ElfModule.LoadError;

pub fn load(gpa: Allocator, path: Path) LoadError!Info {
    var sections: Dwarf.SectionArray = Dwarf.null_section_array;
    const elf_module = try Dwarf.ElfModule.loadPath(gpa, path, null, null, &sections, null);
    var info: Info = .{
        .address_map = .{},
    };
    try info.address_map.put(gpa, elf_module.base_address, elf_module);
    return info;
}

pub fn deinit(info: *Info, gpa: Allocator) void {
    for (info.address_map.values()) |*elf_module| {
        elf_module.dwarf.deinit(gpa);
    }
    info.address_map.deinit(gpa);
    info.* = undefined;
}

pub const ResolveSourceLocationsError = error{
    MissingDebugInfo,
    InvalidDebugInfo,
} || Allocator.Error;

pub fn resolveSourceLocations(
    info: *Info,
    gpa: Allocator,
    sorted_pc_addrs: []const u64,
    /// Asserts its length equals length of `sorted_pc_addrs`.
    output: []std.debug.SourceLocation,
) ResolveSourceLocationsError!void {
    assert(sorted_pc_addrs.len == output.len);
    if (info.address_map.entries.len != 1) @panic("TODO");
    const elf_module = &info.address_map.values()[0];
    return elf_module.dwarf.resolveSourceLocations(gpa, sorted_pc_addrs, output);
}
