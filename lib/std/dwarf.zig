//! DWARF debugging data format.

const builtin = @import("builtin");
const std = @import("std.zig");
const debug = std.debug;
const mem = std.mem;
const math = std.math;
const assert = debug.assert;
const native_endian = builtin.cpu.arch.endian();

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

    GNU_renesas_sh = 0x40,
    GNU_borland_fastcall_i386 = 0x41,

    pub const lo_user = 0x40;
    pub const hi_user = 0xff;
};

pub const Format = enum { @"32", @"64" };

const PcRange = struct {
    start: u64,
    end: u64,
};

const Func = struct {
    pc_range: ?PcRange,
    name: ?[]const u8,
};

pub const CompileUnit = struct {
    version: u16,
    format: Format,
    die: Die,
    pc_range: ?PcRange,

    str_offsets_base: usize,
    addr_base: usize,
    rnglists_base: usize,
    loclists_base: usize,
    frame_base: ?*const FormValue,
};

const Abbrev = struct {
    code: u64,
    tag_id: u64,
    has_children: bool,
    attrs: []Attr,

    fn deinit(abbrev: *Abbrev, allocator: mem.Allocator) void {
        allocator.free(abbrev.attrs);
        abbrev.* = undefined;
    }

    const Attr = struct {
        id: u64,
        form_id: u64,
        /// Only valid if form_id is .implicit_const
        payload: i64,
    };

    const Table = struct {
        // offset from .debug_abbrev
        offset: u64,
        abbrevs: []Abbrev,

        fn deinit(table: *Table, allocator: mem.Allocator) void {
            for (table.abbrevs) |*abbrev| {
                abbrev.deinit(allocator);
            }
            allocator.free(table.abbrevs);
            table.* = undefined;
        }

        fn get(table: *const Table, abbrev_code: u64) ?*const Abbrev {
            return for (table.abbrevs) |*abbrev| {
                if (abbrev.code == abbrev_code) break abbrev;
            } else null;
        }
    };
};

pub const FormValue = union(enum) {
    addr: u64,
    addrx: usize,
    block: []const u8,
    udata: u64,
    data16: *const [16]u8,
    sdata: i64,
    exprloc: []const u8,
    flag: bool,
    sec_offset: u64,
    ref: u64,
    ref_addr: u64,
    string: [:0]const u8,
    strp: u64,
    strx: usize,
    line_strp: u64,
    loclistx: u64,
    rnglistx: u64,

    fn getString(fv: FormValue, di: DwarfInfo) ![:0]const u8 {
        switch (fv) {
            .string => |s| return s,
            .strp => |off| return di.getString(off),
            .line_strp => |off| return di.getLineString(off),
            else => return badDwarf(),
        }
    }

    fn getUInt(fv: FormValue, comptime U: type) !U {
        return switch (fv) {
            inline .udata,
            .sdata,
            .sec_offset,
            => |c| math.cast(U, c) orelse badDwarf(),
            else => badDwarf(),
        };
    }
};

const Die = struct {
    tag_id: u64,
    has_children: bool,
    attrs: []Attr,

    const Attr = struct {
        id: u64,
        value: FormValue,
    };

    fn deinit(self: *Die, allocator: mem.Allocator) void {
        allocator.free(self.attrs);
        self.* = undefined;
    }

    fn getAttr(self: *const Die, id: u64) ?*const FormValue {
        for (self.attrs) |*attr| {
            if (attr.id == id) return &attr.value;
        }
        return null;
    }

    fn getAttrAddr(
        self: *const Die,
        di: *const DwarfInfo,
        id: u64,
        compile_unit: CompileUnit,
    ) error{ InvalidDebugInfo, MissingDebugInfo }!u64 {
        const form_value = self.getAttr(id) orelse return error.MissingDebugInfo;
        return switch (form_value.*) {
            .addr => |value| value,
            .addrx => |index| di.readDebugAddr(compile_unit, index),
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
            .Const => |value| value.asUnsignedLe(),
            else => error.InvalidDebugInfo,
        };
    }

    fn getAttrRef(self: *const Die, id: u64) !u64 {
        const form_value = self.getAttr(id) orelse return error.MissingDebugInfo;
        return switch (form_value.*) {
            .ref => |value| value,
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
            .string => |value| return value,
            .strp => |offset| return di.getString(offset),
            .strx => |index| {
                const debug_str_offsets = di.section(.debug_str_offsets) orelse return badDwarf();
                if (compile_unit.str_offsets_base == 0) return badDwarf();
                switch (compile_unit.format) {
                    .@"32" => {
                        const byte_offset = compile_unit.str_offsets_base + 4 * index;
                        if (byte_offset + 4 > debug_str_offsets.len) return badDwarf();
                        const offset = mem.readInt(u32, debug_str_offsets[byte_offset..][0..4], di.endian);
                        return getStringGeneric(opt_str, offset);
                    },
                    .@"64" => {
                        const byte_offset = compile_unit.str_offsets_base + 8 * index;
                        if (byte_offset + 8 > debug_str_offsets.len) return badDwarf();
                        const offset = mem.readInt(u64, debug_str_offsets[byte_offset..][0..8], di.endian);
                        return getStringGeneric(opt_str, offset);
                    },
                }
            },
            .line_strp => |offset| return di.getLineString(offset),
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

            const file_name = try std.fs.path.join(allocator, &[_][]const u8{
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

const UnitHeader = struct {
    format: Format,
    header_length: u4,
    unit_length: u64,
};
fn readUnitHeader(fbr: *FixedBufferReader) !UnitHeader {
    return switch (try fbr.readInt(u32)) {
        0...0xfffffff0 - 1 => |unit_length| .{
            .format = .@"32",
            .header_length = 4,
            .unit_length = unit_length,
        },
        0xfffffff0...0xffffffff - 1 => badDwarf(),
        0xffffffff => .{
            .format = .@"64",
            .header_length = 12,
            .unit_length = try fbr.readInt(u64),
        },
    };
}

fn parseFormValue(
    fbr: *FixedBufferReader,
    form_id: u64,
    format: Format,
    implicit_const: ?i64,
) anyerror!FormValue {
    return switch (form_id) {
        FORM.addr => .{ .addr = try fbr.readAddress(switch (@bitSizeOf(usize)) {
            32 => .@"32",
            64 => .@"64",
            else => @compileError("unsupported @sizeOf(usize)"),
        }) },
        FORM.addrx1 => .{ .addrx = try fbr.readInt(u8) },
        FORM.addrx2 => .{ .addrx = try fbr.readInt(u16) },
        FORM.addrx3 => .{ .addrx = try fbr.readInt(u24) },
        FORM.addrx4 => .{ .addrx = try fbr.readInt(u32) },
        FORM.addrx => .{ .addrx = try fbr.readUleb128(usize) },

        FORM.block1,
        FORM.block2,
        FORM.block4,
        FORM.block,
        => .{ .block = try fbr.readBytes(switch (form_id) {
            FORM.block1 => try fbr.readInt(u8),
            FORM.block2 => try fbr.readInt(u16),
            FORM.block4 => try fbr.readInt(u32),
            FORM.block => try fbr.readUleb128(usize),
            else => unreachable,
        }) },

        FORM.data1 => .{ .udata = try fbr.readInt(u8) },
        FORM.data2 => .{ .udata = try fbr.readInt(u16) },
        FORM.data4 => .{ .udata = try fbr.readInt(u32) },
        FORM.data8 => .{ .udata = try fbr.readInt(u64) },
        FORM.data16 => .{ .data16 = (try fbr.readBytes(16))[0..16] },
        FORM.udata => .{ .udata = try fbr.readUleb128(u64) },
        FORM.sdata => .{ .sdata = try fbr.readIleb128(i64) },
        FORM.exprloc => .{ .exprloc = try fbr.readBytes(try fbr.readUleb128(usize)) },
        FORM.flag => .{ .flag = (try fbr.readByte()) != 0 },
        FORM.flag_present => .{ .flag = true },
        FORM.sec_offset => .{ .sec_offset = try fbr.readAddress(format) },

        FORM.ref1 => .{ .ref = try fbr.readInt(u8) },
        FORM.ref2 => .{ .ref = try fbr.readInt(u16) },
        FORM.ref4 => .{ .ref = try fbr.readInt(u32) },
        FORM.ref8 => .{ .ref = try fbr.readInt(u64) },
        FORM.ref_udata => .{ .ref = try fbr.readUleb128(u64) },

        FORM.ref_addr => .{ .ref_addr = try fbr.readAddress(format) },
        FORM.ref_sig8 => .{ .ref = try fbr.readInt(u64) },

        FORM.string => .{ .string = try fbr.readBytesTo(0) },
        FORM.strp => .{ .strp = try fbr.readAddress(format) },
        FORM.strx1 => .{ .strx = try fbr.readInt(u8) },
        FORM.strx2 => .{ .strx = try fbr.readInt(u16) },
        FORM.strx3 => .{ .strx = try fbr.readInt(u24) },
        FORM.strx4 => .{ .strx = try fbr.readInt(u32) },
        FORM.strx => .{ .strx = try fbr.readUleb128(usize) },
        FORM.line_strp => .{ .line_strp = try fbr.readAddress(format) },
        FORM.indirect => parseFormValue(fbr, try fbr.readUleb128(u64), format, implicit_const),
        FORM.implicit_const => .{ .sdata = implicit_const orelse return badDwarf() },
        FORM.loclistx => .{ .loclistx = try fbr.readUleb128(u64) },
        FORM.rnglistx => .{ .rnglistx = try fbr.readUleb128(u64) },
        else => {
            //debug.print("unrecognized form id: {x}\n", .{form_id});
            return badDwarf();
        },
    };
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
        // Module-relative virtual address.
        // Only set if the section data was loaded from disk.
        virtual_address: ?usize = null,
        // If `data` is owned by this DwarfInfo.
        owned: bool,

        // For sections that are not memory mapped by the loader, this is an offset
        // from `data.ptr` to where the section would have been mapped. Otherwise,
        // `data` is directly backed by the section and the offset is zero.
        pub fn virtualOffset(self: Section, base_address: usize) i64 {
            return if (self.virtual_address) |va|
                @as(i64, @intCast(base_address + va)) -
                    @as(i64, @intCast(@intFromPtr(self.data.ptr)))
            else
                0;
        }
    };

    const num_sections = std.enums.directEnumArrayLen(DwarfSection, 0);
    pub const SectionArray = [num_sections]?Section;
    pub const null_section_array = [_]?Section{null} ** num_sections;

    endian: std.builtin.Endian,
    sections: SectionArray = null_section_array,
    is_macho: bool,

    // Filled later by the initializer
    abbrev_table_list: std.ArrayListUnmanaged(Abbrev.Table) = .{},
    compile_unit_list: std.ArrayListUnmanaged(CompileUnit) = .{},
    func_list: std.ArrayListUnmanaged(Func) = .{},

    eh_frame_hdr: ?ExceptionFrameHeader = null,
    // These lookup tables are only used if `eh_frame_hdr` is null
    cie_map: std.AutoArrayHashMapUnmanaged(u64, CommonInformationEntry) = .{},
    // Sorted by start_pc
    fde_list: std.ArrayListUnmanaged(FrameDescriptionEntry) = .{},

    pub fn section(di: DwarfInfo, dwarf_section: DwarfSection) ?[]const u8 {
        return if (di.sections[@intFromEnum(dwarf_section)]) |s| s.data else null;
    }

    pub fn sectionVirtualOffset(di: DwarfInfo, dwarf_section: DwarfSection, base_address: usize) ?i64 {
        return if (di.sections[@intFromEnum(dwarf_section)]) |s| s.virtualOffset(base_address) else null;
    }

    pub fn deinit(di: *DwarfInfo, allocator: mem.Allocator) void {
        for (di.sections) |opt_section| {
            if (opt_section) |s| if (s.owned) allocator.free(s.data);
        }
        for (di.abbrev_table_list.items) |*abbrev| {
            abbrev.deinit(allocator);
        }
        di.abbrev_table_list.deinit(allocator);
        for (di.compile_unit_list.items) |*cu| {
            cu.die.deinit(allocator);
        }
        di.compile_unit_list.deinit(allocator);
        di.func_list.deinit(allocator);
        di.cie_map.deinit(allocator);
        di.fde_list.deinit(allocator);
        di.* = undefined;
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
        var fbr: FixedBufferReader = .{ .buf = di.section(.debug_info).?, .endian = di.endian };
        var this_unit_offset: u64 = 0;

        while (this_unit_offset < fbr.buf.len) {
            try fbr.seekTo(this_unit_offset);

            const unit_header = try readUnitHeader(&fbr);
            if (unit_header.unit_length == 0) return;
            const next_offset = unit_header.header_length + unit_header.unit_length;

            const version = try fbr.readInt(u16);
            if (version < 2 or version > 5) return badDwarf();

            var address_size: u8 = undefined;
            var debug_abbrev_offset: u64 = undefined;
            if (version >= 5) {
                const unit_type = try fbr.readInt(u8);
                if (unit_type != UT.compile) return badDwarf();
                address_size = try fbr.readByte();
                debug_abbrev_offset = try fbr.readAddress(unit_header.format);
            } else {
                debug_abbrev_offset = try fbr.readAddress(unit_header.format);
                address_size = try fbr.readByte();
            }
            if (address_size != @sizeOf(usize)) return badDwarf();

            const abbrev_table = try di.getAbbrevTable(allocator, debug_abbrev_offset);

            var max_attrs: usize = 0;
            var zig_padding_abbrev_code: u7 = 0;
            for (abbrev_table.abbrevs) |abbrev| {
                max_attrs = @max(max_attrs, abbrev.attrs.len);
                if (math.cast(u7, abbrev.code)) |code| {
                    if (abbrev.tag_id == TAG.ZIG_padding and
                        !abbrev.has_children and
                        abbrev.attrs.len == 0)
                    {
                        zig_padding_abbrev_code = code;
                    }
                }
            }
            const attrs_buf = try allocator.alloc(Die.Attr, max_attrs * 3);
            defer allocator.free(attrs_buf);
            var attrs_bufs: [3][]Die.Attr = undefined;
            for (&attrs_bufs, 0..) |*buf, index| buf.* = attrs_buf[index * max_attrs ..][0..max_attrs];

            const next_unit_pos = this_unit_offset + next_offset;

            var compile_unit: CompileUnit = .{
                .version = version,
                .format = unit_header.format,
                .die = undefined,
                .pc_range = null,

                .str_offsets_base = 0,
                .addr_base = 0,
                .rnglists_base = 0,
                .loclists_base = 0,
                .frame_base = null,
            };

            while (true) {
                fbr.pos = mem.indexOfNonePos(u8, fbr.buf, fbr.pos, &.{
                    zig_padding_abbrev_code, 0,
                }) orelse fbr.buf.len;
                if (fbr.pos >= next_unit_pos) break;
                var die_obj = (try parseDie(
                    &fbr,
                    attrs_bufs[0],
                    abbrev_table,
                    unit_header.format,
                )) orelse continue;

                switch (die_obj.tag_id) {
                    TAG.compile_unit => {
                        compile_unit.die = die_obj;
                        compile_unit.die.attrs = attrs_bufs[1][0..die_obj.attrs.len];
                        @memcpy(compile_unit.die.attrs, die_obj.attrs);

                        compile_unit.str_offsets_base = if (die_obj.getAttr(AT.str_offsets_base)) |fv| try fv.getUInt(usize) else 0;
                        compile_unit.addr_base = if (die_obj.getAttr(AT.addr_base)) |fv| try fv.getUInt(usize) else 0;
                        compile_unit.rnglists_base = if (die_obj.getAttr(AT.rnglists_base)) |fv| try fv.getUInt(usize) else 0;
                        compile_unit.loclists_base = if (die_obj.getAttr(AT.loclists_base)) |fv| try fv.getUInt(usize) else 0;
                        compile_unit.frame_base = die_obj.getAttr(AT.frame_base);
                    },
                    TAG.subprogram, TAG.inlined_subroutine, TAG.subroutine, TAG.entry_point => {
                        const fn_name = x: {
                            var this_die_obj = die_obj;
                            // Prevent endless loops
                            for (0..3) |_| {
                                if (this_die_obj.getAttr(AT.name)) |_| {
                                    break :x try this_die_obj.getAttrString(di, AT.name, di.section(.debug_str), compile_unit);
                                } else if (this_die_obj.getAttr(AT.abstract_origin)) |_| {
                                    const after_die_offset = fbr.pos;
                                    defer fbr.pos = after_die_offset;

                                    // Follow the DIE it points to and repeat
                                    const ref_offset = try this_die_obj.getAttrRef(AT.abstract_origin);
                                    if (ref_offset > next_offset) return badDwarf();
                                    try fbr.seekTo(this_unit_offset + ref_offset);
                                    this_die_obj = (try parseDie(
                                        &fbr,
                                        attrs_bufs[2],
                                        abbrev_table,
                                        unit_header.format,
                                    )) orelse return badDwarf();
                                } else if (this_die_obj.getAttr(AT.specification)) |_| {
                                    const after_die_offset = fbr.pos;
                                    defer fbr.pos = after_die_offset;

                                    // Follow the DIE it points to and repeat
                                    const ref_offset = try this_die_obj.getAttrRef(AT.specification);
                                    if (ref_offset > next_offset) return badDwarf();
                                    try fbr.seekTo(this_unit_offset + ref_offset);
                                    this_die_obj = (try parseDie(
                                        &fbr,
                                        attrs_bufs[2],
                                        abbrev_table,
                                        unit_header.format,
                                    )) orelse return badDwarf();
                                } else {
                                    break :x null;
                                }
                            }

                            break :x null;
                        };

                        var range_added = if (die_obj.getAttrAddr(di, AT.low_pc, compile_unit)) |low_pc| blk: {
                            if (die_obj.getAttr(AT.high_pc)) |high_pc_value| {
                                const pc_end = switch (high_pc_value.*) {
                                    .addr => |value| value,
                                    .udata => |offset| low_pc + offset,
                                    else => return badDwarf(),
                                };

                                try di.func_list.append(allocator, .{
                                    .name = fn_name,
                                    .pc_range = .{
                                        .start = low_pc,
                                        .end = pc_end,
                                    },
                                });

                                break :blk true;
                            }

                            break :blk false;
                        } else |err| blk: {
                            if (err != error.MissingDebugInfo) return err;
                            break :blk false;
                        };

                        if (die_obj.getAttr(AT.ranges)) |ranges_value| blk: {
                            var iter = DebugRangeIterator.init(ranges_value, di, &compile_unit) catch |err| {
                                if (err != error.MissingDebugInfo) return err;
                                break :blk;
                            };

                            while (try iter.next()) |range| {
                                range_added = true;
                                try di.func_list.append(allocator, .{
                                    .name = fn_name,
                                    .pc_range = .{
                                        .start = range.start_addr,
                                        .end = range.end_addr,
                                    },
                                });
                            }
                        }

                        if (fn_name != null and !range_added) {
                            try di.func_list.append(allocator, .{
                                .name = fn_name,
                                .pc_range = null,
                            });
                        }
                    },
                    else => {},
                }
            }

            this_unit_offset += next_offset;
        }
    }

    fn scanAllCompileUnits(di: *DwarfInfo, allocator: mem.Allocator) !void {
        var fbr: FixedBufferReader = .{ .buf = di.section(.debug_info).?, .endian = di.endian };
        var this_unit_offset: u64 = 0;

        var attrs_buf = std.ArrayList(Die.Attr).init(allocator);
        defer attrs_buf.deinit();

        while (this_unit_offset < fbr.buf.len) {
            try fbr.seekTo(this_unit_offset);

            const unit_header = try readUnitHeader(&fbr);
            if (unit_header.unit_length == 0) return;
            const next_offset = unit_header.header_length + unit_header.unit_length;

            const version = try fbr.readInt(u16);
            if (version < 2 or version > 5) return badDwarf();

            var address_size: u8 = undefined;
            var debug_abbrev_offset: u64 = undefined;
            if (version >= 5) {
                const unit_type = try fbr.readInt(u8);
                if (unit_type != UT.compile) return badDwarf();
                address_size = try fbr.readByte();
                debug_abbrev_offset = try fbr.readAddress(unit_header.format);
            } else {
                debug_abbrev_offset = try fbr.readAddress(unit_header.format);
                address_size = try fbr.readByte();
            }
            if (address_size != @sizeOf(usize)) return badDwarf();

            const abbrev_table = try di.getAbbrevTable(allocator, debug_abbrev_offset);

            var max_attrs: usize = 0;
            for (abbrev_table.abbrevs) |abbrev| {
                max_attrs = @max(max_attrs, abbrev.attrs.len);
            }
            try attrs_buf.resize(max_attrs);

            var compile_unit_die = (try parseDie(
                &fbr,
                attrs_buf.items,
                abbrev_table,
                unit_header.format,
            )) orelse return badDwarf();

            if (compile_unit_die.tag_id != TAG.compile_unit) return badDwarf();

            compile_unit_die.attrs = try allocator.dupe(Die.Attr, compile_unit_die.attrs);

            var compile_unit: CompileUnit = .{
                .version = version,
                .format = unit_header.format,
                .pc_range = null,
                .die = compile_unit_die,
                .str_offsets_base = if (compile_unit_die.getAttr(AT.str_offsets_base)) |fv| try fv.getUInt(usize) else 0,
                .addr_base = if (compile_unit_die.getAttr(AT.addr_base)) |fv| try fv.getUInt(usize) else 0,
                .rnglists_base = if (compile_unit_die.getAttr(AT.rnglists_base)) |fv| try fv.getUInt(usize) else 0,
                .loclists_base = if (compile_unit_die.getAttr(AT.loclists_base)) |fv| try fv.getUInt(usize) else 0,
                .frame_base = compile_unit_die.getAttr(AT.frame_base),
            };

            compile_unit.pc_range = x: {
                if (compile_unit_die.getAttrAddr(di, AT.low_pc, compile_unit)) |low_pc| {
                    if (compile_unit_die.getAttr(AT.high_pc)) |high_pc_value| {
                        const pc_end = switch (high_pc_value.*) {
                            .addr => |value| value,
                            .udata => |offset| low_pc + offset,
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

    const DebugRangeIterator = struct {
        base_address: u64,
        section_type: DwarfSection,
        di: *const DwarfInfo,
        compile_unit: *const CompileUnit,
        fbr: FixedBufferReader,

        pub fn init(ranges_value: *const FormValue, di: *const DwarfInfo, compile_unit: *const CompileUnit) !@This() {
            const section_type = if (compile_unit.version >= 5) DwarfSection.debug_rnglists else DwarfSection.debug_ranges;
            const debug_ranges = di.section(section_type) orelse return error.MissingDebugInfo;

            const ranges_offset = switch (ranges_value.*) {
                .sec_offset, .udata => |off| off,
                .rnglistx => |idx| off: {
                    switch (compile_unit.format) {
                        .@"32" => {
                            const offset_loc = @as(usize, @intCast(compile_unit.rnglists_base + 4 * idx));
                            if (offset_loc + 4 > debug_ranges.len) return badDwarf();
                            const offset = mem.readInt(u32, debug_ranges[offset_loc..][0..4], di.endian);
                            break :off compile_unit.rnglists_base + offset;
                        },
                        .@"64" => {
                            const offset_loc = @as(usize, @intCast(compile_unit.rnglists_base + 8 * idx));
                            if (offset_loc + 8 > debug_ranges.len) return badDwarf();
                            const offset = mem.readInt(u64, debug_ranges[offset_loc..][0..8], di.endian);
                            break :off compile_unit.rnglists_base + offset;
                        },
                    }
                },
                else => return badDwarf(),
            };

            // All the addresses in the list are relative to the value
            // specified by DW_AT.low_pc or to some other value encoded
            // in the list itself.
            // If no starting value is specified use zero.
            const base_address = compile_unit.die.getAttrAddr(di, AT.low_pc, compile_unit.*) catch |err| switch (err) {
                error.MissingDebugInfo => 0,
                else => return err,
            };

            return .{
                .base_address = base_address,
                .section_type = section_type,
                .di = di,
                .compile_unit = compile_unit,
                .fbr = .{
                    .buf = debug_ranges,
                    .pos = math.cast(usize, ranges_offset) orelse return badDwarf(),
                    .endian = di.endian,
                },
            };
        }

        // Returns the next range in the list, or null if the end was reached.
        pub fn next(self: *@This()) !?struct { start_addr: u64, end_addr: u64 } {
            switch (self.section_type) {
                .debug_rnglists => {
                    const kind = try self.fbr.readByte();
                    switch (kind) {
                        RLE.end_of_list => return null,
                        RLE.base_addressx => {
                            const index = try self.fbr.readUleb128(usize);
                            self.base_address = try self.di.readDebugAddr(self.compile_unit.*, index);
                            return try self.next();
                        },
                        RLE.startx_endx => {
                            const start_index = try self.fbr.readUleb128(usize);
                            const start_addr = try self.di.readDebugAddr(self.compile_unit.*, start_index);

                            const end_index = try self.fbr.readUleb128(usize);
                            const end_addr = try self.di.readDebugAddr(self.compile_unit.*, end_index);

                            return .{
                                .start_addr = start_addr,
                                .end_addr = end_addr,
                            };
                        },
                        RLE.startx_length => {
                            const start_index = try self.fbr.readUleb128(usize);
                            const start_addr = try self.di.readDebugAddr(self.compile_unit.*, start_index);

                            const len = try self.fbr.readUleb128(usize);
                            const end_addr = start_addr + len;

                            return .{
                                .start_addr = start_addr,
                                .end_addr = end_addr,
                            };
                        },
                        RLE.offset_pair => {
                            const start_addr = try self.fbr.readUleb128(usize);
                            const end_addr = try self.fbr.readUleb128(usize);

                            // This is the only kind that uses the base address
                            return .{
                                .start_addr = self.base_address + start_addr,
                                .end_addr = self.base_address + end_addr,
                            };
                        },
                        RLE.base_address => {
                            self.base_address = try self.fbr.readInt(usize);
                            return try self.next();
                        },
                        RLE.start_end => {
                            const start_addr = try self.fbr.readInt(usize);
                            const end_addr = try self.fbr.readInt(usize);

                            return .{
                                .start_addr = start_addr,
                                .end_addr = end_addr,
                            };
                        },
                        RLE.start_length => {
                            const start_addr = try self.fbr.readInt(usize);
                            const len = try self.fbr.readUleb128(usize);
                            const end_addr = start_addr + len;

                            return .{
                                .start_addr = start_addr,
                                .end_addr = end_addr,
                            };
                        },
                        else => return badDwarf(),
                    }
                },
                .debug_ranges => {
                    const start_addr = try self.fbr.readInt(usize);
                    const end_addr = try self.fbr.readInt(usize);
                    if (start_addr == 0 and end_addr == 0) return null;

                    // This entry selects a new value for the base address
                    if (start_addr == math.maxInt(usize)) {
                        self.base_address = end_addr;
                        return try self.next();
                    }

                    return .{
                        .start_addr = self.base_address + start_addr,
                        .end_addr = self.base_address + end_addr,
                    };
                },
                else => unreachable,
            }
        }
    };

    pub fn findCompileUnit(di: *const DwarfInfo, target_address: u64) !*const CompileUnit {
        for (di.compile_unit_list.items) |*compile_unit| {
            if (compile_unit.pc_range) |range| {
                if (target_address >= range.start and target_address < range.end) return compile_unit;
            }

            const ranges_value = compile_unit.die.getAttr(AT.ranges) orelse continue;
            var iter = DebugRangeIterator.init(ranges_value, di, compile_unit) catch continue;
            while (try iter.next()) |range| {
                if (target_address >= range.start_addr and target_address < range.end_addr) return compile_unit;
            }
        }

        return missingDwarf();
    }

    /// Gets an already existing AbbrevTable given the abbrev_offset, or if not found,
    /// seeks in the stream and parses it.
    fn getAbbrevTable(di: *DwarfInfo, allocator: mem.Allocator, abbrev_offset: u64) !*const Abbrev.Table {
        for (di.abbrev_table_list.items) |*table| {
            if (table.offset == abbrev_offset) {
                return table;
            }
        }
        try di.abbrev_table_list.append(
            allocator,
            try di.parseAbbrevTable(allocator, abbrev_offset),
        );
        return &di.abbrev_table_list.items[di.abbrev_table_list.items.len - 1];
    }

    fn parseAbbrevTable(di: *DwarfInfo, allocator: mem.Allocator, offset: u64) !Abbrev.Table {
        var fbr: FixedBufferReader = .{
            .buf = di.section(.debug_abbrev).?,
            .pos = math.cast(usize, offset) orelse return badDwarf(),
            .endian = di.endian,
        };

        var abbrevs = std.ArrayList(Abbrev).init(allocator);
        defer {
            for (abbrevs.items) |*abbrev| {
                abbrev.deinit(allocator);
            }
            abbrevs.deinit();
        }

        var attrs = std.ArrayList(Abbrev.Attr).init(allocator);
        defer attrs.deinit();

        while (true) {
            const code = try fbr.readUleb128(u64);
            if (code == 0) break;
            const tag_id = try fbr.readUleb128(u64);
            const has_children = (try fbr.readByte()) == CHILDREN.yes;

            while (true) {
                const attr_id = try fbr.readUleb128(u64);
                const form_id = try fbr.readUleb128(u64);
                if (attr_id == 0 and form_id == 0) break;
                try attrs.append(.{
                    .id = attr_id,
                    .form_id = form_id,
                    .payload = switch (form_id) {
                        FORM.implicit_const => try fbr.readIleb128(i64),
                        else => undefined,
                    },
                });
            }

            try abbrevs.append(.{
                .code = code,
                .tag_id = tag_id,
                .has_children = has_children,
                .attrs = try attrs.toOwnedSlice(),
            });
        }

        return .{
            .offset = offset,
            .abbrevs = try abbrevs.toOwnedSlice(),
        };
    }

    fn parseDie(
        fbr: *FixedBufferReader,
        attrs_buf: []Die.Attr,
        abbrev_table: *const Abbrev.Table,
        format: Format,
    ) !?Die {
        const abbrev_code = try fbr.readUleb128(u64);
        if (abbrev_code == 0) return null;
        const table_entry = abbrev_table.get(abbrev_code) orelse return badDwarf();

        const attrs = attrs_buf[0..table_entry.attrs.len];
        for (attrs, table_entry.attrs) |*result_attr, attr| result_attr.* = Die.Attr{
            .id = attr.id,
            .value = try parseFormValue(
                fbr,
                attr.form_id,
                format,
                attr.payload,
            ),
        };
        return .{
            .tag_id = table_entry.tag_id,
            .has_children = table_entry.has_children,
            .attrs = attrs,
        };
    }

    pub fn getLineNumberInfo(
        di: *DwarfInfo,
        allocator: mem.Allocator,
        compile_unit: CompileUnit,
        target_address: u64,
    ) !debug.LineInfo {
        const compile_unit_cwd = try compile_unit.die.getAttrString(di, AT.comp_dir, di.section(.debug_line_str), compile_unit);
        const line_info_offset = try compile_unit.die.getAttrSecOffset(AT.stmt_list);

        var fbr: FixedBufferReader = .{ .buf = di.section(.debug_line).?, .endian = di.endian };
        try fbr.seekTo(line_info_offset);

        const unit_header = try readUnitHeader(&fbr);
        if (unit_header.unit_length == 0) return missingDwarf();
        const next_offset = unit_header.header_length + unit_header.unit_length;

        const version = try fbr.readInt(u16);
        if (version < 2) return badDwarf();

        var addr_size: u8 = switch (unit_header.format) {
            .@"32" => 4,
            .@"64" => 8,
        };
        var seg_size: u8 = 0;
        if (version >= 5) {
            addr_size = try fbr.readByte();
            seg_size = try fbr.readByte();
        }

        const prologue_length = try fbr.readAddress(unit_header.format);
        const prog_start_offset = fbr.pos + prologue_length;

        const minimum_instruction_length = try fbr.readByte();
        if (minimum_instruction_length == 0) return badDwarf();

        if (version >= 4) {
            // maximum_operations_per_instruction
            _ = try fbr.readByte();
        }

        const default_is_stmt = (try fbr.readByte()) != 0;
        const line_base = try fbr.readByteSigned();

        const line_range = try fbr.readByte();
        if (line_range == 0) return badDwarf();

        const opcode_base = try fbr.readByte();

        const standard_opcode_lengths = try fbr.readBytes(opcode_base - 1);

        var include_directories = std.ArrayList(FileEntry).init(allocator);
        defer include_directories.deinit();
        var file_entries = std.ArrayList(FileEntry).init(allocator);
        defer file_entries.deinit();

        if (version < 5) {
            try include_directories.append(.{ .path = compile_unit_cwd });

            while (true) {
                const dir = try fbr.readBytesTo(0);
                if (dir.len == 0) break;
                try include_directories.append(.{ .path = dir });
            }

            while (true) {
                const file_name = try fbr.readBytesTo(0);
                if (file_name.len == 0) break;
                const dir_index = try fbr.readUleb128(u32);
                const mtime = try fbr.readUleb128(u64);
                const size = try fbr.readUleb128(u64);
                try file_entries.append(.{
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
                const directory_entry_format_count = try fbr.readByte();
                if (directory_entry_format_count > dir_ent_fmt_buf.len) return badDwarf();
                for (dir_ent_fmt_buf[0..directory_entry_format_count]) |*ent_fmt| {
                    ent_fmt.* = .{
                        .content_type_code = try fbr.readUleb128(u8),
                        .form_code = try fbr.readUleb128(u16),
                    };
                }

                const directories_count = try fbr.readUleb128(usize);
                try include_directories.ensureUnusedCapacity(directories_count);
                {
                    var i: usize = 0;
                    while (i < directories_count) : (i += 1) {
                        var e: FileEntry = .{ .path = &.{} };
                        for (dir_ent_fmt_buf[0..directory_entry_format_count]) |ent_fmt| {
                            const form_value = try parseFormValue(
                                &fbr,
                                ent_fmt.form_code,
                                unit_header.format,
                                null,
                            );
                            switch (ent_fmt.content_type_code) {
                                LNCT.path => e.path = try form_value.getString(di.*),
                                LNCT.directory_index => e.dir_index = try form_value.getUInt(u32),
                                LNCT.timestamp => e.mtime = try form_value.getUInt(u64),
                                LNCT.size => e.size = try form_value.getUInt(u64),
                                LNCT.MD5 => e.md5 = switch (form_value) {
                                    .data16 => |data16| data16.*,
                                    else => return badDwarf(),
                                },
                                else => continue,
                            }
                        }
                        include_directories.appendAssumeCapacity(e);
                    }
                }
            }

            var file_ent_fmt_buf: [10]FileEntFmt = undefined;
            const file_name_entry_format_count = try fbr.readByte();
            if (file_name_entry_format_count > file_ent_fmt_buf.len) return badDwarf();
            for (file_ent_fmt_buf[0..file_name_entry_format_count]) |*ent_fmt| {
                ent_fmt.* = .{
                    .content_type_code = try fbr.readUleb128(u8),
                    .form_code = try fbr.readUleb128(u16),
                };
            }

            const file_names_count = try fbr.readUleb128(usize);
            try file_entries.ensureUnusedCapacity(file_names_count);
            {
                var i: usize = 0;
                while (i < file_names_count) : (i += 1) {
                    var e: FileEntry = .{ .path = &.{} };
                    for (file_ent_fmt_buf[0..file_name_entry_format_count]) |ent_fmt| {
                        const form_value = try parseFormValue(
                            &fbr,
                            ent_fmt.form_code,
                            unit_header.format,
                            null,
                        );
                        switch (ent_fmt.content_type_code) {
                            LNCT.path => e.path = try form_value.getString(di.*),
                            LNCT.directory_index => e.dir_index = try form_value.getUInt(u32),
                            LNCT.timestamp => e.mtime = try form_value.getUInt(u64),
                            LNCT.size => e.size = try form_value.getUInt(u64),
                            LNCT.MD5 => e.md5 = switch (form_value) {
                                .data16 => |data16| data16.*,
                                else => return badDwarf(),
                            },
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

        try fbr.seekTo(prog_start_offset);

        const next_unit_pos = line_info_offset + next_offset;

        while (fbr.pos < next_unit_pos) {
            const opcode = try fbr.readByte();

            if (opcode == LNS.extended_op) {
                const op_size = try fbr.readUleb128(u64);
                if (op_size < 1) return badDwarf();
                const sub_op = try fbr.readByte();
                switch (sub_op) {
                    LNE.end_sequence => {
                        prog.end_sequence = true;
                        if (try prog.checkLineMatch(allocator, file_entries.items)) |info| return info;
                        prog.reset();
                    },
                    LNE.set_address => {
                        const addr = try fbr.readInt(usize);
                        prog.address = addr;
                    },
                    LNE.define_file => {
                        const path = try fbr.readBytesTo(0);
                        const dir_index = try fbr.readUleb128(u32);
                        const mtime = try fbr.readUleb128(u64);
                        const size = try fbr.readUleb128(u64);
                        try file_entries.append(.{
                            .path = path,
                            .dir_index = dir_index,
                            .mtime = mtime,
                            .size = size,
                        });
                    },
                    else => try fbr.seekForward(op_size - 1),
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
                        const arg = try fbr.readUleb128(usize);
                        prog.address += arg * minimum_instruction_length;
                    },
                    LNS.advance_line => {
                        const arg = try fbr.readIleb128(i64);
                        prog.line += arg;
                    },
                    LNS.set_file => {
                        const arg = try fbr.readUleb128(usize);
                        prog.file = arg;
                    },
                    LNS.set_column => {
                        const arg = try fbr.readUleb128(u64);
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
                        const arg = try fbr.readInt(u16);
                        prog.address += arg;
                    },
                    LNS.set_prologue_end => {},
                    else => {
                        if (opcode - 1 >= standard_opcode_lengths.len) return badDwarf();
                        try fbr.seekForward(standard_opcode_lengths[opcode - 1]);
                    },
                }
            }
        }

        return missingDwarf();
    }

    fn getString(di: DwarfInfo, offset: u64) ![:0]const u8 {
        return getStringGeneric(di.section(.debug_str), offset);
    }

    fn getLineString(di: DwarfInfo, offset: u64) ![:0]const u8 {
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

    /// If .eh_frame_hdr is present, then only the header needs to be parsed.
    ///
    /// Otherwise, .eh_frame and .debug_frame are scanned and a sorted list
    /// of FDEs is built for binary searching during unwinding.
    pub fn scanAllUnwindInfo(di: *DwarfInfo, allocator: mem.Allocator, base_address: usize) !void {
        if (di.section(.eh_frame_hdr)) |eh_frame_hdr| blk: {
            var fbr: FixedBufferReader = .{ .buf = eh_frame_hdr, .endian = native_endian };

            const version = try fbr.readByte();
            if (version != 1) break :blk;

            const eh_frame_ptr_enc = try fbr.readByte();
            if (eh_frame_ptr_enc == EH.PE.omit) break :blk;
            const fde_count_enc = try fbr.readByte();
            if (fde_count_enc == EH.PE.omit) break :blk;
            const table_enc = try fbr.readByte();
            if (table_enc == EH.PE.omit) break :blk;

            const eh_frame_ptr = math.cast(usize, try readEhPointer(&fbr, eh_frame_ptr_enc, @sizeOf(usize), .{
                .pc_rel_base = @intFromPtr(&eh_frame_hdr[fbr.pos]),
                .follow_indirect = true,
            }) orelse return badDwarf()) orelse return badDwarf();

            const fde_count = math.cast(usize, try readEhPointer(&fbr, fde_count_enc, @sizeOf(usize), .{
                .pc_rel_base = @intFromPtr(&eh_frame_hdr[fbr.pos]),
                .follow_indirect = true,
            }) orelse return badDwarf()) orelse return badDwarf();

            const entry_size = try ExceptionFrameHeader.entrySize(table_enc);
            const entries_len = fde_count * entry_size;
            if (entries_len > eh_frame_hdr.len - fbr.pos) return badDwarf();

            di.eh_frame_hdr = .{
                .eh_frame_ptr = eh_frame_ptr,
                .table_enc = table_enc,
                .fde_count = fde_count,
                .entries = eh_frame_hdr[fbr.pos..][0..entries_len],
            };

            // No need to scan .eh_frame, we have a binary search table already
            return;
        }

        const frame_sections = [2]DwarfSection{ .eh_frame, .debug_frame };
        for (frame_sections) |frame_section| {
            if (di.section(frame_section)) |section_data| {
                var fbr: FixedBufferReader = .{ .buf = section_data, .endian = di.endian };
                while (fbr.pos < fbr.buf.len) {
                    const entry_header = try EntryHeader.read(&fbr, frame_section);
                    switch (entry_header.type) {
                        .cie => {
                            const cie = try CommonInformationEntry.parse(
                                entry_header.entry_bytes,
                                di.sectionVirtualOffset(frame_section, base_address).?,
                                true,
                                entry_header.format,
                                frame_section,
                                entry_header.length_offset,
                                @sizeOf(usize),
                                di.endian,
                            );
                            try di.cie_map.put(allocator, entry_header.length_offset, cie);
                        },
                        .fde => |cie_offset| {
                            const cie = di.cie_map.get(cie_offset) orelse return badDwarf();
                            const fde = try FrameDescriptionEntry.parse(
                                entry_header.entry_bytes,
                                di.sectionVirtualOffset(frame_section, base_address).?,
                                true,
                                cie,
                                @sizeOf(usize),
                                di.endian,
                            );
                            try di.fde_list.append(allocator, fde);
                        },
                        .terminator => break,
                    }
                }

                mem.sortUnstable(FrameDescriptionEntry, di.fde_list.items, {}, struct {
                    fn lessThan(ctx: void, a: FrameDescriptionEntry, b: FrameDescriptionEntry) bool {
                        _ = ctx;
                        return a.pc_begin < b.pc_begin;
                    }
                }.lessThan);
            }
        }
    }

    /// Unwind a stack frame using DWARF unwinding info, updating the register context.
    ///
    /// If `.eh_frame_hdr` is available, it will be used to binary search for the FDE.
    /// Otherwise, a linear scan of `.eh_frame` and `.debug_frame` is done to find the FDE.
    ///
    /// `explicit_fde_offset` is for cases where the FDE offset is known, such as when __unwind_info
    /// defers unwinding to DWARF. This is an offset into the `.eh_frame` section.
    pub fn unwindFrame(di: *const DwarfInfo, context: *UnwindContext, explicit_fde_offset: ?usize) !usize {
        if (!comptime abi.supportsUnwinding(builtin.target)) return error.UnsupportedCpuArchitecture;
        if (context.pc == 0) return 0;

        // Find the FDE and CIE
        var cie: CommonInformationEntry = undefined;
        var fde: FrameDescriptionEntry = undefined;

        if (explicit_fde_offset) |fde_offset| {
            const dwarf_section: DwarfSection = .eh_frame;
            const frame_section = di.section(dwarf_section) orelse return error.MissingFDE;
            if (fde_offset >= frame_section.len) return error.MissingFDE;

            var fbr: FixedBufferReader = .{
                .buf = frame_section,
                .pos = fde_offset,
                .endian = di.endian,
            };

            const fde_entry_header = try EntryHeader.read(&fbr, dwarf_section);
            if (fde_entry_header.type != .fde) return error.MissingFDE;

            const cie_offset = fde_entry_header.type.fde;
            try fbr.seekTo(cie_offset);

            fbr.endian = native_endian;
            const cie_entry_header = try EntryHeader.read(&fbr, dwarf_section);
            if (cie_entry_header.type != .cie) return badDwarf();

            cie = try CommonInformationEntry.parse(
                cie_entry_header.entry_bytes,
                0,
                true,
                cie_entry_header.format,
                dwarf_section,
                cie_entry_header.length_offset,
                @sizeOf(usize),
                native_endian,
            );

            fde = try FrameDescriptionEntry.parse(
                fde_entry_header.entry_bytes,
                0,
                true,
                cie,
                @sizeOf(usize),
                native_endian,
            );
        } else if (di.eh_frame_hdr) |header| {
            const eh_frame_len = if (di.section(.eh_frame)) |eh_frame| eh_frame.len else null;
            try header.findEntry(
                context.isValidMemory,
                eh_frame_len,
                @intFromPtr(di.section(.eh_frame_hdr).?.ptr),
                context.pc,
                &cie,
                &fde,
            );
        } else {
            const index = std.sort.binarySearch(FrameDescriptionEntry, context.pc, di.fde_list.items, {}, struct {
                pub fn compareFn(_: void, pc: usize, mid_item: FrameDescriptionEntry) math.Order {
                    if (pc < mid_item.pc_begin) return .lt;

                    const range_end = mid_item.pc_begin + mid_item.pc_range;
                    if (pc < range_end) return .eq;

                    return .gt;
                }
            }.compareFn);

            fde = if (index) |i| di.fde_list.items[i] else return error.MissingFDE;
            cie = di.cie_map.get(fde.cie_length_offset) orelse return error.MissingCIE;
        }

        var expression_context: expressions.ExpressionContext = .{
            .format = cie.format,
            .isValidMemory = context.isValidMemory,
            .compile_unit = di.findCompileUnit(fde.pc_begin) catch null,
            .thread_context = context.thread_context,
            .reg_context = context.reg_context,
            .cfa = context.cfa,
        };

        context.vm.reset();
        context.reg_context.eh_frame = cie.version != 4;
        context.reg_context.is_macho = di.is_macho;

        const row = try context.vm.runToNative(context.allocator, context.pc, cie, fde);
        context.cfa = switch (row.cfa.rule) {
            .val_offset => |offset| blk: {
                const register = row.cfa.register orelse return error.InvalidCFARule;
                const value = mem.readInt(usize, (try abi.regBytes(context.thread_context, register, context.reg_context))[0..@sizeOf(usize)], native_endian);
                break :blk try call_frame.applyOffset(value, offset);
            },
            .expression => |expression| blk: {
                context.stack_machine.reset();
                const value = try context.stack_machine.run(
                    expression,
                    context.allocator,
                    expression_context,
                    context.cfa,
                );

                if (value) |v| {
                    if (v != .generic) return error.InvalidExpressionValue;
                    break :blk v.generic;
                } else return error.NoExpressionValue;
            },
            else => return error.InvalidCFARule,
        };

        if (!context.isValidMemory(context.cfa.?)) return error.InvalidCFA;
        expression_context.cfa = context.cfa;

        // Buffering the modifications is done because copying the thread context is not portable,
        // some implementations (ie. darwin) use internal pointers to the mcontext.
        var arena = std.heap.ArenaAllocator.init(context.allocator);
        defer arena.deinit();
        const update_allocator = arena.allocator();

        const RegisterUpdate = struct {
            // Backed by thread_context
            dest: []u8,
            // Backed by arena
            src: []const u8,
            prev: ?*@This(),
        };

        var update_tail: ?*RegisterUpdate = null;
        var has_return_address = true;
        for (context.vm.rowColumns(row)) |column| {
            if (column.register) |register| {
                if (register == cie.return_address_register) {
                    has_return_address = column.rule != .undefined;
                }

                const dest = try abi.regBytes(context.thread_context, register, context.reg_context);
                const src = try update_allocator.alloc(u8, dest.len);

                const prev = update_tail;
                update_tail = try update_allocator.create(RegisterUpdate);
                update_tail.?.* = .{
                    .dest = dest,
                    .src = src,
                    .prev = prev,
                };

                try column.resolveValue(
                    context,
                    expression_context,
                    src,
                );
            }
        }

        // On all implemented architectures, the CFA is defined as being the previous frame's SP
        (try abi.regValueNative(usize, context.thread_context, abi.spRegNum(context.reg_context), context.reg_context)).* = context.cfa.?;

        while (update_tail) |tail| {
            @memcpy(tail.dest, tail.src);
            update_tail = tail.prev;
        }

        if (has_return_address) {
            context.pc = abi.stripInstructionPtrAuthCode(mem.readInt(usize, (try abi.regBytes(
                context.thread_context,
                cie.return_address_register,
                context.reg_context,
            ))[0..@sizeOf(usize)], native_endian));
        } else {
            context.pc = 0;
        }

        (try abi.regValueNative(usize, context.thread_context, abi.ipRegNum(), context.reg_context)).* = context.pc;

        // The call instruction will have pushed the address of the instruction that follows the call as the return address.
        // This next instruction may be past the end of the function if the caller was `noreturn` (ie. the last instruction in
        // the function was the call). If we were to look up an FDE entry using the return address directly, it could end up
        // either not finding an FDE at all, or using the next FDE in the program, producing incorrect results. To prevent this,
        // we subtract one so that the next lookup is guaranteed to land inside the
        //
        // The exception to this rule is signal frames, where we return execution would be returned to the instruction
        // that triggered the handler.
        const return_address = context.pc;
        if (context.pc > 0 and !cie.isSignalFrame()) context.pc -= 1;

        return return_address;
    }
};

/// Returns the DWARF register number for an x86_64 register number found in compact unwind info
fn compactUnwindToDwarfRegNumber(unwind_reg_number: u3) !u8 {
    return switch (unwind_reg_number) {
        1 => 3, // RBX
        2 => 12, // R12
        3 => 13, // R13
        4 => 14, // R14
        5 => 15, // R15
        6 => 6, // RBP
        else => error.InvalidUnwindRegisterNumber,
    };
}

const macho = std.macho;

/// Unwind a frame using MachO compact unwind info (from __unwind_info).
/// If the compact encoding can't encode a way to unwind a frame, it will
/// defer unwinding to DWARF, in which case `.eh_frame` will be used if available.
pub fn unwindFrameMachO(context: *UnwindContext, unwind_info: []const u8, eh_frame: ?[]const u8, module_base_address: usize) !usize {
    const header = mem.bytesAsValue(
        macho.unwind_info_section_header,
        unwind_info[0..@sizeOf(macho.unwind_info_section_header)],
    );
    const indices = mem.bytesAsSlice(
        macho.unwind_info_section_header_index_entry,
        unwind_info[header.indexSectionOffset..][0 .. header.indexCount * @sizeOf(macho.unwind_info_section_header_index_entry)],
    );
    if (indices.len == 0) return error.MissingUnwindInfo;

    const mapped_pc = context.pc - module_base_address;
    const second_level_index = blk: {
        var left: usize = 0;
        var len: usize = indices.len;

        while (len > 1) {
            const mid = left + len / 2;
            const offset = indices[mid].functionOffset;
            if (mapped_pc < offset) {
                len /= 2;
            } else {
                left = mid;
                if (mapped_pc == offset) break;
                len -= len / 2;
            }
        }

        // Last index is a sentinel containing the highest address as its functionOffset
        if (indices[left].secondLevelPagesSectionOffset == 0) return error.MissingUnwindInfo;
        break :blk &indices[left];
    };

    const common_encodings = mem.bytesAsSlice(
        macho.compact_unwind_encoding_t,
        unwind_info[header.commonEncodingsArraySectionOffset..][0 .. header.commonEncodingsArrayCount * @sizeOf(macho.compact_unwind_encoding_t)],
    );

    const start_offset = second_level_index.secondLevelPagesSectionOffset;
    const kind = mem.bytesAsValue(
        macho.UNWIND_SECOND_LEVEL,
        unwind_info[start_offset..][0..@sizeOf(macho.UNWIND_SECOND_LEVEL)],
    );

    const entry: struct {
        function_offset: usize,
        raw_encoding: u32,
    } = switch (kind.*) {
        .REGULAR => blk: {
            const page_header = mem.bytesAsValue(
                macho.unwind_info_regular_second_level_page_header,
                unwind_info[start_offset..][0..@sizeOf(macho.unwind_info_regular_second_level_page_header)],
            );

            const entries = mem.bytesAsSlice(
                macho.unwind_info_regular_second_level_entry,
                unwind_info[start_offset + page_header.entryPageOffset ..][0 .. page_header.entryCount * @sizeOf(macho.unwind_info_regular_second_level_entry)],
            );
            if (entries.len == 0) return error.InvalidUnwindInfo;

            var left: usize = 0;
            var len: usize = entries.len;
            while (len > 1) {
                const mid = left + len / 2;
                const offset = entries[mid].functionOffset;
                if (mapped_pc < offset) {
                    len /= 2;
                } else {
                    left = mid;
                    if (mapped_pc == offset) break;
                    len -= len / 2;
                }
            }

            break :blk .{
                .function_offset = entries[left].functionOffset,
                .raw_encoding = entries[left].encoding,
            };
        },
        .COMPRESSED => blk: {
            const page_header = mem.bytesAsValue(
                macho.unwind_info_compressed_second_level_page_header,
                unwind_info[start_offset..][0..@sizeOf(macho.unwind_info_compressed_second_level_page_header)],
            );

            const entries = mem.bytesAsSlice(
                macho.UnwindInfoCompressedEntry,
                unwind_info[start_offset + page_header.entryPageOffset ..][0 .. page_header.entryCount * @sizeOf(macho.UnwindInfoCompressedEntry)],
            );
            if (entries.len == 0) return error.InvalidUnwindInfo;

            var left: usize = 0;
            var len: usize = entries.len;
            while (len > 1) {
                const mid = left + len / 2;
                const offset = second_level_index.functionOffset + entries[mid].funcOffset;
                if (mapped_pc < offset) {
                    len /= 2;
                } else {
                    left = mid;
                    if (mapped_pc == offset) break;
                    len -= len / 2;
                }
            }

            const entry = entries[left];
            const function_offset = second_level_index.functionOffset + entry.funcOffset;
            if (entry.encodingIndex < header.commonEncodingsArrayCount) {
                if (entry.encodingIndex >= common_encodings.len) return error.InvalidUnwindInfo;
                break :blk .{
                    .function_offset = function_offset,
                    .raw_encoding = common_encodings[entry.encodingIndex],
                };
            } else {
                const local_index = try math.sub(
                    u8,
                    entry.encodingIndex,
                    math.cast(u8, header.commonEncodingsArrayCount) orelse return error.InvalidUnwindInfo,
                );
                const local_encodings = mem.bytesAsSlice(
                    macho.compact_unwind_encoding_t,
                    unwind_info[start_offset + page_header.encodingsPageOffset ..][0 .. page_header.encodingsCount * @sizeOf(macho.compact_unwind_encoding_t)],
                );
                if (local_index >= local_encodings.len) return error.InvalidUnwindInfo;
                break :blk .{
                    .function_offset = function_offset,
                    .raw_encoding = local_encodings[local_index],
                };
            }
        },
        else => return error.InvalidUnwindInfo,
    };

    if (entry.raw_encoding == 0) return error.NoUnwindInfo;
    const reg_context = abi.RegisterContext{
        .eh_frame = false,
        .is_macho = true,
    };

    const encoding: macho.CompactUnwindEncoding = @bitCast(entry.raw_encoding);
    const new_ip = switch (builtin.cpu.arch) {
        .x86_64 => switch (encoding.mode.x86_64) {
            .OLD => return error.UnimplementedUnwindEncoding,
            .RBP_FRAME => blk: {
                const regs: [5]u3 = .{
                    encoding.value.x86_64.frame.reg0,
                    encoding.value.x86_64.frame.reg1,
                    encoding.value.x86_64.frame.reg2,
                    encoding.value.x86_64.frame.reg3,
                    encoding.value.x86_64.frame.reg4,
                };

                const frame_offset = encoding.value.x86_64.frame.frame_offset * @sizeOf(usize);
                var max_reg: usize = 0;
                inline for (regs, 0..) |reg, i| {
                    if (reg > 0) max_reg = i;
                }

                const fp = (try abi.regValueNative(usize, context.thread_context, abi.fpRegNum(reg_context), reg_context)).*;
                const new_sp = fp + 2 * @sizeOf(usize);

                // Verify the stack range we're about to read register values from
                if (!context.isValidMemory(new_sp) or !context.isValidMemory(fp - frame_offset + max_reg * @sizeOf(usize))) return error.InvalidUnwindInfo;

                const ip_ptr = fp + @sizeOf(usize);
                const new_ip = @as(*const usize, @ptrFromInt(ip_ptr)).*;
                const new_fp = @as(*const usize, @ptrFromInt(fp)).*;

                (try abi.regValueNative(usize, context.thread_context, abi.fpRegNum(reg_context), reg_context)).* = new_fp;
                (try abi.regValueNative(usize, context.thread_context, abi.spRegNum(reg_context), reg_context)).* = new_sp;
                (try abi.regValueNative(usize, context.thread_context, abi.ipRegNum(), reg_context)).* = new_ip;

                for (regs, 0..) |reg, i| {
                    if (reg == 0) continue;
                    const addr = fp - frame_offset + i * @sizeOf(usize);
                    const reg_number = try compactUnwindToDwarfRegNumber(reg);
                    (try abi.regValueNative(usize, context.thread_context, reg_number, reg_context)).* = @as(*const usize, @ptrFromInt(addr)).*;
                }

                break :blk new_ip;
            },
            .STACK_IMMD,
            .STACK_IND,
            => blk: {
                const sp = (try abi.regValueNative(usize, context.thread_context, abi.spRegNum(reg_context), reg_context)).*;
                const stack_size = if (encoding.mode.x86_64 == .STACK_IMMD)
                    @as(usize, encoding.value.x86_64.frameless.stack.direct.stack_size) * @sizeOf(usize)
                else stack_size: {
                    // In .STACK_IND, the stack size is inferred from the subq instruction at the beginning of the function.
                    const sub_offset_addr =
                        module_base_address +
                        entry.function_offset +
                        encoding.value.x86_64.frameless.stack.indirect.sub_offset;
                    if (!context.isValidMemory(sub_offset_addr)) return error.InvalidUnwindInfo;

                    // `sub_offset_addr` points to the offset of the literal within the instruction
                    const sub_operand = @as(*align(1) const u32, @ptrFromInt(sub_offset_addr)).*;
                    break :stack_size sub_operand + @sizeOf(usize) * @as(usize, encoding.value.x86_64.frameless.stack.indirect.stack_adjust);
                };

                // Decode the Lehmer-coded sequence of registers.
                // For a description of the encoding see lib/libc/include/any-macos.13-any/mach-o/compact_unwind_encoding.h

                // Decode the variable-based permutation number into its digits. Each digit represents
                // an index into the list of register numbers that weren't yet used in the sequence at
                // the time the digit was added.
                const reg_count = encoding.value.x86_64.frameless.stack_reg_count;
                const ip_ptr = if (reg_count > 0) reg_blk: {
                    var digits: [6]u3 = undefined;
                    var accumulator: usize = encoding.value.x86_64.frameless.stack_reg_permutation;
                    var base: usize = 2;
                    for (0..reg_count) |i| {
                        const div = accumulator / base;
                        digits[digits.len - 1 - i] = @intCast(accumulator - base * div);
                        accumulator = div;
                        base += 1;
                    }

                    const reg_numbers = [_]u3{ 1, 2, 3, 4, 5, 6 };
                    var registers: [reg_numbers.len]u3 = undefined;
                    var used_indices = [_]bool{false} ** reg_numbers.len;
                    for (digits[digits.len - reg_count ..], 0..) |target_unused_index, i| {
                        var unused_count: u8 = 0;
                        const unused_index = for (used_indices, 0..) |used, index| {
                            if (!used) {
                                if (target_unused_index == unused_count) break index;
                                unused_count += 1;
                            }
                        } else unreachable;

                        registers[i] = reg_numbers[unused_index];
                        used_indices[unused_index] = true;
                    }

                    var reg_addr = sp + stack_size - @sizeOf(usize) * @as(usize, reg_count + 1);
                    if (!context.isValidMemory(reg_addr)) return error.InvalidUnwindInfo;
                    for (0..reg_count) |i| {
                        const reg_number = try compactUnwindToDwarfRegNumber(registers[i]);
                        (try abi.regValueNative(usize, context.thread_context, reg_number, reg_context)).* = @as(*const usize, @ptrFromInt(reg_addr)).*;
                        reg_addr += @sizeOf(usize);
                    }

                    break :reg_blk reg_addr;
                } else sp + stack_size - @sizeOf(usize);

                const new_ip = @as(*const usize, @ptrFromInt(ip_ptr)).*;
                const new_sp = ip_ptr + @sizeOf(usize);
                if (!context.isValidMemory(new_sp)) return error.InvalidUnwindInfo;

                (try abi.regValueNative(usize, context.thread_context, abi.spRegNum(reg_context), reg_context)).* = new_sp;
                (try abi.regValueNative(usize, context.thread_context, abi.ipRegNum(), reg_context)).* = new_ip;

                break :blk new_ip;
            },
            .DWARF => {
                return unwindFrameMachODwarf(context, eh_frame orelse return error.MissingEhFrame, @intCast(encoding.value.x86_64.dwarf));
            },
        },
        .aarch64 => switch (encoding.mode.arm64) {
            .OLD => return error.UnimplementedUnwindEncoding,
            .FRAMELESS => blk: {
                const sp = (try abi.regValueNative(usize, context.thread_context, abi.spRegNum(reg_context), reg_context)).*;
                const new_sp = sp + encoding.value.arm64.frameless.stack_size * 16;
                const new_ip = (try abi.regValueNative(usize, context.thread_context, 30, reg_context)).*;
                if (!context.isValidMemory(new_sp)) return error.InvalidUnwindInfo;
                (try abi.regValueNative(usize, context.thread_context, abi.spRegNum(reg_context), reg_context)).* = new_sp;
                break :blk new_ip;
            },
            .DWARF => {
                return unwindFrameMachODwarf(context, eh_frame orelse return error.MissingEhFrame, @intCast(encoding.value.arm64.dwarf));
            },
            .FRAME => blk: {
                const fp = (try abi.regValueNative(usize, context.thread_context, abi.fpRegNum(reg_context), reg_context)).*;
                const new_sp = fp + 16;
                const ip_ptr = fp + @sizeOf(usize);

                const num_restored_pairs: usize =
                    @popCount(@as(u5, @bitCast(encoding.value.arm64.frame.x_reg_pairs))) +
                    @popCount(@as(u4, @bitCast(encoding.value.arm64.frame.d_reg_pairs)));
                const min_reg_addr = fp - num_restored_pairs * 2 * @sizeOf(usize);

                if (!context.isValidMemory(new_sp) or !context.isValidMemory(min_reg_addr)) return error.InvalidUnwindInfo;

                var reg_addr = fp - @sizeOf(usize);
                inline for (@typeInfo(@TypeOf(encoding.value.arm64.frame.x_reg_pairs)).Struct.fields, 0..) |field, i| {
                    if (@field(encoding.value.arm64.frame.x_reg_pairs, field.name) != 0) {
                        (try abi.regValueNative(usize, context.thread_context, 19 + i, reg_context)).* = @as(*const usize, @ptrFromInt(reg_addr)).*;
                        reg_addr += @sizeOf(usize);
                        (try abi.regValueNative(usize, context.thread_context, 20 + i, reg_context)).* = @as(*const usize, @ptrFromInt(reg_addr)).*;
                        reg_addr += @sizeOf(usize);
                    }
                }

                inline for (@typeInfo(@TypeOf(encoding.value.arm64.frame.d_reg_pairs)).Struct.fields, 0..) |field, i| {
                    if (@field(encoding.value.arm64.frame.d_reg_pairs, field.name) != 0) {
                        // Only the lower half of the 128-bit V registers are restored during unwinding
                        @memcpy(
                            try abi.regBytes(context.thread_context, 64 + 8 + i, context.reg_context),
                            mem.asBytes(@as(*const usize, @ptrFromInt(reg_addr))),
                        );
                        reg_addr += @sizeOf(usize);
                        @memcpy(
                            try abi.regBytes(context.thread_context, 64 + 9 + i, context.reg_context),
                            mem.asBytes(@as(*const usize, @ptrFromInt(reg_addr))),
                        );
                        reg_addr += @sizeOf(usize);
                    }
                }

                const new_ip = @as(*const usize, @ptrFromInt(ip_ptr)).*;
                const new_fp = @as(*const usize, @ptrFromInt(fp)).*;

                (try abi.regValueNative(usize, context.thread_context, abi.fpRegNum(reg_context), reg_context)).* = new_fp;
                (try abi.regValueNative(usize, context.thread_context, abi.ipRegNum(), reg_context)).* = new_ip;

                break :blk new_ip;
            },
        },
        else => return error.UnimplementedArch,
    };

    context.pc = abi.stripInstructionPtrAuthCode(new_ip);
    if (context.pc > 0) context.pc -= 1;
    return new_ip;
}

fn unwindFrameMachODwarf(context: *UnwindContext, eh_frame: []const u8, fde_offset: usize) !usize {
    var di = DwarfInfo{
        .endian = native_endian,
        .is_macho = true,
    };
    defer di.deinit(context.allocator);

    di.sections[@intFromEnum(DwarfSection.eh_frame)] = .{
        .data = eh_frame,
        .owned = false,
    };

    return di.unwindFrame(context, fde_offset);
}

pub const UnwindContext = struct {
    allocator: mem.Allocator,
    cfa: ?usize,
    pc: usize,
    thread_context: *debug.ThreadContext,
    reg_context: abi.RegisterContext,
    isValidMemory: *const fn (address: usize) bool,
    vm: call_frame.VirtualMachine,
    stack_machine: expressions.StackMachine(.{ .call_frame_context = true }),

    pub fn init(allocator: mem.Allocator, thread_context: *const debug.ThreadContext, isValidMemory: *const fn (address: usize) bool) !UnwindContext {
        const pc = abi.stripInstructionPtrAuthCode((try abi.regValueNative(usize, thread_context, abi.ipRegNum(), null)).*);

        const context_copy = try allocator.create(debug.ThreadContext);
        debug.copyContext(thread_context, context_copy);

        return .{
            .allocator = allocator,
            .cfa = null,
            .pc = pc,
            .thread_context = context_copy,
            .reg_context = undefined,
            .isValidMemory = isValidMemory,
            .vm = .{},
            .stack_machine = .{},
        };
    }

    pub fn deinit(self: *UnwindContext) void {
        self.vm.deinit(self.allocator);
        self.stack_machine.deinit(self.allocator);
        self.allocator.destroy(self.thread_context);
        self.* = undefined;
    }

    pub fn getFp(self: *const UnwindContext) !usize {
        return (try abi.regValueNative(usize, self.thread_context, abi.fpRegNum(self.reg_context), self.reg_context)).*;
    }
};

/// Initialize DWARF info. The caller has the responsibility to initialize most
/// the DwarfInfo fields before calling. `binary_mem` is the raw bytes of the
/// main binary file (not the secondary debug info file).
pub fn openDwarfDebugInfo(di: *DwarfInfo, allocator: mem.Allocator) !void {
    try di.scanAllFunctions(allocator);
    try di.scanAllCompileUnits(allocator);
}

/// This function is to make it handy to comment out the return and make it
/// into a crash when working on this file.
fn badDwarf() error{InvalidDebugInfo} {
    //if (true) @panic("badDwarf"); // can be handy to uncomment when working on this file
    return error.InvalidDebugInfo;
}

fn missingDwarf() error{MissingDebugInfo} {
    //if (true) @panic("missingDwarf"); // can be handy to uncomment when working on this file
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
    // debug info
    follow_indirect: bool,

    // These relative addressing modes are only used in specific cases, and
    // might not be available / required in all parsing contexts
    data_rel_base: ?u64 = null,
    text_rel_base: ?u64 = null,
    function_rel_base: ?u64 = null,
};
fn readEhPointer(fbr: *FixedBufferReader, enc: u8, addr_size_bytes: u8, ctx: EhPointerContext) !?u64 {
    if (enc == EH.PE.omit) return null;

    const value: union(enum) {
        signed: i64,
        unsigned: u64,
    } = switch (enc & EH.PE.type_mask) {
        EH.PE.absptr => .{
            .unsigned = switch (addr_size_bytes) {
                2 => try fbr.readInt(u16),
                4 => try fbr.readInt(u32),
                8 => try fbr.readInt(u64),
                else => return error.InvalidAddrSize,
            },
        },
        EH.PE.uleb128 => .{ .unsigned = try fbr.readUleb128(u64) },
        EH.PE.udata2 => .{ .unsigned = try fbr.readInt(u16) },
        EH.PE.udata4 => .{ .unsigned = try fbr.readInt(u32) },
        EH.PE.udata8 => .{ .unsigned = try fbr.readInt(u64) },
        EH.PE.sleb128 => .{ .signed = try fbr.readIleb128(i64) },
        EH.PE.sdata2 => .{ .signed = try fbr.readInt(i16) },
        EH.PE.sdata4 => .{ .signed = try fbr.readInt(i32) },
        EH.PE.sdata8 => .{ .signed = try fbr.readInt(i64) },
        else => return badDwarf(),
    };

    const base = switch (enc & EH.PE.rel_mask) {
        EH.PE.pcrel => ctx.pc_rel_base,
        EH.PE.textrel => ctx.text_rel_base orelse return error.PointerBaseNotSpecified,
        EH.PE.datarel => ctx.data_rel_base orelse return error.PointerBaseNotSpecified,
        EH.PE.funcrel => ctx.function_rel_base orelse return error.PointerBaseNotSpecified,
        else => null,
    };

    const ptr: u64 = if (base) |b| switch (value) {
        .signed => |s| @intCast(try math.add(i64, s, @as(i64, @intCast(b)))),
        // absptr can actually contain signed values in some cases (aarch64 MachO)
        .unsigned => |u| u +% b,
    } else switch (value) {
        .signed => |s| @as(u64, @intCast(s)),
        .unsigned => |u| u,
    };

    if ((enc & EH.PE.indirect) > 0 and ctx.follow_indirect) {
        if (@sizeOf(usize) != addr_size_bytes) {
            // See the documentation for `follow_indirect`
            return error.NonNativeIndirection;
        }

        const native_ptr = math.cast(usize, ptr) orelse return error.PointerOverflow;
        return switch (addr_size_bytes) {
            2, 4, 8 => return @as(*const usize, @ptrFromInt(native_ptr)).*,
            else => return error.UnsupportedAddrSize,
        };
    } else {
        return ptr;
    }
}

/// This represents the decoded .eh_frame_hdr header
pub const ExceptionFrameHeader = struct {
    eh_frame_ptr: usize,
    table_enc: u8,
    fde_count: usize,
    entries: []const u8,

    pub fn entrySize(table_enc: u8) !u8 {
        return switch (table_enc & EH.PE.type_mask) {
            EH.PE.udata2,
            EH.PE.sdata2,
            => 4,
            EH.PE.udata4,
            EH.PE.sdata4,
            => 8,
            EH.PE.udata8,
            EH.PE.sdata8,
            => 16,
            // This is a binary search table, so all entries must be the same length
            else => return badDwarf(),
        };
    }

    fn isValidPtr(
        self: ExceptionFrameHeader,
        ptr: usize,
        isValidMemory: *const fn (address: usize) bool,
        eh_frame_len: ?usize,
    ) bool {
        if (eh_frame_len) |len| {
            return ptr >= self.eh_frame_ptr and ptr < self.eh_frame_ptr + len;
        } else {
            return isValidMemory(ptr);
        }
    }

    /// Find an entry by binary searching the eh_frame_hdr section.
    ///
    /// Since the length of the eh_frame section (`eh_frame_len`) may not be known by the caller,
    /// `isValidMemory` will be called before accessing any memory referenced by
    /// the header entries. If `eh_frame_len` is provided, then these checks can be skipped.
    pub fn findEntry(
        self: ExceptionFrameHeader,
        isValidMemory: *const fn (address: usize) bool,
        eh_frame_len: ?usize,
        eh_frame_hdr_ptr: usize,
        pc: usize,
        cie: *CommonInformationEntry,
        fde: *FrameDescriptionEntry,
    ) !void {
        const entry_size = try entrySize(self.table_enc);

        var left: usize = 0;
        var len: usize = self.fde_count;

        var fbr: FixedBufferReader = .{ .buf = self.entries, .endian = native_endian };

        while (len > 1) {
            const mid = left + len / 2;

            fbr.pos = mid * entry_size;
            const pc_begin = try readEhPointer(&fbr, self.table_enc, @sizeOf(usize), .{
                .pc_rel_base = @intFromPtr(&self.entries[fbr.pos]),
                .follow_indirect = true,
                .data_rel_base = eh_frame_hdr_ptr,
            }) orelse return badDwarf();

            if (pc < pc_begin) {
                len /= 2;
            } else {
                left = mid;
                if (pc == pc_begin) break;
                len -= len / 2;
            }
        }

        if (len == 0) return badDwarf();
        fbr.pos = left * entry_size;

        // Read past the pc_begin field of the entry
        _ = try readEhPointer(&fbr, self.table_enc, @sizeOf(usize), .{
            .pc_rel_base = @intFromPtr(&self.entries[fbr.pos]),
            .follow_indirect = true,
            .data_rel_base = eh_frame_hdr_ptr,
        }) orelse return badDwarf();

        const fde_ptr = math.cast(usize, try readEhPointer(&fbr, self.table_enc, @sizeOf(usize), .{
            .pc_rel_base = @intFromPtr(&self.entries[fbr.pos]),
            .follow_indirect = true,
            .data_rel_base = eh_frame_hdr_ptr,
        }) orelse return badDwarf()) orelse return badDwarf();

        // Verify the length fields of the FDE header are readable
        if (!self.isValidPtr(fde_ptr, isValidMemory, eh_frame_len) or fde_ptr < self.eh_frame_ptr) return badDwarf();

        var fde_entry_header_len: usize = 4;
        if (!self.isValidPtr(fde_ptr + 3, isValidMemory, eh_frame_len)) return badDwarf();
        if (self.isValidPtr(fde_ptr + 11, isValidMemory, eh_frame_len)) fde_entry_header_len = 12;

        // Even if eh_frame_len is not specified, all ranges accssed are checked by isValidPtr
        const eh_frame = @as([*]const u8, @ptrFromInt(self.eh_frame_ptr))[0 .. eh_frame_len orelse math.maxInt(u32)];

        const fde_offset = fde_ptr - self.eh_frame_ptr;
        var eh_frame_fbr: FixedBufferReader = .{
            .buf = eh_frame,
            .pos = fde_offset,
            .endian = native_endian,
        };

        const fde_entry_header = try EntryHeader.read(&eh_frame_fbr, .eh_frame);
        if (!self.isValidPtr(@intFromPtr(&fde_entry_header.entry_bytes[fde_entry_header.entry_bytes.len - 1]), isValidMemory, eh_frame_len)) return badDwarf();
        if (fde_entry_header.type != .fde) return badDwarf();

        // CIEs always come before FDEs (the offset is a subtraction), so we can assume this memory is readable
        const cie_offset = fde_entry_header.type.fde;
        try eh_frame_fbr.seekTo(cie_offset);
        const cie_entry_header = try EntryHeader.read(&eh_frame_fbr, .eh_frame);
        if (!self.isValidPtr(@intFromPtr(&cie_entry_header.entry_bytes[cie_entry_header.entry_bytes.len - 1]), isValidMemory, eh_frame_len)) return badDwarf();
        if (cie_entry_header.type != .cie) return badDwarf();

        cie.* = try CommonInformationEntry.parse(
            cie_entry_header.entry_bytes,
            0,
            true,
            cie_entry_header.format,
            .eh_frame,
            cie_entry_header.length_offset,
            @sizeOf(usize),
            native_endian,
        );

        fde.* = try FrameDescriptionEntry.parse(
            fde_entry_header.entry_bytes,
            0,
            true,
            cie.*,
            @sizeOf(usize),
            native_endian,
        );
    }
};

pub const EntryHeader = struct {
    /// Offset of the length field in the backing buffer
    length_offset: usize,
    format: Format,
    type: union(enum) {
        cie,
        /// Value is the offset of the corresponding CIE
        fde: u64,
        terminator,
    },
    /// The entry's contents, not including the ID field
    entry_bytes: []const u8,

    /// The length of the entry including the ID field, but not the length field itself
    pub fn entryLength(self: EntryHeader) usize {
        return self.entry_bytes.len + @as(u8, if (self.format == .@"64") 8 else 4);
    }

    /// Reads a header for either an FDE or a CIE, then advances the fbr to the position after the trailing structure.
    /// `fbr` must be a FixedBufferReader backed by either the .eh_frame or .debug_frame sections.
    pub fn read(fbr: *FixedBufferReader, dwarf_section: DwarfSection) !EntryHeader {
        assert(dwarf_section == .eh_frame or dwarf_section == .debug_frame);

        const length_offset = fbr.pos;
        const unit_header = try readUnitHeader(fbr);
        const unit_length = math.cast(usize, unit_header.unit_length) orelse return badDwarf();
        if (unit_length == 0) return .{
            .length_offset = length_offset,
            .format = unit_header.format,
            .type = .terminator,
            .entry_bytes = &.{},
        };
        const start_offset = fbr.pos;
        const end_offset = start_offset + unit_length;
        defer fbr.pos = end_offset;

        const id = try fbr.readAddress(unit_header.format);
        const entry_bytes = fbr.buf[fbr.pos..end_offset];
        const cie_id: u64 = switch (dwarf_section) {
            .eh_frame => CommonInformationEntry.eh_id,
            .debug_frame => switch (unit_header.format) {
                .@"32" => CommonInformationEntry.dwarf32_id,
                .@"64" => CommonInformationEntry.dwarf64_id,
            },
            else => unreachable,
        };

        return .{
            .length_offset = length_offset,
            .format = unit_header.format,
            .type = if (id == cie_id) .cie else .{ .fde = switch (dwarf_section) {
                .eh_frame => try math.sub(u64, start_offset, id),
                .debug_frame => id,
                else => unreachable,
            } },
            .entry_bytes = entry_bytes,
        };
    }
};

pub const CommonInformationEntry = struct {
    // Used in .eh_frame
    pub const eh_id = 0;

    // Used in .debug_frame (DWARF32)
    pub const dwarf32_id = math.maxInt(u32);

    // Used in .debug_frame (DWARF64)
    pub const dwarf64_id = math.maxInt(u64);

    // Offset of the length field of this entry in the eh_frame section.
    // This is the key that FDEs use to reference CIEs.
    length_offset: u64,
    version: u8,
    address_size: u8,
    format: Format,

    // Only present in version 4
    segment_selector_size: ?u8,

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

    /// This function expects to read the CIE starting with the version field.
    /// The returned struct references memory backed by cie_bytes.
    ///
    /// See the FrameDescriptionEntry.parse documentation for the description
    /// of `pc_rel_offset` and `is_runtime`.
    ///
    /// `length_offset` specifies the offset of this CIE's length field in the
    /// .eh_frame / .debug_frame section.
    pub fn parse(
        cie_bytes: []const u8,
        pc_rel_offset: i64,
        is_runtime: bool,
        format: Format,
        dwarf_section: DwarfSection,
        length_offset: u64,
        addr_size_bytes: u8,
        endian: std.builtin.Endian,
    ) !CommonInformationEntry {
        if (addr_size_bytes > 8) return error.UnsupportedAddrSize;

        var fbr: FixedBufferReader = .{ .buf = cie_bytes, .endian = endian };

        const version = try fbr.readByte();
        switch (dwarf_section) {
            .eh_frame => if (version != 1 and version != 3) return error.UnsupportedDwarfVersion,
            .debug_frame => if (version != 4) return error.UnsupportedDwarfVersion,
            else => return error.UnsupportedDwarfSection,
        }

        var has_eh_data = false;
        var has_aug_data = false;

        var aug_str_len: usize = 0;
        const aug_str_start = fbr.pos;
        var aug_byte = try fbr.readByte();
        while (aug_byte != 0) : (aug_byte = try fbr.readByte()) {
            switch (aug_byte) {
                'z' => {
                    if (aug_str_len != 0) return badDwarf();
                    has_aug_data = true;
                },
                'e' => {
                    if (has_aug_data or aug_str_len != 0) return badDwarf();
                    if (try fbr.readByte() != 'h') return badDwarf();
                    has_eh_data = true;
                },
                else => if (has_eh_data) return badDwarf(),
            }

            aug_str_len += 1;
        }

        if (has_eh_data) {
            // legacy data created by older versions of gcc - unsupported here
            for (0..addr_size_bytes) |_| _ = try fbr.readByte();
        }

        const address_size = if (version == 4) try fbr.readByte() else addr_size_bytes;
        const segment_selector_size = if (version == 4) try fbr.readByte() else null;

        const code_alignment_factor = try fbr.readUleb128(u32);
        const data_alignment_factor = try fbr.readIleb128(i32);
        const return_address_register = if (version == 1) try fbr.readByte() else try fbr.readUleb128(u8);

        var lsda_pointer_enc: u8 = EH.PE.omit;
        var personality_enc: ?u8 = null;
        var personality_routine_pointer: ?u64 = null;
        var fde_pointer_enc: u8 = EH.PE.absptr;

        var aug_data: []const u8 = &[_]u8{};
        const aug_str = if (has_aug_data) blk: {
            const aug_data_len = try fbr.readUleb128(usize);
            const aug_data_start = fbr.pos;
            aug_data = cie_bytes[aug_data_start..][0..aug_data_len];

            const aug_str = cie_bytes[aug_str_start..][0..aug_str_len];
            for (aug_str[1..]) |byte| {
                switch (byte) {
                    'L' => {
                        lsda_pointer_enc = try fbr.readByte();
                    },
                    'P' => {
                        personality_enc = try fbr.readByte();
                        personality_routine_pointer = try readEhPointer(&fbr, personality_enc.?, addr_size_bytes, .{
                            .pc_rel_base = try pcRelBase(@intFromPtr(&cie_bytes[fbr.pos]), pc_rel_offset),
                            .follow_indirect = is_runtime,
                        });
                    },
                    'R' => {
                        fde_pointer_enc = try fbr.readByte();
                    },
                    'S', 'B', 'G' => {},
                    else => return badDwarf(),
                }
            }

            // aug_data_len can include padding so the CIE ends on an address boundary
            fbr.pos = aug_data_start + aug_data_len;
            break :blk aug_str;
        } else &[_]u8{};

        const initial_instructions = cie_bytes[fbr.pos..];
        return .{
            .length_offset = length_offset,
            .version = version,
            .address_size = address_size,
            .format = format,
            .segment_selector_size = segment_selector_size,
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

    /// This function expects to read the FDE starting at the PC Begin field.
    /// The returned struct references memory backed by `fde_bytes`.
    ///
    /// `pc_rel_offset` specifies an offset to be applied to pc_rel_base values
    /// used when decoding pointers. This should be set to zero if fde_bytes is
    /// backed by the memory of a .eh_frame / .debug_frame section in the running executable.
    /// Otherwise, it should be the relative offset to translate addresses from
    /// where the section is currently stored in memory, to where it *would* be
    /// stored at runtime: section base addr - backing data base ptr.
    ///
    /// Similarly, `is_runtime` specifies this function is being called on a runtime
    /// section, and so indirect pointers can be followed.
    pub fn parse(
        fde_bytes: []const u8,
        pc_rel_offset: i64,
        is_runtime: bool,
        cie: CommonInformationEntry,
        addr_size_bytes: u8,
        endian: std.builtin.Endian,
    ) !FrameDescriptionEntry {
        if (addr_size_bytes > 8) return error.InvalidAddrSize;

        var fbr: FixedBufferReader = .{ .buf = fde_bytes, .endian = endian };

        const pc_begin = try readEhPointer(&fbr, cie.fde_pointer_enc, addr_size_bytes, .{
            .pc_rel_base = try pcRelBase(@intFromPtr(&fde_bytes[fbr.pos]), pc_rel_offset),
            .follow_indirect = is_runtime,
        }) orelse return badDwarf();

        const pc_range = try readEhPointer(&fbr, cie.fde_pointer_enc, addr_size_bytes, .{
            .pc_rel_base = 0,
            .follow_indirect = false,
        }) orelse return badDwarf();

        var aug_data: []const u8 = &[_]u8{};
        const lsda_pointer = if (cie.aug_str.len > 0) blk: {
            const aug_data_len = try fbr.readUleb128(usize);
            const aug_data_start = fbr.pos;
            aug_data = fde_bytes[aug_data_start..][0..aug_data_len];

            const lsda_pointer = if (cie.lsda_pointer_enc != EH.PE.omit)
                try readEhPointer(&fbr, cie.lsda_pointer_enc, addr_size_bytes, .{
                    .pc_rel_base = try pcRelBase(@intFromPtr(&fde_bytes[fbr.pos]), pc_rel_offset),
                    .follow_indirect = is_runtime,
                })
            else
                null;

            fbr.pos = aug_data_start + aug_data_len;
            break :blk lsda_pointer;
        } else null;

        const instructions = fde_bytes[fbr.pos..];
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

fn pcRelBase(field_ptr: usize, pc_rel_offset: i64) !usize {
    if (pc_rel_offset < 0) {
        return math.sub(usize, field_ptr, @as(usize, @intCast(-pc_rel_offset)));
    } else {
        return math.add(usize, field_ptr, @as(usize, @intCast(pc_rel_offset)));
    }
}

// Reading debug info needs to be fast, even when compiled in debug mode,
// so avoid using a `std.io.FixedBufferStream` which is too slow.
pub const FixedBufferReader = struct {
    buf: []const u8,
    pos: usize = 0,
    endian: std.builtin.Endian,

    pub const Error = error{ EndOfBuffer, Overflow };

    fn seekTo(fbr: *FixedBufferReader, pos: u64) Error!void {
        if (pos > fbr.buf.len) return error.EndOfBuffer;
        fbr.pos = @intCast(pos);
    }

    fn seekForward(fbr: *FixedBufferReader, amount: u64) Error!void {
        if (fbr.buf.len - fbr.pos < amount) return error.EndOfBuffer;
        fbr.pos += @intCast(amount);
    }

    pub inline fn readByte(fbr: *FixedBufferReader) Error!u8 {
        if (fbr.pos >= fbr.buf.len) return error.EndOfBuffer;
        defer fbr.pos += 1;
        return fbr.buf[fbr.pos];
    }

    fn readByteSigned(fbr: *FixedBufferReader) Error!i8 {
        return @bitCast(try fbr.readByte());
    }

    fn readInt(fbr: *FixedBufferReader, comptime T: type) Error!T {
        const size = @divExact(@typeInfo(T).Int.bits, 8);
        if (fbr.buf.len - fbr.pos < size) return error.EndOfBuffer;
        defer fbr.pos += size;
        return mem.readInt(T, fbr.buf[fbr.pos..][0..size], fbr.endian);
    }

    fn readUleb128(fbr: *FixedBufferReader, comptime T: type) Error!T {
        return std.leb.readULEB128(T, fbr);
    }

    fn readIleb128(fbr: *FixedBufferReader, comptime T: type) Error!T {
        return std.leb.readILEB128(T, fbr);
    }

    fn readAddress(fbr: *FixedBufferReader, format: Format) Error!u64 {
        return switch (format) {
            .@"32" => try fbr.readInt(u32),
            .@"64" => try fbr.readInt(u64),
        };
    }

    fn readBytes(fbr: *FixedBufferReader, len: usize) Error![]const u8 {
        if (fbr.buf.len - fbr.pos < len) return error.EndOfBuffer;
        defer fbr.pos += len;
        return fbr.buf[fbr.pos..][0..len];
    }

    fn readBytesTo(fbr: *FixedBufferReader, comptime sentinel: u8) Error![:sentinel]const u8 {
        const end = @call(.always_inline, mem.indexOfScalarPos, .{
            u8,
            fbr.buf,
            fbr.pos,
            sentinel,
        }) orelse return error.EndOfBuffer;
        defer fbr.pos = end + 1;
        return fbr.buf[fbr.pos..end :sentinel];
    }
};

test {
    std.testing.refAllDecls(@This());
}
