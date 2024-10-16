debug_info: []u8 = &[0]u8{},
debug_abbrev: []u8 = &[0]u8{},
debug_str: []u8 = &[0]u8{},
debug_str_offsets: []u8 = &[0]u8{},

pub fn deinit(dwarf: *Dwarf, allocator: Allocator) void {
    allocator.free(dwarf.debug_info);
    allocator.free(dwarf.debug_abbrev);
    allocator.free(dwarf.debug_str);
    allocator.free(dwarf.debug_str_offsets);
}

/// Pulls an offset into __debug_str section from a __debug_str_offs section.
/// This is new in DWARFv5 and requires the producer to specify DW_FORM_strx* (`index` arg)
/// but also DW_AT_str_offsets_base with DW_FORM_sec_offset (`base` arg) in the opening header
/// of a "referencing entity" such as DW_TAG_compile_unit.
fn getOffset(debug_str_offsets: []const u8, base: u64, index: u64, dw_fmt: DwarfFormat) u64 {
    return switch (dw_fmt) {
        .dwarf32 => @as(*align(1) const u32, @ptrCast(debug_str_offsets.ptr + base + index * @sizeOf(u32))).*,
        .dwarf64 => @as(*align(1) const u64, @ptrCast(debug_str_offsets.ptr + base + index * @sizeOf(u64))).*,
    };
}

pub const InfoReader = struct {
    ctx: Dwarf,
    pos: usize = 0,

    fn bytes(p: InfoReader) []const u8 {
        return p.ctx.debug_info;
    }

    pub fn readCompileUnitHeader(p: *InfoReader, macho_file: *MachO) !CompileUnitHeader {
        _ = macho_file;
        var length: u64 = try p.readInt(u32);
        const is_64bit = length == 0xffffffff;
        if (is_64bit) {
            length = try p.readInt(u64);
        }
        const dw_fmt: DwarfFormat = if (is_64bit) .dwarf64 else .dwarf32;
        const version = try p.readInt(Version);
        const rest: struct {
            debug_abbrev_offset: u64,
            address_size: u8,
            unit_type: u8,
        } = switch (version) {
            4 => .{
                .debug_abbrev_offset = try p.readOffset(dw_fmt),
                .address_size = try p.readByte(),
                .unit_type = 0,
            },
            5 => .{
                // According to the spec, version 5 introduced .unit_type field in the header, and
                // it reordered .debug_abbrev_offset with .address_size fields.
                .unit_type = try p.readByte(),
                .address_size = try p.readByte(),
                .debug_abbrev_offset = try p.readOffset(dw_fmt),
            },
            else => return error.InvalidVersion,
        };
        return .{
            .format = dw_fmt,
            .length = length,
            .version = version,
            .debug_abbrev_offset = rest.debug_abbrev_offset,
            .address_size = rest.address_size,
            .unit_type = rest.unit_type,
        };
    }

    pub fn seekToDie(p: *InfoReader, code: Code, cuh: CompileUnitHeader, abbrev_reader: *AbbrevReader, macho_file: *MachO) !void {
        const cuh_length = math.cast(usize, cuh.length) orelse return error.Overflow;
        const end_pos = p.pos + switch (cuh.format) {
            .dwarf32 => @as(usize, 4),
            .dwarf64 => 12,
        } + cuh_length;
        while (p.pos < end_pos) {
            const di_code = try p.readUleb128(u64);
            if (di_code == 0) return error.UnexpectedEndOfFile;
            if (di_code == code) return;

            while (try abbrev_reader.readAttr()) |attr| {
                try p.skip(attr.form, cuh, macho_file);
            }
        }
        return error.UnexpectedEndOfFile;
    }

    /// When skipping attributes, we don't really need to be able to handle them all
    /// since we only ever care about the DW_TAG_compile_unit.
    pub fn skip(p: *InfoReader, form: Form, cuh: CompileUnitHeader, macho_file: *MachO) !void {
        _ = macho_file;
        switch (form) {
            dw.FORM.sec_offset,
            dw.FORM.ref_addr,
            => {
                _ = try p.readOffset(cuh.format);
            },

            dw.FORM.addr => {
                _ = try p.readNBytes(cuh.address_size);
            },

            dw.FORM.block1,
            dw.FORM.block2,
            dw.FORM.block4,
            dw.FORM.block,
            => {
                _ = try p.readBlock(form);
            },

            dw.FORM.exprloc => {
                _ = try p.readExprLoc();
            },

            dw.FORM.flag_present => {},

            dw.FORM.data1,
            dw.FORM.ref1,
            dw.FORM.flag,
            dw.FORM.data2,
            dw.FORM.ref2,
            dw.FORM.data4,
            dw.FORM.ref4,
            dw.FORM.data8,
            dw.FORM.ref8,
            dw.FORM.ref_sig8,
            dw.FORM.udata,
            dw.FORM.ref_udata,
            dw.FORM.sdata,
            => {
                _ = try p.readConstant(form);
            },

            dw.FORM.strp,
            dw.FORM.string,
            => {
                _ = try p.readString(form, cuh);
            },

            else => if (cuh.version >= 5) switch (form) {
                dw.FORM.strx,
                dw.FORM.strx1,
                dw.FORM.strx2,
                dw.FORM.strx3,
                dw.FORM.strx4,
                => {
                    // We are just iterating over the __debug_info data, so we don't care about an actual
                    // string, therefore we set the `base = 0`.
                    _ = try p.readStringIndexed(form, cuh, 0);
                },

                dw.FORM.addrx,
                dw.FORM.addrx1,
                dw.FORM.addrx2,
                dw.FORM.addrx3,
                dw.FORM.addrx4,
                => {
                    _ = try p.readIndex(form);
                },

                else => return error.UnknownForm,
            } else return error.UnknownForm,
        }
    }

    pub fn readBlock(p: *InfoReader, form: Form) ![]const u8 {
        const len: u64 = switch (form) {
            dw.FORM.block1 => try p.readByte(),
            dw.FORM.block2 => try p.readInt(u16),
            dw.FORM.block4 => try p.readInt(u32),
            dw.FORM.block => try p.readUleb128(u64),
            else => unreachable,
        };
        return p.readNBytes(len);
    }

    pub fn readExprLoc(p: *InfoReader) ![]const u8 {
        const len: u64 = try p.readUleb128(u64);
        return p.readNBytes(len);
    }

    pub fn readConstant(p: *InfoReader, form: Form) !u64 {
        return switch (form) {
            dw.FORM.data1, dw.FORM.ref1, dw.FORM.flag => try p.readByte(),
            dw.FORM.data2, dw.FORM.ref2 => try p.readInt(u16),
            dw.FORM.data4, dw.FORM.ref4 => try p.readInt(u32),
            dw.FORM.data8, dw.FORM.ref8, dw.FORM.ref_sig8 => try p.readInt(u64),
            dw.FORM.udata, dw.FORM.ref_udata => try p.readUleb128(u64),
            dw.FORM.sdata => @bitCast(try p.readIleb128(i64)),
            else => return error.UnhandledConstantForm,
        };
    }

    pub fn readIndex(p: *InfoReader, form: Form) !u64 {
        return switch (form) {
            dw.FORM.strx1, dw.FORM.addrx1 => try p.readByte(),
            dw.FORM.strx2, dw.FORM.addrx2 => try p.readInt(u16),
            dw.FORM.strx3, dw.FORM.addrx3 => error.UnhandledDwForm,
            dw.FORM.strx4, dw.FORM.addrx4 => try p.readInt(u32),
            dw.FORM.strx, dw.FORM.addrx => try p.readUleb128(u64),
            else => return error.UnhandledIndexForm,
        };
    }

    pub fn readString(p: *InfoReader, form: Form, cuh: CompileUnitHeader) ![:0]const u8 {
        switch (form) {
            dw.FORM.strp => {
                const off = try p.readOffset(cuh.format);
                const off_u = math.cast(usize, off) orelse return error.Overflow;
                return mem.sliceTo(@as([*:0]const u8, @ptrCast(p.ctx.debug_str.ptr + off_u)), 0);
            },
            dw.FORM.string => {
                const start = p.pos;
                while (p.pos < p.bytes().len) : (p.pos += 1) {
                    if (p.bytes()[p.pos] == 0) break;
                }
                if (p.bytes()[p.pos] != 0) return error.UnexpectedEndOfFile;
                return p.bytes()[start..p.pos :0];
            },
            else => unreachable,
        }
    }

    pub fn readStringIndexed(p: *InfoReader, form: Form, cuh: CompileUnitHeader, base: u64) ![:0]const u8 {
        switch (form) {
            dw.FORM.strx,
            dw.FORM.strx1,
            dw.FORM.strx2,
            dw.FORM.strx3,
            dw.FORM.strx4,
            => {
                const index = try p.readIndex(form);
                const off = getOffset(p.ctx.debug_str_offsets, base, index, cuh.format);
                return mem.sliceTo(@as([*:0]const u8, @ptrCast(p.ctx.debug_str.ptr + off)), 0);
            },
            else => unreachable,
        }
    }

    pub fn readByte(p: *InfoReader) !u8 {
        if (p.pos + 1 > p.bytes().len) return error.UnexpectedEndOfFile;
        defer p.pos += 1;
        return p.bytes()[p.pos];
    }

    pub fn readNBytes(p: *InfoReader, num: u64) ![]const u8 {
        const num_usize = math.cast(usize, num) orelse return error.Overflow;
        if (p.pos + num_usize > p.bytes().len) return error.UnexpectedEndOfFile;
        defer p.pos += num_usize;
        return p.bytes()[p.pos..][0..num_usize];
    }

    pub fn readInt(p: *InfoReader, comptime Int: type) !Int {
        if (p.pos + @sizeOf(Int) > p.bytes().len) return error.UnexpectedEndOfFile;
        defer p.pos += @sizeOf(Int);
        return mem.readInt(Int, p.bytes()[p.pos..][0..@sizeOf(Int)], .little);
    }

    pub fn readOffset(p: *InfoReader, dw_fmt: DwarfFormat) !u64 {
        return switch (dw_fmt) {
            .dwarf32 => try p.readInt(u32),
            .dwarf64 => try p.readInt(u64),
        };
    }

    pub fn readUleb128(p: *InfoReader, comptime Type: type) !Type {
        var stream = std.io.fixedBufferStream(p.bytes()[p.pos..]);
        var creader = std.io.countingReader(stream.reader());
        const value: Type = try leb.readUleb128(Type, creader.reader());
        p.pos += math.cast(usize, creader.bytes_read) orelse return error.Overflow;
        return value;
    }

    pub fn readIleb128(p: *InfoReader, comptime Type: type) !Type {
        var stream = std.io.fixedBufferStream(p.bytes()[p.pos..]);
        var creader = std.io.countingReader(stream.reader());
        const value: Type = try leb.readIleb128(Type, creader.reader());
        p.pos += math.cast(usize, creader.bytes_read) orelse return error.Overflow;
        return value;
    }

    pub fn seekTo(p: *InfoReader, off: u64) !void {
        p.pos = math.cast(usize, off) orelse return error.Overflow;
    }
};

pub const AbbrevReader = struct {
    ctx: Dwarf,
    pos: usize = 0,

    fn bytes(p: AbbrevReader) []const u8 {
        return p.ctx.debug_abbrev;
    }

    pub fn hasMore(p: AbbrevReader) bool {
        return p.pos < p.bytes().len;
    }

    pub fn readDecl(p: *AbbrevReader) !?AbbrevDecl {
        const pos = p.pos;
        const code = try p.readUleb128(Code);
        if (code == 0) return null;

        const tag = try p.readUleb128(Tag);
        const has_children = (try p.readByte()) > 0;
        return .{
            .code = code,
            .pos = pos,
            .len = p.pos - pos,
            .tag = tag,
            .has_children = has_children,
        };
    }

    pub fn readAttr(p: *AbbrevReader) !?AbbrevAttr {
        const pos = p.pos;
        const at = try p.readUleb128(At);
        const form = try p.readUleb128(Form);
        return if (at == 0 and form == 0) null else .{
            .at = at,
            .form = form,
            .pos = pos,
            .len = p.pos - pos,
        };
    }

    pub fn readByte(p: *AbbrevReader) !u8 {
        if (p.pos + 1 > p.bytes().len) return error.Eof;
        defer p.pos += 1;
        return p.bytes()[p.pos];
    }

    pub fn readUleb128(p: *AbbrevReader, comptime Type: type) !Type {
        var stream = std.io.fixedBufferStream(p.bytes()[p.pos..]);
        var creader = std.io.countingReader(stream.reader());
        const value: Type = try leb.readUleb128(Type, creader.reader());
        p.pos += math.cast(usize, creader.bytes_read) orelse return error.Overflow;
        return value;
    }

    pub fn seekTo(p: *AbbrevReader, off: u64) !void {
        p.pos = math.cast(usize, off) orelse return error.Overflow;
    }
};

const AbbrevDecl = struct {
    code: Code,
    pos: usize,
    len: usize,
    tag: Tag,
    has_children: bool,
};

const AbbrevAttr = struct {
    at: At,
    form: Form,
    pos: usize,
    len: usize,
};

const CompileUnitHeader = struct {
    format: DwarfFormat,
    length: u64,
    version: Version,
    debug_abbrev_offset: u64,
    address_size: u8,
    unit_type: u8,
};

const Die = struct {
    pos: usize,
    len: usize,
};

const DwarfFormat = enum {
    dwarf32,
    dwarf64,
};

const dw = std.dwarf;
const leb = std.leb;
const log = std.log.scoped(.link);
const math = std.math;
const mem = std.mem;
const std = @import("std");
const Allocator = mem.Allocator;
const Dwarf = @This();
const File = @import("file.zig").File;
const MachO = @import("../MachO.zig");
const Object = @import("Object.zig");

pub const At = u64;
pub const Code = u64;
pub const Form = u64;
pub const Tag = u64;
pub const Version = u16;

pub const AT = dw.AT;
pub const FORM = dw.FORM;
pub const TAG = dw.TAG;
