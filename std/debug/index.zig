const std = @import("../index.zig");
const math = std.math;
const mem = std.mem;
const io = std.io;
const os = std.os;
const elf = std.elf;
const DW = std.dwarf;
const macho = std.macho;
const ArrayList = std.ArrayList;
const builtin = @import("builtin");

pub const FailingAllocator = @import("failing_allocator.zig").FailingAllocator;

/// Tries to write to stderr, unbuffered, and ignores any error returned.
/// Does not append a newline.
/// TODO atomic/multithread support
var stderr_file: os.File = undefined;
var stderr_file_out_stream: io.FileOutStream = undefined;
var stderr_stream: ?*io.OutStream(io.FileOutStream.Error) = null;
pub fn warn(comptime fmt: []const u8, args: ...) void {
    const stderr = getStderrStream() catch return;
    stderr.print(fmt, args) catch return;
}
fn getStderrStream() !*io.OutStream(io.FileOutStream.Error) {
    if (stderr_stream) |st| {
        return st;
    } else {
        stderr_file = try io.getStdErr();
        stderr_file_out_stream = io.FileOutStream.init(&stderr_file);
        const st = &stderr_file_out_stream.stream;
        stderr_stream = st;
        return st;
    }
}

var self_debug_info: ?*ElfStackTrace = null;
pub fn getSelfDebugInfo() !*ElfStackTrace {
    if (self_debug_info) |info| {
        return info;
    } else {
        const info = try openSelfDebugInfo(getDebugInfoAllocator());
        self_debug_info = info;
        return info;
    }
}

/// Tries to print the current stack trace to stderr, unbuffered, and ignores any error returned.
pub fn dumpCurrentStackTrace(start_addr: ?usize) void {
    const stderr = getStderrStream() catch return;
    const debug_info = getSelfDebugInfo() catch |err| {
        stderr.print("Unable to dump stack trace: Unable to open debug info: {}\n", @errorName(err)) catch return;
        return;
    };
    writeCurrentStackTrace(stderr, getDebugInfoAllocator(), debug_info, stderr_file.isTty(), start_addr) catch |err| {
        stderr.print("Unable to dump stack trace: {}\n", @errorName(err)) catch return;
        return;
    };
}

/// Tries to print a stack trace to stderr, unbuffered, and ignores any error returned.
pub fn dumpStackTrace(stack_trace: *const builtin.StackTrace) void {
    const stderr = getStderrStream() catch return;
    const debug_info = getSelfDebugInfo() catch |err| {
        stderr.print("Unable to dump stack trace: Unable to open debug info: {}\n", @errorName(err)) catch return;
        return;
    };
    writeStackTrace(stack_trace, stderr, getDebugInfoAllocator(), debug_info, stderr_file.isTty()) catch |err| {
        stderr.print("Unable to dump stack trace: {}\n", @errorName(err)) catch return;
        return;
    };
}

/// This function invokes undefined behavior when `ok` is `false`.
/// In Debug and ReleaseSafe modes, calls to this function are always
/// generated, and the `unreachable` statement triggers a panic.
/// In ReleaseFast and ReleaseSmall modes, calls to this function can be
/// optimized away.
pub fn assert(ok: bool) void {
    if (!ok) {
        // In ReleaseFast test mode, we still want assert(false) to crash, so
        // we insert an explicit call to @panic instead of unreachable.
        // TODO we should use `assertOrPanic` in tests and remove this logic.
        if (builtin.is_test) {
            @panic("assertion failure");
        } else {
            unreachable; // assertion failure
        }
    }
}

/// TODO: add `==` operator for `error_union == error_set`, and then
/// remove this function
pub fn assertError(value: var, expected_error: error) void {
    if (value) {
        @panic("expected error");
    } else |actual_error| {
        assert(actual_error == expected_error);
    }
}

/// Call this function when you want to panic if the condition is not true.
/// If `ok` is `false`, this function will panic in every release mode.
pub fn assertOrPanic(ok: bool) void {
    if (!ok) {
        @panic("assertion failure");
    }
}

pub fn panic(comptime format: []const u8, args: ...) noreturn {
    @setCold(true);
    const first_trace_addr = @ptrToInt(@returnAddress());
    panicExtra(null, first_trace_addr, format, args);
}

var panicking: u8 = 0; // TODO make this a bool

pub fn panicExtra(trace: ?*const builtin.StackTrace, first_trace_addr: ?usize, comptime format: []const u8, args: ...) noreturn {
    @setCold(true);

    if (@atomicRmw(u8, &panicking, builtin.AtomicRmwOp.Xchg, 1, builtin.AtomicOrder.SeqCst) == 1) {
        // Panicked during a panic.

        // TODO detect if a different thread caused the panic, because in that case
        // we would want to return here instead of calling abort, so that the thread
        // which first called panic can finish printing a stack trace.
        os.abort();
    }
    const stderr = getStderrStream() catch os.abort();
    stderr.print(format ++ "\n", args) catch os.abort();
    if (trace) |t| {
        dumpStackTrace(t);
    }
    dumpCurrentStackTrace(first_trace_addr);

    os.abort();
}

const GREEN = "\x1b[32;1m";
const WHITE = "\x1b[37;1m";
const DIM = "\x1b[2m";
const RESET = "\x1b[0m";

pub fn writeStackTrace(stack_trace: *const builtin.StackTrace, out_stream: var, allocator: *mem.Allocator, debug_info: *ElfStackTrace, tty_color: bool) !void {
    var frame_index: usize = undefined;
    var frames_left: usize = undefined;
    if (stack_trace.index < stack_trace.instruction_addresses.len) {
        frame_index = 0;
        frames_left = stack_trace.index;
    } else {
        frame_index = (stack_trace.index + 1) % stack_trace.instruction_addresses.len;
        frames_left = stack_trace.instruction_addresses.len;
    }

    while (frames_left != 0) : ({
        frames_left -= 1;
        frame_index = (frame_index + 1) % stack_trace.instruction_addresses.len;
    }) {
        const return_address = stack_trace.instruction_addresses[frame_index];
        try printSourceAtAddress(debug_info, out_stream, return_address, tty_color);
    }
}

pub fn writeCurrentStackTrace(out_stream: var, allocator: *mem.Allocator, debug_info: *ElfStackTrace, tty_color: bool, start_addr: ?usize) !void {
    const AddressState = union(enum) {
        NotLookingForStartAddress,
        LookingForStartAddress: usize,
    };
    // TODO: I want to express like this:
    //var addr_state = if (start_addr) |addr| AddressState { .LookingForStartAddress = addr }
    //    else AddressState.NotLookingForStartAddress;
    var addr_state: AddressState = undefined;
    if (start_addr) |addr| {
        addr_state = AddressState{ .LookingForStartAddress = addr };
    } else {
        addr_state = AddressState.NotLookingForStartAddress;
    }

    var fp = @ptrToInt(@frameAddress());
    while (fp != 0) : (fp = @intToPtr(*const usize, fp).*) {
        const return_address = @intToPtr(*const usize, fp + @sizeOf(usize)).*;

        switch (addr_state) {
            AddressState.NotLookingForStartAddress => {},
            AddressState.LookingForStartAddress => |addr| {
                if (return_address == addr) {
                    addr_state = AddressState.NotLookingForStartAddress;
                } else {
                    continue;
                }
            },
        }
        try printSourceAtAddress(debug_info, out_stream, return_address, tty_color);
    }
}

fn printSourceAtAddress(debug_info: *ElfStackTrace, out_stream: var, address: usize, tty_color: bool) !void {
    switch (builtin.os) {
        builtin.Os.windows => return error.UnsupportedDebugInfo,
        builtin.Os.macosx => {
            // TODO(bnoordhuis) It's theoretically possible to obtain the
            // compilation unit from the symbtab but it's not that useful
            // in practice because the compiler dumps everything in a single
            // object file.  Future improvement: use external dSYM data when
            // available.
            const unknown = macho.Symbol{
                .name = "???",
                .address = address,
            };
            const symbol = debug_info.symbol_table.search(address) orelse &unknown;
            try out_stream.print(WHITE ++ "{}" ++ RESET ++ ": " ++ DIM ++ "0x{x}" ++ " in ??? (???)" ++ RESET ++ "\n", symbol.name, address);
        },
        else => {
            const compile_unit = findCompileUnit(debug_info, address) catch {
                if (tty_color) {
                    try out_stream.print("???:?:?: " ++ DIM ++ "0x{x} in ??? (???)" ++ RESET ++ "\n    ???\n\n", address);
                } else {
                    try out_stream.print("???:?:?: 0x{x} in ??? (???)\n    ???\n\n", address);
                }
                return;
            };
            const compile_unit_name = try compile_unit.die.getAttrString(debug_info, DW.AT_name);
            if (getLineNumberInfo(debug_info, compile_unit, address - 1)) |line_info| {
                defer line_info.deinit();
                if (tty_color) {
                    try out_stream.print(
                        WHITE ++ "{}:{}:{}" ++ RESET ++ ": " ++ DIM ++ "0x{x} in ??? ({})" ++ RESET ++ "\n",
                        line_info.file_name,
                        line_info.line,
                        line_info.column,
                        address,
                        compile_unit_name,
                    );
                    if (printLineFromFile(debug_info.allocator(), out_stream, line_info)) {
                        if (line_info.column == 0) {
                            try out_stream.write("\n");
                        } else {
                            {
                                var col_i: usize = 1;
                                while (col_i < line_info.column) : (col_i += 1) {
                                    try out_stream.writeByte(' ');
                                }
                            }
                            try out_stream.write(GREEN ++ "^" ++ RESET ++ "\n");
                        }
                    } else |err| switch (err) {
                        error.EndOfFile => {},
                        else => return err,
                    }
                } else {
                    try out_stream.print(
                        "{}:{}:{}: 0x{x} in ??? ({})\n",
                        line_info.file_name,
                        line_info.line,
                        line_info.column,
                        address,
                        compile_unit_name,
                    );
                }
            } else |err| switch (err) {
                error.MissingDebugInfo, error.InvalidDebugInfo => {
                    try out_stream.print("0x{x} in ??? ({})\n", address, compile_unit_name);
                },
                else => return err,
            }
        },
    }
}

pub fn openSelfDebugInfo(allocator: *mem.Allocator) !*ElfStackTrace {
    switch (builtin.object_format) {
        builtin.ObjectFormat.elf => {
            const st = try allocator.create(ElfStackTrace{
                .self_exe_file = undefined,
                .elf = undefined,
                .debug_info = undefined,
                .debug_abbrev = undefined,
                .debug_str = undefined,
                .debug_line = undefined,
                .debug_ranges = null,
                .abbrev_table_list = ArrayList(AbbrevTableHeader).init(allocator),
                .compile_unit_list = ArrayList(CompileUnit).init(allocator),
            });
            errdefer allocator.destroy(st);
            st.self_exe_file = try os.openSelfExe();
            errdefer st.self_exe_file.close();

            try st.elf.openFile(allocator, &st.self_exe_file);
            errdefer st.elf.close();

            st.debug_info = (try st.elf.findSection(".debug_info")) orelse return error.MissingDebugInfo;
            st.debug_abbrev = (try st.elf.findSection(".debug_abbrev")) orelse return error.MissingDebugInfo;
            st.debug_str = (try st.elf.findSection(".debug_str")) orelse return error.MissingDebugInfo;
            st.debug_line = (try st.elf.findSection(".debug_line")) orelse return error.MissingDebugInfo;
            st.debug_ranges = (try st.elf.findSection(".debug_ranges"));
            try scanAllCompileUnits(st);
            return st;
        },
        builtin.ObjectFormat.macho => {
            var exe_file = try os.openSelfExe();
            defer exe_file.close();

            const st = try allocator.create(ElfStackTrace{ .symbol_table = try macho.loadSymbols(allocator, &io.FileInStream.init(&exe_file)) });
            errdefer allocator.destroy(st);
            return st;
        },
        builtin.ObjectFormat.coff => {
            return error.TodoSupportCoffDebugInfo;
        },
        builtin.ObjectFormat.wasm => {
            return error.TodoSupportCOFFDebugInfo;
        },
        builtin.ObjectFormat.unknown => {
            return error.UnknownObjectFormat;
        },
    }
}

fn printLineFromFile(allocator: *mem.Allocator, out_stream: var, line_info: *const LineInfo) !void {
    var f = try os.File.openRead(allocator, line_info.file_name);
    defer f.close();
    // TODO fstat and make sure that the file has the correct size

    var buf: [os.page_size]u8 = undefined;
    var line: usize = 1;
    var column: usize = 1;
    var abs_index: usize = 0;
    while (true) {
        const amt_read = try f.read(buf[0..]);
        const slice = buf[0..amt_read];

        for (slice) |byte| {
            if (line == line_info.line) {
                try out_stream.writeByte(byte);
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

        if (amt_read < buf.len) return error.EndOfFile;
    }
}

pub const ElfStackTrace = switch (builtin.os) {
    builtin.Os.macosx => struct {
        symbol_table: macho.SymbolTable,

        pub fn close(self: *ElfStackTrace) void {
            self.symbol_table.deinit();
        }
    },
    else => struct {
        self_exe_file: os.File,
        elf: elf.Elf,
        debug_info: *elf.SectionHeader,
        debug_abbrev: *elf.SectionHeader,
        debug_str: *elf.SectionHeader,
        debug_line: *elf.SectionHeader,
        debug_ranges: ?*elf.SectionHeader,
        abbrev_table_list: ArrayList(AbbrevTableHeader),
        compile_unit_list: ArrayList(CompileUnit),

        pub fn allocator(self: *const ElfStackTrace) *mem.Allocator {
            return self.abbrev_table_list.allocator;
        }

        pub fn readString(self: *ElfStackTrace) ![]u8 {
            var in_file_stream = io.FileInStream.init(&self.self_exe_file);
            const in_stream = &in_file_stream.stream;
            return readStringRaw(self.allocator(), in_stream);
        }

        pub fn close(self: *ElfStackTrace) void {
            self.self_exe_file.close();
            self.elf.close();
        }
    },
};

const PcRange = struct {
    start: u64,
    end: u64,
};

const CompileUnit = struct {
    version: u16,
    is_64: bool,
    die: *Die,
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

    fn asUnsignedLe(self: *const Constant) !u64 {
        if (self.payload.len > @sizeOf(u64)) return error.InvalidDebugInfo;
        if (self.signed) return error.InvalidDebugInfo;
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

    fn getAttr(self: *const Die, id: u64) ?*const FormValue {
        for (self.attrs.toSliceConst()) |*attr| {
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

    fn getAttrString(self: *const Die, st: *ElfStackTrace, id: u64) ![]u8 {
        const form_value = self.getAttr(id) orelse return error.MissingDebugInfo;
        return switch (form_value.*) {
            FormValue.String => |value| value,
            FormValue.StrPtr => |offset| getString(st, offset),
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

const LineInfo = struct {
    line: usize,
    column: usize,
    file_name: []u8,
    allocator: *mem.Allocator,

    fn deinit(self: *const LineInfo) void {
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
    file_entries: *ArrayList(FileEntry),

    prev_address: usize,
    prev_file: usize,
    prev_line: isize,
    prev_column: usize,
    prev_is_stmt: bool,
    prev_basic_block: bool,
    prev_end_sequence: bool,

    pub fn init(is_stmt: bool, include_dirs: []const []const u8, file_entries: *ArrayList(FileEntry), target_address: usize) LineNumberProgram {
        return LineNumberProgram{
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
        };
    }

    pub fn checkLineMatch(self: *LineNumberProgram) !?LineInfo {
        if (self.target_address >= self.prev_address and self.target_address < self.address) {
            const file_entry = if (self.prev_file == 0) {
                return error.MissingDebugInfo;
            } else if (self.prev_file - 1 >= self.file_entries.len) {
                return error.InvalidDebugInfo;
            } else
                &self.file_entries.items[self.prev_file - 1];

            const dir_name = if (file_entry.dir_index >= self.include_dirs.len) {
                return error.InvalidDebugInfo;
            } else
                self.include_dirs[file_entry.dir_index];
            const file_name = try os.path.join(self.file_entries.allocator, dir_name, file_entry.file_name);
            errdefer self.file_entries.allocator.free(file_name);
            return LineInfo{
                .line = if (self.prev_line >= 0) @intCast(usize, self.prev_line) else 0,
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

fn readStringRaw(allocator: *mem.Allocator, in_stream: var) ![]u8 {
    var buf = ArrayList(u8).init(allocator);
    while (true) {
        const byte = try in_stream.readByte();
        if (byte == 0) break;
        try buf.append(byte);
    }
    return buf.toSlice();
}

fn getString(st: *ElfStackTrace, offset: u64) ![]u8 {
    const pos = st.debug_str.offset + offset;
    try st.self_exe_file.seekTo(pos);
    return st.readString();
}

fn readAllocBytes(allocator: *mem.Allocator, in_stream: var, size: usize) ![]u8 {
    const buf = try allocator.alloc(u8, size);
    errdefer allocator.free(buf);
    if ((try in_stream.read(buf)) < size) return error.EndOfFile;
    return buf;
}

fn parseFormValueBlockLen(allocator: *mem.Allocator, in_stream: var, size: usize) !FormValue {
    const buf = try readAllocBytes(allocator, in_stream, size);
    return FormValue{ .Block = buf };
}

fn parseFormValueBlock(allocator: *mem.Allocator, in_stream: var, size: usize) !FormValue {
    const block_len = try in_stream.readVarInt(builtin.Endian.Little, usize, size);
    return parseFormValueBlockLen(allocator, in_stream, block_len);
}

fn parseFormValueConstant(allocator: *mem.Allocator, in_stream: var, signed: bool, size: usize) !FormValue {
    return FormValue{
        .Const = Constant{
            .signed = signed,
            .payload = try readAllocBytes(allocator, in_stream, size),
        },
    };
}

fn parseFormValueDwarfOffsetSize(in_stream: var, is_64: bool) !u64 {
    return if (is_64) try in_stream.readIntLe(u64) else u64(try in_stream.readIntLe(u32));
}

fn parseFormValueTargetAddrSize(in_stream: var) !u64 {
    return if (@sizeOf(usize) == 4) u64(try in_stream.readIntLe(u32)) else if (@sizeOf(usize) == 8) try in_stream.readIntLe(u64) else unreachable;
}

fn parseFormValueRefLen(allocator: *mem.Allocator, in_stream: var, size: usize) !FormValue {
    const buf = try readAllocBytes(allocator, in_stream, size);
    return FormValue{ .Ref = buf };
}

fn parseFormValueRef(allocator: *mem.Allocator, in_stream: var, comptime T: type) !FormValue {
    const block_len = try in_stream.readIntLe(T);
    return parseFormValueRefLen(allocator, in_stream, block_len);
}

const ParseFormValueError = error{
    EndOfStream,
    Io,
    BadFd,
    Unexpected,
    InvalidDebugInfo,
    EndOfFile,
    IsDir,
    OutOfMemory,
};

fn parseFormValue(allocator: *mem.Allocator, in_stream: var, form_id: u64, is_64: bool) ParseFormValueError!FormValue {
    return switch (form_id) {
        DW.FORM_addr => FormValue{ .Address = try parseFormValueTargetAddrSize(in_stream) },
        DW.FORM_block1 => parseFormValueBlock(allocator, in_stream, 1),
        DW.FORM_block2 => parseFormValueBlock(allocator, in_stream, 2),
        DW.FORM_block4 => parseFormValueBlock(allocator, in_stream, 4),
        DW.FORM_block => x: {
            const block_len = try readULeb128(in_stream);
            return parseFormValueBlockLen(allocator, in_stream, block_len);
        },
        DW.FORM_data1 => parseFormValueConstant(allocator, in_stream, false, 1),
        DW.FORM_data2 => parseFormValueConstant(allocator, in_stream, false, 2),
        DW.FORM_data4 => parseFormValueConstant(allocator, in_stream, false, 4),
        DW.FORM_data8 => parseFormValueConstant(allocator, in_stream, false, 8),
        DW.FORM_udata, DW.FORM_sdata => {
            const block_len = try readULeb128(in_stream);
            const signed = form_id == DW.FORM_sdata;
            return parseFormValueConstant(allocator, in_stream, signed, block_len);
        },
        DW.FORM_exprloc => {
            const size = try readULeb128(in_stream);
            const buf = try readAllocBytes(allocator, in_stream, size);
            return FormValue{ .ExprLoc = buf };
        },
        DW.FORM_flag => FormValue{ .Flag = (try in_stream.readByte()) != 0 },
        DW.FORM_flag_present => FormValue{ .Flag = true },
        DW.FORM_sec_offset => FormValue{ .SecOffset = try parseFormValueDwarfOffsetSize(in_stream, is_64) },

        DW.FORM_ref1 => parseFormValueRef(allocator, in_stream, u8),
        DW.FORM_ref2 => parseFormValueRef(allocator, in_stream, u16),
        DW.FORM_ref4 => parseFormValueRef(allocator, in_stream, u32),
        DW.FORM_ref8 => parseFormValueRef(allocator, in_stream, u64),
        DW.FORM_ref_udata => {
            const ref_len = try readULeb128(in_stream);
            return parseFormValueRefLen(allocator, in_stream, ref_len);
        },

        DW.FORM_ref_addr => FormValue{ .RefAddr = try parseFormValueDwarfOffsetSize(in_stream, is_64) },
        DW.FORM_ref_sig8 => FormValue{ .RefSig8 = try in_stream.readIntLe(u64) },

        DW.FORM_string => FormValue{ .String = try readStringRaw(allocator, in_stream) },
        DW.FORM_strp => FormValue{ .StrPtr = try parseFormValueDwarfOffsetSize(in_stream, is_64) },
        DW.FORM_indirect => {
            const child_form_id = try readULeb128(in_stream);
            return parseFormValue(allocator, in_stream, child_form_id, is_64);
        },
        else => error.InvalidDebugInfo,
    };
}

fn parseAbbrevTable(st: *ElfStackTrace) !AbbrevTable {
    const in_file = &st.self_exe_file;
    var in_file_stream = io.FileInStream.init(in_file);
    const in_stream = &in_file_stream.stream;
    var result = AbbrevTable.init(st.allocator());
    while (true) {
        const abbrev_code = try readULeb128(in_stream);
        if (abbrev_code == 0) return result;
        try result.append(AbbrevTableEntry{
            .abbrev_code = abbrev_code,
            .tag_id = try readULeb128(in_stream),
            .has_children = (try in_stream.readByte()) == DW.CHILDREN_yes,
            .attrs = ArrayList(AbbrevAttr).init(st.allocator()),
        });
        const attrs = &result.items[result.len - 1].attrs;

        while (true) {
            const attr_id = try readULeb128(in_stream);
            const form_id = try readULeb128(in_stream);
            if (attr_id == 0 and form_id == 0) break;
            try attrs.append(AbbrevAttr{
                .attr_id = attr_id,
                .form_id = form_id,
            });
        }
    }
}

/// Gets an already existing AbbrevTable given the abbrev_offset, or if not found,
/// seeks in the stream and parses it.
fn getAbbrevTable(st: *ElfStackTrace, abbrev_offset: u64) !*const AbbrevTable {
    for (st.abbrev_table_list.toSlice()) |*header| {
        if (header.offset == abbrev_offset) {
            return &header.table;
        }
    }
    try st.self_exe_file.seekTo(st.debug_abbrev.offset + abbrev_offset);
    try st.abbrev_table_list.append(AbbrevTableHeader{
        .offset = abbrev_offset,
        .table = try parseAbbrevTable(st),
    });
    return &st.abbrev_table_list.items[st.abbrev_table_list.len - 1].table;
}

fn getAbbrevTableEntry(abbrev_table: *const AbbrevTable, abbrev_code: u64) ?*const AbbrevTableEntry {
    for (abbrev_table.toSliceConst()) |*table_entry| {
        if (table_entry.abbrev_code == abbrev_code) return table_entry;
    }
    return null;
}

fn parseDie(st: *ElfStackTrace, abbrev_table: *const AbbrevTable, is_64: bool) !Die {
    const in_file = &st.self_exe_file;
    var in_file_stream = io.FileInStream.init(in_file);
    const in_stream = &in_file_stream.stream;
    const abbrev_code = try readULeb128(in_stream);
    const table_entry = getAbbrevTableEntry(abbrev_table, abbrev_code) orelse return error.InvalidDebugInfo;

    var result = Die{
        .tag_id = table_entry.tag_id,
        .has_children = table_entry.has_children,
        .attrs = ArrayList(Die.Attr).init(st.allocator()),
    };
    try result.attrs.resize(table_entry.attrs.len);
    for (table_entry.attrs.toSliceConst()) |attr, i| {
        result.attrs.items[i] = Die.Attr{
            .id = attr.attr_id,
            .value = try parseFormValue(st.allocator(), in_stream, attr.form_id, is_64),
        };
    }
    return result;
}

fn getLineNumberInfo(st: *ElfStackTrace, compile_unit: *const CompileUnit, target_address: usize) !LineInfo {
    const compile_unit_cwd = try compile_unit.die.getAttrString(st, DW.AT_comp_dir);

    const in_file = &st.self_exe_file;
    const debug_line_end = st.debug_line.offset + st.debug_line.size;
    var this_offset = st.debug_line.offset;
    var this_index: usize = 0;

    var in_file_stream = io.FileInStream.init(in_file);
    const in_stream = &in_file_stream.stream;

    while (this_offset < debug_line_end) : (this_index += 1) {
        try in_file.seekTo(this_offset);

        var is_64: bool = undefined;
        const unit_length = try readInitialLength(@typeOf(in_stream.readFn).ReturnType.ErrorSet, in_stream, &is_64);
        if (unit_length == 0) return error.MissingDebugInfo;
        const next_offset = unit_length + (if (is_64) usize(12) else usize(4));

        if (compile_unit.index != this_index) {
            this_offset += next_offset;
            continue;
        }

        const version = try in_stream.readInt(st.elf.endian, u16);
        // TODO support 3 and 5
        if (version != 2 and version != 4) return error.InvalidDebugInfo;

        const prologue_length = if (is_64) try in_stream.readInt(st.elf.endian, u64) else try in_stream.readInt(st.elf.endian, u32);
        const prog_start_offset = (try in_file.getPos()) + prologue_length;

        const minimum_instruction_length = try in_stream.readByte();
        if (minimum_instruction_length == 0) return error.InvalidDebugInfo;

        if (version >= 4) {
            // maximum_operations_per_instruction
            _ = try in_stream.readByte();
        }

        const default_is_stmt = (try in_stream.readByte()) != 0;
        const line_base = try in_stream.readByteSigned();

        const line_range = try in_stream.readByte();
        if (line_range == 0) return error.InvalidDebugInfo;

        const opcode_base = try in_stream.readByte();

        const standard_opcode_lengths = try st.allocator().alloc(u8, opcode_base - 1);

        {
            var i: usize = 0;
            while (i < opcode_base - 1) : (i += 1) {
                standard_opcode_lengths[i] = try in_stream.readByte();
            }
        }

        var include_directories = ArrayList([]u8).init(st.allocator());
        try include_directories.append(compile_unit_cwd);
        while (true) {
            const dir = try st.readString();
            if (dir.len == 0) break;
            try include_directories.append(dir);
        }

        var file_entries = ArrayList(FileEntry).init(st.allocator());
        var prog = LineNumberProgram.init(default_is_stmt, include_directories.toSliceConst(), &file_entries, target_address);

        while (true) {
            const file_name = try st.readString();
            if (file_name.len == 0) break;
            const dir_index = try readULeb128(in_stream);
            const mtime = try readULeb128(in_stream);
            const len_bytes = try readULeb128(in_stream);
            try file_entries.append(FileEntry{
                .file_name = file_name,
                .dir_index = dir_index,
                .mtime = mtime,
                .len_bytes = len_bytes,
            });
        }

        try in_file.seekTo(prog_start_offset);

        while (true) {
            const opcode = try in_stream.readByte();

            var sub_op: u8 = undefined; // TODO move this to the correct scope and fix the compiler crash
            if (opcode == DW.LNS_extended_op) {
                const op_size = try readULeb128(in_stream);
                if (op_size < 1) return error.InvalidDebugInfo;
                sub_op = try in_stream.readByte();
                switch (sub_op) {
                    DW.LNE_end_sequence => {
                        prog.end_sequence = true;
                        if (try prog.checkLineMatch()) |info| return info;
                        return error.MissingDebugInfo;
                    },
                    DW.LNE_set_address => {
                        const addr = try in_stream.readInt(st.elf.endian, usize);
                        prog.address = addr;
                    },
                    DW.LNE_define_file => {
                        const file_name = try st.readString();
                        const dir_index = try readULeb128(in_stream);
                        const mtime = try readULeb128(in_stream);
                        const len_bytes = try readULeb128(in_stream);
                        try file_entries.append(FileEntry{
                            .file_name = file_name,
                            .dir_index = dir_index,
                            .mtime = mtime,
                            .len_bytes = len_bytes,
                        });
                    },
                    else => {
                        const fwd_amt = math.cast(isize, op_size - 1) catch return error.InvalidDebugInfo;
                        try in_file.seekForward(fwd_amt);
                    },
                }
            } else if (opcode >= opcode_base) {
                // special opcodes
                const adjusted_opcode = opcode - opcode_base;
                const inc_addr = minimum_instruction_length * (adjusted_opcode / line_range);
                const inc_line = i32(line_base) + i32(adjusted_opcode % line_range);
                prog.line += inc_line;
                prog.address += inc_addr;
                if (try prog.checkLineMatch()) |info| return info;
                prog.basic_block = false;
            } else {
                switch (opcode) {
                    DW.LNS_copy => {
                        if (try prog.checkLineMatch()) |info| return info;
                        prog.basic_block = false;
                    },
                    DW.LNS_advance_pc => {
                        const arg = try readULeb128(in_stream);
                        prog.address += arg * minimum_instruction_length;
                    },
                    DW.LNS_advance_line => {
                        const arg = try readILeb128(in_stream);
                        prog.line += arg;
                    },
                    DW.LNS_set_file => {
                        const arg = try readULeb128(in_stream);
                        prog.file = arg;
                    },
                    DW.LNS_set_column => {
                        const arg = try readULeb128(in_stream);
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
                        const arg = try in_stream.readInt(st.elf.endian, u16);
                        prog.address += arg;
                    },
                    DW.LNS_set_prologue_end => {},
                    else => {
                        if (opcode - 1 >= standard_opcode_lengths.len) return error.InvalidDebugInfo;
                        const len_bytes = standard_opcode_lengths[opcode - 1];
                        try in_file.seekForward(len_bytes);
                    },
                }
            }
        }

        this_offset += next_offset;
    }

    return error.MissingDebugInfo;
}

fn scanAllCompileUnits(st: *ElfStackTrace) !void {
    const debug_info_end = st.debug_info.offset + st.debug_info.size;
    var this_unit_offset = st.debug_info.offset;
    var cu_index: usize = 0;

    var in_file_stream = io.FileInStream.init(&st.self_exe_file);
    const in_stream = &in_file_stream.stream;

    while (this_unit_offset < debug_info_end) {
        try st.self_exe_file.seekTo(this_unit_offset);

        var is_64: bool = undefined;
        const unit_length = try readInitialLength(@typeOf(in_stream.readFn).ReturnType.ErrorSet, in_stream, &is_64);
        if (unit_length == 0) return;
        const next_offset = unit_length + (if (is_64) usize(12) else usize(4));

        const version = try in_stream.readInt(st.elf.endian, u16);
        if (version < 2 or version > 5) return error.InvalidDebugInfo;

        const debug_abbrev_offset = if (is_64) try in_stream.readInt(st.elf.endian, u64) else try in_stream.readInt(st.elf.endian, u32);

        const address_size = try in_stream.readByte();
        if (address_size != @sizeOf(usize)) return error.InvalidDebugInfo;

        const compile_unit_pos = try st.self_exe_file.getPos();
        const abbrev_table = try getAbbrevTable(st, debug_abbrev_offset);

        try st.self_exe_file.seekTo(compile_unit_pos);

        const compile_unit_die = try st.allocator().create(try parseDie(st, abbrev_table, is_64));

        if (compile_unit_die.tag_id != DW.TAG_compile_unit) return error.InvalidDebugInfo;

        const pc_range = x: {
            if (compile_unit_die.getAttrAddr(DW.AT_low_pc)) |low_pc| {
                if (compile_unit_die.getAttr(DW.AT_high_pc)) |high_pc_value| {
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

        try st.compile_unit_list.append(CompileUnit{
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

fn findCompileUnit(st: *ElfStackTrace, target_address: u64) !*const CompileUnit {
    var in_file_stream = io.FileInStream.init(&st.self_exe_file);
    const in_stream = &in_file_stream.stream;
    for (st.compile_unit_list.toSlice()) |*compile_unit| {
        if (compile_unit.pc_range) |range| {
            if (target_address >= range.start and target_address < range.end) return compile_unit;
        }
        if (compile_unit.die.getAttrSecOffset(DW.AT_ranges)) |ranges_offset| {
            var base_address: usize = 0;
            if (st.debug_ranges) |debug_ranges| {
                try st.self_exe_file.seekTo(debug_ranges.offset + ranges_offset);
                while (true) {
                    const begin_addr = try in_stream.readIntLe(usize);
                    const end_addr = try in_stream.readIntLe(usize);
                    if (begin_addr == 0 and end_addr == 0) {
                        break;
                    }
                    if (begin_addr == @maxValue(usize)) {
                        base_address = begin_addr;
                        continue;
                    }
                    if (target_address >= begin_addr and target_address < end_addr) {
                        return compile_unit;
                    }
                }
            }
        } else |err| {
            if (err != error.MissingDebugInfo) return err;
            continue;
        }
    }
    return error.MissingDebugInfo;
}

fn readInitialLength(comptime E: type, in_stream: *io.InStream(E), is_64: *bool) !u64 {
    const first_32_bits = try in_stream.readIntLe(u32);
    is_64.* = (first_32_bits == 0xffffffff);
    if (is_64.*) {
        return in_stream.readIntLe(u64);
    } else {
        if (first_32_bits >= 0xfffffff0) return error.InvalidDebugInfo;
        return u64(first_32_bits);
    }
}

fn readULeb128(in_stream: var) !u64 {
    var result: u64 = 0;
    var shift: usize = 0;

    while (true) {
        const byte = try in_stream.readByte();

        var operand: u64 = undefined;

        if (@shlWithOverflow(u64, byte & 0b01111111, @intCast(u6, shift), &operand)) return error.InvalidDebugInfo;

        result |= operand;

        if ((byte & 0b10000000) == 0) return result;

        shift += 7;
    }
}

fn readILeb128(in_stream: var) !i64 {
    var result: i64 = 0;
    var shift: usize = 0;

    while (true) {
        const byte = try in_stream.readByte();

        var operand: i64 = undefined;

        if (@shlWithOverflow(i64, byte & 0b01111111, @intCast(u6, shift), &operand)) return error.InvalidDebugInfo;

        result |= operand;
        shift += 7;

        if ((byte & 0b10000000) == 0) {
            if (shift < @sizeOf(i64) * 8 and (byte & 0b01000000) != 0) result |= -(i64(1) << @intCast(u6, shift));
            return result;
        }
    }
}

/// This should only be used in temporary test programs.
pub const global_allocator = &global_fixed_allocator.allocator;
var global_fixed_allocator = std.heap.FixedBufferAllocator.init(global_allocator_mem[0..]);
var global_allocator_mem: [100 * 1024]u8 = undefined;

// TODO make thread safe
var debug_info_allocator: ?*mem.Allocator = null;
var debug_info_direct_allocator: std.heap.DirectAllocator = undefined;
var debug_info_arena_allocator: std.heap.ArenaAllocator = undefined;
fn getDebugInfoAllocator() *mem.Allocator {
    if (debug_info_allocator) |a| return a;

    debug_info_direct_allocator = std.heap.DirectAllocator.init();
    debug_info_arena_allocator = std.heap.ArenaAllocator.init(&debug_info_direct_allocator.allocator);
    debug_info_allocator = &debug_info_arena_allocator.allocator;
    return &debug_info_arena_allocator.allocator;
}
