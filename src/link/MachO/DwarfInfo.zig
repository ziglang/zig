/// Abbreviation table indexed by offset in the .debug_abbrev bytestream
abbrev_tables: std.AutoArrayHashMapUnmanaged(u64, AbbrevTable) = .{},
/// List of compile units as they appear in the .debug_info bytestream
compile_units: std.ArrayListUnmanaged(CompileUnit) = .{},
/// Debug info string table
strtab: std.ArrayListUnmanaged(u8) = .{},
/// Debug info data
di_data: std.ArrayListUnmanaged(u8) = .{},

pub fn init(dw: *DwarfInfo, allocator: Allocator, di: DebugInfo) !void {
    try dw.strtab.ensureTotalCapacityPrecise(allocator, di.debug_str.len);
    dw.strtab.appendSliceAssumeCapacity(di.debug_str);
    try dw.parseAbbrevTables(allocator, di);
    try dw.parseCompileUnits(allocator, di);
}

pub fn deinit(dw: *DwarfInfo, allocator: Allocator) void {
    dw.abbrev_tables.deinit(allocator);
    for (dw.compile_units.items) |*cu| {
        cu.deinit(allocator);
    }
    dw.compile_units.deinit(allocator);
    dw.strtab.deinit(allocator);
    dw.di_data.deinit(allocator);
}

fn appendDiData(dw: *DwarfInfo, allocator: Allocator, values: []const u8) error{OutOfMemory}!u32 {
    const index: u32 = @intCast(dw.di_data.items.len);
    try dw.di_data.ensureUnusedCapacity(allocator, values.len);
    dw.di_data.appendSliceAssumeCapacity(values);
    return index;
}

fn getString(dw: DwarfInfo, off: usize) [:0]const u8 {
    assert(off < dw.strtab.items.len);
    return mem.sliceTo(@as([*:0]const u8, @ptrCast(dw.strtab.items.ptr + off)), 0);
}

fn parseAbbrevTables(dw: *DwarfInfo, allocator: Allocator, di: DebugInfo) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const debug_abbrev = di.debug_abbrev;
    var stream = std.io.fixedBufferStream(debug_abbrev);
    var creader = std.io.countingReader(stream.reader());
    const reader = creader.reader();

    while (true) {
        if (creader.bytes_read >= debug_abbrev.len) break;

        try dw.abbrev_tables.ensureUnusedCapacity(allocator, 1);
        const table_gop = dw.abbrev_tables.getOrPutAssumeCapacity(@intCast(creader.bytes_read));
        assert(!table_gop.found_existing);
        const table = table_gop.value_ptr;
        table.* = .{};

        while (true) {
            const code = try leb.readULEB128(Code, reader);
            if (code == 0) break;

            try table.decls.ensureUnusedCapacity(allocator, 1);
            const decl_gop = table.decls.getOrPutAssumeCapacity(code);
            assert(!decl_gop.found_existing);
            const decl = decl_gop.value_ptr;
            decl.* = .{
                .code = code,
                .tag = undefined,
                .children = false,
            };
            decl.tag = try leb.readULEB128(Tag, reader);
            decl.children = (try reader.readByte()) > 0;

            while (true) {
                const at = try leb.readULEB128(At, reader);
                const form = try leb.readULEB128(Form, reader);
                if (at == 0 and form == 0) break;

                try decl.attrs.ensureUnusedCapacity(allocator, 1);
                const attr_gop = decl.attrs.getOrPutAssumeCapacity(at);
                assert(!attr_gop.found_existing);
                const attr = attr_gop.value_ptr;
                attr.* = .{
                    .at = at,
                    .form = form,
                };
            }
        }
    }
}

fn parseCompileUnits(dw: *DwarfInfo, allocator: Allocator, di: DebugInfo) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const debug_info = di.debug_info;
    var stream = std.io.fixedBufferStream(debug_info);
    var creader = std.io.countingReader(stream.reader());
    const reader = creader.reader();

    while (true) {
        if (creader.bytes_read == debug_info.len) break;

        const cu = try dw.compile_units.addOne(allocator);
        cu.* = .{
            .header = undefined,
            .pos = creader.bytes_read,
        };

        var length: u64 = try reader.readInt(u32, .little);
        const is_64bit = length == 0xffffffff;
        if (is_64bit) {
            length = try reader.readInt(u64, .little);
        }
        cu.header.format = if (is_64bit) .dwarf64 else .dwarf32;
        cu.header.length = length;
        cu.header.version = try reader.readInt(u16, .little);
        cu.header.debug_abbrev_offset = try readOffset(cu.header.format, reader);
        cu.header.address_size = try reader.readInt(u8, .little);

        const table = dw.abbrev_tables.get(cu.header.debug_abbrev_offset).?;
        try dw.parseDie(allocator, cu, table, di, null, &creader);
    }
}

fn parseDie(
    dw: *DwarfInfo,
    allocator: Allocator,
    cu: *CompileUnit,
    table: AbbrevTable,
    di: DebugInfo,
    parent: ?u32,
    creader: anytype,
) anyerror!void {
    const tracy = trace(@src());
    defer tracy.end();

    while (creader.bytes_read < cu.nextCompileUnitOffset()) {
        const die = try cu.addDie(allocator);
        cu.diePtr(die).* = .{ .code = undefined };
        if (parent) |p| {
            try cu.diePtr(p).children.append(allocator, die);
        } else {
            try cu.children.append(allocator, die);
        }

        const code = try leb.readULEB128(Code, creader.reader());
        cu.diePtr(die).code = code;

        if (code == 0) {
            if (parent == null) continue;
            return; // Close scope
        }

        const decl = table.decls.get(code) orelse return error.MalformedDwarf; // TODO better errors
        const data = di.debug_info;
        try cu.diePtr(die).values.ensureTotalCapacityPrecise(allocator, decl.attrs.values().len);

        for (decl.attrs.values()) |attr| {
            const start = std.math.cast(usize, creader.bytes_read) orelse return error.Overflow;
            try advanceByFormSize(cu, attr.form, creader);
            const end = std.math.cast(usize, creader.bytes_read) orelse return error.Overflow;
            const index = try dw.appendDiData(allocator, data[start..end]);
            cu.diePtr(die).values.appendAssumeCapacity(.{ .index = index, .len = @intCast(end - start) });
        }

        if (decl.children) {
            // Open scope
            try dw.parseDie(allocator, cu, table, di, die, creader);
        }
    }
}

fn advanceByFormSize(cu: *CompileUnit, form: Form, creader: anytype) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const reader = creader.reader();
    switch (form) {
        dwarf.FORM.strp,
        dwarf.FORM.sec_offset,
        dwarf.FORM.ref_addr,
        => {
            _ = try readOffset(cu.header.format, reader);
        },

        dwarf.FORM.addr => try reader.skipBytes(cu.header.address_size, .{}),

        dwarf.FORM.block1,
        dwarf.FORM.block2,
        dwarf.FORM.block4,
        dwarf.FORM.block,
        => {
            const len: u64 = switch (form) {
                dwarf.FORM.block1 => try reader.readInt(u8, .little),
                dwarf.FORM.block2 => try reader.readInt(u16, .little),
                dwarf.FORM.block4 => try reader.readInt(u32, .little),
                dwarf.FORM.block => try leb.readULEB128(u64, reader),
                else => unreachable,
            };
            var i: u64 = 0;
            while (i < len) : (i += 1) {
                _ = try reader.readByte();
            }
        },

        dwarf.FORM.exprloc => {
            const len = try leb.readULEB128(u64, reader);
            var i: u64 = 0;
            while (i < len) : (i += 1) {
                _ = try reader.readByte();
            }
        },
        dwarf.FORM.flag_present => {},

        dwarf.FORM.data1,
        dwarf.FORM.ref1,
        dwarf.FORM.flag,
        => try reader.skipBytes(1, .{}),

        dwarf.FORM.data2,
        dwarf.FORM.ref2,
        => try reader.skipBytes(2, .{}),

        dwarf.FORM.data4,
        dwarf.FORM.ref4,
        => try reader.skipBytes(4, .{}),

        dwarf.FORM.data8,
        dwarf.FORM.ref8,
        dwarf.FORM.ref_sig8,
        => try reader.skipBytes(8, .{}),

        dwarf.FORM.udata,
        dwarf.FORM.ref_udata,
        => {
            _ = try leb.readULEB128(u64, reader);
        },

        dwarf.FORM.sdata => {
            _ = try leb.readILEB128(i64, reader);
        },

        dwarf.FORM.string => {
            while (true) {
                const byte = try reader.readByte();
                if (byte == 0x0) break;
            }
        },

        else => {
            // TODO better errors
            log.err("unhandled DW_FORM_* value with identifier {x}", .{form});
            return error.UnhandledDwFormValue;
        },
    }
}

fn readOffset(format: Format, reader: anytype) !u64 {
    return switch (format) {
        .dwarf32 => try reader.readInt(u32, .little),
        .dwarf64 => try reader.readInt(u64, .little),
    };
}

pub const AbbrevTable = struct {
    /// Table of abbreviation declarations indexed by their assigned code value
    decls: std.AutoArrayHashMapUnmanaged(Code, Decl) = .{},

    pub fn deinit(table: *AbbrevTable, gpa: Allocator) void {
        for (table.decls.values()) |*decl| {
            decl.deinit(gpa);
        }
        table.decls.deinit(gpa);
    }
};

pub const Decl = struct {
    code: Code,
    tag: Tag,
    children: bool,

    /// Table of attributes indexed by their AT value
    attrs: std.AutoArrayHashMapUnmanaged(At, Attr) = .{},

    pub fn deinit(decl: *Decl, gpa: Allocator) void {
        decl.attrs.deinit(gpa);
    }
};

pub const Attr = struct {
    at: At,
    form: Form,
};

pub const At = u64;
pub const Code = u64;
pub const Form = u64;
pub const Tag = u64;

pub const CompileUnitHeader = struct {
    format: Format,
    length: u64,
    version: u16,
    debug_abbrev_offset: u64,
    address_size: u8,
};

pub const CompileUnit = struct {
    header: CompileUnitHeader,
    pos: u64,
    dies: std.ArrayListUnmanaged(Die) = .{},
    children: std.ArrayListUnmanaged(Die.Index) = .{},

    pub fn deinit(cu: *CompileUnit, gpa: Allocator) void {
        for (cu.dies.items) |*die| {
            die.deinit(gpa);
        }
        cu.dies.deinit(gpa);
        cu.children.deinit(gpa);
    }

    pub fn addDie(cu: *CompileUnit, gpa: Allocator) !Die.Index {
        const index = @as(Die.Index, @intCast(cu.dies.items.len));
        _ = try cu.dies.addOne(gpa);
        return index;
    }

    pub fn diePtr(cu: *CompileUnit, index: Die.Index) *Die {
        return &cu.dies.items[index];
    }

    pub fn getCompileDir(cu: CompileUnit, ctx: DwarfInfo) error{Overflow}!?[:0]const u8 {
        assert(cu.dies.items.len > 0);
        const die = cu.dies.items[0];
        const res = die.find(dwarf.AT.comp_dir, cu, ctx) orelse return null;
        return res.getString(cu.header.format, ctx);
    }

    pub fn getSourceFile(cu: CompileUnit, ctx: DwarfInfo) error{Overflow}!?[:0]const u8 {
        assert(cu.dies.items.len > 0);
        const die = cu.dies.items[0];
        const res = die.find(dwarf.AT.name, cu, ctx) orelse return null;
        return res.getString(cu.header.format, ctx);
    }

    pub fn nextCompileUnitOffset(cu: CompileUnit) u64 {
        return cu.pos + switch (cu.header.format) {
            .dwarf32 => @as(u64, 4),
            .dwarf64 => 12,
        } + cu.header.length;
    }
};

pub const Die = struct {
    code: Code,
    values: std.ArrayListUnmanaged(struct { index: u32, len: u32 }) = .{},
    children: std.ArrayListUnmanaged(Die.Index) = .{},

    pub fn deinit(die: *Die, gpa: Allocator) void {
        die.values.deinit(gpa);
        die.children.deinit(gpa);
    }

    pub fn find(die: Die, at: At, cu: CompileUnit, ctx: DwarfInfo) ?DieValue {
        const table = ctx.abbrev_tables.get(cu.header.debug_abbrev_offset) orelse return null;
        const decl = table.decls.get(die.code).?;
        const index = decl.attrs.getIndex(at) orelse return null;
        const attr = decl.attrs.values()[index];
        const value = die.values.items[index];
        return .{ .attr = attr, .bytes = ctx.di_data.items[value.index..][0..value.len] };
    }

    pub const Index = u32;
};

pub const DieValue = struct {
    attr: Attr,
    bytes: []const u8,

    pub fn getFlag(value: DieValue) ?bool {
        return switch (value.attr.form) {
            dwarf.FORM.flag => value.bytes[0] == 1,
            dwarf.FORM.flag_present => true,
            else => null,
        };
    }

    pub fn getString(value: DieValue, format: Format, ctx: DwarfInfo) error{Overflow}!?[:0]const u8 {
        switch (value.attr.form) {
            dwarf.FORM.string => {
                return mem.sliceTo(@as([*:0]const u8, @ptrCast(value.bytes.ptr)), 0);
            },
            dwarf.FORM.strp => {
                const off = switch (format) {
                    .dwarf64 => mem.readInt(u64, value.bytes[0..8], .little),
                    .dwarf32 => mem.readInt(u32, value.bytes[0..4], .little),
                };
                const off_u = std.math.cast(usize, off) orelse return error.Overflow;
                return ctx.getString(off_u);
            },
            else => return null,
        }
    }

    pub fn getSecOffset(value: DieValue, format: Format) ?u64 {
        return switch (value.attr.form) {
            dwarf.FORM.sec_offset => switch (format) {
                .dwarf32 => mem.readInt(u32, value.bytes[0..4], .little),
                .dwarf64 => mem.readInt(u64, value.bytes[0..8], .little),
            },
            else => null,
        };
    }

    pub fn getConstant(value: DieValue) !?i128 {
        var stream = std.io.fixedBufferStream(value.bytes);
        const reader = stream.reader();
        return switch (value.attr.form) {
            dwarf.FORM.data1 => value.bytes[0],
            dwarf.FORM.data2 => mem.readInt(u16, value.bytes[0..2], .little),
            dwarf.FORM.data4 => mem.readInt(u32, value.bytes[0..4], .little),
            dwarf.FORM.data8 => mem.readInt(u64, value.bytes[0..8], .little),
            dwarf.FORM.udata => try leb.readULEB128(u64, reader),
            dwarf.FORM.sdata => try leb.readILEB128(i64, reader),
            else => null,
        };
    }

    pub fn getReference(value: DieValue, format: Format) !?u64 {
        var stream = std.io.fixedBufferStream(value.bytes);
        const reader = stream.reader();
        return switch (value.attr.form) {
            dwarf.FORM.ref1 => value.bytes[0],
            dwarf.FORM.ref2 => mem.readInt(u16, value.bytes[0..2], .little),
            dwarf.FORM.ref4 => mem.readInt(u32, value.bytes[0..4], .little),
            dwarf.FORM.ref8 => mem.readInt(u64, value.bytes[0..8], .little),
            dwarf.FORM.ref_udata => try leb.readULEB128(u64, reader),
            dwarf.FORM.ref_addr => switch (format) {
                .dwarf32 => mem.readInt(u32, value.bytes[0..4], .little),
                .dwarf64 => mem.readInt(u64, value.bytes[0..8], .little),
            },
            else => null,
        };
    }

    pub fn getAddr(value: DieValue, header: CompileUnitHeader) ?u64 {
        return switch (value.attr.form) {
            dwarf.FORM.addr => switch (header.address_size) {
                1 => value.bytes[0],
                2 => mem.readInt(u16, value.bytes[0..2], .little),
                4 => mem.readInt(u32, value.bytes[0..4], .little),
                8 => mem.readInt(u64, value.bytes[0..8], .little),
                else => null,
            },
            else => null,
        };
    }

    pub fn getExprloc(value: DieValue) !?[]const u8 {
        if (value.attr.form != dwarf.FORM.exprloc) return null;
        var stream = std.io.fixedBufferStream(value.bytes);
        var creader = std.io.countingReader(stream.reader());
        const reader = creader.reader();
        const expr_len = try leb.readULEB128(u64, reader);
        return value.bytes[creader.bytes_read..][0..expr_len];
    }
};

pub const Format = enum {
    dwarf32,
    dwarf64,
};

const DebugInfo = struct {
    debug_info: []const u8,
    debug_abbrev: []const u8,
    debug_str: []const u8,
};

const assert = std.debug.assert;
const dwarf = std.dwarf;
const leb = std.leb;
const log = std.log.scoped(.link);
const mem = std.mem;
const std = @import("std");
const trace = @import("../../tracy.zig").trace;

const Allocator = mem.Allocator;
const DwarfInfo = @This();
const MachO = @import("../MachO.zig");
