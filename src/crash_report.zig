/// We override the panic implementation to our own one, so we can print our own information before
/// calling the default panic handler. This declaration must be re-exposed from `@import("root")`.
pub const panic = if (dev.env == .bootstrap)
    std.debug.simple_panic
else
    std.debug.FullPanic(panicImpl);

/// We let std install its segfault handler, but we override the target-agnostic handler it calls,
/// so we can print our own information before calling the default segfault logic. This declaration
/// must be re-exposed from `@import("root")`.
pub const debug = struct {
    pub const handleSegfault = handleSegfaultImpl;
};

/// Printed in panic messages when suggesting a command to run, allowing copy-pasting the command.
/// Set by `main` as soon as arguments are known. The value here is a default in case we somehow
/// crash earlier than that.
pub var zig_argv0: []const u8 = "zig";

fn handleSegfaultImpl(addr: ?usize, name: []const u8, opt_ctx: ?std.debug.CpuContextPtr) noreturn {
    @branchHint(.cold);
    dumpCrashContext() catch {};
    std.debug.defaultHandleSegfault(addr, name, opt_ctx);
}
fn panicImpl(msg: []const u8, first_trace_addr: ?usize) noreturn {
    @branchHint(.cold);
    dumpCrashContext() catch {};
    std.debug.defaultPanic(msg, first_trace_addr orelse @returnAddress());
}

pub const AnalyzeBody = if (build_options.enable_debug_extensions) struct {
    parent: ?*AnalyzeBody,
    sema: *Sema,
    block: *Sema.Block,
    body: []const Zir.Inst.Index,
    body_index: usize,

    threadlocal var current: ?*AnalyzeBody = null;

    pub fn setBodyIndex(ab: *AnalyzeBody, index: usize) void {
        ab.body_index = index;
    }

    pub fn push(ab: *AnalyzeBody, sema: *Sema, block: *Sema.Block, body: []const Zir.Inst.Index) void {
        ab.* = .{
            .parent = current,
            .sema = sema,
            .block = block,
            .body = body,
            .body_index = 0,
        };
        current = ab;
    }
    pub fn pop(ab: *AnalyzeBody) void {
        std.debug.assert(current.? == ab); // `Sema.analyzeBodyInner` did not match push/pop calls
        current = ab.parent;
    }
} else struct {
    const current: ?noreturn = null;
    // Dummy implementation, with functions marked `inline` to avoid interfering with tail calls.
    pub inline fn push(_: AnalyzeBody, _: *Sema, _: *Sema.Block, _: []const Zir.Inst.Index) void {}
    pub inline fn pop(_: AnalyzeBody) void {}
    pub inline fn setBodyIndex(_: @This(), _: usize) void {}
};

pub const CodegenFunc = if (build_options.enable_debug_extensions) struct {
    zcu: *const Zcu,
    func_index: InternPool.Index,
    threadlocal var current: ?CodegenFunc = null;
    pub fn start(zcu: *const Zcu, func_index: InternPool.Index) void {
        std.debug.assert(current == null);
        current = .{ .zcu = zcu, .func_index = func_index };
    }
    pub fn stop(func_index: InternPool.Index) void {
        std.debug.assert(current.?.func_index == func_index);
        current = null;
    }
} else struct {
    const current: ?noreturn = null;
    // Dummy implementation
    pub fn start(_: *const Zcu, _: InternPool.Index) void {}
    pub fn stop(_: InternPool.Index) void {}
};

fn dumpCrashContext() Io.Writer.Error!void {
    const S = struct {
        /// In the case of recursive panics or segfaults, don't print the context for a second time.
        threadlocal var already_dumped = false;
        /// TODO: make this unnecessary. It exists because `print_zir` currently needs an allocator,
        /// but that shouldn't be necessary---it's already only used in one place.
        threadlocal var crash_heap: [64 * 1024]u8 = undefined;
    };
    if (S.already_dumped) return;
    S.already_dumped = true;

    // TODO: this does mean that a different thread could grab the stderr mutex between the context
    // and the actual panic printing, which would be quite confusing.
    const stderr, _ = std.debug.lockStderrWriter(&.{});
    defer std.debug.unlockStderrWriter();

    try stderr.writeAll("Compiler crash context:\n");

    if (CodegenFunc.current) |*cg| {
        const func_nav = cg.zcu.funcInfo(cg.func_index).owner_nav;
        const func_fqn = cg.zcu.intern_pool.getNav(func_nav).fqn;
        try stderr.print("Generating function '{f}'\n\n", .{func_fqn.fmt(&cg.zcu.intern_pool)});
    } else if (AnalyzeBody.current) |anal| {
        try dumpCrashContextSema(anal, stderr, &S.crash_heap);
    } else {
        try stderr.writeAll("(no context)\n\n");
    }
}
fn dumpCrashContextSema(anal: *AnalyzeBody, stderr: *Io.Writer, crash_heap: []u8) Io.Writer.Error!void {
    const block: *Sema.Block = anal.block;
    const zcu = anal.sema.pt.zcu;
    const comp = zcu.comp;

    var fba: std.heap.FixedBufferAllocator = .init(crash_heap);

    const file, const src_base_node = Zcu.LazySrcLoc.resolveBaseNode(block.src_base_inst, zcu) orelse {
        const file = zcu.fileByIndex(block.src_base_inst.resolveFile(&zcu.intern_pool));
        try stderr.print("Analyzing lost instruction in file '{f}'. This should not happen!\n\n", .{file.path.fmt(comp)});
        return;
    };

    try stderr.print("Analyzing '{f}'\n", .{file.path.fmt(comp)});

    print_zir.renderInstructionContext(
        fba.allocator(),
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
    try stderr.print(
        \\    For full context, use the command
        \\      {s} ast-check -t {f}
        \\
        \\
    , .{ zig_argv0, file.path.fmt(comp) });

    var parent = anal.parent;
    while (parent) |curr| {
        fba.reset();
        const cur_block_file = zcu.fileByIndex(curr.block.src_base_inst.resolveFile(&zcu.intern_pool));
        try stderr.print("  in {f}\n", .{cur_block_file.path.fmt(comp)});
        _, const cur_block_src_base_node = Zcu.LazySrcLoc.resolveBaseNode(curr.block.src_base_inst, zcu) orelse {
            try stderr.writeAll("    > [lost instruction; this should not happen]\n");
            parent = curr.parent;
            continue;
        };
        try stderr.writeAll("    > ");
        print_zir.renderSingleInstruction(
            fba.allocator(),
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

    try stderr.writeByte('\n');
}

const std = @import("std");
const Io = std.Io;
const Zir = std.zig.Zir;

const Sema = @import("Sema.zig");
const Zcu = @import("Zcu.zig");
const InternPool = @import("InternPool.zig");
const dev = @import("dev.zig");
const print_zir = @import("print_zir.zig");

const build_options = @import("build_options");
