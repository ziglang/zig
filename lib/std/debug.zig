const std = @import("std.zig");
const math = std.math;
const mem = std.mem;
const posix = std.posix;
const fs = std.fs;
const testing = std.testing;
const Allocator = mem.Allocator;
const File = std.fs.File;
const windows = std.os.windows;
const Writer = std.Io.Writer;
const tty = std.Io.tty;

const builtin = @import("builtin");
const native_arch = builtin.cpu.arch;
const native_os = builtin.os.tag;

const root = @import("root");

pub const Dwarf = @import("debug/Dwarf.zig");
pub const Pdb = @import("debug/Pdb.zig");
pub const ElfFile = @import("debug/ElfFile.zig");
pub const Info = @import("debug/Info.zig");
pub const Coverage = @import("debug/Coverage.zig");
pub const cpu_context = @import("debug/cpu_context.zig");

/// This type abstracts the target-specific implementation of accessing this process' own debug
/// information behind a generic interface which supports looking up source locations associated
/// with addresses, as well as unwinding the stack where a safe mechanism to do so exists.
///
/// The Zig Standard Library provides default implementations of `SelfInfo` for common targets, but
/// the implementation can be overriden by exposing `root.debug.SelfInfo`. Setting `SelfInfo` to
/// `void` indicates that the `SelfInfo` API is not supported.
///
/// This type must expose the following declarations:
///
/// ```
/// pub const init: SelfInfo;
/// pub fn deinit(si: *SelfInfo, gpa: Allocator) void;
///
/// /// Returns the symbol and source location of the instruction at `address`.
/// pub fn getSymbol(si: *SelfInfo, gpa: Allocator, address: usize) SelfInfoError!Symbol;
/// /// Returns a name for the "module" (e.g. shared library or executable image) containing `address`.
/// pub fn getModuleName(si: *SelfInfo, gpa: Allocator, address: usize) SelfInfoError![]const u8;
///
/// /// Whether a reliable stack unwinding strategy, such as DWARF unwinding, is available.
/// pub const can_unwind: bool;
/// /// Only required if `can_unwind == true`.
/// pub const UnwindContext = struct {
///     /// An address representing the instruction pointer in the last frame.
///     pc: usize,
///
///     pub fn init(ctx: *cpu_context.Native, gpa: Allocator) Allocator.Error!UnwindContext;
///     pub fn deinit(ctx: *UnwindContext, gpa: Allocator) void;
///     /// Returns the frame pointer associated with the last unwound stack frame.
///     /// If the frame pointer is unknown, 0 may be returned instead.
///     pub fn getFp(uc: *UnwindContext) usize;
/// };
/// /// Only required if `can_unwind == true`. Unwinds a single stack frame, returning the frame's
/// /// return address, or 0 if the end of the stack has been reached.
/// pub fn unwindFrame(si: *SelfInfo, gpa: Allocator, context: *UnwindContext) SelfInfoError!usize;
/// ```
pub const SelfInfo = if (@hasDecl(root, "debug") and @hasDecl(root.debug, "SelfInfo"))
    root.debug.SelfInfo
else switch (std.Target.ObjectFormat.default(native_os, native_arch)) {
    .coff => if (native_os == .windows) @import("debug/SelfInfo/Windows.zig") else void,
    .elf => switch (native_os) {
        .freestanding, .other => void,
        else => @import("debug/SelfInfo/Elf.zig"),
    },
    .macho => @import("debug/SelfInfo/MachO.zig"),
    .goff, .plan9, .spirv, .wasm, .xcoff => void,
    .c, .hex, .raw => unreachable,
};

pub const SelfInfoError = error{
    /// The required debug info is invalid or corrupted.
    InvalidDebugInfo,
    /// The required debug info could not be found.
    MissingDebugInfo,
    /// The required debug info was found, and may be valid, but is not supported by this implementation.
    UnsupportedDebugInfo,
    /// The required debug info could not be read from disk due to some IO error.
    ReadFailed,
    OutOfMemory,
    Unexpected,
};

pub const simple_panic = @import("debug/simple_panic.zig");
pub const no_panic = @import("debug/no_panic.zig");

/// A fully-featured panic handler namespace which lowers all panics to calls to `panicFn`.
/// Safety panics will use formatted printing to provide a meaningful error message.
/// The signature of `panicFn` should match that of `defaultPanic`.
pub fn FullPanic(comptime panicFn: fn ([]const u8, ?usize) noreturn) type {
    return struct {
        pub const call = panicFn;
        pub fn sentinelMismatch(expected: anytype, found: @TypeOf(expected)) noreturn {
            @branchHint(.cold);
            std.debug.panicExtra(@returnAddress(), "sentinel mismatch: expected {any}, found {any}", .{
                expected, found,
            });
        }
        pub fn unwrapError(err: anyerror) noreturn {
            @branchHint(.cold);
            std.debug.panicExtra(@returnAddress(), "attempt to unwrap error: {s}", .{@errorName(err)});
        }
        pub fn outOfBounds(index: usize, len: usize) noreturn {
            @branchHint(.cold);
            std.debug.panicExtra(@returnAddress(), "index out of bounds: index {d}, len {d}", .{ index, len });
        }
        pub fn startGreaterThanEnd(start: usize, end: usize) noreturn {
            @branchHint(.cold);
            std.debug.panicExtra(@returnAddress(), "start index {d} is larger than end index {d}", .{ start, end });
        }
        pub fn inactiveUnionField(active: anytype, accessed: @TypeOf(active)) noreturn {
            @branchHint(.cold);
            std.debug.panicExtra(@returnAddress(), "access of union field '{s}' while field '{s}' is active", .{
                @tagName(accessed), @tagName(active),
            });
        }
        pub fn sliceCastLenRemainder(src_len: usize) noreturn {
            @branchHint(.cold);
            std.debug.panicExtra(@returnAddress(), "slice length '{d}' does not divide exactly into destination elements", .{src_len});
        }
        pub fn reachedUnreachable() noreturn {
            @branchHint(.cold);
            call("reached unreachable code", @returnAddress());
        }
        pub fn unwrapNull() noreturn {
            @branchHint(.cold);
            call("attempt to use null value", @returnAddress());
        }
        pub fn castToNull() noreturn {
            @branchHint(.cold);
            call("cast causes pointer to be null", @returnAddress());
        }
        pub fn incorrectAlignment() noreturn {
            @branchHint(.cold);
            call("incorrect alignment", @returnAddress());
        }
        pub fn invalidErrorCode() noreturn {
            @branchHint(.cold);
            call("invalid error code", @returnAddress());
        }
        pub fn integerOutOfBounds() noreturn {
            @branchHint(.cold);
            call("integer does not fit in destination type", @returnAddress());
        }
        pub fn integerOverflow() noreturn {
            @branchHint(.cold);
            call("integer overflow", @returnAddress());
        }
        pub fn shlOverflow() noreturn {
            @branchHint(.cold);
            call("left shift overflowed bits", @returnAddress());
        }
        pub fn shrOverflow() noreturn {
            @branchHint(.cold);
            call("right shift overflowed bits", @returnAddress());
        }
        pub fn divideByZero() noreturn {
            @branchHint(.cold);
            call("division by zero", @returnAddress());
        }
        pub fn exactDivisionRemainder() noreturn {
            @branchHint(.cold);
            call("exact division produced remainder", @returnAddress());
        }
        pub fn integerPartOutOfBounds() noreturn {
            @branchHint(.cold);
            call("integer part of floating point value out of bounds", @returnAddress());
        }
        pub fn corruptSwitch() noreturn {
            @branchHint(.cold);
            call("switch on corrupt value", @returnAddress());
        }
        pub fn shiftRhsTooBig() noreturn {
            @branchHint(.cold);
            call("shift amount is greater than the type size", @returnAddress());
        }
        pub fn invalidEnumValue() noreturn {
            @branchHint(.cold);
            call("invalid enum value", @returnAddress());
        }
        pub fn forLenMismatch() noreturn {
            @branchHint(.cold);
            call("for loop over objects with non-equal lengths", @returnAddress());
        }
        pub fn copyLenMismatch() noreturn {
            @branchHint(.cold);
            call("source and destination arguments have non-equal lengths", @returnAddress());
        }
        pub fn memcpyAlias() noreturn {
            @branchHint(.cold);
            call("@memcpy arguments alias", @returnAddress());
        }
        pub fn noreturnReturned() noreturn {
            @branchHint(.cold);
            call("'noreturn' function returned", @returnAddress());
        }
    };
}

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
    name: ?[]const u8,
    compile_unit_name: ?[]const u8,
    source_location: ?SourceLocation,
    pub const unknown: Symbol = .{
        .name = null,
        .compile_unit_name = null,
        .source_location = null,
    };
};

/// Deprecated because it returns the optimization mode of the standard
/// library, when the caller probably wants to use the optimization mode of
/// their own module.
pub const runtime_safety = switch (builtin.mode) {
    .Debug, .ReleaseSafe => true,
    .ReleaseFast, .ReleaseSmall => false,
};

/// Whether we can unwind the stack on this target, allowing capturing and/or printing the current
/// stack trace. It is still legal to call `captureCurrentStackTrace`, `writeCurrentStackTrace`, and
/// `dumpCurrentStackTrace` if this is `false`; it will just print an error / capture an empty
/// trace due to missing functionality. This value is just intended as a heuristic to avoid
/// pointless work e.g. capturing always-empty stack traces.
pub const sys_can_stack_trace = switch (builtin.cpu.arch) {
    // `@returnAddress()` in LLVM 10 gives
    // "Non-Emscripten WebAssembly hasn't implemented __builtin_return_address".
    // On Emscripten, Zig only supports `@returnAddress()` in debug builds
    // because Emscripten's implementation is very slow.
    .wasm32,
    .wasm64,
    => native_os == .emscripten and builtin.mode == .Debug,

    // `@returnAddress()` is unsupported in LLVM 21.
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

/// Allows the caller to freely write to stderr until `unlockStdErr` is called.
///
/// During the lock, any `std.Progress` information is cleared from the terminal.
///
/// The lock is recursive, so it is valid for the same thread to call `lockStderrWriter` multiple
/// times. The primary motivation is that this allows the panic handler to safely dump the stack
/// trace and panic message even if the mutex was held at the panic site.
///
/// The returned `Writer` does not need to be manually flushed: flushing is performed automatically
/// when the matching `unlockStderrWriter` call occurs.
pub fn lockStderrWriter(buffer: []u8) *Writer {
    return std.Progress.lockStderrWriter(buffer);
}

pub fn unlockStderrWriter() void {
    std.Progress.unlockStderrWriter();
}

/// Print to stderr, silently returning on failure. Intended for use in "printf
/// debugging". Use `std.log` functions for proper logging.
///
/// Uses a 64-byte buffer for formatted printing which is flushed before this
/// function returns.
pub fn print(comptime fmt: []const u8, args: anytype) void {
    var buffer: [64]u8 = undefined;
    const bw = lockStderrWriter(&buffer);
    defer unlockStderrWriter();
    nosuspend bw.print(fmt, args) catch return;
}

/// Marked `inline` to propagate a comptime-known error to callers.
pub inline fn getSelfDebugInfo() !*SelfInfo {
    if (SelfInfo == void) return error.UnsupportedTarget;
    const S = struct {
        var self_info: SelfInfo = .init;
    };
    return &S.self_info;
}

/// Tries to print a hexadecimal view of the bytes, unbuffered, and ignores any error returned.
/// Obtains the stderr mutex while dumping.
pub fn dumpHex(bytes: []const u8) void {
    const bw = lockStderrWriter(&.{});
    defer unlockStderrWriter();
    const ttyconf = tty.detectConfig(.stderr());
    dumpHexFallible(bw, ttyconf, bytes) catch {};
}

/// Prints a hexadecimal view of the bytes, returning any error that occurs.
pub fn dumpHexFallible(bw: *Writer, ttyconf: tty.Config, bytes: []const u8) !void {
    var chunks = mem.window(u8, bytes, 16, 16);
    while (chunks.next()) |window| {
        // 1. Print the address.
        const address = (@intFromPtr(bytes.ptr) + 0x10 * (std.math.divCeil(usize, chunks.index orelse bytes.len, 16) catch unreachable)) - 0x10;
        try ttyconf.setColor(bw, .dim);
        // We print the address in lowercase and the bytes in uppercase hexadecimal to distinguish them more.
        // Also, make sure all lines are aligned by padding the address.
        try bw.print("{x:0>[1]}  ", .{ address, @sizeOf(usize) * 2 });
        try ttyconf.setColor(bw, .reset);

        // 2. Print the bytes.
        for (window, 0..) |byte, index| {
            try bw.print("{X:0>2} ", .{byte});
            if (index == 7) try bw.writeByte(' ');
        }
        try bw.writeByte(' ');
        if (window.len < 16) {
            var missing_columns = (16 - window.len) * 3;
            if (window.len < 8) missing_columns += 1;
            try bw.splatByteAll(' ', missing_columns);
        }

        // 3. Print the characters.
        for (window) |byte| {
            if (std.ascii.isPrint(byte)) {
                try bw.writeByte(byte);
            } else {
                // Related: https://github.com/ziglang/zig/issues/7600
                if (ttyconf == .windows_api) {
                    try bw.writeByte('.');
                    continue;
                }

                // Let's print some common control codes as graphical Unicode symbols.
                // We don't want to do this for all control codes because most control codes apart from
                // the ones that Zig has escape sequences for are likely not very useful to print as symbols.
                switch (byte) {
                    '\n' => try bw.writeAll("␊"),
                    '\r' => try bw.writeAll("␍"),
                    '\t' => try bw.writeAll("␉"),
                    else => try bw.writeByte('.'),
                }
            }
        }
        try bw.writeByte('\n');
    }
}

test dumpHexFallible {
    const bytes: []const u8 = &.{ 0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99, 0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff, 0x01, 0x12, 0x13 };
    var aw: Writer.Allocating = .init(std.testing.allocator);
    defer aw.deinit();

    try dumpHexFallible(&aw.writer, .no_color, bytes);
    const expected = try std.fmt.allocPrint(std.testing.allocator,
        \\{x:0>[2]}  00 11 22 33 44 55 66 77  88 99 AA BB CC DD EE FF  .."3DUfw........
        \\{x:0>[2]}  01 12 13                                          ...
        \\
    , .{
        @intFromPtr(bytes.ptr),
        @intFromPtr(bytes.ptr) + 16,
        @sizeOf(usize) * 2,
    });
    defer std.testing.allocator.free(expected);
    try std.testing.expectEqualStrings(expected, aw.written());
}

/// The pointer through which a `cpu_context.Native` is received from callers of stack tracing logic.
pub const CpuContextPtr = if (cpu_context.Native == noreturn) noreturn else *const cpu_context.Native;

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

/// Invokes detectable illegal behavior when the provided array is not aligned
/// to the provided amount.
pub fn assertAligned(ptr: anytype, comptime alignment: std.mem.Alignment) void {
    const aligned_ptr: *align(alignment.toByteUnits()) const anyopaque = @ptrCast(@alignCast(ptr));
    _ = aligned_ptr;
}

/// Equivalent to `@panic` but with a formatted message.
pub fn panic(comptime format: []const u8, args: anytype) noreturn {
    @branchHint(.cold);
    panicExtra(@returnAddress(), format, args);
}

/// Equivalent to `@panic` but with a formatted message and an explicitly provided return address
/// which will be the first address in the stack trace.
pub fn panicExtra(
    ret_addr: ?usize,
    comptime format: []const u8,
    args: anytype,
) noreturn {
    @branchHint(.cold);

    const size = 0x1000;
    const trunc_msg = "(msg truncated)";
    var buf: [size + trunc_msg.len]u8 = undefined;
    var bw: Writer = .fixed(buf[0..size]);
    // a minor annoyance with this is that it will result in the NoSpaceLeft
    // error being part of the @panic stack trace (but that error should
    // only happen rarely)
    const msg = if (bw.print(format, args)) |_| bw.buffered() else |_| blk: {
        @memcpy(buf[size..], trunc_msg);
        break :blk &buf;
    };
    std.builtin.panic.call(msg, ret_addr);
}

/// Non-zero whenever the program triggered a panic.
/// The counter is incremented/decremented atomically.
var panicking = std.atomic.Value(u8).init(0);

/// Counts how many times the panic handler is invoked by this thread.
/// This is used to catch and handle panics triggered by the panic handler.
threadlocal var panic_stage: usize = 0;

/// For backends that cannot handle the language features depended on by the
/// default panic handler, we will use a simpler implementation.
const use_trap_panic = switch (builtin.zig_backend) {
    .stage2_aarch64,
    .stage2_arm,
    .stage2_powerpc,
    .stage2_riscv64,
    .stage2_spirv,
    .stage2_wasm,
    .stage2_x86,
    => true,
    else => false,
};

/// Dumps a stack trace to standard error, then aborts.
pub fn defaultPanic(
    msg: []const u8,
    first_trace_addr: ?usize,
) noreturn {
    @branchHint(.cold);

    if (use_trap_panic) @trap();

    switch (builtin.os.tag) {
        .freestanding, .other => {
            @trap();
        },
        .uefi => {
            const uefi = std.os.uefi;

            var utf16_buffer: [1000]u16 = undefined;
            const len_minus_3 = std.unicode.utf8ToUtf16Le(&utf16_buffer, msg) catch 0;
            utf16_buffer[len_minus_3..][0..3].* = .{ '\r', '\n', 0 };
            const len = len_minus_3 + 3;
            const exit_msg = utf16_buffer[0 .. len - 1 :0];

            // Output to both std_err and con_out, as std_err is easier
            // to read in stuff like QEMU at times, but, unlike con_out,
            // isn't visible on actual hardware if directly booted into
            inline for ([_]?*uefi.protocol.SimpleTextOutput{ uefi.system_table.std_err, uefi.system_table.con_out }) |o| {
                if (o) |out| {
                    out.setAttribute(.{ .foreground = .red }) catch {};
                    _ = out.outputString(exit_msg) catch {};
                    out.setAttribute(.{ .foreground = .white }) catch {};
                }
            }

            if (uefi.system_table.boot_services) |bs| {
                // ExitData buffer must be allocated using boot_services.allocatePool (spec: page 220)
                const exit_data = uefi.raw_pool_allocator.dupeZ(u16, exit_msg) catch @trap();
                bs.exit(uefi.handle, .aborted, exit_data) catch {};
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

    // There is very similar logic to the following in `handleSegfault`.
    switch (panic_stage) {
        0 => {
            panic_stage = 1;
            _ = panicking.fetchAdd(1, .seq_cst);

            trace: {
                const tty_config = tty.detectConfig(.stderr());

                const stderr = lockStderrWriter(&.{});
                defer unlockStderrWriter();

                if (builtin.single_threaded) {
                    stderr.print("panic: ", .{}) catch break :trace;
                } else {
                    const current_thread_id = std.Thread.getCurrentId();
                    stderr.print("thread {} panic: ", .{current_thread_id}) catch break :trace;
                }
                stderr.print("{s}\n", .{msg}) catch break :trace;

                if (@errorReturnTrace()) |t| if (t.index > 0) {
                    stderr.writeAll("error return context:\n") catch break :trace;
                    writeStackTrace(t, stderr, tty_config) catch break :trace;
                    stderr.writeAll("\nstack trace:\n") catch break :trace;
                };
                writeCurrentStackTrace(.{
                    .first_address = first_trace_addr orelse @returnAddress(),
                    .allow_unsafe_unwind = true, // we're crashing anyway, give it our all!
                }, stderr, tty_config) catch break :trace;
            }

            waitForOtherThreadToFinishPanicking();
        },
        1 => {
            panic_stage = 2;
            // A panic happened while trying to print a previous panic message.
            // We're still holding the mutex but that's fine as we're going to
            // call abort().
            fs.File.stderr().writeAll("aborting due to recursive panic\n") catch {};
        },
        else => {}, // Panicked while printing the recursive panic message.
    }

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

pub const StackUnwindOptions = struct {
    /// If not `null`, we will ignore all frames up until this return address. This is typically
    /// used to omit intermediate handling code (for instance, a panic handler and its machinery)
    /// from stack traces.
    first_address: ?usize = null,
    /// If not `null`, we will unwind from this `cpu_context.Native` instead of the current top of
    /// the stack. The main use case here is printing stack traces from signal handlers, where the
    /// kernel provides a `*const cpu_context.Native` of the state before the signal.
    context: ?CpuContextPtr = null,
    /// If `true`, stack unwinding strategies which may cause crashes are used as a last resort.
    /// If `false`, only known-safe mechanisms will be attempted.
    allow_unsafe_unwind: bool = false,
};

/// Capture and return the current stack trace. The returned `StackTrace` stores its addresses in
/// the given buffer, so `addr_buf` must have a lifetime at least equal to the `StackTrace`.
///
/// See `writeCurrentStackTrace` to immediately print the trace instead of capturing it.
pub noinline fn captureCurrentStackTrace(options: StackUnwindOptions, addr_buf: []usize) std.builtin.StackTrace {
    const empty_trace: std.builtin.StackTrace = .{ .index = 0, .instruction_addresses = &.{} };
    if (!std.options.allow_stack_tracing) return empty_trace;
    var it = StackIterator.init(options.context) catch return empty_trace;
    defer it.deinit();
    if (!it.stratOk(options.allow_unsafe_unwind)) return empty_trace;
    var total_frames: usize = 0;
    var index: usize = 0;
    var wait_for = options.first_address;
    // Ideally, we would iterate the whole stack so that the `index` in the returned trace was
    // indicative of how many frames were skipped. However, this has a significant runtime cost
    // in some cases, so at least for now, we don't do that.
    while (index < addr_buf.len) switch (it.next()) {
        .switch_to_fp => if (!it.stratOk(options.allow_unsafe_unwind)) break,
        .end => break,
        .frame => |ret_addr| {
            if (total_frames > 10_000) {
                // Limit the number of frames in case of (e.g.) broken debug information which is
                // getting unwinding stuck in a loop.
                break;
            }
            total_frames += 1;
            if (wait_for) |target| {
                if (ret_addr != target) continue;
                wait_for = null;
            }
            addr_buf[index] = ret_addr;
            index += 1;
        },
    };
    return .{
        .index = index,
        .instruction_addresses = addr_buf[0..index],
    };
}
/// Write the current stack trace to `writer`, annotated with source locations.
///
/// See `captureCurrentStackTrace` to capture the trace addresses into a buffer instead of printing.
pub noinline fn writeCurrentStackTrace(options: StackUnwindOptions, writer: *Writer, tty_config: tty.Config) Writer.Error!void {
    if (!std.options.allow_stack_tracing) {
        tty_config.setColor(writer, .dim) catch {};
        try writer.print("Cannot print stack trace: stack tracing is disabled\n", .{});
        tty_config.setColor(writer, .reset) catch {};
        return;
    }
    const di_gpa = getDebugInfoAllocator();
    const di = getSelfDebugInfo() catch |err| switch (err) {
        error.UnsupportedTarget => {
            tty_config.setColor(writer, .dim) catch {};
            try writer.print("Cannot print stack trace: debug info unavailable for target\n", .{});
            tty_config.setColor(writer, .reset) catch {};
            return;
        },
    };
    var it = StackIterator.init(options.context) catch |err| switch (err) {
        error.CannotUnwindFromContext => {
            tty_config.setColor(writer, .dim) catch {};
            try writer.print("Cannot print stack trace: context unwind unavailable for target\n", .{});
            tty_config.setColor(writer, .reset) catch {};
            return;
        },
    };
    defer it.deinit();
    if (!it.stratOk(options.allow_unsafe_unwind)) {
        tty_config.setColor(writer, .dim) catch {};
        try writer.print("Cannot print stack trace: safe unwind unavailable for target\n", .{});
        tty_config.setColor(writer, .reset) catch {};
        return;
    }
    var total_frames: usize = 0;
    var wait_for = options.first_address;
    var printed_any_frame = false;
    while (true) switch (it.next()) {
        .switch_to_fp => |unwind_error| {
            switch (StackIterator.fp_usability) {
                .useless, .unsafe => {},
                .safe, .ideal => continue, // no need to even warn
            }
            const module_name = di.getModuleName(di_gpa, unwind_error.address) catch "???";
            const caption: []const u8 = switch (unwind_error.err) {
                error.MissingDebugInfo => "unwind info unavailable",
                error.InvalidDebugInfo => "unwind info invalid",
                error.UnsupportedDebugInfo => "unwind info unsupported",
                error.ReadFailed => "filesystem error",
                error.OutOfMemory => "out of memory",
                error.Unexpected => "unexpected error",
            };
            if (it.stratOk(options.allow_unsafe_unwind)) {
                tty_config.setColor(writer, .dim) catch {};
                try writer.print(
                    "Unwind error at address `{s}:0x{x}` ({s}), remaining frames may be incorrect\n",
                    .{ module_name, unwind_error.address, caption },
                );
                tty_config.setColor(writer, .reset) catch {};
            } else {
                tty_config.setColor(writer, .dim) catch {};
                try writer.print(
                    "Unwind error at address `{s}:0x{x}` ({s}), stopping trace early\n",
                    .{ module_name, unwind_error.address, caption },
                );
                tty_config.setColor(writer, .reset) catch {};
                return;
            }
        },
        .end => break,
        .frame => |ret_addr| {
            if (total_frames > 10_000) {
                tty_config.setColor(writer, .dim) catch {};
                try writer.print(
                    "Stopping trace after {d} frames (large frame count may indicate broken debug info)\n",
                    .{total_frames},
                );
                tty_config.setColor(writer, .reset) catch {};
                return;
            }
            total_frames += 1;
            if (wait_for) |target| {
                if (ret_addr != target) continue;
                wait_for = null;
            }
            // `ret_addr` is the return address, which is *after* the function call.
            // Subtract 1 to get an address *in* the function call for a better source location.
            try printSourceAtAddress(di_gpa, di, writer, ret_addr -| 1, tty_config);
            printed_any_frame = true;
        },
    };
    if (!printed_any_frame) return writer.writeAll("(empty stack trace)\n");
}
/// A thin wrapper around `writeCurrentStackTrace` which writes to stderr and ignores write errors.
pub fn dumpCurrentStackTrace(options: StackUnwindOptions) void {
    const tty_config = tty.detectConfig(.stderr());
    const stderr = lockStderrWriter(&.{});
    defer unlockStderrWriter();
    writeCurrentStackTrace(.{
        .first_address = a: {
            if (options.first_address) |a| break :a a;
            if (options.context != null) break :a null;
            break :a @returnAddress(); // don't include this frame in the trace
        },
        .context = options.context,
        .allow_unsafe_unwind = options.allow_unsafe_unwind,
    }, stderr, tty_config) catch |err| switch (err) {
        error.WriteFailed => {},
    };
}

/// Write a previously captured stack trace to `writer`, annotated with source locations.
pub fn writeStackTrace(st: *const std.builtin.StackTrace, writer: *Writer, tty_config: tty.Config) Writer.Error!void {
    if (!std.options.allow_stack_tracing) {
        tty_config.setColor(writer, .dim) catch {};
        try writer.print("Cannot print stack trace: stack tracing is disabled\n", .{});
        tty_config.setColor(writer, .reset) catch {};
        return;
    }
    // Fetch `st.index` straight away. Aside from avoiding redundant loads, this prevents issues if
    // `st` is `@errorReturnTrace()` and errors are encountered while writing the stack trace.
    const n_frames = st.index;
    if (n_frames == 0) return writer.writeAll("(empty stack trace)\n");
    const di_gpa = getDebugInfoAllocator();
    const di = getSelfDebugInfo() catch |err| switch (err) {
        error.UnsupportedTarget => {
            tty_config.setColor(writer, .dim) catch {};
            try writer.print("Cannot print stack trace: debug info unavailable for target\n\n", .{});
            tty_config.setColor(writer, .reset) catch {};
            return;
        },
    };
    const captured_frames = @min(n_frames, st.instruction_addresses.len);
    for (st.instruction_addresses[0..captured_frames]) |ret_addr| {
        // `ret_addr` is the return address, which is *after* the function call.
        // Subtract 1 to get an address *in* the function call for a better source location.
        try printSourceAtAddress(di_gpa, di, writer, ret_addr -| 1, tty_config);
    }
    if (n_frames > captured_frames) {
        tty_config.setColor(writer, .bold) catch {};
        try writer.print("({d} additional stack frames skipped...)\n", .{n_frames - captured_frames});
        tty_config.setColor(writer, .reset) catch {};
    }
}
/// A thin wrapper around `writeStackTrace` which writes to stderr and ignores write errors.
pub fn dumpStackTrace(st: *const std.builtin.StackTrace) void {
    const tty_config = tty.detectConfig(.stderr());
    const stderr = lockStderrWriter(&.{});
    defer unlockStderrWriter();
    writeStackTrace(st, stderr, tty_config) catch |err| switch (err) {
        error.WriteFailed => {},
    };
}

const StackIterator = union(enum) {
    /// Unwinding using debug info (e.g. DWARF CFI).
    di: if (SelfInfo != void and SelfInfo.can_unwind) SelfInfo.UnwindContext else noreturn,
    /// We will first report the *current* PC of this `UnwindContext`, then we will switch to `di`.
    di_first: if (SelfInfo != void and SelfInfo.can_unwind) SelfInfo.UnwindContext else noreturn,
    /// Naive frame-pointer-based unwinding. Very simple, but typically unreliable.
    fp: usize,

    /// It is important that this function is marked `inline` so that it can safely use
    /// `@frameAddress` and `cpu_context.Native.current` as the caller's stack frame and
    /// our own are one and the same.
    inline fn init(opt_context_ptr: ?CpuContextPtr) error{CannotUnwindFromContext}!StackIterator {
        if (builtin.cpu.arch.isSPARC()) {
            // Flush all the register windows on stack.
            if (builtin.cpu.has(.sparc, .v9)) {
                asm volatile ("flushw" ::: .{ .memory = true });
            } else {
                asm volatile ("ta 3" ::: .{ .memory = true }); // ST_FLUSH_WINDOWS
            }
        }
        if (opt_context_ptr) |context_ptr| {
            if (SelfInfo == void or !SelfInfo.can_unwind) return error.CannotUnwindFromContext;
            // Use `di_first` here so we report the PC in the context before unwinding any further.
            return .{ .di_first = .init(context_ptr) };
        }
        // Workaround the C backend being unable to use inline assembly on MSVC by disabling the
        // call to `current`. This effectively constrains stack trace collection and dumping to FP
        // unwinding when building with CBE for MSVC.
        if (!(builtin.zig_backend == .stage2_c and builtin.target.abi == .msvc) and
            SelfInfo != void and
            SelfInfo.can_unwind and
            cpu_context.Native != noreturn and
            fp_usability != .ideal)
        {
            // We don't need `di_first` here, because our PC is in `std.debug`; we're only interested
            // in our caller's frame and above.
            return .{ .di = .init(&.current()) };
        }
        return .{ .fp = @frameAddress() };
    }
    fn deinit(si: *StackIterator) void {
        switch (si.*) {
            .fp => {},
            .di, .di_first => |*unwind_context| unwind_context.deinit(getDebugInfoAllocator()),
        }
    }

    const FpUsability = enum {
        /// FP unwinding is impractical on this target. For example, due to its very silly ABI
        /// design decisions, it's not possible to do generic FP unwinding on MIPS without a
        /// complicated code scanning algorithm.
        useless,
        /// FP unwinding is unsafe on this target; we may crash when doing so. We will only perform
        /// FP unwinding in the case of crashes/panics, or if the user opts in.
        unsafe,
        /// FP unwinding is guaranteed to be safe on this target. We will do so if unwinding with
        /// debug info does not work, and if this compilation has frame pointers enabled.
        safe,
        /// FP unwinding is the best option on this target. This is usually because the ABI requires
        /// a backchain pointer, thus making it always available, safe, and fast.
        ideal,
    };

    const fp_usability: FpUsability = switch (builtin.target.cpu.arch) {
        .mips,
        .mipsel,
        .mips64,
        .mips64el,
        => .useless,
        .hexagon,
        // The PowerPC ABIs don't actually strictly require a backchain pointer; they allow omitting
        // it when full unwind info is present. Despite this, both GCC and Clang always enforce the
        // presence of the backchain pointer no matter what options they are given. This seems to be
        // a case of "the spec is only a polite suggestion", except it works in our favor this time!
        .powerpc,
        .powerpcle,
        .powerpc64,
        .powerpc64le,
        => .ideal,
        // https://developer.apple.com/documentation/xcode/writing-arm64-code-for-apple-platforms#Respect-the-purpose-of-specific-CPU-registers
        .aarch64 => if (builtin.target.os.tag.isDarwin()) .safe else .unsafe,
        else => .unsafe,
    };

    /// Whether the current unwind strategy is allowed given `allow_unsafe`.
    fn stratOk(it: *const StackIterator, allow_unsafe: bool) bool {
        return switch (it.*) {
            .di, .di_first => true,
            // If we omitted frame pointers from *this* compilation, FP unwinding would crash
            // immediately regardless of anything. But FPs could also be omitted from a different
            // linked object, so it's not guaranteed to be safe, unless the target specifically
            // requires it.
            .fp => switch (fp_usability) {
                .useless => false,
                .unsafe => allow_unsafe and !builtin.omit_frame_pointer,
                .safe => !builtin.omit_frame_pointer,
                .ideal => true,
            },
        };
    }

    const Result = union(enum) {
        /// A stack frame has been found; this is the corresponding return address.
        frame: usize,
        /// The end of the stack has been reached.
        end,
        /// We were using `SelfInfo.UnwindInfo`, but are now switching to FP unwinding due to this error.
        switch_to_fp: struct {
            address: usize,
            err: SelfInfoError,
        },
    };

    fn next(it: *StackIterator) Result {
        switch (it.*) {
            .di_first => |unwind_context| {
                const first_pc = unwind_context.pc;
                if (first_pc == 0) return .end;
                it.* = .{ .di = unwind_context };
                // The caller expects *return* addresses, where they will subtract 1 to find the address of the call.
                // However, we have the actual current PC, which should not be adjusted. Compensate by adding 1.
                return .{ .frame = first_pc +| 1 };
            },
            .di => |*unwind_context| {
                const di = getSelfDebugInfo() catch unreachable;
                const di_gpa = getDebugInfoAllocator();
                const ret_addr = di.unwindFrame(di_gpa, unwind_context) catch |err| {
                    const pc = unwind_context.pc;
                    it.* = .{ .fp = unwind_context.getFp() };
                    return .{ .switch_to_fp = .{
                        .address = pc,
                        .err = err,
                    } };
                };
                if (ret_addr <= 1) return .end;
                return .{ .frame = ret_addr };
            },
            .fp => |fp| {
                if (fp == 0) return .end; // we reached the "sentinel" base pointer

                const bp_addr = applyOffset(fp, bp_offset) orelse return .end;
                const ra_addr = applyOffset(fp, ra_offset) orelse return .end;

                if (bp_addr == 0 or !mem.isAligned(bp_addr, @alignOf(usize)) or
                    ra_addr == 0 or !mem.isAligned(ra_addr, @alignOf(usize)))
                {
                    // This isn't valid, but it most likely indicates end of stack.
                    return .end;
                }

                const bp_ptr: *const usize = @ptrFromInt(bp_addr);
                const ra_ptr: *const usize = @ptrFromInt(ra_addr);
                const bp = applyOffset(bp_ptr.*, bp_bias) orelse return .end;

                // The stack grows downards, so `bp > fp` should always hold. If it doesn't, this
                // frame is invalid, so we'll treat it as though it we reached end of stack. The
                // exception is address 0, which is a graceful end-of-stack signal, in which case
                // *this* return address is valid and the *next* iteration will be the last.
                if (bp != 0 and bp <= fp) return .end;

                it.fp = bp;
                const ra = stripInstructionPtrAuthCode(ra_ptr.*);
                if (ra <= 1) return .end;
                return .{ .frame = ra };
            },
        }
    }

    /// Offset of the saved base pointer (previous frame pointer) wrt the frame pointer.
    const bp_offset = off: {
        // On RISC-V the frame pointer points to the top of the saved register
        // area, on pretty much every other architecture it points to the stack
        // slot where the previous frame pointer is saved.
        if (native_arch.isLoongArch() or native_arch.isRISCV()) break :off -2 * @sizeOf(usize);
        // On SPARC the previous frame pointer is stored at 14 slots past %fp+BIAS.
        if (native_arch.isSPARC()) break :off 14 * @sizeOf(usize);
        break :off 0;
    };

    /// Offset of the saved return address wrt the frame pointer.
    const ra_offset = off: {
        if (native_arch.isLoongArch() or native_arch.isRISCV()) break :off -1 * @sizeOf(usize);
        if (native_arch.isSPARC()) break :off 15 * @sizeOf(usize);
        if (native_arch.isPowerPC64()) break :off 2 * @sizeOf(usize);
        // On s390x, r14 is the link register and we need to grab it from its customary slot in the
        // register save area (ELF ABI s390x Supplement §1.2.2.2).
        if (native_arch == .s390x) break :off 14 * @sizeOf(usize);
        break :off @sizeOf(usize);
    };

    /// Value to add to a base pointer after loading it from the stack. Yes, SPARC really does this.
    const bp_bias = bias: {
        if (native_arch.isSPARC()) break :bias 2047;
        break :bias 0;
    };

    fn applyOffset(addr: usize, comptime off: comptime_int) ?usize {
        if (off >= 0) return math.add(usize, addr, off) catch return null;
        return math.sub(usize, addr, -off) catch return null;
    }
};

/// Some platforms use pointer authentication: the upper bits of instruction pointers contain a
/// signature. This function clears those signature bits to make the pointer directly usable.
pub inline fn stripInstructionPtrAuthCode(ptr: usize) usize {
    if (native_arch.isAARCH64()) {
        // `hint 0x07` maps to `xpaclri` (or `nop` if the hardware doesn't support it)
        // The save / restore is because `xpaclri` operates on x30 (LR)
        return asm (
            \\mov x16, x30
            \\mov x30, x15
            \\hint 0x07
            \\mov x15, x30
            \\mov x30, x16
            : [ret] "={x15}" (-> usize),
            : [ptr] "{x15}" (ptr),
            : .{ .x16 = true });
    }

    return ptr;
}

fn printSourceAtAddress(gpa: Allocator, debug_info: *SelfInfo, writer: *Writer, address: usize, tty_config: tty.Config) Writer.Error!void {
    const symbol: Symbol = debug_info.getSymbol(gpa, address) catch |err| switch (err) {
        error.MissingDebugInfo,
        error.UnsupportedDebugInfo,
        error.InvalidDebugInfo,
        => .unknown,
        error.ReadFailed, error.Unexpected => s: {
            tty_config.setColor(writer, .dim) catch {};
            try writer.print("Failed to read debug info from filesystem, trace may be incomplete\n\n", .{});
            tty_config.setColor(writer, .reset) catch {};
            break :s .unknown;
        },
        error.OutOfMemory => s: {
            tty_config.setColor(writer, .dim) catch {};
            try writer.print("Ran out of memory loading debug info, trace may be incomplete\n\n", .{});
            tty_config.setColor(writer, .reset) catch {};
            break :s .unknown;
        },
    };
    defer if (symbol.source_location) |sl| gpa.free(sl.file_name);
    return printLineInfo(
        writer,
        symbol.source_location,
        address,
        symbol.name orelse "???",
        symbol.compile_unit_name orelse debug_info.getModuleName(gpa, address) catch "???",
        tty_config,
    );
}
fn printLineInfo(
    writer: *Writer,
    source_location: ?SourceLocation,
    address: usize,
    symbol_name: []const u8,
    compile_unit_name: []const u8,
    tty_config: tty.Config,
) Writer.Error!void {
    nosuspend {
        tty_config.setColor(writer, .bold) catch {};

        if (source_location) |*sl| {
            try writer.print("{s}:{d}:{d}", .{ sl.file_name, sl.line, sl.column });
        } else {
            try writer.writeAll("???:?:?");
        }

        tty_config.setColor(writer, .reset) catch {};
        try writer.writeAll(": ");
        tty_config.setColor(writer, .dim) catch {};
        try writer.print("0x{x} in {s} ({s})", .{ address, symbol_name, compile_unit_name });
        tty_config.setColor(writer, .reset) catch {};
        try writer.writeAll("\n");

        // Show the matching source code line if possible
        if (source_location) |sl| {
            if (printLineFromFile(writer, sl)) {
                if (sl.column > 0) {
                    // The caret already takes one char
                    const space_needed = @as(usize, @intCast(sl.column - 1));

                    try writer.splatByteAll(' ', space_needed);
                    tty_config.setColor(writer, .green) catch {};
                    try writer.writeAll("^");
                    tty_config.setColor(writer, .reset) catch {};
                }
                try writer.writeAll("\n");
            } else |_| {
                // Ignore all errors; it's a better UX to just print the source location without the
                // corresponding line number. The user can always open the source file themselves.
            }
        }
    }
}
fn printLineFromFile(writer: *Writer, source_location: SourceLocation) !void {
    // Allow overriding the target-agnostic source line printing logic by exposing `root.debug.printLineFromFile`.
    if (@hasDecl(root, "debug") and @hasDecl(root.debug, "printLineFromFile")) {
        return root.debug.printLineFromFile(writer, source_location);
    }

    // Need this to always block even in async I/O mode, because this could potentially
    // be called from e.g. the event loop code crashing.
    var f = try fs.cwd().openFile(source_location.file_name, .{});
    defer f.close();
    // TODO fstat and make sure that the file has the correct size

    var buf: [4096]u8 = undefined;
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
        return writer.writeAll(line);
    } else { // Line is the last inside the buffer, and requires another read to find delimiter. Alternatively the file ends.
        mem.replaceScalar(u8, slice, '\t', ' ');
        try writer.writeAll(slice);
        while (amt_read == buf.len) {
            amt_read = try f.read(buf[0..]);
            if (mem.indexOfScalar(u8, buf[0..amt_read], '\n')) |pos| {
                const line = buf[0 .. pos + 1];
                mem.replaceScalar(u8, line, '\t', ' ');
                return writer.writeAll(line);
            } else {
                const line = buf[0..amt_read];
                mem.replaceScalar(u8, line, '\t', ' ');
                try writer.writeAll(line);
            }
        }
        // Make sure printing last line of file inserts extra newline
        try writer.writeByte('\n');
    }
}

test printLineFromFile {
    var aw: Writer.Allocating = .init(std.testing.allocator);
    defer aw.deinit();
    const output_stream = &aw.writer;

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

        try expectError(error.EndOfFile, printLineFromFile(output_stream, .{ .file_name = path, .line = 2, .column = 0 }));

        try printLineFromFile(output_stream, .{ .file_name = path, .line = 1, .column = 0 });
        try expectEqualStrings("no new lines in this file, but one is printed anyway\n", aw.written());
        aw.clearRetainingCapacity();
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

        try printLineFromFile(output_stream, .{ .file_name = path, .line = 1, .column = 0 });
        try expectEqualStrings("1\n", aw.written());
        aw.clearRetainingCapacity();

        try printLineFromFile(output_stream, .{ .file_name = path, .line = 3, .column = 0 });
        try expectEqualStrings("3\n", aw.written());
        aw.clearRetainingCapacity();
    }
    {
        const file = try test_dir.dir.createFile("line_overlaps_page_boundary.zig", .{});
        defer file.close();
        const path = try fs.path.join(allocator, &.{ test_dir_path, "line_overlaps_page_boundary.zig" });
        defer allocator.free(path);

        const overlap = 10;
        var buf: [16]u8 = undefined;
        var file_writer = file.writer(&buf);
        const writer = &file_writer.interface;
        try writer.splatByteAll('a', std.heap.page_size_min - overlap);
        try writer.writeByte('\n');
        try writer.splatByteAll('a', overlap);
        try writer.flush();

        try printLineFromFile(output_stream, .{ .file_name = path, .line = 2, .column = 0 });
        try expectEqualStrings(("a" ** overlap) ++ "\n", aw.written());
        aw.clearRetainingCapacity();
    }
    {
        const file = try test_dir.dir.createFile("file_ends_on_page_boundary.zig", .{});
        defer file.close();
        const path = try fs.path.join(allocator, &.{ test_dir_path, "file_ends_on_page_boundary.zig" });
        defer allocator.free(path);

        var file_writer = file.writer(&.{});
        const writer = &file_writer.interface;
        try writer.splatByteAll('a', std.heap.page_size_max);

        try printLineFromFile(output_stream, .{ .file_name = path, .line = 1, .column = 0 });
        try expectEqualStrings(("a" ** std.heap.page_size_max) ++ "\n", aw.written());
        aw.clearRetainingCapacity();
    }
    {
        const file = try test_dir.dir.createFile("very_long_first_line_spanning_multiple_pages.zig", .{});
        defer file.close();
        const path = try fs.path.join(allocator, &.{ test_dir_path, "very_long_first_line_spanning_multiple_pages.zig" });
        defer allocator.free(path);

        var file_writer = file.writer(&.{});
        const writer = &file_writer.interface;
        try writer.splatByteAll('a', 3 * std.heap.page_size_max);

        try expectError(error.EndOfFile, printLineFromFile(output_stream, .{ .file_name = path, .line = 2, .column = 0 }));

        try printLineFromFile(output_stream, .{ .file_name = path, .line = 1, .column = 0 });
        try expectEqualStrings(("a" ** (3 * std.heap.page_size_max)) ++ "\n", aw.written());
        aw.clearRetainingCapacity();

        try writer.writeAll("a\na");

        try printLineFromFile(output_stream, .{ .file_name = path, .line = 1, .column = 0 });
        try expectEqualStrings(("a" ** (3 * std.heap.page_size_max)) ++ "a\n", aw.written());
        aw.clearRetainingCapacity();

        try printLineFromFile(output_stream, .{ .file_name = path, .line = 2, .column = 0 });
        try expectEqualStrings("a\n", aw.written());
        aw.clearRetainingCapacity();
    }
    {
        const file = try test_dir.dir.createFile("file_of_newlines.zig", .{});
        defer file.close();
        const path = try fs.path.join(allocator, &.{ test_dir_path, "file_of_newlines.zig" });
        defer allocator.free(path);

        var file_writer = file.writer(&.{});
        const writer = &file_writer.interface;
        const real_file_start = 3 * std.heap.page_size_min;
        try writer.splatByteAll('\n', real_file_start);
        try writer.writeAll("abc\ndef");

        try printLineFromFile(output_stream, .{ .file_name = path, .line = real_file_start + 1, .column = 0 });
        try expectEqualStrings("abc\n", aw.written());
        aw.clearRetainingCapacity();

        try printLineFromFile(output_stream, .{ .file_name = path, .line = real_file_start + 2, .column = 0 });
        try expectEqualStrings("def\n", aw.written());
        aw.clearRetainingCapacity();
    }
}

/// The returned allocator should be thread-safe if the compilation is multi-threaded, because
/// multiple threads could capture and/or print stack traces simultaneously.
fn getDebugInfoAllocator() Allocator {
    // Allow overriding the debug info allocator by exposing `root.debug.getDebugInfoAllocator`.
    if (@hasDecl(root, "debug") and @hasDecl(root.debug, "getDebugInfoAllocator")) {
        return root.debug.getDebugInfoAllocator();
    }
    // Otherwise, use a global arena backed by the page allocator
    const S = struct {
        var arena: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
        var ts_arena: std.heap.ThreadSafeAllocator = .{ .child_allocator = arena.allocator() };
    };
    return S.ts_arena.allocator();
}

/// Whether or not the current target can print useful debug information when a segfault occurs.
pub const have_segfault_handling_support = switch (native_os) {
    .haiku,
    .linux,
    .serenity,

    .dragonfly,
    .freebsd,
    .netbsd,
    .openbsd,

    .driverkit,
    .ios,
    .macos,
    .tvos,
    .visionos,
    .watchos,

    .illumos,
    .solaris,

    .windows,
    => true,

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

/// Attaches a global handler for several signals which, when triggered, prints output to stderr
/// similar to the default panic handler, with a message containing the type of signal and a stack
/// trace if possible. This implementation does not just call the panic handler, because unwinding
/// the stack (for a stack trace) when a signal is received requires special target-specific logic.
///
/// The signals for which a handler is installed are:
/// * SIGSEGV (segmentation fault)
/// * SIGILL (illegal instruction)
/// * SIGBUS (bus error)
/// * SIGFPE (arithmetic exception)
pub fn attachSegfaultHandler() void {
    if (!have_segfault_handling_support) {
        @compileError("segfault handler not supported for this target");
    }
    if (native_os == .windows) {
        windows_segfault_handle = windows.kernel32.AddVectoredExceptionHandler(0, handleSegfaultWindows);
        return;
    }
    const act = posix.Sigaction{
        .handler = .{ .sigaction = handleSegfaultPosix },
        .mask = posix.sigemptyset(),
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
    const act = posix.Sigaction{
        .handler = .{ .handler = posix.SIG.DFL },
        .mask = posix.sigemptyset(),
        .flags = 0,
    };
    updateSegfaultHandler(&act);
}

fn handleSegfaultPosix(sig: i32, info: *const posix.siginfo_t, ctx_ptr: ?*anyopaque) callconv(.c) noreturn {
    if (use_trap_panic) @trap();
    const addr: ?usize, const name: []const u8 = info: {
        if (native_os == .linux and native_arch == .x86_64) {
            // x86_64 doesn't have a full 64-bit virtual address space.
            // Addresses outside of that address space are non-canonical
            // and the CPU won't provide the faulting address to us.
            // This happens when accessing memory addresses such as 0xaaaaaaaaaaaaaaaa
            // but can also happen when no addressable memory is involved;
            // for example when reading/writing model-specific registers
            // by executing `rdmsr` or `wrmsr` in user-space (unprivileged mode).
            const SI_KERNEL = 0x80;
            if (sig == posix.SIG.SEGV and info.code == SI_KERNEL) {
                break :info .{ null, "General protection exception" };
            }
        }
        const addr: usize = switch (native_os) {
            .serenity,
            .dragonfly,
            .freebsd,
            .driverkit,
            .ios,
            .macos,
            .tvos,
            .visionos,
            .watchos,
            => @intFromPtr(info.addr),
            .linux,
            => @intFromPtr(info.fields.sigfault.addr),
            .netbsd,
            => @intFromPtr(info.info.reason.fault.addr),
            .haiku,
            .openbsd,
            => @intFromPtr(info.data.fault.addr),
            .illumos,
            .solaris,
            => @intFromPtr(info.reason.fault.addr),
            else => comptime unreachable,
        };
        const name = switch (sig) {
            posix.SIG.SEGV => "Segmentation fault",
            posix.SIG.ILL => "Illegal instruction",
            posix.SIG.BUS => "Bus error",
            posix.SIG.FPE => "Arithmetic exception",
            else => unreachable,
        };
        break :info .{ addr, name };
    };
    const opt_cpu_context: ?cpu_context.Native = cpu_context.fromPosixSignalContext(ctx_ptr);
    handleSegfault(addr, name, if (opt_cpu_context) |*ctx| ctx else null);
}

fn handleSegfaultWindows(info: *windows.EXCEPTION_POINTERS) callconv(.winapi) c_long {
    if (use_trap_panic) @trap();
    const name: []const u8, const addr: ?usize = switch (info.ExceptionRecord.ExceptionCode) {
        windows.EXCEPTION_DATATYPE_MISALIGNMENT => .{ "Unaligned memory access", null },
        windows.EXCEPTION_ACCESS_VIOLATION => .{ "Segmentation fault", info.ExceptionRecord.ExceptionInformation[1] },
        windows.EXCEPTION_ILLEGAL_INSTRUCTION => .{ "Illegal instruction", info.ContextRecord.getRegs().ip },
        windows.EXCEPTION_STACK_OVERFLOW => .{ "Stack overflow", null },
        else => return windows.EXCEPTION_CONTINUE_SEARCH,
    };
    handleSegfault(addr, name, &cpu_context.fromWindowsContext(info.ContextRecord));
}

fn handleSegfault(addr: ?usize, name: []const u8, opt_ctx: ?CpuContextPtr) noreturn {
    // Allow overriding the target-agnostic segfault handler by exposing `root.debug.handleSegfault`.
    if (@hasDecl(root, "debug") and @hasDecl(root.debug, "handleSegfault")) {
        return root.debug.handleSegfault(addr, name, opt_ctx);
    }
    return defaultHandleSegfault(addr, name, opt_ctx);
}

pub fn defaultHandleSegfault(addr: ?usize, name: []const u8, opt_ctx: ?CpuContextPtr) noreturn {
    // There is very similar logic to the following in `defaultPanic`.
    switch (panic_stage) {
        0 => {
            panic_stage = 1;
            _ = panicking.fetchAdd(1, .seq_cst);

            trace: {
                const tty_config = tty.detectConfig(.stderr());

                const stderr = lockStderrWriter(&.{});
                defer unlockStderrWriter();

                if (addr) |a| {
                    stderr.print("{s} at address 0x{x}\n", .{ name, a }) catch break :trace;
                } else {
                    stderr.print("{s} (no address available)\n", .{name}) catch break :trace;
                }
                if (opt_ctx) |context| {
                    writeCurrentStackTrace(.{
                        .context = context,
                        .allow_unsafe_unwind = true, // we're crashing anyway, give it our all!
                    }, stderr, tty_config) catch break :trace;
                }
            }
        },
        1 => {
            panic_stage = 2;
            // A segfault happened while trying to print a previous panic message.
            // We're still holding the mutex but that's fine as we're going to
            // call abort().
            fs.File.stderr().writeAll("aborting due to recursive panic\n") catch {};
        },
        else => {}, // Panicked while printing the recursive panic message.
    }

    // We cannot allow the signal handler to return because when it runs the original instruction
    // again, the memory may be mapped and undefined behavior would occur rather than repeating
    // the segfault. So we simply abort here.
    posix.abort();
}

pub fn dumpStackPointerAddr(prefix: []const u8) void {
    const sp = asm (""
        : [argc] "={rsp}" (-> usize),
    );
    print("{s} sp = 0x{x}\n", .{ prefix, sp });
}

test "manage resources correctly" {
    if (SelfInfo == void) return error.SkipZigTest;
    const S = struct {
        noinline fn showMyTrace() usize {
            return @returnAddress();
        }
    };
    const gpa = std.testing.allocator;
    var discarding: std.Io.Writer.Discarding = .init(&.{});
    var di: SelfInfo = .init;
    defer di.deinit(gpa);
    try printSourceAtAddress(
        gpa,
        &di,
        &discarding.writer,
        S.showMyTrace(),
        tty.detectConfig(.stderr()),
    );
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
                const addrs = &t.addrs[t.index];
                const st = captureCurrentStackTrace(.{ .first_address = addr }, addrs);
                if (st.index < addrs.len) {
                    @memset(addrs[st.index..], 0); // zero unused frames to indicate end of trace
                }
            }
            // Keep counting even if the end is reached so that the
            // user can find out how much more size they need.
            t.index += 1;
        }

        pub fn dump(t: @This()) void {
            if (!enabled) return;

            const tty_config = tty.detectConfig(.stderr());
            const stderr = lockStderrWriter(&.{});
            defer unlockStderrWriter();
            const end = @min(t.index, size);
            for (t.addrs[0..end], 0..) |frames_array, i| {
                stderr.print("{s}:\n", .{t.notes[i]}) catch return;
                var frames_array_mutable = frames_array;
                const frames = mem.sliceTo(frames_array_mutable[0..], 0);
                const stack_trace: std.builtin.StackTrace = .{
                    .index = frames.len,
                    .instruction_addresses = frames,
                };
                writeStackTrace(&stack_trace, stderr, tty_config) catch return;
            }
            if (t.index > end) {
                stderr.print("{d} more traces not shown; consider increasing trace size\n", .{
                    t.index - end,
                }) catch return;
            }
        }

        pub fn format(
            t: @This(),
            comptime fmt: []const u8,
            options: std.fmt.Options,
            writer: *Writer,
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
    state: State = if (runtime_safety) .unlocked else .unknown,

    pub const State = if (runtime_safety) enum { unlocked, locked } else enum { unknown };

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

    pub fn assertLocked(l: SafetyLock) void {
        if (!runtime_safety) return;
        assert(l.state == .locked);
    }
};

test SafetyLock {
    var safety_lock: SafetyLock = .{};
    safety_lock.assertUnlocked();
    safety_lock.lock();
    safety_lock.assertLocked();
    safety_lock.unlock();
    safety_lock.assertUnlocked();
}

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
    _ = &Pdb;
    _ = &SelfInfo;
    _ = &dumpHex;
}
