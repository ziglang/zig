// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

//! std.debug contains functions for capturing and printing out stack traces as
//! well as misc. functions such as `print`, `assert`, and `panicExtra`.
//!
//! You can override how addresses are mapped to symbols via
//! `root.debug_config.initSymbolMap` or `root.os.debug.initSymbolMap`.
//!
//! You can override how stack traces are collected via
//! `root.debug_config.captureStackTraceFrom` or
//! `root.os.debug.captureStackTraceFrom`
//!
//! To see what these functions should look like look at the implementations
//! in `debug_config`.

const std = @import("std.zig");
const builtin = std.builtin;
const math = std.math;
const mem = std.mem;
const io = std.io;
const os = std.os;
const fs = std.fs;
const lookupDecl = std.meta.lookupDecl;
const process = std.process;
const root = @import("root");
const File = fs.File;
const windows = os.windows;

pub const runtime_safety = switch (builtin.mode) {
    .Debug, .ReleaseSafe => true,
    .ReleaseFast, .ReleaseSmall => false,
};

// TODO: improve error approach somehow, anyerror shouldn't be used here.

/// Interface for mapping from addresses to symbols (`SymbolInfo`).
pub const SymbolMap = struct {
    pub const LineInfo = struct {
        line: u64,
        column: u64,
        file_name: []const u8,
        allocator: ?*mem.Allocator,

        fn deinit(self: @This()) void {
            const allocator = self.allocator orelse return;
            allocator.free(self.file_name);
        }
    };

    pub const SymbolInfo = struct {
        symbol_name: []const u8 = "???",
        compile_unit_name: []const u8 = "???",
        line_info: ?LineInfo = null,

        fn deinit(self: @This()) void {
            if (self.line_info) |li| {
                li.deinit();
            }
        }
    };

    const Self = @This();

    deinitFn: fn (self: *Self) void,
    addressToSymbolFn: fn (self: *Self, address: usize) anyerror!SymbolInfo,

    fn deinit(self: *Self) void {
        self.deinitFn(self);
    }

    fn addressToSymbol(self: *Self, address: usize) anyerror!SymbolInfo {
        return self.addressToSymbolFn(self, address);
    }

    pub const InitFn = fn (allocator: *mem.Allocator) anyerror!*Self;
};

pub const CaptureStackTraceFn = fn (
    allocator: *std.mem.Allocator,
    first_address: ?usize,
    base_pointer: ?usize,
    stack_trace: *builtin.StackTrace,
) anyerror!void;

pub const default_config = struct {
    /// A function to initialize a object of the interface type SymbolMap.
    pub const initSymbolMap: SymbolMap.InitFn = switch (builtin.os.tag) {
        .macos, .ios, .watchos, .tvos => std.initSymbolMapDarwin,
        .linux, .netbsd, .freebsd, .dragonfly, .openbsd => std.initSymbolMapUnix,
        .uefi, .windows => std.initSymbolMapPdb,
        else => std.initSymbolMapUnsupported,
    };

    /// Loads a stack trace into the provided argument.
    pub const captureStackTraceFrom: CaptureStackTraceFn = defaultCaptureStackTraceFrom;
};

const config = lookupDecl(root, &.{"debug_config"}) orelse struct {};
const os_config = lookupDecl(root, &.{ "os", "debug" }) orelse struct {};

fn lookupConfigItem(
    comptime name: []const u8,
) @TypeOf(lookupDecl(config, &.{name}) orelse
    (lookupDecl(os_config, &.{name}) orelse
    @field(default_config, name))) {
    return lookupDecl(config, &.{name}) orelse
        (lookupDecl(os_config, &.{name}) orelse
        @field(default_config, name));
}

// Slightly different names than in config to avoid redefinition in default.

const initSymMap = lookupConfigItem("initSymbolMap");
const capStackTraceFrom = lookupConfigItem("captureStackTraceFrom");

/// Get the writer used for `print`, `panicExtra`, and stack trace dumping.
pub fn getWriter() File.Writer {
    return io.getStdErr().writer();
}

/// Detect the `TTY.Config` for the writer returned by `getWriter`.
/// This determines which escape codes can be used.
pub fn detectTTYConfig() TTY.Config {
    var bytes: [128]u8 = undefined;
    const allocator = &std.heap.FixedBufferAllocator.init(bytes[0..]).allocator;
    if (process.getEnvVarOwned(allocator, "ZIG_DEBUG_COLOR")) |_| {
        return .escape_codes;
    } else |_| {
        const stderr_file = io.getStdErr();
        if (stderr_file.supportsAnsiEscapeCodes()) {
            return .escape_codes;
        } else if (builtin.os.tag == .windows and stderr_file.isTty()) {
            return .{ .windows_api = stderr_file };
        } else {
            return .no_color;
        }
    }
}

var print_mutex = std.Thread.Mutex{};

pub fn getPrintMutex() *std.Thread.Mutex {
    return &print_mutex;
}

pub const getStderrMutex = @compileError("This was renamed to getPrintMutex because " ++
    "the writer used by `debug` can be overriden.");

/// Deprecated. Use `std.log` functions for logging or `std.debug.print` for
/// "printf debugging".
pub const warn = print;

/// Print to log writer, unbuffered, and silently returning on failure. Intended
/// for use in "printf debugging." Use `std.log` functions for proper logging.
pub fn print(comptime fmt: []const u8, args: anytype) void {
    const held = print_mutex.acquire();
    defer held.release();
    const writer = getWriter();
    nosuspend writer.print(fmt, args) catch {};
}

/// TODO multithreaded awareness
var sym_map: ?*SymbolMap = null;

pub fn getSymbolMap() !*SymbolMap {
    if (sym_map) |info| {
        return info;
    } else {
        sym_map = try initSymMap(getDebugInfoAllocator());
        return sym_map.?;
    }
}

fn getMappingForDump(writer: anytype) ?*SymbolMap {
    return getSymbolMap() catch |err| {
        writer.print(
            "Unable to dump stack trace: Unable to open debug info: {s}\n",
            .{@errorName(err)},
        ) catch {};
        return null;
    };
}

/// Should be called with the writer locked.
fn getStackTraceDumper(writer: anytype) ?StackTraceDumper(@TypeOf(writer)) {
    return if (getMappingForDump(writer)) |mapping|
        .{ .writer = writer, .tty_config = detectTTYConfig(), .mapping = mapping }
    else
        null;
}

fn dumpHandleError(writer: anytype, err: anytype) void {
    writer.print("Unable to dump stack trace: {s}\n", .{@errorName(err)}) catch {};
}

/// Tries to print the current stack trace to writer (as determined by
/// getWriter from the config), unbuffered, and ignores any error returned.
pub fn dumpCurrentStackTrace(start_addr: ?usize) void {
    const held = print_mutex.acquire();
    defer held.release();
    const writer = getWriter();
    nosuspend if (getStackTraceDumper(writer)) |write_trace| {
        write_trace.current(start_addr) catch |err| dumpHandleError(writer, err);
    };
}

/// Tries to print the stack trace starting from the supplied base pointer
/// to writer (as determined by getWriter from the config), unbuffered, and
/// ignores any error returned.
pub fn dumpStackTraceFromBase(bp: usize, ip: usize) void {
    const held = print_mutex.acquire();
    defer held.release();
    const writer = getWriter();
    nosuspend if (getStackTraceDumper(writer)) |write_trace| {
        write_trace.fromBase(bp, ip) catch |err| dumpHandleError(writer, err);
    };
}

/// Tries to print a stack trace to writer (as determined by getWriter from
/// the config), unbuffered, and ignores any error returned.
pub fn dumpStackTrace(stack_trace: builtin.StackTrace) void {
    const held = print_mutex.acquire();
    defer held.release();
    const writer = getWriter();
    nosuspend if (getStackTraceDumper(writer)) |write_trace| {
        write_trace.stackTrace(stack_trace) catch |err| dumpHandleError(writer, err);
    };
}

const StackTraceWithTTYConfig = struct {
    trace: builtin.StackTrace,
    tty_config: std.debug.TTY.Config,
};

fn formatStackTraceWithTTYConfig(
    self: StackTraceWithTTYConfig,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    if (getMappingForDump(writer)) |mapping| {
        const dumper = std.debug.StackTraceDumper(@TypeOf(writer)){
            .writer = writer,
            .tty_config = self.tty_config,
            .mapping = mapping,
        };
        dumper.stackTrace(self.trace) catch |err| dumpHandleError(writer, err);
    }
}

pub const FmtStackTrace = std.fmt.Formatter(formatStackTraceWithTTYConfig);

/// Create a "Formatter" struct which will pretty print a stack trace (with
/// color if specified).
pub fn fmtStackTrace(
    trace: builtin.StackTrace,
    tty_config: std.debug.TTY.Config,
) FmtStackTrace {
    return .{ .data = .{ .trace = trace, .tty_config = tty_config } };
}

/// Wrapper for nicer internal debug usage. Use captureStackTrace and
/// fmtStackTrace for external stack trace printing.
fn StackTraceDumper(comptime Writer: type) type {
    return struct {
        const Self = @This();

        writer: Writer,
        tty_config: TTY.Config,
        mapping: *SymbolMap,

        fn current(
            self: Self,
            first_address: ?usize,
        ) !void {
            return self.currentFrom(first_address, null);
        }

        fn currentFrom(
            self: Self,
            first_address: ?usize,
            base_pointer: ?usize,
        ) !void {
            var addr_buf: [1024]usize = undefined;
            var trace = builtin.StackTrace{
                .index = 0,
                .instruction_addresses = &addr_buf,
            };
            try capStackTraceFrom(
                getDebugInfoAllocator(), // TODO: different allocator?
                first_address,
                base_pointer,
                &trace,
            );
            return self.stackTrace(trace);
        }

        fn fromBase(
            self: @This(),
            bp: usize,
            ip: usize,
        ) !void {
            try self.sourceAtAddress(ip);
            try self.currentFrom(null, bp);
        }

        fn stackTrace(
            self: @This(),
            stack_trace: builtin.StackTrace,
        ) !void {
            var frame_index: usize = 0;
            var frames_left: usize = math.min(stack_trace.index, stack_trace.instruction_addresses.len);

            while (frames_left != 0) : ({
                frames_left -= 1;
                frame_index = (frame_index + 1) % stack_trace.instruction_addresses.len;
            }) {
                const return_address = stack_trace.instruction_addresses[frame_index];
                // should this case be handled here?
                if (return_address == 0) break;
                try self.sourceAtAddress(return_address - 1);
            }
        }

        fn sourceAtAddress(
            self: @This(),
            address: usize,
        ) !void {
            const symbol_info = try self.mapping.addressToSymbol(address);
            defer symbol_info.deinit();

            const writer = self.writer;
            const tty_config = self.tty_config;

            nosuspend {
                try formatStackTraceLine(
                    writer,
                    tty_config,
                    address,
                    symbol_info,
                    attemptWriteLineFromSourceFile,
                );
            }
        }
    };
}

fn formatStackTraceLine(
    writer: anytype,
    tty_config: TTY.Config,
    address: usize,
    si: SymbolMap.SymbolInfo,
    tryWriteLineFromSourceFile: anytype,
) !void {
    tty_config.setColor(writer, .White);

    if (si.line_info) |*li| {
        try writer.print("{s}:{d}:{d}", .{ li.file_name, li.line, li.column });
    } else {
        try writer.writeAll("???:?:?");
    }

    tty_config.setColor(writer, .Reset);
    try writer.writeAll(": ");
    tty_config.setColor(writer, .Dim);
    try writer.print("0x{x} in {s} ({s})", .{ address, si.symbol_name, si.compile_unit_name });
    tty_config.setColor(writer, .Reset);
    try writer.writeAll("\n");

    // Show the matching source code line if possible
    if (si.line_info) |li| {
        if (try tryWriteLineFromSourceFile(writer, li)) {
            if (li.column > 0) {
                // The caret already takes one char
                const space_needed = @intCast(usize, li.column - 1);

                try writer.writeByteNTimes(' ', space_needed);
                tty_config.setColor(writer, .Green);
                try writer.writeAll("^");
                tty_config.setColor(writer, .Reset);
            }
            try writer.writeAll("\n");
        }
    }
}

/// Try to write a line from a source file. If the line couldn't be written but
/// the error is acceptable (end of file, file not found, etc.), returns false.
/// If the line was correctly writen it returns true.
pub fn attemptWriteLineFromSourceFile(writer: anytype, line_info: SymbolMap.LineInfo) !bool {
    // TODO: is this the right place to check?
    if (comptime builtin.arch.isWasm()) {
        return false;
    }

    writeLineFromFileAnyOs(writer, line_info) catch |err| {
        switch (err) {
            error.EndOfFile, error.FileNotFound => {},
            error.BadPathName => {},
            error.AccessDenied => {},
            else => return err,
        }
        return false;
    };
    return true;
}

fn writeLineFromFileAnyOs(writer: anytype, line_info: SymbolMap.LineInfo) !void {
    // Need this to always block even in async I/O mode, because this could potentially
    // be called from e.g. the event loop code crashing.
    var f = try fs.cwd().openFile(line_info.file_name, .{ .intended_io_mode = .blocking });
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
                try writer.writeByte(byte);
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

    panicExtra(null, format, args);
}

/// `panicExtra` is useful when you want to print out an `@errorReturnTrace`
/// and also print out some values.
pub fn panicExtra(
    trace: ?*builtin.StackTrace,
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
    builtin.panic(msg, trace);
}

/// Non-zero whenever the program triggered a panic.
/// Counts the number of threads which are waiting on the `panic_mutex`
/// to print out the stack traces and msg.
var panicking = std.atomic.Int(u32).init(0);

/// Locked to avoid interleaving panic messages from multiple threads.
///
/// We can't use the other Mutex ("print_mutex") because a panic may have
/// happended while that mutex is held. Unfortunately, this means that panic
/// messages may interleave with print(...) or similar.
var panic_mutex = std.Thread.Mutex{};

/// Counts how many times the panic handler is invoked by this thread.
/// This is used to catch and handle panics triggered by the panic handler.
threadlocal var panic_stage: usize = 0;

pub fn panicImpl(trace: ?*const builtin.StackTrace, first_trace_addr: ?usize, msg: []const u8) noreturn {
    @setCold(true);

    if (enable_segfault_handler) {
        // If a segfault happens while panicking, we want it to actually segfault, not trigger
        // the handler.
        resetSegfaultHandler();
    }

    // we can't lock the writer (see above comment on panic_mutex)
    const writer = getWriter();

    nosuspend switch (panic_stage) {
        0 => blk: {
            panic_stage = 1;

            _ = panicking.incr();

            // Make sure to release the mutex when done
            {
                const held = panic_mutex.acquire();
                defer held.release();

                if (builtin.single_threaded) {
                    writer.print("panic: ", .{}) catch break :blk;
                } else {
                    const current_thread_id = std.Thread.getCurrentThreadId();
                    writer.print("thread {d} panic: ", .{current_thread_id}) catch break :blk;
                }
                writer.print("{s}\n", .{msg}) catch break :blk;

                writeTracesForPanic(writer, detectTTYConfig(), trace, first_trace_addr);
            }

            if (panicking.decr() != 1) {
                // Another thread is panicking, wait for the last one to finish
                // and call abort()

                // Sleep forever without hammering the CPU
                var event: std.Thread.StaticResetEvent = .{};
                event.wait();
                unreachable;
            }
        },
        1 => blk: {
            panic_stage = 2;

            // A panic happened while trying to print a previous panic message,
            // we're still holding the mutex but that's fine as we're going to
            // call abort()
            writer.print("Panicked during a panic. Terminating.\n", .{}) catch break :blk;
        },
        else => {
            // Panicked while printing "Panicked during a panic."
        },
    };

    os.abort();
}

/// Utility function for dumping out stack traces which swallows errors.
/// This may be useful for writing your own panic implementation.
pub fn writeTracesForPanic(
    writer: anytype,
    tty_config: TTY.Config,
    trace: ?*const builtin.StackTrace,
    first_trace_addr: ?usize,
) void {
    // we don't use the dump functions because those lock the mutex
    const mapping = getMappingForDump(writer) orelse return;
    const write_trace = StackTraceDumper(@TypeOf(writer)){
        .writer = writer,
        .tty_config = tty_config,
        .mapping = mapping,
    };

    if (trace) |t| {
        write_trace.stackTrace(t.*) catch |err| {
            dumpHandleError(writer, err);
            return;
        };
    }
    write_trace.current(first_trace_addr) catch |err| {
        dumpHandleError(writer, err);
        return;
    };
}

const RED = "\x1b[31;1m";
const GREEN = "\x1b[32;1m";
const CYAN = "\x1b[36;1m";
const WHITE = "\x1b[37;1m";
const DIM = "\x1b[2m";
const RESET = "\x1b[0m";

pub const TTY = struct {
    pub const Color = enum {
        Red,
        Green,
        Cyan,
        White,
        Dim,
        Bold,
        Reset,
    };

    pub const Config = union(enum) {
        no_color: void,
        escape_codes: void,
        // TODO: should be noreturn instead of void, see
        // https://github.com/ziglang/zig/issues/3257
        // making this noreturn right now causes a crash
        windows_api: if (builtin.os.tag == .windows) File else void,

        pub fn setColor(conf: Config, writer: anytype, color: Color) void {
            nosuspend switch (conf) {
                .no_color => return,
                .escape_codes => switch (color) {
                    .Red => writer.writeAll(RED) catch return,
                    .Green => writer.writeAll(GREEN) catch return,
                    .Cyan => writer.writeAll(CYAN) catch return,
                    .White, .Bold => writer.writeAll(WHITE) catch return,
                    .Dim => writer.writeAll(DIM) catch return,
                    .Reset => writer.writeAll(RESET) catch return,
                },
                .windows_api => |file| if (builtin.os.tag == .windows) {
                    const S = struct {
                        var attrs: windows.WORD = undefined;
                        var init_attrs = false;
                    };
                    if (!S.init_attrs) {
                        S.init_attrs = true;
                        var info: windows.CONSOLE_SCREEN_BUFFER_INFO = undefined;
                        // TODO handle error
                        _ = windows.kernel32.GetConsoleScreenBufferInfo(file.handle, &info);
                        S.attrs = info.wAttributes;
                    }

                    // TODO handle errors
                    switch (color) {
                        .Red => {
                            _ = windows.SetConsoleTextAttribute(file.handle, windows.FOREGROUND_RED | windows.FOREGROUND_INTENSITY) catch {};
                        },
                        .Green => {
                            _ = windows.SetConsoleTextAttribute(file.handle, windows.FOREGROUND_GREEN | windows.FOREGROUND_INTENSITY) catch {};
                        },
                        .Cyan => {
                            _ = windows.SetConsoleTextAttribute(file.handle, windows.FOREGROUND_GREEN | windows.FOREGROUND_BLUE | windows.FOREGROUND_INTENSITY) catch {};
                        },
                        .White, .Bold => {
                            _ = windows.SetConsoleTextAttribute(file.handle, windows.FOREGROUND_RED | windows.FOREGROUND_GREEN | windows.FOREGROUND_BLUE | windows.FOREGROUND_INTENSITY) catch {};
                        },
                        .Dim => {
                            _ = windows.SetConsoleTextAttribute(file.handle, windows.FOREGROUND_INTENSITY) catch {};
                        },
                        .Reset => {
                            _ = windows.SetConsoleTextAttribute(file.handle, S.attrs) catch {};
                        },
                    }
                } else {
                    unreachable;
                },
            };
        }
    };
};

/// Returns a slice with the same pointer as addresses, with a potentially smaller len.
pub fn captureStackTrace(
    allocator: *std.mem.Allocator,
    first_address: ?usize,
    stack_trace: *builtin.StackTrace,
) !void {
    // TODO are there any other arguments/registers which captureStackTraceFrom
    // should get access to?
    try capStackTraceFrom(allocator, first_address, null, stack_trace);
}

/// On Windows, when first_address is not null, we ask for at least 32 stack frames,
/// and then try to find the first address. If addresses.len is more than 32, we
/// capture that many stack frames exactly, and then look for the first address,
/// chopping off the irrelevant frames and shifting so that the returned addresses pointer
/// equals the passed in addresses pointer.
pub fn defaultCaptureStackTraceFrom(
    allocator: *std.mem.Allocator,
    first_address: ?usize,
    base_pointer: ?usize,
    stack_trace: *builtin.StackTrace,
) !void {
    if (builtin.os.tag == .windows) {
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
        var it = StackIterator.init(first_address, base_pointer);
        for (stack_trace.instruction_addresses) |*addr, i| {
            addr.* = it.next() orelse {
                stack_trace.index = i;
                return;
            };
        }
        stack_trace.index = stack_trace.instruction_addresses.len;
    }
}

pub const StackIterator = struct {
    // Skip every frame before this address is found.
    first_address: ?usize,
    // Last known value of the frame pointer register.
    fp: usize,

    pub fn init(first_address: ?usize, fp: ?usize) StackIterator {
        return StackIterator{
            .first_address = first_address,
            .fp = fp orelse @frameAddress(),
        };
    }

    // Offset of the saved BP wrt the frame pointer.
    const fp_offset = if (builtin.arch.isRISCV())
        // On RISC-V the frame pointer points to the top of the saved register
        // area, on pretty much every other architecture it points to the stack
        // slot where the previous frame pointer is saved.
        2 * @sizeOf(usize)
    else if (builtin.arch.isSPARC())
        // On SPARC the previous frame pointer is stored at 14 slots past %fp+BIAS.
        14 * @sizeOf(usize)
    else
        0;

    const fp_bias = if (builtin.arch.isSPARC())
        // On SPARC frame pointers are biased by a constant.
        2047
    else
        0;

    // Positive offset of the saved PC wrt the frame pointer.
    const pc_offset = if (builtin.arch == .powerpc64le)
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

    fn next_internal(self: *StackIterator) ?usize {
        const fp = if (builtin.arch.isSPARC())
            // On SPARC the offset is positive. (!)
            math.add(usize, self.fp, fp_offset) catch return null
        else
            math.sub(usize, self.fp, fp_offset) catch return null;

        // Sanity check.
        if (fp == 0 or !mem.isAligned(fp, @alignOf(usize)))
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

/// TODO multithreaded awareness
var debug_info_allocator: ?*mem.Allocator = null;
var debug_info_arena_allocator: std.heap.ArenaAllocator = undefined;
/// Note: this is also used from StackTraceDumper, so be careful when deinit
/// is (eventually) implemented
fn getDebugInfoAllocator() *mem.Allocator {
    if (debug_info_allocator) |a| return a;

    debug_info_arena_allocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    debug_info_allocator = &debug_info_arena_allocator.allocator;
    return &debug_info_arena_allocator.allocator;
}

/// Whether or not the current target can print useful debug information when a segfault occurs.
pub const have_segfault_handling_support = switch (builtin.os.tag) {
    .linux, .netbsd => true,
    .windows => true,
    .freebsd, .openbsd => @hasDecl(os, "ucontext_t"),
    else => false,
};
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
    if (builtin.os.tag == .windows) {
        windows_segfault_handle = windows.kernel32.AddVectoredExceptionHandler(0, handleSegfaultWindows);
        return;
    }
    var act = os.Sigaction{
        .handler = .{ .sigaction = handleSegfaultLinux },
        .mask = os.empty_sigset,
        .flags = (os.SA_SIGINFO | os.SA_RESTART | os.SA_RESETHAND),
    };

    os.sigaction(os.SIGSEGV, &act, null);
    os.sigaction(os.SIGILL, &act, null);
    os.sigaction(os.SIGBUS, &act, null);
}

fn resetSegfaultHandler() void {
    if (builtin.os.tag == .windows) {
        if (windows_segfault_handle) |handle| {
            assert(windows.kernel32.RemoveVectoredExceptionHandler(handle) != 0);
            windows_segfault_handle = null;
        }
        return;
    }
    var act = os.Sigaction{
        .handler = .{ .sigaction = os.SIG_DFL },
        .mask = os.empty_sigset,
        .flags = 0,
    };
    os.sigaction(os.SIGSEGV, &act, null);
    os.sigaction(os.SIGILL, &act, null);
    os.sigaction(os.SIGBUS, &act, null);
}

fn handleSegfaultLinux(sig: i32, info: *const os.siginfo_t, ctx_ptr: ?*const c_void) callconv(.C) noreturn {
    // Reset to the default handler so that if a segfault happens in this handler it will crash
    // the process. Also when this handler returns, the original instruction will be repeated
    // and the resulting segfault will crash the process rather than continually dump stack traces.
    resetSegfaultHandler();

    const addr = switch (builtin.os.tag) {
        .linux => @ptrToInt(info.fields.sigfault.addr),
        .freebsd => @ptrToInt(info.addr),
        .netbsd => @ptrToInt(info.info.reason.fault.addr),
        .openbsd => @ptrToInt(info.data.fault.addr),
        else => unreachable,
    };

    // Don't use std.debug.print() as print_mutex may still be locked.
    nosuspend {
        const writer = getWriter();
        _ = switch (sig) {
            os.SIGSEGV => writer.print("Segmentation fault at address 0x{x}\n", .{addr}),
            os.SIGILL => writer.print("Illegal instruction at address 0x{x}\n", .{addr}),
            os.SIGBUS => writer.print("Bus error at address 0x{x}\n", .{addr}),
            else => unreachable,
        } catch os.abort();
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
            const ip = switch (builtin.os.tag) {
                .linux, .netbsd => @intCast(usize, ctx.mcontext.gregs[os.REG_RIP]),
                .freebsd => @intCast(usize, ctx.mcontext.rip),
                .openbsd => @intCast(usize, ctx.sc_rip),
                else => unreachable,
            };
            const bp = switch (builtin.os.tag) {
                .linux, .netbsd => @intCast(usize, ctx.mcontext.gregs[os.REG_RBP]),
                .openbsd => @intCast(usize, ctx.sc_rbp),
                .freebsd => @intCast(usize, ctx.mcontext.rbp),
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
        // Don't use std.debug.print() as print_mutex may still be locked.
        nosuspend {
            const writer = getWriter();
            _ = switch (msg) {
                0 => writer.print("{s}\n", .{format.?}),
                1 => writer.print("Segmentation fault at address 0x{x}\n", .{info.ExceptionRecord.ExceptionInformation[1]}),
                2 => writer.print("Illegal instruction at address 0x{x}\n", .{regs.ip}),
                else => unreachable,
            } catch os.abort();
        }

        dumpStackTraceFromBase(regs.bp, regs.ip);
        os.abort();
    } else {
        switch (msg) {
            0 => panicExtra(null, exception_address, format.?, .{}),
            1 => panicExtra(null, exception_address, "Segmentation fault at address 0x{x}", .{info.ExceptionRecord.ExceptionInformation[1]}),
            2 => panicExtra(null, exception_address, "Illegal Instruction", .{}),
            else => unreachable,
        }
    }
}

pub fn dumpStackPointerAddr(prefix: []const u8) void {
    const sp = asm (""
        : [argc] "={rsp}" (-> usize)
    );
    std.debug.print("{} sp = 0x{x}\n", .{ prefix, sp });
}
