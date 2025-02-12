const builtin = @import("builtin");
const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const fatal = std.process.fatal;
const SeenPcsHeader = std.Build.Fuzz.abi.SeenPcsHeader;

pub const std_options = std.Options{
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
    fuzzer.traceValue(pc ^ val);
    _ = val_size_in_bits;
    _ = cases;
    //std.log.debug("0x{x}: switch on value {d} ({d} bits) with {d} cases", .{
    //    pc, val, val_size_in_bits, cases.len,
    //});
}

export fn __sanitizer_cov_trace_pc_indir(callee: usize) void {
    // Not valuable because we already have pc tracing via 8bit counters.
    _ = callee;
    //const pc = @returnAddress();
    //fuzzer.traceValue(pc ^ callee);
    //std.log.debug("0x{x}: indirect call to 0x{x}", .{ pc, callee });
}

fn handleCmp(pc: usize, arg1: u64, arg2: u64) void {
    fuzzer.traceValue(pc ^ arg1 ^ arg2);
    //std.log.debug("0x{x}: comparison of {d} and {d}", .{ pc, arg1, arg2 });
}

const Fuzzer = struct {
    rng: std.Random.DefaultPrng,
    pcs: []const usize,
    pc_counters: []u8,
    n_runs: usize,
    traced_comparisons: std.AutoArrayHashMapUnmanaged(usize, void),
    /// Tracks which PCs have been seen across all runs that do not crash the fuzzer process.
    /// Stored in a memory-mapped file so that it can be shared with other
    /// processes and viewed while the fuzzer is running.
    seen_pcs: MemoryMappedList,
    cache_dir: std.fs.Dir,
    /// Identifies the file name that will be used to store coverage
    /// information, available to other processes.
    coverage_id: u64,
    unit_test_name: []const u8,

    /// The index corresponds to the file name within the f/ subdirectory.
    /// The string is the input.
    /// This data is read-only; it caches what is on the filesystem.
    corpus: std.ArrayListUnmanaged(Input),
    corpus_directory: std.Build.Cache.Directory,

    /// The next input that will be given to the testOne function. When the
    /// current process crashes, this memory-mapped file is used to recover the
    /// input.
    ///
    /// The file size corresponds to the capacity. The length is not stored
    /// and that is the next thing to work on!
    input: MemoryMappedList,

    const Input = struct {
        bytes: []u8,
        last_traced_comparison: usize,
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

    fn initNextInput(f: *Fuzzer) void {
        while (true) {
            const i = f.corpus.items.len;
            var buf: [30]u8 = undefined;
            const input_sub_path = std.fmt.bufPrint(&buf, "{d}", .{i}) catch unreachable;
            const input = f.corpus_directory.handle.readFileAlloc(gpa, input_sub_path, 1 << 31) catch |err| switch (err) {
                error.FileNotFound => {
                    // Make this one the next input.
                    const input_file = f.corpus_directory.handle.createFile(input_sub_path, .{
                        .exclusive = true,
                        .truncate = false,
                        .read = true,
                    }) catch |e| switch (e) {
                        error.PathAlreadyExists => continue,
                        else => fatal("unable to create '{}{d}: {s}", .{ f.corpus_directory, i, @errorName(err) }),
                    };
                    errdefer input_file.close();
                    // Initialize the mmap for the current input.
                    f.input = MemoryMappedList.create(input_file, 0, std.heap.page_size_max) catch |e| {
                        fatal("unable to init memory map for input at '{}{d}': {s}", .{
                            f.corpus_directory, i, @errorName(e),
                        });
                    };
                    break;
                },
                else => fatal("unable to read '{}{d}': {s}", .{ f.corpus_directory, i, @errorName(err) }),
            };
            errdefer gpa.free(input);
            f.corpus.append(gpa, .{
                .bytes = input,
                .last_traced_comparison = 0,
            }) catch |err| oom(err);
        }
    }

    fn addCorpusElem(f: *Fuzzer, input: []const u8) !void {
        try f.corpus.append(gpa, .{
            .bytes = try gpa.dupe(u8, input),
            .last_traced_comparison = 0,
        });
    }

    fn start(f: *Fuzzer) !void {
        const rng = fuzzer.rng.random();

        // Grab the corpus which is namespaced based on `unit_test_name`.
        {
            if (f.unit_test_name.len == 0) fatal("test runner never set unit test name", .{});
            const sub_path = try std.fmt.allocPrint(gpa, "f/{s}", .{f.unit_test_name});
            f.corpus_directory = .{
                .handle = f.cache_dir.makeOpenPath(sub_path, .{}) catch |err|
                    fatal("unable to open corpus directory 'f/{s}': {s}", .{ sub_path, @errorName(err) }),
                .path = sub_path,
            };
            initNextInput(f);
        }

        assert(f.n_runs == 0);

        // If the corpus is empty, synthesize one input.
        if (f.corpus.items.len == 0) {
            const len = rng.uintLessThanBiased(usize, 200);
            const slice = try gpa.alloc(u8, len);
            rng.bytes(slice);
            f.input.appendSliceAssumeCapacity(slice);
            try f.corpus.append(gpa, .{
                .bytes = slice,
                .last_traced_comparison = 0,
            });
            runOne(f, 0);
        }

        while (true) {
            const chosen_index = rng.uintLessThanBiased(usize, f.corpus.items.len);
            const modification = rng.enumValue(Mutation);
            f.mutateAndRunOne(chosen_index, modification);
        }
    }

    /// `x` represents a possible branch. It is the PC address of the possible
    /// branch site, hashed together with the value(s) used that determine to
    /// where it branches.
    fn traceValue(f: *Fuzzer, x: usize) void {
        errdefer |err| oom(err);
        try f.traced_comparisons.put(gpa, x, {});
    }

    const Mutation = enum {
        remove_byte,
        modify_byte,
        add_byte,
    };

    fn mutateAndRunOne(f: *Fuzzer, corpus_index: usize, mutation: Mutation) void {
        const rng = fuzzer.rng.random();
        f.input.clearRetainingCapacity();
        const old_input = f.corpus.items[corpus_index].bytes;
        f.input.ensureTotalCapacity(old_input.len + 1) catch @panic("mmap file resize failed");
        switch (mutation) {
            .remove_byte => {
                const omitted_index = rng.uintLessThanBiased(usize, old_input.len);
                f.input.appendSliceAssumeCapacity(old_input[0..omitted_index]);
                f.input.appendSliceAssumeCapacity(old_input[omitted_index + 1 ..]);
            },
            .modify_byte => {
                const modified_index = rng.uintLessThanBiased(usize, old_input.len);
                f.input.appendSliceAssumeCapacity(old_input);
                f.input.items[modified_index] = rng.int(u8);
            },
            .add_byte => {
                const modified_index = rng.uintLessThanBiased(usize, old_input.len);
                f.input.appendSliceAssumeCapacity(old_input[0..modified_index]);
                f.input.appendAssumeCapacity(rng.int(u8));
                f.input.appendSliceAssumeCapacity(old_input[modified_index..]);
            },
        }
        runOne(f, corpus_index);
    }

    fn runOne(f: *Fuzzer, corpus_index: usize) void {
        const header: *volatile SeenPcsHeader = @ptrCast(f.seen_pcs.items[0..@sizeOf(SeenPcsHeader)]);

        f.traced_comparisons.clearRetainingCapacity();
        @memset(f.pc_counters, 0);
        __sancov_lowest_stack = std.math.maxInt(usize);

        fuzzer_one(@volatileCast(f.input.items.ptr), f.input.items.len);

        f.n_runs += 1;
        _ = @atomicRmw(usize, &header.n_runs, .Add, 1, .monotonic);

        // Track code coverage from all runs.
        comptime assert(SeenPcsHeader.trailing[0] == .pc_bits_usize);
        const header_end_ptr: [*]volatile usize = @ptrCast(f.seen_pcs.items[@sizeOf(SeenPcsHeader)..]);
        const remainder = f.pcs.len % @bitSizeOf(usize);
        const aligned_len = f.pcs.len - remainder;
        const seen_pcs = header_end_ptr[0..aligned_len];
        const pc_counters = std.mem.bytesAsSlice([@bitSizeOf(usize)]u8, f.pc_counters[0..aligned_len]);
        const V = @Vector(@bitSizeOf(usize), u8);
        const zero_v: V = @splat(0);
        var fresh = false;
        var superset = true;

        for (header_end_ptr[0..pc_counters.len], pc_counters) |*elem, *array| {
            const v: V = array.*;
            const mask: usize = @bitCast(v != zero_v);
            const prev = @atomicRmw(usize, elem, .Or, mask, .monotonic);
            fresh = fresh or (prev | mask) != prev;
            superset = superset and (prev | mask) != mask;
        }
        if (remainder > 0) {
            const i = pc_counters.len;
            const elem = &seen_pcs[i];
            var mask: usize = 0;
            for (f.pc_counters[i * @bitSizeOf(usize) ..][0..remainder], 0..) |byte, bit_index| {
                mask |= @as(usize, @intFromBool(byte != 0)) << @intCast(bit_index);
            }
            const prev = @atomicRmw(usize, elem, .Or, mask, .monotonic);
            fresh = fresh or (prev | mask) != prev;
            superset = superset and (prev | mask) != mask;
        }

        // First check if this is a better version of an already existing
        // input, replacing that input.
        if (superset or f.traced_comparisons.entries.len >= f.corpus.items[corpus_index].last_traced_comparison) {
            const new_input = gpa.realloc(f.corpus.items[corpus_index].bytes, f.input.items.len) catch |err| oom(err);
            f.corpus.items[corpus_index] = .{
                .bytes = new_input,
                .last_traced_comparison = f.traced_comparisons.count(),
            };
            @memcpy(new_input, @volatileCast(f.input.items));
            _ = @atomicRmw(usize, &header.unique_runs, .Add, 1, .monotonic);
            return;
        }

        if (!fresh) return;

        // Input is already committed to the file system, we just need to open a new file
        // for the next input.
        // Pre-add it to the corpus list so that it does not get redundantly picked up.
        f.corpus.append(gpa, .{
            .bytes = gpa.dupe(u8, @volatileCast(f.input.items)) catch |err| oom(err),
            .last_traced_comparison = f.traced_comparisons.entries.len,
        }) catch |err| oom(err);
        f.input.deinit();
        initNextInput(f);

        // TODO: also mark input as "hot" so it gets prioritized for checking mutations above others.

        _ = @atomicRmw(usize, &header.unique_runs, .Add, 1, .monotonic);
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

var debug_allocator: std.heap.GeneralPurposeAllocator(.{}) = .init;

const gpa = switch (builtin.mode) {
    .Debug => debug_allocator.allocator(),
    .ReleaseFast, .ReleaseSmall, .ReleaseSafe => std.heap.smp_allocator,
};

var fuzzer: Fuzzer = .{
    .rng = std.Random.DefaultPrng.init(0),
    .input = undefined,
    .pcs = undefined,
    .pc_counters = undefined,
    .n_runs = 0,
    .cache_dir = undefined,
    .seen_pcs = undefined,
    .coverage_id = undefined,
    .unit_test_name = &.{},
    .corpus = .empty,
    .corpus_directory = undefined,
    .traced_comparisons = .empty,
};

/// Invalid until `fuzzer_init` is called.
export fn fuzzer_coverage_id() u64 {
    return fuzzer.coverage_id;
}

var fuzzer_one: *const fn (input_ptr: [*]const u8, input_len: usize) callconv(.C) void = undefined;

export fn fuzzer_start(testOne: @TypeOf(fuzzer_one)) void {
    fuzzer_one = testOne;
    fuzzer.start() catch |err| oom(err);
}

export fn fuzzer_set_name(name_ptr: [*]const u8, name_len: usize) void {
    fuzzer.unit_test_name = name_ptr[0..name_len];
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

export fn fuzzer_init_corpus_elem(input_ptr: [*]const u8, input_len: usize) void {
    fuzzer.addCorpusElem(input_ptr[0..input_len]) catch |err|
        fatal("failed to add corpus element: {s}", .{@errorName(err)});
}

/// Like `std.ArrayListUnmanaged(u8)` but backed by memory mapping.
pub const MemoryMappedList = struct {
    /// Contents of the list.
    ///
    /// Pointers to elements in this slice are invalidated by various functions
    /// of this ArrayList in accordance with the respective documentation. In
    /// all cases, "invalidated" means that the memory has been passed to this
    /// allocator's resize or free function.
    items: []align(std.heap.page_size_min) volatile u8,
    /// How many bytes this list can hold without allocating additional memory.
    capacity: usize,
    /// The file is kept open so that it can be resized.
    file: std.fs.File,

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
            .file = file,
            .items = ptr[0..length],
            .capacity = capacity,
        };
    }

    pub fn create(file: std.fs.File, length: usize, capacity: usize) !MemoryMappedList {
        try file.setEndPos(capacity);
        return init(file, length, capacity);
    }

    pub fn deinit(l: *MemoryMappedList) void {
        l.file.close();
        std.posix.munmap(@volatileCast(l.items.ptr[0..l.capacity]));
        l.* = undefined;
    }

    /// Modify the array so that it can hold at least `additional_count` **more** items.
    /// Invalidates element pointers if additional memory is needed.
    pub fn ensureUnusedCapacity(l: *MemoryMappedList, additional_count: usize) !void {
        return l.ensureTotalCapacity(l.items.len + additional_count);
    }

    /// If the current capacity is less than `new_capacity`, this function will
    /// modify the array so that it can hold at least `new_capacity` items.
    /// Invalidates element pointers if additional memory is needed.
    pub fn ensureTotalCapacity(l: *MemoryMappedList, new_capacity: usize) !void {
        if (l.capacity >= new_capacity) return;

        const better_capacity = growCapacity(l.capacity, new_capacity);
        return l.ensureTotalCapacityPrecise(better_capacity);
    }

    pub fn ensureTotalCapacityPrecise(l: *MemoryMappedList, new_capacity: usize) !void {
        if (l.capacity >= new_capacity) return;

        std.posix.munmap(@volatileCast(l.items.ptr[0..l.capacity]));
        try l.file.setEndPos(new_capacity);
        l.* = try init(l.file, l.items.len, new_capacity);
    }

    /// Invalidates all element pointers.
    pub fn clearRetainingCapacity(l: *MemoryMappedList) void {
        l.items.len = 0;
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

    /// Extends the list by 1 element.
    /// Never invalidates element pointers.
    /// Asserts that the list can hold one additional item.
    pub fn appendAssumeCapacity(l: *MemoryMappedList, item: u8) void {
        const new_item_ptr = l.addOneAssumeCapacity();
        new_item_ptr.* = item;
    }

    /// Increase length by 1, returning pointer to the new item.
    /// The returned pointer becomes invalid when the list is resized.
    /// Never invalidates element pointers.
    /// Asserts that the list can hold one additional item.
    pub fn addOneAssumeCapacity(l: *MemoryMappedList) *volatile u8 {
        assert(l.items.len < l.capacity);
        l.items.len += 1;
        return &l.items[l.items.len - 1];
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

    /// Resize the array, adding `n` new elements, which have `undefined` values.
    /// The return value is a slice pointing to the newly allocated elements.
    /// Never invalidates element pointers.
    /// The returned pointer becomes invalid when the list is resized.
    /// Asserts that the list can hold the additional items.
    pub fn addManyAsSliceAssumeCapacity(l: *MemoryMappedList, n: usize) []volatile u8 {
        assert(l.items.len + n <= l.capacity);
        const prev_len = l.items.len;
        l.items.len += n;
        return l.items[prev_len..][0..n];
    }

    /// Called when memory growth is necessary. Returns a capacity larger than
    /// minimum that grows super-linearly.
    fn growCapacity(current: usize, minimum: usize) usize {
        var new = current;
        while (true) {
            new = std.mem.alignForward(usize, new + new / 2, std.heap.page_size_max);
            if (new >= minimum) return new;
        }
    }
};
