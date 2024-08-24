const builtin = @import("builtin");
const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const fatal = std.process.fatal;
const Fuzzer = @import("fuzzer/main.zig").Fuzzer;
const fc = @import("fuzzer/feature_capture.zig");
const FlaggedPc = @import("fuzzer/main.zig").FlaggedPc;
const Slice = @import("fuzzer/main.zig").Slice;

// ==== global state ====

var log_file: ?std.fs.File = null;

var general_purpose_allocator: std.heap.GeneralPurposeAllocator(.{}) = .{};

var fuzzer: Fuzzer = .{
    .gpa = general_purpose_allocator.allocator(),
    .rng = std.Random.DefaultPrng.init(0),
    .cache_dir = undefined,
    .seen_pcs = undefined,
    .coverage_id = undefined,
};

var module_count_8bc: usize = 0; // used to check that llvm init callbacs were called exactly once
var module_count_pcs: usize = 0; // -||-

// ==== llvm callbacks ====

}

}

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
    // TODO: use arg1 and arg2 as part of inputs
    _ = arg1;
    _ = arg2;
    const c: u64 = pc;
    const lo: u32 = @truncate(c);
    const hi: u32 = @intCast(c >> 32);
    fc.newFeature(lo ^ hi);
}

export fn __sanitizer_cov_trace_switch(val: u64, _: [*]u64) void {
    const pc = @returnAddress();
    _ = val;
    const c: u64 = pc;
    const lo: u32 = @truncate(c);
    const hi: u32 = @intCast(c >> 32);
    fc.newFeature(lo ^ hi);
}

export fn __sanitizer_cov_trace_pc_indir(callee: usize) void {
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

/// Called before each invocation of the user's code
export fn fuzzer_next(options: *const std.testing.FuzzInputOptions) Slice {
    return Slice.fromZig(fuzzer.next(options) catch |err| switch (err) {
        error.OutOfMemory => @panic("fuzzer: out of memory"),
    });
}

/// Called once
export fn fuzzer_init(cache_dir_struct: Slice) void {
    // setup log file as soon as possible
    const cache_dir_path = cache_dir_struct.toZig();
    const cache_dir = if (cache_dir_path.len == 0)
        std.fs.cwd()
    else
        std.fs.cwd().makeOpenPath(cache_dir_path, .{ .iterate = true }) catch
            @panic("unable to open fuzz directory"); // cant log details because log file is not setup

    setupLogFile(cache_dir);

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

    fuzzer.init(cache_dir, pc_counters, pcs) catch |err|
        fatal("unable to init fuzzer: {s}", .{@errorName(err)});
}

// ==== log ====

pub const std_options = .{
    .logFn = logOverride,
    .log_level = .debug,
};

fn setupLogFile(cachedir: std.fs.Dir) void {
    log_file = cachedir.createFile("tmp/zigfuzzer.log", .{}) catch
        @panic("failed to open fuzzer log file");
}

fn logOverride(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    const w = if (log_file) |f| f.writer() else @panic("logging before log file was setup");
    // 256 is the first power of two that is greater than the width of my terminal
    var bw: std.io.BufferedWriter(256, @TypeOf(w)) = .{ .unbuffered_writer = w };

    const prefix1 = comptime level.asText();
    const prefix2 = if (scope == .default) ": " else "(" ++ @tagName(scope) ++ "): ";
    errdefer @panic("io error while logging");
    try bw.writer().print(prefix1 ++ prefix2 ++ format ++ "\n", args);
    try bw.flush();
}

// ==== panic handler ====

pub fn panic(
    msg: []const u8,
    _: ?*std.builtin.StackTrace,
    _: ?usize,
) noreturn {
    @setCold(true);
    std.debug.print("fuzzer panic: {s}\n", .{msg});
    std.process.exit(1);
}
