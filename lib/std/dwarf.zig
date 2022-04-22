const builtin = @import("builtin");
const std = @import("std.zig");
const debug = std.debug;
const fs = std.fs;
const io = std.io;
const mem = std.mem;
const math = std.math;
const leb = @import("leb128.zig");

pub const TAG = @import("dwarf/TAG.zig");
pub const AT = @import("dwarf/AT.zig");
pub const OP = @import("dwarf/OP.zig");
pub const LANG = @import("dwarf/LANG.zig");
pub const FORM = @import("dwarf/FORM.zig");
pub const ATE = @import("dwarf/ATE.zig");

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
    Block: []u8,
    Const: Constant,
    ExprLoc: []u8,
    Flag: bool,
    SecOffset: u64,
    Ref: u64,
    RefAddr: u64,
    String: []const u8,
    StrPtr: u64,
    LineStrPtr: u64,
};

const Constant = struct {
    payload: u64,
    signed: bool,

    fn asUnsignedLe(self: *const Constant) !u64 {
        if (self.signed) return error.InvalidDebugInfo;
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

    fn getAttrAddr(self: *const Die, id: u64) !u64 {
        const form_value = self.getAttr(id) orelse return error.MissingDebugInfo;
        return switch (form_value.*) {
            FormValue.Address => |value| value,
            else => error.InvalidDebugInfo,
        };
    }

    fn getAttrSecOffset(self: *const Die, id: u64) !u64 {
        const form_value = self.getAttr(id) orelse return error.MissingDebugInfo;
        return switch (form_value.*) {
            FormValue.Const => |value| value.asUnsignedLe(),
            FormValue.SecOffset => |value| value,
            else => error.InvalidDebugInfo,
        };
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

    pub fn getAttrString(self: *const Die, di: *DwarfInfo, id: u64) ![]const u8 {
        const form_value = self.getAttr(id) orelse return error.MissingDebugInfo;
        return switch (form_value.*) {
            FormValue.String => |value| value,
            FormValue.StrPtr => |offset| di.getString(offset),
            FormValue.LineStrPtr => |offset| di.getLineString(offset),
            else => error.InvalidDebugInfo,
        };
    }
};

const FileEntry = struct {
    file_name: []const u8,
    dir_index: usize,
    mtime: usize,
    len_bytes: usize,
};

const LineNumberProgram = struct {
    address: u64,
    file: usize,
    line: i64,
    column: u64,
    is_stmt: bool,
    basic_block: bool,
    end_sequence: bool,

    default_is_stmt: bool,
    target_address: u64,
    include_dirs: []const []const u8,

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

    pub fn init(is_stmt: bool, include_dirs: []const []const u8, target_address: u64) LineNumberProgram {
        return LineNumberProgram{
            .address = 0,
            .file = 1,
            .line = 1,
            .column = 0,
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
        if (self.prev_valid and self.target_address >= self.prev_address and self.target_address < self.address) {
            const file_entry = if (self.prev_file == 0) {
                return error.MissingDebugInfo;
            } else if (self.prev_file - 1 >= file_entries.len) {
                return error.InvalidDebugInfo;
            } else &file_entries[self.prev_file - 1];

            const dir_name = if (file_entry.dir_index >= self.include_dirs.len) {
                return error.InvalidDebugInfo;
            } else self.include_dirs[file_entry.dir_index];

            const file_name = try fs.path.join(allocator, &[_][]const u8{ dir_name, file_entry.file_name });

            return debug.LineInfo{
                .line = if (self.prev_line >= 0) @intCast(u64, self.prev_line) else 0,
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
        if (first_32_bits >= 0xfffffff0) return error.InvalidDebugInfo;
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
                        break :blk @bitCast(u64, x);
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
        FORM.line_strp => FormValue{ .LineStrPtr = try readAddress(in_stream, endian, is_64) },
        FORM.indirect => {
            const child_form_id = try nosuspend leb.readULEB128(u64, in_stream);
            if (builtin.zig_backend != .stage1) {
                return parseFormValue(allocator, in_stream, child_form_id, endian, is_64);
            }
            const F = @TypeOf(async parseFormValue(allocator, in_stream, child_form_id, endian, is_64));
            var frame = try allocator.create(F);
            defer allocator.destroy(frame);
            return await @asyncCall(frame, {}, parseFormValue, .{ allocator, in_stream, child_form_id, endian, is_64 });
        },
        FORM.implicit_const => FormValue{ .Const = Constant{ .signed = true, .payload = undefined } },

        else => {
            return error.InvalidDebugInfo;
        },
    };
}

fn getAbbrevTableEntry(abbrev_table: *const AbbrevTable, abbrev_code: u64) ?*const AbbrevTableEntry {
    for (abbrev_table.items) |*table_entry| {
        if (table_entry.abbrev_code == abbrev_code) return table_entry;
    }
    return null;
}

pub const DwarfInfo = struct {
    endian: std.builtin.Endian,
    // No memory is owned by the DwarfInfo
    debug_info: []const u8,
    debug_abbrev: []const u8,
    debug_str: []const u8,
    debug_line: []const u8,
    debug_line_str: ?[]const u8,
    debug_ranges: ?[]const u8,
    // Filled later by the initializer
    abbrev_table_list: std.ArrayListUnmanaged(AbbrevTableHeader) = .{},
    compile_unit_list: std.ArrayListUnmanaged(CompileUnit) = .{},
    func_list: std.ArrayListUnmanaged(Func) = .{},

    pub fn deinit(di: *DwarfInfo, allocator: mem.Allocator) void {
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
    }

    pub fn getSymbolName(di: *DwarfInfo, address: u64) ?[]const u8 {
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
        var stream = io.fixedBufferStream(di.debug_info);
        const in = &stream.reader();
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
            if (version < 2 or version > 5) return error.InvalidDebugInfo;

            var address_size: u8 = undefined;
            var debug_abbrev_offset: u64 = undefined;
            switch (version) {
                5 => {
                    const unit_type = try in.readInt(u8, di.endian);
                    if (unit_type != UT.compile) return error.InvalidDebugInfo;
                    address_size = try in.readByte();
                    debug_abbrev_offset = if (is_64)
                        try in.readInt(u64, di.endian)
                    else
                        try in.readInt(u32, di.endian);
                },
                else => {
                    debug_abbrev_offset = if (is_64)
                        try in.readInt(u64, di.endian)
                    else
                        try in.readInt(u32, di.endian);
                    address_size = try in.readByte();
                },
            }
            if (address_size != @sizeOf(usize)) return error.InvalidDebugInfo;

            const compile_unit_pos = try seekable.getPos();
            const abbrev_table = try di.getAbbrevTable(allocator, debug_abbrev_offset);

            try seekable.seekTo(compile_unit_pos);

            const next_unit_pos = this_unit_offset + next_offset;

            while ((try seekable.getPos()) < next_unit_pos) {
                const die_obj = (try di.parseDie(arena, in, abbrev_table, is_64)) orelse continue;
                const after_die_offset = try seekable.getPos();

                switch (die_obj.tag_id) {
                    TAG.subprogram, TAG.inlined_subroutine, TAG.subroutine, TAG.entry_point => {
                        const fn_name = x: {
                            var depth: i32 = 3;
                            var this_die_obj = die_obj;
                            // Prevent endless loops
                            while (depth > 0) : (depth -= 1) {
                                if (this_die_obj.getAttr(AT.name)) |_| {
                                    const name = try this_die_obj.getAttrString(di, AT.name);
                                    break :x try allocator.dupe(u8, name);
                                } else if (this_die_obj.getAttr(AT.abstract_origin)) |_| {
                                    // Follow the DIE it points to and repeat
                                    const ref_offset = try this_die_obj.getAttrRef(AT.abstract_origin);
                                    if (ref_offset > next_offset) return error.InvalidDebugInfo;
                                    try seekable.seekTo(this_unit_offset + ref_offset);
                                    this_die_obj = (try di.parseDie(
                                        arena,
                                        in,
                                        abbrev_table,
                                        is_64,
                                    )) orelse return error.InvalidDebugInfo;
                                } else if (this_die_obj.getAttr(AT.specification)) |_| {
                                    // Follow the DIE it points to and repeat
                                    const ref_offset = try this_die_obj.getAttrRef(AT.specification);
                                    if (ref_offset > next_offset) return error.InvalidDebugInfo;
                                    try seekable.seekTo(this_unit_offset + ref_offset);
                                    this_die_obj = (try di.parseDie(
                                        arena,
                                        in,
                                        abbrev_table,
                                        is_64,
                                    )) orelse return error.InvalidDebugInfo;
                                } else {
                                    break :x null;
                                }
                            }

                            break :x null;
                        };

                        const pc_range = x: {
                            if (die_obj.getAttrAddr(AT.low_pc)) |low_pc| {
                                if (die_obj.getAttr(AT.high_pc)) |high_pc_value| {
                                    const pc_end = switch (high_pc_value.*) {
                                        FormValue.Address => |value| value,
                                        FormValue.Const => |value| b: {
                                            const offset = try value.asUnsignedLe();
                                            break :b (low_pc + offset);
                                        },
                                        else => return error.InvalidDebugInfo,
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
        var stream = io.fixedBufferStream(di.debug_info);
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
            if (version < 2 or version > 5) return error.InvalidDebugInfo;

            var address_size: u8 = undefined;
            var debug_abbrev_offset: u64 = undefined;
            switch (version) {
                5 => {
                    const unit_type = try in.readInt(u8, di.endian);
                    if (unit_type != UT.compile) return error.InvalidDebugInfo;
                    address_size = try in.readByte();
                    debug_abbrev_offset = if (is_64)
                        try in.readInt(u64, di.endian)
                    else
                        try in.readInt(u32, di.endian);
                },
                else => {
                    debug_abbrev_offset = if (is_64)
                        try in.readInt(u64, di.endian)
                    else
                        try in.readInt(u32, di.endian);
                    address_size = try in.readByte();
                },
            }
            if (address_size != @sizeOf(usize)) return error.InvalidDebugInfo;

            const compile_unit_pos = try seekable.getPos();
            const abbrev_table = try di.getAbbrevTable(allocator, debug_abbrev_offset);

            try seekable.seekTo(compile_unit_pos);

            const compile_unit_die = try allocator.create(Die);
            errdefer allocator.destroy(compile_unit_die);
            compile_unit_die.* = (try di.parseDie(allocator, in, abbrev_table, is_64)) orelse
                return error.InvalidDebugInfo;

            if (compile_unit_die.tag_id != TAG.compile_unit) return error.InvalidDebugInfo;

            const pc_range = x: {
                if (compile_unit_die.getAttrAddr(AT.low_pc)) |low_pc| {
                    if (compile_unit_die.getAttr(AT.high_pc)) |high_pc_value| {
                        const pc_end = switch (high_pc_value.*) {
                            FormValue.Address => |value| value,
                            FormValue.Const => |value| b: {
                                const offset = try value.asUnsignedLe();
                                break :b (low_pc + offset);
                            },
                            else => return error.InvalidDebugInfo,
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

            try di.compile_unit_list.append(allocator, CompileUnit{
                .version = version,
                .is_64 = is_64,
                .pc_range = pc_range,
                .die = compile_unit_die,
            });

            this_unit_offset += next_offset;
        }
    }

    pub fn findCompileUnit(di: *DwarfInfo, target_address: u64) !*const CompileUnit {
        for (di.compile_unit_list.items) |*compile_unit| {
            if (compile_unit.pc_range) |range| {
                if (target_address >= range.start and target_address < range.end) return compile_unit;
            }
            if (di.debug_ranges) |debug_ranges| {
                if (compile_unit.die.getAttrSecOffset(AT.ranges)) |ranges_offset| {
                    var stream = io.fixedBufferStream(debug_ranges);
                    const in = &stream.reader();
                    const seekable = &stream.seekableStream();

                    // All the addresses in the list are relative to the value
                    // specified by DW_AT.low_pc or to some other value encoded
                    // in the list itself.
                    // If no starting value is specified use zero.
                    var base_address = compile_unit.die.getAttrAddr(AT.low_pc) catch |err| switch (err) {
                        error.MissingDebugInfo => @as(u64, 0), // TODO https://github.com/ziglang/zig/issues/11135
                        else => return err,
                    };

                    try seekable.seekTo(ranges_offset);

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
                } else |err| {
                    if (err != error.MissingDebugInfo) return err;
                    continue;
                }
            }
        }
        return error.MissingDebugInfo;
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
        var stream = io.fixedBufferStream(di.debug_abbrev);
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
        const table_entry = getAbbrevTableEntry(abbrev_table, abbrev_code) orelse return error.InvalidDebugInfo;

        var result = Die{
            // Lives as long as the Die.
            .arena = std.heap.ArenaAllocator.init(allocator),
            .tag_id = table_entry.tag_id,
            .has_children = table_entry.has_children,
        };
        try result.attrs.resize(allocator, table_entry.attrs.items.len);
        for (table_entry.attrs.items) |attr, i| {
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
                result.attrs.items[i].value.Const.payload = @bitCast(u64, attr.payload);
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
        var stream = io.fixedBufferStream(di.debug_line);
        const in = &stream.reader();
        const seekable = &stream.seekableStream();

        const compile_unit_cwd = try compile_unit.die.getAttrString(di, AT.comp_dir);
        const line_info_offset = try compile_unit.die.getAttrSecOffset(AT.stmt_list);

        try seekable.seekTo(line_info_offset);

        var is_64: bool = undefined;
        const unit_length = try readUnitLength(in, di.endian, &is_64);
        if (unit_length == 0) {
            return error.MissingDebugInfo;
        }
        const next_offset = unit_length + (if (is_64) @as(usize, 12) else @as(usize, 4));

        const version = try in.readInt(u16, di.endian);
        if (version < 2 or version > 4) return error.InvalidDebugInfo;

        const prologue_length = if (is_64) try in.readInt(u64, di.endian) else try in.readInt(u32, di.endian);
        const prog_start_offset = (try seekable.getPos()) + prologue_length;

        const minimum_instruction_length = try in.readByte();
        if (minimum_instruction_length == 0) return error.InvalidDebugInfo;

        if (version >= 4) {
            // maximum_operations_per_instruction
            _ = try in.readByte();
        }

        const default_is_stmt = (try in.readByte()) != 0;
        const line_base = try in.readByteSigned();

        const line_range = try in.readByte();
        if (line_range == 0) return error.InvalidDebugInfo;

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

        var include_directories = std.ArrayList([]const u8).init(arena);
        try include_directories.append(compile_unit_cwd);

        while (true) {
            const dir = try in.readUntilDelimiterAlloc(arena, 0, math.maxInt(usize));
            if (dir.len == 0) break;
            try include_directories.append(dir);
        }

        var file_entries = std.ArrayList(FileEntry).init(arena);
        var prog = LineNumberProgram.init(
            default_is_stmt,
            include_directories.items,
            target_address,
        );

        while (true) {
            const file_name = try in.readUntilDelimiterAlloc(arena, 0, math.maxInt(usize));
            if (file_name.len == 0) break;
            const dir_index = try leb.readULEB128(usize, in);
            const mtime = try leb.readULEB128(usize, in);
            const len_bytes = try leb.readULEB128(usize, in);
            try file_entries.append(FileEntry{
                .file_name = file_name,
                .dir_index = dir_index,
                .mtime = mtime,
                .len_bytes = len_bytes,
            });
        }

        try seekable.seekTo(prog_start_offset);

        const next_unit_pos = line_info_offset + next_offset;

        while ((try seekable.getPos()) < next_unit_pos) {
            const opcode = try in.readByte();

            if (opcode == LNS.extended_op) {
                const op_size = try leb.readULEB128(u64, in);
                if (op_size < 1) return error.InvalidDebugInfo;
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
                        const file_name = try in.readUntilDelimiterAlloc(arena, 0, math.maxInt(usize));
                        const dir_index = try leb.readULEB128(usize, in);
                        const mtime = try leb.readULEB128(usize, in);
                        const len_bytes = try leb.readULEB128(usize, in);
                        try file_entries.append(FileEntry{
                            .file_name = file_name,
                            .dir_index = dir_index,
                            .mtime = mtime,
                            .len_bytes = len_bytes,
                        });
                    },
                    else => {
                        const fwd_amt = math.cast(isize, op_size - 1) catch return error.InvalidDebugInfo;
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
                        if (opcode - 1 >= standard_opcode_lengths.len) return error.InvalidDebugInfo;
                        const len_bytes = standard_opcode_lengths[opcode - 1];
                        try seekable.seekBy(len_bytes);
                    },
                }
            }
        }

        return error.MissingDebugInfo;
    }

    fn getString(di: *DwarfInfo, offset: u64) ![]const u8 {
        if (offset > di.debug_str.len)
            return error.InvalidDebugInfo;
        const casted_offset = math.cast(usize, offset) catch
            return error.InvalidDebugInfo;

        // Valid strings always have a terminating zero byte
        if (mem.indexOfScalarPos(u8, di.debug_str, casted_offset, 0)) |last| {
            return di.debug_str[casted_offset..last];
        }

        return error.InvalidDebugInfo;
    }

    fn getLineString(di: *DwarfInfo, offset: u64) ![]const u8 {
        const debug_line_str = di.debug_line_str orelse return error.InvalidDebugInfo;
        if (offset > debug_line_str.len)
            return error.InvalidDebugInfo;
        const casted_offset = math.cast(usize, offset) catch
            return error.InvalidDebugInfo;

        // Valid strings always have a terminating zero byte
        if (mem.indexOfScalarPos(u8, debug_line_str, casted_offset, 0)) |last| {
            return debug_line_str[casted_offset..last];
        }

        return error.InvalidDebugInfo;
    }
};

/// Initialize DWARF info. The caller has the responsibility to initialize most
/// the DwarfInfo fields before calling.
pub fn openDwarfDebugInfo(di: *DwarfInfo, allocator: mem.Allocator) !void {
    try di.scanAllFunctions(allocator);
    try di.scanAllCompileUnits(allocator);
}
