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
const Coverage = std.debug.Coverage;
const SourceLocation = std.debug.Coverage.SourceLocation;

const Info = @This();

/// Sorted by key, ascending.
address_map: std.AutoArrayHashMapUnmanaged(u64, Dwarf.ElfModule),
/// Externally managed, outlives this `Info` instance.
coverage: *Coverage,

pub const LoadError = Dwarf.ElfModule.LoadError;

pub fn load(gpa: Allocator, path: Path, coverage: *Coverage) LoadError!Info {
    var sections: Dwarf.SectionArray = Dwarf.null_section_array;
    var elf_module = try Dwarf.ElfModule.loadPath(gpa, path, null, null, &sections, null);
    try elf_module.dwarf.populateRanges(gpa);
    var info: Info = .{
        .address_map = .{},
        .coverage = coverage,
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

pub const ResolveAddressesError = Coverage.ResolveAddressesDwarfError;

/// Given an array of virtual memory addresses, sorted ascending, outputs a
/// corresponding array of source locations.
pub fn resolveAddresses(
    info: *Info,
    gpa: Allocator,
    /// Asserts the addresses are in ascending order.
    sorted_pc_addrs: []const u64,
    /// Asserts its length equals length of `sorted_pc_addrs`.
    output: []SourceLocation,
) ResolveAddressesError!void {
    assert(sorted_pc_addrs.len == output.len);
    if (info.address_map.entries.len != 1) @panic("TODO");
    const elf_module = &info.address_map.values()[0];
    return info.coverage.resolveAddressesDwarf(gpa, sorted_pc_addrs, output, &elf_module.dwarf);
}
