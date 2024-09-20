const builtin = @import("builtin");
const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const fatal = std.process.fatal;
const SeenPcsHeader = std.Build.Fuzz.abi.SeenPcsHeader;

pub const std_options = .{
    .logFn = logOverride,
};

var log_file: ?std.fs.File = null;

fn logOverride(
    comptime level: std.log.Level,
    comptime scope: @Type(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    const f = if (log_file) |f| f else f: {
        const f = fuzzer.cache_dir.createFile("tmp/libfuzzer.log", .{}) catch
            @panic("failed to open fuzzer log file");
        log_file = f;
        break :f f;
    };
    const prefix1 = comptime level.asText();
    const prefix2 = if (scope == .default) ": " else "(" ++ @tagName(scope) ++ "): ";
    f.writer().print(prefix1 ++ prefix2 ++ format ++ "\n", args) catch @panic("failed to write to fuzzer log");
}

/// Helps determine run uniqueness in the face of recursion.
export threadlocal var __sancov_lowest_stack: usize = 0;

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
    pcs: []const usize,
    pc_counters: []u8,
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

    const Analysis = struct {
        score: usize,
        id: Run.Id,
    };

    fn init(f: *Fuzzer, cache_dir: std.fs.Dir, pc_counters: []u8, pcs: []const usize) !void {
        f.cache_dir = cache_dir;
        f.pc_counters = pc_counters;
        f.pcs = pcs;

        // Choose a file name for the coverage based on a hash of the PCs that will be stored within.
        const pc_digest = std.hash.Wyhash.hash(0, std.mem.sliceAsBytes(pcs));
        f.coverage_id = pc_digest;
        const hex_digest = std.fmt.hex(pc_digest);
        const coverage_file_path = "v/" ++ hex_digest;

        // Layout of this file:
        // - Header
        // - list of PC addresses (usize elements)
        // - list of hit flag, 1 bit per address (stored in u8 elements)
        const coverage_file = createFileBail(cache_dir, coverage_file_path, .{
            .read = true,
            .truncate = false,
        });
        defer coverage_file.close();
        const n_bitset_elems = (pcs.len + @bitSizeOf(usize) - 1) / @bitSizeOf(usize);
        comptime assert(SeenPcsHeader.trailing[0] == .pc_bits_usize);
        comptime assert(SeenPcsHeader.trailing[1] == .pc_addr);
        const bytes_len = @sizeOf(SeenPcsHeader) +
            n_bitset_elems * @sizeOf(usize) +
            pcs.len * @sizeOf(usize);
        const existing_len = coverage_file.getEndPos() catch |err| {
            fatal("unable to check len of coverage file: {s}", .{@errorName(err)});
        };
        if (existing_len == 0) {
            coverage_file.setEndPos(bytes_len) catch |err| {
                fatal("unable to set len of coverage file: {s}", .{@errorName(err)});
            };
        } else if (existing_len != bytes_len) {
            fatal("incompatible existing coverage file (differing lengths)", .{});
        }
        f.seen_pcs = MemoryMappedList.init(coverage_file, existing_len, bytes_len) catch |err| {
            fatal("unable to init coverage memory map: {s}", .{@errorName(err)});
        };
        if (existing_len != 0) {
            const existing_pcs_bytes = f.seen_pcs.items[@sizeOf(SeenPcsHeader) + @sizeOf(usize) * n_bitset_elems ..][0 .. pcs.len * @sizeOf(usize)];
            const existing_pcs = std.mem.bytesAsSlice(usize, existing_pcs_bytes);
            for (existing_pcs, pcs, 0..) |old, new, i| {
                if (old != new) {
                    fatal("incompatible existing coverage file (differing PC at index {d}: {x} != {x})", .{
                        i, old, new,
                    });
                }
            }
        } else {
            const header: SeenPcsHeader = .{
                .n_runs = 0,
                .unique_runs = 0,
                .pcs_len = pcs.len,
            };
            f.seen_pcs.appendSliceAssumeCapacity(std.mem.asBytes(&header));
            f.seen_pcs.appendNTimesAssumeCapacity(0, n_bitset_elems * @sizeOf(usize));
            f.seen_pcs.appendSliceAssumeCapacity(std.mem.sliceAsBytes(pcs));
        }
    }

    fn analyzeLastRun(f: *Fuzzer) Analysis {
        return .{
            .id = f.coverage.run_id_hasher.final(),
            .score = f.coverage.pc_table.count(),
        };
    }

    fn start(f: *Fuzzer) !void {
        const gpa = f.gpa;
        const rng = fuzzer.rng.random();

        // Prepare initial input.
        assert(f.recent_cases.entries.len == 0);
        assert(f.n_runs == 0);
        try f.recent_cases.ensureUnusedCapacity(gpa, 100);
        const len = rng.uintLessThanBiased(usize, 80);
        try f.input.resize(gpa, len);
        rng.bytes(f.input.items);
        f.recent_cases.putAssumeCapacity(.{
            .id = 0,
            .input = try gpa.dupe(u8, f.input.items),
            .score = 0,
        }, {});

        const header: *volatile SeenPcsHeader = @ptrCast(f.seen_pcs.items[0..@sizeOf(SeenPcsHeader)]);

        while (true) {
            const chosen_index = rng.uintLessThanBiased(usize, f.recent_cases.entries.len);
            const run = &f.recent_cases.keys()[chosen_index];
            f.input.clearRetainingCapacity();
            f.input.appendSliceAssumeCapacity(run.input);
            try f.mutate();

            @memset(f.pc_counters, 0);
            __sancov_lowest_stack = std.math.maxInt(usize);
            f.coverage.reset();

            fuzzer_one(f.input.items.ptr, f.input.items.len);

            f.n_runs += 1;
            _ = @atomicRmw(usize, &header.n_runs, .Add, 1, .monotonic);

            if (f.n_runs % 10000 == 0) f.dumpStats();

            const analysis = f.analyzeLastRun();
            const gop = f.recent_cases.getOrPutAssumeCapacity(.{
                .id = analysis.id,
                .input = undefined,
                .score = undefined,
            });
            if (gop.found_existing) {
                //std.log.info("duplicate analysis: score={d} id={d}", .{ analysis.score, analysis.id });
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

                {
                    // Track code coverage from all runs.
                    comptime assert(SeenPcsHeader.trailing[0] == .pc_bits_usize);
                    const header_end_ptr: [*]volatile usize = @ptrCast(f.seen_pcs.items[@sizeOf(SeenPcsHeader)..]);
                    const remainder = f.pcs.len % @bitSizeOf(usize);
                    const aligned_len = f.pcs.len - remainder;
                    const seen_pcs = header_end_ptr[0..aligned_len];
                    const pc_counters = std.mem.bytesAsSlice([@bitSizeOf(usize)]u8, f.pc_counters[0..aligned_len]);
                    const V = @Vector(@bitSizeOf(usize), u8);
                    const zero_v: V = @splat(0);

                    for (header_end_ptr[0..pc_counters.len], pc_counters) |*elem, *array| {
                        const v: V = array.*;
                        const mask: usize = @bitCast(v != zero_v);
                        _ = @atomicRmw(usize, elem, .Or, mask, .monotonic);
                    }
                    if (remainder > 0) {
                        const i = pc_counters.len;
                        const elem = &seen_pcs[i];
                        var mask: usize = 0;
                        for (f.pc_counters[i * @bitSizeOf(usize) ..][0..remainder], 0..) |byte, bit_index| {
                            mask |= @as(usize, @intFromBool(byte != 0)) << @intCast(bit_index);
                        }
                        _ = @atomicRmw(usize, elem, .Or, mask, .monotonic);
                    }
                }

                _ = @atomicRmw(usize, &header.unique_runs, .Add, 1, .monotonic);
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
                for (doomed_runs) |*doomed_run| {
                    std.log.info("culling score={d} id={d}", .{ doomed_run.score, doomed_run.id });
                    doomed_run.deinit(gpa);
                }
            }
        }
    }

    fn visitPc(f: *Fuzzer, pc: usize) void {
        errdefer |err| oom(err);
        try f.coverage.pc_table.put(f.gpa, pc, {});
        f.coverage.run_id_hasher.update(std.mem.asBytes(&pc));
    }

    fn dumpStats(f: *Fuzzer) void {
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

fn createFileBail(dir: std.fs.Dir, sub_path: []const u8, flags: std.fs.File.CreateFlags) std.fs.File {
    return dir.createFile(sub_path, flags) catch |err| switch (err) {
        error.FileNotFound => {
            const dir_name = std.fs.path.dirname(sub_path).?;
            dir.makePath(dir_name) catch |e| {
                fatal("unable to make path '{s}': {s}", .{ dir_name, @errorName(e) });
            };
            return dir.createFile(sub_path, flags) catch |e| {
                fatal("unable to create file '{s}': {s}", .{ sub_path, @errorName(e) });
            };
        },
        else => fatal("unable to create file '{s}': {s}", .{ sub_path, @errorName(err) }),
    };
}

fn oom(err: anytype) noreturn {
    switch (err) {
        error.OutOfMemory => @panic("out of memory"),
    }
}

var general_purpose_allocator: std.heap.GeneralPurposeAllocator(.{}) = .init;

var fuzzer: Fuzzer = .{
    .gpa = general_purpose_allocator.allocator(),
    .rng = std.Random.DefaultPrng.init(0),
    .input = .{},
    .pcs = undefined,
    .pc_counters = undefined,
    .n_runs = 0,
    .recent_cases = .{},
    .coverage = undefined,
    .cache_dir = undefined,
    .seen_pcs = undefined,
    .coverage_id = undefined,
};

/// Invalid until `fuzzer_init` is called.
export fn fuzzer_coverage_id() u64 {
    return fuzzer.coverage_id;
}

var fuzzer_one: *const fn (input_ptr: [*]const u8, input_len: usize) callconv(.C) void = undefined;

export fn fuzzer_start(testOne: @TypeOf(fuzzer_one)) void {
    fuzzer_one = testOne;
    fuzzer.start() catch |err| switch (err) {
        error.OutOfMemory => fatal("out of memory", .{}),
    };
}

export fn fuzzer_init(cache_dir_struct: Fuzzer.Slice) void {
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

    const cache_dir_path = cache_dir_struct.toZig();
    const cache_dir = if (cache_dir_path.len == 0)
        std.fs.cwd()
    else
        std.fs.cwd().makeOpenPath(cache_dir_path, .{ .iterate = true }) catch |err| {
            fatal("unable to open fuzz directory '{s}': {s}", .{ cache_dir_path, @errorName(err) });
        };

    fuzzer.init(cache_dir, pc_counters, pcs) catch |err|
        fatal("unable to init fuzzer: {s}", .{@errorName(err)});
}

/// Like `std.ArrayListUnmanaged(u8)` but backed by memory mapping.
pub const MemoryMappedList = struct {
    /// Contents of the list.
    ///
    /// Pointers to elements in this slice are invalidated by various functions
    /// of this ArrayList in accordance with the respective documentation. In
    /// all cases, "invalidated" means that the memory has been passed to this
    /// allocator's resize or free function.
    items: []align(std.mem.page_size) volatile u8,
    /// How many bytes this list can hold without allocating additional memory.
    capacity: usize,

    pub fn init(file: std.fs.File, length: usize, capacity: usize) !MemoryMappedList {
        const ptr = try std.posix.mmap(
            null,
            capacity,
            std.posix.PROT.READ | std.posix.PROT.WRITE,
            .{ .TYPE = .SHARED },
            file.handle,
            0,
        );
        return .{
            .items = ptr[0..length],
            .capacity = capacity,
        };
    }

    /// Append the slice of items to the list.
    /// Asserts that the list can hold the additional items.
    pub fn appendSliceAssumeCapacity(l: *MemoryMappedList, items: []const u8) void {
        const old_len = l.items.len;
        const new_len = old_len + items.len;
        assert(new_len <= l.capacity);
        l.items.len = new_len;
        @memcpy(l.items[old_len..][0..items.len], items);
    }

    /// Append a value to the list `n` times.
    /// Never invalidates element pointers.
    /// The function is inline so that a comptime-known `value` parameter will
    /// have better memset codegen in case it has a repeated byte pattern.
    /// Asserts that the list can hold the additional items.
    pub inline fn appendNTimesAssumeCapacity(l: *MemoryMappedList, value: u8, n: usize) void {
        const new_len = l.items.len + n;
        assert(new_len <= l.capacity);
        @memset(l.items.ptr[l.items.len..new_len], value);
        l.items.len = new_len;
    }
};
