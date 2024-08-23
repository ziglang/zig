const builtin = @import("builtin");
const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const fatal = std.process.fatal;
const SeenPcsHeader = std.Build.Fuzz.abi.SeenPcsHeader;
const MemoryMappedList = @import("MemoryMappedList.zig");

export threadlocal var __sancov_lowest_stack: usize = std.math.maxInt(usize);

/// LLVM creates an array of these and we can look at them. They have 1:1
/// relationship with the inline counters
pub const FlaggedPc = extern struct {
    addr: usize,
    flags: packed struct(usize) {
        entry: bool,
        _: std.meta.Int(.unsigned, @bitSizeOf(usize) - 1),
    },
};

/// for passing slices across extern functions
pub const Slice = extern struct {
    ptr: [*]const u8,
    len: usize,

    pub fn toZig(s: Slice) []const u8 {
        return s.ptr[0..s.len];
    }

    pub fn fromZig(s: []const u8) Slice {
        return .{
            .ptr = s.ptr,
            .len = s.len,
        };
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

const RunMap = std.ArrayHashMapUnmanaged(Run, void, Run.HashContext, false);

const Analysis = struct {
    score: usize,
    id: Run.Id,
};

fn hashPCs(pcs: []const FlaggedPc) u64 {
    var hasher = std.hash.Wyhash.init(0);
    for (pcs) |flagged_pc| {
        hasher.update(std.mem.asBytes(&flagged_pc.addr));
    }
    return hasher.final();
}

fn createFileBail(dir: std.fs.Dir, sub_path: []const u8, flags: std.fs.File.CreateFlags) !std.fs.File {
    return dir.createFile(sub_path, flags) catch |err| switch (err) {
        error.FileNotFound => {
            const dir_name = std.fs.path.dirname(sub_path).?;
            try dir.makePath(dir_name);
            return try dir.createFile(sub_path, flags);
        },
        else => |e| return e,
    };
}

/// Layout of this file:
/// - Header
/// - list of PC addresses (usize elements)
/// - list of hit flag, 1 bit per address (stored in u8 elements)
fn initCoverageFile(cache_dir: std.fs.Dir, coverage_file_path: []const u8, flagged_pcs: []const FlaggedPc) !MemoryMappedList {
    const coverage_file = try createFileBail(cache_dir, coverage_file_path, .{
        .read = true,
        .truncate = false,
    });
    defer coverage_file.close();
    const n_bitset_elems = (flagged_pcs.len + @bitSizeOf(usize) - 1) / @bitSizeOf(usize);

    comptime assert(SeenPcsHeader.trailing[0] == .pc_bits_usize);
    comptime assert(SeenPcsHeader.trailing[1] == .pc_addr);

    // how long the file should be
    const bytes_len = @sizeOf(SeenPcsHeader) + n_bitset_elems * @sizeOf(usize) + flagged_pcs.len * @sizeOf(usize);

    // how long the file actually is
    const existing_len = try coverage_file.getEndPos();

    if (existing_len == 0)
        try coverage_file.setEndPos(bytes_len)
    else if (existing_len != bytes_len)
        return error.InvalidCoverageFile;

    var seen_pcs = try MemoryMappedList.init(coverage_file, existing_len, bytes_len);

    if (existing_len != 0) {
        // check existing file is ok
        const existing_pcs_bytes = seen_pcs.items[@sizeOf(SeenPcsHeader) + @sizeOf(usize) * n_bitset_elems ..][0 .. flagged_pcs.len * @sizeOf(usize)];
        const existing_pcs = std.mem.bytesAsSlice(usize, existing_pcs_bytes);
        for (existing_pcs, flagged_pcs) |old, new| {
            if (old != new.addr) {
                return error.InvalidCoverageFile;
            }
        }
    } else {
        // init file content
        const header: SeenPcsHeader = .{
            .n_runs = 0,
            .unique_runs = 0,
            .pcs_len = flagged_pcs.len,
            .lowest_stack = std.math.maxInt(usize),
        };
        seen_pcs.appendSliceAssumeCapacity(std.mem.asBytes(&header));
        seen_pcs.appendNTimesAssumeCapacity(0, n_bitset_elems * @sizeOf(usize));
        for (flagged_pcs) |flagged_pc| {
            seen_pcs.appendSliceAssumeCapacity(std.mem.asBytes(&flagged_pc.addr));
        }
        std.debug.assert(seen_pcs.items.len == bytes_len);
    }

    return seen_pcs;
}

/// Global coverage is set of all PCs that are covered by some fuzz input and
/// did not crash. They show up as green in the web ui
fn updateGlobalCoverage(pc_counters_: []const u8, seen_pcs_: MemoryMappedList) void {
    comptime assert(SeenPcsHeader.trailing[0] == .pc_bits_usize);
    const header_end_ptr: [*]volatile usize = @ptrCast(seen_pcs_.items[@sizeOf(SeenPcsHeader)..]);
    const remainder = pc_counters_.len % @bitSizeOf(usize);
    const aligned_len = pc_counters_.len - remainder;
    const seen_pcs = header_end_ptr[0..aligned_len];
    const pc_counters = std.mem.bytesAsSlice([@bitSizeOf(usize)]u8, pc_counters_[0..aligned_len]);
    const V = @Vector(@bitSizeOf(usize), u8);
    const zero_v: V = @splat(0);

    // update usize wide chunks
    for (header_end_ptr[0..pc_counters.len], pc_counters) |*elem, *array| {
        const v: V = array.*;
        const mask: usize = @bitCast(v != zero_v);
        _ = @atomicRmw(usize, elem, .Or, mask, .monotonic);
    }

    if (remainder > 0) {
        const i = pc_counters.len;
        const elem = &seen_pcs[i];
        var mask: usize = 0;
        for (pc_counters_[i * @bitSizeOf(usize) ..][0..remainder], 0..) |byte, bit_index| {
            mask |= @as(usize, @intFromBool(byte != 0)) << @intCast(bit_index);
        }
        _ = @atomicRmw(usize, elem, .Or, mask, .monotonic);
    }
}

fn incrementUniqueRuns(seen_pcs: MemoryMappedList) void {
    const header: *volatile SeenPcsHeader = @ptrCast(seen_pcs.items[0..@sizeOf(SeenPcsHeader)]);
    _ = @atomicRmw(usize, &header.unique_runs, .Add, 1, .monotonic);
}

fn incrementNumberOfRuns(seen_pcs: MemoryMappedList) void {
    const header: *volatile SeenPcsHeader = @ptrCast(seen_pcs.items[0..@sizeOf(SeenPcsHeader)]);
    _ = @atomicRmw(usize, &header.n_runs, .Add, 1, .monotonic);
}

fn updateLowersStack(seen_pcs: MemoryMappedList) void {
    const header: *volatile SeenPcsHeader = @ptrCast(seen_pcs.items[0..@sizeOf(SeenPcsHeader)]);
    _ = @atomicRmw(usize, &header.lowest_stack, .Min, __sancov_lowest_stack, .monotonic);
}

pub const Fuzzer = struct {
    gpa: Allocator,
    rng: std.Random.DefaultPrng,
    input: std.ArrayListUnmanaged(u8),

    flagged_pcs: []const FlaggedPc, // maybe around 100k elements
    pc_counters: []u8, // same length as flagged_pcs

    n_runs: usize,
    recent_cases: RunMap,
    /// Data collected from code coverage instrumentation from one execution of
    /// the test function.
    coverage: Coverage,
    /// Tracks which PCs have been seen across all runs that do not crash the fuzzer process.
    /// Stored in a memory-mapped file so that it can be shared with other
    /// processes and viewed while the fuzzer is running.
    seen_pcs: MemoryMappedList,
    cache_dir: std.fs.Dir,
    /// Identifies the file name that will be used to store coverage
    /// information, available to other processes.
    coverage_id: u64,

    const Coverage = struct {
        pc_table: std.AutoArrayHashMapUnmanaged(usize, void),
        run_id_hasher: std.hash.Wyhash,

        fn reset(cov: *Coverage) void {
            cov.pc_table.clearRetainingCapacity();
            cov.run_id_hasher = std.hash.Wyhash.init(0);
        }
    };

    pub fn init(f: *Fuzzer, cache_dir: std.fs.Dir) !void {
        f.cache_dir = cache_dir;

        assert(f.pc_counters.len == f.flagged_pcs.len);

        // Choose a file name for the coverage based on a hash of the PCs that
        // will be stored within.
        const pc_digest = hashPCs(f.flagged_pcs);
        f.coverage_id = pc_digest;
        const hex_digest = std.fmt.hex(pc_digest);
        const coverage_file_path = "v/" ++ hex_digest;

        f.seen_pcs = try initCoverageFile(f.cache_dir, coverage_file_path, f.flagged_pcs);
    }

    fn analyzeLastRun(f: *Fuzzer) void {
        const analysis = Analysis{
            .id = f.coverage.run_id_hasher.final(),
            .score = f.coverage.pc_table.count(),
        };
        const gop = f.recent_cases.getOrPutAssumeCapacity(.{
            .id = analysis.id,
            .input = undefined,
            .score = undefined,
        });
        if (gop.found_existing) {
            //std.log.info("duplicate analysis: score={d} id={d}", .{ analysis.score, analysis.id });
            if (f.input.items.len < gop.key_ptr.input.len or gop.key_ptr.score == 0) {
                f.gpa.free(gop.key_ptr.input);
                f.gop.key_ptr.input = try f.gpa.dupe(u8, f.input.items);
                gop.key_ptr.score = analysis.score;
            }
        } else {
            std.log.info("unique analysis: score={d} id={d}", .{ analysis.score, analysis.id });
            gop.key_ptr.* = .{
                .id = analysis.id,
                .input = try f.gpa.dupe(u8, f.input.items),
                .score = analysis.score,
            };
            updateGlobalCoverage(f.flagged_pcs, f.pc_counters, f.seen_pcs);
            incrementUniqueRuns(f.seen_pcs);
        }
    }

    fn firstRun(f: *Fuzzer) void {
        try f.recent_cases.ensureUnusedCapacity(f.gpa, 100);
        const len = f.rng.uintLessThanBiased(usize, 80);
        try f.input.resize(f.gpa, len);
        f.rng.bytes(f.input.items);
        f.recent_cases.putAssumeCapacity(.{
            .id = 0,
            .input = try f.gpa.dupe(u8, f.input.items),
            .score = 0,
        }, {});
    }

    fn prune(f: *Fuzzer) void {
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
                run.deinit(f.gpa);
            }
        }
    }

    pub fn next(f: *Fuzzer) ![]const u8 {
        if (f.recent_cases.entries.len == 0) {
            f.firstRun();
        } else {
            if (f.n_runs % 10000 == 0) f.dumpStats();
            f.analyzeLastRun();
            f.prune();
        }

        // choose input, mutate it and select it for the next run
        const chosen_index = f.rng.uintLessThanBiased(usize, f.recent_cases.entries.len);
        const run = &f.recent_cases.keys()[chosen_index];
        f.input.clearRetainingCapacity();
        f.input.appendSliceAssumeCapacity(run.input);
        try f.mutate();

        f.n_runs += 1;
        incrementNumberOfRuns(f.seen_pcs);
        updateLowersStack(f.seen_pcs);
        @memset(f.pc_counters, 0);
        f.coverage.reset();
        return f.input.items;
    }

    fn dumpStats(f: *Fuzzer) void {
        for (f.recent_cases.keys()[0..@min(f.recent_cases.entries.len, 5)], 0..) |run, i| {
            std.log.info("best[{d}] id={x} score={d} input: '{}'", .{
                i, run.id, run.score, std.zig.fmtEscapes(run.input),
            });
        }
    }
};
