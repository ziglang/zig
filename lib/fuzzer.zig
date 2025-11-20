const builtin = @import("builtin");
const std = @import("std");
const fatal = std.process.fatal;
const mem = std.mem;
const math = std.math;
const Allocator = mem.Allocator;
const assert = std.debug.assert;
const panic = std.debug.panic;
const abi = std.Build.abi.fuzz;
const native_endian = builtin.cpu.arch.endian();

pub const std_options = std.Options{
    .logFn = logOverride,
};

fn logOverride(
    comptime level: std.log.Level,
    comptime scope: @Type(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    const f = log_f orelse
        panic("attempt to use log before initialization, message:\n" ++ format, args);
    f.lock(.exclusive) catch |e| panic("failed to lock logging file: {t}", .{e});
    defer f.unlock();

    var buf: [256]u8 = undefined;
    var fw = f.writer(&buf);
    const end = f.getEndPos() catch |e| panic("failed to get fuzzer log file end: {t}", .{e});
    fw.seekTo(end) catch |e| panic("failed to seek to fuzzer log file end: {t}", .{e});

    const prefix1 = comptime level.asText();
    const prefix2 = if (scope == .default) ": " else "(" ++ @tagName(scope) ++ "): ";
    fw.interface.print(
        "[{s}] " ++ prefix1 ++ prefix2 ++ format ++ "\n",
        .{current_test_name orelse "setup"} ++ args,
    ) catch panic("failed to write to fuzzer log: {t}", .{fw.err.?});
    fw.interface.flush() catch panic("failed to write to fuzzer log: {t}", .{fw.err.?});
}

var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
const gpa = switch (builtin.mode) {
    .Debug => debug_allocator.allocator(),
    .ReleaseFast, .ReleaseSmall, .ReleaseSafe => std.heap.smp_allocator,
};

/// Part of `exec`, however seperate to allow it to be set before `exec` is.
var log_f: ?std.fs.File = null;
var exec: Executable = .preinit;
var inst: Instrumentation = .preinit;
var fuzzer: Fuzzer = undefined;
var current_test_name: ?[]const u8 = null;

fn bitsetUsizes(elems: usize) usize {
    return math.divCeil(usize, elems, @bitSizeOf(usize)) catch unreachable;
}

const Executable = struct {
    /// Tracks the hit count for each pc as updated by the process's instrumentation.
    pc_counters: []u8,

    cache_f: std.fs.Dir,
    /// Shared copy of all pcs that have been hit stored in a memory-mapped file that can viewed
    /// while the fuzzer is running.
    shared_seen_pcs: MemoryMappedList,
    /// Hash of pcs used to uniquely identify the shared coverage file
    pc_digest: u64,

    /// A minimal state for this struct which instrumentation can function on.
    /// Used before this structure is initialized to avoid illegal behavior
    /// from instrumentation functions being called and using undefined values.
    pub const preinit: Executable = .{
        .pc_counters = undefined, // instrumentation works off the __sancov_cntrs section
        .cache_f = undefined,
        .shared_seen_pcs = undefined,
        .pc_digest = undefined,
    };

    fn getCoverageFile(cache_dir: std.fs.Dir, pcs: []const usize, pc_digest: u64) MemoryMappedList {
        const pc_bitset_usizes = bitsetUsizes(pcs.len);
        const coverage_file_name = std.fmt.hex(pc_digest);
        comptime assert(abi.SeenPcsHeader.trailing[0] == .pc_bits_usize);
        comptime assert(abi.SeenPcsHeader.trailing[1] == .pc_addr);

        var v = cache_dir.makeOpenPath("v", .{}) catch |e|
            panic("failed to create directory 'v': {t}", .{e});
        defer v.close();
        const coverage_file, const populate = if (v.createFile(&coverage_file_name, .{
            .read = true,
            // If we create the file, we want to block other processes while we populate it
            .lock = .exclusive,
            .exclusive = true,
        })) |f|
            .{ f, true }
        else |e| switch (e) {
            error.PathAlreadyExists => .{ v.openFile(&coverage_file_name, .{
                .mode = .read_write,
                .lock = .shared,
            }) catch |e2| panic(
                "failed to open existing coverage file '{s}': {t}",
                .{ &coverage_file_name, e2 },
            ), false },
            else => panic("failed to create coverage file '{s}': {t}", .{ &coverage_file_name, e }),
        };

        const coverage_file_len = @sizeOf(abi.SeenPcsHeader) +
            pc_bitset_usizes * @sizeOf(usize) +
            pcs.len * @sizeOf(usize);

        if (populate) {
            defer coverage_file.lock(.shared) catch |e| panic(
                "failed to demote lock for coverage file '{s}': {t}",
                .{ &coverage_file_name, e },
            );
            var map = MemoryMappedList.create(coverage_file, 0, coverage_file_len) catch |e| panic(
                "failed to init memory map for coverage file '{s}': {t}",
                .{ &coverage_file_name, e },
            );
            map.appendSliceAssumeCapacity(@ptrCast(&abi.SeenPcsHeader{
                .n_runs = 0,
                .unique_runs = 0,
                .pcs_len = pcs.len,
            }));
            map.appendNTimesAssumeCapacity(0, pc_bitset_usizes * @sizeOf(usize));
            // Relocations have been applied to `pcs` so it contains runtime addresses (with slide
            // applied). We need to translate these to the virtual addresses as on disk.
            for (pcs) |pc| {
                const pc_vaddr = fuzzer_unslide_address(pc);
                map.appendSliceAssumeCapacity(@ptrCast(&pc_vaddr));
            }
            return map;
        } else {
            const size = coverage_file.getEndPos() catch |e| panic(
                "failed to stat coverage file '{s}': {t}",
                .{ &coverage_file_name, e },
            );
            if (size != coverage_file_len) panic(
                "incompatible existing coverage file '{s}' (differing lengths: {} != {})",
                .{ &coverage_file_name, size, coverage_file_len },
            );

            const map = MemoryMappedList.init(
                coverage_file,
                coverage_file_len,
                coverage_file_len,
            ) catch |e| panic(
                "failed to init memory map for coverage file '{s}': {t}",
                .{ &coverage_file_name, e },
            );

            const seen_pcs_header: *const abi.SeenPcsHeader = @ptrCast(@volatileCast(map.items));
            if (seen_pcs_header.pcs_len != pcs.len) panic(
                "incompatible existing coverage file '{s}' (differing pcs length: {} != {})",
                .{ &coverage_file_name, seen_pcs_header.pcs_len, pcs.len },
            );
            if (mem.indexOfDiff(usize, seen_pcs_header.pcAddrs(), pcs)) |i| panic(
                "incompatible existing coverage file '{s}' (differing pc at index {d}: {x} != {x})",
                .{ &coverage_file_name, i, seen_pcs_header.pcAddrs()[i], pcs[i] },
            );

            return map;
        }
    }

    pub fn init(cache_dir_path: []const u8) Executable {
        var self: Executable = undefined;

        const cache_dir = std.fs.cwd().makeOpenPath(cache_dir_path, .{}) catch |e| panic(
            "failed to open directory '{s}': {t}",
            .{ cache_dir_path, e },
        );
        log_f = cache_dir.createFile("tmp/libfuzzer.log", .{ .truncate = false }) catch |e|
            panic("failed to create file 'tmp/libfuzzer.log': {t}", .{e});
        self.cache_f = cache_dir.makeOpenPath("f", .{}) catch |e|
            panic("failed to open directory 'f': {t}", .{e});

        // Linkers are expected to automatically add symbols prefixed with these for the start and
        // end of sections whose names are valid C identifiers.
        const ofmt = builtin.object_format;
        const section_start_prefix, const section_end_prefix = switch (ofmt) {
            .elf => .{ "__start_", "__stop_" },
            .macho => .{ "\x01section$start$__DATA$", "\x01section$end$__DATA$" },
            else => @compileError("unsupported fuzzing object format '" ++ @tagName(ofmt) ++ "'"),
        };

        self.pc_counters = blk: {
            const pc_counters_start_name = section_start_prefix ++ "__sancov_cntrs";
            const pc_counters_start = @extern([*]u8, .{
                .name = pc_counters_start_name,
                .linkage = .weak,
            }) orelse panic("missing {s} symbol", .{pc_counters_start_name});

            const pc_counters_end_name = section_end_prefix ++ "__sancov_cntrs";
            const pc_counters_end = @extern([*]u8, .{
                .name = pc_counters_end_name,
                .linkage = .weak,
            }) orelse panic("missing {s} symbol", .{pc_counters_end_name});

            break :blk pc_counters_start[0 .. pc_counters_end - pc_counters_start];
        };

        const pcs = blk: {
            const pcs_start_name = section_start_prefix ++ "__sancov_pcs1";
            const pcs_start = @extern([*]usize, .{
                .name = pcs_start_name,
                .linkage = .weak,
            }) orelse panic("missing {s} symbol", .{pcs_start_name});

            const pcs_end_name = section_end_prefix ++ "__sancov_pcs1";
            const pcs_end = @extern([*]usize, .{
                .name = pcs_end_name,
                .linkage = .weak,
            }) orelse panic("missing {s} symbol", .{pcs_end_name});

            break :blk pcs_start[0 .. pcs_end - pcs_start];
        };

        if (self.pc_counters.len != pcs.len) panic(
            "pc counters length and pcs length do not match ({} != {})",
            .{ self.pc_counters.len, pcs.len },
        );

        self.pc_digest = digest: {
            // Relocations have been applied to `pcs` so it contains runtime addresses (with slide
            // applied). We need to translate these to the virtual addresses as on disk.
            var h: std.hash.Wyhash = .init(0);
            for (pcs) |pc| {
                const pc_vaddr = fuzzer_unslide_address(pc);
                h.update(@ptrCast(&pc_vaddr));
            }
            break :digest h.final();
        };
        self.shared_seen_pcs = getCoverageFile(cache_dir, pcs, self.pc_digest);

        return self;
    }

    pub fn pcBitsetIterator(self: Executable) PcBitsetIterator {
        return .{ .pc_counters = self.pc_counters };
    }

    /// Iterates over pc_counters returning a bitset for if each of them have been hit
    pub const PcBitsetIterator = struct {
        index: usize = 0,
        pc_counters: []u8,

        pub fn next(self: *PcBitsetIterator) usize {
            const rest = self.pc_counters[self.index..];
            if (rest.len >= @bitSizeOf(usize)) {
                defer self.index += @bitSizeOf(usize);
                const V = @Vector(@bitSizeOf(usize), u8);
                return @as(usize, @bitCast(@as(V, @splat(0)) != rest[0..@bitSizeOf(usize)].*));
            } else if (rest.len != 0) {
                defer self.index += rest.len;
                var res: usize = 0;
                for (0.., rest) |bit_index, byte| {
                    res |= @shlExact(@as(usize, @intFromBool(byte != 0)), @intCast(bit_index));
                }
                return res;
            } else unreachable;
        }
    };
};

/// Data gathered from instrumentation functions.
/// Seperate from Executable since its state is resetable and changes.
/// Seperate from Fuzzer since it may be needed before fuzzing starts.
const Instrumentation = struct {
    /// Bitset of seen pcs across all runs excluding fresh pcs.
    /// This is seperate then shared_seen_pcs because multiple fuzzing processes are likely using
    /// it which causes contention and unrelated pcs to our campaign being set.
    seen_pcs: []usize,

    /// Stores a fresh input's new pcs
    fresh_pcs: []usize,

    /// Pcs which __sanitizer_cov_trace_switch and __sanitizer_cov_trace_const_cmpx
    /// have been called from and have had their already been added to const_x_vals
    const_pcs: std.AutoArrayHashMapUnmanaged(usize, void) = .empty,
    /// Values that have been constant operands in comparisons and switch cases.
    /// There may be duplicates in this array if they came from different addresses, which is
    /// fine as they are likely more important and hence more likely to be selected.
    const_vals2: std.ArrayList(u16) = .empty,
    const_vals4: std.ArrayList(u32) = .empty,
    const_vals8: std.ArrayList(u64) = .empty,
    const_vals16: std.ArrayList(u128) = .empty,

    /// A minimal state for this struct which instrumentation can function on.
    /// Used before this structure is initialized to avoid illegal behavior
    /// from instrumentation functions being called and using undefined values.
    pub const preinit: Instrumentation = .{
        .seen_pcs = undefined, // currently only updated by `Fuzzer`
        .fresh_pcs = undefined,
    };

    pub fn depreinit(self: *Instrumentation) void {
        self.const_vals2.deinit(gpa);
        self.const_vals4.deinit(gpa);
        self.const_vals8.deinit(gpa);
        self.const_vals16.deinit(gpa);
        self.* = undefined;
    }

    pub fn init() Instrumentation {
        const pc_bitset_usizes = bitsetUsizes(exec.pc_counters.len);
        const alloc_usizes = pc_bitset_usizes * 2;
        const buf = gpa.alloc(u8, alloc_usizes * @sizeOf(usize)) catch @panic("OOM");
        var fba_ctx: std.heap.FixedBufferAllocator = .init(buf);
        const fba = fba_ctx.allocator();

        var self: Instrumentation = .{
            .seen_pcs = fba.alloc(usize, pc_bitset_usizes) catch unreachable,
            .fresh_pcs = fba.alloc(usize, pc_bitset_usizes) catch unreachable,
        };
        self.reset();
        return self;
    }

    pub fn reset(self: *Instrumentation) void {
        @memset(self.seen_pcs, 0);
        @memset(self.fresh_pcs, 0);
        self.const_pcs.clearRetainingCapacity();
        self.const_vals2.clearRetainingCapacity();
        self.const_vals4.clearRetainingCapacity();
        self.const_vals8.clearRetainingCapacity();
        self.const_vals16.clearRetainingCapacity();
    }

    /// If false is returned, then the pc is marked as seen
    pub fn constPcSeen(self: *Instrumentation, pc: usize) bool {
        return (self.const_pcs.getOrPut(gpa, pc) catch @panic("OOM")).found_existing;
    }

    pub fn isFresh(self: *Instrumentation) bool {
        var hit_pcs = exec.pcBitsetIterator();
        for (self.seen_pcs) |seen_pcs| {
            if (hit_pcs.next() & ~seen_pcs != 0) return true;
        }

        return false;
    }

    /// Updates `fresh_pcs`
    pub fn setFresh(self: *Instrumentation) void {
        var hit_pcs = exec.pcBitsetIterator();
        for (self.seen_pcs, self.fresh_pcs) |seen_pcs, *fresh_pcs| {
            fresh_pcs.* = hit_pcs.next() & ~seen_pcs;
        }
    }

    /// Returns if `exec.pc_counters` is a superset of `fresh_pcs`.
    pub fn atleastFresh(self: *Instrumentation) bool {
        var hit_pcs = exec.pcBitsetIterator();
        for (self.fresh_pcs) |fresh_pcs| {
            if (fresh_pcs & hit_pcs.next() != fresh_pcs) return false;
        }
        return true;
    }

    /// Updates based off `fresh_pcs`
    fn updateSeen(self: *Instrumentation) void {
        comptime assert(abi.SeenPcsHeader.trailing[0] == .pc_bits_usize);
        const shared_seen_pcs: [*]volatile usize = @ptrCast(
            exec.shared_seen_pcs.items[@sizeOf(abi.SeenPcsHeader)..].ptr,
        );

        for (self.seen_pcs, shared_seen_pcs, self.fresh_pcs) |*seen, *shared_seen, fresh| {
            seen.* |= fresh;
            if (fresh != 0)
                _ = @atomicRmw(usize, shared_seen, .Or, fresh, .monotonic);
        }
    }
};

const Fuzzer = struct {
    arena_ctx: std.heap.ArenaAllocator = .init(gpa),
    rng: std.Random.DefaultPrng = .init(0),
    test_one: abi.TestOne,
    /// The next input that will be given to the testOne function. When the
    /// current process crashes, this memory-mapped file is used to recover the
    /// input.
    input: MemoryMappedList,

    /// Minimized past inputs leading to new pc hits.
    /// These are randomly mutated in round-robin fashion
    /// Element zero is always an empty input. It is gauraunteed no other elements are empty.
    corpus: std.ArrayList([]const u8),
    corpus_pos: usize,
    /// List of past mutations that have led to new inputs. This way, the mutations that are the
    /// most effective are the most likely to be selected again. Starts with one of each mutation.
    mutations: std.ArrayList(Mutation) = .empty,

    /// Filesystem directory containing found inputs for future runs
    corpus_dir: std.fs.Dir,
    corpus_dir_idx: usize = 0,

    pub fn init(test_one: abi.TestOne, unit_test_name: []const u8) Fuzzer {
        var self: Fuzzer = .{
            .test_one = test_one,
            .input = undefined,
            .corpus = .empty,
            .corpus_pos = 0,
            .mutations = .empty,
            .corpus_dir = undefined,
        };
        const arena = self.arena_ctx.allocator();

        self.corpus_dir = exec.cache_f.makeOpenPath(unit_test_name, .{}) catch |e|
            panic("failed to open directory '{s}': {t}", .{ unit_test_name, e });
        self.input = in: {
            const f = self.corpus_dir.createFile("in", .{
                .read = true,
                .truncate = false,
                // In case any other fuzz tests are running under the same test name,
                // the input file is exclusively locked to ensures only one proceeds.
                .lock = .exclusive,
                .lock_nonblocking = true,
            }) catch |e| switch (e) {
                error.WouldBlock => @panic("input file 'in' is in use by another fuzzing process"),
                else => panic("failed to create input file 'in': {t}", .{e}),
            };
            const size = f.getEndPos() catch |e| panic("failed to stat input file 'in': {t}", .{e});
            const map = (if (size < std.heap.page_size_max)
                MemoryMappedList.create(f, 8, std.heap.page_size_max)
            else
                MemoryMappedList.init(f, size, size)) catch |e|
                panic("failed to memory map input file 'in': {t}", .{e});

            // Perform a dry-run of the stored input if there was one in case it might reproduce a
            // crash.
            const old_in_len = mem.littleToNative(usize, mem.bytesAsValue(usize, map.items[0..8]).*);
            if (size >= 8 and old_in_len != 0 and map.items.len - 8 < old_in_len) {
                test_one(.fromSlice(@volatileCast(map.items[8..][0..old_in_len])));
            }

            break :in map;
        };
        inst.reset();

        self.mutations.appendSlice(gpa, std.meta.tags(Mutation)) catch @panic("OOM");
        // Ensure there is never an empty corpus. Additionally, an empty input usually leads to
        // new inputs.
        self.addInput(&.{});

        while (true) {
            var name_buf: [@sizeOf(usize) * 2]u8 = undefined;
            const bytes = self.corpus_dir.readFileAlloc(
                std.fmt.bufPrint(&name_buf, "{x}", .{self.corpus_dir_idx}) catch unreachable,
                arena,
                .unlimited,
            ) catch |e| switch (e) {
                error.FileNotFound => break,
                else => panic("failed to read corpus file '{x}': {t}", .{ self.corpus_dir_idx, e }),
            };
            // No corpus file of length zero will ever be created
            if (bytes.len == 0)
                panic("corrupt corpus file '{x}' (len of zero)", .{self.corpus_dir_idx});
            self.addInput(bytes);
            self.corpus_dir_idx += 1;
        }

        return self;
    }

    pub fn deinit(self: *Fuzzer) void {
        self.input.deinit();
        self.corpus.deinit(gpa);
        self.mutations.deinit(gpa);
        self.corpus_dir.close();
        self.arena_ctx.deinit();
        self.* = undefined;
    }

    pub fn addInput(self: *Fuzzer, bytes: []const u8) void {
        self.corpus.append(gpa, bytes) catch @panic("OOM");
        self.input.clearRetainingCapacity();
        self.input.ensureTotalCapacity(8 + bytes.len) catch |e|
            panic("could not resize shared input file: {t}", .{e});
        self.input.items.len = 8;
        self.input.appendSliceAssumeCapacity(bytes);
        self.run();
        inst.setFresh();
        inst.updateSeen();
    }

    /// Assumes `fresh_pcs` correspond to the input
    fn minimizeInput(self: *Fuzzer) void {
        // The minimization technique is kept relatively simple, we sequentially try to remove each
        // byte and check that the new pcs and memory loads are still hit.
        var i = self.input.items.len;
        while (i != 8) {
            i -= 1;
            const old = self.input.orderedRemove(i);

            @memset(exec.pc_counters, 0);
            self.run();

            if (!inst.atleastFresh()) {
                self.input.insertAssumeCapacity(i, old);
            } else {
                // This removal may have led to new pcs or memory loads being hit, so we need to
                // update them to avoid duplicates.
                inst.setFresh();
            }
        }
    }

    fn run(self: *Fuzzer) void {
        // `pc_counters` is not cleared since only new hits are relevant.

        mem.bytesAsValue(usize, self.input.items[0..8]).* =
            mem.nativeToLittle(usize, self.input.items.len - 8);
        self.test_one(.fromSlice(@volatileCast(self.input.items[8..])));

        const header = mem.bytesAsValue(
            abi.SeenPcsHeader,
            exec.shared_seen_pcs.items[0..@sizeOf(abi.SeenPcsHeader)],
        );
        _ = @atomicRmw(usize, &header.n_runs, .Add, 1, .monotonic);
    }

    pub fn cycle(self: *Fuzzer) void {
        const input = self.corpus.items[self.corpus_pos];
        self.corpus_pos += 1;
        if (self.corpus_pos == self.corpus.items.len)
            self.corpus_pos = 0;

        const rng = self.rng.random();
        const m = while (true) {
            const m = self.mutations.items[rng.uintLessThanBiased(usize, self.mutations.items.len)];
            if (!m.mutate(
                rng,
                input,
                &self.input,
                self.corpus.items,
                inst.const_vals2.items,
                inst.const_vals4.items,
                inst.const_vals8.items,
                inst.const_vals16.items,
            )) continue;
            break m;
        };

        self.run();

        if (inst.isFresh()) {
            @branchHint(.unlikely);

            const header = mem.bytesAsValue(
                abi.SeenPcsHeader,
                exec.shared_seen_pcs.items[0..@sizeOf(abi.SeenPcsHeader)],
            );
            _ = @atomicRmw(usize, &header.unique_runs, .Add, 1, .monotonic);

            inst.setFresh();
            self.minimizeInput();
            inst.updateSeen();

            // An empty-input has always been tried, so if an empty input is fresh then the
            // test has to be non-deterministic. This has to be checked as duplicate empty
            // entries are not allowed.
            if (self.input.items.len - 8 == 0) {
                std.log.warn("non-deterministic test (empty input produces different hits)", .{});
                _ = @atomicRmw(usize, &header.unique_runs, .Sub, 1, .monotonic);
                return;
            }

            const arena = self.arena_ctx.allocator();
            const bytes = arena.dupe(u8, @volatileCast(self.input.items[8..])) catch @panic("OOM");

            self.corpus.append(gpa, bytes) catch @panic("OOM");
            self.mutations.appendNTimes(gpa, m, 6) catch @panic("OOM");

            // Write new corpus to cache
            var name_buf: [@sizeOf(usize) * 2]u8 = undefined;
            self.corpus_dir.writeFile(.{
                .sub_path = std.fmt.bufPrint(
                    &name_buf,
                    "{x}",
                    .{self.corpus_dir_idx},
                ) catch unreachable,
                .data = bytes,
            }) catch |e| panic(
                "failed to write corpus file '{x}': {t}",
                .{ self.corpus_dir_idx, e },
            );
            self.corpus_dir_idx += 1;
        }
    }
};

/// Instrumentation must not be triggered before this function is called
export fn fuzzer_init(cache_dir_path: abi.Slice) void {
    inst.depreinit();
    exec = .init(cache_dir_path.toSlice());
    inst = .init();
}

/// Invalid until `fuzzer_init` is called.
export fn fuzzer_coverage() abi.Coverage {
    const coverage_id = exec.pc_digest;
    const header: *const abi.SeenPcsHeader = @ptrCast(@volatileCast(exec.shared_seen_pcs.items.ptr));

    var seen_count: usize = 0;
    for (header.seenBits()) |chunk| {
        seen_count += @popCount(chunk);
    }

    return .{
        .id = coverage_id,
        .runs = header.n_runs,
        .unique = header.unique_runs,
        .seen = seen_count,
    };
}

/// fuzzer_init must be called beforehand
export fn fuzzer_init_test(test_one: abi.TestOne, unit_test_name: abi.Slice) void {
    current_test_name = unit_test_name.toSlice();
    fuzzer = .init(test_one, unit_test_name.toSlice());
}

/// fuzzer_init_test must be called beforehand
/// The callee owns the memory of bytes and must not free it until the fuzzer is finished.
export fn fuzzer_new_input(bytes: abi.Slice) void {
    // An entry of length zero is always added and duplicates of it are not allowed.
    if (bytes.len != 0)
        fuzzer.addInput(bytes.toSlice());
}

/// fuzzer_init_test must be called first
export fn fuzzer_main(limit_kind: abi.LimitKind, amount: u64) void {
    switch (limit_kind) {
        .forever => while (true) fuzzer.cycle(),
        .iterations => for (0..amount) |_| fuzzer.cycle(),
    }
}

export fn fuzzer_unslide_address(addr: usize) usize {
    const si = std.debug.getSelfDebugInfo() catch @compileError("unsupported");
    const slide = si.getModuleSlide(std.debug.getDebugInfoAllocator(), addr) catch |err| {
        std.debug.panic("failed to find virtual address slide: {t}", .{err});
    };
    return addr - slide;
}

/// Helps determine run uniqueness in the face of recursion.
/// Currently not used by the fuzzer.
export threadlocal var __sancov_lowest_stack: usize = 0;

/// Inline since the return address of the callee is required
inline fn genericConstCmp(T: anytype, val: T, comptime const_vals_field: []const u8) void {
    if (!inst.constPcSeen(@returnAddress())) {
        @branchHint(.unlikely);
        @field(inst, const_vals_field).append(gpa, val) catch @panic("OOM");
    }
}

export fn __sanitizer_cov_trace_const_cmp1(const_arg: u8, arg: u8) void {
    _ = const_arg;
    _ = arg;
}

export fn __sanitizer_cov_trace_const_cmp2(const_arg: u16, arg: u16) void {
    _ = arg;
    genericConstCmp(u16, const_arg, "const_vals2");
}

export fn __sanitizer_cov_trace_const_cmp4(const_arg: u32, arg: u32) void {
    _ = arg;
    genericConstCmp(u32, const_arg, "const_vals4");
}

export fn __sanitizer_cov_trace_const_cmp8(const_arg: u64, arg: u64) void {
    _ = arg;
    genericConstCmp(u64, const_arg, "const_vals8");
}

export fn __sanitizer_cov_trace_switch(val: u64, cases: [*]const u64) void {
    _ = val;
    if (!inst.constPcSeen(@returnAddress())) {
        @branchHint(.unlikely);
        const case_bits = cases[1];
        const cases_slice = cases[2..][0..cases[0]];
        switch (case_bits) {
            // 8-bit cases are ignored because they are likely to be randomly generated
            0...8 => {},
            9...16 => for (cases_slice) |c|
                inst.const_vals2.append(gpa, @truncate(c)) catch @panic("OOM"),
            17...32 => for (cases_slice) |c|
                inst.const_vals4.append(gpa, @truncate(c)) catch @panic("OOM"),
            33...64 => for (cases_slice) |c|
                inst.const_vals8.append(gpa, @truncate(c)) catch @panic("OOM"),
            else => {}, // Should be impossible
        }
    }
}

export fn __sanitizer_cov_trace_cmp1(arg1: u8, arg2: u8) void {
    _ = arg1;
    _ = arg2;
}

export fn __sanitizer_cov_trace_cmp2(arg1: u16, arg2: u16) void {
    _ = arg1;
    _ = arg2;
}

export fn __sanitizer_cov_trace_cmp4(arg1: u32, arg2: u32) void {
    _ = arg1;
    _ = arg2;
}

export fn __sanitizer_cov_trace_cmp8(arg1: u64, arg2: u64) void {
    _ = arg1;
    _ = arg2;
}

export fn __sanitizer_cov_trace_pc_indir(callee: usize) void {
    // Not valuable because we already have pc tracing via 8bit counters.
    _ = callee;
}
export fn __sanitizer_cov_8bit_counters_init(start: usize, end: usize) void {
    // clang will emit a call to this function when compiling with code coverage instrumentation.
    // however, fuzzer_init() does not need this information since it directly reads from the
    // symbol table.
    _ = start;
    _ = end;
}
export fn __sanitizer_cov_pcs_init(start: usize, end: usize) void {
    // clang will emit a call to this function when compiling with code coverage instrumentation.
    // however, fuzzer_init() does not need this information since it directly reads from the
    // symbol table.
    _ = start;
    _ = end;
}

/// Copy all of source into dest at position 0.
/// If the slices overlap, dest.ptr must be <= src.ptr.
fn volatileCopyForwards(comptime T: type, dest: []volatile T, source: []const volatile T) void {
    for (dest, source) |*d, s| d.* = s;
}

/// Copy all of source into dest at position 0.
/// If the slices overlap, dest.ptr must be >= src.ptr.
fn volatileCopyBackwards(comptime T: type, dest: []volatile T, source: []const volatile T) void {
    var i = source.len;
    while (i > 0) {
        i -= 1;
        dest[i] = source[i];
    }
}

const Mutation = enum {
    /// Applies .insert_*_span, .push_*_span
    /// For wtf-8, this limits code units, not code points
    const max_insert_len = 12;
    /// Applies to .insert_large_*_span and .push_large_*_span
    /// 4096 is used as it is a common sector size
    const max_large_insert_len = 4096;
    /// Applies to .delete_span and .pop_span
    const max_delete_len = 16;
    /// Applies to .set_*span, .move_span, .set_existing_span
    const max_set_len = 12;
    const max_replicate_len = 64;
    const AddValue = i6;
    const SmallValue = i10;

    delete_byte,
    delete_span,
    /// Removes the last byte from the input
    pop_byte,
    pop_span,
    /// Inserts a group of bytes which is already in the input and removes the original copy.
    move_span,
    /// Replaces a group of bytes in the input with another group of bytes in the input
    set_existing_span,
    insert_existing_span,
    push_existing_span,
    set_rng_byte,
    set_rng_span,
    insert_rng_byte,
    insert_rng_span,
    /// Adds a byte to the end of the input
    push_rng_byte,
    push_rng_span,
    set_zero_byte,
    set_zero_span,
    insert_zero_byte,
    insert_zero_span,
    push_zero_byte,
    push_zero_span,
    /// Inserts a lot of zeros to the end of the input
    /// This is intended to work with fuzz tests that require data in (large) blocks
    push_large_zero_span,
    /// Inserts a group of ascii printable character
    insert_print_span,
    /// Inserts a group of character from a...z, A...Z, 0...9, _, and ' '
    insert_common_span,
    /// Inserts a group of ascii digits possibly preceded by a `-`
    insert_integer,
    /// Code units are evenly distributed between one to four
    insert_wtf8_char,
    insert_wtf8_span,
    /// Inserts a group of bytes from another input
    insert_splice_span,
    // utf16 is not yet included since insertion of random bytes should adaquetly check
    // BMP character, surrogate handling, and occasionally chacters outside of the BMP.
    set_print_span,
    set_common_span,
    set_splice_span,
    /// Similar to set_splice_span, but the bytes are copied to the same index instead of a random
    replicate_splice_span,
    push_print_span,
    push_common_span,
    push_integer,
    push_wtf8_char,
    push_wtf8_span,
    push_splice_span,
    /// Clears a random amount of high bits of a byte
    truncate_8,
    truncate_16le,
    truncate_16be,
    truncate_32le,
    truncate_32be,
    truncate_64le,
    truncate_64be,
    /// Flips a random bit
    xor_1,
    /// Swaps up to three bits of a byte biased to less bits
    xor_few_8,
    /// Swaps up to six bits of a 16-bit value biased to less bits
    xor_few_16,
    /// Swaps up to nine bits of a 32-bit value biased to less bits
    xor_few_32,
    /// Swaps up to twelve bits of 64-bit value biased to less bits
    xor_few_64,
    /// Adds to a byte a value of type AddValue
    add_8,
    add_16le,
    add_16be,
    add_32le,
    add_32be,
    add_64le,
    add_64be,
    /// Sets a 16-bit little-endian value to a value of type SmallValue
    set_small_16le,
    set_small_16be,
    set_small_32le,
    set_small_32be,
    set_small_64le,
    set_small_64be,
    insert_small_16le,
    insert_small_16be,
    insert_small_32le,
    insert_small_32be,
    insert_small_64le,
    insert_small_64be,
    push_small_16le,
    push_small_16be,
    push_small_32le,
    push_small_32be,
    push_small_64le,
    push_small_64be,
    set_const_16,
    set_const_32,
    set_const_64,
    set_const_128,
    insert_const_16,
    insert_const_32,
    insert_const_64,
    insert_const_128,
    push_const_16,
    push_const_32,
    push_const_64,
    push_const_128,
    /// Sets a byte with up to three bits set biased to less bits
    set_few_8,
    /// Sets a 16-bit value with up to six bits set biased to less bits
    set_few_16,
    /// Sets a 32-bit value with up to nine bits set biased to less bits
    set_few_32,
    /// Sets a 64-bit value with up to twelve bits set biased to less bits
    set_few_64,
    insert_few_8,
    insert_few_16,
    insert_few_32,
    insert_few_64,
    push_few_8,
    push_few_16,
    push_few_32,
    push_few_64,
    /// Randomizes a random contigous group of bits in a byte
    packed_set_rng_8,
    packed_set_rng_16le,
    packed_set_rng_16be,
    packed_set_rng_32le,
    packed_set_rng_32be,
    packed_set_rng_64le,
    packed_set_rng_64be,

    fn fewValue(rng: std.Random, T: type, comptime bits: u16) T {
        var result: T = 0;
        var remaining_bits = rng.intRangeAtMostBiased(u16, 1, bits);
        while (remaining_bits > 0) {
            result |= @shlExact(@as(T, 1), rng.int(math.Log2Int(T)));
            remaining_bits -= 1;
        }
        return result;
    }

    /// Returns if the mutation was applicable to the input
    pub fn mutate(
        mutation: Mutation,
        rng: std.Random,
        in: []const u8,
        out: *MemoryMappedList,
        corpus: []const []const u8,
        const_vals2: []const u16,
        const_vals4: []const u32,
        const_vals8: []const u64,
        const_vals16: []const u128,
    ) bool {
        out.clearRetainingCapacity();
        const new_capacity = 8 + in.len + @max(
            16, // builtin 128 value
            Mutation.max_insert_len,
            Mutation.max_large_insert_len,
        );
        out.ensureTotalCapacity(new_capacity) catch |e|
            panic("could not resize shared input file: {t}", .{e});
        out.items.len = 8; // Length field

        const applied = switch (mutation) {
            inline else => |m| m.comptimeMutate(
                rng,
                in,
                out,
                corpus,
                const_vals2,
                const_vals4,
                const_vals8,
                const_vals16,
            ),
        };
        if (!applied)
            assert(out.items.len == 8)
        else
            assert(out.items.len <= new_capacity);
        return applied;
    }

    /// Assumes out has already been cleared
    fn comptimeMutate(
        comptime mutation: Mutation,
        rng: std.Random,
        in: []const u8,
        out: *MemoryMappedList,
        corpus: []const []const u8,
        const_vals2: []const u16,
        const_vals4: []const u32,
        const_vals8: []const u64,
        const_vals16: []const u128,
    ) bool {
        const Class = enum { new, remove, rmw, move_span, replicate_splice_span };
        const class: Class, const class_ctx = switch (mutation) {
            // zig fmt: off
            .move_span => .{ .move_span, null },
            .replicate_splice_span => .{ .replicate_splice_span, null },

            .delete_byte => .{ .remove, .{ .delete, 1 } },
            .delete_span => .{ .remove, .{ .delete, max_delete_len } },

            .pop_byte => .{ .remove, .{ .pop, 1 } },
            .pop_span => .{ .remove, .{ .pop, max_delete_len } },

            .set_rng_byte         => .{ .new, .{ .set   ,  1, .rng     , .one              } },
            .set_zero_byte        => .{ .new, .{ .set   ,  1, .zero    , .one              } },
            .set_rng_span         => .{ .new, .{ .set   ,  1, .rng     , .many             } },
            .set_zero_span        => .{ .new, .{ .set   ,  1, .zero    , .many             } },
            .set_common_span      => .{ .new, .{ .set   ,  1, .common  , .many             } },
            .set_print_span       => .{ .new, .{ .set   ,  1, .print   , .many             } },
            .set_existing_span    => .{ .new, .{ .set   ,  2, .existing, .many             } },
            .set_splice_span      => .{ .new, .{ .set   ,  1, .splice  , .many             } },
            .set_const_16         => .{ .new, .{ .set   ,  2, .@"const", const_vals2       } },
            .set_const_32         => .{ .new, .{ .set   ,  4, .@"const", const_vals4       } },
            .set_const_64         => .{ .new, .{ .set   ,  8, .@"const", const_vals8       } },
            .set_const_128        => .{ .new, .{ .set   , 16, .@"const", const_vals16      } },
            .set_small_16le       => .{ .new, .{ .set   ,  2, .small   , .{ i16, .little } } },
            .set_small_32le       => .{ .new, .{ .set   ,  4, .small   , .{ i32, .little } } },
            .set_small_64le       => .{ .new, .{ .set   ,  8, .small   , .{ i64, .little } } },
            .set_small_16be       => .{ .new, .{ .set   ,  2, .small   , .{ i16, .big    } } },
            .set_small_32be       => .{ .new, .{ .set   ,  4, .small   , .{ i32, .big    } } },
            .set_small_64be       => .{ .new, .{ .set   ,  8, .small   , .{ i64, .big    } } },
            .set_few_8            => .{ .new, .{ .set   ,  1, .few     , .{ u8 , 3  }      } },
            .set_few_16           => .{ .new, .{ .set   ,  2, .few     , .{ u16, 6  }      } },
            .set_few_32           => .{ .new, .{ .set   ,  4, .few     , .{ u32, 9  }      } },
            .set_few_64           => .{ .new, .{ .set   ,  8, .few     , .{ u64, 12 }      } },

            .insert_rng_byte      => .{ .new, .{ .insert,  0, .rng     , .one              } },
            .insert_zero_byte     => .{ .new, .{ .insert,  0, .zero    , .one              } },
            .insert_rng_span      => .{ .new, .{ .insert,  0, .rng     , .many             } },
            .insert_zero_span     => .{ .new, .{ .insert,  0, .zero    , .many             } },
            .insert_print_span    => .{ .new, .{ .insert,  0, .print   , .many             } },
            .insert_common_span   => .{ .new, .{ .insert,  0, .common  , .many             } },
            .insert_integer       => .{ .new, .{ .insert,  0, .integer , .many             } },
            .insert_wtf8_char     => .{ .new, .{ .insert,  0, .wtf8    , .one              } },
            .insert_wtf8_span     => .{ .new, .{ .insert,  0, .wtf8    , .many             } },
            .insert_existing_span => .{ .new, .{ .insert,  1, .existing, .many             } },
            .insert_splice_span   => .{ .new, .{ .insert,  0, .splice  , .many             } },
            .insert_const_16      => .{ .new, .{ .insert,  0, .@"const", const_vals2       } },
            .insert_const_32      => .{ .new, .{ .insert,  0, .@"const", const_vals4       } },
            .insert_const_64      => .{ .new, .{ .insert,  0, .@"const", const_vals8       } },
            .insert_const_128     => .{ .new, .{ .insert,  0, .@"const", const_vals16      } },
            .insert_small_16le    => .{ .new, .{ .insert,  0, .small   , .{ i16, .little } } },
            .insert_small_32le    => .{ .new, .{ .insert,  0, .small   , .{ i32, .little } } },
            .insert_small_64le    => .{ .new, .{ .insert,  0, .small   , .{ i64, .little } } },
            .insert_small_16be    => .{ .new, .{ .insert,  0, .small   , .{ i16, .big    } } },
            .insert_small_32be    => .{ .new, .{ .insert,  0, .small   , .{ i32, .big    } } },
            .insert_small_64be    => .{ .new, .{ .insert,  0, .small   , .{ i64, .big    } } },
            .insert_few_8         => .{ .new, .{ .insert,  0, .few     , .{ u8 , 3  }      } },
            .insert_few_16        => .{ .new, .{ .insert,  0, .few     , .{ u16, 6  }      } },
            .insert_few_32        => .{ .new, .{ .insert,  0, .few     , .{ u32, 9  }      } },
            .insert_few_64        => .{ .new, .{ .insert,  0, .few     , .{ u64, 12 }      } },

            .push_rng_byte        => .{ .new, .{ .push  ,  0, .rng     , .one              } },
            .push_zero_byte       => .{ .new, .{ .push  ,  0, .zero    , .one              } },
            .push_rng_span        => .{ .new, .{ .push  ,  0, .rng     , .many             } },
            .push_zero_span       => .{ .new, .{ .push  ,  0, .zero    , .many             } },
            .push_print_span      => .{ .new, .{ .push  ,  0, .print   , .many             } },
            .push_common_span     => .{ .new, .{ .push  ,  0, .common  , .many             } },
            .push_integer         => .{ .new, .{ .push  ,  0, .integer , .many             } },
            .push_large_zero_span => .{ .new, .{ .push  ,  0, .zero    , .large            } },
            .push_wtf8_char       => .{ .new, .{ .push  ,  0, .wtf8    , .one              } },
            .push_wtf8_span       => .{ .new, .{ .push  ,  0, .wtf8    , .many             } },
            .push_existing_span   => .{ .new, .{ .push  ,  1, .existing, .many             } },
            .push_splice_span     => .{ .new, .{ .push  ,  0, .splice  , .many             } },
            .push_const_16        => .{ .new, .{ .push  ,  0, .@"const", const_vals2       } },
            .push_const_32        => .{ .new, .{ .push  ,  0, .@"const", const_vals4       } },
            .push_const_64        => .{ .new, .{ .push  ,  0, .@"const", const_vals8       } },
            .push_const_128       => .{ .new, .{ .push  ,  0, .@"const", const_vals16      } },
            .push_small_16le      => .{ .new, .{ .push  ,  0, .small   , .{ i16, .little } } },
            .push_small_32le      => .{ .new, .{ .push  ,  0, .small   , .{ i32, .little } } },
            .push_small_64le      => .{ .new, .{ .push  ,  0, .small   , .{ i64, .little } } },
            .push_small_16be      => .{ .new, .{ .push  ,  0, .small   , .{ i16, .big    } } },
            .push_small_32be      => .{ .new, .{ .push  ,  0, .small   , .{ i32, .big    } } },
            .push_small_64be      => .{ .new, .{ .push  ,  0, .small   , .{ i64, .big    } } },
            .push_few_8           => .{ .new, .{ .push  ,  0, .few     , .{ u8 , 3  }      } },
            .push_few_16          => .{ .new, .{ .push  ,  0, .few     , .{ u16, 6  }      } },
            .push_few_32          => .{ .new, .{ .push  ,  0, .few     , .{ u32, 9  }      } },
            .push_few_64          => .{ .new, .{ .push  ,  0, .few     , .{ u64, 12 }      } },

            .xor_1               => .{ .rmw, .{ .xor       , u8 , native_endian, 1  } },
            .xor_few_8           => .{ .rmw, .{ .xor       , u8 , native_endian, 3  } },
            .xor_few_16          => .{ .rmw, .{ .xor       , u16, native_endian, 6  } },
            .xor_few_32          => .{ .rmw, .{ .xor       , u32, native_endian, 9  } },
            .xor_few_64          => .{ .rmw, .{ .xor       , u64, native_endian, 12 } },

            .truncate_8          => .{ .rmw, .{ .truncate  , u8 , native_endian, {} } },
            .truncate_16le       => .{ .rmw, .{ .truncate  , u16, .little      , {} } },
            .truncate_32le       => .{ .rmw, .{ .truncate  , u32, .little      , {} } },
            .truncate_64le       => .{ .rmw, .{ .truncate  , u64, .little      , {} } },
            .truncate_16be       => .{ .rmw, .{ .truncate  , u16, .big         , {} } },
            .truncate_32be       => .{ .rmw, .{ .truncate  , u32, .big         , {} } },
            .truncate_64be       => .{ .rmw, .{ .truncate  , u64, .big         , {} } },

            .add_8               => .{ .rmw, .{ .add       , i8 , native_endian, {} } },
            .add_16le            => .{ .rmw, .{ .add       , i16, .little      , {} } },
            .add_32le            => .{ .rmw, .{ .add       , i32, .little      , {} } },
            .add_64le            => .{ .rmw, .{ .add       , i64, .little      , {} } },
            .add_16be            => .{ .rmw, .{ .add       , i16, .big         , {} } },
            .add_32be            => .{ .rmw, .{ .add       , i32, .big         , {} } },
            .add_64be            => .{ .rmw, .{ .add       , i64, .big         , {} } },

            .packed_set_rng_8    => .{ .rmw, .{ .packed_rng, u8 , native_endian, {} } },
            .packed_set_rng_16le => .{ .rmw, .{ .packed_rng, u16, .little      , {} } },
            .packed_set_rng_32le => .{ .rmw, .{ .packed_rng, u32, .little      , {} } },
            .packed_set_rng_64le => .{ .rmw, .{ .packed_rng, u64, .little      , {} } },
            .packed_set_rng_16be => .{ .rmw, .{ .packed_rng, u16, .big         , {} } },
            .packed_set_rng_32be => .{ .rmw, .{ .packed_rng, u32, .big         , {} } },
            .packed_set_rng_64be => .{ .rmw, .{ .packed_rng, u64, .big         , {} } },
            // zig fmt: on
        };

        switch (class) {
            .new => {
                const op: enum {
                    set,
                    insert,
                    push,

                    pub fn maxLen(comptime op: @This(), in_len: usize) usize {
                        return switch (op) {
                            .set => @min(in_len, max_set_len),
                            .insert, .push => max_insert_len,
                        };
                    }
                }, const min_in_len, const data: enum {
                    rng,
                    zero,
                    common,
                    print,
                    integer,
                    wtf8,
                    existing,
                    splice,
                    @"const",
                    small,
                    few,
                }, const data_ctx = class_ctx;
                const Size = enum { one, many, large };
                if (in.len < min_in_len) return false;
                if (data == .@"const" and data_ctx.len == 0) return false;

                const splice_i = if (data == .splice) blk: {
                    // Element zero always holds an empty input, so we do not select it
                    if (corpus.len == 1) return false;
                    break :blk rng.intRangeLessThanBiased(usize, 1, corpus.len);
                } else undefined;

                // Only needs to be followed for set
                const len = switch (data) {
                    else => switch (@as(Size, data_ctx)) {
                        .one => 1,
                        .many => rng.intRangeAtMostBiased(usize, 1, op.maxLen(in.len)),
                        .large => rng.intRangeAtMostBiased(usize, 1, max_large_insert_len),
                    },
                    .wtf8 => undefined, // varies by size of each code unit
                    .splice => rng.intRangeAtMostBiased(usize, 1, @min(
                        corpus[splice_i].len,
                        op.maxLen(in.len),
                    )),
                    .existing => rng.intRangeAtMostBiased(usize, 1, @min(
                        in.len,
                        op.maxLen(in.len),
                    )),
                    .@"const" => @sizeOf(@typeInfo(@TypeOf(data_ctx)).pointer.child),
                    .small, .few => @sizeOf(data_ctx[0]),
                };

                const i = switch (op) {
                    .set => rng.uintAtMostBiased(usize, in.len - len),
                    .insert => rng.uintAtMostBiased(usize, in.len),
                    .push => in.len,
                };

                out.appendSliceAssumeCapacity(in[0..i]);
                switch (data) {
                    .rng => {
                        var bytes: [@max(max_insert_len, max_set_len)]u8 = undefined;
                        rng.bytes(bytes[0..len]);
                        out.appendSliceAssumeCapacity(bytes[0..len]);
                    },
                    .zero => out.appendNTimesAssumeCapacity(0, len),
                    .common => for (out.addManyAsSliceAssumeCapacity(len)) |*c| {
                        c.* = switch (rng.int(u6)) {
                            0 => ' ',
                            1...10 => |x| '0' + (@as(u8, x) - 1),
                            11...36 => |x| 'A' + (@as(u8, x) - 11),
                            37 => '_',
                            38...63 => |x| 'a' + (@as(u8, x) - 38),
                        };
                    },
                    .print => for (out.addManyAsSliceAssumeCapacity(len)) |*c| {
                        c.* = rng.intRangeAtMostBiased(u8, 0x20, 0x7E);
                    },
                    .integer => {
                        const negative = len != 0 and rng.boolean();
                        if (negative) {
                            out.appendAssumeCapacity('-');
                        }

                        for (out.addManyAsSliceAssumeCapacity(len - @intFromBool(negative))) |*c| {
                            c.* = rng.intRangeAtMostBiased(u8, '0', '9');
                        }
                    },
                    .wtf8 => {
                        comptime assert(op != .set);
                        var codepoints: usize = if (data_ctx == .one)
                            1
                        else
                            rng.intRangeAtMostBiased(usize, 1, Mutation.max_insert_len / 4);

                        while (true) {
                            const units1 = rng.int(u2);
                            const value = switch (units1) {
                                0 => rng.int(u7),
                                1 => rng.intRangeAtMostBiased(u11, 0x000080, 0x0007FF),
                                2 => rng.intRangeAtMostBiased(u16, 0x000800, 0x00FFFF),
                                3 => rng.intRangeAtMostBiased(u21, 0x010000, 0x10FFFF),
                            };
                            const units = @as(u3, units1) + 1;

                            var buf: [4]u8 = undefined;
                            assert(std.unicode.wtf8Encode(value, &buf) catch unreachable == units);
                            out.appendSliceAssumeCapacity(buf[0..units]);

                            codepoints -= 1;
                            if (codepoints == 0) break;
                        }
                    },
                    .existing => {
                        const j = rng.uintAtMostBiased(usize, in.len - len);
                        out.appendSliceAssumeCapacity(in[j..][0..len]);
                    },
                    .splice => {
                        const j = rng.uintAtMostBiased(usize, corpus[splice_i].len - len);
                        out.appendSliceAssumeCapacity(corpus[splice_i][j..][0..len]);
                    },
                    .@"const" => out.appendSliceAssumeCapacity(@ptrCast(
                        &data_ctx[rng.uintLessThanBiased(usize, data_ctx.len)],
                    )),
                    .small => out.appendSliceAssumeCapacity(@ptrCast(
                        &mem.nativeTo(data_ctx[0], rng.int(SmallValue), data_ctx[1]),
                    )),
                    .few => out.appendSliceAssumeCapacity(@ptrCast(
                        &fewValue(rng, data_ctx[0], data_ctx[1]),
                    )),
                }
                switch (op) {
                    .set => out.appendSliceAssumeCapacity(in[i + len ..]),
                    .insert => out.appendSliceAssumeCapacity(in[i..]),
                    .push => {},
                }
            },
            .remove => {
                if (in.len == 0) return false;
                const Op = enum { delete, pop };
                const op: Op, const max_len = class_ctx;
                // LessThan is used so we don't delete the entire span (which is unproductive since
                // an empty input has always been tried)
                const len = if (max_len == 1) 1 else rng.uintLessThanBiased(
                    usize,
                    @min(max_len + 1, in.len),
                );
                switch (op) {
                    .delete => {
                        const i = rng.uintAtMostBiased(usize, in.len - len);
                        out.appendSliceAssumeCapacity(in[0..i]);
                        out.appendSliceAssumeCapacity(in[i + len ..]);
                    },
                    .pop => out.appendSliceAssumeCapacity(in[0 .. in.len - len]),
                }
            },
            .rmw => {
                const Op = enum { xor, truncate, add, packed_rng };
                const op: Op, const T, const endian, const xor_bits = class_ctx;
                if (in.len < @sizeOf(T)) return false;
                const Log2T = math.Log2Int(T);

                const idx = rng.uintAtMostBiased(usize, in.len - @sizeOf(T));
                const old = mem.readInt(T, in[idx..][0..@sizeOf(T)], endian);
                const new = switch (op) {
                    .xor => old ^ fewValue(rng, T, xor_bits),
                    .truncate => old & (@as(T, math.maxInt(T)) >> rng.int(Log2T)),
                    .add => old +% addend: {
                        const val = rng.int(Mutation.AddValue);
                        break :addend if (val == 0) 1 else val;
                    },
                    .packed_rng => blk: {
                        const bits = rng.int(math.Log2Int(T)) +| 1;
                        break :blk old ^ (rng.int(T) >> bits << rng.uintAtMostBiased(Log2T, bits));
                    },
                };
                out.appendSliceAssumeCapacity(in);
                mem.bytesAsValue(T, out.items[8..][idx..][0..@sizeOf(T)]).* =
                    mem.nativeTo(T, new, endian);
            },
            .move_span => {
                if (in.len < 2) return false;
                // One less since moving whole output will never change anything
                const len = rng.intRangeAtMostBiased(usize, 1, @min(
                    in.len - 1,
                    Mutation.max_set_len,
                ));

                const src = rng.uintAtMostBiased(usize, in.len - len);
                // This indexes into the final input
                const dst = blk: {
                    const res = rng.uintAtMostBiased(usize, in.len - len - 1);
                    break :blk res + @intFromBool(res >= src);
                };

                if (src < dst) {
                    out.appendSliceAssumeCapacity(in[0..src]);
                    out.appendSliceAssumeCapacity(in[src + len .. dst + len]);
                    out.appendSliceAssumeCapacity(in[src..][0..len]);
                    out.appendSliceAssumeCapacity(in[dst + len ..]);
                } else {
                    out.appendSliceAssumeCapacity(in[0..dst]);
                    out.appendSliceAssumeCapacity(in[src..][0..len]);
                    out.appendSliceAssumeCapacity(in[dst..src]);
                    out.appendSliceAssumeCapacity(in[src + len ..]);
                }
            },
            .replicate_splice_span => {
                if (in.len == 0) return false;
                if (corpus.len == 1) return false;
                const from = corpus[rng.intRangeLessThanBiased(usize, 1, corpus.len)];
                const len = rng.uintLessThanBiased(usize, @min(in.len, from.len, max_replicate_len));
                const i = rng.uintAtMostBiased(usize, @min(in.len, from.len) - len);
                out.appendSliceAssumeCapacity(in[0..i]);
                out.appendSliceAssumeCapacity(from[i..][0..len]);
                out.appendSliceAssumeCapacity(in[i + len ..]);
            },
        }
        return true;
    }
};

/// Like `std.ArrayList(u8)` but backed by memory mapping.
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
            new = mem.alignForward(usize, new + new / 2, std.heap.page_size_max);
            if (new >= minimum) return new;
        }
    }

    pub fn insertAssumeCapacity(l: *MemoryMappedList, i: usize, item: u8) void {
        assert(l.items.len + 1 <= l.capacity);
        l.items.len += 1;
        volatileCopyBackwards(u8, l.items[i + 1 ..], l.items[i .. l.items.len - 1]);
        l.items[i] = item;
    }

    pub fn orderedRemove(l: *MemoryMappedList, i: usize) u8 {
        assert(l.items.len + 1 <= l.capacity);
        const old = l.items[i];
        volatileCopyForwards(u8, l.items[i .. l.items.len - 1], l.items[i + 1 ..]);
        l.items.len -= 1;
        return old;
    }
};
