const std = @import("../index.zig");
const math = std.math;
const mem = std.mem;
const io = std.io;
const os = std.os;
const elf = std.elf;
const DW = std.dwarf;
const macho = std.macho;
const coff = std.coff;
const pdb = std.pdb;
const windows = os.windows;
const ArrayList = std.ArrayList;
const builtin = @import("builtin");

pub const FailingAllocator = @import("failing_allocator.zig").FailingAllocator;
pub const failing_allocator = FailingAllocator.init(global_allocator, 0);

pub const runtime_safety = switch (builtin.mode) {
    builtin.Mode.Debug, builtin.Mode.ReleaseSafe => true,
    builtin.Mode.ReleaseFast, builtin.Mode.ReleaseSmall => false,
};

const Module = struct {
    mod_info: pdb.ModInfo,
    module_name: []u8,
    obj_file_name: []u8,

    populated: bool,
    symbols: []u8,
    subsect_info: []u8,
    checksum_offset: ?usize,
};

/// Tries to write to stderr, unbuffered, and ignores any error returned.
/// Does not append a newline.
var stderr_file: os.File = undefined;
var stderr_file_out_stream: io.FileOutStream = undefined;

/// TODO multithreaded awareness
var stderr_stream: ?*io.OutStream(io.FileOutStream.Error) = null;
var stderr_mutex = std.Mutex.init();
pub fn warn(comptime fmt: []const u8, args: ...) void {
    const held = stderr_mutex.acquire();
    defer held.release();
    const stderr = getStderrStream() catch return;
    stderr.print(fmt, args) catch return;
}

pub fn getStderrStream() !*io.OutStream(io.FileOutStream.Error) {
    if (stderr_stream) |st| {
        return st;
    } else {
        stderr_file = try io.getStdErr();
        stderr_file_out_stream = io.FileOutStream.init(stderr_file);
        const st = &stderr_file_out_stream.stream;
        stderr_stream = st;
        return st;
    }
}

/// TODO multithreaded awareness
var self_debug_info: ?DebugInfo = null;

pub fn getSelfDebugInfo() !*DebugInfo {
    if (self_debug_info) |*info| {
        return info;
    } else {
        self_debug_info = try openSelfDebugInfo(getDebugInfoAllocator());
        return &self_debug_info.?;
    }
}

fn wantTtyColor() bool {
    var bytes: [128]u8 = undefined;
    const allocator = &std.heap.FixedBufferAllocator.init(bytes[0..]).allocator;
    return if (std.os.getEnvVarOwned(allocator, "ZIG_DEBUG_COLOR")) |_| true else |_| stderr_file.isTty();
}

/// Tries to print the current stack trace to stderr, unbuffered, and ignores any error returned.
/// TODO multithreaded awareness
pub fn dumpCurrentStackTrace(start_addr: ?usize) void {
    const stderr = getStderrStream() catch return;
    const debug_info = getSelfDebugInfo() catch |err| {
        stderr.print("Unable to dump stack trace: Unable to open debug info: {}\n", @errorName(err)) catch return;
        return;
    };
    writeCurrentStackTrace(stderr, debug_info, wantTtyColor(), start_addr) catch |err| {
        stderr.print("Unable to dump stack trace: {}\n", @errorName(err)) catch return;
        return;
    };
}

/// Tries to print a stack trace to stderr, unbuffered, and ignores any error returned.
/// TODO multithreaded awareness
pub fn dumpStackTrace(stack_trace: *const builtin.StackTrace) void {
    const stderr = getStderrStream() catch return;
    const debug_info = getSelfDebugInfo() catch |err| {
        stderr.print("Unable to dump stack trace: Unable to open debug info: {}\n", @errorName(err)) catch return;
        return;
    };
    writeStackTrace(stack_trace, stderr, getDebugInfoAllocator(), debug_info, wantTtyColor()) catch |err| {
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

/// TODO multithreaded awareness
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

pub fn writeStackTrace(stack_trace: *const builtin.StackTrace, out_stream: var, allocator: *mem.Allocator, debug_info: *DebugInfo, tty_color: bool) !void {
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

pub inline fn getReturnAddress(frame_count: usize) usize {
    var fp = @ptrToInt(@frameAddress());
    var i: usize = 0;
    while (fp != 0 and i < frame_count) {
        fp = @intToPtr(*const usize, fp).*;
        i += 1;
    }
    return @intToPtr(*const usize, fp + @sizeOf(usize)).*;
}

pub fn writeCurrentStackTrace(out_stream: var, debug_info: *DebugInfo, tty_color: bool, start_addr: ?usize) !void {
    switch (builtin.os) {
        builtin.Os.windows => return writeCurrentStackTraceWindows(out_stream, debug_info, tty_color, start_addr),
        else => {},
    }
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

pub fn writeCurrentStackTraceWindows(out_stream: var, debug_info: *DebugInfo,
    tty_color: bool, start_addr: ?usize) !void
{
    var addr_buf: [1024]usize = undefined;
    const casted_len = @intCast(u32, addr_buf.len); // TODO shouldn't need this cast
    const n = windows.RtlCaptureStackBackTrace(0, casted_len, @ptrCast(**c_void, &addr_buf), null);
    const addrs = addr_buf[0..n];
    var start_i: usize = if (start_addr) |saddr| blk: {
        for (addrs) |addr, i| {
            if (addr == saddr) break :blk i;
        }
        return;
    } else 0;
    for (addrs[start_i..]) |addr| {
        try printSourceAtAddress(debug_info, out_stream, addr, tty_color);
    }
}

pub fn printSourceAtAddress(debug_info: *DebugInfo, out_stream: var, address: usize, tty_color: bool) !void {
    switch (builtin.os) {
        builtin.Os.macosx => return printSourceAtAddressMacOs(debug_info, out_stream, address, tty_color),
        builtin.Os.linux => return printSourceAtAddressLinux(debug_info, out_stream, address, tty_color),
        builtin.Os.windows => return printSourceAtAddressWindows(debug_info, out_stream, address, tty_color),
        else => return error.UnsupportedOperatingSystem,
    }
}

fn printSourceAtAddressWindows(di: *DebugInfo, out_stream: var, relocated_address: usize, tty_color: bool) !void {
    const allocator = getDebugInfoAllocator();
    const base_address = os.getBaseAddress();
    const relative_address = relocated_address - base_address;

    var coff_section: *coff.Section = undefined;
    const mod_index = for (di.sect_contribs) |sect_contrib| {
        if (sect_contrib.Section >= di.coff.sections.len) continue;
        coff_section = &di.coff.sections.toSlice()[sect_contrib.Section];

        const vaddr_start = coff_section.header.virtual_address + sect_contrib.Offset;
        const vaddr_end = vaddr_start + sect_contrib.Size;
        if (relative_address >= vaddr_start and relative_address < vaddr_end) {
            break sect_contrib.ModuleIndex;
        }
    } else {
        // we have no information to add to the address
        if (tty_color) {
            try out_stream.print("???:?:?: ");
            setTtyColor(TtyColor.Dim);
            try out_stream.print("0x{x} in ??? (???)", relocated_address);
            setTtyColor(TtyColor.Reset);
            try out_stream.print("\n\n\n");
        } else {
            try out_stream.print("???:?:?: 0x{x} in ??? (???)\n\n\n", relocated_address);
        }
        return;
    };

    const mod = &di.modules[mod_index];
    try populateModule(di, mod);
    const obj_basename = os.path.basename(mod.obj_file_name);

    var symbol_i: usize = 0;
    const symbol_name = while (symbol_i != mod.symbols.len) {
        const prefix = @ptrCast(*pdb.RecordPrefix, &mod.symbols[symbol_i]);
        if (prefix.RecordLen < 2)
            return error.InvalidDebugInfo;
        switch (prefix.RecordKind) {
            pdb.SymbolKind.S_LPROC32 => {
                const proc_sym = @ptrCast(*pdb.ProcSym, &mod.symbols[symbol_i + @sizeOf(pdb.RecordPrefix)]);
                const vaddr_start = coff_section.header.virtual_address + proc_sym.CodeOffset;
                const vaddr_end = vaddr_start + proc_sym.CodeSize;
                if (relative_address >= vaddr_start and relative_address < vaddr_end) {
                    break mem.toSliceConst(u8, @ptrCast([*]u8, proc_sym) + @sizeOf(pdb.ProcSym));
                }
            },
            else => {},
        }
        symbol_i += prefix.RecordLen + @sizeOf(u16);
        if (symbol_i > mod.symbols.len)
            return error.InvalidDebugInfo;
    } else "???";

    const subsect_info = mod.subsect_info;

    var sect_offset: usize = 0;
    var skip_len: usize = undefined;
    const opt_line_info = subsections: {
        const checksum_offset = mod.checksum_offset orelse break :subsections null;
        while (sect_offset != subsect_info.len) : (sect_offset += skip_len) {
            const subsect_hdr = @ptrCast(*pdb.DebugSubsectionHeader, &subsect_info[sect_offset]);
            skip_len = subsect_hdr.Length;
            sect_offset += @sizeOf(pdb.DebugSubsectionHeader);

            switch (subsect_hdr.Kind) {
                pdb.DebugSubsectionKind.Lines => {
                    var line_index: usize = sect_offset;

                    const line_hdr = @ptrCast(*pdb.LineFragmentHeader, &subsect_info[line_index]);
                    if (line_hdr.RelocSegment == 0) return error.MissingDebugInfo;
                    line_index += @sizeOf(pdb.LineFragmentHeader);

                    const block_hdr = @ptrCast(*pdb.LineBlockFragmentHeader, &subsect_info[line_index]);
                    line_index += @sizeOf(pdb.LineBlockFragmentHeader);

                    const has_column = line_hdr.Flags.LF_HaveColumns;

                    const frag_vaddr_start = coff_section.header.virtual_address + line_hdr.RelocOffset;
                    const frag_vaddr_end = frag_vaddr_start + line_hdr.CodeSize;
                    if (relative_address >= frag_vaddr_start and relative_address < frag_vaddr_end) {
                        var line_i: usize = 0;
                        const start_line_index = line_index;
                        while (line_i < block_hdr.NumLines) : (line_i += 1) {
                            const line_num_entry = @ptrCast(*pdb.LineNumberEntry, &subsect_info[line_index]);
                            line_index += @sizeOf(pdb.LineNumberEntry);
                            const flags = @ptrCast(*pdb.LineNumberEntry.Flags, &line_num_entry.Flags);
                            const vaddr_start = frag_vaddr_start + line_num_entry.Offset;
                            const vaddr_end = if (flags.End == 0) frag_vaddr_end else vaddr_start + flags.End;
                            if (relative_address >= vaddr_start and relative_address < vaddr_end) {
                                const subsect_index = checksum_offset + block_hdr.NameIndex;
                                const chksum_hdr = @ptrCast(*pdb.FileChecksumEntryHeader, &mod.subsect_info[subsect_index]);
                                const strtab_offset = @sizeOf(pdb.PDBStringTableHeader) + chksum_hdr.FileNameOffset;
                                try di.pdb.string_table.seekTo(strtab_offset);
                                const source_file_name = try di.pdb.string_table.readNullTermString(allocator);
                                const line = flags.Start;
                                const column = if (has_column) blk: {
                                    line_index = start_line_index + @sizeOf(pdb.LineNumberEntry) * block_hdr.NumLines;
                                    line_index += @sizeOf(pdb.ColumnNumberEntry) * line_i;
                                    const col_num_entry = @ptrCast(*pdb.ColumnNumberEntry, &subsect_info[line_index]);
                                    break :blk col_num_entry.StartColumn;
                                } else 0;
                                break :subsections LineInfo{
                                    .allocator = allocator,
                                    .file_name = source_file_name,
                                    .line = line,
                                    .column = column,
                                };
                            }
                        }
                        break :subsections null;
                    }
                },
                else => {},
            }

            if (sect_offset > subsect_info.len)
                return error.InvalidDebugInfo;
        } else {
            break :subsections null;
        }
    };
    
    if (tty_color) {
        setTtyColor(TtyColor.White);
        if (opt_line_info) |li| {
            try out_stream.print("{}:{}:{}", li.file_name, li.line, li.column);
        } else {
            try out_stream.print("???:?:?");
        }
        setTtyColor(TtyColor.Reset);
        try out_stream.print(": ");
        setTtyColor(TtyColor.Dim);
        try out_stream.print("0x{x} in {} ({})", relocated_address, symbol_name, obj_basename);
        setTtyColor(TtyColor.Reset);

        if (opt_line_info) |line_info| {
            try out_stream.print("\n");
            if (printLineFromFile(out_stream, line_info)) {
                if (line_info.column == 0) {
                    try out_stream.write("\n");
                } else {
                    {
                        var col_i: usize = 1;
                        while (col_i < line_info.column) : (col_i += 1) {
                            try out_stream.writeByte(' ');
                        }
                    }
                    setTtyColor(TtyColor.Green);
                    try out_stream.write("^");
                    setTtyColor(TtyColor.Reset);
                    try out_stream.write("\n");
                }
            } else |err| switch (err) {
                error.EndOfFile => {},
                else => return err,
            }
        } else {
            try out_stream.print("\n\n\n");
        }
    } else {
        if (opt_line_info) |li| {
            try out_stream.print("{}:{}:{}: 0x{x} in {} ({})\n\n\n", li.file_name, li.line, li.column, relocated_address, symbol_name, obj_basename);
        } else {
            try out_stream.print("???:?:?: 0x{x} in {} ({})\n\n\n", relocated_address, symbol_name, obj_basename);
        }
    }
}

const TtyColor = enum{
    Red,
    Green,
    Cyan,
    White,
    Dim,
    Bold,
    Reset,
};

/// TODO this is a special case hack right now. clean it up and maybe make it part of std.fmt
fn setTtyColor(tty_color: TtyColor) void {
    const S = struct {
        var attrs: windows.WORD = undefined;
        var init_attrs = false;
    };
    if (!S.init_attrs) {
        S.init_attrs = true;
        var info: windows.CONSOLE_SCREEN_BUFFER_INFO = undefined;
        // TODO handle error
        _ = windows.GetConsoleScreenBufferInfo(stderr_file.handle, &info);
        S.attrs = info.wAttributes;
    }

    // TODO handle errors
    switch (tty_color) {
        TtyColor.Red => {
            _ = windows.SetConsoleTextAttribute(stderr_file.handle, windows.FOREGROUND_RED|windows.FOREGROUND_INTENSITY);
        },
        TtyColor.Green => {
            _ = windows.SetConsoleTextAttribute(stderr_file.handle, windows.FOREGROUND_GREEN|windows.FOREGROUND_INTENSITY);
        },
        TtyColor.Cyan => {
            _ = windows.SetConsoleTextAttribute(stderr_file.handle,
                windows.FOREGROUND_GREEN|windows.FOREGROUND_BLUE|windows.FOREGROUND_INTENSITY);
        },
        TtyColor.White, TtyColor.Bold => {
            _ = windows.SetConsoleTextAttribute(stderr_file.handle,
                windows.FOREGROUND_RED|windows.FOREGROUND_GREEN|windows.FOREGROUND_BLUE|windows.FOREGROUND_INTENSITY);
        },
        TtyColor.Dim => {
            _ = windows.SetConsoleTextAttribute(stderr_file.handle, windows.FOREGROUND_INTENSITY);
        },
        TtyColor.Reset => {
            _ = windows.SetConsoleTextAttribute(stderr_file.handle, S.attrs);
        },
    }
}

fn populateModule(di: *DebugInfo, mod: *Module) !void {
    if (mod.populated)
        return;
    const allocator = getDebugInfoAllocator();

    if (mod.mod_info.C11ByteSize != 0)
        return error.InvalidDebugInfo;

    if (mod.mod_info.C13ByteSize == 0)
        return error.MissingDebugInfo;

    const modi = di.pdb.getStreamById(mod.mod_info.ModuleSymStream) orelse return error.MissingDebugInfo;

    const signature = try modi.stream.readIntLe(u32);
    if (signature != 4)
        return error.InvalidDebugInfo;

    mod.symbols = try allocator.alloc(u8, mod.mod_info.SymByteSize - 4);
    try modi.stream.readNoEof(mod.symbols);

    mod.subsect_info = try allocator.alloc(u8, mod.mod_info.C13ByteSize);
    try modi.stream.readNoEof(mod.subsect_info);

    var sect_offset: usize = 0;
    var skip_len: usize = undefined;
    while (sect_offset != mod.subsect_info.len) : (sect_offset += skip_len) {
        const subsect_hdr = @ptrCast(*pdb.DebugSubsectionHeader, &mod.subsect_info[sect_offset]);
        skip_len = subsect_hdr.Length;
        sect_offset += @sizeOf(pdb.DebugSubsectionHeader);

        switch (subsect_hdr.Kind) {
            pdb.DebugSubsectionKind.FileChecksums => {
                mod.checksum_offset = sect_offset;
                break;
            },
            else => {},
        }

        if (sect_offset > mod.subsect_info.len)
            return error.InvalidDebugInfo;
    }

    mod.populated = true;
}

fn machoSearchSymbols(symbols: []const MachoSymbol, address: usize) ?*const MachoSymbol {
    var min: usize = 0;
    var max: usize = symbols.len - 1; // Exclude sentinel.
    while (min < max) {
        const mid = min + (max - min) / 2;
        const curr = &symbols[mid];
        const next = &symbols[mid + 1];
        if (address >= next.address()) {
            min = mid + 1;
        } else if (address < curr.address()) {
            max = mid;
        } else {
            return curr;
        }
    }
    return null;
}

fn printSourceAtAddressMacOs(di: *DebugInfo, out_stream: var, address: usize, tty_color: bool) !void {
    const base_addr = @ptrToInt(&std.c._mh_execute_header);
    const adjusted_addr = 0x100000000 + (address - base_addr);

    const symbol = machoSearchSymbols(di.symbols, adjusted_addr) orelse {
        if (tty_color) {
            try out_stream.print("???:?:?: " ++ DIM ++ "0x{x} in ??? (???)" ++ RESET ++ "\n\n\n", address);
        } else {
            try out_stream.print("???:?:?: 0x{x} in ??? (???)\n\n\n", address);
        }
        return;
    };

    const symbol_name = mem.toSliceConst(u8, di.strings.ptr + symbol.nlist.n_strx);
    const compile_unit_name = if (symbol.ofile) |ofile| blk: {
        const ofile_path = mem.toSliceConst(u8, di.strings.ptr + ofile.n_strx);
        break :blk os.path.basename(ofile_path);
    } else "???";
    if (getLineNumberInfoMacOs(di, symbol.*, adjusted_addr)) |line_info| {
        defer line_info.deinit();
        try printLineInfo(di, out_stream, line_info, address, symbol_name, compile_unit_name, tty_color);
    } else |err| switch (err) {
        error.MissingDebugInfo, error.InvalidDebugInfo => {
            if (tty_color) {
                try out_stream.print("???:?:?: " ++ DIM ++ "0x{x} in {} ({})" ++ RESET ++ "\n\n\n", address, symbol_name, compile_unit_name);
            } else {
                try out_stream.print("???:?:?: 0x{x} in {} ({})\n\n\n", address, symbol_name, compile_unit_name);
            }
        },
        else => return err,
    }
}

pub fn printSourceAtAddressLinux(debug_info: *DebugInfo, out_stream: var, address: usize, tty_color: bool) !void {
    const compile_unit = findCompileUnit(debug_info, address) catch {
        if (tty_color) {
            try out_stream.print("???:?:?: " ++ DIM ++ "0x{x} in ??? (???)" ++ RESET ++ "\n\n\n", address);
        } else {
            try out_stream.print("???:?:?: 0x{x} in ??? (???)\n\n\n", address);
        }
        return;
    };
    const compile_unit_name = try compile_unit.die.getAttrString(debug_info, DW.AT_name);
    if (getLineNumberInfoLinux(debug_info, compile_unit, address - 1)) |line_info| {
        defer line_info.deinit();
        const symbol_name = "???";
        try printLineInfo(debug_info, out_stream, line_info, address, symbol_name, compile_unit_name, tty_color);
    } else |err| switch (err) {
        error.MissingDebugInfo, error.InvalidDebugInfo => {
            if (tty_color) {
                try out_stream.print("???:?:?: " ++ DIM ++ "0x{x} in ??? ({})" ++ RESET ++ "\n\n\n", address, compile_unit_name);
            } else {
                try out_stream.print("???:?:?: 0x{x} in ??? ({})\n\n\n", address, compile_unit_name);
            }
        },
        else => return err,
    }
}

fn printLineInfo(
    debug_info: *DebugInfo,
    out_stream: var,
    line_info: LineInfo,
    address: usize,
    symbol_name: []const u8,
    compile_unit_name: []const u8,
    tty_color: bool,
) !void {
    if (tty_color) {
        try out_stream.print(
            WHITE ++ "{}:{}:{}" ++ RESET ++ ": " ++ DIM ++ "0x{x} in {} ({})" ++ RESET ++ "\n",
            line_info.file_name,
            line_info.line,
            line_info.column,
            address,
            symbol_name,
            compile_unit_name,
        );
        if (printLineFromFile(out_stream, line_info)) {
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
            "{}:{}:{}: 0x{x} in {} ({})\n",
            line_info.file_name,
            line_info.line,
            line_info.column,
            address,
            symbol_name,
            compile_unit_name,
        );
    }
}

// TODO use this
pub const OpenSelfDebugInfoError = error{
    MissingDebugInfo,
    OutOfMemory,
    UnsupportedOperatingSystem,
};

pub fn openSelfDebugInfo(allocator: *mem.Allocator) !DebugInfo {
    switch (builtin.os) {
        builtin.Os.linux => return openSelfDebugInfoLinux(allocator),
        builtin.Os.macosx, builtin.Os.ios => return openSelfDebugInfoMacOs(allocator),
        builtin.Os.windows => return openSelfDebugInfoWindows(allocator),
        else => return error.UnsupportedOperatingSystem,
    }
}

fn openSelfDebugInfoWindows(allocator: *mem.Allocator) !DebugInfo {
    const self_file = try os.openSelfExe();
    defer self_file.close();

    const coff_obj = try allocator.createOne(coff.Coff);
    coff_obj.* = coff.Coff{
        .in_file = self_file,
        .allocator = allocator,
        .coff_header = undefined,
        .pe_header = undefined,
        .sections = undefined,
        .guid = undefined,
        .age = undefined,
    };

    var di = DebugInfo{
        .coff = coff_obj,
        .pdb = undefined,
        .sect_contribs = undefined,
        .modules = undefined,
    };

    try di.coff.loadHeader();

    var path_buf: [windows.MAX_PATH]u8 = undefined;
    const len = try di.coff.getPdbPath(path_buf[0..]);
    const raw_path = path_buf[0..len];

    const path = try os.path.resolve(allocator, raw_path);

    try di.pdb.openFile(di.coff, path);

    var pdb_stream = di.pdb.getStream(pdb.StreamType.Pdb) orelse return error.InvalidDebugInfo;
    const version = try pdb_stream.stream.readIntLe(u32);
    const signature = try pdb_stream.stream.readIntLe(u32);
    const age = try pdb_stream.stream.readIntLe(u32);
    var guid: [16]u8 = undefined;
    try pdb_stream.stream.readNoEof(guid[0..]);
    if (!mem.eql(u8, di.coff.guid, guid) or di.coff.age != age)
        return error.InvalidDebugInfo;
    // We validated the executable and pdb match.

    const string_table_index = str_tab_index: {
        const name_bytes_len = try pdb_stream.stream.readIntLe(u32);
        const name_bytes = try allocator.alloc(u8, name_bytes_len);
        try pdb_stream.stream.readNoEof(name_bytes);

        const HashTableHeader = packed struct {
            Size: u32,
            Capacity: u32,

            fn maxLoad(cap: u32) u32 {
                return cap * 2 / 3 + 1;
            }
        };
        var hash_tbl_hdr: HashTableHeader = undefined;
        try pdb_stream.stream.readStruct(HashTableHeader, &hash_tbl_hdr);
        if (hash_tbl_hdr.Capacity == 0)
            return error.InvalidDebugInfo;

        if (hash_tbl_hdr.Size > HashTableHeader.maxLoad(hash_tbl_hdr.Capacity))
            return error.InvalidDebugInfo;

        const present = try readSparseBitVector(&pdb_stream.stream, allocator);
        if (present.len != hash_tbl_hdr.Size)
            return error.InvalidDebugInfo;
        const deleted = try readSparseBitVector(&pdb_stream.stream, allocator);

        const Bucket = struct {
            first: u32,
            second: u32,
        };
        const bucket_list = try allocator.alloc(Bucket, present.len);
        for (present) |_| {
            const name_offset = try pdb_stream.stream.readIntLe(u32);
            const name_index = try pdb_stream.stream.readIntLe(u32);
            const name = mem.toSlice(u8, name_bytes.ptr + name_offset);
            if (mem.eql(u8, name, "/names")) {
                break :str_tab_index name_index;
            }
        }
        return error.MissingDebugInfo;
    };

    di.pdb.string_table = di.pdb.getStreamById(string_table_index) orelse return error.InvalidDebugInfo;
    di.pdb.dbi = di.pdb.getStream(pdb.StreamType.Dbi) orelse return error.MissingDebugInfo;

    const dbi = di.pdb.dbi;

    // Dbi Header
    var dbi_stream_header: pdb.DbiStreamHeader = undefined;
    try dbi.stream.readStruct(pdb.DbiStreamHeader, &dbi_stream_header);
    const mod_info_size = dbi_stream_header.ModInfoSize;
    const section_contrib_size = dbi_stream_header.SectionContributionSize;

    var modules = ArrayList(Module).init(allocator);

    // Module Info Substream
    var mod_info_offset: usize = 0;
    while (mod_info_offset != mod_info_size) {
        var mod_info: pdb.ModInfo = undefined;
        try dbi.stream.readStruct(pdb.ModInfo, &mod_info);
        var this_record_len: usize = @sizeOf(pdb.ModInfo);

        const module_name = try dbi.readNullTermString(allocator);
        this_record_len += module_name.len + 1;

        const obj_file_name = try dbi.readNullTermString(allocator);
        this_record_len += obj_file_name.len + 1;

        const march_forward_bytes = this_record_len % 4;
        if (march_forward_bytes != 0) {
            try dbi.seekForward(march_forward_bytes);
            this_record_len += march_forward_bytes;
        }

        try modules.append(Module{
            .mod_info = mod_info,
            .module_name = module_name,
            .obj_file_name = obj_file_name,

            .populated = false,
            .symbols = undefined,
            .subsect_info = undefined,
            .checksum_offset = null,
        });

        mod_info_offset += this_record_len;
        if (mod_info_offset > mod_info_size)
            return error.InvalidDebugInfo;
    }

    di.modules = modules.toOwnedSlice();

    // Section Contribution Substream
    var sect_contribs = ArrayList(pdb.SectionContribEntry).init(allocator);
    var sect_cont_offset: usize = 0;
    if (section_contrib_size != 0) {
        const ver = @intToEnum(pdb.SectionContrSubstreamVersion, try dbi.stream.readIntLe(u32));
        if (ver != pdb.SectionContrSubstreamVersion.Ver60)
            return error.InvalidDebugInfo;
        sect_cont_offset += @sizeOf(u32);
    }
    while (sect_cont_offset != section_contrib_size) {
        const entry = try sect_contribs.addOne();
        try dbi.stream.readStruct(pdb.SectionContribEntry, entry);
        sect_cont_offset += @sizeOf(pdb.SectionContribEntry);

        if (sect_cont_offset > section_contrib_size)
            return error.InvalidDebugInfo;
    }

    di.sect_contribs = sect_contribs.toOwnedSlice();

    return di;
}

fn readSparseBitVector(stream: var, allocator: *mem.Allocator) ![]usize {
    const num_words = try stream.readIntLe(u32);
    var word_i: usize = 0;
    var list = ArrayList(usize).init(allocator);
    while (word_i != num_words) : (word_i += 1) {
        const word = try stream.readIntLe(u32);
        var bit_i: u5 = 0;
        while (true) : (bit_i += 1) {
            if (word & (u32(1) << bit_i) != 0) {
                try list.append(word_i * 32 + bit_i);
            }
            if (bit_i == @maxValue(u5)) break;
        }
    }
    return list.toOwnedSlice();
}

fn openSelfDebugInfoLinux(allocator: *mem.Allocator) !DebugInfo {
    var di = DebugInfo{
        .self_exe_file = undefined,
        .elf = undefined,
        .debug_info = undefined,
        .debug_abbrev = undefined,
        .debug_str = undefined,
        .debug_line = undefined,
        .debug_ranges = null,
        .abbrev_table_list = ArrayList(AbbrevTableHeader).init(allocator),
        .compile_unit_list = ArrayList(CompileUnit).init(allocator),
    };
    di.self_exe_file = try os.openSelfExe();
    errdefer di.self_exe_file.close();

    try di.elf.openFile(allocator, &di.self_exe_file);
    errdefer di.elf.close();

    di.debug_info = (try di.elf.findSection(".debug_info")) orelse return error.MissingDebugInfo;
    di.debug_abbrev = (try di.elf.findSection(".debug_abbrev")) orelse return error.MissingDebugInfo;
    di.debug_str = (try di.elf.findSection(".debug_str")) orelse return error.MissingDebugInfo;
    di.debug_line = (try di.elf.findSection(".debug_line")) orelse return error.MissingDebugInfo;
    di.debug_ranges = (try di.elf.findSection(".debug_ranges"));
    try scanAllCompileUnits(&di);
    return di;
}

pub fn findElfSection(elf: *Elf, name: []const u8) ?*elf.Shdr {
    var file_stream = io.FileInStream.init(elf.in_file);
    const in = &file_stream.stream;

    section_loop: for (elf.section_headers) |*elf_section| {
        if (elf_section.sh_type == SHT_NULL) continue;

        const name_offset = elf.string_section.offset + elf_section.name;
        try elf.in_file.seekTo(name_offset);

        for (name) |expected_c| {
            const target_c = try in.readByte();
            if (target_c == 0 or expected_c != target_c) continue :section_loop;
        }

        {
            const null_byte = try in.readByte();
            if (null_byte == 0) return elf_section;
        }
    }

    return null;
}

fn openSelfDebugInfoMacOs(allocator: *mem.Allocator) !DebugInfo {
    const hdr = &std.c._mh_execute_header;
    assert(hdr.magic == std.macho.MH_MAGIC_64);

    const hdr_base = @ptrCast([*]u8, hdr);
    var ptr = hdr_base + @sizeOf(macho.mach_header_64);
    var ncmd: u32 = hdr.ncmds;
    const symtab = while (ncmd != 0) : (ncmd -= 1) {
        const lc = @ptrCast(*std.macho.load_command, ptr);
        switch (lc.cmd) {
            std.macho.LC_SYMTAB => break @ptrCast(*std.macho.symtab_command, ptr),
            else => {},
        }
        ptr += lc.cmdsize; // TODO https://github.com/ziglang/zig/issues/1403
    } else {
        return error.MissingDebugInfo;
    };
    const syms = @ptrCast([*]macho.nlist_64, hdr_base + symtab.symoff)[0..symtab.nsyms];
    const strings = @ptrCast([*]u8, hdr_base + symtab.stroff)[0..symtab.strsize];

    const symbols_buf = try allocator.alloc(MachoSymbol, syms.len);

    var ofile: ?*macho.nlist_64 = null;
    var reloc: u64 = 0;
    var symbol_index: usize = 0;
    var last_len: u64 = 0;
    for (syms) |*sym| {
        if (sym.n_type & std.macho.N_STAB != 0) {
            switch (sym.n_type) {
                std.macho.N_OSO => {
                    ofile = sym;
                    reloc = 0;
                },
                std.macho.N_FUN => {
                    if (sym.n_sect == 0) {
                        last_len = sym.n_value;
                    } else {
                        symbols_buf[symbol_index] = MachoSymbol{
                            .nlist = sym,
                            .ofile = ofile,
                            .reloc = reloc,
                        };
                        symbol_index += 1;
                    }
                },
                std.macho.N_BNSYM => {
                    if (reloc == 0) {
                        reloc = sym.n_value;
                    }
                },
                else => continue,
            }
        }
    }
    const sentinel = try allocator.createOne(macho.nlist_64);
    sentinel.* = macho.nlist_64{
        .n_strx = 0,
        .n_type = 36,
        .n_sect = 0,
        .n_desc = 0,
        .n_value = symbols_buf[symbol_index - 1].nlist.n_value + last_len,
    };

    const symbols = allocator.shrink(MachoSymbol, symbols_buf, symbol_index);

    // Even though lld emits symbols in ascending order, this debug code
    // should work for programs linked in any valid way.
    // This sort is so that we can binary search later.
    std.sort.sort(MachoSymbol, symbols, MachoSymbol.addressLessThan);

    return DebugInfo{
        .ofiles = DebugInfo.OFileTable.init(allocator),
        .symbols = symbols,
        .strings = strings,
    };
}

fn printLineFromFile(out_stream: var, line_info: *const LineInfo) !void {
    var f = try os.File.openRead(line_info.file_name);
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

const MachoSymbol = struct {
    nlist: *macho.nlist_64,
    ofile: ?*macho.nlist_64,
    reloc: u64,

    /// Returns the address from the macho file
    fn address(self: MachoSymbol) u64 {
        return self.nlist.n_value;
    }

    fn addressLessThan(lhs: MachoSymbol, rhs: MachoSymbol) bool {
        return lhs.address() < rhs.address();
    }
};

const MachOFile = struct {
    bytes: []align(@alignOf(macho.mach_header_64)) const u8,
    sect_debug_info: ?*const macho.section_64,
    sect_debug_line: ?*const macho.section_64,
};

pub const DebugInfo = switch (builtin.os) {
    builtin.Os.macosx => struct {
        symbols: []const MachoSymbol,
        strings: []const u8,
        ofiles: OFileTable,

        const OFileTable = std.HashMap(
            *macho.nlist_64,
            MachOFile,
            std.hash_map.getHashPtrAddrFn(*macho.nlist_64),
            std.hash_map.getTrivialEqlFn(*macho.nlist_64),
        );

        pub fn allocator(self: DebugInfo) *mem.Allocator {
            return self.ofiles.allocator;
        }
    },
    builtin.Os.windows => struct {
        pdb: pdb.Pdb,
        coff: *coff.Coff,
        sect_contribs: []pdb.SectionContribEntry,
        modules: []Module,
    },
    builtin.Os.linux => struct {
        self_exe_file: os.File,
        elf: elf.Elf,
        debug_info: *elf.SectionHeader,
        debug_abbrev: *elf.SectionHeader,
        debug_str: *elf.SectionHeader,
        debug_line: *elf.SectionHeader,
        debug_ranges: ?*elf.SectionHeader,
        abbrev_table_list: ArrayList(AbbrevTableHeader),
        compile_unit_list: ArrayList(CompileUnit),

        pub fn allocator(self: DebugInfo) *mem.Allocator {
            return self.abbrev_table_list.allocator;
        }

        pub fn readString(self: *DebugInfo) ![]u8 {
            var in_file_stream = io.FileInStream.init(&self.self_exe_file);
            const in_stream = &in_file_stream.stream;
            return readStringRaw(self.allocator(), in_stream);
        }

        pub fn close(self: *DebugInfo) void {
            self.self_exe_file.close();
            self.elf.close();
        }
    },
    else => @compileError("Unsupported OS"),
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

    fn getAttrString(self: *const Die, st: *DebugInfo, id: u64) ![]u8 {
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

fn getString(st: *DebugInfo, offset: u64) ![]u8 {
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
    InvalidDebugInfo,
    EndOfFile,
    OutOfMemory,
} || std.os.File.ReadError;

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

fn parseAbbrevTable(st: *DebugInfo) !AbbrevTable {
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
fn getAbbrevTable(st: *DebugInfo, abbrev_offset: u64) !*const AbbrevTable {
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

fn parseDie(st: *DebugInfo, abbrev_table: *const AbbrevTable, is_64: bool) !Die {
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

fn getLineNumberInfoMacOs(di: *DebugInfo, symbol: MachoSymbol, target_address: usize) !LineInfo {
    const ofile = symbol.ofile orelse return error.MissingDebugInfo;
    const gop = try di.ofiles.getOrPut(ofile);
    const mach_o_file = if (gop.found_existing) &gop.kv.value else blk: {
        errdefer _ = di.ofiles.remove(ofile);
        const ofile_path = mem.toSliceConst(u8, di.strings.ptr + ofile.n_strx);

        gop.kv.value = MachOFile{
            .bytes = try std.io.readFileAllocAligned(di.ofiles.allocator, ofile_path, @alignOf(macho.mach_header_64)),
            .sect_debug_info = null,
            .sect_debug_line = null,
        };
        const hdr = @ptrCast(*const macho.mach_header_64, gop.kv.value.bytes.ptr);
        if (hdr.magic != std.macho.MH_MAGIC_64) return error.InvalidDebugInfo;

        const hdr_base = @ptrCast([*]const u8, hdr);
        var ptr = hdr_base + @sizeOf(macho.mach_header_64);
        var ncmd: u32 = hdr.ncmds;
        const segcmd = while (ncmd != 0) : (ncmd -= 1) {
            const lc = @ptrCast(*const std.macho.load_command, ptr);
            switch (lc.cmd) {
                std.macho.LC_SEGMENT_64 => break @ptrCast(*const std.macho.segment_command_64, ptr),
                else => {},
            }
            ptr += lc.cmdsize; // TODO https://github.com/ziglang/zig/issues/1403
        } else {
            return error.MissingDebugInfo;
        };
        const sections = @alignCast(@alignOf(macho.section_64), @ptrCast([*]const macho.section_64, ptr + @sizeOf(std.macho.segment_command_64)))[0..segcmd.nsects];
        for (sections) |*sect| {
            if (sect.flags & macho.SECTION_TYPE == macho.S_REGULAR and
                (sect.flags & macho.SECTION_ATTRIBUTES) & macho.S_ATTR_DEBUG == macho.S_ATTR_DEBUG)
            {
                const sect_name = mem.toSliceConst(u8, &sect.sectname);
                if (mem.eql(u8, sect_name, "__debug_line")) {
                    gop.kv.value.sect_debug_line = sect;
                } else if (mem.eql(u8, sect_name, "__debug_info")) {
                    gop.kv.value.sect_debug_info = sect;
                }
            }
        }

        break :blk &gop.kv.value;
    };

    const sect_debug_line = mach_o_file.sect_debug_line orelse return error.MissingDebugInfo;
    var ptr = mach_o_file.bytes.ptr + sect_debug_line.offset;

    var is_64: bool = undefined;
    const unit_length = try readInitialLengthMem(&ptr, &is_64);
    if (unit_length == 0) return error.MissingDebugInfo;

    const version = readIntMem(&ptr, u16, builtin.Endian.Little);
    // TODO support 3 and 5
    if (version != 2 and version != 4) return error.InvalidDebugInfo;

    const prologue_length = if (is_64)
        readIntMem(&ptr, u64, builtin.Endian.Little)
    else
        readIntMem(&ptr, u32, builtin.Endian.Little);
    const prog_start = ptr + prologue_length;

    const minimum_instruction_length = readByteMem(&ptr);
    if (minimum_instruction_length == 0) return error.InvalidDebugInfo;

    if (version >= 4) {
        // maximum_operations_per_instruction
        ptr += 1;
    }

    const default_is_stmt = readByteMem(&ptr) != 0;
    const line_base = readByteSignedMem(&ptr);

    const line_range = readByteMem(&ptr);
    if (line_range == 0) return error.InvalidDebugInfo;

    const opcode_base = readByteMem(&ptr);

    const standard_opcode_lengths = ptr[0 .. opcode_base - 1];
    ptr += opcode_base - 1;

    var include_directories = ArrayList([]const u8).init(di.allocator());
    try include_directories.append("");
    while (true) {
        const dir = readStringMem(&ptr);
        if (dir.len == 0) break;
        try include_directories.append(dir);
    }

    var file_entries = ArrayList(FileEntry).init(di.allocator());
    var prog = LineNumberProgram.init(default_is_stmt, include_directories.toSliceConst(), &file_entries, target_address);

    while (true) {
        const file_name = readStringMem(&ptr);
        if (file_name.len == 0) break;
        const dir_index = try readULeb128Mem(&ptr);
        const mtime = try readULeb128Mem(&ptr);
        const len_bytes = try readULeb128Mem(&ptr);
        try file_entries.append(FileEntry{
            .file_name = file_name,
            .dir_index = dir_index,
            .mtime = mtime,
            .len_bytes = len_bytes,
        });
    }

    ptr = prog_start;
    while (true) {
        const opcode = readByteMem(&ptr);

        if (opcode == DW.LNS_extended_op) {
            const op_size = try readULeb128Mem(&ptr);
            if (op_size < 1) return error.InvalidDebugInfo;
            var sub_op = readByteMem(&ptr);
            switch (sub_op) {
                DW.LNE_end_sequence => {
                    prog.end_sequence = true;
                    if (try prog.checkLineMatch()) |info| return info;
                    return error.MissingDebugInfo;
                },
                DW.LNE_set_address => {
                    const addr = readIntMem(&ptr, usize, builtin.Endian.Little);
                    prog.address = symbol.reloc + addr;
                },
                DW.LNE_define_file => {
                    const file_name = readStringMem(&ptr);
                    const dir_index = try readULeb128Mem(&ptr);
                    const mtime = try readULeb128Mem(&ptr);
                    const len_bytes = try readULeb128Mem(&ptr);
                    try file_entries.append(FileEntry{
                        .file_name = file_name,
                        .dir_index = dir_index,
                        .mtime = mtime,
                        .len_bytes = len_bytes,
                    });
                },
                else => {
                    ptr += op_size - 1;
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
                    const arg = try readULeb128Mem(&ptr);
                    prog.address += arg * minimum_instruction_length;
                },
                DW.LNS_advance_line => {
                    const arg = try readILeb128Mem(&ptr);
                    prog.line += arg;
                },
                DW.LNS_set_file => {
                    const arg = try readULeb128Mem(&ptr);
                    prog.file = arg;
                },
                DW.LNS_set_column => {
                    const arg = try readULeb128Mem(&ptr);
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
                    const arg = readIntMem(&ptr, u16, builtin.Endian.Little);
                    prog.address += arg;
                },
                DW.LNS_set_prologue_end => {},
                else => {
                    if (opcode - 1 >= standard_opcode_lengths.len) return error.InvalidDebugInfo;
                    const len_bytes = standard_opcode_lengths[opcode - 1];
                    ptr += len_bytes;
                },
            }
        }
    }

    return error.MissingDebugInfo;
}

fn getLineNumberInfoLinux(di: *DebugInfo, compile_unit: *const CompileUnit, target_address: usize) !LineInfo {
    const compile_unit_cwd = try compile_unit.die.getAttrString(di, DW.AT_comp_dir);

    const in_file = &di.self_exe_file;
    const debug_line_end = di.debug_line.offset + di.debug_line.size;
    var this_offset = di.debug_line.offset;
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

        const version = try in_stream.readInt(di.elf.endian, u16);
        // TODO support 3 and 5
        if (version != 2 and version != 4) return error.InvalidDebugInfo;

        const prologue_length = if (is_64) try in_stream.readInt(di.elf.endian, u64) else try in_stream.readInt(di.elf.endian, u32);
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

        const standard_opcode_lengths = try di.allocator().alloc(u8, opcode_base - 1);

        {
            var i: usize = 0;
            while (i < opcode_base - 1) : (i += 1) {
                standard_opcode_lengths[i] = try in_stream.readByte();
            }
        }

        var include_directories = ArrayList([]u8).init(di.allocator());
        try include_directories.append(compile_unit_cwd);
        while (true) {
            const dir = try di.readString();
            if (dir.len == 0) break;
            try include_directories.append(dir);
        }

        var file_entries = ArrayList(FileEntry).init(di.allocator());
        var prog = LineNumberProgram.init(default_is_stmt, include_directories.toSliceConst(), &file_entries, target_address);

        while (true) {
            const file_name = try di.readString();
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

            if (opcode == DW.LNS_extended_op) {
                const op_size = try readULeb128(in_stream);
                if (op_size < 1) return error.InvalidDebugInfo;
                var sub_op = try in_stream.readByte();
                switch (sub_op) {
                    DW.LNE_end_sequence => {
                        prog.end_sequence = true;
                        if (try prog.checkLineMatch()) |info| return info;
                        return error.MissingDebugInfo;
                    },
                    DW.LNE_set_address => {
                        const addr = try in_stream.readInt(di.elf.endian, usize);
                        prog.address = addr;
                    },
                    DW.LNE_define_file => {
                        const file_name = try di.readString();
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
                        const arg = try in_stream.readInt(di.elf.endian, u16);
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

fn scanAllCompileUnits(st: *DebugInfo) !void {
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

fn findCompileUnit(st: *DebugInfo, target_address: u64) !*const CompileUnit {
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

fn readIntMem(ptr: *[*]const u8, comptime T: type, endian: builtin.Endian) T {
    const result = mem.readInt(ptr.*[0..@sizeOf(T)], T, endian);
    ptr.* += @sizeOf(T);
    return result;
}

fn readByteMem(ptr: *[*]const u8) u8 {
    const result = ptr.*[0];
    ptr.* += 1;
    return result;
}

fn readByteSignedMem(ptr: *[*]const u8) i8 {
    return @bitCast(i8, readByteMem(ptr));
}

fn readInitialLengthMem(ptr: *[*]const u8, is_64: *bool) !u64 {
    const first_32_bits = mem.readIntLE(u32, ptr.*[0..4]);
    is_64.* = (first_32_bits == 0xffffffff);
    if (is_64.*) {
        ptr.* += 4;
        const result = mem.readIntLE(u64, ptr.*[0..8]);
        ptr.* += 8;
        return result;
    } else {
        if (first_32_bits >= 0xfffffff0) return error.InvalidDebugInfo;
        ptr.* += 4;
        return u64(first_32_bits);
    }
}

fn readStringMem(ptr: *[*]const u8) []const u8 {
    const result = mem.toSliceConst(u8, ptr.*);
    ptr.* += result.len + 1;
    return result;
}

fn readULeb128Mem(ptr: *[*]const u8) !u64 {
    var result: u64 = 0;
    var shift: usize = 0;
    var i: usize = 0;

    while (true) {
        const byte = ptr.*[i];
        i += 1;

        var operand: u64 = undefined;

        if (@shlWithOverflow(u64, byte & 0b01111111, @intCast(u6, shift), &operand)) return error.InvalidDebugInfo;

        result |= operand;

        if ((byte & 0b10000000) == 0) {
            ptr.* += i;
            return result;
        }

        shift += 7;
    }
}
fn readILeb128Mem(ptr: *[*]const u8) !i64 {
    var result: i64 = 0;
    var shift: usize = 0;
    var i: usize = 0;

    while (true) {
        const byte = ptr.*[i];
        i += 1;

        var operand: i64 = undefined;
        if (@shlWithOverflow(i64, byte & 0b01111111, @intCast(u6, shift), &operand)) return error.InvalidDebugInfo;

        result |= operand;
        shift += 7;

        if ((byte & 0b10000000) == 0) {
            if (shift < @sizeOf(i64) * 8 and (byte & 0b01000000) != 0) result |= -(i64(1) << @intCast(u6, shift));
            ptr.* += i;
            return result;
        }
    }
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
var global_fixed_allocator = std.heap.ThreadSafeFixedBufferAllocator.init(global_allocator_mem[0..]);
var global_allocator_mem: [100 * 1024]u8 = undefined;

/// TODO multithreaded awareness
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
