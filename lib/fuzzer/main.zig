const builtin = @import("builtin");
const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const SeenPcsHeader = std.Build.Fuzz.abi.SeenPcsHeader;
const MemoryMappedList = @import("memory_mapped_list.zig").MemoryMappedList;

const mutate = @import("mutate.zig");
const InputPool = @import("input_pool.zig").InputPool;
const feature_capture = @import("feature_capture.zig");

// current unused
export threadlocal var __sancov_lowest_stack: usize = std.math.maxInt(usize);

/// Returns error union payload or void if error set
fn StripError(comptime T: type) type {
    return switch (@typeInfo(T)) {
        .error_union => |eu| eu.payload,
        .error_set => void,
        else => @compileError("no error to strip"),
    };
}

/// Checks that the value is not error. If it is error, it logs the args and
/// terminates
pub fn check(src: std.builtin.SourceLocation, v: anytype, args: anytype) StripError(@TypeOf(v)) {
    return v catch |e| {
        var buffer: [4096]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&buffer);
        var cw = std.io.countingWriter(fbs.writer());
        const w = cw.writer();
        if (@typeInfo(@TypeOf(args)).@"struct".fields.len != 0) {
            w.writeAll(" (") catch {};
            inline for (@typeInfo(@TypeOf(args)).@"struct".fields, 0..) |field, i| {
                const Field = @TypeOf(@field(args, field.name));
                if (i != 0) {
                    w.writeAll(", ") catch {};
                }
                if (Field == []const u8 or Field == []u8) {
                    w.print("{s}='{s}'", .{ field.name, @field(args, field.name) }) catch {};
                } else {
                    w.print("{s}={any}", .{ field.name, @field(args, field.name) }) catch {};
                }
            }
            w.writeAll(")") catch {};
        }
        std.process.fatal("{s}:{}: {s}{s}", .{ src.file, src.line, @errorName(e), buffer[0..cw.bytes_written] });
    };
}

/// Type for passing slices across extern functions where we can't use zig
/// types
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

fn createFileBail(dir: std.fs.Dir, sub_path: []const u8, flags: std.fs.File.CreateFlags) std.fs.File {
    return dir.createFile(sub_path, flags) catch |err| switch (err) {
        error.FileNotFound => {
            const dir_name = std.fs.path.dirname(sub_path).?;
            check(@src(), dir.makePath(dir_name), .{ .dir_name = dir_name });
            return check(@src(), dir.createFile(sub_path, flags), .{ .sub_path = sub_path, .flags = flags });
        },
        else => |e| std.process.fatal("create file '{s}' failed: {}", .{ sub_path, e }),
    };
}

/// Sorts array of features
fn sort(a: []u32) void {
    std.mem.sort(u32, a, void{}, std.sort.asc(u32));
}

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
fn merge(dest: *std.ArrayList(u32), src: []const u32) !void {
    // TODO: can be in O(n) time and O(1) space
    try dest.appendSlice(src);
    sort(dest.items);
    dest.items = uniq(dest.items);
}

fn hashPCs(pcs: []const usize) u64 {
    var hasher = std.hash.Wyhash.init(0);
    hasher.update(std.mem.asBytes(pcs));
    return hasher.final();
}

/// Layout of this file:
/// - Header
/// - list of PC addresses (usize elements)
/// - list of hit flag, 1 bit per address (stored in u8 elements)
fn initCoverageFile(cache_dir: std.fs.Dir, coverage_file_path: []const u8, pcs: []const usize) MemoryMappedList(u8) {
    const coverage_file = createFileBail(cache_dir, coverage_file_path, .{
        .read = true,
        .truncate = false,
    });
    defer coverage_file.close();
    const n_bitset_elems = (pcs.len + @bitSizeOf(usize) - 1) / @bitSizeOf(usize);

    comptime assert(SeenPcsHeader.trailing[0] == .pc_bits_usize);
    comptime assert(SeenPcsHeader.trailing[1] == .pc_addr);

    // how long the file should be
    const bytes_len = @sizeOf(SeenPcsHeader) + n_bitset_elems * @sizeOf(usize) + pcs.len * @sizeOf(usize);

    var seen_pcs = MemoryMappedList(u8).init(coverage_file, bytes_len);

    // how long the file actually is
    const existing_len = seen_pcs.items.len;

    if (existing_len != 0 and existing_len != bytes_len)
        std.process.fatal("coverage file '{s}' is invalid (wrong length)", .{coverage_file_path});

    if (existing_len != 0) {
        // check existing file is ok
        const existing_pcs_bytes = seen_pcs.items[@sizeOf(SeenPcsHeader) + @sizeOf(usize) * n_bitset_elems ..][0 .. pcs.len * @sizeOf(usize)];
        const existing_pcs = std.mem.bytesAsSlice(usize, existing_pcs_bytes);
        for (existing_pcs, pcs) |old, new| {
            if (old != new) {
                std.process.fatal("coverage file '{s}' is invalid (pc missmatch)", .{coverage_file_path});
            }
        }
    } else {
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
        std.debug.assert(seen_pcs.items.len == bytes_len);
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

const InitialFeatureBufferCap = 64;

pub const Fuzzer = struct {
    gpa: Allocator,
    rng: std.Random.DefaultPrng,
    cache_dir: std.fs.Dir,

    input_pool: InputPool,

    mutate_scratch: ArrayListUnmanaged(u8) = .{},
    mutation_seed: u64 = undefined,
    mutation_len: usize = undefined,
    current_input: ArrayListUnmanaged(u8) = .{},
    current_input_checksum: u8 = undefined,

    feature_buffer: []u32 = undefined,
    all_features: ArrayListUnmanaged(u32) = .{},

    // given to us by LLVM
    pcs: []const usize,
    pc_counters: []u8, // same length as pcs

    n_runs: usize = 0,

    /// Tracks which PCs have been seen across all runs that do not crash the fuzzer process.
    /// Stored in a memory-mapped file so that it can be shared with other
    /// processes and viewed while the fuzzer is running.
    seen_pcs: MemoryMappedList(u8),

    /// Identifies the file name that will be used to store coverage
    /// information, available to other processes.
    coverage_id: u64,

    first_run: bool = true,

    /// When we boot, we need to iterate over all corpus inputs and run them
    /// once, populating initial feature set. When we are walking the corpus,
    /// this variable stores current input index. After the walk is done, we
    /// set it to null
    corpus_walk: ?usize = null,

    pub fn init(gpa: Allocator, cache_dir: std.fs.Dir, pc_counters: []u8, pcs: []usize) Fuzzer {
        assert(pc_counters.len == pcs.len);

        // Choose a file name for the coverage based on a hash of the PCs that
        // will be stored within.
        const pc_digest = hashPCs(pcs);
        const coverage_id = pc_digest;
        const hex_digest = std.fmt.hex(pc_digest);
        const coverage_file_path = "v/" ++ hex_digest ++ "coverage";

        const feature_buffer = check(@src(), gpa.alloc(u32, InitialFeatureBufferCap), .{});

        const seen_pcs = initCoverageFile(cache_dir, coverage_file_path, pcs);

        const input_pool = InputPool.init(cache_dir, pc_digest);

        return .{
            .gpa = gpa,
            .rng = std.Random.DefaultPrng.init(0),
            .coverage_id = coverage_id,
            .cache_dir = cache_dir,
            .pcs = pcs,
            .pc_counters = pc_counters,
            .seen_pcs = seen_pcs,
            .feature_buffer = feature_buffer,
            .input_pool = input_pool,
        };
    }

    pub fn deinit(f: *Fuzzer) void {
        f.input_pool.deinit();
        f.seen_pcs.deinit();
    }

    fn readOptions(f: *Fuzzer, options: *const std.testing.FuzzInputOptions) void {
        // Otherwise the options corpus would be re-added every time we restart
        // the fuzzer
        if (f.input_pool.len() == 0) {
            for (options.corpus) |input| {
                f.input_pool.insertString(input);
            }
        }
    }

    fn makeUpInitialCorpus(f: *Fuzzer) void {
        var buffer: [256]u8 = undefined;
        for (0..256) |len| {
            const slice = buffer[0..len];
            f.rng.fill(slice);
            f.input_pool.insertString(slice);
        }
        // TODO: prune
    }

    fn pickInput(f: *Fuzzer) InputPool.Index {
        const input_pool_len = f.input_pool.len();
        assert(input_pool_len != 0);

        if (f.corpus_walk) |w| {
            if (w == input_pool_len) {
                std.log.info("corpus walk done after walking {} inputs", .{w});
                f.corpus_walk = null;
            } else {
                f.corpus_walk = w + 1;
                return @intCast(w);
            }
        }

        const index = f.rng.next() % input_pool_len;
        return @intCast(index);
    }

    fn doMutation(f: *Fuzzer) void {
        if (f.corpus_walk != null) return;

        f.mutation_seed = f.rng.next();
        f.mutate_scratch.clearRetainingCapacity();

        var ar_scratch = f.mutate_scratch.toManaged(f.gpa);
        var ar_input = f.current_input.toManaged(f.gpa);
        check(@src(), mutate.mutate(&ar_input, f.mutation_seed, &ar_scratch), .{ .seed = f.mutation_seed });
        f.mutate_scratch = ar_scratch.moveToUnmanaged();
        f.current_input = ar_input.moveToUnmanaged();
    }

    fn undoMutate(f: *Fuzzer) void {
        if (f.corpus_walk != null) return;

        var ar_scratch = f.mutate_scratch.toManaged(f.gpa);
        var ar_input = f.current_input.toManaged(f.gpa);
        mutate.mutateReverse(&ar_input, f.mutation_seed, &ar_scratch);
        f.mutate_scratch = ar_scratch.moveToUnmanaged();
        f.current_input = ar_input.moveToUnmanaged();

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

    fn growFeatureBuffer(f: *Fuzzer) void {
        // we dont need to copy over the data so we try to resize and
        // fallback to new blank allocation
        const new_size = f.feature_buffer.len * 2;
        if (!f.gpa.resize(f.feature_buffer, new_size)) {
            std.log.info("growing feature buffer to {}", .{new_size});
            const new_feature_buffer = check(@src(), f.gpa.alloc(u32, new_size), .{ .size = new_size });
            f.gpa.free(f.feature_buffer);
            f.feature_buffer = new_feature_buffer;
        } else {
            std.log.info("growing feature buffer to {} (resize)", .{new_size});
        }
    }

    fn analyzeLastRun(f: *Fuzzer) void {
        var features = feature_capture.values();
        sort(features);
        features = uniq(features);

        const analysis = cmp(features, f.all_features.items);

        if (analysis.only_a == 0) {
            return; // bad input
        }

        if (f.corpus_walk == null) {
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
            incrementUniqueRuns(f.seen_pcs);
            f.input_pool.insertString(f.current_input.items);
        }

        var ar = f.all_features.toManaged(f.gpa);
        check(@src(), merge(&ar, features), .{});
        f.all_features = ar.moveToUnmanaged();
        updateGlobalCoverage(f.pc_counters, f.seen_pcs);
    }

    fn selectAndMutate(f: *Fuzzer) void {
        const input_index = f.pickInput();

        const input_extra = f.input_pool.getString(input_index);
        const input = input_extra[0..input_extra.len];

        f.current_input.clearRetainingCapacity();

        // manual slice append since appendSlice doesn't take volatile slice
        check(@src(), f.current_input.ensureTotalCapacity(f.gpa, input.len), .{ .input_len = input.len });
        f.current_input.items.len = input.len;
        @memcpy(f.current_input.items, input);

        f.doMutation();
        f.current_input_checksum = checksum(f.current_input.items);
    }

    fn beforeRun(f: *Fuzzer) void {
        @memset(f.pc_counters, 0);
        feature_capture.prepare(f.feature_buffer);
    }

    fn firstRun(f: *Fuzzer, options: *const std.testing.FuzzInputOptions) void {
        f.readOptions(options);
        std.log.info(
            \\ starting to fuzz with initial corpus of {}
            \\ F - this input features
            \\ N - this input new features
            \\ C - this input features already discovered
            \\ M - features this input missed but discovered by other
            \\ T - new total unique features
        , .{f.input_pool.len()});
        if (f.input_pool.len() == 0) {
            f.makeUpInitialCorpus();
        }
        std.log.info("starting corpus walk", .{});
        f.corpus_walk = 0;
    }

    pub fn next(f: *Fuzzer, options: *const std.testing.FuzzInputOptions) []const u8 {
        incrementNumberOfRuns(f.seen_pcs);

        if (f.first_run) {
            f.first_run = false;
            f.firstRun(options);
        } else {
            if (f.current_input_checksum != checksum(f.current_input.items)) {
                // TODO: report the input? it is not very useful since it was written to
                @panic("user code mutated input!");
            }

            f.collectPcCounterFeatures();

            if (feature_capture.is_full()) {
                f.growFeatureBuffer();
                // rerun same input with larger buffer
                f.beforeRun();
                return f.current_input.items;
            }

            f.analyzeLastRun();

            f.undoMutate();
        }

        f.selectAndMutate();

        f.beforeRun();
        return f.current_input.items;
    }
};
