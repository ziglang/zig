const std = @import("std.zig");
const builtin = @import("builtin");
const math = std.math;
const mem = std.mem;
const io = std.io;
const os = std.os;
const fs = std.fs;
const process = std.process;
const testing = std.testing;
const elf = std.elf;
const DW = std.dwarf;
const macho = std.macho;
const coff = std.coff;
const pdb = std.pdb;
const ArrayList = std.ArrayList;
const root = @import("root");
const maxInt = std.math.maxInt;
const File = std.fs.File;
const windows = std.os.windows;
const native_arch = builtin.cpu.arch;
const native_os = builtin.os.tag;
const native_endian = native_arch.endian();

pub const runtime_safety = switch (builtin.mode) {
    .Debug, .ReleaseSafe => true,
    .ReleaseFast, .ReleaseSmall => false,
};

pub const sys_can_stack_trace = switch (builtin.cpu.arch) {
    // Observed to go into an infinite loop.
    // TODO: Make this work.
    .mips,
    .mipsel,
    => false,

    // `@returnAddress()` in LLVM 10 gives
    // "Non-Emscripten WebAssembly hasn't implemented __builtin_return_address".
    .wasm32,
    .wasm64,
    => builtin.os.tag == .emscripten,

    // `@returnAddress()` is unsupported in LLVM 13.
    .bpfel,
    .bpfeb,
    => false,

    else => true,
};

pub const LineInfo = struct {
    line: u64,
    column: u64,
    file_name: []const u8,

    pub fn deinit(self: LineInfo, allocator: mem.Allocator) void {
        allocator.free(self.file_name);
    }
};

pub const SymbolInfo = struct {
    symbol_name: []const u8 = "???",
    compile_unit_name: []const u8 = "???",
    line_info: ?LineInfo = null,

    pub fn deinit(self: SymbolInfo, allocator: mem.Allocator) void {
        if (self.line_info) |li| {
            li.deinit(allocator);
        }
    }
};
const PdbOrDwarf = union(enum) {
    pdb: pdb.Pdb,
    dwarf: DW.DwarfInfo,

    fn deinit(self: *PdbOrDwarf, allocator: mem.Allocator) void {
        switch (self.*) {
            .pdb => |*inner| inner.deinit(),
            .dwarf => |*inner| inner.deinit(allocator),
        }
    }
};

var stderr_mutex = std.Thread.Mutex{};

pub const warn = @compileError("deprecated; use `std.log` functions for logging or `std.debug.print` for 'printf debugging'");

/// Print to stderr, unbuffered, and silently returning on failure. Intended
/// for use in "printf debugging." Use `std.log` functions for proper logging.
pub fn print(comptime fmt: []const u8, args: anytype) void {
    stderr_mutex.lock();
    defer stderr_mutex.unlock();
    const stderr = io.getStdErr().writer();
    nosuspend stderr.print(fmt, args) catch return;
}

pub fn getStderrMutex() *std.Thread.Mutex {
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

pub fn detectTTYConfig(file: std.fs.File) TTY.Config {
    if (builtin.os.tag == .wasi) {
        // Per https://github.com/WebAssembly/WASI/issues/162 ANSI codes
        // aren't currently supported.
        return .no_color;
    } else if (process.hasEnvVarConstant("ZIG_DEBUG_COLOR")) {
        return .escape_codes;
    } else if (process.hasEnvVarConstant("NO_COLOR")) {
        return .no_color;
    } else if (file.supportsAnsiEscapeCodes()) {
        return .escape_codes;
    } else if (native_os == .windows and file.isTty()) {
        var info: windows.CONSOLE_SCREEN_BUFFER_INFO = undefined;
        if (windows.kernel32.GetConsoleScreenBufferInfo(file.handle, &info) != windows.TRUE) {
            // TODO: Should this return an error instead?
            return .no_color;
        }
        return .{ .windows_api = .{
            .handle = file.handle,
            .reset_attributes = info.wAttributes,
        } };
    }
    return .no_color;
}

/// Tries to print the current stack trace to stderr, unbuffered, and ignores any error returned.
/// TODO multithreaded awareness
pub fn dumpCurrentStackTrace(start_addr: ?usize) void {
    nosuspend {
        if (comptime builtin.target.isWasm()) {
            if (native_os == .wasi) {
                const stderr = io.getStdErr().writer();
                stderr.print("Unable to dump stack trace: not implemented for Wasm\n", .{}) catch return;
            }
            return;
        }
        const stderr = io.getStdErr().writer();
        if (builtin.strip_debug_info) {
            stderr.print("Unable to dump stack trace: debug info stripped\n", .{}) catch return;
            return;
        }
        const debug_info = getSelfDebugInfo() catch |err| {
            stderr.print("Unable to dump stack trace: Unable to open debug info: {s}\n", .{@errorName(err)}) catch return;
            return;
        };
        writeCurrentStackTrace(stderr, debug_info, detectTTYConfig(io.getStdErr()), start_addr) catch |err| {
            stderr.print("Unable to dump stack trace: {s}\n", .{@errorName(err)}) catch return;
            return;
        };
    }
}

/// Tries to print the stack trace starting from the supplied base pointer to stderr,
/// unbuffered, and ignores any error returned.
/// TODO multithreaded awareness
pub fn dumpStackTraceFromBase(bp: usize, ip: usize) void {
    nosuspend {
        if (comptime builtin.target.isWasm()) {
            if (native_os == .wasi) {
                const stderr = io.getStdErr().writer();
                stderr.print("Unable to dump stack trace: not implemented for Wasm\n", .{}) catch return;
            }
            return;
        }
        const stderr = io.getStdErr().writer();
        if (builtin.strip_debug_info) {
            stderr.print("Unable to dump stack trace: debug info stripped\n", .{}) catch return;
            return;
        }
        const debug_info = getSelfDebugInfo() catch |err| {
            stderr.print("Unable to dump stack trace: Unable to open debug info: {s}\n", .{@errorName(err)}) catch return;
            return;
        };
        const tty_config = detectTTYConfig(io.getStdErr());
        printSourceAtAddress(debug_info, stderr, ip, tty_config) catch return;
        var it = StackIterator.init(null, bp);
        while (it.next()) |return_address| {
            // On arm64 macOS, the address of the last frame is 0x0 rather than 0x1 as on x86_64 macOS,
            // therefore, we do a check for `return_address == 0` before subtracting 1 from it to avoid
            // an overflow. We do not need to signal `StackIterator` as it will correctly detect this
            // condition on the subsequent iteration and return `null` thus terminating the loop.
            // same behaviour for x86-windows-msvc
            const address = if (return_address == 0) return_address else return_address - 1;
            printSourceAtAddress(debug_info, stderr, address, tty_config) catch return;
        }
    }
}

/// Returns a slice with the same pointer as addresses, with a potentially smaller len.
/// On Windows, when first_address is not null, we ask for at least 32 stack frames,
/// and then try to find the first address. If addresses.len is more than 32, we
/// capture that many stack frames exactly, and then look for the first address,
/// chopping off the irrelevant frames and shifting so that the returned addresses pointer
/// equals the passed in addresses pointer.
pub fn captureStackTrace(first_address: ?usize, stack_trace: *std.builtin.StackTrace) void {
    if (native_os == .windows) {
        const addrs = stack_trace.instruction_addresses;
        const first_addr = first_address orelse {
            stack_trace.index = walkStackWindows(addrs[0..]);
            return;
        };
        var addr_buf_stack: [32]usize = undefined;
        const addr_buf = if (addr_buf_stack.len > addrs.len) addr_buf_stack[0..] else addrs;
        const n = walkStackWindows(addr_buf[0..]);
        const first_index = for (addr_buf[0..n], 0..) |addr, i| {
            if (addr == first_addr) {
                break i;
            }
        } else {
            stack_trace.index = 0;
            return;
        };
        const end_index = math.min(first_index + addrs.len, n);
        const slice = addr_buf[first_index..end_index];
        // We use a for loop here because slice and addrs may alias.
        for (slice, 0..) |addr, i| {
            addrs[i] = addr;
        }
        stack_trace.index = slice.len;
    } else {
        var it = StackIterator.init(first_address, null);
        for (stack_trace.instruction_addresses, 0..) |*addr, i| {
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
pub fn dumpStackTrace(stack_trace: std.builtin.StackTrace) void {
    nosuspend {
        if (comptime builtin.target.isWasm()) {
            if (native_os == .wasi) {
                const stderr = io.getStdErr().writer();
                stderr.print("Unable to dump stack trace: not implemented for Wasm\n", .{}) catch return;
            }
            return;
        }
        const stderr = io.getStdErr().writer();
        if (builtin.strip_debug_info) {
            stderr.print("Unable to dump stack trace: debug info stripped\n", .{}) catch return;
            return;
        }
        const debug_info = getSelfDebugInfo() catch |err| {
            stderr.print("Unable to dump stack trace: Unable to open debug info: {s}\n", .{@errorName(err)}) catch return;
            return;
        };
        writeStackTrace(stack_trace, stderr, getDebugInfoAllocator(), debug_info, detectTTYConfig(io.getStdErr())) catch |err| {
            stderr.print("Unable to dump stack trace: {s}\n", .{@errorName(err)}) catch return;
            return;
        };
    }
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

pub fn panic(comptime format: []const u8, args: anytype) noreturn {
    @setCold(true);

    panicExtra(null, null, format, args);
}

/// `panicExtra` is useful when you want to print out an `@errorReturnTrace`
/// and also print out some values.
pub fn panicExtra(
    trace: ?*std.builtin.StackTrace,
    ret_addr: ?usize,
    comptime format: []const u8,
    args: anytype,
) noreturn {
    @setCold(true);

    const size = 0x1000;
    const trunc_msg = "(msg truncated)";
    var buf: [size + trunc_msg.len]u8 = undefined;
    // a minor annoyance with this is that it will result in the NoSpaceLeft
    // error being part of the @panic stack trace (but that error should
    // only happen rarely)
    const msg = std.fmt.bufPrint(buf[0..size], format, args) catch |err| switch (err) {
        std.fmt.BufPrintError.NoSpaceLeft => blk: {
            std.mem.copy(u8, buf[size..], trunc_msg);
            break :blk &buf;
        },
    };
    std.builtin.panic(msg, trace, ret_addr);
}

/// Non-zero whenever the program triggered a panic.
/// The counter is incremented/decremented atomically.
var panicking = std.atomic.Atomic(u8).init(0);

// Locked to avoid interleaving panic messages from multiple threads.
var panic_mutex = std.Thread.Mutex{};

/// Counts how many times the panic handler is invoked by this thread.
/// This is used to catch and handle panics triggered by the panic handler.
threadlocal var panic_stage: usize = 0;

// `panicImpl` could be useful in implementing a custom panic handler which
// calls the default handler (on supported platforms)
pub fn panicImpl(trace: ?*const std.builtin.StackTrace, first_trace_addr: ?usize, msg: []const u8) noreturn {
    @setCold(true);

    if (enable_segfault_handler) {
        // If a segfault happens while panicking, we want it to actually segfault, not trigger
        // the handler.
        resetSegfaultHandler();
    }

    nosuspend switch (panic_stage) {
        0 => {
            panic_stage = 1;

            _ = panicking.fetchAdd(1, .SeqCst);

            // Make sure to release the mutex when done
            {
                panic_mutex.lock();
                defer panic_mutex.unlock();

                const stderr = io.getStdErr().writer();
                if (builtin.single_threaded) {
                    stderr.print("panic: ", .{}) catch os.abort();
                } else {
                    const current_thread_id = std.Thread.getCurrentId();
                    stderr.print("thread {} panic: ", .{current_thread_id}) catch os.abort();
                }
                stderr.print("{s}\n", .{msg}) catch os.abort();
                if (trace) |t| {
                    dumpStackTrace(t.*);
                }
                dumpCurrentStackTrace(first_trace_addr);
            }

            if (panicking.fetchSub(1, .SeqCst) != 1) {
                // Another thread is panicking, wait for the last one to finish
                // and call abort()
                if (builtin.single_threaded) unreachable;

                // Sleep forever without hammering the CPU
                var futex = std.atomic.Atomic(u32).init(0);
                while (true) std.Thread.Futex.wait(&futex, 0);
                unreachable;
            }
        },
        1 => {
            panic_stage = 2;

            // A panic happened while trying to print a previous panic message,
            // we're still holding the mutex but that's fine as we're going to
            // call abort()
            const stderr = io.getStdErr().writer();
            stderr.print("Panicked during a panic. Aborting.\n", .{}) catch os.abort();
        },
        else => {
            // Panicked while printing "Panicked during a panic."
        },
    };

    os.abort();
}

pub fn writeStackTrace(
    stack_trace: std.builtin.StackTrace,
    out_stream: anytype,
    allocator: mem.Allocator,
    debug_info: *DebugInfo,
    tty_config: TTY.Config,
) !void {
    _ = allocator;
    if (builtin.strip_debug_info) return error.MissingDebugInfo;
    var frame_index: usize = 0;
    var frames_left: usize = std.math.min(stack_trace.index, stack_trace.instruction_addresses.len);

    while (frames_left != 0) : ({
        frames_left -= 1;
        frame_index = (frame_index + 1) % stack_trace.instruction_addresses.len;
    }) {
        const return_address = stack_trace.instruction_addresses[frame_index];
        try printSourceAtAddress(debug_info, out_stream, return_address - 1, tty_config);
    }

    if (stack_trace.index > stack_trace.instruction_addresses.len) {
        const dropped_frames = stack_trace.index - stack_trace.instruction_addresses.len;

        tty_config.setColor(out_stream, .Bold) catch {};
        try out_stream.print("({d} additional stack frames skipped...)\n", .{dropped_frames});
        tty_config.setColor(out_stream, .Reset) catch {};
    }
}

pub const StackIterator = struct {
    // Skip every frame before this address is found.
    first_address: ?usize,
    // Last known value of the frame pointer register.
    fp: usize,

    pub fn init(first_address: ?usize, fp: ?usize) StackIterator {
        if (native_arch == .sparc64) {
            // Flush all the register windows on stack.
            asm volatile (
                \\ flushw
                ::: "memory");
        }

        return StackIterator{
            .first_address = first_address,
            .fp = fp orelse @frameAddress(),
        };
    }

    // Offset of the saved BP wrt the frame pointer.
    const fp_offset = if (native_arch.isRISCV())
        // On RISC-V the frame pointer points to the top of the saved register
        // area, on pretty much every other architecture it points to the stack
        // slot where the previous frame pointer is saved.
        2 * @sizeOf(usize)
    else if (native_arch.isSPARC())
        // On SPARC the previous frame pointer is stored at 14 slots past %fp+BIAS.
        14 * @sizeOf(usize)
    else
        0;

    const fp_bias = if (native_arch.isSPARC())
        // On SPARC frame pointers are biased by a constant.
        2047
    else
        0;

    // Positive offset of the saved PC wrt the frame pointer.
    const pc_offset = if (native_arch == .powerpc64le)
        2 * @sizeOf(usize)
    else
        @sizeOf(usize);

    pub fn next(self: *StackIterator) ?usize {
        var address = self.next_internal() orelse return null;

        if (self.first_address) |first_address| {
            while (address != first_address) {
                address = self.next_internal() orelse return null;
            }
            self.first_address = null;
        }

        return address;
    }

    fn isValidMemory(address: usize) bool {
        // We are unable to determine validity of memory for freestanding targets
        if (native_os == .freestanding) return true;

        const aligned_address = address & ~@intCast(usize, (mem.page_size - 1));
        const aligned_memory = @intToPtr([*]align(mem.page_size) u8, aligned_address)[0..mem.page_size];

        if (native_os != .windows) {
            if (native_os != .wasi) {
                os.msync(aligned_memory, os.MSF.ASYNC) catch |err| {
                    switch (err) {
                        os.MSyncError.UnmappedMemory => {
                            return false;
                        },
                        else => unreachable,
                    }
                };
            }

            return true;
        } else {
            const w = os.windows;
            var memory_info: w.MEMORY_BASIC_INFORMATION = undefined;

            // The only error this function can throw is ERROR_INVALID_PARAMETER.
            // supply an address that invalid i'll be thrown.
            const rc = w.VirtualQuery(aligned_memory, &memory_info, aligned_memory.len) catch {
                return false;
            };

            // Result code has to be bigger than zero (number of bytes written)
            if (rc == 0) {
                return false;
            }

            // Free pages cannot be read, they are unmapped
            if (memory_info.State == w.MEM_FREE) {
                return false;
            }

            return true;
        }
    }

    fn next_internal(self: *StackIterator) ?usize {
        const fp = if (comptime native_arch.isSPARC())
            // On SPARC the offset is positive. (!)
            math.add(usize, self.fp, fp_offset) catch return null
        else
            math.sub(usize, self.fp, fp_offset) catch return null;

        // Sanity check.
        if (fp == 0 or !mem.isAligned(fp, @alignOf(usize)) or !isValidMemory(fp))
            return null;

        const new_fp = math.add(usize, @intToPtr(*const usize, fp).*, fp_bias) catch return null;

        // Sanity check: the stack grows down thus all the parent frames must be
        // be at addresses that are greater (or equal) than the previous one.
        // A zero frame pointer often signals this is the last frame, that case
        // is gracefully handled by the next call to next_internal.
        if (new_fp != 0 and new_fp < self.fp)
            return null;

        const new_pc = @intToPtr(
            *const usize,
            math.add(usize, fp, pc_offset) catch return null,
        ).*;

        self.fp = new_fp;

        return new_pc;
    }
};

pub fn writeCurrentStackTrace(
    out_stream: anytype,
    debug_info: *DebugInfo,
    tty_config: TTY.Config,
    start_addr: ?usize,
) !void {
    if (native_os == .windows) {
        return writeCurrentStackTraceWindows(out_stream, debug_info, tty_config, start_addr);
    }
    var it = StackIterator.init(start_addr, null);
    while (it.next()) |return_address| {
        // On arm64 macOS, the address of the last frame is 0x0 rather than 0x1 as on x86_64 macOS,
        // therefore, we do a check for `return_address == 0` before subtracting 1 from it to avoid
        // an overflow. We do not need to signal `StackIterator` as it will correctly detect this
        // condition on the subsequent iteration and return `null` thus terminating the loop.
        // same behaviour for x86-windows-msvc
        const address = if (return_address == 0) return_address else return_address - 1;
        try printSourceAtAddress(debug_info, out_stream, address, tty_config);
    }
}

pub noinline fn walkStackWindows(addresses: []usize) usize {
    if (builtin.cpu.arch == .x86) {
        // RtlVirtualUnwind doesn't exist on x86
        return windows.ntdll.RtlCaptureStackBackTrace(0, addresses.len, @ptrCast(**anyopaque, addresses.ptr), null);
    }

    const tib = @ptrCast(*const windows.NT_TIB, &windows.teb().Reserved1);

    var context: windows.CONTEXT = std.mem.zeroes(windows.CONTEXT);
    windows.ntdll.RtlCaptureContext(&context);

    var i: usize = 0;
    var image_base: usize = undefined;
    var history_table: windows.UNWIND_HISTORY_TABLE = std.mem.zeroes(windows.UNWIND_HISTORY_TABLE);

    while (i < addresses.len) : (i += 1) {
        const current_regs = context.getRegs();
        if (windows.ntdll.RtlLookupFunctionEntry(current_regs.ip, &image_base, &history_table)) |runtime_function| {
            var handler_data: ?*anyopaque = null;
            var establisher_frame: u64 = undefined;
            _ = windows.ntdll.RtlVirtualUnwind(windows.UNW_FLAG_NHANDLER, image_base, current_regs.ip, runtime_function, &context, &handler_data, &establisher_frame, null);
        } else {
            // leaf function
            context.setIp(@intToPtr(*u64, current_regs.sp).*);
            context.setSp(current_regs.sp + @sizeOf(usize));
        }

        const next_regs = context.getRegs();
        if (next_regs.sp < @ptrToInt(tib.StackLimit) or next_regs.sp > @ptrToInt(tib.StackBase)) {
            break;
        }

        if (next_regs.ip == 0) {
            break;
        }

        addresses[i] = next_regs.ip;
    }

    return i;
}

pub fn writeCurrentStackTraceWindows(
    out_stream: anytype,
    debug_info: *DebugInfo,
    tty_config: TTY.Config,
    start_addr: ?usize,
) !void {
    var addr_buf: [1024]usize = undefined;
    const n = walkStackWindows(addr_buf[0..]);
    const addrs = addr_buf[0..n];
    var start_i: usize = if (start_addr) |saddr| blk: {
        for (addrs, 0..) |addr, i| {
            if (addr == saddr) break :blk i;
        }
        return;
    } else 0;
    for (addrs[start_i..]) |addr| {
        try printSourceAtAddress(debug_info, out_stream, addr - 1, tty_config);
    }
}

pub const TTY = struct {
    pub const Color = enum {
        Red,
        Green,
        Yellow,
        Cyan,
        White,
        Dim,
        Bold,
        Reset,
    };

    pub const Config = union(enum) {
        no_color,
        escape_codes,
        windows_api: if (native_os == .windows) WindowsContext else void,

        pub const WindowsContext = struct {
            handle: File.Handle,
            reset_attributes: u16,
        };

        pub fn setColor(conf: Config, out_stream: anytype, color: Color) !void {
            nosuspend switch (conf) {
                .no_color => return,
                .escape_codes => {
                    const color_string = switch (color) {
                        .Red => "\x1b[31;1m",
                        .Green => "\x1b[32;1m",
                        .Yellow => "\x1b[33;1m",
                        .Cyan => "\x1b[36;1m",
                        .White => "\x1b[37;1m",
                        .Bold => "\x1b[1m",
                        .Dim => "\x1b[2m",
                        .Reset => "\x1b[0m",
                    };
                    try out_stream.writeAll(color_string);
                },
                .windows_api => |ctx| if (native_os == .windows) {
                    const attributes = switch (color) {
                        .Red => windows.FOREGROUND_RED | windows.FOREGROUND_INTENSITY,
                        .Green => windows.FOREGROUND_GREEN | windows.FOREGROUND_INTENSITY,
                        .Yellow => windows.FOREGROUND_RED | windows.FOREGROUND_GREEN | windows.FOREGROUND_INTENSITY,
                        .Cyan => windows.FOREGROUND_GREEN | windows.FOREGROUND_BLUE | windows.FOREGROUND_INTENSITY,
                        .White, .Bold => windows.FOREGROUND_RED | windows.FOREGROUND_GREEN | windows.FOREGROUND_BLUE | windows.FOREGROUND_INTENSITY,
                        .Dim => windows.FOREGROUND_INTENSITY,
                        .Reset => ctx.reset_attributes,
                    };
                    try windows.SetConsoleTextAttribute(ctx.handle, attributes);
                } else {
                    unreachable;
                },
            };
        }

        pub fn writeDEC(conf: Config, writer: anytype, codepoint: u8) !void {
            const bytes = switch (conf) {
                .no_color, .windows_api => switch (codepoint) {
                    0x50...0x5e => @as(*const [1]u8, &codepoint),
                    0x6a => "+", // ┘
                    0x6b => "+", // ┐
                    0x6c => "+", // ┌
                    0x6d => "+", // └
                    0x6e => "+", // ┼
                    0x71 => "-", // ─
                    0x74 => "+", // ├
                    0x75 => "+", // ┤
                    0x76 => "+", // ┴
                    0x77 => "+", // ┬
                    0x78 => "|", // │
                    else => " ", // TODO
                },
                .escape_codes => switch (codepoint) {
                    // Here we avoid writing the DEC beginning sequence and
                    // ending sequence in separate syscalls by putting the
                    // beginning and ending sequence into the same string
                    // literals, to prevent terminals ending up in bad states
                    // in case a crash happens between syscalls.
                    inline 0x50...0x7f => |x| "\x1B\x28\x30" ++ [1]u8{x} ++ "\x1B\x28\x42",
                    else => unreachable,
                },
            };
            return writer.writeAll(bytes);
        }
    };
};

fn machoSearchSymbols(symbols: []const MachoSymbol, address: usize) ?*const MachoSymbol {
    var min: usize = 0;
    var max: usize = symbols.len - 1;
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

    const max_sym = &symbols[symbols.len - 1];
    if (address >= max_sym.address())
        return max_sym;

    return null;
}

test "machoSearchSymbols" {
    const symbols = [_]MachoSymbol{
        .{ .addr = 100, .strx = undefined, .size = undefined, .ofile = undefined },
        .{ .addr = 200, .strx = undefined, .size = undefined, .ofile = undefined },
        .{ .addr = 300, .strx = undefined, .size = undefined, .ofile = undefined },
    };

    try testing.expectEqual(@as(?*const MachoSymbol, null), machoSearchSymbols(&symbols, 0));
    try testing.expectEqual(@as(?*const MachoSymbol, null), machoSearchSymbols(&symbols, 99));
    try testing.expectEqual(&symbols[0], machoSearchSymbols(&symbols, 100).?);
    try testing.expectEqual(&symbols[0], machoSearchSymbols(&symbols, 150).?);
    try testing.expectEqual(&symbols[0], machoSearchSymbols(&symbols, 199).?);

    try testing.expectEqual(&symbols[1], machoSearchSymbols(&symbols, 200).?);
    try testing.expectEqual(&symbols[1], machoSearchSymbols(&symbols, 250).?);
    try testing.expectEqual(&symbols[1], machoSearchSymbols(&symbols, 299).?);

    try testing.expectEqual(&symbols[2], machoSearchSymbols(&symbols, 300).?);
    try testing.expectEqual(&symbols[2], machoSearchSymbols(&symbols, 301).?);
    try testing.expectEqual(&symbols[2], machoSearchSymbols(&symbols, 5000).?);
}

pub fn printSourceAtAddress(debug_info: *DebugInfo, out_stream: anytype, address: usize, tty_config: TTY.Config) !void {
    const module = debug_info.getModuleForAddress(address) catch |err| switch (err) {
        error.MissingDebugInfo, error.InvalidDebugInfo => {
            return printLineInfo(
                out_stream,
                null,
                address,
                "???",
                "???",
                tty_config,
                printLineFromFileAnyOs,
            );
        },
        else => return err,
    };

    const symbol_info = try module.getSymbolAtAddress(debug_info.allocator, address);
    defer symbol_info.deinit(debug_info.allocator);

    return printLineInfo(
        out_stream,
        symbol_info.line_info,
        address,
        symbol_info.symbol_name,
        symbol_info.compile_unit_name,
        tty_config,
        printLineFromFileAnyOs,
    );
}

fn printLineInfo(
    out_stream: anytype,
    line_info: ?LineInfo,
    address: usize,
    symbol_name: []const u8,
    compile_unit_name: []const u8,
    tty_config: TTY.Config,
    comptime printLineFromFile: anytype,
) !void {
    nosuspend {
        try tty_config.setColor(out_stream, .Bold);

        if (line_info) |*li| {
            try out_stream.print("{s}:{d}:{d}", .{ li.file_name, li.line, li.column });
        } else {
            try out_stream.writeAll("???:?:?");
        }

        try tty_config.setColor(out_stream, .Reset);
        try out_stream.writeAll(": ");
        try tty_config.setColor(out_stream, .Dim);
        try out_stream.print("0x{x} in {s} ({s})", .{ address, symbol_name, compile_unit_name });
        try tty_config.setColor(out_stream, .Reset);
        try out_stream.writeAll("\n");

        // Show the matching source code line if possible
        if (line_info) |li| {
            if (printLineFromFile(out_stream, li)) {
                if (li.column > 0) {
                    // The caret already takes one char
                    const space_needed = @intCast(usize, li.column - 1);

                    try out_stream.writeByteNTimes(' ', space_needed);
                    try tty_config.setColor(out_stream, .Green);
                    try out_stream.writeAll("^");
                    try tty_config.setColor(out_stream, .Reset);
                }
                try out_stream.writeAll("\n");
            } else |err| switch (err) {
                error.EndOfFile, error.FileNotFound => {},
                error.BadPathName => {},
                error.AccessDenied => {},
                else => return err,
            }
        }
    }
}

pub const OpenSelfDebugInfoError = error{
    MissingDebugInfo,
    UnsupportedOperatingSystem,
} || @typeInfo(@typeInfo(@TypeOf(DebugInfo.init)).Fn.return_type.?).ErrorUnion.error_set;

pub fn openSelfDebugInfo(allocator: mem.Allocator) OpenSelfDebugInfoError!DebugInfo {
    nosuspend {
        if (builtin.strip_debug_info)
            return error.MissingDebugInfo;
        if (@hasDecl(root, "os") and @hasDecl(root.os, "debug") and @hasDecl(root.os.debug, "openSelfDebugInfo")) {
            return root.os.debug.openSelfDebugInfo(allocator);
        }
        switch (native_os) {
            .linux,
            .freebsd,
            .netbsd,
            .dragonfly,
            .openbsd,
            .macos,
            .solaris,
            .windows,
            => return try DebugInfo.init(allocator),
            else => return error.UnsupportedOperatingSystem,
        }
    }
}

fn readCoffDebugInfo(allocator: mem.Allocator, coff_bytes: []const u8) !ModuleDebugInfo {
    nosuspend {
        const coff_obj = try allocator.create(coff.Coff);
        defer allocator.destroy(coff_obj);
        coff_obj.* = try coff.Coff.init(coff_bytes);

        var di = ModuleDebugInfo{
            .base_address = undefined,
            .coff_image_base = coff_obj.getImageBase(),
            .coff_section_headers = undefined,
            .debug_data = undefined,
        };

        if (coff_obj.getSectionByName(".debug_info")) |sec| {
            // This coff file has embedded DWARF debug info
            _ = sec;

            const debug_info = coff_obj.getSectionDataAlloc(".debug_info", allocator) catch return error.MissingDebugInfo;
            errdefer allocator.free(debug_info);
            const debug_abbrev = coff_obj.getSectionDataAlloc(".debug_abbrev", allocator) catch return error.MissingDebugInfo;
            errdefer allocator.free(debug_abbrev);
            const debug_str = coff_obj.getSectionDataAlloc(".debug_str", allocator) catch return error.MissingDebugInfo;
            errdefer allocator.free(debug_str);
            const debug_line = coff_obj.getSectionDataAlloc(".debug_line", allocator) catch return error.MissingDebugInfo;
            errdefer allocator.free(debug_line);

            const debug_str_offsets = coff_obj.getSectionDataAlloc(".debug_str_offsets", allocator) catch null;
            const debug_line_str = coff_obj.getSectionDataAlloc(".debug_line_str", allocator) catch null;
            const debug_ranges = coff_obj.getSectionDataAlloc(".debug_ranges", allocator) catch null;
            const debug_loclists = coff_obj.getSectionDataAlloc(".debug_loclists", allocator) catch null;
            const debug_rnglists = coff_obj.getSectionDataAlloc(".debug_rnglists", allocator) catch null;
            const debug_addr = coff_obj.getSectionDataAlloc(".debug_addr", allocator) catch null;
            const debug_names = coff_obj.getSectionDataAlloc(".debug_names", allocator) catch null;
            const debug_frame = coff_obj.getSectionDataAlloc(".debug_frame", allocator) catch null;

            var dwarf = DW.DwarfInfo{
                .endian = native_endian,
                .debug_info = debug_info,
                .debug_abbrev = debug_abbrev,
                .debug_str = debug_str,
                .debug_str_offsets = debug_str_offsets,
                .debug_line = debug_line,
                .debug_line_str = debug_line_str,
                .debug_ranges = debug_ranges,
                .debug_loclists = debug_loclists,
                .debug_rnglists = debug_rnglists,
                .debug_addr = debug_addr,
                .debug_names = debug_names,
                .debug_frame = debug_frame,
            };

            DW.openDwarfDebugInfo(&dwarf, allocator) catch |err| {
                if (debug_str_offsets) |d| allocator.free(d);
                if (debug_line_str) |d| allocator.free(d);
                if (debug_ranges) |d| allocator.free(d);
                if (debug_loclists) |d| allocator.free(d);
                if (debug_rnglists) |d| allocator.free(d);
                if (debug_addr) |d| allocator.free(d);
                if (debug_names) |d| allocator.free(d);
                if (debug_frame) |d| allocator.free(d);
                return err;
            };

            di.debug_data = PdbOrDwarf{ .dwarf = dwarf };
            return di;
        }

        // Only used by pdb path
        di.coff_section_headers = try coff_obj.getSectionHeadersAlloc(allocator);

        var path_buf: [windows.MAX_PATH]u8 = undefined;
        const len = try coff_obj.getPdbPath(path_buf[0..]);
        const raw_path = path_buf[0..len];

        const path = try fs.path.resolve(allocator, &[_][]const u8{raw_path});
        defer allocator.free(path);

        di.debug_data = PdbOrDwarf{ .pdb = undefined };
        di.debug_data.pdb = pdb.Pdb.init(allocator, path) catch |err| switch (err) {
            error.FileNotFound, error.IsDir => return error.MissingDebugInfo,
            else => return err,
        };
        try di.debug_data.pdb.parseInfoStream();
        try di.debug_data.pdb.parseDbiStream();

        if (!mem.eql(u8, &coff_obj.guid, &di.debug_data.pdb.guid) or coff_obj.age != di.debug_data.pdb.age)
            return error.InvalidDebugInfo;

        return di;
    }
}

fn chopSlice(ptr: []const u8, offset: u64, size: u64) error{Overflow}![]const u8 {
    const start = math.cast(usize, offset) orelse return error.Overflow;
    const end = start + (math.cast(usize, size) orelse return error.Overflow);
    return ptr[start..end];
}

/// This takes ownership of elf_file: users of this function should not close
/// it themselves, even on error.
/// TODO it's weird to take ownership even on error, rework this code.
pub fn readElfDebugInfo(allocator: mem.Allocator, elf_file: File) !ModuleDebugInfo {
    nosuspend {
        const mapped_mem = try mapWholeFile(elf_file);
        const hdr = @ptrCast(*const elf.Ehdr, &mapped_mem[0]);
        if (!mem.eql(u8, hdr.e_ident[0..4], elf.MAGIC)) return error.InvalidElfMagic;
        if (hdr.e_ident[elf.EI_VERSION] != 1) return error.InvalidElfVersion;

        const endian: std.builtin.Endian = switch (hdr.e_ident[elf.EI_DATA]) {
            elf.ELFDATA2LSB => .Little,
            elf.ELFDATA2MSB => .Big,
            else => return error.InvalidElfEndian,
        };
        assert(endian == native_endian); // this is our own debug info

        const shoff = hdr.e_shoff;
        const str_section_off = shoff + @as(u64, hdr.e_shentsize) * @as(u64, hdr.e_shstrndx);
        const str_shdr = @ptrCast(
            *const elf.Shdr,
            @alignCast(@alignOf(elf.Shdr), &mapped_mem[math.cast(usize, str_section_off) orelse return error.Overflow]),
        );
        const header_strings = mapped_mem[str_shdr.sh_offset .. str_shdr.sh_offset + str_shdr.sh_size];
        const shdrs = @ptrCast(
            [*]const elf.Shdr,
            @alignCast(@alignOf(elf.Shdr), &mapped_mem[shoff]),
        )[0..hdr.e_shnum];

        var opt_debug_info: ?[]const u8 = null;
        var opt_debug_abbrev: ?[]const u8 = null;
        var opt_debug_str: ?[]const u8 = null;
        var opt_debug_str_offsets: ?[]const u8 = null;
        var opt_debug_line: ?[]const u8 = null;
        var opt_debug_line_str: ?[]const u8 = null;
        var opt_debug_ranges: ?[]const u8 = null;
        var opt_debug_loclists: ?[]const u8 = null;
        var opt_debug_rnglists: ?[]const u8 = null;
        var opt_debug_addr: ?[]const u8 = null;
        var opt_debug_names: ?[]const u8 = null;
        var opt_debug_frame: ?[]const u8 = null;

        for (shdrs) |*shdr| {
            if (shdr.sh_type == elf.SHT_NULL) continue;

            const name = mem.sliceTo(header_strings[shdr.sh_name..], 0);
            if (mem.eql(u8, name, ".debug_info")) {
                opt_debug_info = try chopSlice(mapped_mem, shdr.sh_offset, shdr.sh_size);
            } else if (mem.eql(u8, name, ".debug_abbrev")) {
                opt_debug_abbrev = try chopSlice(mapped_mem, shdr.sh_offset, shdr.sh_size);
            } else if (mem.eql(u8, name, ".debug_str")) {
                opt_debug_str = try chopSlice(mapped_mem, shdr.sh_offset, shdr.sh_size);
            } else if (mem.eql(u8, name, ".debug_str_offsets")) {
                opt_debug_str_offsets = try chopSlice(mapped_mem, shdr.sh_offset, shdr.sh_size);
            } else if (mem.eql(u8, name, ".debug_line")) {
                opt_debug_line = try chopSlice(mapped_mem, shdr.sh_offset, shdr.sh_size);
            } else if (mem.eql(u8, name, ".debug_line_str")) {
                opt_debug_line_str = try chopSlice(mapped_mem, shdr.sh_offset, shdr.sh_size);
            } else if (mem.eql(u8, name, ".debug_ranges")) {
                opt_debug_ranges = try chopSlice(mapped_mem, shdr.sh_offset, shdr.sh_size);
            } else if (mem.eql(u8, name, ".debug_loclists")) {
                opt_debug_loclists = try chopSlice(mapped_mem, shdr.sh_offset, shdr.sh_size);
            } else if (mem.eql(u8, name, ".debug_rnglists")) {
                opt_debug_rnglists = try chopSlice(mapped_mem, shdr.sh_offset, shdr.sh_size);
            } else if (mem.eql(u8, name, ".debug_addr")) {
                opt_debug_addr = try chopSlice(mapped_mem, shdr.sh_offset, shdr.sh_size);
            } else if (mem.eql(u8, name, ".debug_names")) {
                opt_debug_names = try chopSlice(mapped_mem, shdr.sh_offset, shdr.sh_size);
            } else if (mem.eql(u8, name, ".debug_frame")) {
                opt_debug_frame = try chopSlice(mapped_mem, shdr.sh_offset, shdr.sh_size);
            }
        }

        var di = DW.DwarfInfo{
            .endian = endian,
            .debug_info = opt_debug_info orelse return error.MissingDebugInfo,
            .debug_abbrev = opt_debug_abbrev orelse return error.MissingDebugInfo,
            .debug_str = opt_debug_str orelse return error.MissingDebugInfo,
            .debug_str_offsets = opt_debug_str_offsets,
            .debug_line = opt_debug_line orelse return error.MissingDebugInfo,
            .debug_line_str = opt_debug_line_str,
            .debug_ranges = opt_debug_ranges,
            .debug_loclists = opt_debug_loclists,
            .debug_rnglists = opt_debug_rnglists,
            .debug_addr = opt_debug_addr,
            .debug_names = opt_debug_names,
            .debug_frame = opt_debug_frame,
        };

        try DW.openDwarfDebugInfo(&di, allocator);

        return ModuleDebugInfo{
            .base_address = undefined,
            .dwarf = di,
            .mapped_memory = mapped_mem,
        };
    }
}

/// This takes ownership of macho_file: users of this function should not close
/// it themselves, even on error.
/// TODO it's weird to take ownership even on error, rework this code.
fn readMachODebugInfo(allocator: mem.Allocator, macho_file: File) !ModuleDebugInfo {
    const mapped_mem = try mapWholeFile(macho_file);

    const hdr = @ptrCast(
        *const macho.mach_header_64,
        @alignCast(@alignOf(macho.mach_header_64), mapped_mem.ptr),
    );
    if (hdr.magic != macho.MH_MAGIC_64)
        return error.InvalidDebugInfo;

    var it = macho.LoadCommandIterator{
        .ncmds = hdr.ncmds,
        .buffer = mapped_mem[@sizeOf(macho.mach_header_64)..][0..hdr.sizeofcmds],
    };
    const symtab = while (it.next()) |cmd| switch (cmd.cmd()) {
        .SYMTAB => break cmd.cast(macho.symtab_command).?,
        else => {},
    } else return error.MissingDebugInfo;

    const syms = @ptrCast(
        [*]const macho.nlist_64,
        @alignCast(@alignOf(macho.nlist_64), &mapped_mem[symtab.symoff]),
    )[0..symtab.nsyms];
    const strings = mapped_mem[symtab.stroff..][0 .. symtab.strsize - 1 :0];

    const symbols_buf = try allocator.alloc(MachoSymbol, syms.len);

    var ofile: u32 = undefined;
    var last_sym: MachoSymbol = undefined;
    var symbol_index: usize = 0;
    var state: enum {
        init,
        oso_open,
        oso_close,
        bnsym,
        fun_strx,
        fun_size,
        ensym,
    } = .init;

    for (syms) |*sym| {
        if (!sym.stab()) continue;

        // TODO handle globals N_GSYM, and statics N_STSYM
        switch (sym.n_type) {
            macho.N_OSO => {
                switch (state) {
                    .init, .oso_close => {
                        state = .oso_open;
                        ofile = sym.n_strx;
                    },
                    else => return error.InvalidDebugInfo,
                }
            },
            macho.N_BNSYM => {
                switch (state) {
                    .oso_open, .ensym => {
                        state = .bnsym;
                        last_sym = .{
                            .strx = 0,
                            .addr = sym.n_value,
                            .size = 0,
                            .ofile = ofile,
                        };
                    },
                    else => return error.InvalidDebugInfo,
                }
            },
            macho.N_FUN => {
                switch (state) {
                    .bnsym => {
                        state = .fun_strx;
                        last_sym.strx = sym.n_strx;
                    },
                    .fun_strx => {
                        state = .fun_size;
                        last_sym.size = @intCast(u32, sym.n_value);
                    },
                    else => return error.InvalidDebugInfo,
                }
            },
            macho.N_ENSYM => {
                switch (state) {
                    .fun_size => {
                        state = .ensym;
                        symbols_buf[symbol_index] = last_sym;
                        symbol_index += 1;
                    },
                    else => return error.InvalidDebugInfo,
                }
            },
            macho.N_SO => {
                switch (state) {
                    .init, .oso_close => {},
                    .oso_open, .ensym => {
                        state = .oso_close;
                    },
                    else => return error.InvalidDebugInfo,
                }
            },
            else => {},
        }
    }

    switch (state) {
        .init => return error.MissingDebugInfo,
        .oso_close => {},
        else => return error.InvalidDebugInfo,
    }

    const symbols = try allocator.realloc(symbols_buf, symbol_index);

    // Even though lld emits symbols in ascending order, this debug code
    // should work for programs linked in any valid way.
    // This sort is so that we can binary search later.
    std.sort.sort(MachoSymbol, symbols, {}, MachoSymbol.addressLessThan);

    return ModuleDebugInfo{
        .base_address = undefined,
        .mapped_memory = mapped_mem,
        .ofiles = ModuleDebugInfo.OFileTable.init(allocator),
        .symbols = symbols,
        .strings = strings,
    };
}

fn printLineFromFileAnyOs(out_stream: anytype, line_info: LineInfo) !void {
    // Need this to always block even in async I/O mode, because this could potentially
    // be called from e.g. the event loop code crashing.
    var f = try fs.cwd().openFile(line_info.file_name, .{ .intended_io_mode = .blocking });
    defer f.close();
    // TODO fstat and make sure that the file has the correct size

    var buf: [mem.page_size]u8 = undefined;
    var line: usize = 1;
    var column: usize = 1;
    while (true) {
        const amt_read = try f.read(buf[0..]);
        const slice = buf[0..amt_read];

        for (slice) |byte| {
            if (line == line_info.line) {
                switch (byte) {
                    '\t' => try out_stream.writeByte(' '),
                    else => try out_stream.writeByte(byte),
                }
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
    strx: u32,
    addr: u64,
    size: u32,
    ofile: u32,

    /// Returns the address from the macho file
    fn address(self: MachoSymbol) u64 {
        return self.addr;
    }

    fn addressLessThan(context: void, lhs: MachoSymbol, rhs: MachoSymbol) bool {
        _ = context;
        return lhs.addr < rhs.addr;
    }
};

/// `file` is expected to have been opened with .intended_io_mode == .blocking.
/// Takes ownership of file, even on error.
/// TODO it's weird to take ownership even on error, rework this code.
fn mapWholeFile(file: File) ![]align(mem.page_size) const u8 {
    nosuspend {
        defer file.close();

        const file_len = math.cast(usize, try file.getEndPos()) orelse math.maxInt(usize);
        const mapped_mem = try os.mmap(
            null,
            file_len,
            os.PROT.READ,
            os.MAP.SHARED,
            file.handle,
            0,
        );
        errdefer os.munmap(mapped_mem);

        return mapped_mem;
    }
}

pub const ModuleInfo = struct {
    base_address: usize,
    size: u32,
};

pub const DebugInfo = struct {
    allocator: mem.Allocator,
    address_map: std.AutoHashMap(usize, *ModuleDebugInfo),
    modules: if (native_os == .windows) std.ArrayListUnmanaged(ModuleInfo) else void,

    pub fn init(allocator: mem.Allocator) !DebugInfo {
        var debug_info = DebugInfo{
            .allocator = allocator,
            .address_map = std.AutoHashMap(usize, *ModuleDebugInfo).init(allocator),
            .modules = if (native_os == .windows) .{} else {},
        };

        if (native_os == .windows) {
            const handle = windows.kernel32.CreateToolhelp32Snapshot(windows.TH32CS_SNAPMODULE | windows.TH32CS_SNAPMODULE32, 0);
            if (handle == windows.INVALID_HANDLE_VALUE) {
                switch (windows.kernel32.GetLastError()) {
                    else => |err| return windows.unexpectedError(err),
                }
            }

            defer windows.CloseHandle(handle);

            var module_entry: windows.MODULEENTRY32 = undefined;
            module_entry.dwSize = @sizeOf(windows.MODULEENTRY32);
            if (windows.kernel32.Module32First(handle, &module_entry) == 0) {
                return error.MissingDebugInfo;
            }

            var module_valid = true;
            while (module_valid) {
                const module_info = try debug_info.modules.addOne(allocator);
                module_info.base_address = @ptrToInt(module_entry.modBaseAddr);
                module_info.size = module_entry.modBaseSize;
                module_valid = windows.kernel32.Module32Next(handle, &module_entry) == 1;
            }
        }

        return debug_info;
    }

    pub fn deinit(self: *DebugInfo) void {
        var it = self.address_map.iterator();
        while (it.next()) |entry| {
            const mdi = entry.value_ptr.*;
            mdi.deinit(self.allocator);
            self.allocator.destroy(mdi);
        }
        self.address_map.deinit();
        if (native_os == .windows) self.modules.deinit(self.allocator);
    }

    pub fn getModuleForAddress(self: *DebugInfo, address: usize) !*ModuleDebugInfo {
        if (builtin.zig_backend == .stage2_c) {
            return @as(error{
                InvalidDebugInfo,
                MissingDebugInfo,
                UnsupportedBackend,
            }, error.UnsupportedBackend);
        } else if (comptime builtin.target.isDarwin()) {
            return self.lookupModuleDyld(address);
        } else if (native_os == .windows) {
            return self.lookupModuleWin32(address);
        } else if (native_os == .haiku) {
            return self.lookupModuleHaiku(address);
        } else if (comptime builtin.target.isWasm()) {
            return self.lookupModuleWasm(address);
        } else {
            return self.lookupModuleDl(address);
        }
    }

    fn lookupModuleDyld(self: *DebugInfo, address: usize) !*ModuleDebugInfo {
        const image_count = std.c._dyld_image_count();

        var i: u32 = 0;
        while (i < image_count) : (i += 1) {
            const base_address = std.c._dyld_get_image_vmaddr_slide(i);

            if (address < base_address) continue;

            const header = std.c._dyld_get_image_header(i) orelse continue;

            var it = macho.LoadCommandIterator{
                .ncmds = header.ncmds,
                .buffer = @alignCast(@alignOf(u64), @intToPtr(
                    [*]u8,
                    @ptrToInt(header) + @sizeOf(macho.mach_header_64),
                ))[0..header.sizeofcmds],
            };
            while (it.next()) |cmd| switch (cmd.cmd()) {
                .SEGMENT_64 => {
                    const segment_cmd = cmd.cast(macho.segment_command_64).?;
                    const rebased_address = address - base_address;
                    const seg_start = segment_cmd.vmaddr;
                    const seg_end = seg_start + segment_cmd.vmsize;

                    if (rebased_address >= seg_start and rebased_address < seg_end) {
                        if (self.address_map.get(base_address)) |obj_di| {
                            return obj_di;
                        }

                        const obj_di = try self.allocator.create(ModuleDebugInfo);
                        errdefer self.allocator.destroy(obj_di);

                        const macho_path = mem.sliceTo(std.c._dyld_get_image_name(i), 0);
                        const macho_file = fs.cwd().openFile(macho_path, .{
                            .intended_io_mode = .blocking,
                        }) catch |err| switch (err) {
                            error.FileNotFound => return error.MissingDebugInfo,
                            else => return err,
                        };
                        obj_di.* = try readMachODebugInfo(self.allocator, macho_file);
                        obj_di.base_address = base_address;

                        try self.address_map.putNoClobber(base_address, obj_di);

                        return obj_di;
                    }
                },
                else => {},
            };
        }

        return error.MissingDebugInfo;
    }

    fn lookupModuleWin32(self: *DebugInfo, address: usize) !*ModuleDebugInfo {
        for (self.modules.items) |module| {
            if (address >= module.base_address and address < module.base_address + module.size) {
                if (self.address_map.get(module.base_address)) |obj_di| {
                    return obj_di;
                }

                const mapped_module = @intToPtr([*]const u8, module.base_address)[0..module.size];
                const obj_di = try self.allocator.create(ModuleDebugInfo);
                errdefer self.allocator.destroy(obj_di);

                obj_di.* = try readCoffDebugInfo(self.allocator, mapped_module);
                obj_di.base_address = module.base_address;

                try self.address_map.putNoClobber(module.base_address, obj_di);
                return obj_di;
            }
        }

        return error.MissingDebugInfo;
    }

    fn lookupModuleDl(self: *DebugInfo, address: usize) !*ModuleDebugInfo {
        var ctx: struct {
            // Input
            address: usize,
            // Output
            base_address: usize = undefined,
            name: []const u8 = undefined,
        } = .{ .address = address };
        const CtxTy = @TypeOf(ctx);

        if (os.dl_iterate_phdr(&ctx, error{Found}, struct {
            fn callback(info: *os.dl_phdr_info, size: usize, context: *CtxTy) !void {
                _ = size;
                // The base address is too high
                if (context.address < info.dlpi_addr)
                    return;

                const phdrs = info.dlpi_phdr[0..info.dlpi_phnum];
                for (phdrs) |*phdr| {
                    if (phdr.p_type != elf.PT_LOAD) continue;

                    const seg_start = info.dlpi_addr + phdr.p_vaddr;
                    const seg_end = seg_start + phdr.p_memsz;

                    if (context.address >= seg_start and context.address < seg_end) {
                        // Android libc uses NULL instead of an empty string to mark the
                        // main program
                        context.name = mem.sliceTo(info.dlpi_name, 0) orelse "";
                        context.base_address = info.dlpi_addr;
                        // Stop the iteration
                        return error.Found;
                    }
                }
            }
        }.callback)) {
            return error.MissingDebugInfo;
        } else |err| switch (err) {
            error.Found => {},
        }

        if (self.address_map.get(ctx.base_address)) |obj_di| {
            return obj_di;
        }

        const obj_di = try self.allocator.create(ModuleDebugInfo);
        errdefer self.allocator.destroy(obj_di);

        // TODO https://github.com/ziglang/zig/issues/5525
        const copy = if (ctx.name.len > 0)
            fs.cwd().openFile(ctx.name, .{ .intended_io_mode = .blocking })
        else
            fs.openSelfExe(.{ .intended_io_mode = .blocking });

        const elf_file = copy catch |err| switch (err) {
            error.FileNotFound => return error.MissingDebugInfo,
            else => return err,
        };

        obj_di.* = try readElfDebugInfo(self.allocator, elf_file);
        obj_di.base_address = ctx.base_address;

        try self.address_map.putNoClobber(ctx.base_address, obj_di);

        return obj_di;
    }

    fn lookupModuleHaiku(self: *DebugInfo, address: usize) !*ModuleDebugInfo {
        _ = self;
        _ = address;
        @panic("TODO implement lookup module for Haiku");
    }

    fn lookupModuleWasm(self: *DebugInfo, address: usize) !*ModuleDebugInfo {
        _ = self;
        _ = address;
        @panic("TODO implement lookup module for Wasm");
    }
};

pub const ModuleDebugInfo = switch (native_os) {
    .macos, .ios, .watchos, .tvos => struct {
        base_address: usize,
        mapped_memory: []align(mem.page_size) const u8,
        symbols: []const MachoSymbol,
        strings: [:0]const u8,
        ofiles: OFileTable,

        const OFileTable = std.StringHashMap(OFileInfo);
        const OFileInfo = struct {
            di: DW.DwarfInfo,
            addr_table: std.StringHashMap(u64),
        };

        fn deinit(self: *@This(), allocator: mem.Allocator) void {
            var it = self.ofiles.iterator();
            while (it.next()) |entry| {
                const ofile = entry.value_ptr;
                ofile.di.deinit(allocator);
                ofile.addr_table.deinit();
            }
            self.ofiles.deinit();
            allocator.free(self.symbols);
            os.munmap(self.mapped_memory);
        }

        fn loadOFile(self: *@This(), allocator: mem.Allocator, o_file_path: []const u8) !OFileInfo {
            const o_file = try fs.cwd().openFile(o_file_path, .{ .intended_io_mode = .blocking });
            const mapped_mem = try mapWholeFile(o_file);

            const hdr = @ptrCast(
                *const macho.mach_header_64,
                @alignCast(@alignOf(macho.mach_header_64), mapped_mem.ptr),
            );
            if (hdr.magic != std.macho.MH_MAGIC_64)
                return error.InvalidDebugInfo;

            var segcmd: ?macho.LoadCommandIterator.LoadCommand = null;
            var symtabcmd: ?macho.symtab_command = null;
            var it = macho.LoadCommandIterator{
                .ncmds = hdr.ncmds,
                .buffer = mapped_mem[@sizeOf(macho.mach_header_64)..][0..hdr.sizeofcmds],
            };
            while (it.next()) |cmd| switch (cmd.cmd()) {
                .SEGMENT_64 => segcmd = cmd,
                .SYMTAB => symtabcmd = cmd.cast(macho.symtab_command).?,
                else => {},
            };

            if (segcmd == null or symtabcmd == null) return error.MissingDebugInfo;

            // Parse symbols
            const strtab = @ptrCast(
                [*]const u8,
                &mapped_mem[symtabcmd.?.stroff],
            )[0 .. symtabcmd.?.strsize - 1 :0];
            const symtab = @ptrCast(
                [*]const macho.nlist_64,
                @alignCast(
                    @alignOf(macho.nlist_64),
                    &mapped_mem[symtabcmd.?.symoff],
                ),
            )[0..symtabcmd.?.nsyms];

            // TODO handle tentative (common) symbols
            var addr_table = std.StringHashMap(u64).init(allocator);
            try addr_table.ensureTotalCapacity(@intCast(u32, symtab.len));
            for (symtab) |sym| {
                if (sym.n_strx == 0) continue;
                if (sym.undf() or sym.tentative() or sym.abs()) continue;
                const sym_name = mem.sliceTo(strtab[sym.n_strx..], 0);
                // TODO is it possible to have a symbol collision?
                addr_table.putAssumeCapacityNoClobber(sym_name, sym.n_value);
            }

            var opt_debug_line: ?macho.section_64 = null;
            var opt_debug_info: ?macho.section_64 = null;
            var opt_debug_abbrev: ?macho.section_64 = null;
            var opt_debug_str: ?macho.section_64 = null;
            var opt_debug_str_offsets: ?macho.section_64 = null;
            var opt_debug_line_str: ?macho.section_64 = null;
            var opt_debug_ranges: ?macho.section_64 = null;
            var opt_debug_loclists: ?macho.section_64 = null;
            var opt_debug_rnglists: ?macho.section_64 = null;
            var opt_debug_addr: ?macho.section_64 = null;
            var opt_debug_names: ?macho.section_64 = null;
            var opt_debug_frame: ?macho.section_64 = null;

            for (segcmd.?.getSections()) |sect| {
                const name = sect.sectName();
                if (mem.eql(u8, name, "__debug_line")) {
                    opt_debug_line = sect;
                } else if (mem.eql(u8, name, "__debug_info")) {
                    opt_debug_info = sect;
                } else if (mem.eql(u8, name, "__debug_abbrev")) {
                    opt_debug_abbrev = sect;
                } else if (mem.eql(u8, name, "__debug_str")) {
                    opt_debug_str = sect;
                } else if (mem.eql(u8, name, "__debug_str_offsets")) {
                    opt_debug_str_offsets = sect;
                } else if (mem.eql(u8, name, "__debug_line_str")) {
                    opt_debug_line_str = sect;
                } else if (mem.eql(u8, name, "__debug_ranges")) {
                    opt_debug_ranges = sect;
                } else if (mem.eql(u8, name, "__debug_loclists")) {
                    opt_debug_loclists = sect;
                } else if (mem.eql(u8, name, "__debug_rnglists")) {
                    opt_debug_rnglists = sect;
                } else if (mem.eql(u8, name, "__debug_addr")) {
                    opt_debug_addr = sect;
                } else if (mem.eql(u8, name, "__debug_names")) {
                    opt_debug_names = sect;
                } else if (mem.eql(u8, name, "__debug_frame")) {
                    opt_debug_frame = sect;
                }
            }

            const debug_line = opt_debug_line orelse
                return error.MissingDebugInfo;
            const debug_info = opt_debug_info orelse
                return error.MissingDebugInfo;
            const debug_str = opt_debug_str orelse
                return error.MissingDebugInfo;
            const debug_abbrev = opt_debug_abbrev orelse
                return error.MissingDebugInfo;

            var di = DW.DwarfInfo{
                .endian = .Little,
                .debug_info = try chopSlice(mapped_mem, debug_info.offset, debug_info.size),
                .debug_abbrev = try chopSlice(mapped_mem, debug_abbrev.offset, debug_abbrev.size),
                .debug_str = try chopSlice(mapped_mem, debug_str.offset, debug_str.size),
                .debug_str_offsets = if (opt_debug_str_offsets) |debug_str_offsets|
                    try chopSlice(mapped_mem, debug_str_offsets.offset, debug_str_offsets.size)
                else
                    null,
                .debug_line = try chopSlice(mapped_mem, debug_line.offset, debug_line.size),
                .debug_line_str = if (opt_debug_line_str) |debug_line_str|
                    try chopSlice(mapped_mem, debug_line_str.offset, debug_line_str.size)
                else
                    null,
                .debug_ranges = if (opt_debug_ranges) |debug_ranges|
                    try chopSlice(mapped_mem, debug_ranges.offset, debug_ranges.size)
                else
                    null,
                .debug_loclists = if (opt_debug_loclists) |debug_loclists|
                    try chopSlice(mapped_mem, debug_loclists.offset, debug_loclists.size)
                else
                    null,
                .debug_rnglists = if (opt_debug_rnglists) |debug_rnglists|
                    try chopSlice(mapped_mem, debug_rnglists.offset, debug_rnglists.size)
                else
                    null,
                .debug_addr = if (opt_debug_addr) |debug_addr|
                    try chopSlice(mapped_mem, debug_addr.offset, debug_addr.size)
                else
                    null,
                .debug_names = if (opt_debug_names) |debug_names|
                    try chopSlice(mapped_mem, debug_names.offset, debug_names.size)
                else
                    null,
                .debug_frame = if (opt_debug_frame) |debug_frame|
                    try chopSlice(mapped_mem, debug_frame.offset, debug_frame.size)
                else
                    null,
            };

            try DW.openDwarfDebugInfo(&di, allocator);
            var info = OFileInfo{
                .di = di,
                .addr_table = addr_table,
            };

            // Add the debug info to the cache
            try self.ofiles.putNoClobber(o_file_path, info);

            return info;
        }

        pub fn getSymbolAtAddress(self: *@This(), allocator: mem.Allocator, address: usize) !SymbolInfo {
            nosuspend {
                // Translate the VA into an address into this object
                const relocated_address = address - self.base_address;

                // Find the .o file where this symbol is defined
                const symbol = machoSearchSymbols(self.symbols, relocated_address) orelse
                    return SymbolInfo{};
                const addr_off = relocated_address - symbol.addr;

                // Take the symbol name from the N_FUN STAB entry, we're going to
                // use it if we fail to find the DWARF infos
                const stab_symbol = mem.sliceTo(self.strings[symbol.strx..], 0);
                const o_file_path = mem.sliceTo(self.strings[symbol.ofile..], 0);

                // Check if its debug infos are already in the cache
                var o_file_info = self.ofiles.get(o_file_path) orelse
                    (self.loadOFile(allocator, o_file_path) catch |err| switch (err) {
                    error.FileNotFound,
                    error.MissingDebugInfo,
                    error.InvalidDebugInfo,
                    => {
                        return SymbolInfo{ .symbol_name = stab_symbol };
                    },
                    else => return err,
                });
                const o_file_di = &o_file_info.di;

                // Translate again the address, this time into an address inside the
                // .o file
                const relocated_address_o = o_file_info.addr_table.get(stab_symbol) orelse return SymbolInfo{
                    .symbol_name = "???",
                };

                if (o_file_di.findCompileUnit(relocated_address_o)) |compile_unit| {
                    return SymbolInfo{
                        .symbol_name = o_file_di.getSymbolName(relocated_address_o) orelse "???",
                        .compile_unit_name = compile_unit.die.getAttrString(
                            o_file_di,
                            DW.AT.name,
                            o_file_di.debug_str,
                            compile_unit.*,
                        ) catch |err| switch (err) {
                            error.MissingDebugInfo, error.InvalidDebugInfo => "???",
                        },
                        .line_info = o_file_di.getLineNumberInfo(
                            allocator,
                            compile_unit.*,
                            relocated_address_o + addr_off,
                        ) catch |err| switch (err) {
                            error.MissingDebugInfo, error.InvalidDebugInfo => null,
                            else => return err,
                        },
                    };
                } else |err| switch (err) {
                    error.MissingDebugInfo, error.InvalidDebugInfo => {
                        return SymbolInfo{ .symbol_name = stab_symbol };
                    },
                    else => return err,
                }

                unreachable;
            }
        }
    },
    .uefi, .windows => struct {
        base_address: usize,
        debug_data: PdbOrDwarf,
        coff_image_base: u64,
        coff_section_headers: []coff.SectionHeader,

        fn deinit(self: *@This(), allocator: mem.Allocator) void {
            switch (self.debug_data) {
                .dwarf => |*dwarf| {
                    allocator.free(dwarf.debug_info);
                    allocator.free(dwarf.debug_abbrev);
                    allocator.free(dwarf.debug_str);
                    allocator.free(dwarf.debug_line);
                    if (dwarf.debug_str_offsets) |d| allocator.free(d);
                    if (dwarf.debug_line_str) |d| allocator.free(d);
                    if (dwarf.debug_ranges) |d| allocator.free(d);
                    if (dwarf.debug_loclists) |d| allocator.free(d);
                    if (dwarf.debug_rnglists) |d| allocator.free(d);
                    if (dwarf.debug_addr) |d| allocator.free(d);
                    if (dwarf.debug_names) |d| allocator.free(d);
                    if (dwarf.debug_frame) |d| allocator.free(d);
                },
                .pdb => {
                    allocator.free(self.coff_section_headers);
                },
            }

            self.debug_data.deinit(allocator);
        }

        pub fn getSymbolAtAddress(self: *@This(), allocator: mem.Allocator, address: usize) !SymbolInfo {
            // Translate the VA into an address into this object
            const relocated_address = address - self.base_address;

            switch (self.debug_data) {
                .dwarf => |*dwarf| {
                    const dwarf_address = relocated_address + self.coff_image_base;
                    return getSymbolFromDwarf(allocator, dwarf_address, dwarf);
                },
                .pdb => {
                    // fallthrough to pdb handling
                },
            }

            var coff_section: *align(1) const coff.SectionHeader = undefined;
            const mod_index = for (self.debug_data.pdb.sect_contribs) |sect_contrib| {
                if (sect_contrib.Section > self.coff_section_headers.len) continue;
                // Remember that SectionContribEntry.Section is 1-based.
                coff_section = &self.coff_section_headers[sect_contrib.Section - 1];

                const vaddr_start = coff_section.virtual_address + sect_contrib.Offset;
                const vaddr_end = vaddr_start + sect_contrib.Size;
                if (relocated_address >= vaddr_start and relocated_address < vaddr_end) {
                    break sect_contrib.ModuleIndex;
                }
            } else {
                // we have no information to add to the address
                return SymbolInfo{};
            };

            const module = (try self.debug_data.pdb.getModule(mod_index)) orelse
                return error.InvalidDebugInfo;
            const obj_basename = fs.path.basename(module.obj_file_name);

            const symbol_name = self.debug_data.pdb.getSymbolName(
                module,
                relocated_address - coff_section.virtual_address,
            ) orelse "???";
            const opt_line_info = try self.debug_data.pdb.getLineNumberInfo(
                module,
                relocated_address - coff_section.virtual_address,
            );

            return SymbolInfo{
                .symbol_name = symbol_name,
                .compile_unit_name = obj_basename,
                .line_info = opt_line_info,
            };
        }
    },
    .linux, .netbsd, .freebsd, .dragonfly, .openbsd, .haiku, .solaris => struct {
        base_address: usize,
        dwarf: DW.DwarfInfo,
        mapped_memory: []align(mem.page_size) const u8,

        fn deinit(self: *@This(), allocator: mem.Allocator) void {
            self.dwarf.deinit(allocator);
            os.munmap(self.mapped_memory);
        }

        pub fn getSymbolAtAddress(self: *@This(), allocator: mem.Allocator, address: usize) !SymbolInfo {
            // Translate the VA into an address into this object
            const relocated_address = address - self.base_address;
            return getSymbolFromDwarf(allocator, relocated_address, &self.dwarf);
        }
    },
    .wasi => struct {
        fn deinit(self: *@This(), allocator: mem.Allocator) void {
            _ = self;
            _ = allocator;
        }

        pub fn getSymbolAtAddress(self: *@This(), allocator: mem.Allocator, address: usize) !SymbolInfo {
            _ = self;
            _ = allocator;
            _ = address;
            return SymbolInfo{};
        }
    },
    else => DW.DwarfInfo,
};

fn getSymbolFromDwarf(allocator: mem.Allocator, address: u64, di: *DW.DwarfInfo) !SymbolInfo {
    if (nosuspend di.findCompileUnit(address)) |compile_unit| {
        return SymbolInfo{
            .symbol_name = nosuspend di.getSymbolName(address) orelse "???",
            .compile_unit_name = compile_unit.die.getAttrString(di, DW.AT.name, di.debug_str, compile_unit.*) catch |err| switch (err) {
                error.MissingDebugInfo, error.InvalidDebugInfo => "???",
            },
            .line_info = nosuspend di.getLineNumberInfo(allocator, compile_unit.*, address) catch |err| switch (err) {
                error.MissingDebugInfo, error.InvalidDebugInfo => null,
                else => return err,
            },
        };
    } else |err| switch (err) {
        error.MissingDebugInfo, error.InvalidDebugInfo => {
            return SymbolInfo{};
        },
        else => return err,
    }
}

/// TODO multithreaded awareness
var debug_info_allocator: ?mem.Allocator = null;
var debug_info_arena_allocator: std.heap.ArenaAllocator = undefined;
fn getDebugInfoAllocator() mem.Allocator {
    if (debug_info_allocator) |a| return a;

    debug_info_arena_allocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = debug_info_arena_allocator.allocator();
    debug_info_allocator = allocator;
    return allocator;
}

/// Whether or not the current target can print useful debug information when a segfault occurs.
pub const have_segfault_handling_support = switch (native_os) {
    .linux,
    .macos,
    .netbsd,
    .solaris,
    .windows,
    => true,

    .freebsd, .openbsd => @hasDecl(os.system, "ucontext_t"),
    else => false,
};

const enable_segfault_handler = std.options.enable_segfault_handler;
pub const default_enable_segfault_handler = runtime_safety and have_segfault_handling_support;

pub fn maybeEnableSegfaultHandler() void {
    if (enable_segfault_handler) {
        std.debug.attachSegfaultHandler();
    }
}

var windows_segfault_handle: ?windows.HANDLE = null;

pub fn updateSegfaultHandler(act: ?*const os.Sigaction) error{OperationNotSupported}!void {
    try os.sigaction(os.SIG.SEGV, act, null);
    try os.sigaction(os.SIG.ILL, act, null);
    try os.sigaction(os.SIG.BUS, act, null);
    try os.sigaction(os.SIG.FPE, act, null);
}

/// Attaches a global SIGSEGV handler which calls @panic("segmentation fault");
pub fn attachSegfaultHandler() void {
    if (!have_segfault_handling_support) {
        @compileError("segfault handler not supported for this target");
    }
    if (native_os == .windows) {
        windows_segfault_handle = windows.kernel32.AddVectoredExceptionHandler(0, handleSegfaultWindows);
        return;
    }
    var act = os.Sigaction{
        .handler = .{ .sigaction = handleSegfaultPosix },
        .mask = os.empty_sigset,
        .flags = (os.SA.SIGINFO | os.SA.RESTART | os.SA.RESETHAND),
    };

    updateSegfaultHandler(&act) catch {
        @panic("unable to install segfault handler, maybe adjust have_segfault_handling_support in std/debug.zig");
    };
}

fn resetSegfaultHandler() void {
    if (native_os == .windows) {
        if (windows_segfault_handle) |handle| {
            assert(windows.kernel32.RemoveVectoredExceptionHandler(handle) != 0);
            windows_segfault_handle = null;
        }
        return;
    }
    var act = os.Sigaction{
        .handler = .{ .handler = os.SIG.DFL },
        .mask = os.empty_sigset,
        .flags = 0,
    };
    // To avoid a double-panic, do nothing if an error happens here.
    updateSegfaultHandler(&act) catch {};
}

fn handleSegfaultPosix(sig: i32, info: *const os.siginfo_t, ctx_ptr: ?*const anyopaque) callconv(.C) noreturn {
    // Reset to the default handler so that if a segfault happens in this handler it will crash
    // the process. Also when this handler returns, the original instruction will be repeated
    // and the resulting segfault will crash the process rather than continually dump stack traces.
    resetSegfaultHandler();

    const addr = switch (native_os) {
        .linux => @ptrToInt(info.fields.sigfault.addr),
        .freebsd, .macos => @ptrToInt(info.addr),
        .netbsd => @ptrToInt(info.info.reason.fault.addr),
        .openbsd => @ptrToInt(info.data.fault.addr),
        .solaris => @ptrToInt(info.reason.fault.addr),
        else => unreachable,
    };

    // Don't use std.debug.print() as stderr_mutex may still be locked.
    nosuspend {
        const stderr = io.getStdErr().writer();
        _ = switch (sig) {
            os.SIG.SEGV => stderr.print("Segmentation fault at address 0x{x}\n", .{addr}),
            os.SIG.ILL => stderr.print("Illegal instruction at address 0x{x}\n", .{addr}),
            os.SIG.BUS => stderr.print("Bus error at address 0x{x}\n", .{addr}),
            os.SIG.FPE => stderr.print("Arithmetic exception at address 0x{x}\n", .{addr}),
            else => unreachable,
        } catch os.abort();
    }

    switch (native_arch) {
        .x86 => {
            const ctx = @ptrCast(*const os.ucontext_t, @alignCast(@alignOf(os.ucontext_t), ctx_ptr));
            const ip = @intCast(usize, ctx.mcontext.gregs[os.REG.EIP]);
            const bp = @intCast(usize, ctx.mcontext.gregs[os.REG.EBP]);
            dumpStackTraceFromBase(bp, ip);
        },
        .x86_64 => {
            const ctx = @ptrCast(*const os.ucontext_t, @alignCast(@alignOf(os.ucontext_t), ctx_ptr));
            const ip = switch (native_os) {
                .linux, .netbsd, .solaris => @intCast(usize, ctx.mcontext.gregs[os.REG.RIP]),
                .freebsd => @intCast(usize, ctx.mcontext.rip),
                .openbsd => @intCast(usize, ctx.sc_rip),
                .macos => @intCast(usize, ctx.mcontext.ss.rip),
                else => unreachable,
            };
            const bp = switch (native_os) {
                .linux, .netbsd, .solaris => @intCast(usize, ctx.mcontext.gregs[os.REG.RBP]),
                .openbsd => @intCast(usize, ctx.sc_rbp),
                .freebsd => @intCast(usize, ctx.mcontext.rbp),
                .macos => @intCast(usize, ctx.mcontext.ss.rbp),
                else => unreachable,
            };
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
            const ip = switch (native_os) {
                .macos => @intCast(usize, ctx.mcontext.ss.pc),
                .netbsd => @intCast(usize, ctx.mcontext.gregs[os.REG.PC]),
                .freebsd => @intCast(usize, ctx.mcontext.gpregs.elr),
                else => @intCast(usize, ctx.mcontext.pc),
            };
            // x29 is the ABI-designated frame pointer
            const bp = switch (native_os) {
                .macos => @intCast(usize, ctx.mcontext.ss.fp),
                .netbsd => @intCast(usize, ctx.mcontext.gregs[os.REG.FP]),
                .freebsd => @intCast(usize, ctx.mcontext.gpregs.x[os.REG.FP]),
                else => @intCast(usize, ctx.mcontext.regs[29]),
            };
            dumpStackTraceFromBase(bp, ip);
        },
        else => {},
    }

    // We cannot allow the signal handler to return because when it runs the original instruction
    // again, the memory may be mapped and undefined behavior would occur rather than repeating
    // the segfault. So we simply abort here.
    os.abort();
}

fn handleSegfaultWindows(info: *windows.EXCEPTION_POINTERS) callconv(windows.WINAPI) c_long {
    switch (info.ExceptionRecord.ExceptionCode) {
        windows.EXCEPTION_DATATYPE_MISALIGNMENT => handleSegfaultWindowsExtra(info, 0, "Unaligned Memory Access"),
        windows.EXCEPTION_ACCESS_VIOLATION => handleSegfaultWindowsExtra(info, 1, null),
        windows.EXCEPTION_ILLEGAL_INSTRUCTION => handleSegfaultWindowsExtra(info, 2, null),
        windows.EXCEPTION_STACK_OVERFLOW => handleSegfaultWindowsExtra(info, 0, "Stack Overflow"),
        else => return windows.EXCEPTION_CONTINUE_SEARCH,
    }
}

// zig won't let me use an anon enum here https://github.com/ziglang/zig/issues/3707
fn handleSegfaultWindowsExtra(info: *windows.EXCEPTION_POINTERS, comptime msg: u8, comptime format: ?[]const u8) noreturn {
    const exception_address = @ptrToInt(info.ExceptionRecord.ExceptionAddress);
    if (@hasDecl(windows, "CONTEXT")) {
        const regs = info.ContextRecord.getRegs();
        // Don't use std.debug.print() as stderr_mutex may still be locked.
        nosuspend {
            const stderr = io.getStdErr().writer();
            _ = switch (msg) {
                0 => stderr.print("{s}\n", .{format.?}),
                1 => stderr.print("Segmentation fault at address 0x{x}\n", .{info.ExceptionRecord.ExceptionInformation[1]}),
                2 => stderr.print("Illegal instruction at address 0x{x}\n", .{regs.ip}),
                else => unreachable,
            } catch os.abort();
        }

        dumpStackTraceFromBase(regs.bp, regs.ip);
        os.abort();
    } else {
        switch (msg) {
            0 => panicImpl(null, exception_address, format.?),
            1 => {
                const format_item = "Segmentation fault at address 0x{x}";
                var buf: [format_item.len + 64]u8 = undefined; // 64 is arbitrary, but sufficiently large
                const to_print = std.fmt.bufPrint(buf[0..buf.len], format_item, .{info.ExceptionRecord.ExceptionInformation[1]}) catch unreachable;
                panicImpl(null, exception_address, to_print);
            },
            2 => panicImpl(null, exception_address, "Illegal Instruction"),
            else => unreachable,
        }
    }
}

pub fn dumpStackPointerAddr(prefix: []const u8) void {
    const sp = asm (""
        : [argc] "={rsp}" (-> usize),
    );
    std.debug.print("{} sp = 0x{x}\n", .{ prefix, sp });
}

test "manage resources correctly" {
    if (builtin.os.tag == .wasi) return error.SkipZigTest;

    if (builtin.os.tag == .windows and builtin.cpu.arch == .x86_64) {
        // https://github.com/ziglang/zig/issues/13963
        return error.SkipZigTest;
    }

    const writer = std.io.null_writer;
    var di = try openSelfDebugInfo(testing.allocator);
    defer di.deinit();
    try printSourceAtAddress(&di, writer, showMyTrace(), detectTTYConfig(std.io.getStdErr()));
}

noinline fn showMyTrace() usize {
    return @returnAddress();
}

/// This API helps you track where a value originated and where it was mutated,
/// or any other points of interest.
/// In debug mode, it adds a small size penalty (104 bytes on 64-bit architectures)
/// to the aggregate that you add it to.
/// In release mode, it is size 0 and all methods are no-ops.
/// This is a pre-made type with default settings.
/// For more advanced usage, see `ConfigurableTrace`.
pub const Trace = ConfigurableTrace(2, 4, builtin.mode == .Debug);

pub fn ConfigurableTrace(comptime size: usize, comptime stack_frame_count: usize, comptime is_enabled: bool) type {
    return struct {
        addrs: [actual_size][stack_frame_count]usize = undefined,
        notes: [actual_size][]const u8 = undefined,
        index: Index = 0,

        const actual_size = if (enabled) size else 0;
        const Index = if (enabled) usize else u0;

        pub const enabled = is_enabled;

        pub const add = if (enabled) addNoInline else addNoOp;

        pub noinline fn addNoInline(t: *@This(), note: []const u8) void {
            comptime assert(enabled);
            return addAddr(t, @returnAddress(), note);
        }

        pub inline fn addNoOp(t: *@This(), note: []const u8) void {
            _ = t;
            _ = note;
            comptime assert(!enabled);
        }

        pub fn addAddr(t: *@This(), addr: usize, note: []const u8) void {
            if (!enabled) return;

            if (t.index < size) {
                t.notes[t.index] = note;
                t.addrs[t.index] = [1]usize{0} ** stack_frame_count;
                var stack_trace: std.builtin.StackTrace = .{
                    .index = 0,
                    .instruction_addresses = &t.addrs[t.index],
                };
                captureStackTrace(addr, &stack_trace);
            }
            // Keep counting even if the end is reached so that the
            // user can find out how much more size they need.
            t.index += 1;
        }

        pub fn dump(t: @This()) void {
            if (!enabled) return;

            const tty_config = detectTTYConfig(std.io.getStdErr());
            const stderr = io.getStdErr().writer();
            const end = @min(t.index, size);
            const debug_info = getSelfDebugInfo() catch |err| {
                stderr.print(
                    "Unable to dump stack trace: Unable to open debug info: {s}\n",
                    .{@errorName(err)},
                ) catch return;
                return;
            };
            for (t.addrs[0..end], 0..) |frames_array, i| {
                stderr.print("{s}:\n", .{t.notes[i]}) catch return;
                var frames_array_mutable = frames_array;
                const frames = mem.sliceTo(frames_array_mutable[0..], 0);
                const stack_trace: std.builtin.StackTrace = .{
                    .index = frames.len,
                    .instruction_addresses = frames,
                };
                writeStackTrace(stack_trace, stderr, getDebugInfoAllocator(), debug_info, tty_config) catch continue;
            }
            if (t.index > end) {
                stderr.print("{d} more traces not shown; consider increasing trace size\n", .{
                    t.index - end,
                }) catch return;
            }
        }

        pub fn format(
            t: Trace,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            if (fmt.len != 0) std.fmt.invalidFmtError(fmt, t);
            _ = options;
            if (enabled) {
                try writer.writeAll("\n");
                t.dump();
                try writer.writeAll("\n");
            } else {
                return writer.writeAll("(value tracing disabled)");
            }
        }
    };
}
