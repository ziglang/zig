const builtin = @import("builtin");
const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

pub const std_options = .{
    .logFn = logOverride,
};

var log_file: ?std.fs.File = null;

fn logOverride(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    if (builtin.mode != .Debug) return;
    const f = if (log_file) |f| f else f: {
        const f = std.fs.cwd().createFile("libfuzzer.log", .{}) catch @panic("failed to open fuzzer log file");
        log_file = f;
        break :f f;
    };
    const prefix1 = comptime level.asText();
    const prefix2 = if (scope == .default) ": " else "(" ++ @tagName(scope) ++ "): ";
    f.writer().print(prefix1 ++ prefix2 ++ format ++ "\n", args) catch @panic("failed to write to fuzzer log");
}

export threadlocal var __sancov_lowest_stack: usize = 0;

export fn __sanitizer_cov_8bit_counters_init(start: [*]u8, stop: [*]u8) void {
    std.log.debug("__sanitizer_cov_8bit_counters_init start={*}, stop={*}", .{ start, stop });
}

export fn __sanitizer_cov_pcs_init(pc_start: [*]const usize, pc_end: [*]const usize) void {
    std.log.debug("__sanitizer_cov_pcs_init pc_start={*}, pc_end={*}", .{ pc_start, pc_end });
    fuzzer.pc_range = .{
        .start = @intFromPtr(pc_start),
        .end = @intFromPtr(pc_start),
    };
}

export fn __sanitizer_cov_trace_const_cmp1(arg1: u8, arg2: u8) void {
    handleCmp(@returnAddress(), arg1, arg2);
}

export fn __sanitizer_cov_trace_cmp1(arg1: u8, arg2: u8) void {
    handleCmp(@returnAddress(), arg1, arg2);
}

export fn __sanitizer_cov_trace_const_cmp2(arg1: u16, arg2: u16) void {
    handleCmp(@returnAddress(), arg1, arg2);
}

export fn __sanitizer_cov_trace_cmp2(arg1: u16, arg2: u16) void {
    handleCmp(@returnAddress(), arg1, arg2);
}

export fn __sanitizer_cov_trace_const_cmp4(arg1: u32, arg2: u32) void {
    handleCmp(@returnAddress(), arg1, arg2);
}

export fn __sanitizer_cov_trace_cmp4(arg1: u32, arg2: u32) void {
    handleCmp(@returnAddress(), arg1, arg2);
}

export fn __sanitizer_cov_trace_const_cmp8(arg1: u64, arg2: u64) void {
    handleCmp(@returnAddress(), arg1, arg2);
}

export fn __sanitizer_cov_trace_cmp8(arg1: u64, arg2: u64) void {
    handleCmp(@returnAddress(), arg1, arg2);
}

export fn __sanitizer_cov_trace_switch(val: u64, cases_ptr: [*]u64) void {
    const pc = @returnAddress();
    const len = cases_ptr[0];
    const val_size_in_bits = cases_ptr[1];
    const cases = cases_ptr[2..][0..len];
    _ = val;
    fuzzer.visitPc(pc);
    _ = val_size_in_bits;
    _ = cases;
    //std.log.debug("0x{x}: switch on value {d} ({d} bits) with {d} cases", .{
    //    pc, val, val_size_in_bits, cases.len,
    //});
}

export fn __sanitizer_cov_trace_pc_indir(callee: usize) void {
    const pc = @returnAddress();
    _ = callee;
    fuzzer.visitPc(pc);
    //std.log.debug("0x{x}: indirect call to 0x{x}", .{ pc, callee });
}

fn handleCmp(pc: usize, arg1: u64, arg2: u64) void {
    fuzzer.visitPc(pc ^ arg1 ^ arg2);
    //std.log.debug("0x{x}: comparison of {d} and {d}", .{ pc, arg1, arg2 });
}

const Fuzzer = struct {
    gpa: Allocator,
    rng: std.Random.DefaultPrng,
    input: std.ArrayListUnmanaged(u8),
    pc_range: PcRange,
    count: usize,
    recent_cases: RunMap,
    deduplicated_runs: usize,
    coverage: Coverage,

    const RunMap = std.ArrayHashMapUnmanaged(Run, void, Run.HashContext, false);

    const Coverage = struct {
        pc_table: std.AutoArrayHashMapUnmanaged(usize, void),
        run_id_hasher: std.hash.Wyhash,

        fn reset(cov: *Coverage) void {
            cov.pc_table.clearRetainingCapacity();
            cov.run_id_hasher = std.hash.Wyhash.init(0);
        }
    };

    const Run = struct {
        id: Id,
        input: []const u8,
        score: usize,

        const Id = u64;

        const HashContext = struct {
            pub fn eql(ctx: HashContext, a: Run, b: Run, b_index: usize) bool {
                _ = b_index;
                _ = ctx;
                return a.id == b.id;
            }
            pub fn hash(ctx: HashContext, a: Run) u32 {
                _ = ctx;
                return @truncate(a.id);
            }
        };

        fn deinit(run: *Run, gpa: Allocator) void {
            gpa.free(run.input);
            run.* = undefined;
        }
    };

    const Slice = extern struct {
        ptr: [*]const u8,
        len: usize,

        fn toZig(s: Slice) []const u8 {
            return s.ptr[0..s.len];
        }

        fn fromZig(s: []const u8) Slice {
            return .{
                .ptr = s.ptr,
                .len = s.len,
            };
        }
    };

    const PcRange = struct {
        start: usize,
        end: usize,
    };

    const Analysis = struct {
        score: usize,
        id: Run.Id,
    };

    fn analyzeLastRun(f: *Fuzzer) Analysis {
        return .{
            .id = f.coverage.run_id_hasher.final(),
            .score = f.coverage.pc_table.count(),
        };
    }

    fn next(f: *Fuzzer) ![]const u8 {
        const gpa = f.gpa;
        const rng = fuzzer.rng.random();

        if (f.recent_cases.entries.len == 0) {
            // Prepare initial input.
            try f.recent_cases.ensureUnusedCapacity(gpa, 100);
            const len = rng.uintLessThanBiased(usize, 80);
            try f.input.resize(gpa, len);
            rng.bytes(f.input.items);
            f.recent_cases.putAssumeCapacity(.{
                .id = 0,
                .input = try gpa.dupe(u8, f.input.items),
                .score = 0,
            }, {});
        } else {
            if (f.count % 1000 == 0) f.dumpStats();

            const analysis = f.analyzeLastRun();
            const gop = f.recent_cases.getOrPutAssumeCapacity(.{
                .id = analysis.id,
                .input = undefined,
                .score = undefined,
            });
            if (gop.found_existing) {
                //std.log.info("duplicate analysis: score={d} id={d}", .{ analysis.score, analysis.id });
                f.deduplicated_runs += 1;
                if (f.input.items.len < gop.key_ptr.input.len or gop.key_ptr.score == 0) {
                    gpa.free(gop.key_ptr.input);
                    gop.key_ptr.input = try gpa.dupe(u8, f.input.items);
                    gop.key_ptr.score = analysis.score;
                }
            } else {
                std.log.info("unique analysis: score={d} id={d}", .{ analysis.score, analysis.id });
                gop.key_ptr.* = .{
                    .id = analysis.id,
                    .input = try gpa.dupe(u8, f.input.items),
                    .score = analysis.score,
                };
            }

            if (f.recent_cases.entries.len >= 100) {
                const Context = struct {
                    values: []const Run,
                    pub fn lessThan(ctx: @This(), a_index: usize, b_index: usize) bool {
                        return ctx.values[b_index].score < ctx.values[a_index].score;
                    }
                };
                f.recent_cases.sortUnstable(Context{ .values = f.recent_cases.keys() });
                const cap = 50;
                // This has to be done before deinitializing the deleted items.
                const doomed_runs = f.recent_cases.keys()[cap..];
                f.recent_cases.shrinkRetainingCapacity(cap);
                for (doomed_runs) |*run| {
                    std.log.info("culling score={d} id={d}", .{ run.score, run.id });
                    run.deinit(gpa);
                }
            }
        }

        const chosen_index = rng.uintLessThanBiased(usize, f.recent_cases.entries.len);
        const run = &f.recent_cases.keys()[chosen_index];
        f.input.clearRetainingCapacity();
        f.input.appendSliceAssumeCapacity(run.input);
        try f.mutate();

        f.coverage.reset();
        f.count += 1;
        return f.input.items;
    }

    fn visitPc(f: *Fuzzer, pc: usize) void {
        errdefer |err| oom(err);
        try f.coverage.pc_table.put(f.gpa, pc, {});
        f.coverage.run_id_hasher.update(std.mem.asBytes(&pc));
    }

    fn dumpStats(f: *Fuzzer) void {
        std.log.info("stats: runs={d} deduplicated={d}", .{
            f.count,
            f.deduplicated_runs,
        });
        for (f.recent_cases.keys()[0..@min(f.recent_cases.entries.len, 5)], 0..) |run, i| {
            std.log.info("best[{d}] id={x} score={d} input: '{}'", .{
                i, run.id, run.score, std.zig.fmtEscapes(run.input),
            });
        }
    }

    fn mutate(f: *Fuzzer) !void {
        const gpa = f.gpa;
        const rng = fuzzer.rng.random();

        if (f.input.items.len == 0) {
            const len = rng.uintLessThanBiased(usize, 80);
            try f.input.resize(gpa, len);
            rng.bytes(f.input.items);
            return;
        }

        const index = rng.uintLessThanBiased(usize, f.input.items.len * 3);
        if (index < f.input.items.len) {
            f.input.items[index] = rng.int(u8);
        } else if (index < f.input.items.len * 2) {
            _ = f.input.orderedRemove(index - f.input.items.len);
        } else if (index < f.input.items.len * 3) {
            try f.input.insert(gpa, index - f.input.items.len * 2, rng.int(u8));
        } else {
            unreachable;
        }
    }
};

fn oom(err: anytype) noreturn {
    switch (err) {
        error.OutOfMemory => @panic("out of memory"),
    }
}

var general_purpose_allocator: std.heap.GeneralPurposeAllocator(.{}) = .{};

var fuzzer: Fuzzer = .{
    .gpa = general_purpose_allocator.allocator(),
    .rng = std.Random.DefaultPrng.init(0),
    .input = .{},
    .pc_range = .{ .start = 0, .end = 0 },
    .count = 0,
    .deduplicated_runs = 0,
    .recent_cases = .{},
    .coverage = undefined,
};

export fn fuzzer_next() Fuzzer.Slice {
    return Fuzzer.Slice.fromZig(fuzzer.next() catch |err| switch (err) {
        error.OutOfMemory => @panic("out of memory"),
    });
}
