const Allocator = @import("mem.zig").Allocator;
const io = @import("io.zig");
const os = @import("os.zig");
const elf = @import("elf.zig");
const DW = @import("dwarf.zig");
const List = @import("list.zig").List;

pub error MissingDebugInfo;
pub error InvalidDebugInfo;
pub error UnsupportedDebugInfo;

pub fn assert(b: bool) {
    if (!b) @unreachable()
}

pub fn printStackTrace() -> %void {
    %return writeStackTrace(&io.stderr);
    %return io.stderr.flush();
}

pub fn writeStackTrace(out_stream: &io.OutStream) -> %void {
    switch (@compileVar("object_format")) {
        elf => {
            var st: ElfStackTrace = undefined;
            %return io.openSelfExe(&st.self_exe_stream);
            defer %return st.self_exe_stream.close();

            %return st.elf.openStream(&global_allocator, &st.self_exe_stream);
            defer %return st.elf.close();

            st.aranges = %return st.elf.findSection(".debug_aranges");
            st.debug_info = (%return st.elf.findSection(".debug_info")) ?? return error.MissingDebugInfo;
            st.debug_abbrev = (%return st.elf.findSection(".debug_abbrev")) ?? return error.MissingDebugInfo;

            var maybe_fp: ?&const u8 = @frameAddress();
            while (true) {
                const fp = maybe_fp ?? break;
                const return_address = *(&const usize)(usize(fp) + @sizeOf(usize));

                // read .debug_aranges to find out which compile unit the address is in
                const compile_unit_offset = %return findCompileUnitOffset(&st, return_address);

                %return out_stream.printInt(usize, return_address);
                %return out_stream.printf("  -> ");
                %return out_stream.printInt(u64, compile_unit_offset);
                %return out_stream.printf("\n");
                maybe_fp = *(&const ?&const u8)(fp);
            }
        },
        coff => {
            out_stream.write("(stack trace unavailable for COFF object format)\n");
        },
        macho => {
            %return out_stream.write("(stack trace unavailable for Mach-O object format)\n");
        },
        unknown => {
            out_stream.write("(stack trace unavailable for unknown object format)\n");
        },
    }
}

struct ElfStackTrace {
    self_exe_stream: io.InStream,
    elf: elf.Elf,
    aranges: ?&elf.SectionHeader,
    debug_info: &elf.SectionHeader,
    debug_abbrev: &elf.SectionHeader,
}

enum FormValue {
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
}

struct Constant {
    payload: []u8,
    signed: bool,
}


fn readAllocBytes(in_stream: &io.InStream, size: usize) -> %[]u8 {
    const buf = %return global_allocator.alloc(u8, size);
    %defer global_allocator.free(u8, buf);
    %return in_stream.read(buf);
    return buf;
}

fn parseFormValueBlockLen(in_stream: &io.InStream, size: usize) -> %FormValue {
    const buf = %return readAllocBytes(in_stream, size);
    return FormValue.Block { buf };
}

fn parseFormValueBlock(in_stream: &io.InStream, inline T: type) -> %FormValue {
    const block_len = %return in_stream.readIntLe(T);
    return parseFormValueBlockLen(in_stream, block_len);
}

fn parseFormValueConstantLen(in_stream: &io.InStream, signed: bool, size: usize) -> %FormValue {
    const buf = %return readAllocBytes(in_stream, size);
    return FormValue.Const { Constant {
        .signed = signed,
        .payload = buf,
    }};
}

fn parseFormValueConstant(in_stream: &io.InStream, signed: bool, inline T: type) -> %FormValue {
    const block_len = %return in_stream.readIntLe(T);
    return parseFormValueConstantLen(in_stream, signed, block_len);
}

fn parseFormValueAddrSize(in_stream: &io.InStream, is_64: bool) -> %u64 {
    return if (is_64) {
        %return in_stream.readIntLe(u64)
    } else {
        u64(%return in_stream.readIntLe(u32))
    };
}

fn parseFormValueRefLen(in_stream: &io.InStream, size: usize) -> %FormValue {
    const buf = %return readAllocBytes(in_stream, size);
    return FormValue.Ref { buf };
}

fn parseFormValueRef(in_stream: &io.InStream, inline T: type) -> %FormValue {
    const block_len = %return in_stream.readIntLe(T);
    return parseFormValueRefLen(in_stream, block_len);
}

fn parseFormValue(in_stream: &io.InStream, form_id: u64, is_64: bool) -> %FormValue {
    return switch (form_id) {
        DW.FORM_addr => FormValue.Address {
            %return parseFormValueAddrSize(in_stream, is_64)
        },
        DW.FORM_block1 => parseFormValueBlock(in_stream, u8),
        DW.FORM_block2 => parseFormValueBlock(in_stream, u16),
        DW.FORM_block4 => parseFormValueBlock(in_stream, u32),
        DW.FORM_block => {
            const block_len = %return readULeb128(in_stream);
            parseFormValueBlockLen(in_stream, block_len)
        },
        DW.FORM_data1 => parseFormValueConstant(in_stream, false, u8),
        DW.FORM_data2 => parseFormValueConstant(in_stream, false, u16),
        DW.FORM_data4 => parseFormValueConstant(in_stream, false, u32),
        DW.FORM_data8 => parseFormValueConstant(in_stream, false, u64),
        DW.FORM_udata, DW.FORM_sdata => {
            const block_len = %return readULeb128(in_stream);
            const signed = form_id == DW.FORM_sdata;
            parseFormValueConstantLen(in_stream, signed, block_len)
        },
        DW.FORM_exprloc => {
            const size = %return readULeb128(in_stream);
            const buf = %return readAllocBytes(in_stream, size);
            return FormValue.ExprLoc { buf };
        },
        DW.FORM_flag => FormValue.Flag { (%return in_stream.readByte()) != 0 },
        DW.FORM_flag_present => FormValue.Flag { true },
        DW.FORM_sec_offset => FormValue.SecOffset {
            %return parseFormValueAddrSize(in_stream, is_64)
        },

        DW.FORM_ref1 => parseFormValueRef(in_stream, u8),
        DW.FORM_ref2 => parseFormValueRef(in_stream, u16),
        DW.FORM_ref4 => parseFormValueRef(in_stream, u32),
        DW.FORM_ref8 => parseFormValueRef(in_stream, u64),
        DW.FORM_ref_udata => {
            const ref_len = %return readULeb128(in_stream);
            parseFormValueRefLen(in_stream, ref_len)
        },

        DW.FORM_ref_addr => FormValue.RefAddr { %return parseFormValueAddrSize(in_stream, is_64) },
        DW.FORM_ref_sig8 => FormValue.RefSig8 { %return in_stream.readIntLe(u64) },

        DW.FORM_string => {
            var buf: List(u8) = undefined; 
            buf.init(&global_allocator);
            while (true) {
                const byte = %return in_stream.readByte();
                if (byte == 0)
                    break;
                %return buf.append(byte);
            }

            FormValue.String { buf.items }
        },
        DW.FORM_strp => FormValue.StrPtr { %return parseFormValueAddrSize(in_stream, is_64) },
        DW.FORM_indirect => {
            const child_form_id = %return readULeb128(in_stream);
            parseFormValue(in_stream, child_form_id, is_64)
        },
        else => return error.InvalidDebugInfo,
    }
}

fn findCompileUnitOffset(st: &ElfStackTrace, target_address: usize) -> %u64 {
    if (const result ?= %return arangesOffset(st, target_address))
        return result;

    // iterate over compile units looking for a match with the low pc and high pc
    %return st.elf.seekToSection(st.debug_info);

    while (true) {
        var is_64: bool = undefined;
        const unit_length = %return readInitialLength(&st.self_exe_stream, &is_64);

        const version = %return st.self_exe_stream.readInt(st.elf.is_big_endian, u16);
        if (version != 4) return error.InvalidDebugInfo;

        const debug_abbrev_offset = if (is_64) {
            %return st.self_exe_stream.readInt(st.elf.is_big_endian, u64)
        } else {
            %return st.self_exe_stream.readInt(st.elf.is_big_endian, u32)
        };

        const address_size = %return st.self_exe_stream.readByte();
        if (address_size != @sizeOf(usize)) return error.InvalidDebugInfo;

        const abbrev_tag_id = %return st.self_exe_stream.readByte();


    }
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

fn arangesOffset(st: &ElfStackTrace, target_address: usize) -> %?u64 {
    // TODO ability to implicitly cast null to %?T
    const aranges = st.aranges ?? return (?u64)(null);

    %return st.elf.seekToSection(aranges);

    const first_32_bits = %return st.self_exe_stream.readIntLe(u32);
    var is_64: bool = undefined;
    const unit_length = %return readInitialLength(&st.self_exe_stream, &is_64);
    var unit_index: u64 = 0;

    while (unit_index < unit_length) {
        const version = %return st.self_exe_stream.readIntLe(u16);
        if (version != 2) return error.InvalidDebugInfo;
        unit_index += 2;

        const debug_info_offset = if (is_64) {
            unit_index += 4;
            %return st.self_exe_stream.readIntLe(u64)
        } else {
            unit_index += 2;
            %return st.self_exe_stream.readIntLe(u32)
        };

        const address_size = %return st.self_exe_stream.readByte();
        if (address_size > 8) return error.UnsupportedDebugInfo;
        unit_index += 1;

        const segment_size = %return st.self_exe_stream.readByte();
        if (segment_size > 0) return error.UnsupportedDebugInfo;
        unit_index += 1;

        const align = segment_size + 2 * address_size;
        const padding = (%return st.self_exe_stream.getPos()) % align;
        %return st.self_exe_stream.seekForward(padding);
        unit_index += padding;

        while (true) {
            const address = %return st.self_exe_stream.readVarInt(false, u64, address_size);
            const length = %return st.self_exe_stream.readVarInt(false, u64, address_size);
            unit_index += align;
            if (address == 0 && length == 0) break;

            if (target_address >= address && target_address < address + length) {
                // TODO ability to implicitly cast T to %?T
                return (?u64)(debug_info_offset);
            }
        }
    }

    return error.MissingDebugInfo;
}

pub var global_allocator = Allocator {
    .allocFn = globalAlloc,
    .reallocFn = globalRealloc,
    .freeFn = globalFree,
    .context = null,
};

var some_mem: [10 * 1024]u8 = undefined;
var some_mem_index: usize = 0;

fn globalAlloc(self: &Allocator, n: usize) -> %[]u8 {
    const result = some_mem[some_mem_index ... some_mem_index + n];
    some_mem_index += n;
    return result;
}

fn globalRealloc(self: &Allocator, old_mem: []u8, new_size: usize) -> %[]u8 {
    const result = %return globalAlloc(self, new_size);
    @memcpy(result.ptr, old_mem.ptr, old_mem.len);
    return result;
}

fn globalFree(self: &Allocator, old_mem: []u8) { }
