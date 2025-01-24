const builtin = @import("builtin");
const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const fatal = std.process.fatal;
const Fuzzer = @import("fuzzer/main.zig").Fuzzer;
const fc = @import("fuzzer/feature_capture.zig");

/// Type for passing slices across extern functions where we can't use zig
/// types
pub const Slice = extern struct {
    ptr: [*]const u8,
    len: usize,

    pub fn toZig(s: Slice) []const u8 {
        return s.ptr[0..s.len];
    }
};

// ==== global state ====

var log_file: ?std.fs.File = null;

var fuzzer: Fuzzer = undefined;

// ==== llvm callbacks ====

// zig fmt: off
export fn __sanitizer_cov_trace_const_cmp1(arg1: u8 , arg2: u8 ) void { handleCmp(@returnAddress(), arg1, arg2); }
export fn __sanitizer_cov_trace_cmp1      (arg1: u8 , arg2: u8 ) void { handleCmp(@returnAddress(), arg1, arg2); }
export fn __sanitizer_cov_trace_const_cmp2(arg1: u16, arg2: u16) void { handleCmp(@returnAddress(), arg1, arg2); }
export fn __sanitizer_cov_trace_cmp2      (arg1: u16, arg2: u16) void { handleCmp(@returnAddress(), arg1, arg2); }
export fn __sanitizer_cov_trace_const_cmp4(arg1: u32, arg2: u32) void { handleCmp(@returnAddress(), arg1, arg2); }
export fn __sanitizer_cov_trace_cmp4      (arg1: u32, arg2: u32) void { handleCmp(@returnAddress(), arg1, arg2); }
export fn __sanitizer_cov_trace_const_cmp8(arg1: u64, arg2: u64) void { handleCmp(@returnAddress(), arg1, arg2); }
export fn __sanitizer_cov_trace_cmp8      (arg1: u64, arg2: u64) void { handleCmp(@returnAddress(), arg1, arg2); }
// zig fmt: on

fn handleCmp(pc: usize, arg1: u64, arg2: u64) void {
    // TODO: TORC
    _ = arg1;
    _ = arg2;
    const c: u64 = pc;
    const lo: u32 = @truncate(c);
    const hi: u32 = @intCast(c >> 32);
    fc.newFeature(lo ^ hi);
}

export fn __sanitizer_cov_trace_switch(val: u64, _: [*]u64) void {
    // TODO: is this called?
    const pc = @returnAddress();
    _ = val;
    const c: u64 = pc;
    const lo: u32 = @truncate(c);
    const hi: u32 = @intCast(c >> 32);
    fc.newFeature(lo ^ hi);
}

export fn __sanitizer_cov_trace_pc_indir(callee: usize) void {
    // TODO: is this called?
    const pc = @returnAddress();
    const c: u64 = pc ^ callee;
    const lo: u32 = @truncate(c);
    const hi: u32 = @intCast(c >> 32);
    fc.newFeature(lo ^ hi);
}

// ==== libfuzzer API ====

/// Invalid until `fuzzer_init` is called.
export fn fuzzer_coverage_id() u64 {
    return fuzzer.coverage_id;
}

export fn fuzzer_start(
    testOne: *const fn ([*]const u8, usize) callconv(.C) void,
    options: *const std.testing.FuzzInputOptions,
) void {
    fuzzer.start(testOne, options.*) catch |e| switch (e) {
        error.OutOfMemory => {
            std.debug.print("fuzzer OOM\n", .{});
            if (@errorReturnTrace()) |trace| {
                std.debug.dumpStackTrace(trace.*);
            }
        },
    };
}

export fn fuzzer_init(cache_dir_struct: Slice) void {
    // setup log file as soon as possible
    const cache_dir_path = cache_dir_struct.toZig();
    const cache_dir = if (cache_dir_path.len == 0)
        std.fs.cwd()
    else
        std.fs.cwd().makeOpenPath(cache_dir_path, .{ .iterate = true }) catch |err|
            std.debug.panic("unable to open fuzz directory: {}", .{err}); // cant call fatal since it depends on std.log.err

    log_file = cache_dir.createFile("tmp/libfuzzer.log", .{}) catch |err|
        std.debug.panic("create log file failed: {}", .{err}); // cant call fatal since it depends on std.log.err

    std.log.info("Cache dir @'{s}'", .{cache_dir_path});

    // Linkers are expected to automatically add `__start_<section>` and
    // `__stop_<section>` symbols when section names are valid C identifiers.

    const pc_counters_start = @extern([*]u8, .{
        .name = "__start___sancov_cntrs",
        .linkage = .weak,
    }) orelse fatal("missing __start___sancov_cntrs symbol", .{});

    const pc_counters_end = @extern([*]u8, .{
        .name = "__stop___sancov_cntrs",
        .linkage = .weak,
    }) orelse fatal("missing __stop___sancov_cntrs symbol", .{});

    const pc_counters = pc_counters_start[0 .. pc_counters_end - pc_counters_start];

    const pcs_start = @extern([*]usize, .{
        .name = "__start___sancov_pcs1",
        .linkage = .weak,
    }) orelse fatal("missing __start___sancov_pcs1 symbol", .{});

    const pcs_end = @extern([*]usize, .{
        .name = "__stop___sancov_pcs1",
        .linkage = .weak,
    }) orelse fatal("missing __stop___sancov_pcs1 symbol", .{});

    const pcs = pcs_start[0 .. pcs_end - pcs_start];

    fuzzer = Fuzzer.init(cache_dir, pc_counters, pcs);
}

// ==== log ====

pub const std_options = std.Options{
    .logFn = logOverride,
    .log_level = .debug,
};

fn logOverride(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    const w = (log_file orelse unreachable).writer();
    var bw = std.io.bufferedWriter(w);

    const prefix1 = comptime level.asText();
    const prefix2 = if (scope == .default) ": " else "(" ++ @tagName(scope) ++ "): ";

    errdefer |err| std.debug.panic("io error while logging: {}", .{err});

    // NOTE(prokop): These bubble through to be a `write` syscall on Linux
    // which guarantees atomic operation as long as the message is not too long
    // (4k i think?). It might not be a bad idea to put a lock here...
    try bw.writer().print(prefix1 ++ prefix2 ++ format ++ "\n", args);
    try bw.flush();
}

// ==== panic handler ====

pub fn panic(
    msg: []const u8,
    trace: ?*std.builtin.StackTrace,
    _: ?usize,
) noreturn {
    @branchHint(.cold);
    std.debug.print("fuzzer panic: {s}\n", .{msg});
    if (trace) |t| {
        std.debug.dumpStackTrace(t.*);
    }
    std.process.exit(1);
}
