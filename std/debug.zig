const std = @import("index.zig");
const math = std.math;
const mem = std.mem;
const io = std.io;
const os = std.os;
const elf = @import("elf.zig");
const DW = @import("dwarf.zig");
const ArrayList = std.ArrayList;
const builtin = @import("builtin");

error MissingDebugInfo;
error InvalidDebugInfo;
error UnsupportedDebugInfo;


/// Tries to write to stderr, unbuffered, and ignores any error returned.
/// Does not append a newline.
/// TODO atomic/multithread support
var stderr_file: io.File = undefined;
var stderr_file_out_stream: io.FileOutStream = undefined;
var stderr_stream: ?&io.OutStream = null;
pub fn warn(comptime fmt: []const u8, args: ...) {
    const stderr = getStderrStream() %% return;
    stderr.print(fmt, args) %% return;
}
fn getStderrStream() -> %&io.OutStream {
    if (stderr_stream) |st| {
        return st;
    } else {
        stderr_file = %return io.getStdErr();
        stderr_file_out_stream = io.FileOutStream.init(&stderr_file);
        const st = &stderr_file_out_stream.stream;
        stderr_stream = st;
        return st;
    };
}

/// Tries to print a stack trace to stderr, unbuffered, and ignores any error returned.
pub fn dumpStackTrace() {
    const stderr = getStderrStream() %% return;
    writeStackTrace(stderr, global_allocator, stderr_file.isTty(), 1) %% return;
}

/// This function invokes undefined behavior when `ok` is `false`.
/// In Debug and ReleaseSafe modes, calls to this function are always
/// generated, and the `unreachable` statement triggers a panic.
/// In ReleaseFast and ReleaseSmall modes, calls to this function can be
/// optimized away.
pub fn assert(ok: bool) {
    if (!ok) {
        // In ReleaseFast test mode, we still want assert(false) to crash, so
        // we insert an explicit call to @panic instead of unreachable.
        // TODO we should use `assertOrPanic` in tests and remove this logic.
        if (builtin.is_test) {
            @panic("assertion failure")
        } else {
            unreachable // assertion failure
        }
    }
}

/// Call this function when you want to panic if the condition is not true.
/// If `ok` is `false`, this function will panic in every release mode.
pub fn assertOrPanic(ok: bool) {
    if (!ok) {
        @panic("assertion failure");
    }
}

var panicking = false;
/// This is the default panic implementation.
pub fn panic(comptime format: []const u8, args: ...) -> noreturn {
    // TODO an intrinsic that labels this as unlikely to be reached

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

    const stderr = getStderrStream() %% os.abort();
    stderr.print(format ++ "\n", args) %% os.abort();
    writeStackTrace(stderr, global_allocator, stderr_file.isTty(), 1) %% os.abort();

    os.abort();
}

const GREEN = "\x1b[32;1m";
const WHITE = "\x1b[37;1m";
const DIM = "\x1b[2m";
const RESET = "\x1b[0m";

pub var user_main_fn: ?fn() -> %void = null;

error PathNotFound;
error InvalidDebugInfo;

pub fn writeStackTrace(out_stream: &io.OutStream, allocator: &mem.Allocator, tty_color: bool,
    ignore_frame_count: usize) -> %void
{
    switch (builtin.object_format) {
        builtin.ObjectFormat.elf => {
            var stack_trace = ElfStackTrace {
                .self_exe_file = undefined,
                .elf = undefined,
                .debug_info = undefined,
                .debug_abbrev = undefined,
                .debug_str = undefined,
                .debug_line = undefined,
                .abbrev_table_list = ArrayList(AbbrevTableHeader).init(allocator),
                .compile_unit_list = ArrayList(CompileUnit).init(allocator),
            };
            const st = &stack_trace;
            st.self_exe_file = %return os.openSelfExe();
            defer st.self_exe_file.close();

            %return st.elf.openFile(allocator, &st.self_exe_file);
            defer st.elf.close();

            st.debug_info = (%return st.elf.findSection(".debug_info")) ?? return error.MissingDebugInfo;
            st.debug_abbrev = (%return st.elf.findSection(".debug_abbrev")) ?? return error.MissingDebugInfo;
            st.debug_str = (%return st.elf.findSection(".debug_str")) ?? return error.MissingDebugInfo;
            st.debug_line = (%return st.elf.findSection(".debug_line")) ?? return error.MissingDebugInfo;
            %return scanAllCompileUnits(st);

            var ignored_count: usize = 0;

            var fp = @ptrToInt(@frameAddress());
            while (fp != 0) : (fp = *@intToPtr(&const usize, fp)) {
                if (ignored_count < ignore_frame_count) {
                    ignored_count += 1;
                    continue;
                }

                const return_address = *@intToPtr(&const usize, fp + @sizeOf(usize));

                // TODO we really should be able to convert @sizeOf(usize) * 2 to a string literal
                // at compile time. I'll call it issue #313
                const ptr_hex = if (@sizeOf(usize) == 4) "0x{x8}" else "0x{x16}";

                const compile_unit = findCompileUnit(st, return_address) ?? {
                    %return out_stream.print("???:?:?: " ++ DIM ++ ptr_hex ++ " in ??? (???)" ++ RESET ++ "\n    ???\n\n",
                        return_address);
                    continue;
                };
                const compile_unit_name = %return compile_unit.die.getAttrString(st, DW.AT_name);
                if (getLineNumberInfo(st, compile_unit, usize(return_address) - 1)) |line_info| {
                    defer line_info.deinit();
                    %return out_stream.print(WHITE ++ "{}:{}:{}" ++ RESET ++ ": " ++
                        DIM ++ ptr_hex ++ " in ??? ({})" ++ RESET ++ "\n",
                        line_info.file_name, line_info.line, line_info.column,
                        return_address, compile_unit_name);
                    if (printLineFromFile(st.allocator(), out_stream, line_info)) {
                        if (line_info.column == 0) {
                            %return out_stream.write("\n");
                        } else {
                            {var col_i: usize = 1; while (col_i < line_info.column) : (col_i += 1) {
                                %return out_stream.writeByte(' ');
                            }}
                            %return out_stream.write(GREEN ++ "^" ++ RESET ++ "\n");
                        }
                    } else |err| switch (err) {
                        error.EndOfFile, error.PathNotFound => {},
                        else => return err,
                    }
                } else |err| switch (err) {
                    error.MissingDebugInfo, error.InvalidDebugInfo => {
                        %return out_stream.print(ptr_hex ++ " in ??? ({})\n",
                            return_address, compile_unit_name);
                    },
                    else => return err,
                };
            }
        },
        builtin.ObjectFormat.coff => {
            %return out_stream.write("(stack trace unavailable for COFF object format)\n");
        },
        builtin.ObjectFormat.macho => {
            %return out_stream.write("(stack trace unavailable for Mach-O object format)\n");
        },
        builtin.ObjectFormat.wasm => {
            %return out_stream.write("(stack trace unavailable for WASM object format)\n");
        },
        builtin.ObjectFormat.unknown => {
            %return out_stream.write("(stack trace unavailable for unknown object format)\n");
        },
    }
}

fn printLineFromFile(allocator: &mem.Allocator, out_stream: &io.OutStream, line_info: &const LineInfo) -> %void {
    var f = %return io.File.openRead(line_info.file_name, allocator);
    defer f.close();
    // TODO fstat and make sure that the file has the correct size

    var buf: [os.page_size]u8 = undefined;
    var line: usize = 1;
    var column: usize = 1;
    var abs_index: usize = 0;
    while (true) {
        const amt_read = %return f.read(buf[0..]);
        const slice = buf[0..amt_read];

        for (slice) |byte| {
            if (line == line_info.line) {
                %return out_stream.writeByte(byte);
                if (byte == '\n') {
                    return;
                }
            }
            if (byte == '\n') {
                line += 1;
                column = 1;
            } else {
                column += 1;
            }
        }

        if (amt_read < buf.len)
            return error.EndOfFile;
    }
}

const ElfStackTrace = struct {
    self_exe_file: io.File,
    elf: elf.Elf,
    debug_info: &elf.SectionHeader,
    debug_abbrev: &elf.SectionHeader,
    debug_str: &elf.SectionHeader,
    debug_line: &elf.SectionHeader,
    abbrev_table_list: ArrayList(AbbrevTableHeader),
    compile_unit_list: ArrayList(CompileUnit),

    pub fn allocator(self: &const ElfStackTrace) -> &mem.Allocator {
        return self.abbrev_table_list.allocator;
    }

    pub fn readString(self: &ElfStackTrace) -> %[]u8 {
        var in_file_stream = io.FileInStream.init(&self.self_exe_file);
        const in_stream = &in_file_stream.stream;
        return readStringRaw(self.allocator(), in_stream);
    }
};

const PcRange = struct {
    start: u64,
    end: u64,
};

const CompileUnit = struct {
    version: u16,
    is_64: bool,
    die: &Die,
    index: usize,
    pc_range: ?PcRange,
};

const AbbrevTable = ArrayList(AbbrevTableEntry);

const AbbrevTableHeader = struct {
    // offset from .debug_abbrev
    offset: u64,
    table: AbbrevTable,
};

const AbbrevTableEntry = struct {
    has_children: bool,
    abbrev_code: u64,
    tag_id: u64,
    attrs: ArrayList(AbbrevAttr),
};

const AbbrevAttr = struct {
    attr_id: u64,
    form_id: u64,
};

const FormValue = union(enum) {
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
        return mem.readInt(self.payload, u64, builtin.Endian.Little);
    }
};

const Die = struct {
    tag_id: u64,
    has_children: bool,
    attrs: ArrayList(Attr),

    const Attr = struct {
        id: u64,
        value: FormValue,
    };

    fn getAttr(self: &const Die, id: u64) -> ?&const FormValue {
        for (self.attrs.toSliceConst()) |*attr| {
            if (attr.id == id)
                return &attr.value;
        }
        return null;
    }

    fn getAttrAddr(self: &const Die, id: u64) -> %u64 {
        const form_value = self.getAttr(id) ?? return error.MissingDebugInfo;
        return switch (*form_value) {
            FormValue.Address => |value| value,
            else => error.InvalidDebugInfo,
        };
    }

    fn getAttrUnsignedLe(self: &const Die, id: u64) -> %u64 {
        const form_value = self.getAttr(id) ?? return error.MissingDebugInfo;
        return switch (*form_value) {
            FormValue.Const => |value| value.asUnsignedLe(),
            else => error.InvalidDebugInfo,
        };
    }

    fn getAttrString(self: &const Die, st: &ElfStackTrace, id: u64) -> %[]u8 {
        const form_value = self.getAttr(id) ?? return error.MissingDebugInfo;
        return switch (*form_value) {
            FormValue.String => |value| value,
            FormValue.StrPtr => |offset| getString(st, offset),
            else => error.InvalidDebugInfo,
        }
    }
};

const FileEntry = struct {
    file_name: []const u8,
    dir_index: usize,
    mtime: usize,
    len_bytes: usize,
};

const LineInfo = struct {
    line: usize,
    column: usize,
    file_name: []u8,
    allocator: &mem.Allocator,

    fn deinit(self: &const LineInfo) {
        self.allocator.free(self.file_name);
    }
};

const LineNumberProgram = struct {
    address: usize,
    file: usize,
    line: isize,
    column: usize,
    is_stmt: bool,
    basic_block: bool,
    end_sequence: bool,

    target_address: usize,
    include_dirs: []const []const u8,
    file_entries: &ArrayList(FileEntry),

    prev_address: usize,
    prev_file: usize,
    prev_line: isize,
    prev_column: usize,
    prev_is_stmt: bool,
    prev_basic_block: bool,
    prev_end_sequence: bool,

    pub fn init(is_stmt: bool, include_dirs: []const []const u8,
        file_entries: &ArrayList(FileEntry), target_address: usize) -> LineNumberProgram
    {
        LineNumberProgram {
            .address = 0,
            .file = 1,
            .line = 1,
            .column = 0,
            .is_stmt = is_stmt,
            .basic_block = false,
            .end_sequence = false,
            .include_dirs = include_dirs,
            .file_entries = file_entries,
            .target_address = target_address,
            .prev_address = 0,
            .prev_file = undefined,
            .prev_line = undefined,
            .prev_column = undefined,
            .prev_is_stmt = undefined,
            .prev_basic_block = undefined,
            .prev_end_sequence = undefined,
        }
    }

    pub fn checkLineMatch(self: &LineNumberProgram) -> %?LineInfo {
        if (self.target_address >= self.prev_address and self.target_address < self.address) {
            const file_entry = if (self.prev_file == 0) {
                return error.MissingDebugInfo;
            } else if (self.prev_file - 1 >= self.file_entries.len) {
                return error.InvalidDebugInfo;
            } else {
                &self.file_entries.items[self.prev_file - 1]
            };
            const dir_name = if (file_entry.dir_index >= self.include_dirs.len) {
                return error.InvalidDebugInfo;
            } else {
                self.include_dirs[file_entry.dir_index]
            };
            const file_name = %return os.path.join(self.file_entries.allocator, dir_name, file_entry.file_name);
            %defer self.file_entries.allocator.free(file_name);
            return LineInfo {
                .line = if (self.prev_line >= 0) usize(self.prev_line) else 0,
                .column = self.prev_column,
                .file_name = file_name,
                .allocator = self.file_entries.allocator,
            };
        }

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

fn readStringRaw(allocator: &mem.Allocator, in_stream: &io.InStream) -> %[]u8 {
    var buf = ArrayList(u8).init(allocator);
    while (true) {
        const byte = %return in_stream.readByte();
        if (byte == 0)
            break;
        %return buf.append(byte);
    }
    return buf.toSlice();
}

fn getString(st: &ElfStackTrace, offset: u64) -> %[]u8 {
    const pos = st.debug_str.offset + offset;
    %return st.self_exe_file.seekTo(pos);
    return st.readString();
}

fn readAllocBytes(allocator: &mem.Allocator, in_stream: &io.InStream, size: usize) -> %[]u8 {
    const buf = %return global_allocator.alloc(u8, size);
    %defer global_allocator.free(buf);
    if ((%return in_stream.read(buf)) < size) return error.EndOfFile;
    return buf;
}

fn parseFormValueBlockLen(allocator: &mem.Allocator, in_stream: &io.InStream, size: usize) -> %FormValue {
    const buf = %return readAllocBytes(allocator, in_stream, size);
    return FormValue { .Block = buf };
}

fn parseFormValueBlock(allocator: &mem.Allocator, in_stream: &io.InStream, size: usize) -> %FormValue {
    const block_len = %return in_stream.readVarInt(builtin.Endian.Little, usize, size);
    return parseFormValueBlockLen(allocator, in_stream, block_len);
}

fn parseFormValueConstant(allocator: &mem.Allocator, in_stream: &io.InStream, signed: bool, size: usize) -> %FormValue {
    FormValue { .Const = Constant {
        .signed = signed,
        .payload = %return readAllocBytes(allocator, in_stream, size),
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
        unreachable;
    };
}

fn parseFormValueRefLen(allocator: &mem.Allocator, in_stream: &io.InStream, size: usize) -> %FormValue {
    const buf = %return readAllocBytes(allocator, in_stream, size);
    return FormValue { .Ref = buf };
}

fn parseFormValueRef(allocator: &mem.Allocator, in_stream: &io.InStream, comptime T: type) -> %FormValue {
    const block_len = %return in_stream.readIntLe(T);
    return parseFormValueRefLen(allocator, in_stream, block_len);
}

fn parseFormValue(allocator: &mem.Allocator, in_stream: &io.InStream, form_id: u64, is_64: bool) -> %FormValue {
    return switch (form_id) {
        DW.FORM_addr => FormValue { .Address = %return parseFormValueTargetAddrSize(in_stream) },
        DW.FORM_block1 => parseFormValueBlock(allocator, in_stream, 1),
        DW.FORM_block2 => parseFormValueBlock(allocator, in_stream, 2),
        DW.FORM_block4 => parseFormValueBlock(allocator, in_stream, 4),
        DW.FORM_block => {
            const block_len = %return readULeb128(in_stream);
            parseFormValueBlockLen(allocator, in_stream, block_len)
        },
        DW.FORM_data1 => parseFormValueConstant(allocator, in_stream, false, 1),
        DW.FORM_data2 => parseFormValueConstant(allocator, in_stream, false, 2),
        DW.FORM_data4 => parseFormValueConstant(allocator, in_stream, false, 4),
        DW.FORM_data8 => parseFormValueConstant(allocator, in_stream, false, 8),
        DW.FORM_udata, DW.FORM_sdata => {
            const block_len = %return readULeb128(in_stream);
            const signed = form_id == DW.FORM_sdata;
            parseFormValueConstant(allocator, in_stream, signed, block_len)
        },
        DW.FORM_exprloc => {
            const size = %return readULeb128(in_stream);
            const buf = %return readAllocBytes(allocator, in_stream, size);
            return FormValue { .ExprLoc = buf };
        },
        DW.FORM_flag => FormValue { .Flag = (%return in_stream.readByte()) != 0 },
        DW.FORM_flag_present => FormValue { .Flag = true },
        DW.FORM_sec_offset => FormValue { .SecOffset = %return parseFormValueDwarfOffsetSize(in_stream, is_64) },

        DW.FORM_ref1 => parseFormValueRef(allocator, in_stream, u8),
        DW.FORM_ref2 => parseFormValueRef(allocator, in_stream, u16),
        DW.FORM_ref4 => parseFormValueRef(allocator, in_stream, u32),
        DW.FORM_ref8 => parseFormValueRef(allocator, in_stream, u64),
        DW.FORM_ref_udata => {
            const ref_len = %return readULeb128(in_stream);
            parseFormValueRefLen(allocator, in_stream, ref_len)
        },

        DW.FORM_ref_addr => FormValue { .RefAddr = %return parseFormValueDwarfOffsetSize(in_stream, is_64) },
        DW.FORM_ref_sig8 => FormValue { .RefSig8 = %return in_stream.readIntLe(u64) },

        DW.FORM_string => FormValue { .String = %return readStringRaw(allocator, in_stream) },
        DW.FORM_strp => FormValue { .StrPtr = %return parseFormValueDwarfOffsetSize(in_stream, is_64) },
        DW.FORM_indirect => {
            const child_form_id = %return readULeb128(in_stream);
            parseFormValue(allocator, in_stream, child_form_id, is_64)
        },
        else => error.InvalidDebugInfo,
    }
}

fn parseAbbrevTable(st: &ElfStackTrace) -> %AbbrevTable {
    const in_file = &st.self_exe_file;
    var in_file_stream = io.FileInStream.init(in_file);
    const in_stream = &in_file_stream.stream;
    var result = AbbrevTable.init(st.allocator());
    while (true) {
        const abbrev_code = %return readULeb128(in_stream);
        if (abbrev_code == 0)
            return result;
        %return result.append(AbbrevTableEntry {
            .abbrev_code = abbrev_code,
            .tag_id = %return readULeb128(in_stream),
            .has_children = (%return in_stream.readByte()) == DW.CHILDREN_yes,
            .attrs = ArrayList(AbbrevAttr).init(st.allocator()),
        });
        const attrs = &result.items[result.len - 1].attrs;

        while (true) {
            const attr_id = %return readULeb128(in_stream);
            const form_id = %return readULeb128(in_stream);
            if (attr_id == 0 and form_id == 0)
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
    %return st.self_exe_file.seekTo(st.debug_abbrev.offset + abbrev_offset);
    %return st.abbrev_table_list.append(AbbrevTableHeader {
        .offset = abbrev_offset,
        .table = %return parseAbbrevTable(st),
    });
    return &st.abbrev_table_list.items[st.abbrev_table_list.len - 1].table;
}

fn getAbbrevTableEntry(abbrev_table: &const AbbrevTable, abbrev_code: u64) -> ?&const AbbrevTableEntry {
    for (abbrev_table.toSliceConst()) |*table_entry| {
        if (table_entry.abbrev_code == abbrev_code)
            return table_entry;
    }
    return null;
}

fn parseDie(st: &ElfStackTrace, abbrev_table: &const AbbrevTable, is_64: bool) -> %Die {
    const in_file = &st.self_exe_file;
    var in_file_stream = io.FileInStream.init(in_file);
    const in_stream = &in_file_stream.stream;
    const abbrev_code = %return readULeb128(in_stream);
    const table_entry = getAbbrevTableEntry(abbrev_table, abbrev_code) ?? return error.InvalidDebugInfo;

    var result = Die {
        .tag_id = table_entry.tag_id,
        .has_children = table_entry.has_children,
        .attrs = ArrayList(Die.Attr).init(st.allocator()),
    };
    %return result.attrs.resize(table_entry.attrs.len);
    for (table_entry.attrs.toSliceConst()) |attr, i| {
        result.attrs.items[i] = Die.Attr {
            .id = attr.attr_id,
            .value = %return parseFormValue(st.allocator(), in_stream, attr.form_id, is_64),
        };
    }
    return result;
}

fn getLineNumberInfo(st: &ElfStackTrace, compile_unit: &const CompileUnit, target_address: usize) -> %LineInfo {
    const compile_unit_cwd = %return compile_unit.die.getAttrString(st, DW.AT_comp_dir);

    const in_file = &st.self_exe_file;
    const debug_line_end = st.debug_line.offset + st.debug_line.size;
    var this_offset = st.debug_line.offset;
    var this_index: usize = 0;

    var in_file_stream = io.FileInStream.init(in_file);
    const in_stream = &in_file_stream.stream;

    while (this_offset < debug_line_end) : (this_index += 1) {
        %return in_file.seekTo(this_offset);

        var is_64: bool = undefined;
        const unit_length = %return readInitialLength(in_stream, &is_64);
        if (unit_length == 0)
            return error.MissingDebugInfo;
        const next_offset = unit_length + (if (is_64) usize(12) else usize(4));

        if (compile_unit.index != this_index) {
            this_offset += next_offset;
            continue;
        }

        const version = %return in_stream.readInt(st.elf.endian, u16);
        if (version != 2) return error.InvalidDebugInfo;

        const prologue_length = %return in_stream.readInt(st.elf.endian, u32);
        const prog_start_offset = (%return in_file.getPos()) + prologue_length;

        const minimum_instruction_length = %return in_stream.readByte();
        if (minimum_instruction_length == 0) return error.InvalidDebugInfo;

        const default_is_stmt = (%return in_stream.readByte()) != 0;
        const line_base = %return in_stream.readByteSigned();

        const line_range = %return in_stream.readByte();
        if (line_range == 0)
            return error.InvalidDebugInfo;

        const opcode_base = %return in_stream.readByte();

        const standard_opcode_lengths = %return st.allocator().alloc(u8, opcode_base - 1);

        {var i: usize = 0; while (i < opcode_base - 1) : (i += 1) {
            standard_opcode_lengths[i] = %return in_stream.readByte();
        }}

        var include_directories = ArrayList([]u8).init(st.allocator());
        %return include_directories.append(compile_unit_cwd);
        while (true) {
            const dir = %return st.readString();
            if (dir.len == 0)
                break;
            %return include_directories.append(dir);
        }

        var file_entries = ArrayList(FileEntry).init(st.allocator());
        var prog = LineNumberProgram.init(default_is_stmt, include_directories.toSliceConst(),
            &file_entries, target_address);

        while (true) {
            const file_name = %return st.readString();
            if (file_name.len == 0)
                break;
            const dir_index = %return readULeb128(in_stream);
            const mtime = %return readULeb128(in_stream);
            const len_bytes = %return readULeb128(in_stream);
            %return file_entries.append(FileEntry {
                .file_name = file_name,
                .dir_index = dir_index,
                .mtime = mtime,
                .len_bytes = len_bytes,
            });
        }

        %return in_file.seekTo(prog_start_offset);

        while (true) {
            const opcode = %return in_stream.readByte();

            var sub_op: u8 = undefined; // TODO move this to the correct scope and fix the compiler crash
            if (opcode == DW.LNS_extended_op) {
                const op_size = %return readULeb128(in_stream);
                if (op_size < 1)
                    return error.InvalidDebugInfo;
                sub_op = %return in_stream.readByte();
                switch (sub_op) {
                    DW.LNE_end_sequence => {
                        prog.end_sequence = true;
                        if (%return prog.checkLineMatch()) |info| return info;
                        return error.MissingDebugInfo;
                    },
                    DW.LNE_set_address => {
                        const addr = %return in_stream.readInt(st.elf.endian, usize);
                        prog.address = addr;
                    },
                    DW.LNE_define_file => {
                        const file_name = %return st.readString();
                        const dir_index = %return readULeb128(in_stream);
                        const mtime = %return readULeb128(in_stream);
                        const len_bytes = %return readULeb128(in_stream);
                        %return file_entries.append(FileEntry {
                            .file_name = file_name,
                            .dir_index = dir_index,
                            .mtime = mtime,
                            .len_bytes = len_bytes,
                        });
                    },
                    else => {
                        const fwd_amt = math.cast(isize, op_size - 1) %% return error.InvalidDebugInfo;
                        %return in_file.seekForward(fwd_amt);
                    },
                }
            } else if (opcode >= opcode_base) {
                // special opcodes
                const adjusted_opcode = opcode - opcode_base;
                const inc_addr = minimum_instruction_length * (adjusted_opcode / line_range);
                const inc_line = i32(line_base) + i32(adjusted_opcode % line_range);
                prog.line += inc_line;
                prog.address += inc_addr;
                if (%return prog.checkLineMatch()) |info| return info;
                prog.basic_block = false;
            } else {
                switch (opcode) {
                    DW.LNS_copy => {
                        if (%return prog.checkLineMatch()) |info| return info;
                        prog.basic_block = false;
                    },
                    DW.LNS_advance_pc => {
                        const arg = %return readULeb128(in_stream);
                        prog.address += arg * minimum_instruction_length;
                    },
                    DW.LNS_advance_line => {
                        const arg = %return readILeb128(in_stream);
                        prog.line += arg;
                    },
                    DW.LNS_set_file => {
                        const arg = %return readULeb128(in_stream);
                        prog.file = arg;
                    },
                    DW.LNS_set_column => {
                        const arg = %return readULeb128(in_stream);
                        prog.column = arg;
                    },
                    DW.LNS_negate_stmt => {
                        prog.is_stmt = !prog.is_stmt;
                    },
                    DW.LNS_set_basic_block => {
                        prog.basic_block = true;
                    },
                    DW.LNS_const_add_pc => {
                        const inc_addr = minimum_instruction_length * ((255 - opcode_base) / line_range);
                        prog.address += inc_addr;
                    },
                    DW.LNS_fixed_advance_pc => {
                        const arg = %return in_stream.readInt(st.elf.endian, u16);
                        prog.address += arg;
                    },
                    DW.LNS_set_prologue_end => {
                    },
                    else => {
                        if (opcode - 1 >= standard_opcode_lengths.len)
                            return error.InvalidDebugInfo;
                        const len_bytes = standard_opcode_lengths[opcode - 1];
                        %return in_file.seekForward(len_bytes);
                    },
                }
            }
        }

        this_offset += next_offset;
    }

    return error.MissingDebugInfo;
}

fn scanAllCompileUnits(st: &ElfStackTrace) -> %void {
    const debug_info_end = st.debug_info.offset + st.debug_info.size;
    var this_unit_offset = st.debug_info.offset;
    var cu_index: usize = 0;

    var in_file_stream = io.FileInStream.init(&st.self_exe_file);
    const in_stream = &in_file_stream.stream;

    while (this_unit_offset < debug_info_end) {
        %return st.self_exe_file.seekTo(this_unit_offset);

        var is_64: bool = undefined;
        const unit_length = %return readInitialLength(in_stream, &is_64);
        if (unit_length == 0)
            return;
        const next_offset = unit_length + (if (is_64) usize(12) else usize(4));

        const version = %return in_stream.readInt(st.elf.endian, u16);
        if (version < 2 or version > 5) return error.InvalidDebugInfo;

        const debug_abbrev_offset = if (is_64) {
            %return in_stream.readInt(st.elf.endian, u64)
        } else {
            %return in_stream.readInt(st.elf.endian, u32)
        };

        const address_size = %return in_stream.readByte();
        if (address_size != @sizeOf(usize)) return error.InvalidDebugInfo;

        const compile_unit_pos = %return st.self_exe_file.getPos();
        const abbrev_table = %return getAbbrevTable(st, debug_abbrev_offset);

        %return st.self_exe_file.seekTo(compile_unit_pos);

        const compile_unit_die = %return st.allocator().create(Die);
        *compile_unit_die = %return parseDie(st, abbrev_table, is_64);

        if (compile_unit_die.tag_id != DW.TAG_compile_unit)
            return error.InvalidDebugInfo;

        const pc_range = {
            if (compile_unit_die.getAttrAddr(DW.AT_low_pc)) |low_pc| {
                if (compile_unit_die.getAttr(DW.AT_high_pc)) |high_pc_value| {
                    const pc_end = switch (*high_pc_value) {
                        FormValue.Address => |value| value,
                        FormValue.Const => |value| {
                            const offset = %return value.asUnsignedLe();
                            low_pc + offset
                        },
                        else => return error.InvalidDebugInfo,
                    };
                    PcRange {
                        .start = low_pc,
                        .end = pc_end,
                    }
                } else {
                    null
                }
            } else |err| {
                if (err != error.MissingDebugInfo)
                    return err;
                null
            }
        };

        %return st.compile_unit_list.append(CompileUnit {
            .version = version,
            .is_64 = is_64,
            .pc_range = pc_range,
            .die = compile_unit_die,
            .index = cu_index,
        });

        this_unit_offset += next_offset;
        cu_index += 1;
    }
}

fn findCompileUnit(st: &ElfStackTrace, target_address: u64) -> ?&const CompileUnit {
    for (st.compile_unit_list.toSlice()) |*compile_unit| {
        if (compile_unit.pc_range) |range| {
            if (target_address >= range.start and target_address < range.end)
                return compile_unit;
        }
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
    var shift: usize = 0;

    while (true) {
        const byte = %return in_stream.readByte();

        var operand: u64 = undefined;

        if (@shlWithOverflow(u64, byte & 0b01111111, u6(shift), &operand))
            return error.InvalidDebugInfo;

        result |= operand;

        if ((byte & 0b10000000) == 0)
            return result;

        shift += 7;
    }
}

fn readILeb128(in_stream: &io.InStream) -> %i64 {
    var result: i64 = 0;
    var shift: usize = 0;

    while (true) {
        const byte = %return in_stream.readByte();

        var operand: i64 = undefined;

        if (@shlWithOverflow(i64, byte & 0b01111111, u6(shift), &operand))
            return error.InvalidDebugInfo;

        result |= operand;
        shift += 7;

        if ((byte & 0b10000000) == 0) {
            if (shift < @sizeOf(i64) * 8 and (byte & 0b01000000) != 0)
                result |= -(i64(1) << u6(shift));
            return result;
        }
    }
}

pub const global_allocator = &global_allocator_state;
var global_allocator_state = mem.Allocator {
    .allocFn = globalAlloc,
    .reallocFn = globalRealloc,
    .freeFn = globalFree,
};

var some_mem: [100 * 1024]u8 = undefined;
var some_mem_index: usize = 0;

error OutOfMemory;

fn globalAlloc(self: &mem.Allocator, n: usize, alignment: usize) -> %[]u8 {
    const addr = @ptrToInt(&some_mem[some_mem_index]);
    const rem = @rem(addr, alignment);
    const march_forward_bytes = if (rem == 0) 0 else (alignment - rem);
    const adjusted_index = some_mem_index + march_forward_bytes;
    const end_index = adjusted_index + n;
    if (end_index > some_mem.len) {
        return error.OutOfMemory;
    }
    const result = some_mem[adjusted_index .. end_index];
    some_mem_index = end_index;
    return result;
}

fn globalRealloc(self: &mem.Allocator, old_mem: []u8, new_size: usize, alignment: usize) -> %[]u8 {
    if (new_size <= old_mem.len) {
        return old_mem[0..new_size];
    } else {
        const result = %return globalAlloc(self, new_size, alignment);
        @memcpy(result.ptr, old_mem.ptr, old_mem.len);
        return result;
    }
}

fn globalFree(self: &mem.Allocator, memory: []u8) { }
