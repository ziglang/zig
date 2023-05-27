const std = @import("std.zig");
const builtin = @import("builtin");
const math = std.math;
const mem = std.mem;
const io = std.io;
const os = std.os;
const fs = std.fs;
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

pub const StackTraceContext = blk: {
    if (native_os == .windows) {
        break :blk @typeInfo(@TypeOf(os.windows.CONTEXT.getRegs)).Fn.return_type.?;
    } else if (@hasDecl(os.system, "ucontext_t")) {
        break :blk *const os.ucontext_t;
    } else {
        break :blk void;
    }
};

/// Tries to print the stack trace starting from the supplied base pointer to stderr,
/// unbuffered, and ignores any error returned.
/// TODO multithreaded awareness
pub fn dumpStackTraceFromBase(context: StackTraceContext) void {
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
            writeCurrentStackTraceWindows(stderr, debug_info, tty_config, context.ip) catch return;
            return;
        }

        var it = StackIterator.initWithContext(null, debug_info, context) catch return;
        printSourceAtAddress(debug_info, stderr, it.dwarf_context.pc, tty_config) catch return;

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
        const end_index = @min(first_index + addrs.len, n);
        const slice = addr_buf[first_index..end_index];
        // We use a for loop here because slice and addrs may alias.
        for (slice, 0..) |addr, i| {
            addrs[i] = addr;
        }
        stack_trace.index = slice.len;
    } else {
        // TODO: This should use the dwarf unwinder if it's available
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
        writeStackTrace(stack_trace, stderr, getDebugInfoAllocator(), debug_info, io.tty.detectConfig(io.getStdErr())) catch |err| {
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
        error.NoSpaceLeft => blk: {
            @memcpy(buf[size..], trunc_msg);
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

    // Note there is similar logic in handleSegfaultPosix and handleSegfaultWindowsExtra.
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

            waitForOtherThreadToFinishPanicking();
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

/// Must be called only after adding 1 to `panicking`. There are three callsites.
fn waitForOtherThreadToFinishPanicking() void {
    if (panicking.fetchSub(1, .SeqCst) != 1) {
        // Another thread is panicking, wait for the last one to finish
        // and call abort()
        if (builtin.single_threaded) unreachable;

        // Sleep forever without hammering the CPU
        var futex = std.atomic.Atomic(u32).init(0);
        while (true) std.Thread.Futex.wait(&futex, 0);
        unreachable;
    }
}

pub fn writeStackTrace(
    stack_trace: std.builtin.StackTrace,
    out_stream: anytype,
    allocator: mem.Allocator,
    debug_info: *DebugInfo,
    tty_config: io.tty.Config,
) !void {
    _ = allocator;
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

pub const StackIterator = struct {
    // Skip every frame before this address is found.
    first_address: ?usize,
    // Last known value of the frame pointer register.
    fp: usize,

    // When DebugInfo and a register context is available, this iterator can unwind
    // stacks with frames that don't use a frame pointer (ie. -fomit-frame-pointer).
    debug_info: ?*DebugInfo,
    dwarf_context: if (supports_context) DW.UnwindContext else void = undefined,
    const supports_context = @hasDecl(os.system, "ucontext_t") and
        (builtin.os.tag != .linux or switch (builtin.cpu.arch) {
        .mips, .mipsel, .mips64, .mips64el, .riscv64 => false,
        else => true,
    });

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
            .debug_info = null,
        };
    }

    pub fn initWithContext(first_address: ?usize, debug_info: *DebugInfo, context: *const os.ucontext_t) !StackIterator {
        var iterator = init(first_address, null);
        iterator.debug_info = debug_info;
        iterator.dwarf_context = try DW.UnwindContext.init(context);
        return iterator;
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

        const aligned_address = address & ~@as(usize, @intCast((mem.page_size - 1)));
        const aligned_memory = @as([*]align(mem.page_size) u8, @ptrFromInt(aligned_address))[0..mem.page_size];

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

    fn next_dwarf(self: *StackIterator) !void {
        const module = try self.debug_info.?.getModuleForAddress(self.dwarf_context.pc);
        if (try module.getDwarfInfoForAddress(self.debug_info.?.allocator, self.dwarf_context.pc)) |di| {
            self.dwarf_context.reg_ctx.eh_frame = true;
            self.dwarf_context.reg_ctx.is_macho = di.is_macho;
            try di.unwindFrame(self.debug_info.?.allocator, &self.dwarf_context, module.base_address);
        } else return error.MissingDebugInfo;
    }

    fn next_internal(self: *StackIterator) ?usize {
        if (supports_context and self.debug_info != null) {
            if (self.next_dwarf()) |_| {
                return self.dwarf_context.pc;
            } else |err| {
                if (err != error.MissingFDE) print("DWARF unwind error: {}\n", .{err});

                // Fall back to fp unwinding on the first failure,
                // as the register context won't be updated

                // TODO: Could still attempt dwarf unwinding after this, maybe marking non-updated registers as
                //       invalid, so the unwind only fails if it requires out of date registers?

                self.fp = self.dwarf_context.getFp() catch 0;
                self.debug_info = null;
            }
        }

        const fp = if (comptime native_arch.isSPARC())
            // On SPARC the offset is positive. (!)
            math.add(usize, self.fp, fp_offset) catch return null
        else
            math.sub(usize, self.fp, fp_offset) catch return null;

        // Sanity check.
        if (fp == 0 or !mem.isAligned(fp, @alignOf(usize)) or !isValidMemory(fp))
            return null;

        const new_fp = math.add(usize, @as(*const usize, @ptrFromInt(fp)).*, fp_bias) catch return null;

        // Sanity check: the stack grows down thus all the parent frames must be
        // be at addresses that are greater (or equal) than the previous one.
        // A zero frame pointer often signals this is the last frame, that case
        // is gracefully handled by the next call to next_internal.
        if (new_fp != 0 and new_fp < self.fp)
            return null;

        const new_pc = @as(
            *const usize,
            @ptrFromInt(math.add(usize, fp, pc_offset) catch return null),
        ).*;

        self.fp = new_fp;

        return new_pc;
    }
};

pub fn writeCurrentStackTrace(
    out_stream: anytype,
    debug_info: *DebugInfo,
    tty_config: io.tty.Config,
    start_addr: ?usize,
) !void {
    if (native_os == .windows) {
        return writeCurrentStackTraceWindows(out_stream, debug_info, tty_config, start_addr);
    }

    // TODO: Capture a context and use initWithContext
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
        return windows.ntdll.RtlCaptureStackBackTrace(0, addresses.len, @as(**anyopaque, @ptrCast(addresses.ptr)), null);
    }

    const tib = @as(*const windows.NT_TIB, @ptrCast(&windows.teb().Reserved1));

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
            context.setIp(@as(*u64, @ptrFromInt(current_regs.sp)).*);
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

pub fn writeCurrentStackTraceWindows(
    out_stream: anytype,
    debug_info: *DebugInfo,
    tty_config: io.tty.Config,
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

fn printUnknownSource(debug_info: *DebugInfo, out_stream: anytype, address: usize, tty_config: io.tty.Config) !void {
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

pub fn printSourceAtAddress(debug_info: *DebugInfo, out_stream: anytype, address: usize, tty_config: io.tty.Config) !void {
    const module = debug_info.getModuleForAddress(address) catch |err| switch (err) {
        error.MissingDebugInfo, error.InvalidDebugInfo => return printUnknownSource(debug_info, out_stream, address, tty_config),
        else => {
            return err;
        },
    };

    const symbol_info = module.getSymbolAtAddress(debug_info.allocator, address) catch |err| switch (err) {
        error.MissingDebugInfo, error.InvalidDebugInfo => return printUnknownSource(debug_info, out_stream, address, tty_config),
        else => {
            return err;
        },
    };
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
    tty_config: io.tty.Config,
    comptime printLineFromFile: anytype,
) !void {
    nosuspend {
        try tty_config.setColor(out_stream, .bold);

        if (line_info) |*li| {
            try out_stream.print("{s}:{d}:{d}", .{ li.file_name, li.line, li.column });
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
        if (line_info) |li| {
            if (printLineFromFile(out_stream, li)) {
                if (li.column > 0) {
                    // The caret already takes one char
                    const space_needed = @as(usize, @intCast(li.column - 1));

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

            var sections: DW.DwarfInfo.SectionArray = DW.DwarfInfo.null_section_array;
            errdefer for (sections) |section| if (section) |s| if (s.owned) allocator.free(s.data);

            inline for (@typeInfo(DW.DwarfSection).Enum.fields, 0..) |section, i| {
                sections[i] = .{
                    .data = try coff_obj.getSectionDataAlloc("." ++ section.name, allocator),
                    .owned = true,
                };
            }

            var dwarf = DW.DwarfInfo{
                .endian = native_endian,
                .sections = sections,
                .is_macho = false,
            };

            try DW.openDwarfDebugInfo(&dwarf, allocator, coff_bytes);
            di.debug_data = PdbOrDwarf{ .dwarf = dwarf };
            return di;
        }

        // Only used by pdb path
        di.coff_section_headers = try coff_obj.getSectionHeadersAlloc(allocator);
        errdefer allocator.free(di.coff_section_headers);

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

pub fn readElfDebugInfo(
    allocator: mem.Allocator,
    elf_filename: ?[]const u8,
    build_id: ?[]const u8,
    expected_crc: ?u32,
    parent_sections: *DW.DwarfInfo.SectionArray,
    parent_mapped_mem: ?[]align(mem.page_size) const u8,
) !ModuleDebugInfo {
    nosuspend {

        // TODO https://github.com/ziglang/zig/issues/5525
        const elf_file = (if (elf_filename) |filename| blk: {
            break :blk if (fs.path.isAbsolute(filename))
                fs.openFileAbsolute(filename, .{ .intended_io_mode = .blocking })
            else
                fs.cwd().openFile(filename, .{ .intended_io_mode = .blocking });
        } else fs.openSelfExe(.{ .intended_io_mode = .blocking })) catch |err| switch (err) {
            error.FileNotFound => return error.MissingDebugInfo,
            else => return err,
        };

        const mapped_mem = try mapWholeFile(elf_file);
        if (expected_crc) |crc| if (crc != std.hash.crc.Crc32SmallWithPoly(.IEEE).hash(mapped_mem)) return error.InvalidDebugInfo;

        const hdr: *const elf.Ehdr = @ptrCast(&mapped_mem[0]);
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
        const str_shdr: *const elf.Shdr = @ptrCast(@alignCast(&mapped_mem[math.cast(usize, str_section_off) orelse return error.Overflow]));
        const header_strings = mapped_mem[str_shdr.sh_offset..][0..str_shdr.sh_size];
        const shdrs = @as(
            [*]const elf.Shdr,
            @ptrCast(@alignCast(&mapped_mem[shoff])),
        )[0..hdr.e_shnum];

        var sections: DW.DwarfInfo.SectionArray = DW.DwarfInfo.null_section_array;

        // Take ownership over any owned sections from the parent scope
        for (parent_sections, &sections) |*parent, *section| {
            if (parent.*) |*p| {
                section.* = p.*;
                p.owned = false;
            }
        }

        errdefer for (sections) |section| if (section) |s| if (s.owned) allocator.free(s.data);

        // TODO: This function should take a ptr to GNU_EH_FRAME (which is .eh_frame_hdr) from the ELF headers
        //       and prefil sections[.eh_frame_hdr]

        var separate_debug_filename: ?[]const u8 = null;
        var separate_debug_crc: ?u32 = null;

        for (shdrs) |*shdr| {
            if (shdr.sh_type == elf.SHT_NULL or shdr.sh_type == elf.SHT_NOBITS) continue;
            const name = mem.sliceTo(header_strings[shdr.sh_name..], 0);

            if (mem.eql(u8, name, ".gnu_debuglink")) {
                const gnu_debuglink = try chopSlice(mapped_mem, shdr.sh_offset, shdr.sh_size);
                const debug_filename = mem.sliceTo(@ptrCast([*:0]const u8, gnu_debuglink.ptr), 0);
                const crc_offset = mem.alignForward(@ptrToInt(&debug_filename[debug_filename.len]) + 1, 4) - @ptrToInt(gnu_debuglink.ptr);
                const crc_bytes = gnu_debuglink[crc_offset .. crc_offset + 4];
                separate_debug_crc = mem.readIntSliceNative(u32, crc_bytes);
                separate_debug_filename = debug_filename;
                continue;
            }

            var section_index: ?usize = null;
            inline for (@typeInfo(DW.DwarfSection).Enum.fields, 0..) |section, i| {
                if (mem.eql(u8, "." ++ section.name, name)) section_index = i;
            }
            if (section_index == null) continue;

            const section_bytes = try chopSlice(mapped_mem, shdr.sh_offset, shdr.sh_size);
            sections[section_index.?] = if ((shdr.sh_flags & elf.SHF_COMPRESSED) > 0) blk: {
                var section_stream = io.fixedBufferStream(section_bytes);
                var section_reader = section_stream.reader();
                const chdr = section_reader.readStruct(elf.Chdr) catch continue;

                // TODO: Support ZSTD
                if (chdr.ch_type != .ZLIB) continue;

                var zlib_stream = std.compress.zlib.zlibStream(allocator, section_stream.reader()) catch continue;
                defer zlib_stream.deinit();

                var decompressed_section = try allocator.alloc(u8, chdr.ch_size);
                errdefer allocator.free(decompressed_section);

                const read = zlib_stream.reader().readAll(decompressed_section) catch continue;
                assert(read == decompressed_section.len);

                break :blk .{
                    .data = decompressed_section,
                    .owned = true,
                };
            } else .{
                .data = section_bytes,
                .owned = false,
            };
        }

        const missing_debug_info =
            sections[@enumToInt(DW.DwarfSection.debug_info)] == null or
            sections[@enumToInt(DW.DwarfSection.debug_abbrev)] == null or
            sections[@enumToInt(DW.DwarfSection.debug_str)] == null or
            sections[@enumToInt(DW.DwarfSection.debug_line)] == null;

        // Attempt to load debug info from an external file
        // See: https://sourceware.org/gdb/onlinedocs/gdb/Separate-Debug-Files.html
        if (missing_debug_info) {

            // Only allow one level of debug info nesting
            if (parent_mapped_mem) |_| {
                return error.MissingDebugInfo;
            }

            const global_debug_directories = [_][]const u8{
                "/usr/lib/debug",
            };

            // <global debug directory>/.build-id/<2-character id prefix>/<id remainder>.debug
            if (build_id) |id| blk: {
                if (id.len < 3) break :blk;

                // Either md5 (16 bytes) or sha1 (20 bytes) are used here in practice
                const extension = ".debug";
                var id_prefix_buf: [2]u8 = undefined;
                var filename_buf: [38 + extension.len]u8 = undefined;

                _ = std.fmt.bufPrint(&id_prefix_buf, "{s}", .{std.fmt.fmtSliceHexLower(id[0..1])}) catch unreachable;
                const filename = std.fmt.bufPrint(
                    &filename_buf,
                    "{s}" ++ extension,
                    .{std.fmt.fmtSliceHexLower(id[1..])},
                ) catch break :blk;

                for (global_debug_directories) |global_directory| {
                    // TODO: joinBuf would be ideal (with a fs.MAX_PATH_BYTES buffer)
                    const path = try fs.path.join(allocator, &.{ global_directory, ".build-id", &id_prefix_buf, filename });
                    defer allocator.free(path);
                    // TODO: Remove
                    std.debug.print("  Loading external debug info from {s}\n", .{path});
                    return readElfDebugInfo(allocator, path, null, separate_debug_crc, &sections, mapped_mem) catch continue;
                }
            }

            // use the path from .gnu_debuglink, in the search order as gdb
            if (separate_debug_filename) |separate_filename| blk: {
                if (elf_filename != null and mem.eql(u8, elf_filename.?, separate_filename)) return error.MissingDebugInfo;

                // <cwd>/<gnu_debuglink>
                if (readElfDebugInfo(allocator, separate_filename, null, separate_debug_crc, &sections, mapped_mem)) |debug_info| return debug_info else |_| {}

                // <cwd>/.debug/<gnu_debuglink>
                {
                    const path = try fs.path.join(allocator, &.{ ".debug", separate_filename });
                    defer allocator.free(path);

                    if (readElfDebugInfo(allocator, path, null, separate_debug_crc, &sections, mapped_mem)) |debug_info| return debug_info else |_| {}
                }

                var cwd_buf: [fs.MAX_PATH_BYTES]u8 = undefined;
                const cwd_path = fs.cwd().realpath("", &cwd_buf) catch break :blk;

                // <global debug directory>/<absolute folder of current binary>/<gnu_debuglink>
                for (global_debug_directories) |global_directory| {
                    const path = try fs.path.join(allocator, &.{ global_directory, cwd_path, separate_filename });
                    defer allocator.free(path);
                    if (readElfDebugInfo(allocator, path, null, separate_debug_crc, &sections, mapped_mem)) |debug_info| return debug_info else |_| {}
                }
            }

            return error.MissingDebugInfo;
        }

        var di = DW.DwarfInfo{
            .endian = endian,
            .sections = sections,
            .is_macho = false,
        };

        try DW.openDwarfDebugInfo(&di, allocator, parent_mapped_mem orelse mapped_mem);

        return ModuleDebugInfo{
            .base_address = undefined,
            .dwarf = di,
            .mapped_memory = parent_mapped_mem orelse mapped_mem,
            .external_mapped_memory = if (parent_mapped_mem != null) mapped_mem else null,
        };
    }
}

/// This takes ownership of macho_file: users of this function should not close
/// it themselves, even on error.
/// TODO it's weird to take ownership even on error, rework this code.
fn readMachODebugInfo(allocator: mem.Allocator, macho_file: File) !ModuleDebugInfo {
    const mapped_mem = try mapWholeFile(macho_file);

    const hdr: *const macho.mach_header_64 = @ptrCast(@alignCast(mapped_mem.ptr));
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

    const syms = @as(
        [*]const macho.nlist_64,
        @ptrCast(@alignCast(&mapped_mem[symtab.symoff])),
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
                        last_sym.size = @as(u32, @intCast(sym.n_value));
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
    mem.sort(MachoSymbol, symbols, {}, MachoSymbol.addressLessThan);

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

pub const WindowsModuleInfo = struct {
    base_address: usize,
    size: u32,
    name: []const u8,
};

pub const DebugInfo = struct {
    allocator: mem.Allocator,
    address_map: std.AutoHashMap(usize, *ModuleDebugInfo),
    modules: if (native_os == .windows) std.ArrayListUnmanaged(WindowsModuleInfo) else void,

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
                module_info.base_address = @intFromPtr(module_entry.modBaseAddr);
                module_info.size = module_entry.modBaseSize;
                module_info.name = allocator.dupe(u8, mem.sliceTo(&module_entry.szModule, 0)) catch &.{};
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
        if (native_os == .windows) {
            for (self.modules.items) |module| {
                self.allocator.free(module.name);
            }
            self.modules.deinit(self.allocator);
        }
    }

    pub fn getModuleForAddress(self: *DebugInfo, address: usize) !*ModuleDebugInfo {
        if (comptime builtin.target.isDarwin()) {
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

    pub fn getModuleNameForAddress(self: *DebugInfo, address: usize) ?[]const u8 {
        if (comptime builtin.target.isDarwin()) {
            return null;
        } else if (native_os == .windows) {
            return self.lookupModuleNameWin32(address);
        } else if (native_os == .haiku) {
            return null;
        } else if (comptime builtin.target.isWasm()) {
            return null;
        } else {
            return null;
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
                .buffer = @alignCast(@as(
                    [*]u8,
                    @ptrFromInt(@intFromPtr(header) + @sizeOf(macho.mach_header_64)),
                )[0..header.sizeofcmds]),
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

                const mapped_module = @as([*]const u8, @ptrFromInt(module.base_address))[0..module.size];
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

    fn lookupModuleNameWin32(self: *DebugInfo, address: usize) ?[]const u8 {
        for (self.modules.items) |module| {
            if (address >= module.base_address and address < module.base_address + module.size) {
                return module.name;
            }
        }
        return null;
    }

    fn lookupModuleDl(self: *DebugInfo, address: usize) !*ModuleDebugInfo {
        var ctx: struct {
            // Input
            address: usize,
            // Output
            base_address: usize = undefined,
            name: []const u8 = undefined,
            build_id: ?[]const u8 = undefined,
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

                    // Overflowing addition is used to handle the case of VSDOs having a p_vaddr = 0xffffffffff700000
                    const seg_start = info.dlpi_addr +% phdr.p_vaddr;
                    const seg_end = seg_start + phdr.p_memsz;
                    if (context.address >= seg_start and context.address < seg_end) {
                        // Android libc uses NULL instead of an empty string to mark the
                        // main program
                        context.name = mem.sliceTo(info.dlpi_name, 0) orelse "";
                        context.base_address = info.dlpi_addr;
                        break;
                    }
                } else return;

                // TODO: Look for the GNU_EH_FRAME section and pass it to readElfDebugInfo

                for (info.dlpi_phdr[0..info.dlpi_phnum]) |phdr| {
                    if (phdr.p_type != elf.PT_NOTE) continue;

                    const note_bytes = @intToPtr([*]const u8, info.dlpi_addr + phdr.p_vaddr)[0..phdr.p_memsz];
                    const name_size = mem.readIntSliceNative(u32, note_bytes[0..4]);
                    if (name_size != 4) continue;
                    const desc_size = mem.readIntSliceNative(u32, note_bytes[4..8]);
                    const note_type = mem.readIntSliceNative(u32, note_bytes[8..12]);
                    if (note_type != elf.NT_GNU_BUILD_ID) continue;
                    if (!mem.eql(u8, "GNU\x00", note_bytes[12..16])) continue;
                    context.build_id = note_bytes[16..][0..desc_size];
                }

                // Stop the iteration
                return error.Found;
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

        var sections: DW.DwarfInfo.SectionArray = DW.DwarfInfo.null_section_array;
        // TODO: If GNU_EH_FRAME was found, set it in sections

        obj_di.* = try readElfDebugInfo(self.allocator, if (ctx.name.len > 0) ctx.name else null, ctx.build_id, null, &sections, null);
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

            const hdr: *const macho.mach_header_64 = @ptrCast(@alignCast(mapped_mem.ptr));
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
            const strtab = @as(
                [*]const u8,
                @ptrCast(&mapped_mem[symtabcmd.?.stroff]),
            )[0 .. symtabcmd.?.strsize - 1 :0];
            const symtab = @as(
                [*]const macho.nlist_64,
                @ptrCast(@alignCast(&mapped_mem[symtabcmd.?.symoff])),
            )[0..symtabcmd.?.nsyms];

            // TODO handle tentative (common) symbols
            var addr_table = std.StringHashMap(u64).init(allocator);
            try addr_table.ensureTotalCapacity(@as(u32, @intCast(symtab.len)));
            for (symtab) |sym| {
                if (sym.n_strx == 0) continue;
                if (sym.undf() or sym.tentative() or sym.abs()) continue;
                const sym_name = mem.sliceTo(strtab[sym.n_strx..], 0);
                // TODO is it possible to have a symbol collision?
                addr_table.putAssumeCapacityNoClobber(sym_name, sym.n_value);
            }

            var sections: DW.DwarfInfo.SectionArray = DW.DwarfInfo.null_section_array;
            for (segcmd.?.getSections()) |sect| {
                const name = sect.sectName();

                var section_index: ?usize = null;
                inline for (@typeInfo(DW.DwarfSection).Enum.fields, 0..) |section, i| {
                    if (mem.eql(u8, "__" ++ section.name, name)) section_index = i;
                }
                if (section_index == null) continue;

                const section_bytes = try chopSlice(mapped_mem, sect.offset, sect.size);
                sections[section_index.?] = .{
                    .data = section_bytes,
                    .owned = false,
                };
            }

            const missing_debug_info =
                sections[@enumToInt(DW.DwarfSection.debug_info)] == null or
                sections[@enumToInt(DW.DwarfSection.debug_abbrev)] == null or
                sections[@enumToInt(DW.DwarfSection.debug_str)] == null or
                sections[@enumToInt(DW.DwarfSection.debug_line)] == null;
            if (missing_debug_info) return error.MissingDebugInfo;

            var di = DW.DwarfInfo{
                .endian = .Little,
                .sections = sections,
                .is_macho = true,
            };

            try DW.openDwarfDebugInfo(&di, allocator, mapped_mem);
            var info = OFileInfo{
                .di = di,
                .addr_table = addr_table,
            };

            // Add the debug info to the cache
            try self.ofiles.putNoClobber(o_file_path, info);

            return info;
        }

        fn getOFileForAddress(self: *@This(), allocator: mem.Allocator, address: usize) !?*OFileInfo {
            nosuspend {
                const relocated_address = address - self.base_address;
                const symbol = machoSearchSymbols(self.symbols, relocated_address) orelse
                    return null;

                const o_file_path = mem.sliceTo(self.strings[symbol.ofile..], 0);
                var o_file_info = self.ofiles.get(o_file_path) orelse
                    (self.loadOFile(allocator, o_file_path) catch |err| switch (err) {
                    error.FileNotFound,
                    error.MissingDebugInfo,
                    error.InvalidDebugInfo,
                    => return null,
                    else => return err,
                });

                return &o_file_info.di;
            }
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
                            o_file_di.section(.debug_str),
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

        pub fn getDwarfInfoForAddress(self: *@This(), allocator: mem.Allocator, address: usize) !?*const DW.DwarfInfo {
            nosuspend {
                const relocated_address = address - self.base_address;
                const symbol = machoSearchSymbols(self.symbols, relocated_address) orelse
                    return null;

                const o_file_path = mem.sliceTo(self.strings[symbol.ofile..], 0);
                var o_file_info = self.ofiles.get(o_file_path) orelse
                    (self.loadOFile(allocator, o_file_path) catch |err| switch (err) {
                    error.FileNotFound,
                    error.MissingDebugInfo,
                    error.InvalidDebugInfo,
                    => return null,
                    else => return err,
                });

                return &o_file_info.di;
            }
        }
    },
    .uefi, .windows => struct {
        base_address: usize,
        debug_data: PdbOrDwarf,
        coff_image_base: u64,
        /// Only used if debug_data is .pdb
        coff_section_headers: []coff.SectionHeader,

        fn deinit(self: *@This(), allocator: mem.Allocator) void {
            self.debug_data.deinit(allocator);
            if (self.debug_data == .pdb) {
                allocator.free(self.coff_section_headers);
            }
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

        pub fn getDwarfInfoForAddress(self: *@This(), allocator: mem.Allocator, address: usize) !?*const DW.DwarfInfo {
            _ = allocator;
            _ = address;

            return switch (self.debug_data) {
                .dwarf => |*dwarf| dwarf,
                else => null,
            };
        }
    },
    .linux, .netbsd, .freebsd, .dragonfly, .openbsd, .haiku, .solaris => struct {
        base_address: usize,
        dwarf: DW.DwarfInfo,
        mapped_memory: []align(mem.page_size) const u8,
        external_mapped_memory: ?[]align(mem.page_size) const u8,

        fn deinit(self: *@This(), allocator: mem.Allocator) void {
            self.dwarf.deinit(allocator);
            os.munmap(self.mapped_memory);
            if (self.external_mapped_memory) |m| os.munmap(m);
        }

        pub fn getSymbolAtAddress(self: *@This(), allocator: mem.Allocator, address: usize) !SymbolInfo {
            // Translate the VA into an address into this object
            const relocated_address = address - self.base_address;
            return getSymbolFromDwarf(allocator, relocated_address, &self.dwarf);
        }

        pub fn getDwarfInfoForAddress(self: *@This(), allocator: mem.Allocator, address: usize) !?*const DW.DwarfInfo {
            _ = allocator;
            _ = address;
            return &self.dwarf;
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

        pub fn getDwarfInfoForAddress(self: *@This(), allocator: mem.Allocator, address: usize) !?*const DW.DwarfInfo {
            _ = self;
            _ = allocator;
            _ = address;
            return null;
        }
    },
    else => DW.DwarfInfo,
};

fn getSymbolFromDwarf(allocator: mem.Allocator, address: u64, di: *DW.DwarfInfo) !SymbolInfo {
    if (nosuspend di.findCompileUnit(address)) |compile_unit| {
        return SymbolInfo{
            .symbol_name = nosuspend di.getSymbolName(address) orelse "???",
            .compile_unit_name = compile_unit.die.getAttrString(di, DW.AT.name, di.section(.debug_str), compile_unit.*) catch |err| switch (err) {
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
        .linux => @intFromPtr(info.fields.sigfault.addr),
        .freebsd, .macos => @intFromPtr(info.addr),
        .netbsd => @intFromPtr(info.info.reason.fault.addr),
        .openbsd => @intFromPtr(info.data.fault.addr),
        .solaris => @intFromPtr(info.reason.fault.addr),
        else => unreachable,
    };

    nosuspend switch (panic_stage) {
        0 => {
            panic_stage = 1;
            _ = panicking.fetchAdd(1, .SeqCst);

            {
                panic_mutex.lock();
                defer panic_mutex.unlock();

                dumpSegfaultInfoPosix(sig, addr, ctx_ptr);
            }

            waitForOtherThreadToFinishPanicking();
        },
        else => {
            // panic mutex already locked
            dumpSegfaultInfoPosix(sig, addr, ctx_ptr);
        },
    };

    // We cannot allow the signal handler to return because when it runs the original instruction
    // again, the memory may be mapped and undefined behavior would occur rather than repeating
    // the segfault. So we simply abort here.
    os.abort();
}

fn dumpSegfaultInfoPosix(sig: i32, addr: usize, ctx_ptr: ?*const anyopaque) void {
    const stderr = io.getStdErr().writer();
    _ = switch (sig) {
        os.SIG.SEGV => stderr.print("Segmentation fault at address 0x{x}\n", .{addr}),
        os.SIG.ILL => stderr.print("Illegal instruction at address 0x{x}\n", .{addr}),
        os.SIG.BUS => stderr.print("Bus error at address 0x{x}\n", .{addr}),
        os.SIG.FPE => stderr.print("Arithmetic exception at address 0x{x}\n", .{addr}),
        else => unreachable,
    } catch os.abort();

    switch (native_arch) {
        .x86,
        .x86_64,
        .arm,
        .aarch64,
        => {
            const ctx = @ptrCast(*const os.ucontext_t, @alignCast(@alignOf(os.ucontext_t), ctx_ptr));
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

fn handleSegfaultWindowsExtra(
    info: *windows.EXCEPTION_POINTERS,
    msg: u8,
    label: ?[]const u8,
) noreturn {
    const exception_address = @intFromPtr(info.ExceptionRecord.ExceptionAddress);
    if (@hasDecl(windows, "CONTEXT")) {
        nosuspend switch (panic_stage) {
            0 => {
                panic_stage = 1;
                _ = panicking.fetchAdd(1, .SeqCst);

                {
                    panic_mutex.lock();
                    defer panic_mutex.unlock();

                    dumpSegfaultInfoWindows(info, msg, label);
                }

                waitForOtherThreadToFinishPanicking();
            },
            else => {
                // panic mutex already locked
                dumpSegfaultInfoWindows(info, msg, label);
            },
        };
        os.abort();
    } else {
        switch (msg) {
            0 => panicImpl(null, exception_address, "{s}", label.?),
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

fn dumpSegfaultInfoWindows(info: *windows.EXCEPTION_POINTERS, msg: u8, label: ?[]const u8) void {
    const regs = info.ContextRecord.getRegs();
    const stderr = io.getStdErr().writer();
    _ = switch (msg) {
        0 => stderr.print("{s}\n", .{label.?}),
        1 => stderr.print("Segmentation fault at address 0x{x}\n", .{info.ExceptionRecord.ExceptionInformation[1]}),
        2 => stderr.print("Illegal instruction at address 0x{x}\n", .{regs.ip}),
        else => unreachable,
    } catch os.abort();

    dumpStackTraceFromBase(regs);
}

pub fn dumpStackPointerAddr(prefix: []const u8) void {
    const sp = asm (""
        : [argc] "={rsp}" (-> usize),
    );
    std.debug.print("{} sp = 0x{x}\n", .{ prefix, sp });
}

test "manage resources correctly" {
    if (builtin.os.tag == .wasi) return error.SkipZigTest;

    if (builtin.os.tag == .windows) {
        // https://github.com/ziglang/zig/issues/13963
        return error.SkipZigTest;
    }

    const writer = std.io.null_writer;
    var di = try openSelfDebugInfo(testing.allocator);
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
