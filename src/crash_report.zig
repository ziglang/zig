const std = @import("std");
const builtin = @import("builtin");
const debug = std.debug;
const os = std.os;
const io = std.io;
const print_zir = @import("print_zir.zig");
const native_os = builtin.os.tag;

const Module = @import("Module.zig");
const Sema = @import("Sema.zig");
const Zir = @import("Zir.zig");
const Decl = Module.Decl;

pub const is_enabled = builtin.mode == .Debug;

/// To use these crash report diagnostics, publish these symbols in your main file.
/// You will also need to call initialize() on startup, preferably as the very first operation in your program.
pub const root_decls = struct {
    pub const panic = if (is_enabled) compilerPanic else std.builtin.default_panic;
    pub const enable_segfault_handler = false;
};

/// Install signal handlers to identify crashes and report diagnostics.
pub fn initialize() void {
    if (is_enabled and debug.have_segfault_handling_support) {
        attachSegfaultHandler();
    }
}

fn En(comptime T: type) type {
    return if (is_enabled) T else void;
}

fn en(val: anytype) En(@TypeOf(val)) {
    return if (is_enabled) val else {};
}

pub const AnalyzeBody = struct {
    parent: if (is_enabled) ?*AnalyzeBody else void,
    sema: En(*Sema),
    block: En(*Sema.Block),
    body: En([]const Zir.Inst.Index),
    body_index: En(usize),

    pub fn push(self: *@This()) void {
        if (!is_enabled) return;
        const head = &zir_state;
        debug.assert(self.parent == null);
        self.parent = head.*;
        head.* = self;
    }

    pub fn pop(self: *@This()) void {
        if (!is_enabled) return;
        const head = &zir_state;
        const old = head.*.?;
        debug.assert(old == self);
        head.* = old.parent;
    }

    pub fn setBodyIndex(self: *@This(), index: usize) void {
        if (!is_enabled) return;
        self.body_index = index;
    }
};

threadlocal var zir_state: ?*AnalyzeBody = if (is_enabled) null else @compileError("Cannot use zir_state if crash_report is disabled.");

pub fn prepAnalyzeBody(sema: *Sema, block: *Sema.Block, body: []const Zir.Inst.Index) AnalyzeBody {
    if (is_enabled) {
        return .{
            .parent = null,
            .sema = sema,
            .block = block,
            .body = body,
            .body_index = 0,
        };
    } else {
        if (@sizeOf(AnalyzeBody) != 0)
            @compileError("AnalyzeBody must have zero size when crash reports are disabled");
        return undefined;
    }
}

fn dumpStatusReport() !void {
    const anal = zir_state orelse return;
    // Note: We have the panic mutex here, so we can safely use the global crash heap.
    var fba = std.heap.FixedBufferAllocator.init(&crash_heap);
    const allocator = fba.allocator();

    const stderr = io.getStdErr().writer();
    const block: *Sema.Block = anal.block;
    const mod = anal.sema.mod;
    const block_src_decl = mod.declPtr(block.src_decl);

    try stderr.writeAll("Analyzing ");
    try writeFullyQualifiedDeclWithFile(mod, block_src_decl, stderr);
    try stderr.writeAll("\n");

    print_zir.renderInstructionContext(
        allocator,
        anal.body,
        anal.body_index,
        block.namespace.file_scope,
        block_src_decl.src_node,
        6, // indent
        stderr,
    ) catch |err| switch (err) {
        error.OutOfMemory => try stderr.writeAll("  <out of memory dumping zir>\n"),
        else => |e| return e,
    };
    try stderr.writeAll("    For full context, use the command\n      zig ast-check -t ");
    try writeFilePath(block.namespace.file_scope, stderr);
    try stderr.writeAll("\n\n");

    var parent = anal.parent;
    while (parent) |curr| {
        fba.reset();
        try stderr.writeAll("  in ");
        const curr_block_src_decl = mod.declPtr(curr.block.src_decl);
        try writeFullyQualifiedDeclWithFile(mod, curr_block_src_decl, stderr);
        try stderr.writeAll("\n    > ");
        print_zir.renderSingleInstruction(
            allocator,
            curr.body[curr.body_index],
            curr.block.namespace.file_scope,
            curr_block_src_decl.src_node,
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

fn writeFilePath(file: *Module.File, stream: anytype) !void {
    if (file.pkg.root_src_directory.path) |path| {
        try stream.writeAll(path);
        try stream.writeAll(std.fs.path.sep_str);
    }
    try stream.writeAll(file.sub_file_path);
}

fn writeFullyQualifiedDeclWithFile(mod: *Module, decl: *Decl, stream: anytype) !void {
    try writeFilePath(decl.getFileScope(), stream);
    try stream.writeAll(": ");
    try decl.renderFullyQualifiedDebugName(mod, stream);
}

pub fn compilerPanic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace) noreturn {
    PanicSwitch.preDispatch();
    @setCold(true);
    const ret_addr = @returnAddress();
    const stack_ctx: StackContext = .{ .current = .{ .ret_addr = ret_addr } };
    PanicSwitch.dispatch(error_return_trace, stack_ctx, msg);
}

/// Attaches a global SIGSEGV handler
pub fn attachSegfaultHandler() void {
    if (!debug.have_segfault_handling_support) {
        @compileError("segfault handler not supported for this target");
    }
    if (builtin.os.tag == .windows) {
        _ = os.windows.kernel32.AddVectoredExceptionHandler(0, handleSegfaultWindows);
        return;
    }
    var act = os.Sigaction{
        .handler = .{ .sigaction = handleSegfaultPosix },
        .mask = os.empty_sigset,
        .flags = (os.SA.SIGINFO | os.SA.RESTART | os.SA.RESETHAND),
    };

    debug.updateSegfaultHandler(&act) catch {
        @panic("unable to install segfault handler, maybe adjust have_segfault_handling_support in std/debug.zig");
    };
}

fn handleSegfaultPosix(sig: i32, info: *const os.siginfo_t, ctx_ptr: ?*const anyopaque) callconv(.C) noreturn {
    // TODO: use alarm() here to prevent infinite loops
    PanicSwitch.preDispatch();

    const addr = switch (builtin.os.tag) {
        .linux => @ptrToInt(info.fields.sigfault.addr),
        .freebsd, .macos => @ptrToInt(info.addr),
        .netbsd => @ptrToInt(info.info.reason.fault.addr),
        .openbsd => @ptrToInt(info.data.fault.addr),
        .solaris => @ptrToInt(info.reason.fault.addr),
        else => @compileError("TODO implement handleSegfaultPosix for new POSIX OS"),
    };

    var err_buffer: [128]u8 = undefined;
    const error_msg = switch (sig) {
        os.SIG.SEGV => std.fmt.bufPrint(&err_buffer, "Segmentation fault at address 0x{x}", .{addr}) catch "Segmentation fault",
        os.SIG.ILL => std.fmt.bufPrint(&err_buffer, "Illegal instruction at address 0x{x}", .{addr}) catch "Illegal instruction",
        os.SIG.BUS => std.fmt.bufPrint(&err_buffer, "Bus error at address 0x{x}", .{addr}) catch "Bus error",
        else => std.fmt.bufPrint(&err_buffer, "Unknown error (signal {}) at address 0x{x}", .{ sig, addr }) catch "Unknown error",
    };

    const stack_ctx: StackContext = switch (builtin.cpu.arch) {
        .i386 => ctx: {
            const ctx = @ptrCast(*const os.ucontext_t, @alignCast(@alignOf(os.ucontext_t), ctx_ptr));
            const ip = @intCast(usize, ctx.mcontext.gregs[os.REG.EIP]);
            const bp = @intCast(usize, ctx.mcontext.gregs[os.REG.EBP]);
            break :ctx StackContext{ .exception = .{ .bp = bp, .ip = ip } };
        },
        .x86_64 => ctx: {
            const ctx = @ptrCast(*const os.ucontext_t, @alignCast(@alignOf(os.ucontext_t), ctx_ptr));
            const ip = switch (builtin.os.tag) {
                .linux, .netbsd, .solaris => @intCast(usize, ctx.mcontext.gregs[os.REG.RIP]),
                .freebsd => @intCast(usize, ctx.mcontext.rip),
                .openbsd => @intCast(usize, ctx.sc_rip),
                .macos => @intCast(usize, ctx.mcontext.ss.rip),
                else => unreachable,
            };
            const bp = switch (builtin.os.tag) {
                .linux, .netbsd, .solaris => @intCast(usize, ctx.mcontext.gregs[os.REG.RBP]),
                .openbsd => @intCast(usize, ctx.sc_rbp),
                .freebsd => @intCast(usize, ctx.mcontext.rbp),
                .macos => @intCast(usize, ctx.mcontext.ss.rbp),
                else => unreachable,
            };
            break :ctx StackContext{ .exception = .{ .bp = bp, .ip = ip } };
        },
        .arm => ctx: {
            const ctx = @ptrCast(*const os.ucontext_t, @alignCast(@alignOf(os.ucontext_t), ctx_ptr));
            const ip = @intCast(usize, ctx.mcontext.arm_pc);
            const bp = @intCast(usize, ctx.mcontext.arm_fp);
            break :ctx StackContext{ .exception = .{ .bp = bp, .ip = ip } };
        },
        .aarch64 => ctx: {
            const ctx = @ptrCast(*const os.ucontext_t, @alignCast(@alignOf(os.ucontext_t), ctx_ptr));
            const ip = switch (native_os) {
                .macos => @intCast(usize, ctx.mcontext.ss.pc),
                else => @intCast(usize, ctx.mcontext.pc),
            };
            // x29 is the ABI-designated frame pointer
            const bp = switch (native_os) {
                .macos => @intCast(usize, ctx.mcontext.ss.fp),
                else => @intCast(usize, ctx.mcontext.regs[29]),
            };
            break :ctx StackContext{ .exception = .{ .bp = bp, .ip = ip } };
        },
        else => .not_supported,
    };

    PanicSwitch.dispatch(null, stack_ctx, error_msg);
}

const WindowsSegfaultMessage = union(enum) {
    literal: []const u8,
    segfault: void,
    illegal_instruction: void,
};

fn handleSegfaultWindows(info: *os.windows.EXCEPTION_POINTERS) callconv(os.windows.WINAPI) c_long {
    switch (info.ExceptionRecord.ExceptionCode) {
        os.windows.EXCEPTION_DATATYPE_MISALIGNMENT => handleSegfaultWindowsExtra(info, .{ .literal = "Unaligned Memory Access" }),
        os.windows.EXCEPTION_ACCESS_VIOLATION => handleSegfaultWindowsExtra(info, .segfault),
        os.windows.EXCEPTION_ILLEGAL_INSTRUCTION => handleSegfaultWindowsExtra(info, .illegal_instruction),
        os.windows.EXCEPTION_STACK_OVERFLOW => handleSegfaultWindowsExtra(info, .{ .literal = "Stack Overflow" }),
        else => return os.windows.EXCEPTION_CONTINUE_SEARCH,
    }
}

fn handleSegfaultWindowsExtra(info: *os.windows.EXCEPTION_POINTERS, comptime msg: WindowsSegfaultMessage) noreturn {
    PanicSwitch.preDispatch();

    const stack_ctx = if (@hasDecl(os.windows, "CONTEXT")) ctx: {
        const regs = info.ContextRecord.getRegs();
        break :ctx StackContext{ .exception = .{ .bp = regs.bp, .ip = regs.ip } };
    } else ctx: {
        const addr = @ptrToInt(info.ExceptionRecord.ExceptionAddress);
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
                .exception => |ex| ex.ip,
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
    exception: struct {
        bp: usize,
        ip: usize,
    },
    not_supported: void,

    pub fn dumpStackTrace(ctx: @This()) void {
        switch (ctx) {
            .current => |ct| {
                debug.dumpCurrentStackTrace(ct.ret_addr);
            },
            .exception => |ex| {
                debug.dumpStackTraceFromBase(ex.bp, ex.ip);
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
    var panicking = std.atomic.Atomic(u8).init(0);

    // Locked to avoid interleaving panic messages from multiple threads.
    var panic_mutex = std.Thread.Mutex{};

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

        _ = panicking.fetchAdd(1, .SeqCst);

        state.recover_stage = .release_ref_count;

        panic_mutex.lock();

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

        panic_mutex.unlock();

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

        if (panicking.fetchSub(1, .SeqCst) != 1) {
            // Another thread is panicking, wait for the last one to finish
            // and call abort()

            // Sleep forever without hammering the CPU
            var futex = std.atomic.Atomic(u32).init(0);
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
        os.abort();
    }

    inline fn goTo(comptime func: anytype, args: anytype) noreturn {
        // TODO: Tailcall is broken right now, but eventually this should be used
        // to avoid blowing up the stack.  It's ok for now though, there are no
        // cycles in the state machine so the max stack usage is bounded.
        //@call(.{.modifier = .always_tail}, func, args);
        @call(.{}, func, args);
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
