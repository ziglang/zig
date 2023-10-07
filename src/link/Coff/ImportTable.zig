//! Represents an import table in the .idata section where each contained pointer
//! is to a symbol from the same DLL.
//!
//! The layout of .idata section is as follows:
//!
//! --- ADDR1 : IAT (all import tables concatenated together)
//!     ptr
//!     ptr
//!     0 sentinel
//!     ptr
//!     0 sentinel
//! --- ADDR2: headers
//!     ImportDirectoryEntry header
//!     ImportDirectoryEntry header
//!     sentinel
//! --- ADDR2: lookup tables
//!     Lookup table
//!     0 sentinel
//!     Lookup table
//!     0 sentinel
//! --- ADDR3: name hint tables
//!     hint-symname
//!     hint-symname
//! --- ADDR4: DLL names
//!     DLL#1 name
//!     DLL#2 name
//! --- END

entries: std.ArrayListUnmanaged(SymbolWithLoc) = .{},
free_list: std.ArrayListUnmanaged(u32) = .{},
lookup: std.AutoHashMapUnmanaged(SymbolWithLoc, u32) = .{},

pub fn deinit(itab: *ImportTable, allocator: Allocator) void {
    itab.entries.deinit(allocator);
    itab.free_list.deinit(allocator);
    itab.lookup.deinit(allocator);
}

/// Size of the import table does not include the sentinel.
pub fn size(itab: ImportTable) u32 {
    return @as(u32, @intCast(itab.entries.items.len)) * @sizeOf(u64);
}

pub fn addImport(itab: *ImportTable, allocator: Allocator, target: SymbolWithLoc) !ImportIndex {
    try itab.entries.ensureUnusedCapacity(allocator, 1);
    const index: u32 = blk: {
        if (itab.free_list.popOrNull()) |index| {
            log.debug("  (reusing import entry index {d})", .{index});
            break :blk index;
        } else {
            log.debug("  (allocating import entry at index {d})", .{itab.entries.items.len});
            const index = @as(u32, @intCast(itab.entries.items.len));
            _ = itab.entries.addOneAssumeCapacity();
            break :blk index;
        }
    };
    itab.entries.items[index] = target;
    try itab.lookup.putNoClobber(allocator, target, index);
    return index;
}

const Context = struct {
    coff_file: *const Coff,
    /// Index of this ImportTable in a global list of all tables.
    /// This is required in order to calculate the base vaddr of this ImportTable.
    index: usize,
    /// Offset into the string interning table of the DLL this ImportTable corresponds to.
    name_off: u32,
};

fn getBaseAddress(ctx: Context) u32 {
    const header = ctx.coff_file.sections.items(.header)[ctx.coff_file.idata_section_index.?];
    var addr = header.virtual_address;
    for (ctx.coff_file.import_tables.values(), 0..) |other_itab, i| {
        if (ctx.index == i) break;
        addr += @as(u32, @intCast(other_itab.entries.items.len * @sizeOf(u64))) + 8;
    }
    return addr;
}

pub fn getImportAddress(itab: *const ImportTable, target: SymbolWithLoc, ctx: Context) ?u32 {
    const index = itab.lookup.get(target) orelse return null;
    const base_vaddr = getBaseAddress(ctx);
    return base_vaddr + index * @sizeOf(u64);
}

const FormatContext = struct {
    itab: ImportTable,
    ctx: Context,
};

fn fmt(
    fmt_ctx: FormatContext,
    comptime unused_format_string: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) @TypeOf(writer).Error!void {
    _ = options;
    comptime assert(unused_format_string.len == 0);
    const lib_name = fmt_ctx.ctx.coff_file.temp_strtab.getAssumeExists(fmt_ctx.ctx.name_off);
    const base_vaddr = getBaseAddress(fmt_ctx.ctx);
    try writer.print("IAT({s}.dll) @{x}:", .{ lib_name, base_vaddr });
    for (fmt_ctx.itab.entries.items, 0..) |entry, i| {
        try writer.print("\n  {d}@{?x} => {s}", .{
            i,
            fmt_ctx.itab.getImportAddress(entry, fmt_ctx.ctx),
            fmt_ctx.ctx.coff_file.getSymbolName(entry),
        });
    }
}

fn format(itab: ImportTable, comptime unused_format_string: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
    _ = itab;
    _ = unused_format_string;
    _ = options;
    _ = writer;
    @compileError("do not format ImportTable directly; use itab.fmtDebug()");
}

pub fn fmtDebug(itab: ImportTable, ctx: Context) std.fmt.Formatter(fmt) {
    return .{ .data = .{ .itab = itab, .ctx = ctx } };
}

pub const ImportIndex = u32;
const ImportTable = @This();

const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.link);

const Allocator = std.mem.Allocator;
const Coff = @import("../Coff.zig");
const SymbolWithLoc = Coff.SymbolWithLoc;
