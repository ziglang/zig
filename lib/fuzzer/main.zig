const std = @import("std");
const builtin = @import("builtin");
const mutate = @import("mutate.zig");
const InputPool = @import("input_pool.zig").InputPool;
const MemoryMappedList = @import("memory_mapped_list.zig").MemoryMappedList;
const feature_capture = @import("feature_capture.zig");

const Allocator = std.mem.Allocator;
const File = std.fs.File;
const Dir = std.fs.Dir;
const ArrayList = std.ArrayList;
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const Options = std.testing.FuzzInputOptions;
const SeenPcsHeader = std.Build.Fuzz.abi.SeenPcsHeader;
const assert = std.debug.assert;
const fatal = std.process.fatal;

const Testee = *const fn ([*]const u8, usize) callconv(.C) void;

const InitialFeatureBufferCap = 64;

// currently unused
export threadlocal var __sancov_lowest_stack: usize = std.math.maxInt(usize);

/// Deduplicates array of sorted features
fn uniq(a: []u32) []u32 {
    var write: usize = 0;

    if (a.len == 0) return a;

    var last: u32 = a[0];
    a[write] = last;
    write += 1;

    for (a[1..]) |v| {
        if (v != last) {
            a[write] = v;
            write += 1;
            last = v;
        }
    }

    return a[0..write];
}

test uniq {
    var data: [9]u32 = (&[_]u32{ 0, 0, 1, 2, 2, 2, 3, 4, 4 }).*;
    const cropped = uniq(&data);
    try std.testing.expectEqualSlices(u32, &[_]u32{ 0, 1, 2, 3, 4 }, cropped);
}

/// sorted and dedeuplicated
fn getLastRunFeatures() []u32 {
    var features = feature_capture.values();
    std.mem.sort(u32, features, void{}, std.sort.asc(u32));
    features = uniq(features);
    return features;
}

pub const CmpResult = struct { only_a: u32, only_b: u32, both: u32 };

/// Compares two sorted lists of features
fn cmp(a: []const u32, b: []const u32) CmpResult {
    var ai: u32 = 0;
    var bi: u32 = 0;

    var only_a: u32 = 0;
    var only_b: u32 = 0;
    var both: u32 = 0;

    while (true) {
        if (ai == a.len) {
            only_b += @intCast(b[bi..].len);
            break;
        } else if (bi == b.len) {
            only_a += @intCast(a[ai..].len);
            break;
        }

        const i = a[ai];
        const j = b[bi];

        if (i < j) {
            only_a += 1;
            ai += 1;
        } else if (i > j) {
            only_b += 1;
            bi += 1;
        } else {
            both += 1;
            ai += 1;
            bi += 1;
        }
    }

    return .{
        .only_a = only_a,
        .only_b = only_b,
        .both = both,
    };
}

test cmp {
    const e = std.testing.expectEqual;
    const R = CmpResult;
    try e(R{ .only_a = 0, .only_b = 0, .both = 0 }, cmp(&.{}, &.{}));
    try e(R{ .only_a = 1, .only_b = 0, .both = 0 }, cmp(&.{1}, &.{}));
    try e(R{ .only_a = 0, .only_b = 1, .both = 0 }, cmp(&.{}, &.{1}));
    try e(R{ .only_a = 0, .only_b = 0, .both = 1 }, cmp(&.{1}, &.{1}));
    try e(R{ .only_a = 1, .only_b = 1, .both = 0 }, cmp(&.{1}, &.{2}));
    try e(R{ .only_a = 1, .only_b = 0, .both = 1 }, cmp(&.{ 1, 2 }, &.{1}));
    try e(R{ .only_a = 0, .only_b = 1, .both = 1 }, cmp(&.{1}, &.{ 1, 2 }));
    try e(R{ .only_a = 0, .only_b = 0, .both = 2 }, cmp(&.{ 1, 2 }, &.{ 1, 2 }));
    try e(R{ .only_a = 3, .only_b = 3, .both = 0 }, cmp(&.{ 1, 2, 3 }, &.{ 4, 5, 6 }));
}

/// Merges the second sorted list of features into the first list of sorted
/// features
fn merge(dest: *ArrayList(u32), src: []const u32) error{OutOfMemory}!void {
    // TODO: can be in O(n) time and O(1) extra space
    try dest.appendSlice(src);
    std.mem.sort(u32, dest.items, void{}, std.sort.asc(u32));
    dest.items = uniq(dest.items);
}

fn hashPCs(pcs: []const usize) u64 {
    var hasher = std.hash.Wyhash.init(0);
    hasher.update(std.mem.sliceAsBytes(pcs));
    return hasher.final();
}

/// File contains SeenPcsHeader and its trailing data
fn initCoverageFile(coverage_file: File, pcs: []const usize) MemoryMappedList(u8) {
    const n_bitset_elems = (pcs.len + @bitSizeOf(usize) - 1) / @bitSizeOf(usize);

    comptime assert(SeenPcsHeader.trailing[0] == .pc_bits_usize);
    comptime assert(SeenPcsHeader.trailing[1] == .pc_addr);

    // how long the file should be
    const bytes_len: usize = @sizeOf(SeenPcsHeader) + n_bitset_elems * @sizeOf(usize) + pcs.len * @sizeOf(usize);

    var seen_pcs: MemoryMappedList(u8) = .init(coverage_file, bytes_len);

    // how long the file actually is
    const existing_len: usize = seen_pcs.fileLen();

    if (existing_len == 0) {
        // init file content
        const header: SeenPcsHeader = .{
            .n_runs = 0,
            .unique_runs = 0,
            .pcs_len = pcs.len,
        };
        seen_pcs.appendSlice(std.mem.asBytes(&header));
        seen_pcs.appendNTimes(0, n_bitset_elems * @sizeOf(usize));
        for (pcs) |pc| {
            seen_pcs.appendSlice(std.mem.asBytes(&pc));
        }
    } else if (existing_len == bytes_len) {
        // check existing file is ok
        const existing_pcs_bytes = seen_pcs.items[@sizeOf(SeenPcsHeader) + @sizeOf(usize) * n_bitset_elems ..][0 .. pcs.len * @sizeOf(usize)];
        const existing_pcs = std.mem.bytesAsSlice(usize, existing_pcs_bytes);
        for (existing_pcs, pcs) |old, new| {
            if (old != new) {
                fatal("coverage file is invalid (pc missmatch)", .{});
            }
        }
    } else {
        fatal(
            "coverage file is invalid (wrong length. wanted {}, is {})",
            .{ bytes_len, existing_len },
        );
    }

    return seen_pcs;
}

/// Global coverage is set of all PCs that are covered by some fuzz input and
/// did not crash. They show up as green in the web ui
fn updateGlobalCoverage(pc_counters_: []const u8, seen_pcs_: MemoryMappedList(u8)) void {
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

fn incrementUniqueRuns(seen_pcs: MemoryMappedList(u8)) void {
    const header: *volatile SeenPcsHeader = @ptrCast(seen_pcs.items[0..@sizeOf(SeenPcsHeader)]);
    _ = @atomicRmw(usize, &header.unique_runs, .Add, 1, .monotonic);
}

fn incrementNumberOfRuns(seen_pcs: MemoryMappedList(u8)) void {
    const header: *volatile SeenPcsHeader = @ptrCast(seen_pcs.items[0..@sizeOf(SeenPcsHeader)]);
    _ = @atomicRmw(usize, &header.n_runs, .Add, 1, .monotonic);
}

fn initialCorpusRandom(ip: *InputPool, rng: std.Random) void {
    var buffer: [256]u8 = undefined;
    for (0..256) |len| {
        const slice = buffer[0..len];
        rng.bytes(slice);
        ip.insertString(slice);
    }
    // TODO: could prune
}

fn selectAndCopyInput(
    a: Allocator,
    ip: *InputPool,
    rng: std.Random,
    input_: ArrayListUnmanaged(u8),
) !ArrayListUnmanaged(u8) {
    var input = input_;
    const new_input_index = rng.intRangeLessThanBiased(u31, 0, ip.len());
    const new_input = ip.getString(new_input_index);

    // manual slice copy since appendSlice doesn't take volatile slice
    input.clearRetainingCapacity();
    try input.ensureTotalCapacity(a, new_input.len);
    input.items.len = new_input.len;
    @memcpy(input.items, new_input);

    return input;
}

fn logNewFeatures(
    seen_pcs: MemoryMappedList(u8),
    features: []u32,
    mutation_seed: u64,
    total_features: usize,
) void {
    var buffer: [128]u8 = undefined;
    var fba: std.heap.FixedBufferAllocator = .init(&buffer);
    var ar: ArrayList(u8) = .init(fba.allocator());
    mutate.writeMutation(mutation_seed, ar.writer()) catch {};
    std.log.info("new unique run: F:{} \tT:{} \t{s}", .{
        features.len,
        total_features,
        ar.items,
    });
    incrementUniqueRuns(seen_pcs);
}

fn checksum(str: []const u8) u8 {
    // this is very bad checksum but since we run the user's code a lot, it
    // will eventually catch when they do it.
    var c: u8 = 0;
    for (str) |s| {
        c ^= s;
    }
    return c;
}

fn collectPcCounterFeatures(pc_counters: []u8) void {
    for (pc_counters, 0..) |counter, i_| {
        if (counter != 0) {
            const i: u32 = @intCast(i_);
            // TODO: does this do a lot of collisions?
            feature_capture.newFeature(std.hash.uint32(i));
        }
    }
}

fn beforeRun(pc_counters: []u8, feature_buffer: []u32) void {
    @memset(pc_counters, 0);
    feature_capture.prepare(feature_buffer);
}

fn growFeatureBuffer(a: Allocator, feature_buffer: *ArrayListUnmanaged(u32)) !void {
    // avoid copying data
    const new_size = feature_buffer.items.len * 2;
    feature_buffer.clearRetainingCapacity();
    try feature_buffer.ensureTotalCapacity(a, new_size);
}

fn runInput(
    a: Allocator,
    test_one: Testee,
    feature_buffer: *ArrayListUnmanaged(u32),
    pc_counters: []u8,
    input: []const u8,
) !void {
    // loop for run retry
    while (true) {
        beforeRun(pc_counters, feature_buffer.items);

        test_one(input.ptr, input.len);

        collectPcCounterFeatures(pc_counters);

        if (feature_capture.is_full()) {
            try growFeatureBuffer(a, feature_buffer);
            // rerun same input with larger buffer. By doing this we keep the
            // feature_capture callback function trivial
            continue;
        }
        break;
    }
}

/// Returns true when the new features are interesting
fn analyzeFeatures(ip: *InputPool, features: []u32, input: []const u8, all_features: []const u32) bool {
    const analysis = cmp(features, all_features);

    if (analysis.only_a > 0) {
        ip.insertString(input);
        return true;
    }
    return false; // boring input
}

fn mergeInput(
    a: Allocator,
    seen_pcs: MemoryMappedList(u8),
    all_features: *ArrayListUnmanaged(u32),
    features: []u32,
    pc_counters: []u8,
) error{OutOfMemory}!void {
    var ar = all_features.toManaged(a);
    try merge(&ar, features);
    all_features.* = ar.moveToUnmanaged();
    updateGlobalCoverage(pc_counters, seen_pcs);
}

const Files = struct { buffer: File, meta: File, coverage: File };

fn initFilesBail(c: Dir, i: u64) Files {
    return setupFiles(c, i) catch |e| fatal("Failed to setup files: {}", .{e});
}

fn deinitFiles(f: Files) void {
    f.buffer.close();
    f.meta.close();
    f.coverage.close();
}

fn setupFiles(cache_dir: Dir, coverage_id: u64) !Files {
    // we create 1 folder and 3 files:
    // cache/v/
    // cache/v/***buffer
    // cache/v/***meta
    // cache/v/***coverage

    const hex_digest = std.fmt.hex(coverage_id);

    const flags = File.CreateFlags{ .read = true, .truncate = false };

    cache_dir.makeDir("v") catch |e| switch (e) {
        error.PathAlreadyExists => {},
        else => return e,
    };

    const buffer = try cache_dir.createFile("v/" ++ hex_digest ++ "buffer", flags);
    errdefer buffer.close();

    const meta = try cache_dir.createFile("v/" ++ hex_digest ++ "meta", flags);
    errdefer meta.close();

    const coverage = try cache_dir.createFile("v/" ++ hex_digest ++ "coverage", flags);
    errdefer coverage.close();

    return .{ .buffer = buffer, .meta = meta, .coverage = coverage };
}

pub const Fuzzer = struct {
    // given to us by LLVM
    pcs: []const usize,
    pc_counters: []u8, // same length as pcs

    /// Identifies the file name that will be used to store coverage
    /// information, available to other processes.
    coverage_id: u64,

    cache_dir: Dir,

    pub fn init(cache_dir: Dir, pc_counters: []u8, pcs: []usize) Fuzzer {
        assert(pc_counters.len == pcs.len);

        return .{
            .pcs = pcs,
            .pc_counters = pc_counters,
            .cache_dir = cache_dir,
            .coverage_id = hashPCs(pcs),
        };
    }

    pub fn start(f: *Fuzzer, test_one: Testee, options: Options) error{OutOfMemory}!void {
        var rng_impl = std.Random.DefaultPrng.init(0);
        const rng = rng_impl.random();

        var gpa_impl: std.heap.GeneralPurposeAllocator(.{}) = .{};
        const a = gpa_impl.allocator();

        var input: ArrayListUnmanaged(u8) = .empty;
        defer input.deinit(a);

        var mutate_scratch: ArrayListUnmanaged(u8) = .empty;
        defer mutate_scratch.deinit(a);

        var all_features: ArrayListUnmanaged(u32) = .empty;
        defer all_features.deinit(a);

        var feature_buffer: ArrayListUnmanaged(u32) = try .initCapacity(a, InitialFeatureBufferCap);
        defer feature_buffer.deinit(a);

        const files = initFilesBail(f.cache_dir, f.coverage_id);
        defer deinitFiles(files);

        // Tracks which PCs have been seen across all runs that do not crash the fuzzer process.
        // Stored in a memory-mapped file so that it can be shared with other
        // processes and viewed while the fuzzer is running.
        const seen_pcs = initCoverageFile(files.coverage, f.pcs);

        var ip = InputPool.init(files.meta, files.buffer);
        defer ip.deinit();

        std.log.info(
            \\Initial corpus of size {}
            \\F - this input features
            \\T - new unique features
        , .{ip.len()});

        if (ip.len() == 0) {
            initialCorpusRandom(&ip, rng);
        }

        for (options.corpus) |inp| {
            try runInput(a, test_one, &feature_buffer, f.pc_counters, inp);
            const features = getLastRunFeatures();
            if (analyzeFeatures(&ip, features, inp, all_features.items)) {
                try mergeInput(a, seen_pcs, &all_features, features, f.pc_counters);
            }
        }

        // fuzzer main loop
        while (true) {
            incrementNumberOfRuns(seen_pcs);
            input = try selectAndCopyInput(a, &ip, rng, input);
            const mutation_seed = rng.int(u64);
            assert(mutate_scratch.items.len == 0);
            try mutate.mutate(&input, mutation_seed, &mutate_scratch, a);
            const input_checksum = checksum(input.items);

            try runInput(a, test_one, &feature_buffer, f.pc_counters, input.items);

            if (input_checksum != checksum(input.items)) {
                // report the input? it is not very useful since it was written to
                std.process.fatal("User code mutated input!", .{});
            }

            const features = getLastRunFeatures();
            if (analyzeFeatures(&ip, features, input.items, all_features.items)) {
                logNewFeatures(seen_pcs, features, mutation_seed, all_features.items.len);
                try mergeInput(a, seen_pcs, &all_features, features, f.pc_counters);
            }

            mutate.mutateReverse(&input, mutation_seed, &mutate_scratch);
        }
    }
};
