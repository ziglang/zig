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
const assert = std.debug.assert;
const Coverage = std.debug.Coverage;
const SourceLocation = std.debug.Coverage.SourceLocation;

const ElfFile = std.debug.ElfFile;
const MachOFile = std.debug.MachOFile;

const Info = @This();

impl: union(enum) {
    elf: ElfFile,
    macho: MachOFile,
},
/// Externally managed, outlives this `Info` instance.
coverage: *Coverage,

pub const LoadError = std.fs.File.OpenError || ElfFile.LoadError || MachOFile.Error || std.debug.Dwarf.ScanError || error{ MissingDebugInfo, UnsupportedDebugInfo };

pub fn load(gpa: Allocator, path: Path, coverage: *Coverage, format: std.Target.ObjectFormat, arch: std.Target.Cpu.Arch) LoadError!Info {
    switch (format) {
        .elf => {
            var file = try path.root_dir.handle.openFile(path.sub_path, .{});
            defer file.close();

            var elf_file: ElfFile = try .load(gpa, file, null, &.none);
            errdefer elf_file.deinit(gpa);

            if (elf_file.dwarf == null) return error.MissingDebugInfo;
            try elf_file.dwarf.?.open(gpa, elf_file.endian);
            try elf_file.dwarf.?.populateRanges(gpa, elf_file.endian);

            return .{
                .impl = .{ .elf = elf_file },
                .coverage = coverage,
            };
        },
        .macho => {
            const path_str = try path.toString(gpa);
            defer gpa.free(path_str);

            var macho_file: MachOFile = try .load(gpa, path_str, arch);
            errdefer macho_file.deinit(gpa);

            return .{
                .impl = .{ .macho = macho_file },
                .coverage = coverage,
            };
        },
        else => return error.UnsupportedDebugInfo,
    }
}

pub fn deinit(info: *Info, gpa: Allocator) void {
    switch (info.impl) {
        .elf => |*ef| ef.deinit(gpa),
        .macho => |*mf| mf.deinit(gpa),
    }
    info.* = undefined;
}

pub const ResolveAddressesError = Coverage.ResolveAddressesDwarfError || error{UnsupportedDebugInfo};

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
    switch (info.impl) {
        .elf => |*ef| return info.coverage.resolveAddressesDwarf(gpa, ef.endian, sorted_pc_addrs, output, &ef.dwarf.?),
        .macho => |*mf| {
            // Resolving all of the addresses at once unfortunately isn't so easy in Mach-O binaries
            // due to split debug information. For now, we'll just resolve the addreses one by one.
            for (sorted_pc_addrs, output) |pc_addr, *src_loc| {
                const dwarf, const dwarf_pc_addr = mf.getDwarfForAddress(gpa, pc_addr) catch |err| switch (err) {
                    error.InvalidMachO, error.InvalidDwarf => return error.InvalidDebugInfo,
                    else => |e| return e,
                };
                if (dwarf.ranges.items.len == 0) {
                    dwarf.populateRanges(gpa, .little) catch |err| switch (err) {
                        error.EndOfStream,
                        error.Overflow,
                        error.StreamTooLong,
                        error.ReadFailed,
                        => return error.InvalidDebugInfo,
                        else => |e| return e,
                    };
                }
                try info.coverage.resolveAddressesDwarf(gpa, .little, &.{dwarf_pc_addr}, src_loc[0..1], dwarf);
            }
        },
    }
}
