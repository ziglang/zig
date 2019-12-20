const std = @import("std.zig");
const math = std.math;
const mem = std.mem;
const io = std.io;
const os = std.os;
const fs = std.fs;
const process = std.process;
const elf = std.elf;
const DW = std.dwarf;
const macho = std.macho;
const coff = std.coff;
const pdb = std.pdb;
const ArrayList = std.ArrayList;
const builtin = @import("builtin");
const root = @import("root");
const maxInt = std.math.maxInt;
const File = std.fs.File;
const windows = std.os.windows;

pub const leb = @import("debug/leb128.zig");

pub const FailingAllocator = @import("debug/failing_allocator.zig").FailingAllocator;
pub const failing_allocator = &FailingAllocator.init(global_allocator, 0).allocator;

pub const runtime_safety = switch (builtin.mode) {
    .Debug, .ReleaseSafe => true,
    .ReleaseFast, .ReleaseSmall => false,
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
var stderr_file: File = undefined;
var stderr_file_out_stream: File.OutStream = undefined;

var stderr_stream: ?*io.OutStream(File.WriteError) = null;
var stderr_mutex = std.Mutex.init();

pub fn warn(comptime fmt: []const u8, args: var) void {
    const held = stderr_mutex.acquire();
    defer held.release();
    const stderr = getStderrStream();
    stderr.print(fmt, args) catch return;
}

pub fn getStderrStream() *io.OutStream(File.WriteError) {
    if (stderr_stream) |st| {
        return st;
    } else {
        stderr_file = io.getStdErr();
        stderr_file_out_stream = stderr_file.outStream();
        const st = &stderr_file_out_stream.stream;
        stderr_stream = st;
        return st;
    }
}

pub fn getStderrMutex() *std.Mutex {
    return &stderr_mutex;
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
    return if (process.getEnvVarOwned(allocator, "ZIG_DEBUG_COLOR")) |_| true else |_| stderr_file.isTty();
}

/// Tries to print the current stack trace to stderr, unbuffered, and ignores any error returned.
/// TODO multithreaded awareness
pub fn dumpCurrentStackTrace(start_addr: ?usize) void {
    const stderr = getStderrStream();
    if (builtin.strip_debug_info) {
        stderr.print("Unable to dump stack trace: debug info stripped\n", .{}) catch return;
        return;
    }
    const debug_info = getSelfDebugInfo() catch |err| {
        stderr.print("Unable to dump stack trace: Unable to open debug info: {}\n", .{@errorName(err)}) catch return;
        return;
    };
    writeCurrentStackTrace(stderr, debug_info, wantTtyColor(), start_addr) catch |err| {
        stderr.print("Unable to dump stack trace: {}\n", .{@errorName(err)}) catch return;
        return;
    };
}

/// Tries to print the stack trace starting from the supplied base pointer to stderr,
/// unbuffered, and ignores any error returned.
/// TODO multithreaded awareness
pub fn dumpStackTraceFromBase(bp: usize, ip: usize) void {
    const stderr = getStderrStream();
    if (builtin.strip_debug_info) {
        stderr.print("Unable to dump stack trace: debug info stripped\n", .{}) catch return;
        return;
    }
    const debug_info = getSelfDebugInfo() catch |err| {
        stderr.print("Unable to dump stack trace: Unable to open debug info: {}\n", .{@errorName(err)}) catch return;
        return;
    };
    const tty_color = wantTtyColor();
    printSourceAtAddress(debug_info, stderr, ip, tty_color) catch return;
    const first_return_address = @intToPtr(*const usize, bp + @sizeOf(usize)).*;
    printSourceAtAddress(debug_info, stderr, first_return_address - 1, tty_color) catch return;
    var it = StackIterator{
        .first_addr = null,
        .fp = bp,
    };
    while (it.next()) |return_address| {
        printSourceAtAddress(debug_info, stderr, return_address - 1, tty_color) catch return;
    }
}

/// Returns a slice with the same pointer as addresses, with a potentially smaller len.
/// On Windows, when first_address is not null, we ask for at least 32 stack frames,
/// and then try to find the first address. If addresses.len is more than 32, we
/// capture that many stack frames exactly, and then look for the first address,
/// chopping off the irrelevant frames and shifting so that the returned addresses pointer
/// equals the passed in addresses pointer.
pub fn captureStackTrace(first_address: ?usize, stack_trace: *builtin.StackTrace) void {
    if (builtin.os == .windows) {
        const addrs = stack_trace.instruction_addresses;
        const u32_addrs_len = @intCast(u32, addrs.len);
        const first_addr = first_address orelse {
            stack_trace.index = windows.ntdll.RtlCaptureStackBackTrace(
                0,
                u32_addrs_len,
                @ptrCast(**c_void, addrs.ptr),
                null,
            );
            return;
        };
        var addr_buf_stack: [32]usize = undefined;
        const addr_buf = if (addr_buf_stack.len > addrs.len) addr_buf_stack[0..] else addrs;
        const n = windows.ntdll.RtlCaptureStackBackTrace(0, u32_addrs_len, @ptrCast(**c_void, addr_buf.ptr), null);
        const first_index = for (addr_buf[0..n]) |addr, i| {
            if (addr == first_addr) {
                break i;
            }
        } else {
            stack_trace.index = 0;
            return;
        };
        const slice = addr_buf[first_index..n];
        // We use a for loop here because slice and addrs may alias.
        for (slice) |addr, i| {
            addrs[i] = addr;
        }
        stack_trace.index = slice.len;
    } else {
        var it = StackIterator.init(first_address);
        for (stack_trace.instruction_addresses) |*addr, i| {
            addr.* = it.next() orelse {
                stack_trace.index = i;
                return;
            };
        }
        stack_trace.index = stack_trace.instruction_addresses.len;
    }
}

/// Tries to print a stack trace to stderr, unbuffered, and ignores any error returned.
/// TODO multithreaded awareness
pub fn dumpStackTrace(stack_trace: builtin.StackTrace) void {
    const stderr = getStderrStream();
    if (builtin.strip_debug_info) {
        stderr.print("Unable to dump stack trace: debug info stripped\n", .{}) catch return;
        return;
    }
    const debug_info = getSelfDebugInfo() catch |err| {
        stderr.print("Unable to dump stack trace: Unable to open debug info: {}\n", .{@errorName(err)}) catch return;
        return;
    };
    writeStackTrace(stack_trace, stderr, getDebugInfoAllocator(), debug_info, wantTtyColor()) catch |err| {
        stderr.print("Unable to dump stack trace: {}\n", .{@errorName(err)}) catch return;
        return;
    };
}

/// This function invokes undefined behavior when `ok` is `false`.
/// In Debug and ReleaseSafe modes, calls to this function are always
/// generated, and the `unreachable` statement triggers a panic.
/// In ReleaseFast and ReleaseSmall modes, calls to this function are
/// optimized away, and in fact the optimizer is able to use the assertion
/// in its heuristics.
/// Inside a test block, it is best to use the `std.testing` module rather
/// than this function, because this function may not detect a test failure
/// in ReleaseFast and ReleaseSmall mode. Outside of a test block, this assert
/// function is the correct function to use.
pub fn assert(ok: bool) void {
    if (!ok) unreachable; // assertion failure
}

pub fn panic(comptime format: []const u8, args: var) noreturn {
    @setCold(true);
    // TODO: remove conditional once wasi / LLVM defines __builtin_return_address
    const first_trace_addr = if (builtin.os == .wasi) null else @returnAddress();
    panicExtra(null, first_trace_addr, format, args);
}

/// TODO multithreaded awareness
var panicking: u8 = 0;

pub fn panicExtra(trace: ?*const builtin.StackTrace, first_trace_addr: ?usize, comptime format: []const u8, args: var) noreturn {
    @setCold(true);

    if (enable_segfault_handler) {
        // If a segfault happens while panicking, we want it to actually segfault, not trigger
        // the handler.
        resetSegfaultHandler();
    }

    switch (@atomicRmw(u8, &panicking, .Add, 1, .SeqCst)) {
        0 => {
            const stderr = getStderrStream();
            stderr.print(format ++ "\n", args) catch os.abort();
            if (trace) |t| {
                dumpStackTrace(t.*);
            }
            dumpCurrentStackTrace(first_trace_addr);
        },
        1 => {
            // TODO detect if a different thread caused the panic, because in that case
            // we would want to return here instead of calling abort, so that the thread
            // which first called panic can finish printing a stack trace.
            warn("Panicked during a panic. Aborting.\n", .{});
        },
        else => {
            // Panicked while printing "Panicked during a panic."
        },
    }
    os.abort();
}

const RED = "\x1b[31;1m";
const GREEN = "\x1b[32;1m";
const CYAN = "\x1b[36;1m";
const WHITE = "\x1b[37;1m";
const DIM = "\x1b[2m";
const RESET = "\x1b[0m";

pub fn writeStackTrace(
    stack_trace: builtin.StackTrace,
    out_stream: var,
    allocator: *mem.Allocator,
    debug_info: *DebugInfo,
    tty_color: bool,
) !void {
    if (builtin.strip_debug_info) return error.MissingDebugInfo;
    var frame_index: usize = 0;
    var frames_left: usize = std.math.min(stack_trace.index, stack_trace.instruction_addresses.len);

    while (frames_left != 0) : ({
        frames_left -= 1;
        frame_index = (frame_index + 1) % stack_trace.instruction_addresses.len;
    }) {
        const return_address = stack_trace.instruction_addresses[frame_index];
        try printSourceAtAddress(debug_info, out_stream, return_address - 1, tty_color);
    }
}

pub const StackIterator = struct {
    first_addr: ?usize,
    fp: usize,

    pub fn init(first_addr: ?usize) StackIterator {
        return StackIterator{
            .first_addr = first_addr,
            .fp = @frameAddress(),
        };
    }

    // On some architectures such as x86 the frame pointer is the address where
    // the previous fp is stored, while on some other architectures such as
    // RISC-V it points to the "top" of the frame, just above where the previous
    // fp and the return address are stored.
    const fp_adjust_factor = if (builtin.arch == .riscv32 or builtin.arch == .riscv64)
        2 * @sizeOf(usize)
    else
        0;

    fn next(self: *StackIterator) ?usize {
        if (self.fp <= fp_adjust_factor) return null;
        self.fp = @intToPtr(*const usize, self.fp - fp_adjust_factor).*;
        if (self.fp <= fp_adjust_factor) return null;

        if (self.first_addr) |addr| {
            while (self.fp > fp_adjust_factor) : (self.fp = @intToPtr(*const usize, self.fp - fp_adjust_factor).*) {
                const return_address = @intToPtr(*const usize, self.fp - fp_adjust_factor + @sizeOf(usize)).*;
                if (addr == return_address) {
                    self.first_addr = null;
                    return return_address;
                }
            }
        }

        const return_address = @intToPtr(*const usize, self.fp - fp_adjust_factor + @sizeOf(usize)).*;
        return return_address;
    }
};

pub fn writeCurrentStackTrace(out_stream: var, debug_info: *DebugInfo, tty_color: bool, start_addr: ?usize) !void {
    if (builtin.os == .windows) {
        return writeCurrentStackTraceWindows(out_stream, debug_info, tty_color, start_addr);
    }
    var it = StackIterator.init(start_addr);
    while (it.next()) |return_address| {
        try printSourceAtAddress(debug_info, out_stream, return_address - 1, tty_color);
    }
}

pub fn writeCurrentStackTraceWindows(
    out_stream: var,
    debug_info: *DebugInfo,
    tty_color: bool,
    start_addr: ?usize,
) !void {
    var addr_buf: [1024]usize = undefined;
    const n = windows.ntdll.RtlCaptureStackBackTrace(0, addr_buf.len, @ptrCast(**c_void, &addr_buf), null);
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

/// TODO once https://github.com/ziglang/zig/issues/3157 is fully implemented,
/// make this `noasync fn` and remove the individual noasync calls.
pub fn printSourceAtAddress(debug_info: *DebugInfo, out_stream: var, address: usize, tty_color: bool) !void {
    if (builtin.os == .windows) {
        return noasync printSourceAtAddressWindows(debug_info, out_stream, address, tty_color);
    }
    if (comptime std.Target.current.isDarwin()) {
        return noasync printSourceAtAddressMacOs(debug_info, out_stream, address, tty_color);
    }
    return noasync printSourceAtAddressPosix(debug_info, out_stream, address, tty_color);
}

fn printSourceAtAddressWindows(di: *DebugInfo, out_stream: var, relocated_address: usize, tty_color: bool) !void {
    const allocator = getDebugInfoAllocator();
    const base_address = process.getBaseAddress();
    const relative_address = relocated_address - base_address;

    var coff_section: *coff.Section = undefined;
    const mod_index = for (di.sect_contribs) |sect_contrib| {
        if (sect_contrib.Section > di.coff.sections.len) continue;
        // Remember that SectionContribEntry.Section is 1-based.
        coff_section = &di.coff.sections.toSlice()[sect_contrib.Section - 1];

        const vaddr_start = coff_section.header.virtual_address + sect_contrib.Offset;
        const vaddr_end = vaddr_start + sect_contrib.Size;
        if (relative_address >= vaddr_start and relative_address < vaddr_end) {
            break sect_contrib.ModuleIndex;
        }
    } else {
        // we have no information to add to the address
        if (tty_color) {
            try out_stream.print("???:?:?: ", .{});
            setTtyColor(TtyColor.Dim);
            try out_stream.print("0x{x} in ??? (???)", .{relocated_address});
            setTtyColor(TtyColor.Reset);
            try out_stream.print("\n\n\n", .{});
        } else {
            try out_stream.print("???:?:?: 0x{x} in ??? (???)\n\n\n", .{relocated_address});
        }
        return;
    };

    const mod = &di.modules[mod_index];
    try populateModule(di, mod);
    const obj_basename = fs.path.basename(mod.obj_file_name);

    var symbol_i: usize = 0;
    const symbol_name = if (!mod.populated) "???" else while (symbol_i != mod.symbols.len) {
        const prefix = @ptrCast(*pdb.RecordPrefix, &mod.symbols[symbol_i]);
        if (prefix.RecordLen < 2)
            return error.InvalidDebugInfo;
        switch (prefix.RecordKind) {
            pdb.SymbolKind.S_LPROC32 => {
                const proc_sym = @ptrCast(*pdb.ProcSym, &mod.symbols[symbol_i + @sizeOf(pdb.RecordPrefix)]);
                const vaddr_start = coff_section.header.virtual_address + proc_sym.CodeOffset;
                const vaddr_end = vaddr_start + proc_sym.CodeSize;
                if (relative_address >= vaddr_start and relative_address < vaddr_end) {
                    break mem.toSliceConst(u8, @ptrCast([*:0]u8, proc_sym) + @sizeOf(pdb.ProcSym));
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
                    var line_index = sect_offset;

                    const line_hdr = @ptrCast(*pdb.LineFragmentHeader, &subsect_info[line_index]);
                    if (line_hdr.RelocSegment == 0) return error.MissingDebugInfo;
                    line_index += @sizeOf(pdb.LineFragmentHeader);
                    const frag_vaddr_start = coff_section.header.virtual_address + line_hdr.RelocOffset;
                    const frag_vaddr_end = frag_vaddr_start + line_hdr.CodeSize;

                    if (relative_address >= frag_vaddr_start and relative_address < frag_vaddr_end) {
                        // There is an unknown number of LineBlockFragmentHeaders (and their accompanying line and column records)
                        // from now on. We will iterate through them, and eventually find a LineInfo that we're interested in,
                        // breaking out to :subsections. If not, we will make sure to not read anything outside of this subsection.
                        const subsection_end_index = sect_offset + subsect_hdr.Length;

                        while (line_index < subsection_end_index) {
                            const block_hdr = @ptrCast(*pdb.LineBlockFragmentHeader, &subsect_info[line_index]);
                            line_index += @sizeOf(pdb.LineBlockFragmentHeader);
                            const start_line_index = line_index;

                            const has_column = line_hdr.Flags.LF_HaveColumns;

                            // All line entries are stored inside their line block by ascending start address.
                            // Heuristic: we want to find the last line entry that has a vaddr_start <= relative_address.
                            // This is done with a simple linear search.
                            var line_i: u32 = 0;
                            while (line_i < block_hdr.NumLines) : (line_i += 1) {
                                const line_num_entry = @ptrCast(*pdb.LineNumberEntry, &subsect_info[line_index]);
                                line_index += @sizeOf(pdb.LineNumberEntry);

                                const vaddr_start = frag_vaddr_start + line_num_entry.Offset;
                                if (relative_address <= vaddr_start) {
                                    break;
                                }
                            }

                            // line_i == 0 would mean that no matching LineNumberEntry was found.
                            if (line_i > 0) {
                                const subsect_index = checksum_offset + block_hdr.NameIndex;
                                const chksum_hdr = @ptrCast(*pdb.FileChecksumEntryHeader, &mod.subsect_info[subsect_index]);
                                const strtab_offset = @sizeOf(pdb.PDBStringTableHeader) + chksum_hdr.FileNameOffset;
                                try di.pdb.string_table.seekTo(strtab_offset);
                                const source_file_name = try di.pdb.string_table.readNullTermString(allocator);

                                const line_entry_idx = line_i - 1;

                                const column = if (has_column) blk: {
                                    const start_col_index = start_line_index + @sizeOf(pdb.LineNumberEntry) * block_hdr.NumLines;
                                    const col_index = start_col_index + @sizeOf(pdb.ColumnNumberEntry) * line_entry_idx;
                                    const col_num_entry = @ptrCast(*pdb.ColumnNumberEntry, &subsect_info[col_index]);
                                    break :blk col_num_entry.StartColumn;
                                } else 0;

                                const found_line_index = start_line_index + line_entry_idx * @sizeOf(pdb.LineNumberEntry);
                                const line_num_entry = @ptrCast(*pdb.LineNumberEntry, &subsect_info[found_line_index]);
                                const flags = @ptrCast(*pdb.LineNumberEntry.Flags, &line_num_entry.Flags);

                                break :subsections LineInfo{
                                    .allocator = allocator,
                                    .file_name = source_file_name,
                                    .line = flags.Start,
                                    .column = column,
                                };
                            }
                        }

                        // Checking that we are not reading garbage after the (possibly) multiple block fragments.
                        if (line_index != subsection_end_index) {
                            return error.InvalidDebugInfo;
                        }
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
            try out_stream.print("{}:{}:{}", .{ li.file_name, li.line, li.column });
        } else {
            try out_stream.print("???:?:?", .{});
        }
        setTtyColor(TtyColor.Reset);
        try out_stream.print(": ", .{});
        setTtyColor(TtyColor.Dim);
        try out_stream.print("0x{x} in {} ({})", .{ relocated_address, symbol_name, obj_basename });
        setTtyColor(TtyColor.Reset);

        if (opt_line_info) |line_info| {
            try out_stream.print("\n", .{});
            if (printLineFromFileAnyOs(out_stream, line_info)) {
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
                error.FileNotFound => {
                    setTtyColor(TtyColor.Dim);
                    try out_stream.write("file not found\n\n");
                    setTtyColor(TtyColor.White);
                },
                else => return err,
            }
        } else {
            try out_stream.print("\n\n\n", .{});
        }
    } else {
        if (opt_line_info) |li| {
            try out_stream.print("{}:{}:{}: 0x{x} in {} ({})\n\n\n", .{
                li.file_name,
                li.line,
                li.column,
                relocated_address,
                symbol_name,
                obj_basename,
            });
        } else {
            try out_stream.print("???:?:?: 0x{x} in {} ({})\n\n\n", .{
                relocated_address,
                symbol_name,
                obj_basename,
            });
        }
    }
}

const TtyColor = enum {
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
    if (stderr_file.supportsAnsiEscapeCodes()) {
        switch (tty_color) {
            TtyColor.Red => {
                stderr_file.write(RED) catch return;
            },
            TtyColor.Green => {
                stderr_file.write(GREEN) catch return;
            },
            TtyColor.Cyan => {
                stderr_file.write(CYAN) catch return;
            },
            TtyColor.White, TtyColor.Bold => {
                stderr_file.write(WHITE) catch return;
            },
            TtyColor.Dim => {
                stderr_file.write(DIM) catch return;
            },
            TtyColor.Reset => {
                stderr_file.write(RESET) catch return;
            },
        }
    } else {
        const S = struct {
            var attrs: windows.WORD = undefined;
            var init_attrs = false;
        };
        if (!S.init_attrs) {
            S.init_attrs = true;
            var info: windows.CONSOLE_SCREEN_BUFFER_INFO = undefined;
            // TODO handle error
            _ = windows.kernel32.GetConsoleScreenBufferInfo(stderr_file.handle, &info);
            S.attrs = info.wAttributes;
        }

        // TODO handle errors
        switch (tty_color) {
            TtyColor.Red => {
                _ = windows.SetConsoleTextAttribute(stderr_file.handle, windows.FOREGROUND_RED | windows.FOREGROUND_INTENSITY) catch {};
            },
            TtyColor.Green => {
                _ = windows.SetConsoleTextAttribute(stderr_file.handle, windows.FOREGROUND_GREEN | windows.FOREGROUND_INTENSITY) catch {};
            },
            TtyColor.Cyan => {
                _ = windows.SetConsoleTextAttribute(stderr_file.handle, windows.FOREGROUND_GREEN | windows.FOREGROUND_BLUE | windows.FOREGROUND_INTENSITY) catch {};
            },
            TtyColor.White, TtyColor.Bold => {
                _ = windows.SetConsoleTextAttribute(stderr_file.handle, windows.FOREGROUND_RED | windows.FOREGROUND_GREEN | windows.FOREGROUND_BLUE | windows.FOREGROUND_INTENSITY) catch {};
            },
            TtyColor.Dim => {
                _ = windows.SetConsoleTextAttribute(stderr_file.handle, windows.FOREGROUND_INTENSITY) catch {};
            },
            TtyColor.Reset => {
                _ = windows.SetConsoleTextAttribute(stderr_file.handle, S.attrs) catch {};
            },
        }
    }
}

fn populateModule(di: *DebugInfo, mod: *Module) !void {
    if (mod.populated)
        return;
    const allocator = getDebugInfoAllocator();

    // At most one can be non-zero.
    if (mod.mod_info.C11ByteSize != 0 and mod.mod_info.C13ByteSize != 0)
        return error.InvalidDebugInfo;

    if (mod.mod_info.C13ByteSize == 0)
        return;

    const modi = di.pdb.getStreamById(mod.mod_info.ModuleSymStream) orelse return error.MissingDebugInfo;

    const signature = try modi.stream.readIntLittle(u32);
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
    const base_addr = process.getBaseAddress();
    const adjusted_addr = 0x100000000 + (address - base_addr);

    const symbol = machoSearchSymbols(di.symbols, adjusted_addr) orelse {
        if (tty_color) {
            try out_stream.print("???:?:?: " ++ DIM ++ "0x{x} in ??? (???)" ++ RESET ++ "\n\n\n", .{address});
        } else {
            try out_stream.print("???:?:?: 0x{x} in ??? (???)\n\n\n", .{address});
        }
        return;
    };

    const symbol_name = mem.toSliceConst(u8, @ptrCast([*:0]const u8, di.strings.ptr + symbol.nlist.n_strx));
    const compile_unit_name = if (symbol.ofile) |ofile| blk: {
        const ofile_path = mem.toSliceConst(u8, @ptrCast([*:0]const u8, di.strings.ptr + ofile.n_strx));
        break :blk fs.path.basename(ofile_path);
    } else "???";
    if (getLineNumberInfoMacOs(di, symbol.*, adjusted_addr)) |line_info| {
        defer line_info.deinit();
        try printLineInfo(
            out_stream,
            line_info,
            address,
            symbol_name,
            compile_unit_name,
            tty_color,
            printLineFromFileAnyOs,
        );
    } else |err| switch (err) {
        error.MissingDebugInfo, error.InvalidDebugInfo => {
            if (tty_color) {
                try out_stream.print("???:?:?: " ++ DIM ++ "0x{x} in {} ({})" ++ RESET ++ "\n\n\n", .{
                    address, symbol_name, compile_unit_name,
                });
            } else {
                try out_stream.print("???:?:?: 0x{x} in {} ({})\n\n\n", .{ address, symbol_name, compile_unit_name });
            }
        },
        else => return err,
    }
}

pub fn printSourceAtAddressPosix(debug_info: *DebugInfo, out_stream: var, address: usize, tty_color: bool) !void {
    return debug_info.printSourceAtAddress(out_stream, address, tty_color, printLineFromFileAnyOs);
}

fn printLineInfo(
    out_stream: var,
    line_info: LineInfo,
    address: usize,
    symbol_name: []const u8,
    compile_unit_name: []const u8,
    tty_color: bool,
    comptime printLineFromFile: var,
) !void {
    if (tty_color) {
        try out_stream.print(WHITE ++ "{}:{}:{}" ++ RESET ++ ": " ++ DIM ++ "0x{x} in {} ({})" ++ RESET ++ "\n", .{
            line_info.file_name,
            line_info.line,
            line_info.column,
            address,
            symbol_name,
            compile_unit_name,
        });
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
            error.EndOfFile, error.FileNotFound => {},
            else => return err,
        }
    } else {
        try out_stream.print("{}:{}:{}: 0x{x} in {} ({})\n", .{
            line_info.file_name,
            line_info.line,
            line_info.column,
            address,
            symbol_name,
            compile_unit_name,
        });
    }
}

// TODO use this
pub const OpenSelfDebugInfoError = error{
    MissingDebugInfo,
    OutOfMemory,
    UnsupportedOperatingSystem,
};

/// TODO once https://github.com/ziglang/zig/issues/3157 is fully implemented,
/// make this `noasync fn` and remove the individual noasync calls.
pub fn openSelfDebugInfo(allocator: *mem.Allocator) !DebugInfo {
    if (builtin.strip_debug_info)
        return error.MissingDebugInfo;
    if (@hasDecl(root, "os") and @hasDecl(root.os, "debug") and @hasDecl(root.os.debug, "openSelfDebugInfo")) {
        return noasync root.os.debug.openSelfDebugInfo(allocator);
    }
    if (builtin.os == .windows) {
        return noasync openSelfDebugInfoWindows(allocator);
    }
    if (comptime std.Target.current.isDarwin()) {
        return noasync openSelfDebugInfoMacOs(allocator);
    }
    return noasync openSelfDebugInfoPosix(allocator);
}

fn openSelfDebugInfoWindows(allocator: *mem.Allocator) !DebugInfo {
    const self_file = try fs.openSelfExe();
    defer self_file.close();

    const coff_obj = try allocator.create(coff.Coff);
    coff_obj.* = coff.Coff.init(allocator, self_file);

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

    const path = try fs.path.resolve(allocator, &[_][]const u8{raw_path});

    try di.pdb.openFile(di.coff, path);

    var pdb_stream = di.pdb.getStream(pdb.StreamType.Pdb) orelse return error.InvalidDebugInfo;
    const version = try pdb_stream.stream.readIntLittle(u32);
    const signature = try pdb_stream.stream.readIntLittle(u32);
    const age = try pdb_stream.stream.readIntLittle(u32);
    var guid: [16]u8 = undefined;
    try pdb_stream.stream.readNoEof(&guid);
    if (version != 20000404) // VC70, only value observed by LLVM team
        return error.UnknownPDBVersion;
    if (!mem.eql(u8, &di.coff.guid, &guid) or di.coff.age != age)
        return error.PDBMismatch;
    // We validated the executable and pdb match.

    const string_table_index = str_tab_index: {
        const name_bytes_len = try pdb_stream.stream.readIntLittle(u32);
        const name_bytes = try allocator.alloc(u8, name_bytes_len);
        try pdb_stream.stream.readNoEof(name_bytes);

        const HashTableHeader = packed struct {
            Size: u32,
            Capacity: u32,

            fn maxLoad(cap: u32) u32 {
                return cap * 2 / 3 + 1;
            }
        };
        const hash_tbl_hdr = try pdb_stream.stream.readStruct(HashTableHeader);
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
            const name_offset = try pdb_stream.stream.readIntLittle(u32);
            const name_index = try pdb_stream.stream.readIntLittle(u32);
            const name = mem.toSlice(u8, @ptrCast([*:0]u8, name_bytes.ptr + name_offset));
            if (mem.eql(u8, name, "/names")) {
                break :str_tab_index name_index;
            }
        }
        return error.MissingDebugInfo;
    };

    di.pdb.string_table = di.pdb.getStreamById(string_table_index) orelse return error.MissingDebugInfo;
    di.pdb.dbi = di.pdb.getStream(pdb.StreamType.Dbi) orelse return error.MissingDebugInfo;

    const dbi = di.pdb.dbi;

    // Dbi Header
    const dbi_stream_header = try dbi.stream.readStruct(pdb.DbiStreamHeader);
    if (dbi_stream_header.VersionHeader != 19990903) // V70, only value observed by LLVM team
        return error.UnknownPDBVersion;
    if (dbi_stream_header.Age != age)
        return error.UnmatchingPDB;

    const mod_info_size = dbi_stream_header.ModInfoSize;
    const section_contrib_size = dbi_stream_header.SectionContributionSize;

    var modules = ArrayList(Module).init(allocator);

    // Module Info Substream
    var mod_info_offset: usize = 0;
    while (mod_info_offset != mod_info_size) {
        const mod_info = try dbi.stream.readStruct(pdb.ModInfo);
        var this_record_len: usize = @sizeOf(pdb.ModInfo);

        const module_name = try dbi.readNullTermString(allocator);
        this_record_len += module_name.len + 1;

        const obj_file_name = try dbi.readNullTermString(allocator);
        this_record_len += obj_file_name.len + 1;

        if (this_record_len % 4 != 0) {
            const round_to_next_4 = (this_record_len | 0x3) + 1;
            const march_forward_bytes = round_to_next_4 - this_record_len;
            try dbi.seekBy(@intCast(isize, march_forward_bytes));
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
        const ver = @intToEnum(pdb.SectionContrSubstreamVersion, try dbi.stream.readIntLittle(u32));
        if (ver != pdb.SectionContrSubstreamVersion.Ver60)
            return error.InvalidDebugInfo;
        sect_cont_offset += @sizeOf(u32);
    }
    while (sect_cont_offset != section_contrib_size) {
        const entry = try sect_contribs.addOne();
        entry.* = try dbi.stream.readStruct(pdb.SectionContribEntry);
        sect_cont_offset += @sizeOf(pdb.SectionContribEntry);

        if (sect_cont_offset > section_contrib_size)
            return error.InvalidDebugInfo;
    }

    di.sect_contribs = sect_contribs.toOwnedSlice();

    return di;
}

fn readSparseBitVector(stream: var, allocator: *mem.Allocator) ![]usize {
    const num_words = try stream.readIntLittle(u32);
    var word_i: usize = 0;
    var list = ArrayList(usize).init(allocator);
    while (word_i != num_words) : (word_i += 1) {
        const word = try stream.readIntLittle(u32);
        var bit_i: u5 = 0;
        while (true) : (bit_i += 1) {
            if (word & (@as(u32, 1) << bit_i) != 0) {
                try list.append(word_i * 32 + bit_i);
            }
            if (bit_i == maxInt(u5)) break;
        }
    }
    return list.toOwnedSlice();
}

fn findDwarfSectionFromElf(elf_file: *elf.Elf, name: []const u8) !?DwarfInfo.Section {
    const elf_header = (try elf_file.findSection(name)) orelse return null;
    return DwarfInfo.Section{
        .offset = elf_header.offset,
        .size = elf_header.size,
    };
}

/// Initialize DWARF info. The caller has the responsibility to initialize most
/// the DwarfInfo fields before calling. These fields can be left undefined:
/// * abbrev_table_list
/// * compile_unit_list
pub fn openDwarfDebugInfo(di: *DwarfInfo, allocator: *mem.Allocator) !void {
    di.abbrev_table_list = ArrayList(AbbrevTableHeader).init(allocator);
    di.compile_unit_list = ArrayList(CompileUnit).init(allocator);
    di.func_list = ArrayList(Func).init(allocator);
    try di.scanAllFunctions();
    try di.scanAllCompileUnits();
}

pub fn openElfDebugInfo(
    allocator: *mem.Allocator,
    elf_seekable_stream: *DwarfSeekableStream,
    elf_in_stream: *DwarfInStream,
) !DwarfInfo {
    var efile = try elf.Elf.openStream(allocator, elf_seekable_stream, elf_in_stream);
    errdefer efile.close();

    var di = DwarfInfo{
        .dwarf_seekable_stream = elf_seekable_stream,
        .dwarf_in_stream = elf_in_stream,
        .endian = efile.endian,
        .debug_info = (try findDwarfSectionFromElf(&efile, ".debug_info")) orelse return error.MissingDebugInfo,
        .debug_abbrev = (try findDwarfSectionFromElf(&efile, ".debug_abbrev")) orelse return error.MissingDebugInfo,
        .debug_str = (try findDwarfSectionFromElf(&efile, ".debug_str")) orelse return error.MissingDebugInfo,
        .debug_line = (try findDwarfSectionFromElf(&efile, ".debug_line")) orelse return error.MissingDebugInfo,
        .debug_ranges = (try findDwarfSectionFromElf(&efile, ".debug_ranges")),
        .abbrev_table_list = undefined,
        .compile_unit_list = undefined,
        .func_list = undefined,
    };
    try openDwarfDebugInfo(&di, allocator);
    return di;
}

fn openSelfDebugInfoPosix(allocator: *mem.Allocator) !DwarfInfo {
    const S = struct {
        var self_exe_file: File = undefined;
        var self_exe_mmap_seekable: io.SliceSeekableInStream = undefined;
    };

    S.self_exe_file = try fs.openSelfExe();
    errdefer S.self_exe_file.close();

    const self_exe_len = math.cast(usize, try S.self_exe_file.getEndPos()) catch return error.DebugInfoTooLarge;
    const self_exe_mmap_len = mem.alignForward(self_exe_len, mem.page_size);
    const self_exe_mmap = try os.mmap(
        null,
        self_exe_mmap_len,
        os.PROT_READ,
        os.MAP_SHARED,
        S.self_exe_file.handle,
        0,
    );
    errdefer os.munmap(self_exe_mmap);

    S.self_exe_mmap_seekable = io.SliceSeekableInStream.init(self_exe_mmap);

    return openElfDebugInfo(
        allocator,
        // TODO https://github.com/ziglang/zig/issues/764
        @ptrCast(*DwarfSeekableStream, &S.self_exe_mmap_seekable.seekable_stream),
        // TODO https://github.com/ziglang/zig/issues/764
        @ptrCast(*DwarfInStream, &S.self_exe_mmap_seekable.stream),
    );
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
        ptr = @alignCast(@alignOf(std.macho.load_command), ptr + lc.cmdsize);
    } else {
        return error.MissingDebugInfo;
    };
    const syms = @ptrCast([*]macho.nlist_64, @alignCast(@alignOf(macho.nlist_64), hdr_base + symtab.symoff))[0..symtab.nsyms];
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
    const sentinel = try allocator.create(macho.nlist_64);
    sentinel.* = macho.nlist_64{
        .n_strx = 0,
        .n_type = 36,
        .n_sect = 0,
        .n_desc = 0,
        .n_value = symbols_buf[symbol_index - 1].nlist.n_value + last_len,
    };

    const symbols = allocator.shrink(symbols_buf, symbol_index);

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

fn printLineFromFileAnyOs(out_stream: var, line_info: LineInfo) !void {
    var f = try fs.cwd().openFile(line_info.file_name, .{});
    defer f.close();
    // TODO fstat and make sure that the file has the correct size

    var buf: [mem.page_size]u8 = undefined;
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

pub const DwarfSeekableStream = io.SeekableStream(anyerror, anyerror);
pub const DwarfInStream = io.InStream(anyerror);

pub const DwarfInfo = struct {
    dwarf_seekable_stream: *DwarfSeekableStream,
    dwarf_in_stream: *DwarfInStream,
    endian: builtin.Endian,
    debug_info: Section,
    debug_abbrev: Section,
    debug_str: Section,
    debug_line: Section,
    debug_ranges: ?Section,
    abbrev_table_list: ArrayList(AbbrevTableHeader),
    compile_unit_list: ArrayList(CompileUnit),
    func_list: ArrayList(Func),

    pub const Section = struct {
        offset: u64,
        size: u64,
    };

    pub fn allocator(self: DwarfInfo) *mem.Allocator {
        return self.abbrev_table_list.allocator;
    }

    pub fn readString(self: *DwarfInfo) ![]u8 {
        return readStringRaw(self.allocator(), self.dwarf_in_stream);
    }

    /// This function works in freestanding mode.
    /// fn printLineFromFile(out_stream: var, line_info: LineInfo) !void
    pub fn printSourceAtAddress(
        self: *DwarfInfo,
        out_stream: var,
        address: usize,
        tty_color: bool,
        comptime printLineFromFile: var,
    ) !void {
        const compile_unit = self.findCompileUnit(address) catch {
            if (tty_color) {
                try out_stream.print("???:?:?: " ++ DIM ++ "0x{x} in ??? (???)" ++ RESET ++ "\n\n\n", .{address});
            } else {
                try out_stream.print("???:?:?: 0x{x} in ??? (???)\n\n\n", .{address});
            }
            return;
        };
        const compile_unit_name = try compile_unit.die.getAttrString(self, DW.AT_name);
        if (self.getLineNumberInfo(compile_unit.*, address)) |line_info| {
            defer line_info.deinit();
            const symbol_name = self.getSymbolName(address) orelse "???";
            try printLineInfo(
                out_stream,
                line_info,
                address,
                symbol_name,
                compile_unit_name,
                tty_color,
                printLineFromFile,
            );
        } else |err| switch (err) {
            error.MissingDebugInfo, error.InvalidDebugInfo => {
                if (tty_color) {
                    try out_stream.print("???:?:?: " ++ DIM ++ "0x{x} in ??? ({})" ++ RESET ++ "\n\n\n", .{
                        address, compile_unit_name,
                    });
                } else {
                    try out_stream.print("???:?:?: 0x{x} in ??? ({})\n\n\n", .{ address, compile_unit_name });
                }
            },
            else => return err,
        }
    }

    fn getSymbolName(di: *DwarfInfo, address: u64) ?[]const u8 {
        for (di.func_list.toSliceConst()) |*func| {
            if (func.pc_range) |range| {
                if (address >= range.start and address < range.end) {
                    return func.name;
                }
            }
        }

        return null;
    }

    fn scanAllFunctions(di: *DwarfInfo) !void {
        const debug_info_end = di.debug_info.offset + di.debug_info.size;
        var this_unit_offset = di.debug_info.offset;

        while (this_unit_offset < debug_info_end) {
            try di.dwarf_seekable_stream.seekTo(this_unit_offset);

            var is_64: bool = undefined;
            const unit_length = try readInitialLength(@TypeOf(di.dwarf_in_stream.readFn).ReturnType.ErrorSet, di.dwarf_in_stream, &is_64);
            if (unit_length == 0) return;
            const next_offset = unit_length + (if (is_64) @as(usize, 12) else @as(usize, 4));

            const version = try di.dwarf_in_stream.readInt(u16, di.endian);
            if (version < 2 or version > 5) return error.InvalidDebugInfo;

            const debug_abbrev_offset = if (is_64) try di.dwarf_in_stream.readInt(u64, di.endian) else try di.dwarf_in_stream.readInt(u32, di.endian);

            const address_size = try di.dwarf_in_stream.readByte();
            if (address_size != @sizeOf(usize)) return error.InvalidDebugInfo;

            const compile_unit_pos = try di.dwarf_seekable_stream.getPos();
            const abbrev_table = try di.getAbbrevTable(debug_abbrev_offset);

            try di.dwarf_seekable_stream.seekTo(compile_unit_pos);

            const next_unit_pos = this_unit_offset + next_offset;

            while ((try di.dwarf_seekable_stream.getPos()) < next_unit_pos) {
                const die_obj = (try di.parseDie(abbrev_table, is_64)) orelse continue;
                const after_die_offset = try di.dwarf_seekable_stream.getPos();

                switch (die_obj.tag_id) {
                    DW.TAG_subprogram, DW.TAG_inlined_subroutine, DW.TAG_subroutine, DW.TAG_entry_point => {
                        const fn_name = x: {
                            var depth: i32 = 3;
                            var this_die_obj = die_obj;
                            // Prenvent endless loops
                            while (depth > 0) : (depth -= 1) {
                                if (this_die_obj.getAttr(DW.AT_name)) |_| {
                                    const name = try this_die_obj.getAttrString(di, DW.AT_name);
                                    break :x name;
                                } else if (this_die_obj.getAttr(DW.AT_abstract_origin)) |ref| {
                                    // Follow the DIE it points to and repeat
                                    const ref_offset = try this_die_obj.getAttrRef(DW.AT_abstract_origin);
                                    if (ref_offset > next_offset) return error.InvalidDebugInfo;
                                    try di.dwarf_seekable_stream.seekTo(this_unit_offset + ref_offset);
                                    this_die_obj = (try di.parseDie(abbrev_table, is_64)) orelse return error.InvalidDebugInfo;
                                } else if (this_die_obj.getAttr(DW.AT_specification)) |ref| {
                                    // Follow the DIE it points to and repeat
                                    const ref_offset = try this_die_obj.getAttrRef(DW.AT_specification);
                                    if (ref_offset > next_offset) return error.InvalidDebugInfo;
                                    try di.dwarf_seekable_stream.seekTo(this_unit_offset + ref_offset);
                                    this_die_obj = (try di.parseDie(abbrev_table, is_64)) orelse return error.InvalidDebugInfo;
                                } else {
                                    break :x null;
                                }
                            }

                            break :x null;
                        };

                        const pc_range = x: {
                            if (die_obj.getAttrAddr(DW.AT_low_pc)) |low_pc| {
                                if (die_obj.getAttr(DW.AT_high_pc)) |high_pc_value| {
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

                        try di.func_list.append(Func{
                            .name = fn_name,
                            .pc_range = pc_range,
                        });
                    },
                    else => {
                        continue;
                    },
                }

                try di.dwarf_seekable_stream.seekTo(after_die_offset);
            }

            this_unit_offset += next_offset;
        }
    }

    fn scanAllCompileUnits(di: *DwarfInfo) !void {
        const debug_info_end = di.debug_info.offset + di.debug_info.size;
        var this_unit_offset = di.debug_info.offset;

        while (this_unit_offset < debug_info_end) {
            try di.dwarf_seekable_stream.seekTo(this_unit_offset);

            var is_64: bool = undefined;
            const unit_length = try readInitialLength(@TypeOf(di.dwarf_in_stream.readFn).ReturnType.ErrorSet, di.dwarf_in_stream, &is_64);
            if (unit_length == 0) return;
            const next_offset = unit_length + (if (is_64) @as(usize, 12) else @as(usize, 4));

            const version = try di.dwarf_in_stream.readInt(u16, di.endian);
            if (version < 2 or version > 5) return error.InvalidDebugInfo;

            const debug_abbrev_offset = if (is_64) try di.dwarf_in_stream.readInt(u64, di.endian) else try di.dwarf_in_stream.readInt(u32, di.endian);

            const address_size = try di.dwarf_in_stream.readByte();
            if (address_size != @sizeOf(usize)) return error.InvalidDebugInfo;

            const compile_unit_pos = try di.dwarf_seekable_stream.getPos();
            const abbrev_table = try di.getAbbrevTable(debug_abbrev_offset);

            try di.dwarf_seekable_stream.seekTo(compile_unit_pos);

            const compile_unit_die = try di.allocator().create(Die);
            compile_unit_die.* = (try di.parseDie(abbrev_table, is_64)) orelse return error.InvalidDebugInfo;

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

            try di.compile_unit_list.append(CompileUnit{
                .version = version,
                .is_64 = is_64,
                .pc_range = pc_range,
                .die = compile_unit_die,
            });

            this_unit_offset += next_offset;
        }
    }

    fn findCompileUnit(di: *DwarfInfo, target_address: u64) !*const CompileUnit {
        for (di.compile_unit_list.toSlice()) |*compile_unit| {
            if (compile_unit.pc_range) |range| {
                if (target_address >= range.start and target_address < range.end) return compile_unit;
            }
            if (compile_unit.die.getAttrSecOffset(DW.AT_ranges)) |ranges_offset| {
                var base_address: usize = 0;
                if (di.debug_ranges) |debug_ranges| {
                    try di.dwarf_seekable_stream.seekTo(debug_ranges.offset + ranges_offset);
                    while (true) {
                        const begin_addr = try di.dwarf_in_stream.readIntLittle(usize);
                        const end_addr = try di.dwarf_in_stream.readIntLittle(usize);
                        if (begin_addr == 0 and end_addr == 0) {
                            break;
                        }
                        if (begin_addr == maxInt(usize)) {
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

    /// Gets an already existing AbbrevTable given the abbrev_offset, or if not found,
    /// seeks in the stream and parses it.
    fn getAbbrevTable(di: *DwarfInfo, abbrev_offset: u64) !*const AbbrevTable {
        for (di.abbrev_table_list.toSlice()) |*header| {
            if (header.offset == abbrev_offset) {
                return &header.table;
            }
        }
        try di.dwarf_seekable_stream.seekTo(di.debug_abbrev.offset + abbrev_offset);
        try di.abbrev_table_list.append(AbbrevTableHeader{
            .offset = abbrev_offset,
            .table = try di.parseAbbrevTable(),
        });
        return &di.abbrev_table_list.items[di.abbrev_table_list.len - 1].table;
    }

    fn parseAbbrevTable(di: *DwarfInfo) !AbbrevTable {
        var result = AbbrevTable.init(di.allocator());
        while (true) {
            const abbrev_code = try leb.readULEB128(u64, di.dwarf_in_stream);
            if (abbrev_code == 0) return result;
            try result.append(AbbrevTableEntry{
                .abbrev_code = abbrev_code,
                .tag_id = try leb.readULEB128(u64, di.dwarf_in_stream),
                .has_children = (try di.dwarf_in_stream.readByte()) == DW.CHILDREN_yes,
                .attrs = ArrayList(AbbrevAttr).init(di.allocator()),
            });
            const attrs = &result.items[result.len - 1].attrs;

            while (true) {
                const attr_id = try leb.readULEB128(u64, di.dwarf_in_stream);
                const form_id = try leb.readULEB128(u64, di.dwarf_in_stream);
                if (attr_id == 0 and form_id == 0) break;
                try attrs.append(AbbrevAttr{
                    .attr_id = attr_id,
                    .form_id = form_id,
                });
            }
        }
    }

    fn parseDie(di: *DwarfInfo, abbrev_table: *const AbbrevTable, is_64: bool) !?Die {
        const abbrev_code = try leb.readULEB128(u64, di.dwarf_in_stream);
        if (abbrev_code == 0) return null;
        const table_entry = getAbbrevTableEntry(abbrev_table, abbrev_code) orelse return error.InvalidDebugInfo;

        var result = Die{
            .tag_id = table_entry.tag_id,
            .has_children = table_entry.has_children,
            .attrs = ArrayList(Die.Attr).init(di.allocator()),
        };
        try result.attrs.resize(table_entry.attrs.len);
        for (table_entry.attrs.toSliceConst()) |attr, i| {
            result.attrs.items[i] = Die.Attr{
                .id = attr.attr_id,
                .value = try parseFormValue(di.allocator(), di.dwarf_in_stream, attr.form_id, is_64),
            };
        }
        return result;
    }

    fn getLineNumberInfo(di: *DwarfInfo, compile_unit: CompileUnit, target_address: usize) !LineInfo {
        const compile_unit_cwd = try compile_unit.die.getAttrString(di, DW.AT_comp_dir);
        const line_info_offset = try compile_unit.die.getAttrSecOffset(DW.AT_stmt_list);

        assert(line_info_offset < di.debug_line.size);

        try di.dwarf_seekable_stream.seekTo(di.debug_line.offset + line_info_offset);

        var is_64: bool = undefined;
        const unit_length = try readInitialLength(@TypeOf(di.dwarf_in_stream.readFn).ReturnType.ErrorSet, di.dwarf_in_stream, &is_64);
        if (unit_length == 0) {
            return error.MissingDebugInfo;
        }
        const next_offset = unit_length + (if (is_64) @as(usize, 12) else @as(usize, 4));

        const version = try di.dwarf_in_stream.readInt(u16, di.endian);
        // TODO support 3 and 5
        if (version != 2 and version != 4) return error.InvalidDebugInfo;

        const prologue_length = if (is_64) try di.dwarf_in_stream.readInt(u64, di.endian) else try di.dwarf_in_stream.readInt(u32, di.endian);
        const prog_start_offset = (try di.dwarf_seekable_stream.getPos()) + prologue_length;

        const minimum_instruction_length = try di.dwarf_in_stream.readByte();
        if (minimum_instruction_length == 0) return error.InvalidDebugInfo;

        if (version >= 4) {
            // maximum_operations_per_instruction
            _ = try di.dwarf_in_stream.readByte();
        }

        const default_is_stmt = (try di.dwarf_in_stream.readByte()) != 0;
        const line_base = try di.dwarf_in_stream.readByteSigned();

        const line_range = try di.dwarf_in_stream.readByte();
        if (line_range == 0) return error.InvalidDebugInfo;

        const opcode_base = try di.dwarf_in_stream.readByte();

        const standard_opcode_lengths = try di.allocator().alloc(u8, opcode_base - 1);

        {
            var i: usize = 0;
            while (i < opcode_base - 1) : (i += 1) {
                standard_opcode_lengths[i] = try di.dwarf_in_stream.readByte();
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
            const dir_index = try leb.readULEB128(usize, di.dwarf_in_stream);
            const mtime = try leb.readULEB128(usize, di.dwarf_in_stream);
            const len_bytes = try leb.readULEB128(usize, di.dwarf_in_stream);
            try file_entries.append(FileEntry{
                .file_name = file_name,
                .dir_index = dir_index,
                .mtime = mtime,
                .len_bytes = len_bytes,
            });
        }

        try di.dwarf_seekable_stream.seekTo(prog_start_offset);

        while (true) {
            const opcode = try di.dwarf_in_stream.readByte();

            if (opcode == DW.LNS_extended_op) {
                const op_size = try leb.readULEB128(u64, di.dwarf_in_stream);
                if (op_size < 1) return error.InvalidDebugInfo;
                var sub_op = try di.dwarf_in_stream.readByte();
                switch (sub_op) {
                    DW.LNE_end_sequence => {
                        prog.end_sequence = true;
                        if (try prog.checkLineMatch()) |info| return info;
                        return error.MissingDebugInfo;
                    },
                    DW.LNE_set_address => {
                        const addr = try di.dwarf_in_stream.readInt(usize, di.endian);
                        prog.address = addr;
                    },
                    DW.LNE_define_file => {
                        const file_name = try di.readString();
                        const dir_index = try leb.readULEB128(usize, di.dwarf_in_stream);
                        const mtime = try leb.readULEB128(usize, di.dwarf_in_stream);
                        const len_bytes = try leb.readULEB128(usize, di.dwarf_in_stream);
                        try file_entries.append(FileEntry{
                            .file_name = file_name,
                            .dir_index = dir_index,
                            .mtime = mtime,
                            .len_bytes = len_bytes,
                        });
                    },
                    else => {
                        const fwd_amt = math.cast(isize, op_size - 1) catch return error.InvalidDebugInfo;
                        try di.dwarf_seekable_stream.seekBy(fwd_amt);
                    },
                }
            } else if (opcode >= opcode_base) {
                // special opcodes
                const adjusted_opcode = opcode - opcode_base;
                const inc_addr = minimum_instruction_length * (adjusted_opcode / line_range);
                const inc_line = @as(i32, line_base) + @as(i32, adjusted_opcode % line_range);
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
                        const arg = try leb.readULEB128(usize, di.dwarf_in_stream);
                        prog.address += arg * minimum_instruction_length;
                    },
                    DW.LNS_advance_line => {
                        const arg = try leb.readILEB128(i64, di.dwarf_in_stream);
                        prog.line += arg;
                    },
                    DW.LNS_set_file => {
                        const arg = try leb.readULEB128(usize, di.dwarf_in_stream);
                        prog.file = arg;
                    },
                    DW.LNS_set_column => {
                        const arg = try leb.readULEB128(u64, di.dwarf_in_stream);
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
                        const arg = try di.dwarf_in_stream.readInt(u16, di.endian);
                        prog.address += arg;
                    },
                    DW.LNS_set_prologue_end => {},
                    else => {
                        if (opcode - 1 >= standard_opcode_lengths.len) return error.InvalidDebugInfo;
                        const len_bytes = standard_opcode_lengths[opcode - 1];
                        try di.dwarf_seekable_stream.seekBy(len_bytes);
                    },
                }
            }
        }

        return error.MissingDebugInfo;
    }

    fn getString(di: *DwarfInfo, offset: u64) ![]u8 {
        const pos = di.debug_str.offset + offset;
        try di.dwarf_seekable_stream.seekTo(pos);
        return di.readString();
    }
};

pub const DebugInfo = switch (builtin.os) {
    .macosx, .ios, .watchos, .tvos => struct {
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
    .uefi, .windows => struct {
        pdb: pdb.Pdb,
        coff: *coff.Coff,
        sect_contribs: []pdb.SectionContribEntry,
        modules: []Module,
    },
    else => DwarfInfo,
};

const PcRange = struct {
    start: u64,
    end: u64,
};

const CompileUnit = struct {
    version: u16,
    is_64: bool,
    die: *Die,
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
    Ref: u64,
    RefAddr: u64,
    String: []u8,
    StrPtr: u64,
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

    fn getAttrRef(self: *const Die, id: u64) !u64 {
        const form_value = self.getAttr(id) orelse return error.MissingDebugInfo;
        return switch (form_value.*) {
            FormValue.Ref => |value| value,
            else => error.InvalidDebugInfo,
        };
    }

    fn getAttrString(self: *const Die, di: *DwarfInfo, id: u64) ![]u8 {
        const form_value = self.getAttr(id) orelse return error.MissingDebugInfo;
        return switch (form_value.*) {
            FormValue.String => |value| value,
            FormValue.StrPtr => |offset| di.getString(offset),
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

pub const LineInfo = struct {
    line: u64,
    column: u64,
    file_name: []const u8,
    allocator: ?*mem.Allocator,

    fn deinit(self: LineInfo) void {
        const allocator = self.allocator orelse return;
        allocator.free(self.file_name);
    }
};

const LineNumberProgram = struct {
    address: usize,
    file: usize,
    line: i64,
    column: u64,
    is_stmt: bool,
    basic_block: bool,
    end_sequence: bool,

    target_address: usize,
    include_dirs: []const []const u8,
    file_entries: *ArrayList(FileEntry),

    prev_address: usize,
    prev_file: usize,
    prev_line: i64,
    prev_column: u64,
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
            const file_name = try fs.path.join(self.file_entries.allocator, &[_][]const u8{ dir_name, file_entry.file_name });
            errdefer self.file_entries.allocator.free(file_name);
            return LineInfo{
                .line = if (self.prev_line >= 0) @intCast(u64, self.prev_line) else 0,
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

// TODO the noasyncs here are workarounds
fn readStringRaw(allocator: *mem.Allocator, in_stream: var) ![]u8 {
    var buf = ArrayList(u8).init(allocator);
    while (true) {
        const byte = try noasync in_stream.readByte();
        if (byte == 0) break;
        try buf.append(byte);
    }
    return buf.toSlice();
}

// TODO the noasyncs here are workarounds
fn readAllocBytes(allocator: *mem.Allocator, in_stream: var, size: usize) ![]u8 {
    const buf = try allocator.alloc(u8, size);
    errdefer allocator.free(buf);
    if ((try noasync in_stream.read(buf)) < size) return error.EndOfFile;
    return buf;
}

fn parseFormValueBlockLen(allocator: *mem.Allocator, in_stream: var, size: usize) !FormValue {
    const buf = try readAllocBytes(allocator, in_stream, size);
    return FormValue{ .Block = buf };
}

// TODO the noasyncs here are workarounds
fn parseFormValueBlock(allocator: *mem.Allocator, in_stream: var, size: usize) !FormValue {
    const block_len = try noasync in_stream.readVarInt(usize, builtin.Endian.Little, size);
    return parseFormValueBlockLen(allocator, in_stream, block_len);
}

fn parseFormValueConstant(allocator: *mem.Allocator, in_stream: var, signed: bool, comptime size: i32) !FormValue {
    // TODO: Please forgive me, I've worked around zig not properly spilling some intermediate values here.
    // `noasync` should be removed from all the function calls once it is fixed.
    return FormValue{
        .Const = Constant{
            .signed = signed,
            .payload = switch (size) {
                1 => try noasync in_stream.readIntLittle(u8),
                2 => try noasync in_stream.readIntLittle(u16),
                4 => try noasync in_stream.readIntLittle(u32),
                8 => try noasync in_stream.readIntLittle(u64),
                -1 => blk: {
                    if (signed) {
                        const x = try noasync leb.readILEB128(i64, in_stream);
                        break :blk @bitCast(u64, x);
                    } else {
                        const x = try noasync leb.readULEB128(u64, in_stream);
                        break :blk x;
                    }
                },
                else => @compileError("Invalid size"),
            },
        },
    };
}

// TODO the noasyncs here are workarounds
fn parseFormValueDwarfOffsetSize(in_stream: var, is_64: bool) !u64 {
    return if (is_64) try noasync in_stream.readIntLittle(u64) else @as(u64, try noasync in_stream.readIntLittle(u32));
}

// TODO the noasyncs here are workarounds
fn parseFormValueTargetAddrSize(in_stream: var) !u64 {
    if (@sizeOf(usize) == 4) {
        // TODO this cast should not be needed
        return @as(u64, try noasync in_stream.readIntLittle(u32));
    } else if (@sizeOf(usize) == 8) {
        return noasync in_stream.readIntLittle(u64);
    } else {
        unreachable;
    }
}

// TODO the noasyncs here are workarounds
fn parseFormValueRef(allocator: *mem.Allocator, in_stream: var, size: i32) !FormValue {
    return FormValue{
        .Ref = switch (size) {
            1 => try noasync in_stream.readIntLittle(u8),
            2 => try noasync in_stream.readIntLittle(u16),
            4 => try noasync in_stream.readIntLittle(u32),
            8 => try noasync in_stream.readIntLittle(u64),
            -1 => try noasync leb.readULEB128(u64, in_stream),
            else => unreachable,
        },
    };
}

// TODO the noasyncs here are workarounds
fn parseFormValue(allocator: *mem.Allocator, in_stream: var, form_id: u64, is_64: bool) anyerror!FormValue {
    return switch (form_id) {
        DW.FORM_addr => FormValue{ .Address = try parseFormValueTargetAddrSize(in_stream) },
        DW.FORM_block1 => parseFormValueBlock(allocator, in_stream, 1),
        DW.FORM_block2 => parseFormValueBlock(allocator, in_stream, 2),
        DW.FORM_block4 => parseFormValueBlock(allocator, in_stream, 4),
        DW.FORM_block => x: {
            const block_len = try noasync leb.readULEB128(usize, in_stream);
            return parseFormValueBlockLen(allocator, in_stream, block_len);
        },
        DW.FORM_data1 => parseFormValueConstant(allocator, in_stream, false, 1),
        DW.FORM_data2 => parseFormValueConstant(allocator, in_stream, false, 2),
        DW.FORM_data4 => parseFormValueConstant(allocator, in_stream, false, 4),
        DW.FORM_data8 => parseFormValueConstant(allocator, in_stream, false, 8),
        DW.FORM_udata, DW.FORM_sdata => {
            const signed = form_id == DW.FORM_sdata;
            return parseFormValueConstant(allocator, in_stream, signed, -1);
        },
        DW.FORM_exprloc => {
            const size = try noasync leb.readULEB128(usize, in_stream);
            const buf = try readAllocBytes(allocator, in_stream, size);
            return FormValue{ .ExprLoc = buf };
        },
        DW.FORM_flag => FormValue{ .Flag = (try noasync in_stream.readByte()) != 0 },
        DW.FORM_flag_present => FormValue{ .Flag = true },
        DW.FORM_sec_offset => FormValue{ .SecOffset = try parseFormValueDwarfOffsetSize(in_stream, is_64) },

        DW.FORM_ref1 => parseFormValueRef(allocator, in_stream, 1),
        DW.FORM_ref2 => parseFormValueRef(allocator, in_stream, 2),
        DW.FORM_ref4 => parseFormValueRef(allocator, in_stream, 4),
        DW.FORM_ref8 => parseFormValueRef(allocator, in_stream, 8),
        DW.FORM_ref_udata => parseFormValueRef(allocator, in_stream, -1),

        DW.FORM_ref_addr => FormValue{ .RefAddr = try parseFormValueDwarfOffsetSize(in_stream, is_64) },
        DW.FORM_ref_sig8 => FormValue{ .Ref = try noasync in_stream.readIntLittle(u64) },

        DW.FORM_string => FormValue{ .String = try readStringRaw(allocator, in_stream) },
        DW.FORM_strp => FormValue{ .StrPtr = try parseFormValueDwarfOffsetSize(in_stream, is_64) },
        DW.FORM_indirect => {
            const child_form_id = try noasync leb.readULEB128(u64, in_stream);
            const F = @TypeOf(async parseFormValue(allocator, in_stream, child_form_id, is_64));
            var frame = try allocator.create(F);
            defer allocator.destroy(frame);
            return await @asyncCall(frame, {}, parseFormValue, allocator, in_stream, child_form_id, is_64);
        },
        else => error.InvalidDebugInfo,
    };
}

fn getAbbrevTableEntry(abbrev_table: *const AbbrevTable, abbrev_code: u64) ?*const AbbrevTableEntry {
    for (abbrev_table.toSliceConst()) |*table_entry| {
        if (table_entry.abbrev_code == abbrev_code) return table_entry;
    }
    return null;
}

fn getLineNumberInfoMacOs(di: *DebugInfo, symbol: MachoSymbol, target_address: usize) !LineInfo {
    const ofile = symbol.ofile orelse return error.MissingDebugInfo;
    const gop = try di.ofiles.getOrPut(ofile);
    const mach_o_file = if (gop.found_existing) &gop.kv.value else blk: {
        errdefer _ = di.ofiles.remove(ofile);
        const ofile_path = mem.toSliceConst(u8, @ptrCast([*:0]const u8, di.strings.ptr + ofile.n_strx));

        gop.kv.value = MachOFile{
            .bytes = try std.fs.cwd().readFileAllocAligned(
                di.ofiles.allocator,
                ofile_path,
                maxInt(usize),
                @alignOf(macho.mach_header_64),
            ),
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
                std.macho.LC_SEGMENT_64 => break @ptrCast(*const std.macho.segment_command_64, @alignCast(@alignOf(std.macho.segment_command_64), ptr)),
                else => {},
            }
            ptr = @alignCast(@alignOf(std.macho.load_command), ptr + lc.cmdsize);
        } else {
            return error.MissingDebugInfo;
        };
        const sections = @ptrCast([*]const macho.section_64, @alignCast(@alignOf(macho.section_64), ptr + @sizeOf(std.macho.segment_command_64)))[0..segcmd.nsects];
        for (sections) |*sect| {
            if (sect.flags & macho.SECTION_TYPE == macho.S_REGULAR and
                (sect.flags & macho.SECTION_ATTRIBUTES) & macho.S_ATTR_DEBUG == macho.S_ATTR_DEBUG)
            {
                const sect_name = mem.toSliceConst(u8, @ptrCast([*:0]const u8, &sect.sectname));
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
        const dir_index = try leb.readULEB128Mem(usize, &ptr);
        const mtime = try leb.readULEB128Mem(usize, &ptr);
        const len_bytes = try leb.readULEB128Mem(usize, &ptr);
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
            const op_size = try leb.readULEB128Mem(u64, &ptr);
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
                    const dir_index = try leb.readULEB128Mem(usize, &ptr);
                    const mtime = try leb.readULEB128Mem(usize, &ptr);
                    const len_bytes = try leb.readULEB128Mem(usize, &ptr);
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
            const inc_line = @as(i32, line_base) + @as(i32, adjusted_opcode % line_range);
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
                    const arg = try leb.readULEB128Mem(usize, &ptr);
                    prog.address += arg * minimum_instruction_length;
                },
                DW.LNS_advance_line => {
                    const arg = try leb.readILEB128Mem(i64, &ptr);
                    prog.line += arg;
                },
                DW.LNS_set_file => {
                    const arg = try leb.readULEB128Mem(usize, &ptr);
                    prog.file = arg;
                },
                DW.LNS_set_column => {
                    const arg = try leb.readULEB128Mem(u64, &ptr);
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

const Func = struct {
    pc_range: ?PcRange,
    name: ?[]u8,
};

fn readIntMem(ptr: *[*]const u8, comptime T: type, endian: builtin.Endian) T {
    // TODO https://github.com/ziglang/zig/issues/863
    const size = (T.bit_count + 7) / 8;
    const result = mem.readIntSlice(T, ptr.*[0..size], endian);
    ptr.* += size;
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
    // TODO this code can be improved with https://github.com/ziglang/zig/issues/863
    const first_32_bits = mem.readIntSliceLittle(u32, ptr.*[0..4]);
    is_64.* = (first_32_bits == 0xffffffff);
    if (is_64.*) {
        ptr.* += 4;
        const result = mem.readIntSliceLittle(u64, ptr.*[0..8]);
        ptr.* += 8;
        return result;
    } else {
        if (first_32_bits >= 0xfffffff0) return error.InvalidDebugInfo;
        ptr.* += 4;
        // TODO this cast should not be needed
        return @as(u64, first_32_bits);
    }
}

fn readStringMem(ptr: *[*]const u8) [:0]const u8 {
    const result = mem.toSliceConst(u8, @ptrCast([*:0]const u8, ptr.*));
    ptr.* += result.len + 1;
    return result;
}

fn readInitialLength(comptime E: type, in_stream: *io.InStream(E), is_64: *bool) !u64 {
    const first_32_bits = try in_stream.readIntLittle(u32);
    is_64.* = (first_32_bits == 0xffffffff);
    if (is_64.*) {
        return in_stream.readIntLittle(u64);
    } else {
        if (first_32_bits >= 0xfffffff0) return error.InvalidDebugInfo;
        // TODO this cast should not be needed
        return @as(u64, first_32_bits);
    }
}

/// This should only be used in temporary test programs.
pub const global_allocator = &global_fixed_allocator.allocator;
var global_fixed_allocator = std.heap.ThreadSafeFixedBufferAllocator.init(global_allocator_mem[0..]);
var global_allocator_mem: [100 * 1024]u8 = undefined;

/// TODO multithreaded awareness
var debug_info_allocator: ?*mem.Allocator = null;
var debug_info_arena_allocator: std.heap.ArenaAllocator = undefined;
fn getDebugInfoAllocator() *mem.Allocator {
    if (debug_info_allocator) |a| return a;

    debug_info_arena_allocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    debug_info_allocator = &debug_info_arena_allocator.allocator;
    return &debug_info_arena_allocator.allocator;
}

/// Whether or not the current target can print useful debug information when a segfault occurs.
pub const have_segfault_handling_support = builtin.os == .linux or builtin.os == .windows;
pub const enable_segfault_handler: bool = if (@hasDecl(root, "enable_segfault_handler"))
    root.enable_segfault_handler
else
    runtime_safety and have_segfault_handling_support;

pub fn maybeEnableSegfaultHandler() void {
    if (enable_segfault_handler) {
        std.debug.attachSegfaultHandler();
    }
}

var windows_segfault_handle: ?windows.HANDLE = null;

/// Attaches a global SIGSEGV handler which calls @panic("segmentation fault");
pub fn attachSegfaultHandler() void {
    if (!have_segfault_handling_support) {
        @compileError("segfault handler not supported for this target");
    }
    if (builtin.os == .windows) {
        windows_segfault_handle = windows.kernel32.AddVectoredExceptionHandler(0, handleSegfaultWindows);
        return;
    }
    var act = os.Sigaction{
        .sigaction = handleSegfaultLinux,
        .mask = os.empty_sigset,
        .flags = (os.SA_SIGINFO | os.SA_RESTART | os.SA_RESETHAND),
    };

    os.sigaction(os.SIGSEGV, &act, null);
    os.sigaction(os.SIGILL, &act, null);
}

fn resetSegfaultHandler() void {
    if (builtin.os == .windows) {
        if (windows_segfault_handle) |handle| {
            assert(windows.kernel32.RemoveVectoredExceptionHandler(handle) != 0);
            windows_segfault_handle = null;
        }
        return;
    }
    var act = os.Sigaction{
        .sigaction = os.SIG_DFL,
        .mask = os.empty_sigset,
        .flags = 0,
    };
    os.sigaction(os.SIGSEGV, &act, null);
    os.sigaction(os.SIGILL, &act, null);
}

fn handleSegfaultLinux(sig: i32, info: *const os.siginfo_t, ctx_ptr: *const c_void) callconv(.C) noreturn {
    // Reset to the default handler so that if a segfault happens in this handler it will crash
    // the process. Also when this handler returns, the original instruction will be repeated
    // and the resulting segfault will crash the process rather than continually dump stack traces.
    resetSegfaultHandler();

    const addr = @ptrToInt(info.fields.sigfault.addr);
    switch (sig) {
        os.SIGSEGV => std.debug.warn("Segmentation fault at address 0x{x}\n", .{addr}),
        os.SIGILL => std.debug.warn("Illegal instruction at address 0x{x}\n", .{addr}),
        else => unreachable,
    }
    switch (builtin.arch) {
        .i386 => {
            const ctx = @ptrCast(*const os.ucontext_t, @alignCast(@alignOf(os.ucontext_t), ctx_ptr));
            const ip = @intCast(usize, ctx.mcontext.gregs[os.REG_EIP]);
            const bp = @intCast(usize, ctx.mcontext.gregs[os.REG_EBP]);
            dumpStackTraceFromBase(bp, ip);
        },
        .x86_64 => {
            const ctx = @ptrCast(*const os.ucontext_t, @alignCast(@alignOf(os.ucontext_t), ctx_ptr));
            const ip = @intCast(usize, ctx.mcontext.gregs[os.REG_RIP]);
            const bp = @intCast(usize, ctx.mcontext.gregs[os.REG_RBP]);
            dumpStackTraceFromBase(bp, ip);
        },
        .arm => {
            const ctx = @ptrCast(*const os.ucontext_t, @alignCast(@alignOf(os.ucontext_t), ctx_ptr));
            const ip = @intCast(usize, ctx.mcontext.arm_pc);
            const bp = @intCast(usize, ctx.mcontext.arm_fp);
            dumpStackTraceFromBase(bp, ip);
        },
        .aarch64 => {
            const ctx = @ptrCast(*const os.ucontext_t, @alignCast(@alignOf(os.ucontext_t), ctx_ptr));
            const ip = @intCast(usize, ctx.mcontext.pc);
            // x29 is the ABI-designated frame pointer
            const bp = @intCast(usize, ctx.mcontext.regs[29]);
            dumpStackTraceFromBase(bp, ip);
        },
        else => {},
    }

    // We cannot allow the signal handler to return because when it runs the original instruction
    // again, the memory may be mapped and undefined behavior would occur rather than repeating
    // the segfault. So we simply abort here.
    os.abort();
}

fn handleSegfaultWindows(info: *windows.EXCEPTION_POINTERS) callconv(.Stdcall) c_long {
    const exception_address = @ptrToInt(info.ExceptionRecord.ExceptionAddress);
    switch (info.ExceptionRecord.ExceptionCode) {
        windows.EXCEPTION_DATATYPE_MISALIGNMENT => panicExtra(null, exception_address, "Unaligned Memory Access", .{}),
        windows.EXCEPTION_ACCESS_VIOLATION => panicExtra(null, exception_address, "Segmentation fault at address 0x{x}", .{info.ExceptionRecord.ExceptionInformation[1]}),
        windows.EXCEPTION_ILLEGAL_INSTRUCTION => panicExtra(null, exception_address, "Illegal Instruction", .{}),
        windows.EXCEPTION_STACK_OVERFLOW => panicExtra(null, exception_address, "Stack Overflow", .{}),
        else => return windows.EXCEPTION_CONTINUE_SEARCH,
    }
}

pub fn dumpStackPointerAddr(prefix: []const u8) void {
    const sp = asm (""
        : [argc] "={rsp}" (-> usize)
    );
    std.debug.warn("{} sp = 0x{x}\n", .{ prefix, sp });
}

// Reference everything so it gets tested.
test "" {
    _ = leb;
}
