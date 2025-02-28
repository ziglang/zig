//! Cross-platform abstraction for loading debug information into an in-memory
//! format that supports queries such as "what is the source location of this
//! virtual memory address?"
//!
//! Unlike `std.debug.SelfInfo`, this API does not assume the debug information
//! in question happens to match the host CPU architecture, OS, or other target
//! properties.

const std = @import("../std.zig");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const Path = std.Build.Cache.Path;
const Dwarf = std.debug.Dwarf;
const assert = std.debug.assert;
const Coverage = std.debug.Coverage;
const SourceLocation = std.debug.Coverage.SourceLocation;

const Info = @This();

/// Sorted by key, ascending.
address_map: std.AutoArrayHashMapUnmanaged(u64, std.debug.SelfInfo.Module),
/// Externally managed, outlives this `Info` instance.
coverage: *Coverage,

pub const LoadError = Dwarf.ElfModule.LoadError;

pub fn load(gpa: Allocator, path: Path, coverage: *Coverage) LoadError!Info {
    var sections: Dwarf.SectionArray = Dwarf.null_section_array;
    var info: Info = .{
        .address_map = .{},
        .coverage = coverage,
    };
    switch (builtin.os.tag) {
        .linux => {
            var elf_module = try Dwarf.ElfModule.loadPath(gpa, path, null, null, &sections, null);
            try elf_module.dwarf.populateRanges(gpa);
            try info.address_map.put(gpa, elf_module.base_address, elf_module);
        },
        .macos => {
            const macho_file = path.root_dir.handle.openFile(path.sub_path, .{}) catch |err| switch (err) {
                error.FileNotFound => return error.MissingDebugInfo,
                else => return error.InvalidDebugInfo,
            };
            // readMachoDebugInfo takes ownership of the file
            // defer elf_file.close();
            var module = std.debug.SelfInfo.readMachODebugInfo(gpa, macho_file) catch {
                return error.InvalidDebugInfo;
            };

            module.base_address = 0;
            module.vmaddr_slide = 0;

            try info.address_map.put(gpa, 0, module);
        },
        else => @compileError("TODO: implement debug info loading for the target platform"),
    }
    return info;
}

pub fn deinit(info: *Info, gpa: Allocator) void {
    // for (info.address_map.values()) |*module| {
    //     module.dwarf.deinit(gpa);
    // }
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
    switch (builtin.os.tag) {
        else => @compileError("unsupported"),
        .linux => {
            const elf_module = &info.address_map.values()[0];
            return info.coverage.resolveAddressesDwarf(gpa, sorted_pc_addrs, output, &elf_module.dwarf);
        },
        .macos => {
            const module = &info.address_map.values()[0];

            var idx: usize = 0;
            while (idx < sorted_pc_addrs.len) {
                const dw = (module.getDwarfInfoForAddress(gpa, sorted_pc_addrs[idx]) catch return error.InvalidDebugInfo).?;
                try dw.populateRanges(gpa);
                const last = dw.ranges.getLastOrNull() orelse return;
                var end_idx = idx;
                while (end_idx < sorted_pc_addrs.len and
                    sorted_pc_addrs[end_idx] < last.end) end_idx += 1;

                if (end_idx == idx) {
                    std.debug.print("made no progress", .{});
                    return;
                }

                try info.coverage.resolveAddressesDwarf(
                    gpa,
                    sorted_pc_addrs[idx..end_idx],
                    output[idx..end_idx],
                    dw,
                );

                idx = end_idx;
            }
        },
    }
}
