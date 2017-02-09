const mem = @import("mem.zig");
const io = @import("io.zig");
const os = @import("os.zig");
const elf = @import("elf.zig");
const DW = @import("dwarf.zig");
const List = @import("list.zig").List;

error MissingDebugInfo;
error InvalidDebugInfo;
error UnsupportedDebugInfo;

pub fn assert(ok: bool) {
    if (!ok) @unreachable()
}

var panicking = false;
/// This is the default panic implementation.
pub coldcc fn panic(message: []const u8) -> unreachable {
    // TODO
    // if (@atomicRmw(AtomicOp.XChg, &panicking, true, AtomicOrder.SeqCst)) { }
    if (panicking) {
        // Panicked during a panic.
        // TODO detect if a different thread caused the panic, because in that case
        // we would want to return here instead of calling abort, so that the thread
        // which first called panic can finish printing a stack trace.
        os.abort();
    } else {
        panicking = true;
    }

    %%io.stderr.printf("{}\n", message);
    %%printStackTrace();

    os.abort();
}

pub fn printStackTrace() -> %void {
    %return writeStackTrace(&io.stderr);
    %return io.stderr.flush();
}

pub fn writeStackTrace(out_stream: &io.OutStream) -> %void {
    switch (@compileVar("object_format")) {
        ObjectFormat.elf => {
            var stack_trace = ElfStackTrace {
                .self_exe_stream = undefined,
                .elf = undefined,
                .debug_info = undefined,
                .debug_abbrev = undefined,
                .debug_str = undefined,
                .abbrev_table_list = List(AbbrevTableHeader).init(&global_allocator),
                .compile_unit_list = List(CompileUnit).init(&global_allocator),
            };
            const st = &stack_trace;
            %return io.openSelfExe(&st.self_exe_stream);
            defer st.self_exe_stream.close() %% {};

            %return st.elf.openStream(&global_allocator, &st.self_exe_stream);
            defer st.elf.close();

            st.debug_info = (%return st.elf.findSection(".debug_info")) ?? return error.MissingDebugInfo;
            st.debug_abbrev = (%return st.elf.findSection(".debug_abbrev")) ?? return error.MissingDebugInfo;
            st.debug_str = (%return st.elf.findSection(".debug_str")) ?? return error.MissingDebugInfo;
            %return scanAllCompileUnits(st);

            %return out_stream.printf("(...work-in-progress stack unwinding code follows...)\n");

            var maybe_fp: ?&const u8 = @frameAddress();
            while (true) {
                const fp = maybe_fp ?? break;
                const return_address = *(&const usize)(usize(fp) + @sizeOf(usize));

                const compile_unit = findCompileUnit(st, return_address) ?? return error.MissingDebugInfo;
                const name = %return compile_unit.die.getAttrString(st, DW.AT_name);

                %return out_stream.printf("{}  -> {}\n", return_address, name);
                maybe_fp = *(&const ?&const u8)(fp);
            }
        },
        ObjectFormat.coff => {
            out_stream.write("(stack trace unavailable for COFF object format)\n");
        },
        ObjectFormat.macho => {
            %return out_stream.write("(stack trace unavailable for Mach-O object format)\n");
        },
        ObjectFormat.unknown => {
            out_stream.write("(stack trace unavailable for unknown object format)\n");
        },
    }
}

const ElfStackTrace = struct {
    self_exe_stream: io.InStream,
    elf: elf.Elf,
    debug_info: &elf.SectionHeader,
    debug_abbrev: &elf.SectionHeader,
    debug_str: &elf.SectionHeader,
    abbrev_table_list: List(AbbrevTableHeader),
    compile_unit_list: List(CompileUnit),
};

const CompileUnit = struct {
    is_64: bool,
    die: &Die,
    pc_start: u64,
    pc_end: u64,
};

const AbbrevTable = List(AbbrevTableEntry);

const AbbrevTableHeader = struct {
    // offset from .debug_abbrev
    offset: u64,
    table: AbbrevTable,
};

const AbbrevTableEntry = struct {
    has_children: bool,
    abbrev_code: u64,
    tag_id: u64,
    attrs: List(AbbrevAttr),
};

const AbbrevAttr = struct {
    attr_id: u64,
    form_id: u64,
};

const FormValue = enum {
    Address: u64,
    Block: []u8,
    Const: Constant,
    ExprLoc: []u8,
    Flag: bool,
    SecOffset: u64,
    Ref: []u8,
    RefAddr: u64,
    RefSig8: u64,
    String: []u8,
    StrPtr: u64,
};

const Constant = struct {
    payload: []u8,
    signed: bool,

    fn asUnsignedLe(self: &const Constant) -> %u64 {
        if (self.payload.len > @sizeOf(u64))
            return error.InvalidDebugInfo;
        if (self.signed)
            return error.InvalidDebugInfo;
        return mem.sliceAsInt(self.payload, false, u64);
    }
};

const Die = struct {
    tag_id: u64,
    has_children: bool,
    attrs: List(Attr),

    const Attr = struct {
        id: u64,
        value: FormValue,
    };

    fn getAttr(self: &const Die, id: u64) -> ?&const FormValue {
        for (self.attrs.toSlice()) |*attr| {
            if (attr.id == id)
                return &attr.value;
        }
        return null;
    }

    fn getAttrAddr(self: &const Die, id: u64) -> %u64 {
        const form_value = self.getAttr(id) ?? return error.InvalidDebugInfo;
        return switch (*form_value) {
            FormValue.Address => |value| value,
            else => error.InvalidDebugInfo,
        };
    }

    fn getAttrUnsignedLe(self: &const Die, id: u64) -> %u64 {
        const form_value = self.getAttr(id) ?? return error.InvalidDebugInfo;
        return switch (*form_value) {
            FormValue.Const => |value| value.asUnsignedLe(),
            else => error.InvalidDebugInfo,
        };
    }

    fn getAttrString(self: &const Die, st: &ElfStackTrace, id: u64) -> %[]u8 {
        const form_value = self.getAttr(id) ?? return error.InvalidDebugInfo;
        return switch (*form_value) {
            FormValue.String => |value| value,
            FormValue.StrPtr => |offset| getString(st, offset),
            else => error.InvalidDebugInfo,
        }
    }
};

fn readString(in_stream: &io.InStream) -> %[]u8 {
    var buf = List(u8).init(&global_allocator);
    while (true) {
        const byte = %return in_stream.readByte();
        if (byte == 0)
            break;
        %return buf.append(byte);
    }
    return buf.items;
}

fn getString(st: &ElfStackTrace, offset: u64) -> %[]u8 {
    const pos = st.debug_str.offset + offset;
    %return st.self_exe_stream.seekTo(pos);
    return readString(&st.self_exe_stream);
}

fn readAllocBytes(in_stream: &io.InStream, size: usize) -> %[]u8 {
    const buf = %return global_allocator.alloc(u8, size);
    %defer global_allocator.free(buf);
    %return in_stream.read(buf);
    return buf;
}

fn parseFormValueBlockLen(in_stream: &io.InStream, size: usize) -> %FormValue {
    const buf = %return readAllocBytes(in_stream, size);
    return FormValue.Block { buf };
}

fn parseFormValueBlock(in_stream: &io.InStream, size: usize) -> %FormValue {
    const block_len = %return in_stream.readVarInt(false, usize, size);
    return parseFormValueBlockLen(in_stream, block_len);
}

fn parseFormValueConstant(in_stream: &io.InStream, signed: bool, size: usize) -> %FormValue {
    FormValue.Const { Constant {
        .signed = signed,
        .payload = %return readAllocBytes(in_stream, size),
    }}
}

fn parseFormValueDwarfOffsetSize(in_stream: &io.InStream, is_64: bool) -> %u64 {
    return if (is_64) {
        %return in_stream.readIntLe(u64)
    } else {
        u64(%return in_stream.readIntLe(u32))
    };
}

fn parseFormValueTargetAddrSize(in_stream: &io.InStream) -> %u64 {
    return if (@sizeOf(usize) == 4) {
        u64(%return in_stream.readIntLe(u32))
    } else if (@sizeOf(usize) == 8) {
        %return in_stream.readIntLe(u64)
    } else {
        @unreachable();
    };
}

fn parseFormValueRefLen(in_stream: &io.InStream, size: usize) -> %FormValue {
    const buf = %return readAllocBytes(in_stream, size);
    return FormValue.Ref { buf };
}

fn parseFormValueRef(in_stream: &io.InStream, comptime T: type) -> %FormValue {
    const block_len = %return in_stream.readIntLe(T);
    return parseFormValueRefLen(in_stream, block_len);
}

fn parseFormValue(in_stream: &io.InStream, form_id: u64, is_64: bool) -> %FormValue {
    return switch (form_id) {
        DW.FORM_addr => FormValue.Address { %return parseFormValueTargetAddrSize(in_stream) },
        DW.FORM_block1 => parseFormValueBlock(in_stream, 1),
        DW.FORM_block2 => parseFormValueBlock(in_stream, 2),
        DW.FORM_block4 => parseFormValueBlock(in_stream, 4),
        DW.FORM_block => {
            const block_len = %return readULeb128(in_stream);
            parseFormValueBlockLen(in_stream, block_len)
        },
        DW.FORM_data1 => parseFormValueConstant(in_stream, false, 1),
        DW.FORM_data2 => parseFormValueConstant(in_stream, false, 2),
        DW.FORM_data4 => parseFormValueConstant(in_stream, false, 4),
        DW.FORM_data8 => parseFormValueConstant(in_stream, false, 8),
        DW.FORM_udata, DW.FORM_sdata => {
            const block_len = %return readULeb128(in_stream);
            const signed = form_id == DW.FORM_sdata;
            parseFormValueConstant(in_stream, signed, block_len)
        },
        DW.FORM_exprloc => {
            const size = %return readULeb128(in_stream);
            const buf = %return readAllocBytes(in_stream, size);
            return FormValue.ExprLoc { buf };
        },
        DW.FORM_flag => FormValue.Flag { (%return in_stream.readByte()) != 0 },
        DW.FORM_flag_present => FormValue.Flag { true },
        DW.FORM_sec_offset => FormValue.SecOffset {
            %return parseFormValueDwarfOffsetSize(in_stream, is_64)
        },

        DW.FORM_ref1 => parseFormValueRef(in_stream, u8),
        DW.FORM_ref2 => parseFormValueRef(in_stream, u16),
        DW.FORM_ref4 => parseFormValueRef(in_stream, u32),
        DW.FORM_ref8 => parseFormValueRef(in_stream, u64),
        DW.FORM_ref_udata => {
            const ref_len = %return readULeb128(in_stream);
            parseFormValueRefLen(in_stream, ref_len)
        },

        DW.FORM_ref_addr => FormValue.RefAddr { %return parseFormValueDwarfOffsetSize(in_stream, is_64) },
        DW.FORM_ref_sig8 => FormValue.RefSig8 { %return in_stream.readIntLe(u64) },

        DW.FORM_string => FormValue.String { %return readString(in_stream) },
        DW.FORM_strp => FormValue.StrPtr { %return parseFormValueDwarfOffsetSize(in_stream, is_64) },
        DW.FORM_indirect => {
            const child_form_id = %return readULeb128(in_stream);
            parseFormValue(in_stream, child_form_id, is_64)
        },
        else => error.InvalidDebugInfo,
    }
}

fn parseAbbrevTable(in_stream: &io.InStream) -> %AbbrevTable {
    var result = AbbrevTable.init(&global_allocator);
    while (true) {
        const abbrev_code = %return readULeb128(in_stream);
        if (abbrev_code == 0)
            return result;
        %return result.append(AbbrevTableEntry {
            .abbrev_code = abbrev_code,
            .tag_id = %return readULeb128(in_stream),
            .has_children = (%return in_stream.readByte()) == DW.CHILDREN_yes,
            .attrs = List(AbbrevAttr).init(&global_allocator),
        });
        const attrs = &result.items[result.len - 1].attrs;

        while (true) {
            const attr_id = %return readULeb128(in_stream);
            const form_id = %return readULeb128(in_stream);
            if (attr_id == 0 && form_id == 0)
                break;
            %return attrs.append(AbbrevAttr {
                .attr_id = attr_id,
                .form_id = form_id,
            });
        }
    }
}

/// Gets an already existing AbbrevTable given the abbrev_offset, or if not found,
/// seeks in the stream and parses it.
fn getAbbrevTable(st: &ElfStackTrace, abbrev_offset: u64) -> %&const AbbrevTable {
    for (st.abbrev_table_list.toSlice()) |*header| {
        if (header.offset == abbrev_offset) {
            return &header.table;
        }
    }
    %return st.self_exe_stream.seekTo(st.debug_abbrev.offset + abbrev_offset);
    %return st.abbrev_table_list.append(AbbrevTableHeader {
        .offset = abbrev_offset,
        .table = %return parseAbbrevTable(&st.self_exe_stream),
    });
    return &st.abbrev_table_list.items[st.abbrev_table_list.len - 1].table;
}

fn getAbbrevTableEntry(abbrev_table: &const AbbrevTable, abbrev_code: u64) -> ?&const AbbrevTableEntry {
    for (abbrev_table.toSlice()) |*table_entry| {
        if (table_entry.abbrev_code == abbrev_code)
            return table_entry;
    }
    return null;
}

fn parseDie(in_stream: &io.InStream, abbrev_table: &const AbbrevTable, is_64: bool) -> %Die {
    const abbrev_code = %return readULeb128(in_stream);
    const table_entry = getAbbrevTableEntry(abbrev_table, abbrev_code) ?? return error.InvalidDebugInfo;

    var result = Die {
        .tag_id = table_entry.tag_id,
        .has_children = table_entry.has_children,
        .attrs = List(Die.Attr).init(&global_allocator),
    };
    %return result.attrs.resize(table_entry.attrs.len);
    for (table_entry.attrs.toSlice()) |attr, i| {
        result.attrs.items[i] = Die.Attr {
            .id = attr.attr_id,
            .value = %return parseFormValue(in_stream, attr.form_id, is_64),
        };
    }
    return result;
}

fn scanAllCompileUnits(st: &ElfStackTrace) -> %void {
    const debug_info_end = st.debug_info.offset + st.debug_info.size;
    var this_unit_offset = st.debug_info.offset;
    while (this_unit_offset < debug_info_end) {
        %return st.self_exe_stream.seekTo(this_unit_offset);

        var is_64: bool = undefined;
        const unit_length = %return readInitialLength(&st.self_exe_stream, &is_64);
        if (unit_length == 0)
            return;
        const next_offset = unit_length + (if (is_64) usize(12) else usize(4));

        const version = %return st.self_exe_stream.readInt(st.elf.is_big_endian, u16);
        if (version != 4) return error.InvalidDebugInfo;

        const debug_abbrev_offset = if (is_64) {
            %return st.self_exe_stream.readInt(st.elf.is_big_endian, u64)
        } else {
            %return st.self_exe_stream.readInt(st.elf.is_big_endian, u32)
        };

        const address_size = %return st.self_exe_stream.readByte();
        if (address_size != @sizeOf(usize)) return error.InvalidDebugInfo;

        const compile_unit_pos = %return st.self_exe_stream.getPos();
        const abbrev_table = %return getAbbrevTable(st, debug_abbrev_offset);

        %return st.self_exe_stream.seekTo(compile_unit_pos);

        const compile_unit_die = (%return global_allocator.alloc(Die, 1)).ptr;
        *compile_unit_die = %return parseDie(&st.self_exe_stream, abbrev_table, is_64);

        if (compile_unit_die.tag_id != DW.TAG_compile_unit)
            return error.InvalidDebugInfo;
        const low_pc = %return compile_unit_die.getAttrAddr(DW.AT_low_pc);

        const high_pc_value = compile_unit_die.getAttr(DW.AT_high_pc) ?? return error.MissingDebugInfo;
        const pc_end = switch (*high_pc_value) {
            FormValue.Address => |value| value,
            FormValue.Const => |value| {
                const offset = %return value.asUnsignedLe();
                low_pc + offset
            },
            else => return error.InvalidDebugInfo,
        };

        %return st.compile_unit_list.append(CompileUnit {
            .is_64 = is_64,
            .pc_start = low_pc,
            .pc_end = pc_end,
            .die = compile_unit_die,
        });

        this_unit_offset += next_offset;
    }
}

fn findCompileUnit(st: &ElfStackTrace, target_address: u64) -> ?&const CompileUnit {
    for (st.compile_unit_list.toSlice()) |*compile_unit| {
        if (target_address >= compile_unit.pc_start && target_address < compile_unit.pc_end)
            return compile_unit;
    }
    return null;
}

fn readInitialLength(in_stream: &io.InStream, is_64: &bool) -> %u64 {
    const first_32_bits = %return in_stream.readIntLe(u32);
    *is_64 = (first_32_bits == 0xffffffff);
    return if (*is_64) {
        %return in_stream.readIntLe(u64)
    } else {
        if (first_32_bits >= 0xfffffff0) return error.InvalidDebugInfo;
        u64(first_32_bits)
    };
}

fn readULeb128(in_stream: &io.InStream) -> %u64 {
    var result: u64 = 0;
    var shift: u64 = 0;

    while (true) {
        const byte = %return in_stream.readByte();
        var operand: u64 = undefined;

        if (@shlWithOverflow(u64, byte & 0b01111111, shift, &operand))
            return error.InvalidDebugInfo;

        result |= operand;

        if ((byte & 0b10000000) == 0)
            return result;

        shift += 7;
    }
}

fn readILeb128(in_stream: &io.InStream) -> %i64 {
    var result: i64 = 0;
    var shift: i64 = 0;

    while (true) {
        const byte = %return in_stream.readByte();
        var operand: i64 = undefined;

        if (@shlWithOverflow(i64, byte & 0b01111111, shift, &operand))
            return error.InvalidDebugInfo;

        result |= operand;
        shift += 7;

        if ((byte & 0b10000000) == 0) {
            if (shift < @sizeOf(i64) * 8 && (byte & 0b01000000) != 0)
                result |= -(i64(1) << shift);

            return result;
        }
    }
}

pub var global_allocator = mem.Allocator {
    .allocFn = globalAlloc,
    .reallocFn = globalRealloc,
    .freeFn = globalFree,
    .context = null,
};

var some_mem: [100 * 1024]u8 = undefined;
var some_mem_index: usize = 0;

fn globalAlloc(self: &mem.Allocator, n: usize) -> %[]u8 {
    const result = some_mem[some_mem_index ... some_mem_index + n];
    some_mem_index += n;
    return result;
}

fn globalRealloc(self: &mem.Allocator, old_mem: []u8, new_size: usize) -> %[]u8 {
    const result = %return globalAlloc(self, new_size);
    @memcpy(result.ptr, old_mem.ptr, old_mem.len);
    return result;
}

fn globalFree(self: &mem.Allocator, old_mem: []u8) { }
