pub const InfoReader = struct {
    bytes: []const u8,
    strtab: []const u8,
    pos: usize = 0,

    pub fn readCompileUnitHeader(p: *InfoReader) !CompileUnitHeader {
        var length: u64 = try p.readInt(u32);
        const is_64bit = length == 0xffffffff;
        if (is_64bit) {
            length = try p.readInt(u64);
        }
        const dw_fmt: DwarfFormat = if (is_64bit) .dwarf64 else .dwarf32;
        return .{
            .format = dw_fmt,
            .length = length,
            .version = try p.readInt(u16),
            .debug_abbrev_offset = try p.readOffset(dw_fmt),
            .address_size = try p.readByte(),
        };
    }

    pub fn seekToDie(p: *InfoReader, code: Code, cuh: CompileUnitHeader, abbrev_reader: *AbbrevReader) !void {
        const cuh_length = math.cast(usize, cuh.length) orelse return error.Overflow;
        const end_pos = p.pos + switch (cuh.format) {
            .dwarf32 => @as(usize, 4),
            .dwarf64 => 12,
        } + cuh_length;
        while (p.pos < end_pos) {
            const di_code = try p.readULEB128(u64);
            if (di_code == 0) return error.Eof;
            if (di_code == code) return;

            while (try abbrev_reader.readAttr()) |attr| switch (attr.at) {
                dwarf.FORM.sec_offset,
                dwarf.FORM.ref_addr,
                => {
                    _ = try p.readOffset(cuh.format);
                },

                dwarf.FORM.addr => {
                    _ = try p.readNBytes(cuh.address_size);
                },

                dwarf.FORM.block1,
                dwarf.FORM.block2,
                dwarf.FORM.block4,
                dwarf.FORM.block,
                => {
                    _ = try p.readBlock(attr.form);
                },

                dwarf.FORM.exprloc => {
                    _ = try p.readExprLoc();
                },

                dwarf.FORM.flag_present => {},

                dwarf.FORM.data1,
                dwarf.FORM.ref1,
                dwarf.FORM.flag,
                dwarf.FORM.data2,
                dwarf.FORM.ref2,
                dwarf.FORM.data4,
                dwarf.FORM.ref4,
                dwarf.FORM.data8,
                dwarf.FORM.ref8,
                dwarf.FORM.ref_sig8,
                dwarf.FORM.udata,
                dwarf.FORM.ref_udata,
                dwarf.FORM.sdata,
                => {
                    _ = try p.readConstant(attr.form);
                },

                dwarf.FORM.strp,
                dwarf.FORM.string,
                => {
                    _ = try p.readString(attr.form, cuh);
                },

                else => {
                    // TODO better errors
                    log.err("unhandled DW_FORM_* value with identifier {x}", .{attr.form});
                    return error.UnhandledDwFormValue;
                },
            };
        }
    }

    pub fn readBlock(p: *InfoReader, form: Form) ![]const u8 {
        const len: u64 = switch (form) {
            dwarf.FORM.block1 => try p.readByte(),
            dwarf.FORM.block2 => try p.readInt(u16),
            dwarf.FORM.block4 => try p.readInt(u32),
            dwarf.FORM.block => try p.readULEB128(u64),
            else => unreachable,
        };
        return p.readNBytes(len);
    }

    pub fn readExprLoc(p: *InfoReader) ![]const u8 {
        const len: u64 = try p.readULEB128(u64);
        return p.readNBytes(len);
    }

    pub fn readConstant(p: *InfoReader, form: Form) !u64 {
        return switch (form) {
            dwarf.FORM.data1, dwarf.FORM.ref1, dwarf.FORM.flag => try p.readByte(),
            dwarf.FORM.data2, dwarf.FORM.ref2 => try p.readInt(u16),
            dwarf.FORM.data4, dwarf.FORM.ref4 => try p.readInt(u32),
            dwarf.FORM.data8, dwarf.FORM.ref8, dwarf.FORM.ref_sig8 => try p.readInt(u64),
            dwarf.FORM.udata, dwarf.FORM.ref_udata => try p.readULEB128(u64),
            dwarf.FORM.sdata => @bitCast(try p.readILEB128(i64)),
            else => return error.UnhandledConstantForm,
        };
    }

    pub fn readString(p: *InfoReader, form: Form, cuh: CompileUnitHeader) ![:0]const u8 {
        switch (form) {
            dwarf.FORM.strp => {
                const off = try p.readOffset(cuh.format);
                const off_u = math.cast(usize, off) orelse return error.Overflow;
                return mem.sliceTo(@as([*:0]const u8, @ptrCast(p.strtab.ptr + off_u)), 0);
            },
            dwarf.FORM.string => {
                const start = p.pos;
                while (p.pos < p.bytes.len) : (p.pos += 1) {
                    if (p.bytes[p.pos] == 0) break;
                }
                if (p.bytes[p.pos] != 0) return error.Eof;
                return p.bytes[start..p.pos :0];
            },
            else => unreachable,
        }
    }

    pub fn readByte(p: *InfoReader) !u8 {
        if (p.pos + 1 > p.bytes.len) return error.Eof;
        defer p.pos += 1;
        return p.bytes[p.pos];
    }

    pub fn readNBytes(p: *InfoReader, num: u64) ![]const u8 {
        const num_usize = math.cast(usize, num) orelse return error.Overflow;
        if (p.pos + num_usize > p.bytes.len) return error.Eof;
        defer p.pos += num_usize;
        return p.bytes[p.pos..][0..num_usize];
    }

    pub fn readInt(p: *InfoReader, comptime Int: type) !Int {
        if (p.pos + @sizeOf(Int) > p.bytes.len) return error.Eof;
        defer p.pos += @sizeOf(Int);
        return mem.readInt(Int, p.bytes[p.pos..][0..@sizeOf(Int)], .little);
    }

    pub fn readOffset(p: *InfoReader, dw_fmt: DwarfFormat) !u64 {
        return switch (dw_fmt) {
            .dwarf32 => try p.readInt(u32),
            .dwarf64 => try p.readInt(u64),
        };
    }

    pub fn readULEB128(p: *InfoReader, comptime Type: type) !Type {
        var stream = std.io.fixedBufferStream(p.bytes[p.pos..]);
        var creader = std.io.countingReader(stream.reader());
        const value: Type = try leb.readULEB128(Type, creader.reader());
        p.pos += math.cast(usize, creader.bytes_read) orelse return error.Overflow;
        return value;
    }

    pub fn readILEB128(p: *InfoReader, comptime Type: type) !Type {
        var stream = std.io.fixedBufferStream(p.bytes[p.pos..]);
        var creader = std.io.countingReader(stream.reader());
        const value: Type = try leb.readILEB128(Type, creader.reader());
        p.pos += math.cast(usize, creader.bytes_read) orelse return error.Overflow;
        return value;
    }

    pub fn seekTo(p: *InfoReader, off: u64) !void {
        p.pos = math.cast(usize, off) orelse return error.Overflow;
    }
};

pub const AbbrevReader = struct {
    bytes: []const u8,
    pos: usize = 0,

    pub fn hasMore(p: AbbrevReader) bool {
        return p.pos < p.bytes.len;
    }

    pub fn readDecl(p: *AbbrevReader) !?AbbrevDecl {
        const pos = p.pos;
        const code = try p.readULEB128(Code);
        if (code == 0) return null;

        const tag = try p.readULEB128(Tag);
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
        const at = try p.readULEB128(At);
        const form = try p.readULEB128(Form);
        return if (at == 0 and form == 0) null else .{
            .at = at,
            .form = form,
            .pos = pos,
            .len = p.pos - pos,
        };
    }

    pub fn readByte(p: *AbbrevReader) !u8 {
        if (p.pos + 1 > p.bytes.len) return error.Eof;
        defer p.pos += 1;
        return p.bytes[p.pos];
    }

    pub fn readULEB128(p: *AbbrevReader, comptime Type: type) !Type {
        var stream = std.io.fixedBufferStream(p.bytes[p.pos..]);
        var creader = std.io.countingReader(stream.reader());
        const value: Type = try leb.readULEB128(Type, creader.reader());
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
    version: u16,
    debug_abbrev_offset: u64,
    address_size: u8,
};

const Die = struct {
    pos: usize,
    len: usize,
};

const DwarfFormat = enum {
    dwarf32,
    dwarf64,
};

const dwarf = std.dwarf;
const leb = std.leb;
const log = std.log.scoped(.link);
const math = std.math;
const mem = std.mem;
const std = @import("std");

const At = u64;
const Code = u64;
const Form = u64;
const Tag = u64;

pub const AT = dwarf.AT;
pub const FORM = dwarf.FORM;
pub const TAG = dwarf.TAG;
