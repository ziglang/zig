const builtin = @import("builtin");
const std = @import("std.zig");
const math = std.math;
const mem = std.mem;
const io = std.io;
const posix = std.posix;
const fs = std.fs;
const testing = std.testing;
const root = @import("root");
const File = std.fs.File;
const windows = std.os.windows;
const native_arch = builtin.cpu.arch;
const native_os = builtin.os.tag;
const native_endian = native_arch.endian();

pub const MemoryAccessor = @import("debug/MemoryAccessor.zig");
pub const FixedBufferReader = @import("debug/FixedBufferReader.zig");
pub const Dwarf = @import("debug/Dwarf.zig");
pub const Pdb = @import("debug/Pdb.zig");
pub const SelfInfo = @import("debug/SelfInfo.zig");
pub const Info = @import("debug/Info.zig");
pub const Coverage = @import("debug/Coverage.zig");

pub const FormattedPanic = @import("debug/FormattedPanic.zig");
pub const SimplePanic = @import("debug/SimplePanic.zig");

/// Unresolved source locations can be represented with a single `usize` that
/// corresponds to a virtual memory address of the program counter. Combined
/// with debug information, those values can be converted into a resolved
/// source location, including file, line, and column.
pub const SourceLocation = struct {
    line: u64,
    column: u64,
    file_name: []const u8,

    pub const invalid: SourceLocation = .{
        .line = 0,
        .column = 0,
        .file_name = &.{},
    };
};

pub const Symbol = struct {
    name: []const u8 = "???",
    compile_unit_name: []const u8 = "???",
    source_location: ?SourceLocation = null,
};

/// Deprecated because it returns the optimization mode of the standard
/// library, when the caller probably wants to use the optimization mode of
/// their own module.
pub const runtime_safety = switch (builtin.mode) {
    .Debug, .ReleaseSafe => true,
    .ReleaseFast, .ReleaseSmall => false,
};

pub const sys_can_stack_trace = switch (builtin.cpu.arch) {
    // Observed to go into an infinite loop.
    // TODO: Make this work.
    .mips,
    .mipsel,
    .mips64,
    .mips64el,
    .s390x,
    => false,

    // `@returnAddress()` in LLVM 10 gives
    // "Non-Emscripten WebAssembly hasn't implemented __builtin_return_address".
    .wasm32,
    .wasm64,
    => native_os == .emscripten,

    // `@returnAddress()` is unsupported in LLVM 13.
    .bpfel,
    .bpfeb,
    => false,

    else => true,
};

/// Allows the caller to freely write to stderr until `unlockStdErr` is called.
///
/// During the lock, any `std.Progress` information is cleared from the terminal.
pub fn lockStdErr() void {
    std.Progress.lockStdErr();
}

pub fn unlockStdErr() void {
    std.Progress.unlockStdErr();
}

/// Print to stderr, unbuffered, and silently returning on failure. Intended
/// for use in "printf debugging." Use `std.log` functions for proper logging.
pub fn print(comptime fmt: []const u8, args: anytype) void {
    lockStdErr();
    defer unlockStdErr();
    const stderr = io.getStdErr().writer();
    nosuspend stderr.print(fmt, args) catch return;
}

pub fn getStderrMutex() *std.Thread.Mutex {
    @compileError("deprecated. call std.debug.lockStdErr() and std.debug.unlockStdErr() instead which will integrate properly with std.Progress");
}

/// TODO multithreaded awareness
var self_debug_info: ?SelfInfo = null;

pub fn getSelfDebugInfo() !*SelfInfo {
    if (self_debug_info) |*info| {
        return info;
    } else {
        self_debug_info = try SelfInfo.open(getDebugInfoAllocator());
        return &self_debug_info.?;
    }
}

/// Tries to print a hexadecimal view of the bytes, unbuffered, and ignores any error returned.
/// Obtains the stderr mutex while dumping.
pub fn dumpHex(bytes: []const u8) void {
    lockStdErr();
    defer unlockStdErr();
    dumpHexFallible(bytes) catch {};
}

/// Prints a hexadecimal view of the bytes, unbuffered, returning any error that occurs.
pub fn dumpHexFallible(bytes: []const u8) !void {
    const stderr = std.io.getStdErr();
    const ttyconf = std.io.tty.detectConfig(stderr);
    const writer = stderr.writer();
    var chunks = mem.window(u8, bytes, 16, 16);
    while (chunks.next()) |window| {
        // 1. Print the address.
        const address = (@intFromPtr(bytes.ptr) + 0x10 * (chunks.index orelse 0) / 16) - 0x10;
        try ttyconf.setColor(writer, .dim);
        // We print the address in lowercase and the bytes in uppercase hexadecimal to distinguish them more.
        // Also, make sure all lines are aligned by padding the address.
        try writer.print("{x:0>[1]}  ", .{ address, @sizeOf(usize) * 2 });
        try ttyconf.setColor(writer, .reset);

        // 2. Print the bytes.
        for (window, 0..) |byte, index| {
            try writer.print("{X:0>2} ", .{byte});
            if (index == 7) try writer.writeByte(' ');
        }
        try writer.writeByte(' ');
        if (window.len < 16) {
            var missing_columns = (16 - window.len) * 3;
            if (window.len < 8) missing_columns += 1;
            try writer.writeByteNTimes(' ', missing_columns);
        }

        // 3. Print the characters.
        for (window) |byte| {
            if (std.ascii.isPrint(byte)) {
                try writer.writeByte(byte);
            } else {
                // Related: https://github.com/ziglang/zig/issues/7600
                if (ttyconf == .windows_api) {
                    try writer.writeByte('.');
                    continue;
                }

                // Let's print some common control codes as graphical Unicode symbols.
                // We don't want to do this for all control codes because most control codes apart from
                // the ones that Zig has escape sequences for are likely not very useful to print as symbols.
                switch (byte) {
                    '\n' => try writer.writeAll("␊"),
                    '\r' => try writer.writeAll("␍"),
                    '\t' => try writer.writeAll("␉"),
                    else => try writer.writeByte('.'),
                }
            }
        }
        try writer.writeByte('\n');
    }
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
        writeCurrentStackTrace(stderr, debug_info, io.tty.detectConfig(io.getStdErr()), start_addr) catch |err| {
            stderr.print("Unable to dump stack trace: {s}\n", .{@errorName(err)}) catch return;
            return;
        };
    }
}

pub const have_ucontext = posix.ucontext_t != void;

/// Platform-specific thread state. This contains register state, and on some platforms
/// information about the stack. This is not safe to trivially copy, because some platforms
/// use internal pointers within this structure. To make a copy, use `copyContext`.
pub const ThreadContext = blk: {
    if (native_os == .windows) {
        break :blk windows.CONTEXT;
    } else if (have_ucontext) {
        break :blk posix.ucontext_t;
    } else {
        break :blk void;
    }
};

/// Copies one context to another, updating any internal pointers
pub fn copyContext(source: *const ThreadContext, dest: *ThreadContext) void {
    if (!have_ucontext) return {};
    dest.* = source.*;
    relocateContext(dest);
}

/// Updates any internal pointers in the context to reflect its current location
pub fn relocateContext(context: *ThreadContext) void {
    return switch (native_os) {
        .macos => {
            context.mcontext = &context.__mcontext_data;
        },
        else => {},
    };
}

pub const have_getcontext = @TypeOf(posix.system.getcontext) != void;

/// Capture the current context. The register values in the context will reflect the
/// state after the platform `getcontext` function returns.
///
/// It is valid to call this if the platform doesn't have context capturing support,
/// in that case false will be returned.
pub inline fn getContext(context: *ThreadContext) bool {
    if (native_os == .windows) {
        context.* = std.mem.zeroes(windows.CONTEXT);
        windows.ntdll.RtlCaptureContext(context);
        return true;
    }

    const result = have_getcontext and posix.system.getcontext(context) == 0;
    if (native_os == .macos) {
        assert(context.mcsize == @sizeOf(std.c.mcontext_t));

        // On aarch64-macos, the system getcontext doesn't write anything into the pc
        // register slot, it only writes lr. This makes the context consistent with
        // other aarch64 getcontext implementations which write the current lr
        // (where getcontext will return to) into both the lr and pc slot of the context.
        if (native_arch == .aarch64) context.mcontext.ss.pc = context.mcontext.ss.lr;
    }

    return result;
}

/// Tries to print the stack trace starting from the supplied base pointer to stderr,
/// unbuffered, and ignores any error returned.
/// TODO multithreaded awareness
pub fn dumpStackTraceFromBase(context: *ThreadContext) void {
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
        const tty_config = io.tty.detectConfig(io.getStdErr());
        if (native_os == .windows) {
            // On x86_64 and aarch64, the stack will be unwound using RtlVirtualUnwind using the context
            // provided by the exception handler. On x86, RtlVirtualUnwind doesn't exist. Instead, a new backtrace
            // will be captured and frames prior to the exception will be filtered.
            // The caveat is that RtlCaptureStackBackTrace does not include the KiUserExceptionDispatcher frame,
            // which is where the IP in `context` points to, so it can't be used as start_addr.
            // Instead, start_addr is recovered from the stack.
            const start_addr = if (builtin.cpu.arch == .x86) @as(*const usize, @ptrFromInt(context.getRegs().bp + 4)).* else null;
            writeStackTraceWindows(stderr, debug_info, tty_config, context, start_addr) catch return;
            return;
        }

        var it = StackIterator.initWithContext(null, debug_info, context) catch return;
        defer it.deinit();
        printSourceAtAddress(debug_info, stderr, it.unwind_state.?.dwarf_context.pc, tty_config) catch return;

        while (it.next()) |return_address| {
            printLastUnwindError(&it, debug_info, stderr, tty_config);

            // On arm64 macOS, the address of the last frame is 0x0 rather than 0x1 as on x86_64 macOS,
            // therefore, we do a check for `return_address == 0` before subtracting 1 from it to avoid
            // an overflow. We do not need to signal `StackIterator` as it will correctly detect this
            // condition on the subsequent iteration and return `null` thus terminating the loop.
            // same behaviour for x86-windows-msvc
            const address = if (return_address == 0) return_address else return_address - 1;
            printSourceAtAddress(debug_info, stderr, address, tty_config) catch return;
        } else printLastUnwindError(&it, debug_info, stderr, tty_config);
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
            stack_trace.index = walkStackWindows(addrs[0..], null);
            return;
        };
        var addr_buf_stack: [32]usize = undefined;
        const addr_buf = if (addr_buf_stack.len > addrs.len) addr_buf_stack[0..] else addrs;
        const n = walkStackWindows(addr_buf[0..], null);
        const first_index = for (addr_buf[0..n], 0..) |addr, i| {
            if (addr == first_addr) {
                break i;
            }
        } else {
            stack_trace.index = 0;
            return;
        };
        const end_index = @min(first_index + addrs.len, n);
        const slice = addr_buf[first_index..end_index];
        // We use a for loop here because slice and addrs may alias.
        for (slice, 0..) |addr, i| {
            addrs[i] = addr;
        }
        stack_trace.index = slice.len;
    } else {
        // TODO: This should use the DWARF unwinder if .eh_frame_hdr is available (so that full debug info parsing isn't required).
        //       A new path for loading SelfInfo needs to be created which will only attempt to parse in-memory sections, because
        //       stopping to load other debug info (ie. source line info) from disk here is not required for unwinding.
        var it = StackIterator.init(first_address, null);
        defer it.deinit();
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
        writeStackTrace(stack_trace, stderr, debug_info, io.tty.detectConfig(io.getStdErr())) catch |err| {
            stderr.print("Unable to dump stack trace: {s}\n", .{@errorName(err)}) catch return;
            return;
        };
    }
}

/// Invokes detectable illegal behavior when `ok` is `false`.
///
/// In Debug and ReleaseSafe modes, calls to this function are always
/// generated, and the `unreachable` statement triggers a panic.
///
/// In ReleaseFast and ReleaseSmall modes, calls to this function are optimized
/// away, and in fact the optimizer is able to use the assertion in its
/// heuristics.
///
/// Inside a test block, it is best to use the `std.testing` module rather than
/// this function, because this function may not detect a test failure in
/// ReleaseFast and ReleaseSmall mode. Outside of a test block, this assert
/// function is the correct function to use.
pub fn assert(ok: bool) void {
    if (!ok) unreachable; // assertion failure
}

/// Invokes detectable illegal behavior when the provided slice is not mapped
/// or lacks read permissions.
pub fn assertReadable(slice: []const volatile u8) void {
    if (!runtime_safety) return;
    for (slice) |*byte| _ = byte.*;
}

/// By including a call to this function, the caller gains an error return trace
/// secret parameter, making `@errorReturnTrace()` more useful. This is not
/// necessary if the function already contains a call to an errorable function
/// elsewhere.
pub fn errorReturnTraceHelper() anyerror!void {}

/// Equivalent to `@panic` but with a formatted message.
pub fn panic(comptime format: []const u8, args: anytype) noreturn {
    @branchHint(.cold);
    errorReturnTraceHelper() catch unreachable;
    panicExtra(@errorReturnTrace(), @returnAddress(), format, args);
}

/// Equivalent to `@panic` but with a formatted message, and with an explicitly
/// provided `@errorReturnTrace` and return address.
pub fn panicExtra(
    trace: ?*std.builtin.StackTrace,
    ret_addr: ?usize,
    comptime format: []const u8,
    args: anytype,
) noreturn {
    @branchHint(.cold);

    const size = 0x1000;
    const trunc_msg = "(msg truncated)";
    var buf: [size + trunc_msg.len]u8 = undefined;
    // a minor annoyance with this is that it will result in the NoSpaceLeft
    // error being part of the @panic stack trace (but that error should
    // only happen rarely)
    const msg = std.fmt.bufPrint(buf[0..size], format, args) catch |err| switch (err) {
        error.NoSpaceLeft => blk: {
            @memcpy(buf[size..], trunc_msg);
            break :blk &buf;
        },
    };
    std.builtin.Panic.call(msg, trace, ret_addr);
}

/// Non-zero whenever the program triggered a panic.
/// The counter is incremented/decremented atomically.
var panicking = std.atomic.Value(u8).init(0);

/// Counts how many times the panic handler is invoked by this thread.
/// This is used to catch and handle panics triggered by the panic handler.
threadlocal var panic_stage: usize = 0;

/// Dumps a stack trace to standard error, then aborts.
pub fn defaultPanic(
    msg: []const u8,
    error_return_trace: ?*const std.builtin.StackTrace,
    first_trace_addr: ?usize,
) noreturn {
    @branchHint(.cold);

    // For backends that cannot handle the language features depended on by the
    // default panic handler, we have a simpler panic handler:
    if (builtin.zig_backend == .stage2_wasm or
        builtin.zig_backend == .stage2_arm or
        builtin.zig_backend == .stage2_aarch64 or
        builtin.zig_backend == .stage2_x86 or
        (builtin.zig_backend == .stage2_x86_64 and (builtin.target.ofmt != .elf and builtin.target.ofmt != .macho)) or
        builtin.zig_backend == .stage2_sparc64 or
        builtin.zig_backend == .stage2_spirv64)
    {
        @trap();
    }

    switch (builtin.os.tag) {
        .freestanding => {
            @trap();
        },
        .uefi => {
            const uefi = std.os.uefi;

            var utf16_buffer: [1000]u16 = undefined;
            const len_minus_3 = std.unicode.utf8ToUtf16Le(&utf16_buffer, msg) catch 0;
            utf16_buffer[len_minus_3][0..3].* = .{ '\r', '\n', 0 };
            const len = len_minus_3 + 3;
            const exit_msg = utf16_buffer[0 .. len - 1 :0];

            // Output to both std_err and con_out, as std_err is easier
            // to read in stuff like QEMU at times, but, unlike con_out,
            // isn't visible on actual hardware if directly booted into
            inline for ([_]?*uefi.protocol.SimpleTextOutput{ uefi.system_table.std_err, uefi.system_table.con_out }) |o| {
                if (o) |out| {
                    _ = out.setAttribute(uefi.protocol.SimpleTextOutput.red);
                    _ = out.outputString(exit_msg);
                    _ = out.setAttribute(uefi.protocol.SimpleTextOutput.white);
                }
            }

            if (uefi.system_table.boot_services) |bs| {
                // ExitData buffer must be allocated using boot_services.allocatePool (spec: page 220)
                const exit_data: []u16 = uefi.raw_pool_allocator.alloc(u16, exit_msg.len + 1) catch @trap();
                @memcpy(exit_data, exit_msg[0..exit_data.len]); // Includes null terminator.
                _ = bs.exit(uefi.handle, .Aborted, exit_msg.len + 1, exit_data);
            }
            @trap();
        },
        .cuda, .amdhsa => std.posix.abort(),
        .plan9 => {
            var status: [std.os.plan9.ERRMAX]u8 = undefined;
            const len = @min(msg.len, status.len - 1);
            @memcpy(status[0..len], msg[0..len]);
            status[len] = 0;
            std.os.plan9.exits(status[0..len :0]);
        },
        else => {},
    }

    if (enable_segfault_handler) {
        // If a segfault happens while panicking, we want it to actually segfault, not trigger
        // the handler.
        resetSegfaultHandler();
    }

    // Note there is similar logic in handleSegfaultPosix and handleSegfaultWindowsExtra.
    nosuspend switch (panic_stage) {
        0 => {
            panic_stage = 1;

            _ = panicking.fetchAdd(1, .seq_cst);

            {
                lockStdErr();
                defer unlockStdErr();

                const stderr = io.getStdErr().writer();
                if (builtin.single_threaded) {
                    stderr.print("panic: ", .{}) catch posix.abort();
                } else {
                    const current_thread_id = std.Thread.getCurrentId();
                    stderr.print("thread {} panic: ", .{current_thread_id}) catch posix.abort();
                }
                stderr.print("{s}\n", .{msg}) catch posix.abort();

                if (error_return_trace) |t| dumpStackTrace(t.*);
                dumpCurrentStackTrace(first_trace_addr orelse @returnAddress());
            }

            waitForOtherThreadToFinishPanicking();
        },
        1 => {
            panic_stage = 2;

            // A panic happened while trying to print a previous panic message.
            // We're still holding the mutex but that's fine as we're going to
            // call abort().
            io.getStdErr().writeAll("aborting due to recursive panic\n") catch {};
        },
        else => {}, // Panicked while printing the recursive panic message.
    };

    posix.abort();
}

/// Must be called only after adding 1 to `panicking`. There are three callsites.
fn waitForOtherThreadToFinishPanicking() void {
    if (panicking.fetchSub(1, .seq_cst) != 1) {
        // Another thread is panicking, wait for the last one to finish
        // and call abort()
        if (builtin.single_threaded) unreachable;

        // Sleep forever without hammering the CPU
        var futex = std.atomic.Value(u32).init(0);
        while (true) std.Thread.Futex.wait(&futex, 0);
        unreachable;
    }
}

pub fn writeStackTrace(
    stack_trace: std.builtin.StackTrace,
    out_stream: anytype,
    debug_info: *SelfInfo,
    tty_config: io.tty.Config,
) !void {
    if (builtin.strip_debug_info) return error.MissingDebugInfo;
    var frame_index: usize = 0;
    var frames_left: usize = @min(stack_trace.index, stack_trace.instruction_addresses.len);

    while (frames_left != 0) : ({
        frames_left -= 1;
        frame_index = (frame_index + 1) % stack_trace.instruction_addresses.len;
    }) {
        const return_address = stack_trace.instruction_addresses[frame_index];
        try printSourceAtAddress(debug_info, out_stream, return_address - 1, tty_config);
    }

    if (stack_trace.index > stack_trace.instruction_addresses.len) {
        const dropped_frames = stack_trace.index - stack_trace.instruction_addresses.len;

        tty_config.setColor(out_stream, .bold) catch {};
        try out_stream.print("({d} additional stack frames skipped...)\n", .{dropped_frames});
        tty_config.setColor(out_stream, .reset) catch {};
    }
}

pub const UnwindError = if (have_ucontext)
    @typeInfo(@typeInfo(@TypeOf(StackIterator.next_unwind)).@"fn".return_type.?).error_union.error_set
else
    void;

pub const StackIterator = struct {
    // Skip every frame before this address is found.
    first_address: ?usize,
    // Last known value of the frame pointer register.
    fp: usize,
    ma: MemoryAccessor = MemoryAccessor.init,

    // When SelfInfo and a register context is available, this iterator can unwind
    // stacks with frames that don't use a frame pointer (ie. -fomit-frame-pointer),
    // using DWARF and MachO unwind info.
    unwind_state: if (have_ucontext) ?struct {
        debug_info: *SelfInfo,
        dwarf_context: SelfInfo.UnwindContext,
        last_error: ?UnwindError = null,
        failed: bool = false,
    } else void = if (have_ucontext) null else {},

    pub fn init(first_address: ?usize, fp: ?usize) StackIterator {
        if (native_arch.isSPARC()) {
            // Flush all the register windows on stack.
            asm volatile (if (std.Target.sparc.featureSetHas(builtin.cpu.features, .v9))
                    "flushw"
                else
                    "ta 3" // ST_FLUSH_WINDOWS
                ::: "memory");
        }

        return StackIterator{
            .first_address = first_address,
            // TODO: this is a workaround for #16876
            //.fp = fp orelse @frameAddress(),
            .fp = fp orelse blk: {
                const fa = @frameAddress();
                break :blk fa;
            },
        };
    }

    pub fn initWithContext(first_address: ?usize, debug_info: *SelfInfo, context: *posix.ucontext_t) !StackIterator {
        // The implementation of DWARF unwinding on aarch64-macos is not complete. However, Apple mandates that
        // the frame pointer register is always used, so on this platform we can safely use the FP-based unwinder.
        if (builtin.target.isDarwin() and native_arch == .aarch64)
            return init(first_address, context.mcontext.ss.fp);

        if (SelfInfo.supports_unwinding) {
            var iterator = init(first_address, null);
            iterator.unwind_state = .{
                .debug_info = debug_info,
                .dwarf_context = try SelfInfo.UnwindContext.init(debug_info.allocator, context),
            };
            return iterator;
        }

        return init(first_address, null);
    }

    pub fn deinit(it: *StackIterator) void {
        if (have_ucontext and it.unwind_state != null) it.unwind_state.?.dwarf_context.deinit();
    }

    pub fn getLastError(it: *StackIterator) ?struct {
        err: UnwindError,
        address: usize,
    } {
        if (!have_ucontext) return null;
        if (it.unwind_state) |*unwind_state| {
            if (unwind_state.last_error) |err| {
                unwind_state.last_error = null;
                return .{
                    .err = err,
                    .address = unwind_state.dwarf_context.pc,
                };
            }
        }

        return null;
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

    pub fn next(it: *StackIterator) ?usize {
        var address = it.next_internal() orelse return null;

        if (it.first_address) |first_address| {
            while (address != first_address) {
                address = it.next_internal() orelse return null;
            }
            it.first_address = null;
        }

        return address;
    }

    fn next_unwind(it: *StackIterator) !usize {
        const unwind_state = &it.unwind_state.?;
        const module = try unwind_state.debug_info.getModuleForAddress(unwind_state.dwarf_context.pc);
        switch (native_os) {
            .macos, .ios, .watchos, .tvos, .visionos => {
                // __unwind_info is a requirement for unwinding on Darwin. It may fall back to DWARF, but unwinding
                // via DWARF before attempting to use the compact unwind info will produce incorrect results.
                if (module.unwind_info) |unwind_info| {
                    if (SelfInfo.unwindFrameMachO(
                        &unwind_state.dwarf_context,
                        &it.ma,
                        unwind_info,
                        module.eh_frame,
                        module.base_address,
                    )) |return_address| {
                        return return_address;
                    } else |err| {
                        if (err != error.RequiresDWARFUnwind) return err;
                    }
                } else return error.MissingUnwindInfo;
            },
            else => {},
        }

        if (try module.getDwarfInfoForAddress(unwind_state.debug_info.allocator, unwind_state.dwarf_context.pc)) |di| {
            return SelfInfo.unwindFrameDwarf(di, &unwind_state.dwarf_context, &it.ma, null);
        } else return error.MissingDebugInfo;
    }

    fn next_internal(it: *StackIterator) ?usize {
        if (have_ucontext) {
            if (it.unwind_state) |*unwind_state| {
                if (!unwind_state.failed) {
                    if (unwind_state.dwarf_context.pc == 0) return null;
                    defer it.fp = unwind_state.dwarf_context.getFp() catch 0;
                    if (it.next_unwind()) |return_address| {
                        return return_address;
                    } else |err| {
                        unwind_state.last_error = err;
                        unwind_state.failed = true;

                        // Fall back to fp-based unwinding on the first failure.
                        // We can't attempt it again for other modules higher in the
                        // stack because the full register state won't have been unwound.
                    }
                }
            }
        }

        const fp = if (comptime native_arch.isSPARC())
            // On SPARC the offset is positive. (!)
            math.add(usize, it.fp, fp_offset) catch return null
        else
            math.sub(usize, it.fp, fp_offset) catch return null;

        // Sanity check.
        if (fp == 0 or !mem.isAligned(fp, @alignOf(usize))) return null;
        const new_fp = math.add(usize, it.ma.load(usize, fp) orelse return null, fp_bias) catch
            return null;

        // Sanity check: the stack grows down thus all the parent frames must be
        // be at addresses that are greater (or equal) than the previous one.
        // A zero frame pointer often signals this is the last frame, that case
        // is gracefully handled by the next call to next_internal.
        if (new_fp != 0 and new_fp < it.fp) return null;
        const new_pc = it.ma.load(usize, math.add(usize, fp, pc_offset) catch return null) orelse
            return null;

        it.fp = new_fp;

        return new_pc;
    }
};

pub fn writeCurrentStackTrace(
    out_stream: anytype,
    debug_info: *SelfInfo,
    tty_config: io.tty.Config,
    start_addr: ?usize,
) !void {
    if (native_os == .windows) {
        var context: ThreadContext = undefined;
        assert(getContext(&context));
        return writeStackTraceWindows(out_stream, debug_info, tty_config, &context, start_addr);
    }
    var context: ThreadContext = undefined;
    const has_context = getContext(&context);

    var it = (if (has_context) blk: {
        break :blk StackIterator.initWithContext(start_addr, debug_info, &context) catch null;
    } else null) orelse StackIterator.init(start_addr, null);
    defer it.deinit();

    while (it.next()) |return_address| {
        printLastUnwindError(&it, debug_info, out_stream, tty_config);

        // On arm64 macOS, the address of the last frame is 0x0 rather than 0x1 as on x86_64 macOS,
        // therefore, we do a check for `return_address == 0` before subtracting 1 from it to avoid
        // an overflow. We do not need to signal `StackIterator` as it will correctly detect this
        // condition on the subsequent iteration and return `null` thus terminating the loop.
        // same behaviour for x86-windows-msvc
        const address = return_address -| 1;
        try printSourceAtAddress(debug_info, out_stream, address, tty_config);
    } else printLastUnwindError(&it, debug_info, out_stream, tty_config);
}

pub noinline fn walkStackWindows(addresses: []usize, existing_context: ?*const windows.CONTEXT) usize {
    if (builtin.cpu.arch == .x86) {
        // RtlVirtualUnwind doesn't exist on x86
        return windows.ntdll.RtlCaptureStackBackTrace(0, addresses.len, @as(**anyopaque, @ptrCast(addresses.ptr)), null);
    }

    const tib = &windows.teb().NtTib;

    var context: windows.CONTEXT = undefined;
    if (existing_context) |context_ptr| {
        context = context_ptr.*;
    } else {
        context = std.mem.zeroes(windows.CONTEXT);
        windows.ntdll.RtlCaptureContext(&context);
    }

    var i: usize = 0;
    var image_base: windows.DWORD64 = undefined;
    var history_table: windows.UNWIND_HISTORY_TABLE = std.mem.zeroes(windows.UNWIND_HISTORY_TABLE);

    while (i < addresses.len) : (i += 1) {
        const current_regs = context.getRegs();
        if (windows.ntdll.RtlLookupFunctionEntry(current_regs.ip, &image_base, &history_table)) |runtime_function| {
            var handler_data: ?*anyopaque = null;
            var establisher_frame: u64 = undefined;
            _ = windows.ntdll.RtlVirtualUnwind(
                windows.UNW_FLAG_NHANDLER,
                image_base,
                current_regs.ip,
                runtime_function,
                &context,
                &handler_data,
                &establisher_frame,
                null,
            );
        } else {
            // leaf function
            context.setIp(@as(*usize, @ptrFromInt(current_regs.sp)).*);
            context.setSp(current_regs.sp + @sizeOf(usize));
        }

        const next_regs = context.getRegs();
        if (next_regs.sp < @intFromPtr(tib.StackLimit) or next_regs.sp > @intFromPtr(tib.StackBase)) {
            break;
        }

        if (next_regs.ip == 0) {
            break;
        }

        addresses[i] = next_regs.ip;
    }

    return i;
}

pub fn writeStackTraceWindows(
    out_stream: anytype,
    debug_info: *SelfInfo,
    tty_config: io.tty.Config,
    context: *const windows.CONTEXT,
    start_addr: ?usize,
) !void {
    var addr_buf: [1024]usize = undefined;
    const n = walkStackWindows(addr_buf[0..], context);
    const addrs = addr_buf[0..n];
    const start_i: usize = if (start_addr) |saddr| blk: {
        for (addrs, 0..) |addr, i| {
            if (addr == saddr) break :blk i;
        }
        return;
    } else 0;
    for (addrs[start_i..]) |addr| {
        try printSourceAtAddress(debug_info, out_stream, addr - 1, tty_config);
    }
}

fn printUnknownSource(debug_info: *SelfInfo, out_stream: anytype, address: usize, tty_config: io.tty.Config) !void {
    const module_name = debug_info.getModuleNameForAddress(address);
    return printLineInfo(
        out_stream,
        null,
        address,
        "???",
        module_name orelse "???",
        tty_config,
        printLineFromFileAnyOs,
    );
}

fn printLastUnwindError(it: *StackIterator, debug_info: *SelfInfo, out_stream: anytype, tty_config: io.tty.Config) void {
    if (!have_ucontext) return;
    if (it.getLastError()) |unwind_error| {
        printUnwindError(debug_info, out_stream, unwind_error.address, unwind_error.err, tty_config) catch {};
    }
}

fn printUnwindError(debug_info: *SelfInfo, out_stream: anytype, address: usize, err: UnwindError, tty_config: io.tty.Config) !void {
    const module_name = debug_info.getModuleNameForAddress(address) orelse "???";
    try tty_config.setColor(out_stream, .dim);
    if (err == error.MissingDebugInfo) {
        try out_stream.print("Unwind information for `{s}:0x{x}` was not available, trace may be incomplete\n\n", .{ module_name, address });
    } else {
        try out_stream.print("Unwind error at address `{s}:0x{x}` ({}), trace may be incomplete\n\n", .{ module_name, address, err });
    }
    try tty_config.setColor(out_stream, .reset);
}

pub fn printSourceAtAddress(debug_info: *SelfInfo, out_stream: anytype, address: usize, tty_config: io.tty.Config) !void {
    const module = debug_info.getModuleForAddress(address) catch |err| switch (err) {
        error.MissingDebugInfo, error.InvalidDebugInfo => return printUnknownSource(debug_info, out_stream, address, tty_config),
        else => return err,
    };

    const symbol_info = module.getSymbolAtAddress(debug_info.allocator, address) catch |err| switch (err) {
        error.MissingDebugInfo, error.InvalidDebugInfo => return printUnknownSource(debug_info, out_stream, address, tty_config),
        else => return err,
    };
    defer if (symbol_info.source_location) |sl| debug_info.allocator.free(sl.file_name);

    return printLineInfo(
        out_stream,
        symbol_info.source_location,
        address,
        symbol_info.name,
        symbol_info.compile_unit_name,
        tty_config,
        printLineFromFileAnyOs,
    );
}

fn printLineInfo(
    out_stream: anytype,
    source_location: ?SourceLocation,
    address: usize,
    symbol_name: []const u8,
    compile_unit_name: []const u8,
    tty_config: io.tty.Config,
    comptime printLineFromFile: anytype,
) !void {
    nosuspend {
        try tty_config.setColor(out_stream, .bold);

        if (source_location) |*sl| {
            try out_stream.print("{s}:{d}:{d}", .{ sl.file_name, sl.line, sl.column });
        } else {
            try out_stream.writeAll("???:?:?");
        }

        try tty_config.setColor(out_stream, .reset);
        try out_stream.writeAll(": ");
        try tty_config.setColor(out_stream, .dim);
        try out_stream.print("0x{x} in {s} ({s})", .{ address, symbol_name, compile_unit_name });
        try tty_config.setColor(out_stream, .reset);
        try out_stream.writeAll("\n");

        // Show the matching source code line if possible
        if (source_location) |sl| {
            if (printLineFromFile(out_stream, sl)) {
                if (sl.column > 0) {
                    // The caret already takes one char
                    const space_needed = @as(usize, @intCast(sl.column - 1));

                    try out_stream.writeByteNTimes(' ', space_needed);
                    try tty_config.setColor(out_stream, .green);
                    try out_stream.writeAll("^");
                    try tty_config.setColor(out_stream, .reset);
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

fn printLineFromFileAnyOs(out_stream: anytype, source_location: SourceLocation) !void {
    // Need this to always block even in async I/O mode, because this could potentially
    // be called from e.g. the event loop code crashing.
    var f = try fs.cwd().openFile(source_location.file_name, .{});
    defer f.close();
    // TODO fstat and make sure that the file has the correct size

    var buf: [mem.page_size]u8 = undefined;
    var amt_read = try f.read(buf[0..]);
    const line_start = seek: {
        var current_line_start: usize = 0;
        var next_line: usize = 1;
        while (next_line != source_location.line) {
            const slice = buf[current_line_start..amt_read];
            if (mem.indexOfScalar(u8, slice, '\n')) |pos| {
                next_line += 1;
                if (pos == slice.len - 1) {
                    amt_read = try f.read(buf[0..]);
                    current_line_start = 0;
                } else current_line_start += pos + 1;
            } else if (amt_read < buf.len) {
                return error.EndOfFile;
            } else {
                amt_read = try f.read(buf[0..]);
                current_line_start = 0;
            }
        }
        break :seek current_line_start;
    };
    const slice = buf[line_start..amt_read];
    if (mem.indexOfScalar(u8, slice, '\n')) |pos| {
        const line = slice[0 .. pos + 1];
        mem.replaceScalar(u8, line, '\t', ' ');
        return out_stream.writeAll(line);
    } else { // Line is the last inside the buffer, and requires another read to find delimiter. Alternatively the file ends.
        mem.replaceScalar(u8, slice, '\t', ' ');
        try out_stream.writeAll(slice);
        while (amt_read == buf.len) {
            amt_read = try f.read(buf[0..]);
            if (mem.indexOfScalar(u8, buf[0..amt_read], '\n')) |pos| {
                const line = buf[0 .. pos + 1];
                mem.replaceScalar(u8, line, '\t', ' ');
                return out_stream.writeAll(line);
            } else {
                const line = buf[0..amt_read];
                mem.replaceScalar(u8, line, '\t', ' ');
                try out_stream.writeAll(line);
            }
        }
        // Make sure printing last line of file inserts extra newline
        try out_stream.writeByte('\n');
    }
}

test printLineFromFileAnyOs {
    var output = std.ArrayList(u8).init(std.testing.allocator);
    defer output.deinit();
    const output_stream = output.writer();

    const allocator = std.testing.allocator;
    const join = std.fs.path.join;
    const expectError = std.testing.expectError;
    const expectEqualStrings = std.testing.expectEqualStrings;

    var test_dir = std.testing.tmpDir(.{});
    defer test_dir.cleanup();
    // Relies on testing.tmpDir internals which is not ideal, but SourceLocation requires paths.
    const test_dir_path = try join(allocator, &.{ ".zig-cache", "tmp", test_dir.sub_path[0..] });
    defer allocator.free(test_dir_path);

    // Cases
    {
        const path = try join(allocator, &.{ test_dir_path, "one_line.zig" });
        defer allocator.free(path);
        try test_dir.dir.writeFile(.{ .sub_path = "one_line.zig", .data = "no new lines in this file, but one is printed anyway" });

        try expectError(error.EndOfFile, printLineFromFileAnyOs(output_stream, .{ .file_name = path, .line = 2, .column = 0 }));

        try printLineFromFileAnyOs(output_stream, .{ .file_name = path, .line = 1, .column = 0 });
        try expectEqualStrings("no new lines in this file, but one is printed anyway\n", output.items);
        output.clearRetainingCapacity();
    }
    {
        const path = try fs.path.join(allocator, &.{ test_dir_path, "three_lines.zig" });
        defer allocator.free(path);
        try test_dir.dir.writeFile(.{
            .sub_path = "three_lines.zig",
            .data =
            \\1
            \\2
            \\3
            ,
        });

        try printLineFromFileAnyOs(output_stream, .{ .file_name = path, .line = 1, .column = 0 });
        try expectEqualStrings("1\n", output.items);
        output.clearRetainingCapacity();

        try printLineFromFileAnyOs(output_stream, .{ .file_name = path, .line = 3, .column = 0 });
        try expectEqualStrings("3\n", output.items);
        output.clearRetainingCapacity();
    }
    {
        const file = try test_dir.dir.createFile("line_overlaps_page_boundary.zig", .{});
        defer file.close();
        const path = try fs.path.join(allocator, &.{ test_dir_path, "line_overlaps_page_boundary.zig" });
        defer allocator.free(path);

        const overlap = 10;
        var writer = file.writer();
        try writer.writeByteNTimes('a', mem.page_size - overlap);
        try writer.writeByte('\n');
        try writer.writeByteNTimes('a', overlap);

        try printLineFromFileAnyOs(output_stream, .{ .file_name = path, .line = 2, .column = 0 });
        try expectEqualStrings(("a" ** overlap) ++ "\n", output.items);
        output.clearRetainingCapacity();
    }
    {
        const file = try test_dir.dir.createFile("file_ends_on_page_boundary.zig", .{});
        defer file.close();
        const path = try fs.path.join(allocator, &.{ test_dir_path, "file_ends_on_page_boundary.zig" });
        defer allocator.free(path);

        var writer = file.writer();
        try writer.writeByteNTimes('a', mem.page_size);

        try printLineFromFileAnyOs(output_stream, .{ .file_name = path, .line = 1, .column = 0 });
        try expectEqualStrings(("a" ** mem.page_size) ++ "\n", output.items);
        output.clearRetainingCapacity();
    }
    {
        const file = try test_dir.dir.createFile("very_long_first_line_spanning_multiple_pages.zig", .{});
        defer file.close();
        const path = try fs.path.join(allocator, &.{ test_dir_path, "very_long_first_line_spanning_multiple_pages.zig" });
        defer allocator.free(path);

        var writer = file.writer();
        try writer.writeByteNTimes('a', 3 * mem.page_size);

        try expectError(error.EndOfFile, printLineFromFileAnyOs(output_stream, .{ .file_name = path, .line = 2, .column = 0 }));

        try printLineFromFileAnyOs(output_stream, .{ .file_name = path, .line = 1, .column = 0 });
        try expectEqualStrings(("a" ** (3 * mem.page_size)) ++ "\n", output.items);
        output.clearRetainingCapacity();

        try writer.writeAll("a\na");

        try printLineFromFileAnyOs(output_stream, .{ .file_name = path, .line = 1, .column = 0 });
        try expectEqualStrings(("a" ** (3 * mem.page_size)) ++ "a\n", output.items);
        output.clearRetainingCapacity();

        try printLineFromFileAnyOs(output_stream, .{ .file_name = path, .line = 2, .column = 0 });
        try expectEqualStrings("a\n", output.items);
        output.clearRetainingCapacity();
    }
    {
        const file = try test_dir.dir.createFile("file_of_newlines.zig", .{});
        defer file.close();
        const path = try fs.path.join(allocator, &.{ test_dir_path, "file_of_newlines.zig" });
        defer allocator.free(path);

        var writer = file.writer();
        const real_file_start = 3 * mem.page_size;
        try writer.writeByteNTimes('\n', real_file_start);
        try writer.writeAll("abc\ndef");

        try printLineFromFileAnyOs(output_stream, .{ .file_name = path, .line = real_file_start + 1, .column = 0 });
        try expectEqualStrings("abc\n", output.items);
        output.clearRetainingCapacity();

        try printLineFromFileAnyOs(output_stream, .{ .file_name = path, .line = real_file_start + 2, .column = 0 });
        try expectEqualStrings("def\n", output.items);
        output.clearRetainingCapacity();
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
    .illumos,
    .windows,
    => true,

    .freebsd, .openbsd => have_ucontext,
    else => false,
};

const enable_segfault_handler = std.options.enable_segfault_handler;
pub const default_enable_segfault_handler = runtime_safety and have_segfault_handling_support;

pub fn maybeEnableSegfaultHandler() void {
    if (enable_segfault_handler) {
        attachSegfaultHandler();
    }
}

var windows_segfault_handle: ?windows.HANDLE = null;

pub fn updateSegfaultHandler(act: ?*const posix.Sigaction) void {
    posix.sigaction(posix.SIG.SEGV, act, null);
    posix.sigaction(posix.SIG.ILL, act, null);
    posix.sigaction(posix.SIG.BUS, act, null);
    posix.sigaction(posix.SIG.FPE, act, null);
}

/// Attaches a global SIGSEGV handler which calls `@panic("segmentation fault");`
pub fn attachSegfaultHandler() void {
    if (!have_segfault_handling_support) {
        @compileError("segfault handler not supported for this target");
    }
    if (native_os == .windows) {
        windows_segfault_handle = windows.kernel32.AddVectoredExceptionHandler(0, handleSegfaultWindows);
        return;
    }
    var act = posix.Sigaction{
        .handler = .{ .sigaction = handleSegfaultPosix },
        .mask = posix.empty_sigset,
        .flags = (posix.SA.SIGINFO | posix.SA.RESTART | posix.SA.RESETHAND),
    };

    updateSegfaultHandler(&act);
}

fn resetSegfaultHandler() void {
    if (native_os == .windows) {
        if (windows_segfault_handle) |handle| {
            assert(windows.kernel32.RemoveVectoredExceptionHandler(handle) != 0);
            windows_segfault_handle = null;
        }
        return;
    }
    var act = posix.Sigaction{
        .handler = .{ .handler = posix.SIG.DFL },
        .mask = posix.empty_sigset,
        .flags = 0,
    };
    updateSegfaultHandler(&act);
}

fn handleSegfaultPosix(sig: i32, info: *const posix.siginfo_t, ctx_ptr: ?*anyopaque) callconv(.C) noreturn {
    // Reset to the default handler so that if a segfault happens in this handler it will crash
    // the process. Also when this handler returns, the original instruction will be repeated
    // and the resulting segfault will crash the process rather than continually dump stack traces.
    resetSegfaultHandler();

    const addr = switch (native_os) {
        .linux => @intFromPtr(info.fields.sigfault.addr),
        .freebsd, .macos => @intFromPtr(info.addr),
        .netbsd => @intFromPtr(info.info.reason.fault.addr),
        .openbsd => @intFromPtr(info.data.fault.addr),
        .solaris, .illumos => @intFromPtr(info.reason.fault.addr),
        else => unreachable,
    };

    const code = if (native_os == .netbsd) info.info.code else info.code;
    nosuspend switch (panic_stage) {
        0 => {
            panic_stage = 1;
            _ = panicking.fetchAdd(1, .seq_cst);

            {
                lockStdErr();
                defer unlockStdErr();

                dumpSegfaultInfoPosix(sig, code, addr, ctx_ptr);
            }

            waitForOtherThreadToFinishPanicking();
        },
        else => {
            // panic mutex already locked
            dumpSegfaultInfoPosix(sig, code, addr, ctx_ptr);
        },
    };

    // We cannot allow the signal handler to return because when it runs the original instruction
    // again, the memory may be mapped and undefined behavior would occur rather than repeating
    // the segfault. So we simply abort here.
    posix.abort();
}

fn dumpSegfaultInfoPosix(sig: i32, code: i32, addr: usize, ctx_ptr: ?*anyopaque) void {
    const stderr = io.getStdErr().writer();
    _ = switch (sig) {
        posix.SIG.SEGV => if (native_arch == .x86_64 and native_os == .linux and code == 128) // SI_KERNEL
            // x86_64 doesn't have a full 64-bit virtual address space.
            // Addresses outside of that address space are non-canonical
            // and the CPU won't provide the faulting address to us.
            // This happens when accessing memory addresses such as 0xaaaaaaaaaaaaaaaa
            // but can also happen when no addressable memory is involved;
            // for example when reading/writing model-specific registers
            // by executing `rdmsr` or `wrmsr` in user-space (unprivileged mode).
            stderr.print("General protection exception (no address available)\n", .{})
        else
            stderr.print("Segmentation fault at address 0x{x}\n", .{addr}),
        posix.SIG.ILL => stderr.print("Illegal instruction at address 0x{x}\n", .{addr}),
        posix.SIG.BUS => stderr.print("Bus error at address 0x{x}\n", .{addr}),
        posix.SIG.FPE => stderr.print("Arithmetic exception at address 0x{x}\n", .{addr}),
        else => unreachable,
    } catch posix.abort();

    switch (native_arch) {
        .x86,
        .x86_64,
        .arm,
        .aarch64,
        => {
            const ctx: *posix.ucontext_t = @ptrCast(@alignCast(ctx_ptr));
            dumpStackTraceFromBase(ctx);
        },
        else => {},
    }
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

fn handleSegfaultWindowsExtra(info: *windows.EXCEPTION_POINTERS, msg: u8, label: ?[]const u8) noreturn {
    comptime assert(windows.CONTEXT != void);
    nosuspend switch (panic_stage) {
        0 => {
            panic_stage = 1;
            _ = panicking.fetchAdd(1, .seq_cst);

            {
                lockStdErr();
                defer unlockStdErr();

                dumpSegfaultInfoWindows(info, msg, label);
            }

            waitForOtherThreadToFinishPanicking();
        },
        1 => {
            panic_stage = 2;
            io.getStdErr().writeAll("aborting due to recursive panic\n") catch {};
        },
        else => {},
    };
    posix.abort();
}

fn dumpSegfaultInfoWindows(info: *windows.EXCEPTION_POINTERS, msg: u8, label: ?[]const u8) void {
    const stderr = io.getStdErr().writer();
    _ = switch (msg) {
        0 => stderr.print("{s}\n", .{label.?}),
        1 => stderr.print("Segmentation fault at address 0x{x}\n", .{info.ExceptionRecord.ExceptionInformation[1]}),
        2 => stderr.print("Illegal instruction at address 0x{x}\n", .{info.ContextRecord.getRegs().ip}),
        else => unreachable,
    } catch posix.abort();

    dumpStackTraceFromBase(info.ContextRecord);
}

pub fn dumpStackPointerAddr(prefix: []const u8) void {
    const sp = asm (""
        : [argc] "={rsp}" (-> usize),
    );
    print("{s} sp = 0x{x}\n", .{ prefix, sp });
}

test "manage resources correctly" {
    if (builtin.strip_debug_info) return error.SkipZigTest;

    if (native_os == .wasi) return error.SkipZigTest;

    if (native_os == .windows) {
        // https://github.com/ziglang/zig/issues/13963
        return error.SkipZigTest;
    }

    // self-hosted debug info is still too buggy
    if (builtin.zig_backend != .stage2_llvm) return error.SkipZigTest;

    const writer = std.io.null_writer;
    var di = try SelfInfo.open(testing.allocator);
    defer di.deinit();
    try printSourceAtAddress(&di, writer, showMyTrace(), io.tty.detectConfig(std.io.getStdErr()));
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
        addrs: [actual_size][stack_frame_count]usize,
        notes: [actual_size][]const u8,
        index: Index,

        const actual_size = if (enabled) size else 0;
        const Index = if (enabled) usize else u0;

        pub const init: @This() = .{
            .addrs = undefined,
            .notes = undefined,
            .index = 0,
        };

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

            const tty_config = io.tty.detectConfig(std.io.getStdErr());
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
                writeStackTrace(stack_trace, stderr, debug_info, tty_config) catch continue;
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

pub const SafetyLock = struct {
    state: State = .unlocked,

    pub const State = if (runtime_safety) enum { unlocked, locked } else enum { unlocked };

    pub fn lock(l: *SafetyLock) void {
        if (!runtime_safety) return;
        assert(l.state == .unlocked);
        l.state = .locked;
    }

    pub fn unlock(l: *SafetyLock) void {
        if (!runtime_safety) return;
        assert(l.state == .locked);
        l.state = .unlocked;
    }

    pub fn assertUnlocked(l: SafetyLock) void {
        if (!runtime_safety) return;
        assert(l.state == .unlocked);
    }
};

/// Detect whether the program is being executed in the Valgrind virtual machine.
///
/// When Valgrind integrations are disabled, this returns comptime-known false.
/// Otherwise, the result is runtime-known.
pub inline fn inValgrind() bool {
    if (@inComptime()) return false;
    if (!builtin.valgrind_support) return false;
    return std.valgrind.runningOnValgrind() > 0;
}

test {
    _ = &Dwarf;
    _ = &MemoryAccessor;
    _ = &FixedBufferReader;
    _ = &Pdb;
    _ = &SelfInfo;
    _ = &dumpHex;
}
