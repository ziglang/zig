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
const Hash = std.hash.Wyhash;

const Info = @This();

/// Sorted by key, ascending.
address_map: std.AutoArrayHashMapUnmanaged(u64, Dwarf.ElfModule),

/// Provides a globally-scoped integer index for directories.
///
/// As opposed to, for example, a directory index that is compilation-unit
/// scoped inside a single ELF module.
///
/// String memory references the memory-mapped debug information.
///
/// Protected by `mutex`.
directories: std.StringArrayHashMapUnmanaged(void),
/// Provides a globally-scoped integer index for files.
///
/// String memory references the memory-mapped debug information.
///
/// Protected by `mutex`.
files: std.ArrayHashMapUnmanaged(File, void, File.MapContext, false),
/// Protects `directories` and `files`.
mutex: std.Thread.Mutex,

pub const SourceLocation = struct {
    file: File.Index,
    line: u32,
    column: u32,

    pub const invalid: SourceLocation = .{
        .file = .invalid,
        .line = 0,
        .column = 0,
    };
};

pub const File = struct {
    directory_index: u32,
    basename: []const u8,

    pub const Index = enum(u32) {
        invalid = std.math.maxInt(u32),
        _,
    };

    pub const MapContext = struct {
        pub fn hash(ctx: MapContext, a: File) u32 {
            _ = ctx;
            return @truncate(Hash.hash(a.directory_index, a.basename));
        }

        pub fn eql(ctx: MapContext, a: File, b: File, b_index: usize) bool {
            _ = ctx;
            _ = b_index;
            return a.directory_index == b.directory_index and std.mem.eql(u8, a.basename, b.basename);
        }
    };
};

pub const LoadError = Dwarf.ElfModule.LoadError;

pub fn load(gpa: Allocator, path: Path) LoadError!Info {
    var sections: Dwarf.SectionArray = Dwarf.null_section_array;
    var elf_module = try Dwarf.ElfModule.loadPath(gpa, path, null, null, &sections, null);
    try elf_module.dwarf.sortCompileUnits();
    var info: Info = .{
        .address_map = .{},
        .directories = .{},
        .files = .{},
        .mutex = .{},
    };
    try info.address_map.put(gpa, elf_module.base_address, elf_module);
    return info;
}

pub fn deinit(info: *Info, gpa: Allocator) void {
    info.directories.deinit(gpa);
    info.files.deinit(gpa);
    for (info.address_map.values()) |*elf_module| {
        elf_module.dwarf.deinit(gpa);
    }
    info.address_map.deinit(gpa);
    info.* = undefined;
}

pub fn fileAt(info: *Info, index: File.Index) *File {
    return &info.files.keys()[@intFromEnum(index)];
}

pub const ResolveSourceLocationsError = Dwarf.ScanError;

/// Given an array of virtual memory addresses, sorted ascending, outputs a
/// corresponding array of source locations.
pub fn resolveSourceLocations(
    info: *Info,
    gpa: Allocator,
    sorted_pc_addrs: []const u64,
    /// Asserts its length equals length of `sorted_pc_addrs`.
    output: []SourceLocation,
) ResolveSourceLocationsError!void {
    assert(sorted_pc_addrs.len == output.len);
    if (info.address_map.entries.len != 1) @panic("TODO");
    const elf_module = &info.address_map.values()[0];
    return resolveSourceLocationsDwarf(info, gpa, sorted_pc_addrs, output, &elf_module.dwarf);
}

pub fn resolveSourceLocationsDwarf(
    info: *Info,
    gpa: Allocator,
    sorted_pc_addrs: []const u64,
    /// Asserts its length equals length of `sorted_pc_addrs`.
    output: []SourceLocation,
    d: *Dwarf,
) ResolveSourceLocationsError!void {
    assert(sorted_pc_addrs.len == output.len);
    assert(d.compile_units_sorted);

    var cu_i: usize = 0;
    var line_table_i: usize = 0;
    var cu: *Dwarf.CompileUnit = &d.compile_unit_list.items[0];
    var range = cu.pc_range.?;
    // Protects directories and files tables from other threads.
    info.mutex.lock();
    defer info.mutex.unlock();
    next_pc: for (sorted_pc_addrs, output) |pc, *out| {
        while (pc >= range.end) {
            cu_i += 1;
            if (cu_i >= d.compile_unit_list.items.len) {
                out.* = SourceLocation.invalid;
                continue :next_pc;
            }
            cu = &d.compile_unit_list.items[cu_i];
            line_table_i = 0;
            range = cu.pc_range orelse {
                out.* = SourceLocation.invalid;
                continue :next_pc;
            };
        }
        if (pc < range.start) {
            out.* = SourceLocation.invalid;
            continue :next_pc;
        }
        if (line_table_i == 0) {
            line_table_i = 1;
            info.mutex.unlock();
            defer info.mutex.lock();
            d.populateSrcLocCache(gpa, cu) catch |err| switch (err) {
                error.MissingDebugInfo, error.InvalidDebugInfo => {
                    out.* = SourceLocation.invalid;
                    cu_i += 1;
                    if (cu_i < d.compile_unit_list.items.len) {
                        cu = &d.compile_unit_list.items[cu_i];
                        line_table_i = 0;
                        if (cu.pc_range) |r| range = r;
                    }
                    continue :next_pc;
                },
                else => |e| return e,
            };
        }
        const slc = &cu.src_loc_cache.?;
        const table_addrs = slc.line_table.keys();
        while (line_table_i < table_addrs.len and table_addrs[line_table_i] < pc) line_table_i += 1;

        const entry = slc.line_table.values()[line_table_i - 1];
        const corrected_file_index = entry.file - @intFromBool(slc.version < 5);
        const file_entry = slc.files[corrected_file_index];
        const dir_path = slc.directories[file_entry.dir_index].path;
        const dir_gop = try info.directories.getOrPut(gpa, dir_path);
        const file_gop = try info.files.getOrPut(gpa, .{
            .directory_index = @intCast(dir_gop.index),
            .basename = file_entry.path,
        });
        out.* = .{
            .file = @enumFromInt(file_gop.index),
            .line = entry.line,
            .column = entry.column,
        };
    }
}
