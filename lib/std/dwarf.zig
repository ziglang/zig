const builtin = @import("builtin");
const std = @import("std.zig");
const debug = std.debug;
const fs = std.fs;
const io = std.io;
const os = std.os;
const mem = std.mem;
const math = std.math;
const leb = @import("leb128.zig");

pub const TAG = @import("dwarf/TAG.zig");
pub const AT = @import("dwarf/AT.zig");
pub const OP = @import("dwarf/OP.zig");
pub const LANG = @import("dwarf/LANG.zig");
pub const FORM = @import("dwarf/FORM.zig");
pub const ATE = @import("dwarf/ATE.zig");
pub const EH = @import("dwarf/EH.zig");
pub const abi = @import("dwarf/abi.zig");
pub const call_frame = @import("dwarf/call_frame.zig");
pub const expressions = @import("dwarf/expressions.zig");

pub const LLE = struct {
    pub const end_of_list = 0x00;
    pub const base_addressx = 0x01;
    pub const startx_endx = 0x02;
    pub const startx_length = 0x03;
    pub const offset_pair = 0x04;
    pub const default_location = 0x05;
    pub const base_address = 0x06;
    pub const start_end = 0x07;
    pub const start_length = 0x08;
};

pub const CFA = struct {
    pub const advance_loc = 0x40;
    pub const offset = 0x80;
    pub const restore = 0xc0;
    pub const nop = 0x00;
    pub const set_loc = 0x01;
    pub const advance_loc1 = 0x02;
    pub const advance_loc2 = 0x03;
    pub const advance_loc4 = 0x04;
    pub const offset_extended = 0x05;
    pub const restore_extended = 0x06;
    pub const @"undefined" = 0x07;
    pub const same_value = 0x08;
    pub const register = 0x09;
    pub const remember_state = 0x0a;
    pub const restore_state = 0x0b;
    pub const def_cfa = 0x0c;
    pub const def_cfa_register = 0x0d;
    pub const def_cfa_offset = 0x0e;

    // DWARF 3.
    pub const def_cfa_expression = 0x0f;
    pub const expression = 0x10;
    pub const offset_extended_sf = 0x11;
    pub const def_cfa_sf = 0x12;
    pub const def_cfa_offset_sf = 0x13;
    pub const val_offset = 0x14;
    pub const val_offset_sf = 0x15;
    pub const val_expression = 0x16;

    pub const lo_user = 0x1c;
    pub const hi_user = 0x3f;

    // SGI/MIPS specific.
    pub const MIPS_advance_loc8 = 0x1d;

    // GNU extensions.
    pub const GNU_window_save = 0x2d;
    pub const GNU_args_size = 0x2e;
    pub const GNU_negative_offset_extended = 0x2f;
};

pub const CHILDREN = struct {
    pub const no = 0x00;
    pub const yes = 0x01;
};

pub const LNS = struct {
    pub const extended_op = 0x00;
    pub const copy = 0x01;
    pub const advance_pc = 0x02;
    pub const advance_line = 0x03;
    pub const set_file = 0x04;
    pub const set_column = 0x05;
    pub const negate_stmt = 0x06;
    pub const set_basic_block = 0x07;
    pub const const_add_pc = 0x08;
    pub const fixed_advance_pc = 0x09;
    pub const set_prologue_end = 0x0a;
    pub const set_epilogue_begin = 0x0b;
    pub const set_isa = 0x0c;
};

pub const LNE = struct {
    pub const end_sequence = 0x01;
    pub const set_address = 0x02;
    pub const define_file = 0x03;
    pub const set_discriminator = 0x04;
    pub const lo_user = 0x80;
    pub const hi_user = 0xff;
};

pub const UT = struct {
    pub const compile = 0x01;
    pub const @"type" = 0x02;
    pub const partial = 0x03;
    pub const skeleton = 0x04;
    pub const split_compile = 0x05;
    pub const split_type = 0x06;

    pub const lo_user = 0x80;
    pub const hi_user = 0xff;
};

pub const LNCT = struct {
    pub const path = 0x1;
    pub const directory_index = 0x2;
    pub const timestamp = 0x3;
    pub const size = 0x4;
    pub const MD5 = 0x5;

    pub const lo_user = 0x2000;
    pub const hi_user = 0x3fff;
};

pub const RLE = struct {
    pub const end_of_list = 0x00;
    pub const base_addressx = 0x01;
    pub const startx_endx = 0x02;
    pub const startx_length = 0x03;
    pub const offset_pair = 0x04;
    pub const base_address = 0x05;
    pub const start_end = 0x06;
    pub const start_length = 0x07;
};

pub const CC = enum(u8) {
    normal = 0x1,
    program = 0x2,
    nocall = 0x3,

    pass_by_reference = 0x4,
    pass_by_value = 0x5,

    lo_user = 0x40,
    hi_user = 0xff,

    GNU_renesas_sh = 0x40,
    GNU_borland_fastcall_i386 = 0x41,
};

pub const Format = enum { @"32", @"64" };

const PcRange = struct {
    start: u64,
    end: u64,
};

const Func = struct {
    pc_range: ?PcRange,
    name: ?[]const u8,

    fn deinit(func: *Func, allocator: mem.Allocator) void {
        if (func.name) |name| {
            allocator.free(name);
        }
    }
};

const CompileUnit = struct {
    version: u16,
    is_64: bool,
    die: *Die,
    pc_range: ?PcRange,

    str_offsets_base: usize,
    addr_base: usize,
    rnglists_base: usize,
    loclists_base: usize,
};

const AbbrevTable = std.ArrayList(AbbrevTableEntry);

const AbbrevTableHeader = struct {
    // offset from .debug_abbrev
    offset: u64,
    table: AbbrevTable,

    fn deinit(header: *AbbrevTableHeader) void {
        for (header.table.items) |*entry| {
            entry.deinit();
        }
        header.table.deinit();
    }
};

const AbbrevTableEntry = struct {
    has_children: bool,
    abbrev_code: u64,
    tag_id: u64,
    attrs: std.ArrayList(AbbrevAttr),

    fn deinit(entry: *AbbrevTableEntry) void {
        entry.attrs.deinit();
    }
};

const AbbrevAttr = struct {
    attr_id: u64,
    form_id: u64,
    /// Only valid if form_id is .implicit_const
    payload: i64,
};

const FormValue = union(enum) {
    Address: u64,
    AddrOffset: usize,
    Block: []u8,
    Const: Constant,
    ExprLoc: []u8,
    Flag: bool,
    SecOffset: u64,
    Ref: u64,
    RefAddr: u64,
    String: []const u8,
    StrPtr: u64,
    StrOffset: usize,
    LineStrPtr: u64,
    LocListOffset: u64,
    RangeListOffset: u64,
    data16: [16]u8,

    fn getString(fv: FormValue, di: DwarfInfo) ![]const u8 {
        switch (fv) {
            .String => |s| return s,
            .StrPtr => |off| return di.getString(off),
            .LineStrPtr => |off| return di.getLineString(off),
            else => return badDwarf(),
        }
    }

    fn getUInt(fv: FormValue, comptime U: type) !U {
        switch (fv) {
            .Const => |c| {
                const int = try c.asUnsignedLe();
                return math.cast(U, int) orelse return badDwarf();
            },
            .SecOffset => |x| return math.cast(U, x) orelse return badDwarf(),
            else => return badDwarf(),
        }
    }

    fn getData16(fv: FormValue) ![16]u8 {
        switch (fv) {
            .data16 => |d| return d,
            else => return badDwarf(),
        }
    }
};

const Constant = struct {
    payload: u64,
    signed: bool,

    fn asUnsignedLe(self: Constant) !u64 {
        if (self.signed) return badDwarf();
        return self.payload;
    }
};

const Die = struct {
    // Arena for Die's Attr's and FormValue's.
    arena: std.heap.ArenaAllocator,
    tag_id: u64,
    has_children: bool,
    attrs: std.ArrayListUnmanaged(Attr) = .{},

    const Attr = struct {
        id: u64,
        value: FormValue,
    };

    fn deinit(self: *Die, allocator: mem.Allocator) void {
        self.arena.deinit();
        self.attrs.deinit(allocator);
    }

    fn getAttr(self: *const Die, id: u64) ?*const FormValue {
        for (self.attrs.items) |*attr| {
            if (attr.id == id) return &attr.value;
        }
        return null;
    }

    fn getAttrAddr(
        self: *const Die,
        di: *DwarfInfo,
        id: u64,
        compile_unit: CompileUnit,
    ) error{ InvalidDebugInfo, MissingDebugInfo }!u64 {
        const form_value = self.getAttr(id) orelse return error.MissingDebugInfo;
        return switch (form_value.*) {
            FormValue.Address => |value| value,
            FormValue.AddrOffset => |index| di.readDebugAddr(compile_unit, index),
            else => error.InvalidDebugInfo,
        };
    }

    fn getAttrSecOffset(self: *const Die, id: u64) !u64 {
        const form_value = self.getAttr(id) orelse return error.MissingDebugInfo;
        return form_value.getUInt(u64);
    }

    fn getAttrUnsignedLe(self: *const Die, id: u64) !u64 {
        const form_value = self.getAttr(id) orelse return error.MissingDebugInfo;
        return switch (form_value.*) {
            FormValue.Const => |value| value.asUnsignedLe(),
            else => error.InvalidDebugInfo,
        };
    }

    fn getAttrRef(self: *const Die, id: u64) !u64 {
        const form_value = self.getAttr(id) orelse return error.MissingDebugInfo;
        return switch (form_value.*) {
            FormValue.Ref => |value| value,
            else => error.InvalidDebugInfo,
        };
    }

    pub fn getAttrString(
        self: *const Die,
        di: *DwarfInfo,
        id: u64,
        opt_str: ?[]const u8,
        compile_unit: CompileUnit,
    ) error{ InvalidDebugInfo, MissingDebugInfo }![]const u8 {
        const form_value = self.getAttr(id) orelse return error.MissingDebugInfo;
        switch (form_value.*) {
            FormValue.String => |value| return value,
            FormValue.StrPtr => |offset| return di.getString(offset),
            FormValue.StrOffset => |index| {
                const debug_str_offsets = di.section(.debug_str_offsets) orelse return badDwarf();
                if (compile_unit.str_offsets_base == 0) return badDwarf();
                if (compile_unit.is_64) {
                    const byte_offset = compile_unit.str_offsets_base + 8 * index;
                    if (byte_offset + 8 > debug_str_offsets.len) return badDwarf();
                    const offset = mem.readInt(u64, debug_str_offsets[byte_offset..][0..8], di.endian);
                    return getStringGeneric(opt_str, offset);
                } else {
                    const byte_offset = compile_unit.str_offsets_base + 4 * index;
                    if (byte_offset + 4 > debug_str_offsets.len) return badDwarf();
                    const offset = mem.readInt(u32, debug_str_offsets[byte_offset..][0..4], di.endian);
                    return getStringGeneric(opt_str, offset);
                }
            },
            FormValue.LineStrPtr => |offset| return di.getLineString(offset),
            else => return badDwarf(),
        }
    }
};

const FileEntry = struct {
    path: []const u8,
    dir_index: u32 = 0,
    mtime: u64 = 0,
    size: u64 = 0,
    md5: [16]u8 = [1]u8{0} ** 16,
};

const LineNumberProgram = struct {
    address: u64,
    file: usize,
    line: i64,
    column: u64,
    version: u16,
    is_stmt: bool,
    basic_block: bool,
    end_sequence: bool,

    default_is_stmt: bool,
    target_address: u64,
    include_dirs: []const FileEntry,

    prev_valid: bool,
    prev_address: u64,
    prev_file: usize,
    prev_line: i64,
    prev_column: u64,
    prev_is_stmt: bool,
    prev_basic_block: bool,
    prev_end_sequence: bool,

    // Reset the state machine following the DWARF specification
    pub fn reset(self: *LineNumberProgram) void {
        self.address = 0;
        self.file = 1;
        self.line = 1;
        self.column = 0;
        self.is_stmt = self.default_is_stmt;
        self.basic_block = false;
        self.end_sequence = false;
        // Invalidate all the remaining fields
        self.prev_valid = false;
        self.prev_address = 0;
        self.prev_file = undefined;
        self.prev_line = undefined;
        self.prev_column = undefined;
        self.prev_is_stmt = undefined;
        self.prev_basic_block = undefined;
        self.prev_end_sequence = undefined;
    }

    pub fn init(
        is_stmt: bool,
        include_dirs: []const FileEntry,
        target_address: u64,
        version: u16,
    ) LineNumberProgram {
        return LineNumberProgram{
            .address = 0,
            .file = 1,
            .line = 1,
            .column = 0,
            .version = version,
            .is_stmt = is_stmt,
            .basic_block = false,
            .end_sequence = false,
            .include_dirs = include_dirs,
            .default_is_stmt = is_stmt,
            .target_address = target_address,
            .prev_valid = false,
            .prev_address = 0,
            .prev_file = undefined,
            .prev_line = undefined,
            .prev_column = undefined,
            .prev_is_stmt = undefined,
            .prev_basic_block = undefined,
            .prev_end_sequence = undefined,
        };
    }

    pub fn checkLineMatch(
        self: *LineNumberProgram,
        allocator: mem.Allocator,
        file_entries: []const FileEntry,
    ) !?debug.LineInfo {
        if (self.prev_valid and
            self.target_address >= self.prev_address and
            self.target_address < self.address)
        {
            const file_index = if (self.version >= 5) self.prev_file else i: {
                if (self.prev_file == 0) return missingDwarf();
                break :i self.prev_file - 1;
            };

            if (file_index >= file_entries.len) return badDwarf();
            const file_entry = &file_entries[file_index];

            if (file_entry.dir_index >= self.include_dirs.len) return badDwarf();
            const dir_name = self.include_dirs[file_entry.dir_index].path;

            const file_name = try fs.path.join(allocator, &[_][]const u8{
                dir_name, file_entry.path,
            });

            return debug.LineInfo{
                .line = if (self.prev_line >= 0) @as(u64, @intCast(self.prev_line)) else 0,
                .column = self.prev_column,
                .file_name = file_name,
            };
        }

        self.prev_valid = true;
        self.prev_address = self.address;
        self.prev_file = self.file;
        self.prev_line = self.line;
        self.prev_column = self.column;
        self.prev_is_stmt = self.is_stmt;
        self.prev_basic_block = self.basic_block;
        self.prev_end_sequence = self.end_sequence;
        return null;
    }
};

fn readUnitLength(in_stream: anytype, endian: std.builtin.Endian, is_64: *bool) !u64 {
    const first_32_bits = try in_stream.readInt(u32, endian);
    is_64.* = (first_32_bits == 0xffffffff);
    if (is_64.*) {
        return in_stream.readInt(u64, endian);
    } else {
        if (first_32_bits >= 0xfffffff0) return badDwarf();
        // TODO this cast should not be needed
        return @as(u64, first_32_bits);
    }
}

// TODO the nosuspends here are workarounds
fn readAllocBytes(allocator: mem.Allocator, in_stream: anytype, size: usize) ![]u8 {
    const buf = try allocator.alloc(u8, size);
    errdefer allocator.free(buf);
    if ((try nosuspend in_stream.read(buf)) < size) return error.EndOfFile;
    return buf;
}

// TODO the nosuspends here are workarounds
fn readAddress(in_stream: anytype, endian: std.builtin.Endian, is_64: bool) !u64 {
    return nosuspend if (is_64)
        try in_stream.readInt(u64, endian)
    else
        @as(u64, try in_stream.readInt(u32, endian));
}

fn parseFormValueBlockLen(allocator: mem.Allocator, in_stream: anytype, size: usize) !FormValue {
    const buf = try readAllocBytes(allocator, in_stream, size);
    return FormValue{ .Block = buf };
}

// TODO the nosuspends here are workarounds
fn parseFormValueBlock(allocator: mem.Allocator, in_stream: anytype, endian: std.builtin.Endian, size: usize) !FormValue {
    const block_len = try nosuspend in_stream.readVarInt(usize, endian, size);
    return parseFormValueBlockLen(allocator, in_stream, block_len);
}

fn parseFormValueConstant(in_stream: anytype, signed: bool, endian: std.builtin.Endian, comptime size: i32) !FormValue {
    // TODO: Please forgive me, I've worked around zig not properly spilling some intermediate values here.
    // `nosuspend` should be removed from all the function calls once it is fixed.
    return FormValue{
        .Const = Constant{
            .signed = signed,
            .payload = switch (size) {
                1 => try nosuspend in_stream.readInt(u8, endian),
                2 => try nosuspend in_stream.readInt(u16, endian),
                4 => try nosuspend in_stream.readInt(u32, endian),
                8 => try nosuspend in_stream.readInt(u64, endian),
                -1 => blk: {
                    if (signed) {
                        const x = try nosuspend leb.readILEB128(i64, in_stream);
                        break :blk @as(u64, @bitCast(x));
                    } else {
                        const x = try nosuspend leb.readULEB128(u64, in_stream);
                        break :blk x;
                    }
                },
                else => @compileError("Invalid size"),
            },
        },
    };
}

// TODO the nosuspends here are workarounds
fn parseFormValueRef(in_stream: anytype, endian: std.builtin.Endian, size: i32) !FormValue {
    return FormValue{
        .Ref = switch (size) {
            1 => try nosuspend in_stream.readInt(u8, endian),
            2 => try nosuspend in_stream.readInt(u16, endian),
            4 => try nosuspend in_stream.readInt(u32, endian),
            8 => try nosuspend in_stream.readInt(u64, endian),
            -1 => try nosuspend leb.readULEB128(u64, in_stream),
            else => unreachable,
        },
    };
}

// TODO the nosuspends here are workarounds
fn parseFormValue(allocator: mem.Allocator, in_stream: anytype, form_id: u64, endian: std.builtin.Endian, is_64: bool) anyerror!FormValue {
    return switch (form_id) {
        FORM.addr => FormValue{ .Address = try readAddress(in_stream, endian, @sizeOf(usize) == 8) },
        FORM.addrx1 => return FormValue{ .AddrOffset = try in_stream.readInt(u8, endian) },
        FORM.addrx2 => return FormValue{ .AddrOffset = try in_stream.readInt(u16, endian) },
        FORM.addrx3 => return FormValue{ .AddrOffset = try in_stream.readInt(u24, endian) },
        FORM.addrx4 => return FormValue{ .AddrOffset = try in_stream.readInt(u32, endian) },
        FORM.addrx => return FormValue{ .AddrOffset = try nosuspend leb.readULEB128(usize, in_stream) },

        FORM.block1 => parseFormValueBlock(allocator, in_stream, endian, 1),
        FORM.block2 => parseFormValueBlock(allocator, in_stream, endian, 2),
        FORM.block4 => parseFormValueBlock(allocator, in_stream, endian, 4),
        FORM.block => {
            const block_len = try nosuspend leb.readULEB128(usize, in_stream);
            return parseFormValueBlockLen(allocator, in_stream, block_len);
        },
        FORM.data1 => parseFormValueConstant(in_stream, false, endian, 1),
        FORM.data2 => parseFormValueConstant(in_stream, false, endian, 2),
        FORM.data4 => parseFormValueConstant(in_stream, false, endian, 4),
        FORM.data8 => parseFormValueConstant(in_stream, false, endian, 8),
        FORM.data16 => {
            var buf: [16]u8 = undefined;
            if ((try nosuspend in_stream.readAll(&buf)) < 16) return error.EndOfFile;
            return FormValue{ .data16 = buf };
        },
        FORM.udata, FORM.sdata => {
            const signed = form_id == FORM.sdata;
            return parseFormValueConstant(in_stream, signed, endian, -1);
        },
        FORM.exprloc => {
            const size = try nosuspend leb.readULEB128(usize, in_stream);
            const buf = try readAllocBytes(allocator, in_stream, size);
            return FormValue{ .ExprLoc = buf };
        },
        FORM.flag => FormValue{ .Flag = (try nosuspend in_stream.readByte()) != 0 },
        FORM.flag_present => FormValue{ .Flag = true },
        FORM.sec_offset => FormValue{ .SecOffset = try readAddress(in_stream, endian, is_64) },

        FORM.ref1 => parseFormValueRef(in_stream, endian, 1),
        FORM.ref2 => parseFormValueRef(in_stream, endian, 2),
        FORM.ref4 => parseFormValueRef(in_stream, endian, 4),
        FORM.ref8 => parseFormValueRef(in_stream, endian, 8),
        FORM.ref_udata => parseFormValueRef(in_stream, endian, -1),

        FORM.ref_addr => FormValue{ .RefAddr = try readAddress(in_stream, endian, is_64) },
        FORM.ref_sig8 => FormValue{ .Ref = try nosuspend in_stream.readInt(u64, endian) },

        FORM.string => FormValue{ .String = try in_stream.readUntilDelimiterAlloc(allocator, 0, math.maxInt(usize)) },
        FORM.strp => FormValue{ .StrPtr = try readAddress(in_stream, endian, is_64) },
        FORM.strx1 => return FormValue{ .StrOffset = try in_stream.readInt(u8, endian) },
        FORM.strx2 => return FormValue{ .StrOffset = try in_stream.readInt(u16, endian) },
        FORM.strx3 => return FormValue{ .StrOffset = try in_stream.readInt(u24, endian) },
        FORM.strx4 => return FormValue{ .StrOffset = try in_stream.readInt(u32, endian) },
        FORM.strx => return FormValue{ .StrOffset = try nosuspend leb.readULEB128(usize, in_stream) },
        FORM.line_strp => FormValue{ .LineStrPtr = try readAddress(in_stream, endian, is_64) },
        FORM.indirect => {
            const child_form_id = try nosuspend leb.readULEB128(u64, in_stream);
            if (true) {
                return parseFormValue(allocator, in_stream, child_form_id, endian, is_64);
            }
            const F = @TypeOf(async parseFormValue(allocator, in_stream, child_form_id, endian, is_64));
            var frame = try allocator.create(F);
            defer allocator.destroy(frame);
            return await @asyncCall(frame, {}, parseFormValue, .{ allocator, in_stream, child_form_id, endian, is_64 });
        },
        FORM.implicit_const => FormValue{ .Const = Constant{ .signed = true, .payload = undefined } },
        FORM.loclistx => return FormValue{ .LocListOffset = try nosuspend leb.readULEB128(u64, in_stream) },
        FORM.rnglistx => return FormValue{ .RangeListOffset = try nosuspend leb.readULEB128(u64, in_stream) },
        else => {
            //std.debug.print("unrecognized form id: {x}\n", .{form_id});
            return badDwarf();
        },
    };
}

fn getAbbrevTableEntry(abbrev_table: *const AbbrevTable, abbrev_code: u64) ?*const AbbrevTableEntry {
    for (abbrev_table.items) |*table_entry| {
        if (table_entry.abbrev_code == abbrev_code) return table_entry;
    }
    return null;
}

pub const DwarfSection = enum {
    debug_info,
    debug_abbrev,
    debug_str,
    debug_str_offsets,
    debug_line,
    debug_line_str,
    debug_ranges,
    debug_loclists,
    debug_rnglists,
    debug_addr,
    debug_names,
    debug_frame,
    eh_frame,
    eh_frame_hdr,
};

pub const DwarfInfo = struct {
    pub const Section = struct {
        data: []const u8,
        owned: bool,
    };

    const num_sections = std.enums.directEnumArrayLen(DwarfSection, 0);
    pub const SectionArray = [num_sections]?Section;
    pub const null_section_array = [_]?Section{null} ** num_sections;

    endian: std.builtin.Endian,
    sections: SectionArray,

    // Filled later by the initializer
    abbrev_table_list: std.ArrayListUnmanaged(AbbrevTableHeader) = .{},
    compile_unit_list: std.ArrayListUnmanaged(CompileUnit) = .{},
    func_list: std.ArrayListUnmanaged(Func) = .{},

    cie_map: std.AutoArrayHashMapUnmanaged(u64, CommonInformationEntry) = .{},
    // Sorted by start_pc
    fde_list: std.ArrayListUnmanaged(FrameDescriptionEntry) = .{},

    is_macho: bool,

    pub fn section(di: DwarfInfo, dwarf_section: DwarfSection) ?[]const u8 {
        return if (di.sections[@enumToInt(dwarf_section)]) |s| s.data else null;
    }

    pub fn deinit(di: *DwarfInfo, allocator: mem.Allocator) void {
        for (di.sections) |opt_section| {
            if (opt_section) |s| if (s.owned) allocator.free(s.data);
        }
        for (di.abbrev_table_list.items) |*abbrev| {
            abbrev.deinit();
        }
        di.abbrev_table_list.deinit(allocator);
        for (di.compile_unit_list.items) |*cu| {
            cu.die.deinit(allocator);
            allocator.destroy(cu.die);
        }
        di.compile_unit_list.deinit(allocator);
        for (di.func_list.items) |*func| {
            func.deinit(allocator);
        }
        di.func_list.deinit(allocator);
        di.cie_map.deinit(allocator);
        di.fde_list.deinit(allocator);
    }

    pub fn getSymbolName(di: *DwarfInfo, address: u64) ?[]const u8 {
        // TODO: Can this be binary searched?
        for (di.func_list.items) |*func| {
            if (func.pc_range) |range| {
                if (address >= range.start and address < range.end) {
                    return func.name;
                }
            }
        }

        return null;
    }

    fn scanAllFunctions(di: *DwarfInfo, allocator: mem.Allocator) !void {
        var stream = io.fixedBufferStream(di.section(.debug_info).?);
        const in = stream.reader();
        const seekable = &stream.seekableStream();
        var this_unit_offset: u64 = 0;

        var tmp_arena = std.heap.ArenaAllocator.init(allocator);
        defer tmp_arena.deinit();
        const arena = tmp_arena.allocator();

        while (this_unit_offset < try seekable.getEndPos()) {
            try seekable.seekTo(this_unit_offset);

            var is_64: bool = undefined;
            const unit_length = try readUnitLength(in, di.endian, &is_64);
            if (unit_length == 0) return;
            const next_offset = unit_length + (if (is_64) @as(usize, 12) else @as(usize, 4));

            const version = try in.readInt(u16, di.endian);
            if (version < 2 or version > 5) return badDwarf();

            var address_size: u8 = undefined;
            var debug_abbrev_offset: u64 = undefined;
            if (version >= 5) {
                const unit_type = try in.readInt(u8, di.endian);
                if (unit_type != UT.compile) return badDwarf();
                address_size = try in.readByte();
                debug_abbrev_offset = if (is_64)
                    try in.readInt(u64, di.endian)
                else
                    try in.readInt(u32, di.endian);
            } else {
                debug_abbrev_offset = if (is_64)
                    try in.readInt(u64, di.endian)
                else
                    try in.readInt(u32, di.endian);
                address_size = try in.readByte();
            }
            if (address_size != @sizeOf(usize)) return badDwarf();

            const compile_unit_pos = try seekable.getPos();
            const abbrev_table = try di.getAbbrevTable(allocator, debug_abbrev_offset);

            try seekable.seekTo(compile_unit_pos);

            const next_unit_pos = this_unit_offset + next_offset;

            var compile_unit: CompileUnit = undefined;

            while ((try seekable.getPos()) < next_unit_pos) {
                var die_obj = (try di.parseDie(arena, in, abbrev_table, is_64)) orelse continue;
                const after_die_offset = try seekable.getPos();

                switch (die_obj.tag_id) {
                    TAG.compile_unit => {
                        compile_unit = .{
                            .version = version,
                            .is_64 = is_64,
                            .die = &die_obj,
                            .pc_range = null,

                            .str_offsets_base = if (die_obj.getAttr(AT.str_offsets_base)) |fv| try fv.getUInt(usize) else 0,
                            .addr_base = if (die_obj.getAttr(AT.addr_base)) |fv| try fv.getUInt(usize) else 0,
                            .rnglists_base = if (die_obj.getAttr(AT.rnglists_base)) |fv| try fv.getUInt(usize) else 0,
                            .loclists_base = if (die_obj.getAttr(AT.loclists_base)) |fv| try fv.getUInt(usize) else 0,
                        };
                    },
                    TAG.subprogram, TAG.inlined_subroutine, TAG.subroutine, TAG.entry_point => {
                        const fn_name = x: {
                            var depth: i32 = 3;
                            var this_die_obj = die_obj;
                            // Prevent endless loops
                            while (depth > 0) : (depth -= 1) {
                                if (this_die_obj.getAttr(AT.name)) |_| {
                                    const name = try this_die_obj.getAttrString(di, AT.name, di.section(.debug_str), compile_unit);
                                    break :x try allocator.dupe(u8, name);
                                } else if (this_die_obj.getAttr(AT.abstract_origin)) |_| {
                                    // Follow the DIE it points to and repeat
                                    const ref_offset = try this_die_obj.getAttrRef(AT.abstract_origin);
                                    if (ref_offset > next_offset) return badDwarf();
                                    try seekable.seekTo(this_unit_offset + ref_offset);
                                    this_die_obj = (try di.parseDie(
                                        arena,
                                        in,
                                        abbrev_table,
                                        is_64,
                                    )) orelse return badDwarf();
                                } else if (this_die_obj.getAttr(AT.specification)) |_| {
                                    // Follow the DIE it points to and repeat
                                    const ref_offset = try this_die_obj.getAttrRef(AT.specification);
                                    if (ref_offset > next_offset) return badDwarf();
                                    try seekable.seekTo(this_unit_offset + ref_offset);
                                    this_die_obj = (try di.parseDie(
                                        arena,
                                        in,
                                        abbrev_table,
                                        is_64,
                                    )) orelse return badDwarf();
                                } else {
                                    break :x null;
                                }
                            }

                            break :x null;
                        };

                        const pc_range = x: {
                            if (die_obj.getAttrAddr(di, AT.low_pc, compile_unit)) |low_pc| {
                                if (die_obj.getAttr(AT.high_pc)) |high_pc_value| {
                                    const pc_end = switch (high_pc_value.*) {
                                        FormValue.Address => |value| value,
                                        FormValue.Const => |value| b: {
                                            const offset = try value.asUnsignedLe();
                                            break :b (low_pc + offset);
                                        },
                                        else => return badDwarf(),
                                    };
                                    break :x PcRange{
                                        .start = low_pc,
                                        .end = pc_end,
                                    };
                                } else {
                                    break :x null;
                                }
                            } else |err| {
                                if (err != error.MissingDebugInfo) return err;
                                break :x null;
                            }
                        };

                        // TODO: Debug issue where `puts` in Ubuntu's libc was not found
                        //if (fn_name != null and pc_range != null) debug.print("func_list: {s} -> 0x{x}-0x{x}\n", .{fn_name.?, pc_range.?.start, pc_range.?.end});

                        try di.func_list.append(allocator, Func{
                            .name = fn_name,
                            .pc_range = pc_range,
                        });
                    },
                    else => {},
                }

                try seekable.seekTo(after_die_offset);
            }

            this_unit_offset += next_offset;
        }
    }

    fn scanAllCompileUnits(di: *DwarfInfo, allocator: mem.Allocator) !void {
        var stream = io.fixedBufferStream(di.section(.debug_info).?);
        const in = &stream.reader();
        const seekable = &stream.seekableStream();
        var this_unit_offset: u64 = 0;

        while (this_unit_offset < try seekable.getEndPos()) {
            try seekable.seekTo(this_unit_offset);

            var is_64: bool = undefined;
            const unit_length = try readUnitLength(in, di.endian, &is_64);
            if (unit_length == 0) return;
            const next_offset = unit_length + (if (is_64) @as(usize, 12) else @as(usize, 4));

            const version = try in.readInt(u16, di.endian);
            if (version < 2 or version > 5) return badDwarf();

            var address_size: u8 = undefined;
            var debug_abbrev_offset: u64 = undefined;
            if (version >= 5) {
                const unit_type = try in.readInt(u8, di.endian);
                if (unit_type != UT.compile) return badDwarf();
                address_size = try in.readByte();
                debug_abbrev_offset = if (is_64)
                    try in.readInt(u64, di.endian)
                else
                    try in.readInt(u32, di.endian);
            } else {
                debug_abbrev_offset = if (is_64)
                    try in.readInt(u64, di.endian)
                else
                    try in.readInt(u32, di.endian);
                address_size = try in.readByte();
            }
            if (address_size != @sizeOf(usize)) return badDwarf();

            const compile_unit_pos = try seekable.getPos();
            const abbrev_table = try di.getAbbrevTable(allocator, debug_abbrev_offset);

            try seekable.seekTo(compile_unit_pos);

            const compile_unit_die = try allocator.create(Die);
            errdefer allocator.destroy(compile_unit_die);
            compile_unit_die.* = (try di.parseDie(allocator, in, abbrev_table, is_64)) orelse
                return badDwarf();

            if (compile_unit_die.tag_id != TAG.compile_unit) return badDwarf();

            var compile_unit: CompileUnit = .{
                .version = version,
                .is_64 = is_64,
                .pc_range = null,
                .die = compile_unit_die,
                .str_offsets_base = if (compile_unit_die.getAttr(AT.str_offsets_base)) |fv| try fv.getUInt(usize) else 0,
                .addr_base = if (compile_unit_die.getAttr(AT.addr_base)) |fv| try fv.getUInt(usize) else 0,
                .rnglists_base = if (compile_unit_die.getAttr(AT.rnglists_base)) |fv| try fv.getUInt(usize) else 0,
                .loclists_base = if (compile_unit_die.getAttr(AT.loclists_base)) |fv| try fv.getUInt(usize) else 0,
            };

            compile_unit.pc_range = x: {
                if (compile_unit_die.getAttrAddr(di, AT.low_pc, compile_unit)) |low_pc| {
                    if (compile_unit_die.getAttr(AT.high_pc)) |high_pc_value| {
                        const pc_end = switch (high_pc_value.*) {
                            FormValue.Address => |value| value,
                            FormValue.Const => |value| b: {
                                const offset = try value.asUnsignedLe();
                                break :b (low_pc + offset);
                            },
                            else => return badDwarf(),
                        };
                        break :x PcRange{
                            .start = low_pc,
                            .end = pc_end,
                        };
                    } else {
                        break :x null;
                    }
                } else |err| {
                    if (err != error.MissingDebugInfo) return err;
                    break :x null;
                }
            };

            try di.compile_unit_list.append(allocator, compile_unit);

            this_unit_offset += next_offset;
        }
    }

    pub fn findCompileUnit(di: *DwarfInfo, target_address: u64) !*const CompileUnit {
        for (di.compile_unit_list.items) |*compile_unit| {
            if (compile_unit.pc_range) |range| {
                if (target_address >= range.start and target_address < range.end) return compile_unit;
            }

            const opt_debug_ranges = if (compile_unit.version >= 5) di.section(.debug_rnglists) else di.section(.debug_ranges);
            const debug_ranges = opt_debug_ranges orelse continue;

            const ranges_val = compile_unit.die.getAttr(AT.ranges) orelse continue;
            const ranges_offset = switch (ranges_val.*) {
                .SecOffset => |off| off,
                .Const => |c| try c.asUnsignedLe(),
                .RangeListOffset => |idx| off: {
                    if (compile_unit.is_64) {
                        const offset_loc = @as(usize, @intCast(compile_unit.rnglists_base + 8 * idx));
                        if (offset_loc + 8 > debug_ranges.len) return badDwarf();
                        const offset = mem.readInt(u64, debug_ranges[offset_loc..][0..8], di.endian);
                        break :off compile_unit.rnglists_base + offset;
                    } else {
                        const offset_loc = @as(usize, @intCast(compile_unit.rnglists_base + 4 * idx));
                        if (offset_loc + 4 > debug_ranges.len) return badDwarf();
                        const offset = mem.readInt(u32, debug_ranges[offset_loc..][0..4], di.endian);
                        break :off compile_unit.rnglists_base + offset;
                    }
                },
                else => return badDwarf(),
            };

            var stream = io.fixedBufferStream(debug_ranges);
            const in = &stream.reader();
            const seekable = &stream.seekableStream();

            // All the addresses in the list are relative to the value
            // specified by DW_AT.low_pc or to some other value encoded
            // in the list itself.
            // If no starting value is specified use zero.
            var base_address = compile_unit.die.getAttrAddr(di, AT.low_pc, compile_unit.*) catch |err| switch (err) {
                error.MissingDebugInfo => @as(u64, 0), // TODO https://github.com/ziglang/zig/issues/11135
                else => return err,
            };

            try seekable.seekTo(ranges_offset);

            if (compile_unit.version >= 5) {
                while (true) {
                    const kind = try in.readByte();
                    switch (kind) {
                        RLE.end_of_list => break,
                        RLE.base_addressx => {
                            const index = try leb.readULEB128(usize, in);
                            base_address = try di.readDebugAddr(compile_unit.*, index);
                        },
                        RLE.startx_endx => {
                            const start_index = try leb.readULEB128(usize, in);
                            const start_addr = try di.readDebugAddr(compile_unit.*, start_index);

                            const end_index = try leb.readULEB128(usize, in);
                            const end_addr = try di.readDebugAddr(compile_unit.*, end_index);

                            if (target_address >= start_addr and target_address < end_addr) {
                                return compile_unit;
                            }
                        },
                        RLE.startx_length => {
                            const start_index = try leb.readULEB128(usize, in);
                            const start_addr = try di.readDebugAddr(compile_unit.*, start_index);

                            const len = try leb.readULEB128(usize, in);
                            const end_addr = start_addr + len;

                            if (target_address >= start_addr and target_address < end_addr) {
                                return compile_unit;
                            }
                        },
                        RLE.offset_pair => {
                            const start_addr = try leb.readULEB128(usize, in);
                            const end_addr = try leb.readULEB128(usize, in);
                            // This is the only kind that uses the base address
                            if (target_address >= base_address + start_addr and target_address < base_address + end_addr) {
                                return compile_unit;
                            }
                        },
                        RLE.base_address => {
                            base_address = try in.readInt(usize, di.endian);
                        },
                        RLE.start_end => {
                            const start_addr = try in.readInt(usize, di.endian);
                            const end_addr = try in.readInt(usize, di.endian);
                            if (target_address >= start_addr and target_address < end_addr) {
                                return compile_unit;
                            }
                        },
                        RLE.start_length => {
                            const start_addr = try in.readInt(usize, di.endian);
                            const len = try leb.readULEB128(usize, in);
                            const end_addr = start_addr + len;
                            if (target_address >= start_addr and target_address < end_addr) {
                                return compile_unit;
                            }
                        },
                        else => return badDwarf(),
                    }
                }
            } else {
                while (true) {
                    const begin_addr = try in.readInt(usize, di.endian);
                    const end_addr = try in.readInt(usize, di.endian);
                    if (begin_addr == 0 and end_addr == 0) {
                        break;
                    }
                    // This entry selects a new value for the base address
                    if (begin_addr == math.maxInt(usize)) {
                        base_address = end_addr;
                        continue;
                    }
                    if (target_address >= base_address + begin_addr and target_address < base_address + end_addr) {
                        return compile_unit;
                    }
                }
            }
        }
        return missingDwarf();
    }

    /// Gets an already existing AbbrevTable given the abbrev_offset, or if not found,
    /// seeks in the stream and parses it.
    fn getAbbrevTable(di: *DwarfInfo, allocator: mem.Allocator, abbrev_offset: u64) !*const AbbrevTable {
        for (di.abbrev_table_list.items) |*header| {
            if (header.offset == abbrev_offset) {
                return &header.table;
            }
        }
        try di.abbrev_table_list.append(allocator, AbbrevTableHeader{
            .offset = abbrev_offset,
            .table = try di.parseAbbrevTable(allocator, abbrev_offset),
        });
        return &di.abbrev_table_list.items[di.abbrev_table_list.items.len - 1].table;
    }

    fn parseAbbrevTable(di: *DwarfInfo, allocator: mem.Allocator, offset: u64) !AbbrevTable {
        var stream = io.fixedBufferStream(di.section(.debug_abbrev).?);
        const in = &stream.reader();
        const seekable = &stream.seekableStream();

        try seekable.seekTo(offset);
        var result = AbbrevTable.init(allocator);
        errdefer {
            for (result.items) |*entry| {
                entry.attrs.deinit();
            }
            result.deinit();
        }

        while (true) {
            const abbrev_code = try leb.readULEB128(u64, in);
            if (abbrev_code == 0) return result;
            try result.append(AbbrevTableEntry{
                .abbrev_code = abbrev_code,
                .tag_id = try leb.readULEB128(u64, in),
                .has_children = (try in.readByte()) == CHILDREN.yes,
                .attrs = std.ArrayList(AbbrevAttr).init(allocator),
            });
            const attrs = &result.items[result.items.len - 1].attrs;

            while (true) {
                const attr_id = try leb.readULEB128(u64, in);
                const form_id = try leb.readULEB128(u64, in);
                if (attr_id == 0 and form_id == 0) break;
                // DW_FORM_implicit_const stores its value immediately after the attribute pair :(
                const payload = if (form_id == FORM.implicit_const) try leb.readILEB128(i64, in) else undefined;
                try attrs.append(AbbrevAttr{
                    .attr_id = attr_id,
                    .form_id = form_id,
                    .payload = payload,
                });
            }
        }
    }

    fn parseDie(
        di: *DwarfInfo,
        allocator: mem.Allocator,
        in_stream: anytype,
        abbrev_table: *const AbbrevTable,
        is_64: bool,
    ) !?Die {
        const abbrev_code = try leb.readULEB128(u64, in_stream);
        if (abbrev_code == 0) return null;
        const table_entry = getAbbrevTableEntry(abbrev_table, abbrev_code) orelse return badDwarf();

        var result = Die{
            // Lives as long as the Die.
            .arena = std.heap.ArenaAllocator.init(allocator),
            .tag_id = table_entry.tag_id,
            .has_children = table_entry.has_children,
        };
        try result.attrs.resize(allocator, table_entry.attrs.items.len);
        for (table_entry.attrs.items, 0..) |attr, i| {
            result.attrs.items[i] = Die.Attr{
                .id = attr.attr_id,
                .value = try parseFormValue(
                    result.arena.allocator(),
                    in_stream,
                    attr.form_id,
                    di.endian,
                    is_64,
                ),
            };
            if (attr.form_id == FORM.implicit_const) {
                result.attrs.items[i].value.Const.payload = @as(u64, @bitCast(attr.payload));
            }
        }
        return result;
    }

    pub fn getLineNumberInfo(
        di: *DwarfInfo,
        allocator: mem.Allocator,
        compile_unit: CompileUnit,
        target_address: u64,
    ) !debug.LineInfo {
        var stream = io.fixedBufferStream(di.section(.debug_line).?);
        const in = &stream.reader();
        const seekable = &stream.seekableStream();

        const compile_unit_cwd = try compile_unit.die.getAttrString(di, AT.comp_dir, di.section(.debug_line_str), compile_unit);
        const line_info_offset = try compile_unit.die.getAttrSecOffset(AT.stmt_list);

        try seekable.seekTo(line_info_offset);

        var is_64: bool = undefined;
        const unit_length = try readUnitLength(in, di.endian, &is_64);
        if (unit_length == 0) {
            return missingDwarf();
        }
        const next_offset = unit_length + (if (is_64) @as(usize, 12) else @as(usize, 4));

        const version = try in.readInt(u16, di.endian);
        if (version < 2) return badDwarf();

        var addr_size: u8 = if (is_64) 8 else 4;
        var seg_size: u8 = 0;
        if (version >= 5) {
            addr_size = try in.readByte();
            seg_size = try in.readByte();
        }

        const prologue_length = if (is_64) try in.readInt(u64, di.endian) else try in.readInt(u32, di.endian);
        const prog_start_offset = (try seekable.getPos()) + prologue_length;

        const minimum_instruction_length = try in.readByte();
        if (minimum_instruction_length == 0) return badDwarf();

        if (version >= 4) {
            // maximum_operations_per_instruction
            _ = try in.readByte();
        }

        const default_is_stmt = (try in.readByte()) != 0;
        const line_base = try in.readByteSigned();

        const line_range = try in.readByte();
        if (line_range == 0) return badDwarf();

        const opcode_base = try in.readByte();

        const standard_opcode_lengths = try allocator.alloc(u8, opcode_base - 1);
        defer allocator.free(standard_opcode_lengths);

        {
            var i: usize = 0;
            while (i < opcode_base - 1) : (i += 1) {
                standard_opcode_lengths[i] = try in.readByte();
            }
        }

        var tmp_arena = std.heap.ArenaAllocator.init(allocator);
        defer tmp_arena.deinit();
        const arena = tmp_arena.allocator();

        var include_directories = std.ArrayList(FileEntry).init(arena);
        var file_entries = std.ArrayList(FileEntry).init(arena);

        if (version < 5) {
            try include_directories.append(.{ .path = compile_unit_cwd });

            while (true) {
                const dir = try in.readUntilDelimiterAlloc(arena, 0, math.maxInt(usize));
                if (dir.len == 0) break;
                try include_directories.append(.{ .path = dir });
            }

            while (true) {
                const file_name = try in.readUntilDelimiterAlloc(arena, 0, math.maxInt(usize));
                if (file_name.len == 0) break;
                const dir_index = try leb.readULEB128(u32, in);
                const mtime = try leb.readULEB128(u64, in);
                const size = try leb.readULEB128(u64, in);
                try file_entries.append(FileEntry{
                    .path = file_name,
                    .dir_index = dir_index,
                    .mtime = mtime,
                    .size = size,
                });
            }
        } else {
            const FileEntFmt = struct {
                content_type_code: u8,
                form_code: u16,
            };
            {
                var dir_ent_fmt_buf: [10]FileEntFmt = undefined;
                const directory_entry_format_count = try in.readByte();
                if (directory_entry_format_count > dir_ent_fmt_buf.len) return badDwarf();
                for (dir_ent_fmt_buf[0..directory_entry_format_count]) |*ent_fmt| {
                    ent_fmt.* = .{
                        .content_type_code = try leb.readULEB128(u8, in),
                        .form_code = try leb.readULEB128(u16, in),
                    };
                }

                const directories_count = try leb.readULEB128(usize, in);
                try include_directories.ensureUnusedCapacity(directories_count);
                {
                    var i: usize = 0;
                    while (i < directories_count) : (i += 1) {
                        var e: FileEntry = .{ .path = &.{} };
                        for (dir_ent_fmt_buf[0..directory_entry_format_count]) |ent_fmt| {
                            const form_value = try parseFormValue(
                                arena,
                                in,
                                ent_fmt.form_code,
                                di.endian,
                                is_64,
                            );
                            switch (ent_fmt.content_type_code) {
                                LNCT.path => e.path = try form_value.getString(di.*),
                                LNCT.directory_index => e.dir_index = try form_value.getUInt(u32),
                                LNCT.timestamp => e.mtime = try form_value.getUInt(u64),
                                LNCT.size => e.size = try form_value.getUInt(u64),
                                LNCT.MD5 => e.md5 = try form_value.getData16(),
                                else => continue,
                            }
                        }
                        include_directories.appendAssumeCapacity(e);
                    }
                }
            }

            var file_ent_fmt_buf: [10]FileEntFmt = undefined;
            const file_name_entry_format_count = try in.readByte();
            if (file_name_entry_format_count > file_ent_fmt_buf.len) return badDwarf();
            for (file_ent_fmt_buf[0..file_name_entry_format_count]) |*ent_fmt| {
                ent_fmt.* = .{
                    .content_type_code = try leb.readULEB128(u8, in),
                    .form_code = try leb.readULEB128(u16, in),
                };
            }

            const file_names_count = try leb.readULEB128(usize, in);
            try file_entries.ensureUnusedCapacity(file_names_count);
            {
                var i: usize = 0;
                while (i < file_names_count) : (i += 1) {
                    var e: FileEntry = .{ .path = &.{} };
                    for (file_ent_fmt_buf[0..file_name_entry_format_count]) |ent_fmt| {
                        const form_value = try parseFormValue(
                            arena,
                            in,
                            ent_fmt.form_code,
                            di.endian,
                            is_64,
                        );
                        switch (ent_fmt.content_type_code) {
                            LNCT.path => e.path = try form_value.getString(di.*),
                            LNCT.directory_index => e.dir_index = try form_value.getUInt(u32),
                            LNCT.timestamp => e.mtime = try form_value.getUInt(u64),
                            LNCT.size => e.size = try form_value.getUInt(u64),
                            LNCT.MD5 => e.md5 = try form_value.getData16(),
                            else => continue,
                        }
                    }
                    file_entries.appendAssumeCapacity(e);
                }
            }
        }

        var prog = LineNumberProgram.init(
            default_is_stmt,
            include_directories.items,
            target_address,
            version,
        );

        try seekable.seekTo(prog_start_offset);

        const next_unit_pos = line_info_offset + next_offset;

        while ((try seekable.getPos()) < next_unit_pos) {
            const opcode = try in.readByte();

            if (opcode == LNS.extended_op) {
                const op_size = try leb.readULEB128(u64, in);
                if (op_size < 1) return badDwarf();
                var sub_op = try in.readByte();
                switch (sub_op) {
                    LNE.end_sequence => {
                        prog.end_sequence = true;
                        if (try prog.checkLineMatch(allocator, file_entries.items)) |info| return info;
                        prog.reset();
                    },
                    LNE.set_address => {
                        const addr = try in.readInt(usize, di.endian);
                        prog.address = addr;
                    },
                    LNE.define_file => {
                        const path = try in.readUntilDelimiterAlloc(arena, 0, math.maxInt(usize));
                        const dir_index = try leb.readULEB128(u32, in);
                        const mtime = try leb.readULEB128(u64, in);
                        const size = try leb.readULEB128(u64, in);
                        try file_entries.append(FileEntry{
                            .path = path,
                            .dir_index = dir_index,
                            .mtime = mtime,
                            .size = size,
                        });
                    },
                    else => {
                        const fwd_amt = math.cast(isize, op_size - 1) orelse return badDwarf();
                        try seekable.seekBy(fwd_amt);
                    },
                }
            } else if (opcode >= opcode_base) {
                // special opcodes
                const adjusted_opcode = opcode - opcode_base;
                const inc_addr = minimum_instruction_length * (adjusted_opcode / line_range);
                const inc_line = @as(i32, line_base) + @as(i32, adjusted_opcode % line_range);
                prog.line += inc_line;
                prog.address += inc_addr;
                if (try prog.checkLineMatch(allocator, file_entries.items)) |info| return info;
                prog.basic_block = false;
            } else {
                switch (opcode) {
                    LNS.copy => {
                        if (try prog.checkLineMatch(allocator, file_entries.items)) |info| return info;
                        prog.basic_block = false;
                    },
                    LNS.advance_pc => {
                        const arg = try leb.readULEB128(usize, in);
                        prog.address += arg * minimum_instruction_length;
                    },
                    LNS.advance_line => {
                        const arg = try leb.readILEB128(i64, in);
                        prog.line += arg;
                    },
                    LNS.set_file => {
                        const arg = try leb.readULEB128(usize, in);
                        prog.file = arg;
                    },
                    LNS.set_column => {
                        const arg = try leb.readULEB128(u64, in);
                        prog.column = arg;
                    },
                    LNS.negate_stmt => {
                        prog.is_stmt = !prog.is_stmt;
                    },
                    LNS.set_basic_block => {
                        prog.basic_block = true;
                    },
                    LNS.const_add_pc => {
                        const inc_addr = minimum_instruction_length * ((255 - opcode_base) / line_range);
                        prog.address += inc_addr;
                    },
                    LNS.fixed_advance_pc => {
                        const arg = try in.readInt(u16, di.endian);
                        prog.address += arg;
                    },
                    LNS.set_prologue_end => {},
                    else => {
                        if (opcode - 1 >= standard_opcode_lengths.len) return badDwarf();
                        const len_bytes = standard_opcode_lengths[opcode - 1];
                        try seekable.seekBy(len_bytes);
                    },
                }
            }
        }

        return missingDwarf();
    }

    fn getString(di: DwarfInfo, offset: u64) ![]const u8 {
        return getStringGeneric(di.section(.debug_str), offset);
    }

    fn getLineString(di: DwarfInfo, offset: u64) ![]const u8 {
        return getStringGeneric(di.section(.debug_line_str), offset);
    }

    fn readDebugAddr(di: DwarfInfo, compile_unit: CompileUnit, index: u64) !u64 {
        const debug_addr = di.section(.debug_addr) orelse return badDwarf();

        // addr_base points to the first item after the header, however we
        // need to read the header to know the size of each item. Empirically,
        // it may disagree with is_64 on the compile unit.
        // The header is 8 or 12 bytes depending on is_64.
        if (compile_unit.addr_base < 8) return badDwarf();

        const version = mem.readInt(u16, debug_addr[compile_unit.addr_base - 4 ..][0..2], di.endian);
        if (version != 5) return badDwarf();

        const addr_size = debug_addr[compile_unit.addr_base - 2];
        const seg_size = debug_addr[compile_unit.addr_base - 1];

        const byte_offset = @as(usize, @intCast(compile_unit.addr_base + (addr_size + seg_size) * index));
        if (byte_offset + addr_size > debug_addr.len) return badDwarf();
        return switch (addr_size) {
            1 => debug_addr[byte_offset],
            2 => mem.readInt(u16, debug_addr[byte_offset..][0..2], di.endian),
            4 => mem.readInt(u32, debug_addr[byte_offset..][0..4], di.endian),
            8 => mem.readInt(u64, debug_addr[byte_offset..][0..8], di.endian),
            else => badDwarf(),
        };
    }

    pub fn scanAllUnwindInfo(di: *DwarfInfo, allocator: mem.Allocator, binary_mem: []const u8) !void {
        var has_eh_frame_hdr = false;
        if (di.section(.eh_frame_hdr)) |eh_frame_hdr| {
            has_eh_frame_hdr = true;

            // TODO: Parse this section to get the lookup table, and skip loading the entire section

            _ = eh_frame_hdr;
        }

        if (di.section(.eh_frame)) |eh_frame| {
            var stream = io.fixedBufferStream(eh_frame);
            const reader = stream.reader();

            while (stream.pos < stream.buffer.len) {
                const length_offset = stream.pos;
                var length: usize = try reader.readInt(u32, di.endian);
                if (length == 0) break;

                var is_64 = length == math.maxInt(u32);
                if (is_64) {
                    length = std.math.cast(usize, try reader.readInt(u64, di.endian)) orelse return error.LengthOverflow;
                }

                const id_len = @as(u8, if (is_64) 8 else 4);
                const id = if (is_64) try reader.readInt(u64, di.endian) else try reader.readInt(u32, di.endian);
                const entry_bytes = eh_frame[stream.pos..][0 .. length - id_len];

                if (id == 0) {
                    const cie = try CommonInformationEntry.parse(
                        entry_bytes,
                        @ptrToInt(eh_frame.ptr),
                        @ptrToInt(eh_frame.ptr) - @ptrToInt(binary_mem.ptr),
                        true,
                        length_offset,
                        @sizeOf(usize),
                        di.endian,
                    );
                    try di.cie_map.put(allocator, length_offset, cie);
                } else {
                    const cie_offset = stream.pos - id_len - id;
                    const cie = di.cie_map.get(cie_offset) orelse return badDwarf();
                    const fde = try FrameDescriptionEntry.parse(
                        entry_bytes,
                        @ptrToInt(eh_frame.ptr),
                        @ptrToInt(eh_frame.ptr) - @ptrToInt(binary_mem.ptr),
                        true,
                        cie,
                        @sizeOf(usize),
                        di.endian,
                    );
                    try di.fde_list.append(allocator, fde);
                }

                stream.pos += entry_bytes.len;
            }

            // TODO: Avoiding sorting if has_eh_frame_hdr exists
            std.mem.sort(FrameDescriptionEntry, di.fde_list.items, {}, struct {
                fn lessThan(ctx: void, a: FrameDescriptionEntry, b: FrameDescriptionEntry) bool {
                    _ = ctx;
                    return a.pc_begin < b.pc_begin;
                }
            }.lessThan);
        }
    }

    pub fn unwindFrame(di: *const DwarfInfo, allocator: mem.Allocator, context: *UnwindContext, module_base_address: usize) !void {
        if (context.pc == 0) return;

        // TODO: Handle signal frame (ie. use_prev_instr in libunwind)
        // TOOD: Use eh_frame_hdr to accelerate the search if available
        //const eh_frame_hdr = di.section(.eh_frame_hdr) orelse return error.MissingDebugInfo;

        // Find the FDE
        const unmapped_pc = context.pc - module_base_address;
        const index = std.sort.binarySearch(FrameDescriptionEntry, unmapped_pc, di.fde_list.items, {}, struct {
            pub fn compareFn(_: void, pc: usize, mid_item: FrameDescriptionEntry) std.math.Order {
                if (pc < mid_item.pc_begin) {
                    return .lt;
                } else {
                    const range_end = mid_item.pc_begin + mid_item.pc_range;
                    if (pc < range_end) {
                        return .eq;
                    }

                    return .gt;
                }
            }
        }.compareFn);

        const fde = if (index) |i| &di.fde_list.items[i] else return error.MissingFDE;
        const cie = di.cie_map.getPtr(fde.cie_length_offset) orelse return error.MissingCIE;

        // const prev_cfa = context.cfa;
        // const prev_pc = context.pc;

        // TODO: Cache this on self so we can re-use the allocations?
        var vm = call_frame.VirtualMachine{};
        defer vm.deinit(allocator);

        const row = try vm.runToNative(allocator, unmapped_pc, cie.*, fde.*);
        context.cfa = switch (row.cfa.rule) {
            .val_offset => |offset| blk: {
                const register = row.cfa.register orelse return error.InvalidCFARule;
                const value = mem.readIntSliceNative(usize, try abi.regBytes(&context.ucontext, register, context.reg_ctx));

                // TODO: Check isValidMemory?
                break :blk try call_frame.applyOffset(value, offset);
            },
            .expression => |expression| {

                // TODO: Evaluate expression
                _ = expression;
                return error.UnimplementedTODO;
            },
            else => return error.InvalidCFARule,
        };

        // Update the context with the previous frame's values
        var next_ucontext = context.ucontext;

        var has_next_ip = false;
        for (vm.rowColumns(row)) |column| {
            if (column.register) |register| {
                const dest = try abi.regBytes(&next_ucontext, register, context.reg_ctx);
                if (register == cie.return_address_register) {
                    has_next_ip = column.rule != .undefined;
                }

                try column.resolveValue(context.*, dest);
            }
        }

        context.ucontext = next_ucontext;

        if (has_next_ip) {
            context.pc = mem.readIntSliceNative(usize, try abi.regBytes(&context.ucontext, comptime abi.ipRegNum(), context.reg_ctx));
        } else {
            context.pc = 0;
        }

        mem.writeIntSliceNative(usize, try abi.regBytes(&context.ucontext, abi.spRegNum(context.reg_ctx), context.reg_ctx), context.cfa.?);
    }
};

pub const UnwindContext = struct {
    cfa: ?usize,
    pc: usize,
    ucontext: os.ucontext_t,
    reg_ctx: abi.RegisterContext,

    pub fn init(ucontext: *const os.ucontext_t) !UnwindContext {
        const pc = mem.readIntSliceNative(usize, try abi.regBytes(ucontext, abi.ipRegNum(), null));
        return .{
            .cfa = null,
            .pc = pc,
            .ucontext = ucontext.*,
            .reg_ctx = undefined,
        };
    }

    pub fn getFp(self: *const UnwindContext) !usize {
        return mem.readIntSliceNative(usize, try abi.regBytes(&self.ucontext, abi.fpRegNum(self.reg_ctx), self.reg_ctx));
    }
};

/// Initialize DWARF info. The caller has the responsibility to initialize most
/// the DwarfInfo fields before calling. `binary_mem` is the raw bytes of the
/// main binary file (not the secondary debug info file).
pub fn openDwarfDebugInfo(di: *DwarfInfo, allocator: mem.Allocator, binary_mem: []const u8) !void {
    try di.scanAllFunctions(allocator);
    try di.scanAllCompileUnits(allocator);

    // Unwind info is not required
    di.scanAllUnwindInfo(allocator, binary_mem) catch {};
}

/// This function is to make it handy to comment out the return and make it
/// into a crash when working on this file.
fn badDwarf() error{InvalidDebugInfo} {
    //std.os.abort(); // can be handy to uncomment when working on this file
    return error.InvalidDebugInfo;
}

fn missingDwarf() error{MissingDebugInfo} {
    //std.os.abort(); // can be handy to uncomment when working on this file
    return error.MissingDebugInfo;
}

fn getStringGeneric(opt_str: ?[]const u8, offset: u64) ![:0]const u8 {
    const str = opt_str orelse return badDwarf();
    if (offset > str.len) return badDwarf();
    const casted_offset = math.cast(usize, offset) orelse return badDwarf();
    // Valid strings always have a terminating zero byte
    const last = mem.indexOfScalarPos(u8, str, casted_offset, 0) orelse return badDwarf();
    return str[casted_offset..last :0];
}

const EhPointerContext = struct {
    // The address of the pointer field itself
    pc_rel_base: u64,

    // Whether or not to follow indirect pointers. This should only be
    // used when decoding pointers at runtime using the current process's
    // debug info.
    follow_indirect: bool,

    // These relative addressing modes are only used in specific cases, and
    // might not be available / required in all parsing contexts
    data_rel_base: ?u64 = null,
    text_rel_base: ?u64 = null,
    function_rel_base: ?u64 = null,
};

fn readEhPointer(reader: anytype, enc: u8, addr_size_bytes: u8, ctx: EhPointerContext, endian: std.builtin.Endian) !?u64 {
    if (enc == EH.PE.omit) return null;

    const value: union(enum) {
        signed: i64,
        unsigned: u64,
    } = switch (enc & EH.PE.type_mask) {
        EH.PE.absptr => .{
            .unsigned = switch (addr_size_bytes) {
                2 => try reader.readInt(u16, endian),
                4 => try reader.readInt(u32, endian),
                8 => try reader.readInt(u64, endian),
                else => return error.InvalidAddrSize,
            },
        },
        EH.PE.uleb128 => .{ .unsigned = try leb.readULEB128(u64, reader) },
        EH.PE.udata2 => .{ .unsigned = try reader.readInt(u16, endian) },
        EH.PE.udata4 => .{ .unsigned = try reader.readInt(u32, endian) },
        EH.PE.udata8 => .{ .unsigned = try reader.readInt(u64, endian) },
        EH.PE.sleb128 => .{ .signed = try leb.readILEB128(i64, reader) },
        EH.PE.sdata2 => .{ .signed = try reader.readInt(i16, endian) },
        EH.PE.sdata4 => .{ .signed = try reader.readInt(i32, endian) },
        EH.PE.sdata8 => .{ .signed = try reader.readInt(i64, endian) },
        else => return badDwarf(),
    };

    var base = switch (enc & EH.PE.rel_mask) {
        EH.PE.pcrel => ctx.pc_rel_base,
        EH.PE.textrel => ctx.text_rel_base orelse return error.PointerBaseNotSpecified,
        EH.PE.datarel => ctx.data_rel_base orelse return error.PointerBaseNotSpecified,
        EH.PE.funcrel => ctx.function_rel_base orelse return error.PointerBaseNotSpecified,
        else => null,
    };

    const ptr = if (base) |b| switch (value) {
        .signed => |s| @intCast(u64, s + @intCast(i64, b)),
        .unsigned => |u| u + b,
    } else switch (value) {
        .signed => |s| @intCast(u64, s),
        .unsigned => |u| u,
    };

    if ((enc & EH.PE.indirect) > 0 and ctx.follow_indirect) {
        if (@sizeOf(usize) != addr_size_bytes) {
            // See the documentation for `follow_indirect`
            return error.NonNativeIndirection;
        }

        const native_ptr = math.cast(usize, ptr) orelse return error.PointerOverflow;
        return switch (addr_size_bytes) {
            2, 4, 8 => return @intToPtr(*const usize, native_ptr).*,
            else => return error.UnsupportedAddrSize,
        };
    } else {
        return ptr;
    }
}

pub const CommonInformationEntry = struct {
    // Used in .eh_frame
    pub const eh_id = 0;

    // Used in .debug_frame (DWARF32)
    pub const dwarf32_id = std.math.maxInt(u32);

    // Used in .debug_frame (DWARF64)
    pub const dwarf64_id = std.math.maxInt(u64);

    // Offset of the length field of this entry in the eh_frame section.
    // This is the key that FDEs use to reference CIEs.
    length_offset: u64,
    version: u8,

    code_alignment_factor: u32,
    data_alignment_factor: i32,
    return_address_register: u8,

    aug_str: []const u8,
    aug_data: []const u8,
    lsda_pointer_enc: u8,
    personality_enc: ?u8,
    personality_routine_pointer: ?u64,
    fde_pointer_enc: u8,
    initial_instructions: []const u8,

    pub fn isSignalFrame(self: CommonInformationEntry) bool {
        for (self.aug_str) |c| if (c == 'S') return true;
        return false;
    }

    pub fn addressesSignedWithBKey(self: CommonInformationEntry) bool {
        for (self.aug_str) |c| if (c == 'B') return true;
        return false;
    }

    pub fn mteTaggedFrame(self: CommonInformationEntry) bool {
        for (self.aug_str) |c| if (c == 'G') return true;
        return false;
    }

    // This function expects to read the CIE starting with the version field.
    // The returned struct references memory backed by cie_bytes.
    pub fn parse(
        cie_bytes: []const u8,
        section_base: u64,
        section_offset: u64,
        is_runtime: bool,
        length_offset: u64,
        addr_size_bytes: u8,
        endian: std.builtin.Endian,
    ) !CommonInformationEntry {
        if (addr_size_bytes > 8) return error.UnsupportedAddrSize;

        var stream = io.fixedBufferStream(cie_bytes);
        const reader = stream.reader();

        const version = try reader.readByte();
        if (version != 1 and version != 3) return error.UnsupportedDwarfVersion;

        var has_eh_data = false;
        var has_aug_data = false;

        var aug_str_len: usize = 0;
        var aug_str_start = stream.pos;
        var aug_byte = try reader.readByte();
        while (aug_byte != 0) : (aug_byte = try reader.readByte()) {
            switch (aug_byte) {
                'z' => {
                    if (aug_str_len != 0) return badDwarf();
                    has_aug_data = true;
                },
                'e' => {
                    if (has_aug_data or aug_str_len != 0) return badDwarf();
                    if (try reader.readByte() != 'h') return badDwarf();
                    has_eh_data = true;
                },
                else => if (has_eh_data) return badDwarf(),
            }

            aug_str_len += 1;
        }

        if (has_eh_data) {
            // legacy data created by older versions of gcc - unsupported here
            for (0..addr_size_bytes) |_| _ = try reader.readByte();
        }

        const code_alignment_factor = try leb.readULEB128(u32, reader);
        const data_alignment_factor = try leb.readILEB128(i32, reader);
        const return_address_register = if (version == 1) try reader.readByte() else try leb.readULEB128(u8, reader);

        var lsda_pointer_enc: u8 = EH.PE.omit;
        var personality_enc: ?u8 = null;
        var personality_routine_pointer: ?u64 = null;
        var fde_pointer_enc: u8 = EH.PE.absptr;

        var aug_data: []const u8 = &[_]u8{};
        const aug_str = if (has_aug_data) blk: {
            const aug_data_len = try leb.readULEB128(usize, reader);
            const aug_data_start = stream.pos;
            aug_data = cie_bytes[aug_data_start..][0..aug_data_len];

            const aug_str = cie_bytes[aug_str_start..][0..aug_str_len];
            for (aug_str[1..]) |byte| {
                switch (byte) {
                    'L' => {
                        lsda_pointer_enc = try reader.readByte();
                    },
                    'P' => {
                        personality_enc = try reader.readByte();
                        personality_routine_pointer = try readEhPointer(
                            reader,
                            personality_enc.?,
                            addr_size_bytes,
                            .{
                                .pc_rel_base = @ptrToInt(&cie_bytes[stream.pos]) - section_base + section_offset,
                                .follow_indirect = is_runtime,
                            },
                            endian,
                        );
                    },
                    'R' => {
                        fde_pointer_enc = try reader.readByte();
                    },
                    'S', 'B', 'G' => {},
                    else => return badDwarf(),
                }
            }

            // aug_data_len can include padding so the CIE ends on an address boundary
            try stream.seekTo(aug_data_start + aug_data_len);
            break :blk aug_str;
        } else &[_]u8{};

        const initial_instructions = cie_bytes[stream.pos..];
        return .{
            .length_offset = length_offset,
            .version = version,
            .code_alignment_factor = code_alignment_factor,
            .data_alignment_factor = data_alignment_factor,
            .return_address_register = return_address_register,
            .aug_str = aug_str,
            .aug_data = aug_data,
            .lsda_pointer_enc = lsda_pointer_enc,
            .personality_enc = personality_enc,
            .personality_routine_pointer = personality_routine_pointer,
            .fde_pointer_enc = fde_pointer_enc,
            .initial_instructions = initial_instructions,
        };
    }
};

pub const FrameDescriptionEntry = struct {
    // Offset into eh_frame where the CIE for this FDE is stored
    cie_length_offset: u64,

    pc_begin: u64,
    pc_range: u64,
    lsda_pointer: ?u64,
    aug_data: []const u8,
    instructions: []const u8,

    // This function expects to read the FDE starting with the PC Begin field
    pub fn parse(
        fde_bytes: []const u8,
        section_base: u64,
        section_offset: u64,
        is_runtime: bool,
        cie: CommonInformationEntry,
        addr_size_bytes: u8,
        endian: std.builtin.Endian,
    ) !FrameDescriptionEntry {
        if (addr_size_bytes > 8) return error.InvalidAddrSize;

        var stream = io.fixedBufferStream(fde_bytes);
        const reader = stream.reader();

        const pc_begin = try readEhPointer(
            reader,
            cie.fde_pointer_enc,
            addr_size_bytes,
            .{
                .pc_rel_base = @ptrToInt(&fde_bytes[stream.pos]) - section_base + section_offset,
                .follow_indirect = is_runtime,
            },
            endian,
        ) orelse return badDwarf();

        const pc_range = try readEhPointer(
            reader,
            cie.fde_pointer_enc,
            addr_size_bytes,
            .{
                .pc_rel_base = 0,
                .follow_indirect = false,
            },
            endian,
        ) orelse return badDwarf();

        var aug_data: []const u8 = &[_]u8{};
        const lsda_pointer = if (cie.aug_str.len > 0) blk: {
            const aug_data_len = try leb.readULEB128(usize, reader);
            const aug_data_start = stream.pos;
            aug_data = fde_bytes[aug_data_start..][0..aug_data_len];

            const lsda_pointer = if (cie.lsda_pointer_enc != EH.PE.omit)
                try readEhPointer(
                    reader,
                    cie.lsda_pointer_enc,
                    addr_size_bytes,
                    .{
                        .pc_rel_base = @ptrToInt(&fde_bytes[stream.pos]) - section_base + section_offset,
                        .follow_indirect = is_runtime,
                    },
                    endian,
                )
            else
                null;

            try stream.seekTo(aug_data_start + aug_data_len);
            break :blk lsda_pointer;
        } else null;

        const instructions = fde_bytes[stream.pos..];
        return .{
            .cie_length_offset = cie.length_offset,
            .pc_begin = pc_begin,
            .pc_range = pc_range,
            .lsda_pointer = lsda_pointer,
            .aug_data = aug_data,
            .instructions = instructions,
        };
    }
};
