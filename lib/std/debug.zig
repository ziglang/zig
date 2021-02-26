// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("std.zig");
const builtin = std.builtin;
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
const root = @import("root");
const maxInt = std.math.maxInt;
const File = std.fs.File;
const windows = std.os.windows;

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

var stderr_mutex = std.Thread.Mutex{};

/// Deprecated. Use `std.log` functions for logging or `std.debug.print` for
/// "printf debugging".
pub const warn = print;

/// Print to stderr, unbuffered, and silently returning on failure. Intended
/// for use in "printf debugging." Use `std.log` functions for proper logging.
pub fn print(comptime fmt: []const u8, args: anytype) void {
    const held = stderr_mutex.acquire();
    defer held.release();
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
            return .windows_api;
        } else {
            return .no_color;
        }
    }
}

/// Tries to print the current stack trace to stderr, unbuffered, and ignores any error returned.
/// TODO multithreaded awareness
pub fn dumpCurrentStackTrace(start_addr: ?usize) void {
    nosuspend {
        const stderr = io.getStdErr().writer();
        if (builtin.strip_debug_info) {
            stderr.print("Unable to dump stack trace: debug info stripped\n", .{}) catch return;
            return;
        }
        const debug_info = getSelfDebugInfo() catch |err| {
            stderr.print("Unable to dump stack trace: Unable to open debug info: {s}\n", .{@errorName(err)}) catch return;
            return;
        };
        writeCurrentStackTrace(stderr, debug_info, detectTTYConfig(), start_addr) catch |err| {
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
        const stderr = io.getStdErr().writer();
        if (builtin.strip_debug_info) {
            stderr.print("Unable to dump stack trace: debug info stripped\n", .{}) catch return;
            return;
        }
        const debug_info = getSelfDebugInfo() catch |err| {
            stderr.print("Unable to dump stack trace: Unable to open debug info: {s}\n", .{@errorName(err)}) catch return;
            return;
        };
        const tty_config = detectTTYConfig();
        printSourceAtAddress(debug_info, stderr, ip, tty_config) catch return;
        var it = StackIterator.init(null, bp);
        while (it.next()) |return_address| {
            printSourceAtAddress(debug_info, stderr, return_address - 1, tty_config) catch return;
        }
    }
}

/// Returns a slice with the same pointer as addresses, with a potentially smaller len.
/// On Windows, when first_address is not null, we ask for at least 32 stack frames,
/// and then try to find the first address. If addresses.len is more than 32, we
/// capture that many stack frames exactly, and then look for the first address,
/// chopping off the irrelevant frames and shifting so that the returned addresses pointer
/// equals the passed in addresses pointer.
pub fn captureStackTrace(first_address: ?usize, stack_trace: *builtin.StackTrace) void {
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
        var it = StackIterator.init(first_address, null);
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
    nosuspend {
        const stderr = io.getStdErr().writer();
        if (builtin.strip_debug_info) {
            stderr.print("Unable to dump stack trace: debug info stripped\n", .{}) catch return;
            return;
        }
        const debug_info = getSelfDebugInfo() catch |err| {
            stderr.print("Unable to dump stack trace: Unable to open debug info: {s}\n", .{@errorName(err)}) catch return;
            return;
        };
        writeStackTrace(stack_trace, stderr, getDebugInfoAllocator(), debug_info, detectTTYConfig()) catch |err| {
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
    // TODO: remove conditional once wasi / LLVM defines __builtin_return_address
    const first_trace_addr = if (builtin.os.tag == .wasi) null else @returnAddress();
    panicExtra(null, first_trace_addr, format, args);
}

/// Non-zero whenever the program triggered a panic.
/// The counter is incremented/decremented atomically.
var panicking: u8 = 0;

// Locked to avoid interleaving panic messages from multiple threads.
var panic_mutex = std.Thread.Mutex{};

/// Counts how many times the panic handler is invoked by this thread.
/// This is used to catch and handle panics triggered by the panic handler.
threadlocal var panic_stage: usize = 0;

pub fn panicExtra(trace: ?*const builtin.StackTrace, first_trace_addr: ?usize, comptime format: []const u8, args: anytype) noreturn {
    @setCold(true);

    if (enable_segfault_handler) {
        // If a segfault happens while panicking, we want it to actually segfault, not trigger
        // the handler.
        resetSegfaultHandler();
    }

    if (comptime std.Target.current.isDarwin() and std.Target.current.cpu.arch == .aarch64)
        nosuspend {
            // As a workaround for not having threadlocal variable support in LLD for this target,
            // we have a simpler panic implementation that does not use threadlocal variables.
            // TODO https://github.com/ziglang/zig/issues/7527
            const stderr = io.getStdErr().writer();
            if (@atomicRmw(u8, &panicking, .Add, 1, .SeqCst) == 0) {
                stderr.print("panic: " ++ format ++ "\n", args) catch os.abort();
                if (trace) |t| {
                    dumpStackTrace(t.*);
                }
                dumpCurrentStackTrace(first_trace_addr);
            } else {
                stderr.print("Panicked during a panic. Aborting.\n", .{}) catch os.abort();
            }
            os.abort();
        };

    nosuspend switch (panic_stage) {
        0 => {
            panic_stage = 1;

            _ = @atomicRmw(u8, &panicking, .Add, 1, .SeqCst);

            // Make sure to release the mutex when done
            {
                const held = panic_mutex.acquire();
                defer held.release();

                const stderr = io.getStdErr().writer();
                if (builtin.single_threaded) {
                    stderr.print("panic: ", .{}) catch os.abort();
                } else {
                    const current_thread_id = std.Thread.getCurrentThreadId();
                    stderr.print("thread {d} panic: ", .{current_thread_id}) catch os.abort();
                }
                stderr.print(format ++ "\n", args) catch os.abort();
                if (trace) |t| {
                    dumpStackTrace(t.*);
                }
                dumpCurrentStackTrace(first_trace_addr);
            }

            if (@atomicRmw(u8, &panicking, .Sub, 1, .SeqCst) != 1) {
                // Another thread is panicking, wait for the last one to finish
                // and call abort()

                // Sleep forever without hammering the CPU
                var event: std.Thread.StaticResetEvent = .{};
                event.wait();
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

const RED = "\x1b[31;1m";
const GREEN = "\x1b[32;1m";
const CYAN = "\x1b[36;1m";
const WHITE = "\x1b[37;1m";
const DIM = "\x1b[2m";
const RESET = "\x1b[0m";

pub fn writeStackTrace(
    stack_trace: builtin.StackTrace,
    out_stream: anytype,
    allocator: *mem.Allocator,
    debug_info: *DebugInfo,
    tty_config: TTY.Config,
) !void {
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

    // Negative offset of the saved BP wrt the frame pointer.
    const fp_offset = if (builtin.arch.isRISCV())
        // On RISC-V the frame pointer points to the top of the saved register
        // area, on pretty much every other architecture it points to the stack
        // slot where the previous frame pointer is saved.
        2 * @sizeOf(usize)
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
        const fp = math.sub(usize, self.fp, fp_offset) catch return null;

        // Sanity check.
        if (fp == 0 or !mem.isAligned(fp, @alignOf(usize)))
            return null;

        const new_fp = @intToPtr(*const usize, fp).*;

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
    if (builtin.os.tag == .windows) {
        return writeCurrentStackTraceWindows(out_stream, debug_info, tty_config, start_addr);
    }
    var it = StackIterator.init(start_addr, null);
    while (it.next()) |return_address| {
        try printSourceAtAddress(debug_info, out_stream, return_address - 1, tty_config);
    }
}

pub fn writeCurrentStackTraceWindows(
    out_stream: anytype,
    debug_info: *DebugInfo,
    tty_config: TTY.Config,
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
        try printSourceAtAddress(debug_info, out_stream, addr - 1, tty_config);
    }
}

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

    pub const Config = enum {
        no_color,
        escape_codes,
        // TODO give this a payload of file handle
        windows_api,

        fn setColor(conf: Config, out_stream: anytype, color: Color) void {
            nosuspend switch (conf) {
                .no_color => return,
                .escape_codes => switch (color) {
                    .Red => out_stream.writeAll(RED) catch return,
                    .Green => out_stream.writeAll(GREEN) catch return,
                    .Cyan => out_stream.writeAll(CYAN) catch return,
                    .White, .Bold => out_stream.writeAll(WHITE) catch return,
                    .Dim => out_stream.writeAll(DIM) catch return,
                    .Reset => out_stream.writeAll(RESET) catch return,
                },
                .windows_api => if (builtin.os.tag == .windows) {
                    const stderr_file = io.getStdErr();
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
                    switch (color) {
                        .Red => {
                            _ = windows.SetConsoleTextAttribute(stderr_file.handle, windows.FOREGROUND_RED | windows.FOREGROUND_INTENSITY) catch {};
                        },
                        .Green => {
                            _ = windows.SetConsoleTextAttribute(stderr_file.handle, windows.FOREGROUND_GREEN | windows.FOREGROUND_INTENSITY) catch {};
                        },
                        .Cyan => {
                            _ = windows.SetConsoleTextAttribute(stderr_file.handle, windows.FOREGROUND_GREEN | windows.FOREGROUND_BLUE | windows.FOREGROUND_INTENSITY) catch {};
                        },
                        .White, .Bold => {
                            _ = windows.SetConsoleTextAttribute(stderr_file.handle, windows.FOREGROUND_RED | windows.FOREGROUND_GREEN | windows.FOREGROUND_BLUE | windows.FOREGROUND_INTENSITY) catch {};
                        },
                        .Dim => {
                            _ = windows.SetConsoleTextAttribute(stderr_file.handle, windows.FOREGROUND_INTENSITY) catch {};
                        },
                        .Reset => {
                            _ = windows.SetConsoleTextAttribute(stderr_file.handle, S.attrs) catch {};
                        },
                    }
                } else {
                    unreachable;
                },
            };
        }
    };
};

/// TODO resources https://github.com/ziglang/zig/issues/4353
fn populateModule(di: *ModuleDebugInfo, mod: *Module) !void {
    if (mod.populated)
        return;
    const allocator = getDebugInfoAllocator();

    // At most one can be non-zero.
    if (mod.mod_info.C11ByteSize != 0 and mod.mod_info.C13ByteSize != 0)
        return error.InvalidDebugInfo;

    if (mod.mod_info.C13ByteSize == 0)
        return;

    const modi = di.pdb.getStreamById(mod.mod_info.ModuleSymStream) orelse return error.MissingDebugInfo;

    const signature = try modi.reader().readIntLittle(u32);
    if (signature != 4)
        return error.InvalidDebugInfo;

    mod.symbols = try allocator.alloc(u8, mod.mod_info.SymByteSize - 4);
    try modi.reader().readNoEof(mod.symbols);

    mod.subsect_info = try allocator.alloc(u8, mod.mod_info.C13ByteSize);
    try modi.reader().readNoEof(mod.subsect_info);

    var sect_offset: usize = 0;
    var skip_len: usize = undefined;
    while (sect_offset != mod.subsect_info.len) : (sect_offset += skip_len) {
        const subsect_hdr = @ptrCast(*pdb.DebugSubsectionHeader, &mod.subsect_info[sect_offset]);
        skip_len = subsect_hdr.Length;
        sect_offset += @sizeOf(pdb.DebugSubsectionHeader);

        switch (subsect_hdr.Kind) {
            .FileChecksums => {
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

/// TODO resources https://github.com/ziglang/zig/issues/4353
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

    const symbol_info = try module.getSymbolAtAddress(address);
    defer symbol_info.deinit();

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
        tty_config.setColor(out_stream, .White);

        if (line_info) |*li| {
            try out_stream.print("{s}:{d}:{d}", .{ li.file_name, li.line, li.column });
        } else {
            try out_stream.writeAll("???:?:?");
        }

        tty_config.setColor(out_stream, .Reset);
        try out_stream.writeAll(": ");
        tty_config.setColor(out_stream, .Dim);
        try out_stream.print("0x{x} in {s} ({s})", .{ address, symbol_name, compile_unit_name });
        tty_config.setColor(out_stream, .Reset);
        try out_stream.writeAll("\n");

        // Show the matching source code line if possible
        if (line_info) |li| {
            if (printLineFromFile(out_stream, li)) {
                if (li.column > 0) {
                    // The caret already takes one char
                    const space_needed = @intCast(usize, li.column - 1);

                    try out_stream.writeByteNTimes(' ', space_needed);
                    tty_config.setColor(out_stream, .Green);
                    try out_stream.writeAll("^");
                    tty_config.setColor(out_stream, .Reset);
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

// TODO use this
pub const OpenSelfDebugInfoError = error{
    MissingDebugInfo,
    OutOfMemory,
    UnsupportedOperatingSystem,
};

/// TODO resources https://github.com/ziglang/zig/issues/4353
pub fn openSelfDebugInfo(allocator: *mem.Allocator) anyerror!DebugInfo {
    nosuspend {
        if (builtin.strip_debug_info)
            return error.MissingDebugInfo;
        if (@hasDecl(root, "os") and @hasDecl(root.os, "debug") and @hasDecl(root.os.debug, "openSelfDebugInfo")) {
            return root.os.debug.openSelfDebugInfo(allocator);
        }
        switch (builtin.os.tag) {
            .linux,
            .freebsd,
            .netbsd,
            .dragonfly,
            .openbsd,
            .macos,
            .windows,
            => return DebugInfo.init(allocator),
            else => return error.UnsupportedDebugInfo,
        }
    }
}

/// This takes ownership of coff_file: users of this function should not close
/// it themselves, even on error.
/// TODO resources https://github.com/ziglang/zig/issues/4353
/// TODO it's weird to take ownership even on error, rework this code.
fn readCoffDebugInfo(allocator: *mem.Allocator, coff_file: File) !ModuleDebugInfo {
    nosuspend {
        errdefer coff_file.close();

        const coff_obj = try allocator.create(coff.Coff);
        coff_obj.* = coff.Coff.init(allocator, coff_file);

        var di = ModuleDebugInfo{
            .base_address = undefined,
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
        const version = try pdb_stream.reader().readIntLittle(u32);
        const signature = try pdb_stream.reader().readIntLittle(u32);
        const age = try pdb_stream.reader().readIntLittle(u32);
        var guid: [16]u8 = undefined;
        try pdb_stream.reader().readNoEof(&guid);
        if (version != 20000404) // VC70, only value observed by LLVM team
            return error.UnknownPDBVersion;
        if (!mem.eql(u8, &di.coff.guid, &guid) or di.coff.age != age)
            return error.PDBMismatch;
        // We validated the executable and pdb match.

        const string_table_index = str_tab_index: {
            const name_bytes_len = try pdb_stream.reader().readIntLittle(u32);
            const name_bytes = try allocator.alloc(u8, name_bytes_len);
            try pdb_stream.reader().readNoEof(name_bytes);

            const HashTableHeader = packed struct {
                Size: u32,
                Capacity: u32,

                fn maxLoad(cap: u32) u32 {
                    return cap * 2 / 3 + 1;
                }
            };
            const hash_tbl_hdr = try pdb_stream.reader().readStruct(HashTableHeader);
            if (hash_tbl_hdr.Capacity == 0)
                return error.InvalidDebugInfo;

            if (hash_tbl_hdr.Size > HashTableHeader.maxLoad(hash_tbl_hdr.Capacity))
                return error.InvalidDebugInfo;

            const present = try readSparseBitVector(&pdb_stream.reader(), allocator);
            if (present.len != hash_tbl_hdr.Size)
                return error.InvalidDebugInfo;
            const deleted = try readSparseBitVector(&pdb_stream.reader(), allocator);

            const Bucket = struct {
                first: u32,
                second: u32,
            };
            const bucket_list = try allocator.alloc(Bucket, present.len);
            for (present) |_| {
                const name_offset = try pdb_stream.reader().readIntLittle(u32);
                const name_index = try pdb_stream.reader().readIntLittle(u32);
                const name = mem.spanZ(std.meta.assumeSentinel(name_bytes.ptr + name_offset, 0));
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
        const dbi_stream_header = try dbi.reader().readStruct(pdb.DbiStreamHeader);
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
            const mod_info = try dbi.reader().readStruct(pdb.ModInfo);
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
            const ver = @intToEnum(pdb.SectionContrSubstreamVersion, try dbi.reader().readIntLittle(u32));
            if (ver != pdb.SectionContrSubstreamVersion.Ver60)
                return error.InvalidDebugInfo;
            sect_cont_offset += @sizeOf(u32);
        }
        while (sect_cont_offset != section_contrib_size) {
            const entry = try sect_contribs.addOne();
            entry.* = try dbi.reader().readStruct(pdb.SectionContribEntry);
            sect_cont_offset += @sizeOf(pdb.SectionContribEntry);

            if (sect_cont_offset > section_contrib_size)
                return error.InvalidDebugInfo;
        }

        di.sect_contribs = sect_contribs.toOwnedSlice();

        return di;
    }
}

fn readSparseBitVector(stream: anytype, allocator: *mem.Allocator) ![]usize {
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

fn chopSlice(ptr: []const u8, offset: u64, size: u64) ![]const u8 {
    const start = try math.cast(usize, offset);
    const end = start + try math.cast(usize, size);
    return ptr[start..end];
}

/// This takes ownership of elf_file: users of this function should not close
/// it themselves, even on error.
/// TODO resources https://github.com/ziglang/zig/issues/4353
/// TODO it's weird to take ownership even on error, rework this code.
pub fn readElfDebugInfo(allocator: *mem.Allocator, elf_file: File) !ModuleDebugInfo {
    nosuspend {
        const mapped_mem = try mapWholeFile(elf_file);
        const hdr = @ptrCast(*const elf.Ehdr, &mapped_mem[0]);
        if (!mem.eql(u8, hdr.e_ident[0..4], "\x7fELF")) return error.InvalidElfMagic;
        if (hdr.e_ident[elf.EI_VERSION] != 1) return error.InvalidElfVersion;

        const endian: builtin.Endian = switch (hdr.e_ident[elf.EI_DATA]) {
            elf.ELFDATA2LSB => .Little,
            elf.ELFDATA2MSB => .Big,
            else => return error.InvalidElfEndian,
        };
        assert(endian == std.builtin.endian); // this is our own debug info

        const shoff = hdr.e_shoff;
        const str_section_off = shoff + @as(u64, hdr.e_shentsize) * @as(u64, hdr.e_shstrndx);
        const str_shdr = @ptrCast(
            *const elf.Shdr,
            @alignCast(@alignOf(elf.Shdr), &mapped_mem[try math.cast(usize, str_section_off)]),
        );
        const header_strings = mapped_mem[str_shdr.sh_offset .. str_shdr.sh_offset + str_shdr.sh_size];
        const shdrs = @ptrCast(
            [*]const elf.Shdr,
            @alignCast(@alignOf(elf.Shdr), &mapped_mem[shoff]),
        )[0..hdr.e_shnum];

        var opt_debug_info: ?[]const u8 = null;
        var opt_debug_abbrev: ?[]const u8 = null;
        var opt_debug_str: ?[]const u8 = null;
        var opt_debug_line: ?[]const u8 = null;
        var opt_debug_ranges: ?[]const u8 = null;

        for (shdrs) |*shdr| {
            if (shdr.sh_type == elf.SHT_NULL) continue;

            const name = std.mem.span(std.meta.assumeSentinel(header_strings[shdr.sh_name..].ptr, 0));
            if (mem.eql(u8, name, ".debug_info")) {
                opt_debug_info = try chopSlice(mapped_mem, shdr.sh_offset, shdr.sh_size);
            } else if (mem.eql(u8, name, ".debug_abbrev")) {
                opt_debug_abbrev = try chopSlice(mapped_mem, shdr.sh_offset, shdr.sh_size);
            } else if (mem.eql(u8, name, ".debug_str")) {
                opt_debug_str = try chopSlice(mapped_mem, shdr.sh_offset, shdr.sh_size);
            } else if (mem.eql(u8, name, ".debug_line")) {
                opt_debug_line = try chopSlice(mapped_mem, shdr.sh_offset, shdr.sh_size);
            } else if (mem.eql(u8, name, ".debug_ranges")) {
                opt_debug_ranges = try chopSlice(mapped_mem, shdr.sh_offset, shdr.sh_size);
            }
        }

        var di = DW.DwarfInfo{
            .endian = endian,
            .debug_info = opt_debug_info orelse return error.MissingDebugInfo,
            .debug_abbrev = opt_debug_abbrev orelse return error.MissingDebugInfo,
            .debug_str = opt_debug_str orelse return error.MissingDebugInfo,
            .debug_line = opt_debug_line orelse return error.MissingDebugInfo,
            .debug_ranges = opt_debug_ranges,
        };

        try DW.openDwarfDebugInfo(&di, allocator);

        return ModuleDebugInfo{
            .base_address = undefined,
            .dwarf = di,
            .mapped_memory = mapped_mem,
        };
    }
}

/// TODO resources https://github.com/ziglang/zig/issues/4353
/// This takes ownership of coff_file: users of this function should not close
/// it themselves, even on error.
/// TODO it's weird to take ownership even on error, rework this code.
fn readMachODebugInfo(allocator: *mem.Allocator, macho_file: File) !ModuleDebugInfo {
    const mapped_mem = try mapWholeFile(macho_file);

    const hdr = @ptrCast(
        *const macho.mach_header_64,
        @alignCast(@alignOf(macho.mach_header_64), mapped_mem.ptr),
    );
    if (hdr.magic != macho.MH_MAGIC_64)
        return error.InvalidDebugInfo;

    const hdr_base = @ptrCast([*]const u8, hdr);
    var ptr = hdr_base + @sizeOf(macho.mach_header_64);
    var ncmd: u32 = hdr.ncmds;
    const symtab = while (ncmd != 0) : (ncmd -= 1) {
        const lc = @ptrCast(*const std.macho.load_command, ptr);
        switch (lc.cmd) {
            std.macho.LC_SYMTAB => break @ptrCast(*const std.macho.symtab_command, ptr),
            else => {},
        }
        ptr = @alignCast(@alignOf(std.macho.load_command), ptr + lc.cmdsize);
    } else {
        return error.MissingDebugInfo;
    };
    const syms = @ptrCast([*]const macho.nlist_64, @alignCast(@alignOf(macho.nlist_64), hdr_base + symtab.symoff))[0..symtab.nsyms];
    const strings = @ptrCast([*]const u8, hdr_base + symtab.stroff)[0 .. symtab.strsize - 1 :0];

    const symbols_buf = try allocator.alloc(MachoSymbol, syms.len);

    var ofile: ?*const macho.nlist_64 = null;
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
    nlist: *const macho.nlist_64,
    ofile: ?*const macho.nlist_64,
    reloc: u64,

    /// Returns the address from the macho file
    fn address(self: MachoSymbol) u64 {
        return self.nlist.n_value;
    }

    fn addressLessThan(context: void, lhs: MachoSymbol, rhs: MachoSymbol) bool {
        return lhs.address() < rhs.address();
    }
};

/// `file` is expected to have been opened with .intended_io_mode == .blocking.
/// Takes ownership of file, even on error.
/// TODO it's weird to take ownership even on error, rework this code.
fn mapWholeFile(file: File) ![]align(mem.page_size) const u8 {
    nosuspend {
        defer file.close();

        const file_len = try math.cast(usize, try file.getEndPos());
        const mapped_mem = try os.mmap(
            null,
            file_len,
            os.PROT_READ,
            os.MAP_SHARED,
            file.handle,
            0,
        );
        errdefer os.munmap(mapped_mem);

        return mapped_mem;
    }
}

pub const DebugInfo = struct {
    allocator: *mem.Allocator,
    address_map: std.AutoHashMap(usize, *ModuleDebugInfo),

    pub fn init(allocator: *mem.Allocator) DebugInfo {
        return DebugInfo{
            .allocator = allocator,
            .address_map = std.AutoHashMap(usize, *ModuleDebugInfo).init(allocator),
        };
    }

    pub fn deinit(self: *DebugInfo) void {
        // TODO: resources https://github.com/ziglang/zig/issues/4353
        self.address_map.deinit();
    }

    pub fn getModuleForAddress(self: *DebugInfo, address: usize) !*ModuleDebugInfo {
        if (comptime std.Target.current.isDarwin()) {
            return self.lookupModuleDyld(address);
        } else if (builtin.os.tag == .windows) {
            return self.lookupModuleWin32(address);
        } else if (builtin.os.tag == .haiku) {
            return self.lookupModuleHaiku(address);
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
            // The array of load commands is right after the header
            var cmd_ptr = @intToPtr([*]u8, @ptrToInt(header) + @sizeOf(macho.mach_header_64));

            var cmds = header.ncmds;
            while (cmds != 0) : (cmds -= 1) {
                const lc = @ptrCast(
                    *macho.load_command,
                    @alignCast(@alignOf(macho.load_command), cmd_ptr),
                );
                cmd_ptr += lc.cmdsize;
                if (lc.cmd != macho.LC_SEGMENT_64) continue;

                const segment_cmd = @ptrCast(
                    *const std.macho.segment_command_64,
                    @alignCast(@alignOf(std.macho.segment_command_64), lc),
                );

                const rebased_address = address - base_address;
                const seg_start = segment_cmd.vmaddr;
                const seg_end = seg_start + segment_cmd.vmsize;

                if (rebased_address >= seg_start and rebased_address < seg_end) {
                    if (self.address_map.get(base_address)) |obj_di| {
                        return obj_di;
                    }

                    const obj_di = try self.allocator.create(ModuleDebugInfo);
                    errdefer self.allocator.destroy(obj_di);

                    const macho_path = mem.spanZ(std.c._dyld_get_image_name(i));
                    const macho_file = fs.cwd().openFile(macho_path, .{ .intended_io_mode = .blocking }) catch |err| switch (err) {
                        error.FileNotFound => return error.MissingDebugInfo,
                        else => return err,
                    };
                    obj_di.* = try readMachODebugInfo(self.allocator, macho_file);
                    obj_di.base_address = base_address;

                    try self.address_map.putNoClobber(base_address, obj_di);

                    return obj_di;
                }
            }
        }

        return error.MissingDebugInfo;
    }

    fn lookupModuleWin32(self: *DebugInfo, address: usize) !*ModuleDebugInfo {
        const process_handle = windows.kernel32.GetCurrentProcess();

        // Find how many modules are actually loaded
        var dummy: windows.HMODULE = undefined;
        var bytes_needed: windows.DWORD = undefined;
        if (windows.kernel32.K32EnumProcessModules(
            process_handle,
            @ptrCast([*]windows.HMODULE, &dummy),
            0,
            &bytes_needed,
        ) == 0)
            return error.MissingDebugInfo;

        const needed_modules = bytes_needed / @sizeOf(windows.HMODULE);

        // Fetch the complete module list
        var modules = try self.allocator.alloc(windows.HMODULE, needed_modules);
        defer self.allocator.free(modules);
        if (windows.kernel32.K32EnumProcessModules(
            process_handle,
            modules.ptr,
            try math.cast(windows.DWORD, modules.len * @sizeOf(windows.HMODULE)),
            &bytes_needed,
        ) == 0)
            return error.MissingDebugInfo;

        // There's an unavoidable TOCTOU problem here, the module list may have
        // changed between the two EnumProcessModules call.
        // Pick the smallest amount of elements to avoid processing garbage.
        const needed_modules_after = bytes_needed / @sizeOf(windows.HMODULE);
        const loaded_modules = math.min(needed_modules, needed_modules_after);

        for (modules[0..loaded_modules]) |module| {
            var info: windows.MODULEINFO = undefined;
            if (windows.kernel32.K32GetModuleInformation(
                process_handle,
                module,
                &info,
                @sizeOf(@TypeOf(info)),
            ) == 0)
                return error.MissingDebugInfo;

            const seg_start = @ptrToInt(info.lpBaseOfDll);
            const seg_end = seg_start + info.SizeOfImage;

            if (address >= seg_start and address < seg_end) {
                if (self.address_map.get(seg_start)) |obj_di| {
                    return obj_di;
                }

                var name_buffer: [windows.PATH_MAX_WIDE + 4:0]u16 = undefined;
                // openFileAbsoluteW requires the prefix to be present
                mem.copy(u16, name_buffer[0..4], &[_]u16{ '\\', '?', '?', '\\' });
                const len = windows.kernel32.K32GetModuleFileNameExW(
                    process_handle,
                    module,
                    @ptrCast(windows.LPWSTR, &name_buffer[4]),
                    windows.PATH_MAX_WIDE,
                );
                assert(len > 0);

                const obj_di = try self.allocator.create(ModuleDebugInfo);
                errdefer self.allocator.destroy(obj_di);

                const coff_file = fs.openFileAbsoluteW(name_buffer[0 .. len + 4 :0], .{}) catch |err| switch (err) {
                    error.FileNotFound => return error.MissingDebugInfo,
                    else => return err,
                };
                obj_di.* = try readCoffDebugInfo(self.allocator, coff_file);
                obj_di.base_address = seg_start;

                try self.address_map.putNoClobber(seg_start, obj_di);

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

        if (os.dl_iterate_phdr(&ctx, anyerror, struct {
            fn callback(info: *os.dl_phdr_info, size: usize, context: *CtxTy) !void {
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
                        context.name = mem.spanZ(info.dlpi_name) orelse "";
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
            else => return error.MissingDebugInfo,
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
        @panic("TODO implement lookup module for Haiku");
    }
};

const SymbolInfo = struct {
    symbol_name: []const u8 = "???",
    compile_unit_name: []const u8 = "???",
    line_info: ?LineInfo = null,

    fn deinit(self: @This()) void {
        if (self.line_info) |li| {
            li.deinit();
        }
    }
};

pub const ModuleDebugInfo = switch (builtin.os.tag) {
    .macos, .ios, .watchos, .tvos => struct {
        base_address: usize,
        mapped_memory: []const u8,
        symbols: []const MachoSymbol,
        strings: [:0]const u8,
        ofiles: OFileTable,

        const OFileTable = std.StringHashMap(DW.DwarfInfo);

        pub fn allocator(self: @This()) *mem.Allocator {
            return self.ofiles.allocator;
        }

        fn loadOFile(self: *@This(), o_file_path: []const u8) !DW.DwarfInfo {
            const o_file = try fs.cwd().openFile(o_file_path, .{ .intended_io_mode = .blocking });
            const mapped_mem = try mapWholeFile(o_file);

            const hdr = @ptrCast(
                *const macho.mach_header_64,
                @alignCast(@alignOf(macho.mach_header_64), mapped_mem.ptr),
            );
            if (hdr.magic != std.macho.MH_MAGIC_64)
                return error.InvalidDebugInfo;

            const hdr_base = @ptrCast([*]const u8, hdr);
            var ptr = hdr_base + @sizeOf(macho.mach_header_64);
            var ncmd: u32 = hdr.ncmds;
            const segcmd = while (ncmd != 0) : (ncmd -= 1) {
                const lc = @ptrCast(*const std.macho.load_command, ptr);
                switch (lc.cmd) {
                    std.macho.LC_SEGMENT_64 => {
                        break @ptrCast(
                            *const std.macho.segment_command_64,
                            @alignCast(@alignOf(std.macho.segment_command_64), ptr),
                        );
                    },
                    else => {},
                }
                ptr = @alignCast(@alignOf(std.macho.load_command), ptr + lc.cmdsize);
            } else {
                return error.MissingDebugInfo;
            };

            var opt_debug_line: ?*const macho.section_64 = null;
            var opt_debug_info: ?*const macho.section_64 = null;
            var opt_debug_abbrev: ?*const macho.section_64 = null;
            var opt_debug_str: ?*const macho.section_64 = null;
            var opt_debug_ranges: ?*const macho.section_64 = null;

            const sections = @ptrCast(
                [*]const macho.section_64,
                @alignCast(@alignOf(macho.section_64), ptr + @sizeOf(std.macho.segment_command_64)),
            )[0..segcmd.nsects];
            for (sections) |*sect| {
                // The section name may not exceed 16 chars and a trailing null may
                // not be present
                const name = if (mem.indexOfScalar(u8, sect.sectname[0..], 0)) |last|
                    sect.sectname[0..last]
                else
                    sect.sectname[0..];

                if (mem.eql(u8, name, "__debug_line")) {
                    opt_debug_line = sect;
                } else if (mem.eql(u8, name, "__debug_info")) {
                    opt_debug_info = sect;
                } else if (mem.eql(u8, name, "__debug_abbrev")) {
                    opt_debug_abbrev = sect;
                } else if (mem.eql(u8, name, "__debug_str")) {
                    opt_debug_str = sect;
                } else if (mem.eql(u8, name, "__debug_ranges")) {
                    opt_debug_ranges = sect;
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
                .debug_line = try chopSlice(mapped_mem, debug_line.offset, debug_line.size),
                .debug_ranges = if (opt_debug_ranges) |debug_ranges|
                    try chopSlice(mapped_mem, debug_ranges.offset, debug_ranges.size)
                else
                    null,
            };

            try DW.openDwarfDebugInfo(&di, self.allocator());

            // Add the debug info to the cache
            try self.ofiles.putNoClobber(o_file_path, di);

            return di;
        }

        pub fn getSymbolAtAddress(self: *@This(), address: usize) !SymbolInfo {
            nosuspend {
                // Translate the VA into an address into this object
                const relocated_address = address - self.base_address;
                assert(relocated_address >= 0x100000000);

                // Find the .o file where this symbol is defined
                const symbol = machoSearchSymbols(self.symbols, relocated_address) orelse
                    return SymbolInfo{};

                // Take the symbol name from the N_FUN STAB entry, we're going to
                // use it if we fail to find the DWARF infos
                const stab_symbol = mem.spanZ(self.strings[symbol.nlist.n_strx..]);

                if (symbol.ofile == null)
                    return SymbolInfo{ .symbol_name = stab_symbol };

                const o_file_path = mem.spanZ(self.strings[symbol.ofile.?.n_strx..]);

                // Check if its debug infos are already in the cache
                var o_file_di = self.ofiles.get(o_file_path) orelse
                    (self.loadOFile(o_file_path) catch |err| switch (err) {
                    error.FileNotFound,
                    error.MissingDebugInfo,
                    error.InvalidDebugInfo,
                    => {
                        return SymbolInfo{ .symbol_name = stab_symbol };
                    },
                    else => return err,
                });

                // Translate again the address, this time into an address inside the
                // .o file
                const relocated_address_o = relocated_address - symbol.reloc;

                if (o_file_di.findCompileUnit(relocated_address_o)) |compile_unit| {
                    return SymbolInfo{
                        .symbol_name = o_file_di.getSymbolName(relocated_address_o) orelse "???",
                        .compile_unit_name = compile_unit.die.getAttrString(&o_file_di, DW.AT_name) catch |err| switch (err) {
                            error.MissingDebugInfo, error.InvalidDebugInfo => "???",
                            else => return err,
                        },
                        .line_info = o_file_di.getLineNumberInfo(compile_unit.*, relocated_address_o) catch |err| switch (err) {
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
        pdb: pdb.Pdb,
        coff: *coff.Coff,
        sect_contribs: []pdb.SectionContribEntry,
        modules: []Module,

        pub fn allocator(self: @This()) *mem.Allocator {
            return self.coff.allocator;
        }

        pub fn getSymbolAtAddress(self: *@This(), address: usize) !SymbolInfo {
            // Translate the VA into an address into this object
            const relocated_address = address - self.base_address;

            var coff_section: *coff.Section = undefined;
            const mod_index = for (self.sect_contribs) |sect_contrib| {
                if (sect_contrib.Section > self.coff.sections.items.len) continue;
                // Remember that SectionContribEntry.Section is 1-based.
                coff_section = &self.coff.sections.items[sect_contrib.Section - 1];

                const vaddr_start = coff_section.header.virtual_address + sect_contrib.Offset;
                const vaddr_end = vaddr_start + sect_contrib.Size;
                if (relocated_address >= vaddr_start and relocated_address < vaddr_end) {
                    break sect_contrib.ModuleIndex;
                }
            } else {
                // we have no information to add to the address
                return SymbolInfo{};
            };

            const mod = &self.modules[mod_index];
            try populateModule(self, mod);
            const obj_basename = fs.path.basename(mod.obj_file_name);

            var symbol_i: usize = 0;
            const symbol_name = if (!mod.populated) "???" else while (symbol_i != mod.symbols.len) {
                const prefix = @ptrCast(*pdb.RecordPrefix, &mod.symbols[symbol_i]);
                if (prefix.RecordLen < 2)
                    return error.InvalidDebugInfo;
                switch (prefix.RecordKind) {
                    .S_LPROC32, .S_GPROC32 => {
                        const proc_sym = @ptrCast(*pdb.ProcSym, &mod.symbols[symbol_i + @sizeOf(pdb.RecordPrefix)]);
                        const vaddr_start = coff_section.header.virtual_address + proc_sym.CodeOffset;
                        const vaddr_end = vaddr_start + proc_sym.CodeSize;
                        if (relocated_address >= vaddr_start and relocated_address < vaddr_end) {
                            break mem.spanZ(@ptrCast([*:0]u8, proc_sym) + @sizeOf(pdb.ProcSym));
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
                        .Lines => {
                            var line_index = sect_offset;

                            const line_hdr = @ptrCast(*pdb.LineFragmentHeader, &subsect_info[line_index]);
                            if (line_hdr.RelocSegment == 0)
                                return error.MissingDebugInfo;
                            line_index += @sizeOf(pdb.LineFragmentHeader);
                            const frag_vaddr_start = coff_section.header.virtual_address + line_hdr.RelocOffset;
                            const frag_vaddr_end = frag_vaddr_start + line_hdr.CodeSize;

                            if (relocated_address >= frag_vaddr_start and relocated_address < frag_vaddr_end) {
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
                                    // Heuristic: we want to find the last line entry
                                    // that has a vaddr_start <= relocated_address.
                                    // This is done with a simple linear search.
                                    var line_i: u32 = 0;
                                    while (line_i < block_hdr.NumLines) : (line_i += 1) {
                                        const line_num_entry = @ptrCast(*pdb.LineNumberEntry, &subsect_info[line_index]);
                                        line_index += @sizeOf(pdb.LineNumberEntry);

                                        const vaddr_start = frag_vaddr_start + line_num_entry.Offset;
                                        if (relocated_address < vaddr_start) {
                                            break;
                                        }
                                    }

                                    // line_i == 0 would mean that no matching LineNumberEntry was found.
                                    if (line_i > 0) {
                                        const subsect_index = checksum_offset + block_hdr.NameIndex;
                                        const chksum_hdr = @ptrCast(*pdb.FileChecksumEntryHeader, &mod.subsect_info[subsect_index]);
                                        const strtab_offset = @sizeOf(pdb.PDBStringTableHeader) + chksum_hdr.FileNameOffset;
                                        try self.pdb.string_table.seekTo(strtab_offset);
                                        const source_file_name = try self.pdb.string_table.readNullTermString(self.allocator());

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
                                            .allocator = self.allocator(),
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

            return SymbolInfo{
                .symbol_name = symbol_name,
                .compile_unit_name = obj_basename,
                .line_info = opt_line_info,
            };
        }
    },
    .linux, .netbsd, .freebsd, .dragonfly, .openbsd => struct {
        base_address: usize,
        dwarf: DW.DwarfInfo,
        mapped_memory: []const u8,

        pub fn getSymbolAtAddress(self: *@This(), address: usize) !SymbolInfo {
            // Translate the VA into an address into this object
            const relocated_address = address - self.base_address;

            if (nosuspend self.dwarf.findCompileUnit(relocated_address)) |compile_unit| {
                return SymbolInfo{
                    .symbol_name = nosuspend self.dwarf.getSymbolName(relocated_address) orelse "???",
                    .compile_unit_name = compile_unit.die.getAttrString(&self.dwarf, DW.AT_name) catch |err| switch (err) {
                        error.MissingDebugInfo, error.InvalidDebugInfo => "???",
                        else => return err,
                    },
                    .line_info = nosuspend self.dwarf.getLineNumberInfo(compile_unit.*, relocated_address) catch |err| switch (err) {
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

            unreachable;
        }
    },
    else => DW.DwarfInfo,
};

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

    // Don't use std.debug.print() as stderr_mutex may still be locked.
    nosuspend {
        const stderr = io.getStdErr().writer();
        _ = switch (sig) {
            os.SIGSEGV => stderr.print("Segmentation fault at address 0x{x}\n", .{addr}),
            os.SIGILL => stderr.print("Illegal instruction at address 0x{x}\n", .{addr}),
            os.SIGBUS => stderr.print("Bus error at address 0x{x}\n", .{addr}),
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
    std.debug.warn("{} sp = 0x{x}\n", .{ prefix, sp });
}
