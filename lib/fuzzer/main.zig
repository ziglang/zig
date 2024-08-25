const builtin = @import("builtin");
const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const fatal = std.process.fatal;
const SeenPcsHeader = std.Build.Fuzz.abi.SeenPcsHeader;
const MemoryMappedList = @import("MemoryMappedList.zig");

const mutate = @import("mutate.zig");
const InputPool = @import("InputPool.zig");
const feature_capture = @import("feature_capture.zig");
const feature_util = @import("feature_util.zig");

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

const InitialFeatureBufferCap = 64;

pub const Fuzzer = struct {
    gpa: Allocator,
    rng: std.Random.DefaultPrng,
    cache_dir: std.fs.Dir,

    input_pool: InputPool = .{},

    mutate_scratch: std.ArrayListUnmanaged(u8) = .{},
    mutation_seed: u64 = undefined,
    mutation_len: usize = undefined,
    current_input_index: InputPool.Index = undefined,
    current_input_checksum: u8 = undefined,

    feature_buffer: []u32 = undefined,
    all_features: std.ArrayListUnmanaged(u32) = .{},

    // given to us by LLVM
    flagged_pcs: []const FlaggedPc = undefined,
    pc_counters: []u8 = undefined, // same length as flagged_pcs

    n_runs: usize = 0,

    /// Tracks which PCs have been seen across all runs that do not crash the fuzzer process.
    /// Stored in a memory-mapped file so that it can be shared with other
    /// processes and viewed while the fuzzer is running.
    seen_pcs: MemoryMappedList,

    /// Identifies the file name that will be used to store coverage
    /// information, available to other processes.
    coverage_id: u64,

    first_run: bool = true,

    pub fn init(f: *Fuzzer, cache_dir: std.fs.Dir) !void {
        f.cache_dir = cache_dir;

        assert(f.pc_counters.len == f.flagged_pcs.len);

        // Choose a file name for the coverage based on a hash of the PCs that
        // will be stored within.
        const pc_digest = hashPCs(f.flagged_pcs);
        f.coverage_id = pc_digest;
        const hex_digest = std.fmt.hex(pc_digest);
        const coverage_file_path = "v/" ++ hex_digest;

        f.feature_buffer = try f.gpa.alloc(u32, InitialFeatureBufferCap);

        f.seen_pcs = try initCoverageFile(f.cache_dir, coverage_file_path, f.flagged_pcs);
    }

    fn readOptions(f: *Fuzzer, options: *const std.testing.FuzzInputOptions) !void {
        for (options.corpus) |input| {
            try f.input_pool.insertString(f.gpa, input);
        }
    }

    pub fn makeUpInitialCorpus(f: *Fuzzer) !void {
        var buffer: [256]u8 = undefined;
        for (0..256) |len| {
            const slice = buffer[0..len];
            f.rng.fill(slice);
            try f.input_pool.insertString(f.gpa, slice);
        }
        // TODO: prune
    }

    fn pickInput(f: *Fuzzer) InputPool.Index {
        assert(f.input_pool.len() != 0);
        const index = f.rng.next() % f.input_pool.len();
        return @intCast(index);
    }

    fn doMutation(f: *Fuzzer, input: []u8, cap: usize) ![]u8 {
        f.mutation_seed = f.rng.next();
        f.mutate_scratch.clearRetainingCapacity();
        var ar = f.mutate_scratch.toManaged(f.gpa);
        const mutated = try mutate.mutate(input, cap, f.mutation_seed, &ar);
        f.mutate_scratch = ar.moveToUnmanaged();
        return mutated;
    }

    fn undoMutate(f: *Fuzzer, mutated: []u8) void {
        var ar = f.mutate_scratch.toManaged(f.gpa);
        // the string lives in input_pool the whole time so we can throw
        // away this here but the undo was done
        _ = mutate.mutateReverse(mutated, f.mutation_seed, &ar);
        f.mutate_scratch = ar.moveToUnmanaged();
        f.mutate_scratch.clearRetainingCapacity();
    }

    fn checksum(str: []const u8) u8 {
        // this is very bad checksum but since we run the user's code a lot, it
        // will probably eventually catch when they do it.
        var c: u8 = 0;
        for (str) |s| {
            c ^= s;
        }
        return c;
    }

    fn collectPcCounterFeatures(f: *Fuzzer) void {
        for (f.pc_counters, 0..) |counter, i_| {
            if (counter != 0) {
                const i: u32 = @intCast(i_);
                // TODO: does this do a lot of collisions?
                feature_capture.newFeature(std.hash.uint32(i));
            }
        }
    }

    fn growFeatureBuffer(f: *Fuzzer) !void {
        // we dont need to copy over the data so we try to resize and
        // fallback to new blank allocation
        const new_size = f.feature_buffer.len * 2;
        if (!f.gpa.resize(f.feature_buffer, new_size)) {
            std.log.info("growing feature buffer to {}", .{new_size});
            const new_feature_buffer = try f.gpa.alloc(u32, new_size);
            f.gpa.free(f.feature_buffer);
            f.feature_buffer = new_feature_buffer;
        } else {
            std.log.info("growing feature buffer to {} (resize)", .{new_size});
        }
    }

    /// Returns true if last run was good
    fn analyzeLastRun(f: *Fuzzer) !bool {
        const features = feature_capture.values();
        feature_util.sort(features);

        const analysis = feature_util.cmp(features, f.all_features.items);

        if (analysis.only_a == 0) {
            return false;
        }

        {
            var buffer: [256]u8 = undefined;
            var fba = std.heap.FixedBufferAllocator.init(&buffer);
            var ar = std.ArrayList(u8).init(fba.allocator());
            mutate.writeMutation(f.mutation_seed, ar.writer()) catch {};

            std.log.info("new unique run: F:{} \tN:{} \tC:{} \tM:{} \tT:{} \t{s}", .{
                features.len,
                analysis.only_a,
                analysis.both,
                analysis.only_b,
                f.all_features.items.len + analysis.only_a,
                ar.items,
            });
        }
        var ar = f.all_features.toManaged(f.gpa);
        try feature_util.merge(&ar, features);
        f.all_features = ar.moveToUnmanaged();
        incrementUniqueRuns(f.seen_pcs);
        updateGlobalCoverage(f.pc_counters, f.seen_pcs);
        return true;
    }

    pub fn next(f: *Fuzzer, options: *const std.testing.FuzzInputOptions) error{OutOfMemory}![]const u8 {
        incrementNumberOfRuns(f.seen_pcs);
        if (f.first_run) {
            f.first_run = false;
            try f.readOptions(options);
            std.log.info(
                \\ starting to fuzz with initial corpus of {}
                \\ F - this input features
                \\ N - this input new features
                \\ C - this input features already discovered
                \\ M - features this input missed but discovered by other
                \\ T - new total unique features
            , .{f.input_pool.len()});
            if (f.input_pool.len() == 0) {
                try f.makeUpInitialCorpus();
            }
        } else {
            var mutated_input = f.input_pool.getString(f.current_input_index);
            mutated_input.len = f.mutation_len;

            if (f.current_input_checksum != checksum(mutated_input)) {
                // TODO: report the input? it is not very useful since it was written to
                @panic("user code mutated input!");
            }

            f.collectPcCounterFeatures();

            if (feature_capture.is_full()) {
                try f.growFeatureBuffer();
                // rerun same input with larger buffer
                @memset(f.pc_counters, 0);
                feature_capture.prepare(f.feature_buffer);
                return mutated_input;
            }

            if (try f.analyzeLastRun()) {
                // !!! this invalidates mutated_input but not the index
                try f.input_pool.insertString(f.gpa, mutated_input);
            }

            // !!! we might have inserted the current input into input_pool,
            // which invalidated the pointers but not the indexes
            mutated_input = f.input_pool.getString(f.current_input_index);
            mutated_input.len = f.mutation_len;

            // this will restore the mutated input (inplace, in the input_pool)
            // ready for a different mutation
            f.undoMutate(mutated_input);

            // This invalidates the indexes
            f.input_pool.maybeRepack();
        }

        const mutated = b: { // select and mutate
            const input_index = f.pickInput();
            f.current_input_index = input_index;

            const input_extra = f.input_pool.getString(input_index);
            const input = input_extra[0 .. input_extra.len - InputPool.InputExtraBytes];
            const cap = input_extra.len;

            const mutated = try f.doMutation(input, cap);
            f.mutation_len = mutated.len;
            f.current_input_checksum = checksum(mutated);
            break :b mutated;
        };

        @memset(f.pc_counters, 0);
        feature_capture.prepare(f.feature_buffer);
        return mutated;
    }
};
