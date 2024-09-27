const std = @import("std");
const builtin = @import("builtin");
const build_options = @import("build_options");
const debug = std.debug;
const io = std.io;
const print_zir = @import("print_zir.zig");
const windows = std.os.windows;
const posix = std.posix;
const native_os = builtin.os.tag;

const Zcu = @import("Zcu.zig");
const Sema = @import("Sema.zig");
const InternPool = @import("InternPool.zig");
const Zir = std.zig.Zir;
const Decl = Zcu.Decl;
const dev = @import("dev.zig");

/// To use these crash report diagnostics, publish this panic in your main file
/// and add `pub const enable_segfault_handler = false;` to your `std_options`.
/// You will also need to call initialize() on startup, preferably as the very first operation in your program.
pub const Panic = if (build_options.enable_debug_extensions) struct {
    pub const call = compilerPanic;
    pub const sentinelMismatch = std.debug.FormattedPanic.sentinelMismatch;
    pub const unwrapError = std.debug.FormattedPanic.unwrapError;
    pub const outOfBounds = std.debug.FormattedPanic.outOfBounds;
    pub const startGreaterThanEnd = std.debug.FormattedPanic.startGreaterThanEnd;
    pub const inactiveUnionField = std.debug.FormattedPanic.inactiveUnionField;
    pub const messages = std.debug.FormattedPanic.messages;
} else if (dev.env == .bootstrap)
    std.debug.SimplePanic
else
    std.debug.FormattedPanic;

/// Install signal handlers to identify crashes and report diagnostics.
pub fn initialize() void {
    if (build_options.enable_debug_extensions and debug.have_segfault_handling_support) {
        attachSegfaultHandler();
    }
}

pub const AnalyzeBody = if (build_options.enable_debug_extensions) struct {
    parent: ?*AnalyzeBody,
    sema: *Sema,
    block: *Sema.Block,
    body: []const Zir.Inst.Index,
    body_index: usize,

    pub fn push(self: *@This()) void {
        const head = &zir_state;
        debug.assert(self.parent == null);
        self.parent = head.*;
        head.* = self;
    }

    pub fn pop(self: *@This()) void {
        const head = &zir_state;
        const old = head.*.?;
        debug.assert(old == self);
        head.* = old.parent;
    }

    pub fn setBodyIndex(self: *@This(), index: usize) void {
        self.body_index = index;
    }
} else struct {
    pub inline fn push(_: @This()) void {}
    pub inline fn pop(_: @This()) void {}
    pub inline fn setBodyIndex(_: @This(), _: usize) void {}
};

threadlocal var zir_state: ?*AnalyzeBody = if (build_options.enable_debug_extensions) null else @compileError("Cannot use zir_state without debug extensions.");

pub fn prepAnalyzeBody(sema: *Sema, block: *Sema.Block, body: []const Zir.Inst.Index) AnalyzeBody {
    return if (build_options.enable_debug_extensions) .{
        .parent = null,
        .sema = sema,
        .block = block,
        .body = body,
        .body_index = 0,
    } else .{};
}

fn dumpStatusReport() !void {
    const anal = zir_state orelse return;
    // Note: We have the panic mutex here, so we can safely use the global crash heap.
    var fba = std.heap.FixedBufferAllocator.init(&crash_heap);
    const allocator = fba.allocator();

    const stderr = io.getStdErr().writer();
    const block: *Sema.Block = anal.block;
    const zcu = anal.sema.pt.zcu;

    const file, const src_base_node = Zcu.LazySrcLoc.resolveBaseNode(block.src_base_inst, zcu) orelse {
        const file = zcu.fileByIndex(block.src_base_inst.resolveFile(&zcu.intern_pool));
        try stderr.writeAll("Analyzing lost instruction in file '");
        try writeFilePath(file, stderr);
        try stderr.writeAll("'. This should not happen!\n\n");
        return;
    };

    try stderr.writeAll("Analyzing ");
    try writeFilePath(file, stderr);
    try stderr.writeAll("\n");

    print_zir.renderInstructionContext(
        allocator,
        anal.body,
        anal.body_index,
        file,
        src_base_node,
        6, // indent
        stderr,
    ) catch |err| switch (err) {
        error.OutOfMemory => try stderr.writeAll("  <out of memory dumping zir>\n"),
        else => |e| return e,
    };
    try stderr.writeAll("    For full context, use the command\n      zig ast-check -t ");
    try writeFilePath(file, stderr);
    try stderr.writeAll("\n\n");

    var parent = anal.parent;
    while (parent) |curr| {
        fba.reset();
        try stderr.writeAll("  in ");
        const cur_block_file, const cur_block_src_base_node = Zcu.LazySrcLoc.resolveBaseNode(curr.block.src_base_inst, zcu) orelse {
            const cur_block_file = zcu.fileByIndex(curr.block.src_base_inst.resolveFile(&zcu.intern_pool));
            try writeFilePath(cur_block_file, stderr);
            try stderr.writeAll("\n    > [lost instruction; this should not happen]\n");
            parent = curr.parent;
            continue;
        };
        try writeFilePath(cur_block_file, stderr);
        try stderr.writeAll("\n    > ");
        print_zir.renderSingleInstruction(
            allocator,
            curr.body[curr.body_index],
            cur_block_file,
            cur_block_src_base_node,
            6, // indent
            stderr,
        ) catch |err| switch (err) {
            error.OutOfMemory => try stderr.writeAll("  <out of memory dumping zir>\n"),
            else => |e| return e,
        };
        try stderr.writeAll("\n");

        parent = curr.parent;
    }

    try stderr.writeAll("\n");
}

var crash_heap: [16 * 4096]u8 = undefined;

fn writeFilePath(file: *Zcu.File, writer: anytype) !void {
    if (file.mod.root.root_dir.path) |path| {
        try writer.writeAll(path);
        try writer.writeAll(std.fs.path.sep_str);
    }
    if (file.mod.root.sub_path.len > 0) {
        try writer.writeAll(file.mod.root.sub_path);
        try writer.writeAll(std.fs.path.sep_str);
    }
    try writer.writeAll(file.sub_file_path);
}

pub fn compilerPanic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, maybe_ret_addr: ?usize) noreturn {
    @branchHint(.cold);
    PanicSwitch.preDispatch();
    const ret_addr = maybe_ret_addr orelse @returnAddress();
    const stack_ctx: StackContext = .{ .current = .{ .ret_addr = ret_addr } };
    PanicSwitch.dispatch(error_return_trace, stack_ctx, msg);
}

/// Attaches a global SIGSEGV handler
pub fn attachSegfaultHandler() void {
    if (!debug.have_segfault_handling_support) {
        @compileError("segfault handler not supported for this target");
    }
    if (native_os == .windows) {
        _ = windows.kernel32.AddVectoredExceptionHandler(0, handleSegfaultWindows);
        return;
    }
    var act: posix.Sigaction = .{
        .handler = .{ .sigaction = handleSegfaultPosix },
        .mask = posix.empty_sigset,
        .flags = (posix.SA.SIGINFO | posix.SA.RESTART | posix.SA.RESETHAND),
    };

    debug.updateSegfaultHandler(&act);
}

fn handleSegfaultPosix(sig: i32, info: *const posix.siginfo_t, ctx_ptr: ?*anyopaque) callconv(.C) noreturn {
    // TODO: use alarm() here to prevent infinite loops
    PanicSwitch.preDispatch();

    const addr = switch (native_os) {
        .linux => @intFromPtr(info.fields.sigfault.addr),
        .freebsd, .macos => @intFromPtr(info.addr),
        .netbsd => @intFromPtr(info.info.reason.fault.addr),
        .openbsd => @intFromPtr(info.data.fault.addr),
        .solaris, .illumos => @intFromPtr(info.reason.fault.addr),
        else => @compileError("TODO implement handleSegfaultPosix for new POSIX OS"),
    };

    var err_buffer: [128]u8 = undefined;
    const error_msg = switch (sig) {
        posix.SIG.SEGV => std.fmt.bufPrint(&err_buffer, "Segmentation fault at address 0x{x}", .{addr}) catch "Segmentation fault",
        posix.SIG.ILL => std.fmt.bufPrint(&err_buffer, "Illegal instruction at address 0x{x}", .{addr}) catch "Illegal instruction",
        posix.SIG.BUS => std.fmt.bufPrint(&err_buffer, "Bus error at address 0x{x}", .{addr}) catch "Bus error",
        else => std.fmt.bufPrint(&err_buffer, "Unknown error (signal {}) at address 0x{x}", .{ sig, addr }) catch "Unknown error",
    };

    const stack_ctx: StackContext = switch (builtin.cpu.arch) {
        .x86,
        .x86_64,
        .arm,
        .aarch64,
        => StackContext{ .exception = @ptrCast(@alignCast(ctx_ptr)) },
        else => .not_supported,
    };

    PanicSwitch.dispatch(null, stack_ctx, error_msg);
}

const WindowsSegfaultMessage = union(enum) {
    literal: []const u8,
    segfault: void,
    illegal_instruction: void,
};

fn handleSegfaultWindows(info: *windows.EXCEPTION_POINTERS) callconv(windows.WINAPI) c_long {
    switch (info.ExceptionRecord.ExceptionCode) {
        windows.EXCEPTION_DATATYPE_MISALIGNMENT => handleSegfaultWindowsExtra(info, .{ .literal = "Unaligned Memory Access" }),
        windows.EXCEPTION_ACCESS_VIOLATION => handleSegfaultWindowsExtra(info, .segfault),
        windows.EXCEPTION_ILLEGAL_INSTRUCTION => handleSegfaultWindowsExtra(info, .illegal_instruction),
        windows.EXCEPTION_STACK_OVERFLOW => handleSegfaultWindowsExtra(info, .{ .literal = "Stack Overflow" }),
        else => return windows.EXCEPTION_CONTINUE_SEARCH,
    }
}

fn handleSegfaultWindowsExtra(info: *windows.EXCEPTION_POINTERS, comptime msg: WindowsSegfaultMessage) noreturn {
    PanicSwitch.preDispatch();

    const stack_ctx = if (@hasDecl(windows, "CONTEXT"))
        StackContext{ .exception = info.ContextRecord }
    else ctx: {
        const addr = @intFromPtr(info.ExceptionRecord.ExceptionAddress);
        break :ctx StackContext{ .current = .{ .ret_addr = addr } };
    };

    switch (msg) {
        .literal => |err| PanicSwitch.dispatch(null, stack_ctx, err),
        .segfault => {
            const format_item = "Segmentation fault at address 0x{x}";
            var buf: [format_item.len + 32]u8 = undefined; // 32 is arbitrary, but sufficiently large
            const to_print = std.fmt.bufPrint(&buf, format_item, .{info.ExceptionRecord.ExceptionInformation[1]}) catch unreachable;
            PanicSwitch.dispatch(null, stack_ctx, to_print);
        },
        .illegal_instruction => {
            const ip: ?usize = switch (stack_ctx) {
                .exception => |ex| ex.getRegs().ip,
                .current => |cur| cur.ret_addr,
                .not_supported => null,
            };

            if (ip) |addr| {
                const format_item = "Illegal instruction at address 0x{x}";
                var buf: [format_item.len + 32]u8 = undefined; // 32 is arbitrary, but sufficiently large
                const to_print = std.fmt.bufPrint(&buf, format_item, .{addr}) catch unreachable;
                PanicSwitch.dispatch(null, stack_ctx, to_print);
            } else {
                PanicSwitch.dispatch(null, stack_ctx, "Illegal Instruction");
            }
        },
    }
}

const StackContext = union(enum) {
    current: struct {
        ret_addr: ?usize,
    },
    exception: *debug.ThreadContext,
    not_supported: void,

    pub fn dumpStackTrace(ctx: @This()) void {
        switch (ctx) {
            .current => |ct| {
                debug.dumpCurrentStackTrace(ct.ret_addr);
            },
            .exception => |context| {
                debug.dumpStackTraceFromBase(context);
            },
            .not_supported => {
                const stderr = io.getStdErr().writer();
                stderr.writeAll("Stack trace not supported on this platform.\n") catch {};
            },
        }
    }
};

const PanicSwitch = struct {
    const RecoverStage = enum {
        initialize,
        report_stack,
        release_mutex,
        release_ref_count,
        abort,
        silent_abort,
    };

    const RecoverVerbosity = enum {
        message_and_stack,
        message_only,
        silent,
    };

    const PanicState = struct {
        recover_stage: RecoverStage = .initialize,
        recover_verbosity: RecoverVerbosity = .message_and_stack,
        panic_ctx: StackContext = undefined,
        panic_trace: ?*const std.builtin.StackTrace = null,
        awaiting_dispatch: bool = false,
    };

    /// Counter for the number of threads currently panicking.
    /// Updated atomically before taking the panic_mutex.
    /// In recoverable cases, the program will not abort
    /// until all panicking threads have dumped their traces.
    var panicking = std.atomic.Value(u8).init(0);

    /// Tracks the state of the current panic.  If the code within the
    /// panic triggers a secondary panic, this allows us to recover.
    threadlocal var panic_state_raw: PanicState = .{};

    /// The segfault handlers above need to do some work before they can dispatch
    /// this switch.  Calling preDispatch() first makes that work fault tolerant.
    pub fn preDispatch() void {
        // TODO: We want segfaults to trigger the panic recursively here,
        // but if there is a segfault accessing this TLS slot it will cause an
        // infinite loop.  We should use `alarm()` to prevent the infinite
        // loop and maybe also use a non-thread-local global to detect if
        // it's happening and print a message.
        var panic_state: *volatile PanicState = &panic_state_raw;
        if (panic_state.awaiting_dispatch) {
            dispatch(null, .{ .current = .{ .ret_addr = null } }, "Panic while preparing callstack");
        }
        panic_state.awaiting_dispatch = true;
    }

    /// This is the entry point to a panic-tolerant panic handler.
    /// preDispatch() *MUST* be called exactly once before calling this.
    /// A threadlocal "recover_stage" is updated throughout the process.
    /// If a panic happens during the panic, the recover_stage will be
    /// used to select a recover* function to call to resume the panic.
    /// The recover_verbosity field is used to handle panics while reporting
    /// panics within panics.  If the panic handler triggers a panic, it will
    /// attempt to log an additional stack trace for the secondary panic.  If
    /// that panics, it will fall back to just logging the panic message.  If
    /// it can't even do that witout panicing, it will recover without logging
    /// anything about the internal panic.  Depending on the state, "recover"
    /// here may just mean "call abort".
    pub fn dispatch(
        trace: ?*const std.builtin.StackTrace,
        stack_ctx: StackContext,
        msg: []const u8,
    ) noreturn {
        var panic_state: *volatile PanicState = &panic_state_raw;
        debug.assert(panic_state.awaiting_dispatch);
        panic_state.awaiting_dispatch = false;
        nosuspend switch (panic_state.recover_stage) {
            .initialize => goTo(initPanic, .{ panic_state, trace, stack_ctx, msg }),
            .report_stack => goTo(recoverReportStack, .{ panic_state, trace, stack_ctx, msg }),
            .release_mutex => goTo(recoverReleaseMutex, .{ panic_state, trace, stack_ctx, msg }),
            .release_ref_count => goTo(recoverReleaseRefCount, .{ panic_state, trace, stack_ctx, msg }),
            .abort => goTo(recoverAbort, .{ panic_state, trace, stack_ctx, msg }),
            .silent_abort => goTo(abort, .{}),
        };
    }

    noinline fn initPanic(
        state: *volatile PanicState,
        trace: ?*const std.builtin.StackTrace,
        stack: StackContext,
        msg: []const u8,
    ) noreturn {
        // use a temporary so there's only one volatile store
        const new_state = PanicState{
            .recover_stage = .abort,
            .panic_ctx = stack,
            .panic_trace = trace,
        };
        state.* = new_state;

        _ = panicking.fetchAdd(1, .seq_cst);

        state.recover_stage = .release_ref_count;

        std.debug.lockStdErr();

        state.recover_stage = .release_mutex;

        const stderr = io.getStdErr().writer();
        if (builtin.single_threaded) {
            stderr.print("panic: ", .{}) catch goTo(releaseMutex, .{state});
        } else {
            const current_thread_id = std.Thread.getCurrentId();
            stderr.print("thread {} panic: ", .{current_thread_id}) catch goTo(releaseMutex, .{state});
        }
        stderr.print("{s}\n", .{msg}) catch goTo(releaseMutex, .{state});

        state.recover_stage = .report_stack;

        dumpStatusReport() catch |err| {
            stderr.print("\nIntercepted error.{} while dumping current state.  Continuing...\n", .{err}) catch {};
        };

        goTo(reportStack, .{state});
    }

    noinline fn recoverReportStack(
        state: *volatile PanicState,
        trace: ?*const std.builtin.StackTrace,
        stack: StackContext,
        msg: []const u8,
    ) noreturn {
        recover(state, trace, stack, msg);

        state.recover_stage = .release_mutex;
        const stderr = io.getStdErr().writer();
        stderr.writeAll("\nOriginal Error:\n") catch {};
        goTo(reportStack, .{state});
    }

    noinline fn reportStack(state: *volatile PanicState) noreturn {
        state.recover_stage = .release_mutex;

        if (state.panic_trace) |t| {
            debug.dumpStackTrace(t.*);
        }
        state.panic_ctx.dumpStackTrace();

        goTo(releaseMutex, .{state});
    }

    noinline fn recoverReleaseMutex(
        state: *volatile PanicState,
        trace: ?*const std.builtin.StackTrace,
        stack: StackContext,
        msg: []const u8,
    ) noreturn {
        recover(state, trace, stack, msg);
        goTo(releaseMutex, .{state});
    }

    noinline fn releaseMutex(state: *volatile PanicState) noreturn {
        state.recover_stage = .abort;

        std.debug.unlockStdErr();

        goTo(releaseRefCount, .{state});
    }

    noinline fn recoverReleaseRefCount(
        state: *volatile PanicState,
        trace: ?*const std.builtin.StackTrace,
        stack: StackContext,
        msg: []const u8,
    ) noreturn {
        recover(state, trace, stack, msg);
        goTo(releaseRefCount, .{state});
    }

    noinline fn releaseRefCount(state: *volatile PanicState) noreturn {
        state.recover_stage = .abort;

        if (panicking.fetchSub(1, .seq_cst) != 1) {
            // Another thread is panicking, wait for the last one to finish
            // and call abort()

            // Sleep forever without hammering the CPU
            var futex = std.atomic.Value(u32).init(0);
            while (true) std.Thread.Futex.wait(&futex, 0);

            // This should be unreachable, recurse into recoverAbort.
            @panic("event.wait() returned");
        }

        goTo(abort, .{});
    }

    noinline fn recoverAbort(
        state: *volatile PanicState,
        trace: ?*const std.builtin.StackTrace,
        stack: StackContext,
        msg: []const u8,
    ) noreturn {
        recover(state, trace, stack, msg);

        state.recover_stage = .silent_abort;
        const stderr = io.getStdErr().writer();
        stderr.writeAll("Aborting...\n") catch {};
        goTo(abort, .{});
    }

    noinline fn abort() noreturn {
        std.process.abort();
    }

    inline fn goTo(comptime func: anytype, args: anytype) noreturn {
        // TODO: Tailcall is broken right now, but eventually this should be used
        // to avoid blowing up the stack.  It's ok for now though, there are no
        // cycles in the state machine so the max stack usage is bounded.
        //@call(.always_tail, func, args);
        @call(.auto, func, args);
    }

    fn recover(
        state: *volatile PanicState,
        trace: ?*const std.builtin.StackTrace,
        stack: StackContext,
        msg: []const u8,
    ) void {
        switch (state.recover_verbosity) {
            .message_and_stack => {
                // lower the verbosity, and restore it at the end if we don't panic.
                state.recover_verbosity = .message_only;

                const stderr = io.getStdErr().writer();
                stderr.writeAll("\nPanicked during a panic: ") catch {};
                stderr.writeAll(msg) catch {};
                stderr.writeAll("\nInner panic stack:\n") catch {};
                if (trace) |t| {
                    debug.dumpStackTrace(t.*);
                }
                stack.dumpStackTrace();

                state.recover_verbosity = .message_and_stack;
            },
            .message_only => {
                state.recover_verbosity = .silent;

                const stderr = io.getStdErr().writer();
                stderr.writeAll("\nPanicked while dumping inner panic stack: ") catch {};
                stderr.writeAll(msg) catch {};
                stderr.writeAll("\n") catch {};

                // If we succeed, restore all the way to dumping the stack.
                state.recover_verbosity = .message_and_stack;
            },
            .silent => {},
        }
    }
};
