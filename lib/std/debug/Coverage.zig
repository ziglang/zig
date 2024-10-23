const std = @import("../std.zig");
const Allocator = std.mem.Allocator;
const Hash = std.hash.Wyhash;
const Dwarf = std.debug.Dwarf;
const assert = std.debug.assert;

const Coverage = @This();

/// Provides a globally-scoped integer index for directories.
///
/// As opposed to, for example, a directory index that is compilation-unit
/// scoped inside a single ELF module.
///
/// String memory references the memory-mapped debug information.
///
/// Protected by `mutex`.
directories: std.ArrayHashMapUnmanaged(String, void, String.MapContext, false),
/// Provides a globally-scoped integer index for files.
///
/// String memory references the memory-mapped debug information.
///
/// Protected by `mutex`.
files: std.ArrayHashMapUnmanaged(File, void, File.MapContext, false),
string_bytes: std.ArrayListUnmanaged(u8),
/// Protects the other fields.
mutex: std.Thread.Mutex,

pub const init: Coverage = .{
    .directories = .{},
    .files = .{},
    .mutex = .{},
    .string_bytes = .{},
};

pub const String = enum(u32) {
    _,

    pub const MapContext = struct {
        string_bytes: []const u8,

        pub fn eql(self: @This(), a: String, b: String, b_index: usize) bool {
            _ = b_index;
            const a_slice = span(self.string_bytes[@intFromEnum(a)..]);
            const b_slice = span(self.string_bytes[@intFromEnum(b)..]);
            return std.mem.eql(u8, a_slice, b_slice);
        }

        pub fn hash(self: @This(), a: String) u32 {
            return @truncate(Hash.hash(0, span(self.string_bytes[@intFromEnum(a)..])));
        }
    };

    pub const SliceAdapter = struct {
        string_bytes: []const u8,

        pub fn eql(self: @This(), a_slice: []const u8, b: String, b_index: usize) bool {
            _ = b_index;
            const b_slice = span(self.string_bytes[@intFromEnum(b)..]);
            return std.mem.eql(u8, a_slice, b_slice);
        }
        pub fn hash(self: @This(), a: []const u8) u32 {
            _ = self;
            return @truncate(Hash.hash(0, a));
        }
    };
};

pub const SourceLocation = extern struct {
    file: File.Index,
    line: u32,
    column: u32,

    pub const invalid: SourceLocation = .{
        .file = .invalid,
        .line = 0,
        .column = 0,
    };
};

pub const File = extern struct {
    directory_index: u32,
    basename: String,

    pub const Index = enum(u32) {
        invalid = std.math.maxInt(u32),
        _,
    };

    pub const MapContext = struct {
        string_bytes: []const u8,

        pub fn hash(self: MapContext, a: File) u32 {
            const a_basename = span(self.string_bytes[@intFromEnum(a.basename)..]);
            return @truncate(Hash.hash(a.directory_index, a_basename));
        }

        pub fn eql(self: MapContext, a: File, b: File, b_index: usize) bool {
            _ = b_index;
            if (a.directory_index != b.directory_index) return false;
            const a_basename = span(self.string_bytes[@intFromEnum(a.basename)..]);
            const b_basename = span(self.string_bytes[@intFromEnum(b.basename)..]);
            return std.mem.eql(u8, a_basename, b_basename);
        }
    };

    pub const SliceAdapter = struct {
        string_bytes: []const u8,

        pub const Entry = struct {
            directory_index: u32,
            basename: []const u8,
        };

        pub fn hash(self: @This(), a: Entry) u32 {
            _ = self;
            return @truncate(Hash.hash(a.directory_index, a.basename));
        }

        pub fn eql(self: @This(), a: Entry, b: File, b_index: usize) bool {
            _ = b_index;
            if (a.directory_index != b.directory_index) return false;
            const b_basename = span(self.string_bytes[@intFromEnum(b.basename)..]);
            return std.mem.eql(u8, a.basename, b_basename);
        }
    };
};

pub fn deinit(cov: *Coverage, gpa: Allocator) void {
    cov.directories.deinit(gpa);
    cov.files.deinit(gpa);
    cov.string_bytes.deinit(gpa);
    cov.* = undefined;
}

pub fn fileAt(cov: *Coverage, index: File.Index) *File {
    return &cov.files.keys()[@intFromEnum(index)];
}

pub fn stringAt(cov: *Coverage, index: String) [:0]const u8 {
    return span(cov.string_bytes.items[@intFromEnum(index)..]);
}

pub const ResolveAddressesDwarfError = Dwarf.ScanError;

pub fn resolveAddressesDwarf(
    cov: *Coverage,
    gpa: Allocator,
    /// Asserts the addresses are in ascending order.
    sorted_pc_addrs: []const u64,
    /// Asserts its length equals length of `sorted_pc_addrs`.
    output: []SourceLocation,
    d: *Dwarf,
) ResolveAddressesDwarfError!void {
    assert(sorted_pc_addrs.len == output.len);
    assert(d.ranges.items.len != 0); // call `populateRanges` first.

    var range_i: usize = 0;
    var range: *std.debug.Dwarf.Range = &d.ranges.items[0];
    var line_table_i: usize = undefined;
    var prev_pc: u64 = 0;
    var prev_cu: ?*std.debug.Dwarf.CompileUnit = null;
    // Protects directories and files tables from other threads.
    cov.mutex.lock();
    defer cov.mutex.unlock();
    next_pc: for (sorted_pc_addrs, output) |pc, *out| {
        assert(pc >= prev_pc);
        prev_pc = pc;

        while (pc >= range.end) {
            range_i += 1;
            if (range_i >= d.ranges.items.len) {
                out.* = SourceLocation.invalid;
                continue :next_pc;
            }
            range = &d.ranges.items[range_i];
        }
        if (pc < range.start) {
            out.* = SourceLocation.invalid;
            continue :next_pc;
        }
        const cu = &d.compile_unit_list.items[range.compile_unit_index];
        if (cu != prev_cu) {
            prev_cu = cu;
            if (cu.src_loc_cache == null) {
                cov.mutex.unlock();
                defer cov.mutex.lock();
                d.populateSrcLocCache(gpa, cu) catch |err| switch (err) {
                    error.MissingDebugInfo, error.InvalidDebugInfo => {
                        out.* = SourceLocation.invalid;
                        continue :next_pc;
                    },
                    else => |e| return e,
                };
            }
            const slc = &cu.src_loc_cache.?;
            const table_addrs = slc.line_table.keys();
            line_table_i = std.sort.upperBound(u64, table_addrs, pc, struct {
                fn order(context: u64, item: u64) std.math.Order {
                    return std.math.order(context, item);
                }
            }.order);
        }
        const slc = &cu.src_loc_cache.?;
        const table_addrs = slc.line_table.keys();
        while (line_table_i < table_addrs.len and table_addrs[line_table_i] <= pc) line_table_i += 1;

        const entry = slc.line_table.values()[line_table_i - 1];
        const corrected_file_index = entry.file - @intFromBool(slc.version < 5);
        const file_entry = slc.files[corrected_file_index];
        const dir_path = slc.directories[file_entry.dir_index].path;
        try cov.string_bytes.ensureUnusedCapacity(gpa, dir_path.len + file_entry.path.len + 2);
        const dir_gop = try cov.directories.getOrPutContextAdapted(gpa, dir_path, String.SliceAdapter{
            .string_bytes = cov.string_bytes.items,
        }, String.MapContext{
            .string_bytes = cov.string_bytes.items,
        });
        if (!dir_gop.found_existing)
            dir_gop.key_ptr.* = addStringAssumeCapacity(cov, dir_path);
        const file_gop = try cov.files.getOrPutContextAdapted(gpa, File.SliceAdapter.Entry{
            .directory_index = @intCast(dir_gop.index),
            .basename = file_entry.path,
        }, File.SliceAdapter{
            .string_bytes = cov.string_bytes.items,
        }, File.MapContext{
            .string_bytes = cov.string_bytes.items,
        });
        if (!file_gop.found_existing) file_gop.key_ptr.* = .{
            .directory_index = @intCast(dir_gop.index),
            .basename = addStringAssumeCapacity(cov, file_entry.path),
        };
        out.* = .{
            .file = @enumFromInt(file_gop.index),
            .line = entry.line,
            .column = entry.column,
        };
    }
}

pub fn addStringAssumeCapacity(cov: *Coverage, s: []const u8) String {
    const result: String = @enumFromInt(cov.string_bytes.items.len);
    cov.string_bytes.appendSliceAssumeCapacity(s);
    cov.string_bytes.appendAssumeCapacity(0);
    return result;
}

fn span(s: []const u8) [:0]const u8 {
    return std.mem.sliceTo(@as([:0]const u8, @ptrCast(s)), 0);
}
