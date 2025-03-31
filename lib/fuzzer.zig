const builtin = @import("builtin");
const std = @import("std");
const mem = std.mem;
const math = std.math;
const Allocator = mem.Allocator;
const assert = std.debug.assert;
const fatal = std.process.fatal;
const abi = std.Build.Fuzz.abi;
const native_endian = builtin.cpu.arch.endian();

pub const std_options = std.Options{
    .logFn = logOverride,
    .log_level = if (builtin.mode == .Debug) .debug else .info,
};

fn logOverride(
    comptime level: std.log.Level,
    comptime scope: @Type(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    const log_file = exec.cache_tmp.createFile("libfuzzer.log", .{
        .truncate = false,
        .lock = .exclusive,
    }) catch |e|
        std.debug.panic("failed to open fuzzer log file 'libfuzzer.log': {s}", .{@errorName(e)});
    defer log_file.close();
    log_file.seekFromEnd(0) catch |e|
        std.debug.panic("failed to seek fuzzer log file 'libfuzzer.log': {s}", .{@errorName(e)});

    const prefix1 = comptime level.asText();
    const prefix2 = if (scope == .default) ": " else "(" ++ @tagName(scope) ++ "): ";
    log_file.writer().print(
        "[{?s}] " ++ prefix1 ++ prefix2 ++ format ++ "\n",
        .{current_test_name} ++ args,
    ) catch |e|
        std.debug.panic("failed to write to fuzzer log file 'libfuzzer.log': {s}", .{@errorName(e)});
}

var debug_allocator: std.heap.GeneralPurposeAllocator(.{}) = .init;
const gpa = switch (builtin.mode) {
    .Debug => debug_allocator.allocator(),
    .ReleaseFast, .ReleaseSmall, .ReleaseSafe => std.heap.smp_allocator,
};

var exec: Executable = undefined;
var inst: Instrumentation = undefined;
var fuzzer: Fuzzer = undefined;
var current_test_name: ?[]const u8 = undefined;

fn bitsetUsizes(elems: usize) usize {
    return math.divCeil(usize, elems, @bitSizeOf(usize)) catch unreachable;
}

const Executable = struct {
    /// Tracks the hit count for each pc as updated by the process's instrumentation.
    pc_counters: []u8,
    /// Read-only memory section containing compiled-in constants found from parsing the executable
    rodata_addr: usize,
    rodata_size: usize,

    cache_f: std.fs.Dir,
    cache_tmp: std.fs.Dir,
    /// Shared copy of all pcs that have been hit stored in a memory-mapped file that can viewed
    /// while the fuzzer is running.
    shared_seen_pcs: MemoryMappedList,
    /// Hash of pcs used to uniquely identify the shared coverage file
    pc_digest: u64,

    /// Always inits rodata_addr and rodata_size to valid values, even on error
    fn initRodata(self: *Executable) !void {
        errdefer {
            self.rodata_addr = 0;
            self.rodata_size = 0;
        }

        const exec_path = std.fs.selfExePathAlloc(gpa) catch |e|
            if (e == error.OutOfMemory) @panic("OOM") else return e;
        defer gpa.free(exec_path);
        const exec_file = try std.fs.cwd().openFile(exec_path, .{});
        defer exec_file.close();

        const ehdr: std.elf.Header = try .read(exec_file);
        if (ehdr.shstrndx == 0) return error.NoElfStringTable;
        var shdr_it = ehdr.section_header_iterator(exec_file);
        shdr_it.index = ehdr.shstrndx;
        const str_tab_shdr = try shdr_it.next() orelse return error.InvalidElfSection;
        const str_tab_off = str_tab_shdr.sh_offset;

        shdr_it.index = 0;
        while (try shdr_it.next()) |shdr| {
            const flags: packed struct(u64) {
                write: bool,
                alloc: bool,
                execinstr: bool,
                _: u61,
            } = @bitCast(shdr.sh_flags);

            if (shdr.sh_addr == 0 or shdr.sh_size == 0 or
                !flags.alloc or flags.write or flags.execinstr) continue;
            try exec_file.seekTo(try math.add(u64, str_tab_off, shdr.sh_name));
            if (!try exec_file.reader().isBytes(".rodata\x00")) continue;

            const addr = math.cast(usize, shdr.sh_addr) orelse return error.Overflow;
            const size = math.cast(usize, shdr.sh_size) orelse return error.Overflow;
            _ = try math.add(usize, addr, size);
            self.rodata_addr = addr;
            self.rodata_size = size;
            return;
        }
        return error.NoRodataSection;
    }

    fn getCoverageFile(cache_dir: std.fs.Dir, pcs: []const usize, pc_digest: u64) MemoryMappedList {
        const pc_bitset_usizes = bitsetUsizes(pcs.len);
        const coverage_file_name = std.fmt.hex(pc_digest);
        comptime assert(abi.SeenPcsHeader.trailing[0] == .pc_bits_usize);
        comptime assert(abi.SeenPcsHeader.trailing[1] == .pc_addr);
        const coverage_file_len = @sizeOf(abi.SeenPcsHeader) +
            pc_bitset_usizes * @sizeOf(usize) +
            pcs.len * @sizeOf(usize);

        var v = cache_dir.makeOpenPath("v", .{}) catch |e|
            fatal("failed to open directory 'v': {s}", .{@errorName(e)});
        defer v.close();
        const coverage_file = v.createFile(&coverage_file_name, .{
            .read = true,
            .truncate = false,
            // Block other fuzzing processes while we populate the coverage file
            .lock = .exclusive,
            // We only want an exclusive lock if we are the first to access the file
            .lock_nonblocking = true,
        }) catch |e| switch (e) {
            error.WouldBlock => v.openFile(&coverage_file_name, .{
                .mode = .read_write,
                .lock = .shared,
            }) catch |e2| fatal(
                "failed to open coverage file '{s}': {s}",
                .{ &coverage_file_name, @errorName(e2) },
            ),
            else => fatal(
                "failed to create coverage file '{s}': {s}",
                .{ &coverage_file_name, @errorName(e) },
            ),
        };
        defer coverage_file.lock(.shared) catch |e| fatal(
            "failed to demote lock for coverage file '{s}': {s}",
            .{ &coverage_file_name, @errorName(e) },
        );

        const size = coverage_file.getEndPos() catch |e| fatal(
            "failed to stat coverage file '{s}': {s}",
            .{ &coverage_file_name, @errorName(e) },
        );
        if (size == 0) {
            var map = MemoryMappedList.create(coverage_file, 0, coverage_file_len) catch |e2|
                fatal(
                    "failed to init memory map for coverage file '{s}': {s}",
                    .{ &coverage_file_name, @errorName(e2) },
                );
            map.appendSliceAssumeCapacity(mem.asBytes(&abi.SeenPcsHeader{
                .n_runs = 0,
                .unique_runs = 0,
                .pcs_len = pcs.len,
            }));
            map.appendNTimesAssumeCapacity(0, pc_bitset_usizes * @sizeOf(usize));
            map.appendSliceAssumeCapacity(mem.sliceAsBytes(pcs));
            return map;
        } else {
            if (size != coverage_file_len) fatal(
                "incompatible existing coverage file '{s}' (differing lengths: {} != {})",
                .{ &coverage_file_name, size, coverage_file_len },
            );

            const map = MemoryMappedList.init(
                coverage_file,
                coverage_file_len,
                coverage_file_len,
            ) catch |e| fatal(
                "failed to map for coverage file '{s}': {s}",
                .{ &coverage_file_name, @errorName(e) },
            );

            const seen_pcs_header: *const abi.SeenPcsHeader = @ptrCast(@volatileCast(map.items));
            if (seen_pcs_header.pcs_len != pcs.len) fatal(
                "incompatible existing coverage file '{s}' (differing pcs length: {} != {})",
                .{ &coverage_file_name, seen_pcs_header.pcs_len, pcs.len },
            );
            if (mem.indexOfDiff(usize, seen_pcs_header.pcAddrs(), pcs)) |i| fatal(
                "incompatible existing coverage file '{s}' (differing pc at index {d}: {x} != {x})",
                .{ &coverage_file_name, i, seen_pcs_header.pcAddrs()[i], pcs[i] },
            );

            return map;
        }
    }

    pub fn init(cache_dir_path: []const u8) Executable {
        var self: Executable = undefined;

        const cache_dir = std.fs.cwd().makeOpenPath(cache_dir_path, .{}) catch |e|
            fatal("failed to open directory '{s}': {s}", .{ cache_dir_path, @errorName(e) });
        self.cache_f = cache_dir.makeOpenPath("f", .{}) catch |e|
            fatal("failed to open directory 'f': {s}", .{@errorName(e)});
        self.cache_tmp = cache_dir.makeOpenPath("tmp", .{}) catch |e|
            fatal("failed to open directory 'tmp': {s}", .{@errorName(e)});

        self.pc_counters = blk: {
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

            break :blk pc_counters_start[0 .. pc_counters_end - pc_counters_start];
        };

        const pcs = blk: {
            const pcs_start = @extern([*]usize, .{
                .name = "__start___sancov_pcs1",
                .linkage = .weak,
            }) orelse fatal("missing __start___sancov_pcs1 symbol", .{});

            const pcs_end = @extern([*]usize, .{
                .name = "__stop___sancov_pcs1",
                .linkage = .weak,
            }) orelse fatal("missing __stop___sancov_pcs1 symbol", .{});

            break :blk pcs_start[0 .. pcs_end - pcs_start];
        };

        if (self.pc_counters.len != pcs.len) fatal(
            "pc counters length and pcs length do not match ({} != {})",
            .{ self.pc_counters.len, pcs.len },
        );

        self.initRodata() catch |e| {
            std.log.warn("failed to enumerate read-only memory: {s}", .{@errorName(e)});
            std.log.warn("efficiency will be severely reduced", .{});
        };

        self.pc_digest = std.hash.Wyhash.hash(0, mem.sliceAsBytes(pcs));
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

/// Data gathered from instrumentation functions
/// Seperate from Executable since its state is resetable and changes
/// Seperate from Fuzzer since it may be needed before fuzzing starts
const Instrumentation = struct {
    /// Bitset of seen pcs across all runs excluding fresh pcs.
    /// This is seperate then shared_seen_pcs because multiple fuzzing processes are likely using
    /// it which causes contention and unrelated pcs to our campaign being set.
    seen_pcs: []usize,
    /// Bitset of seen rodata bytes read across all runs
    seen_rodata_loads: []usize,

    /// Bitset of run's read bytes that weren't present in seen_loads
    /// Elements are always zero if !any_new_data_loads
    new_rodata_loads: []usize,
    any_new_rodata_loads: bool,

    /// Stores a fresh input's new pcs
    fresh_pcs: []usize,
    /// Stores a fresh input's new reads
    /// Elements are always zero if !any_fresh_rodata_loads
    fresh_rodata_loads: []usize,
    any_fresh_rodata_loads: bool,

    /// Pcs which __sanitizer_cov_trace_switch and __sanitizer_cov_trace_const_cmpx
    /// have been called from and have had their already been added to const_x_vals
    const_pcs: std.AutoArrayHashMapUnmanaged(usize, void) = .empty,
    /// Values that have been constant operands in comparisons, switch cases, or memory reads
    /// There may be duplicates in this array if they came from different addresses, which is
    /// fine as they are likely more important and hence more likely to be selected.
    const_vals2: std.ArrayListUnmanaged(u16) = .empty,
    const_vals4: std.ArrayListUnmanaged(u32) = .empty,
    const_vals8: std.ArrayListUnmanaged(u64) = .empty,
    const_vals16: std.ArrayListUnmanaged(u128) = .empty,

    pub fn init() Instrumentation {
        const pc_bitset_usizes = bitsetUsizes(exec.pc_counters.len);
        const rodata_bitset_usizes = bitsetUsizes(exec.rodata_size);
        const alloc_usizes = pc_bitset_usizes * 2 + rodata_bitset_usizes * 3;
        const buf = gpa.alloc(u8, alloc_usizes * @sizeOf(usize)) catch @panic("OOM");
        var fba_ctx: std.heap.FixedBufferAllocator = .init(buf);
        const fba = fba_ctx.allocator();

        var self: Instrumentation = .{
            .seen_pcs = fba.alloc(usize, pc_bitset_usizes) catch unreachable,
            .seen_rodata_loads = fba.alloc(usize, rodata_bitset_usizes) catch unreachable,
            .new_rodata_loads = fba.alloc(usize, rodata_bitset_usizes) catch unreachable,
            .any_new_rodata_loads = undefined,
            .fresh_pcs = fba.alloc(usize, pc_bitset_usizes) catch unreachable,
            .fresh_rodata_loads = fba.alloc(usize, rodata_bitset_usizes) catch unreachable,
            .any_fresh_rodata_loads = undefined,
        };
        self.reset();
        return self;
    }

    pub fn reset(self: *Instrumentation) void {
        @memset(self.seen_pcs, 0);
        @memset(self.seen_rodata_loads, 0);
        @memset(self.new_rodata_loads, 0);
        self.any_new_rodata_loads = false;
        @memset(self.fresh_pcs, 0);
        @memset(self.fresh_rodata_loads, 0);
        self.any_fresh_rodata_loads = false;
        self.const_pcs.clearRetainingCapacity();
        self.const_vals2.clearRetainingCapacity();
        self.const_vals4.clearRetainingCapacity();
        self.const_vals8.clearRetainingCapacity();
        self.const_vals16.clearRetainingCapacity();
    }

    /// If false is returned, then the pc is added to const_pcs
    pub fn constPcSeen(self: *Instrumentation, pc: usize) bool {
        return (self.const_pcs.getOrPut(gpa, pc) catch @panic("OOM")).found_existing;
    }

    pub fn clearNewRodataLoads(self: *Instrumentation) void {
        if (self.any_new_rodata_loads) {
            @memset(self.new_rodata_loads, 0);
            self.any_new_rodata_loads = false;
        }
    }

    pub fn isFresh(self: *Instrumentation) bool {
        if (self.any_new_rodata_loads) return true;

        var hit_pcs = exec.pcBitsetIterator();
        for (self.seen_pcs) |seen_pcs| {
            if (hit_pcs.next() & ~seen_pcs != 0) return true;
        }

        return false;
    }

    /// Updates fresh_pcs and fresh_rodata_loads
    /// any_new_rodata_loads and elements of new_rodata_loads are unspecified
    /// afterwards, but still valid.
    pub fn setFresh(self: *Instrumentation) void {
        var hit_pcs = exec.pcBitsetIterator();
        for (self.seen_pcs, self.fresh_pcs) |seen_pcs, *fresh_pcs| {
            fresh_pcs.* = hit_pcs.next() & ~seen_pcs;
        }

        mem.swap([]usize, &self.fresh_rodata_loads, &self.new_rodata_loads);
        mem.swap(bool, &self.any_fresh_rodata_loads, &self.any_new_rodata_loads);
    }

    /// Returns if exec.pc_counters and new_rodata_loads are the same or a superset of fresh_pcs and
    /// fresh_rodata_loads respectively.
    pub fn atleastFresh(self: *Instrumentation) bool {
        var hit_pcs = exec.pcBitsetIterator();
        for (self.fresh_pcs) |fresh_pcs| {
            if (fresh_pcs & hit_pcs.next() != fresh_pcs) return false;
        }

        if (self.any_fresh_rodata_loads) {
            if (!self.any_new_rodata_loads) return false;
            for (self.new_rodata_loads, self.fresh_rodata_loads) |n, f| {
                if (n & f != f) return false;
            }
        }

        return true;
    }

    /// Updates based off fresh_pcs and fresh_rodata_loads
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

        if (self.any_fresh_rodata_loads) {
            for (self.seen_rodata_loads, self.fresh_rodata_loads) |*s, f|
                s.* |= f;
        }
    }
};

const Fuzzer = struct {
    pub const TestOne = *const fn (input: abi.Slice) callconv(.c) void;

    arena_ctx: std.heap.ArenaAllocator = .init(gpa),
    rng: std.Random.DefaultPrng = .init(0),
    test_one: TestOne,
    /// The next input that will be given to the testOne function. When the
    /// current process crashes, this memory-mapped file is used to recover the
    /// input.
    input: MemoryMappedList,

    /// Minimized past inputs leading to new pcs or rodata reads. These are randomly mutated in
    /// round-robin fashion
    /// Element zero is always an empty input. It is gauraunteed no other elements are empty.
    corpus: std.ArrayListUnmanaged([]const u8),
    corpus_pos: usize,
    /// List of past mutations that have led to new inputs. This way, the mutations that are the
    /// most effective are the most likely to be selected again. Starts with one of each mutation.
    mutations: std.ArrayListUnmanaged(Mutation) = .empty,

    /// Filesystem directory containing found inputs for future runs
    corpus_dir: std.fs.Dir,
    corpus_dir_idx: usize = 0,

    pub fn init(test_one: TestOne, unit_test_name: []const u8) Fuzzer {
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
            fatal("failed to open directory '{s}': {s}", .{ unit_test_name, @errorName(e) });
        self.input = in: {
            const f = self.corpus_dir.createFile("in", .{
                .read = true,
                .truncate = false,
            }) catch |e|
                fatal("failed to create input file 'in': {s}", .{@errorName(e)});
            const size = f.getEndPos() catch |e|
                fatal("failed to stat input file 'in': {s}", .{@errorName(e)});
            const map = (if (size < std.heap.page_size_max)
                MemoryMappedList.create(f, 8, std.heap.page_size_max)
            else
                MemoryMappedList.init(f, size, size)) catch |e|
                fatal("failed to memory map input file 'in': {s}", .{@errorName(e)});

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
                arena,
                std.fmt.bufPrint(&name_buf, "{x}", .{self.corpus_dir_idx}) catch unreachable,
                math.maxInt(usize),
            ) catch |e| switch (e) {
                error.FileNotFound => break,
                else => fatal(
                    "failed to read corpus file '{x}': {s}",
                    .{ self.corpus_dir_idx, @errorName(e) },
                ),
            };
            // No corpus file of length zero will ever be created
            if (bytes.len == 0)
                fatal("corrupt corpus file '{x}' (len of zero)", .{self.corpus_dir_idx});
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
            fatal("could not resize shared input file: {s}", .{@errorName(e)});
        self.input.items.len = 8;
        self.input.appendSliceAssumeCapacity(bytes);
        self.run();
        inst.setFresh();
        inst.updateSeen();
        inst.clearNewRodataLoads();
    }

    /// Assumes fresh_pcs and fresh_rodata_loads correspond to the input
    fn minimizeInput(self: *Fuzzer) void {
        // The minimization technique is kept relatively simple, we sequentially try to remove each
        // byte and check that the new pcs and memory loads are still hit.
        var i = self.input.items.len;
        while (i != 8) {
            i -= 1;
            const old = self.input.orderedRemove(i);

            @memset(exec.pc_counters, 0);
            inst.clearNewRodataLoads();
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
        // We don't need to clear pc_counters here; all we care about is new hits and not already
        // seen hits. Ideally, we wouldn't even have these counters and do something similiar to
        // what we do for tracking memory (i.e. a __sanitizer_cov function that updates a flag on a
        // new hit.)
        assert(!inst.any_new_rodata_loads);

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
        while (true) {
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
                inst.clearNewRodataLoads();

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
                }) catch |e| fatal(
                    "could not write corpus file '{x}': {s}",
                    .{ self.corpus_dir_idx, @errorName(e) },
                );
                self.corpus_dir_idx += 1;
            }

            break;
        }
    }
};

/// Instrumentation must not be triggered before this function is called
export fn fuzzer_init(cache_dir_path: abi.Slice) void {
    exec = .init(cache_dir_path.toSlice());
    inst = .init();
}

/// Invalid until `fuzzer_init` is called.
export fn fuzzer_coverage_id() u64 {
    return exec.pc_digest;
}

/// fuzzer_init must be called beforehand
export fn fuzzer_init_test(test_one: Fuzzer.TestOne, unit_test_name: abi.Slice) void {
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
export fn fuzzer_main() void {
    while (true) {
        fuzzer.cycle();
    }
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

fn genericLoad(T: anytype, ptr: *const T, comptime opt_const_vals_field: ?[]const u8) void {
    const addr = @intFromPtr(ptr);
    const off = addr -% exec.rodata_addr;
    if (off >= exec.rodata_size) return;

    const i = off / @bitSizeOf(usize);
    const new = @shlExact(
        @as(usize, (1 << @sizeOf(T)) - 1),
        @intCast(off % @bitSizeOf(usize)),
    ) & ~inst.seen_rodata_loads[i];
    inst.new_rodata_loads[i] |= new;
    inst.any_new_rodata_loads = inst.any_new_rodata_loads or new != 0;

    if (opt_const_vals_field) |const_vals_field| {
        // This may have already been hit and this run is just being used for evaluating the
        // input, in which case we do not want to readd the same value.
        if (new & ~inst.fresh_rodata_loads[i] != 0) {
            @field(inst, const_vals_field).append(gpa, ptr.*) catch @panic("OOM");
        }
    }
}

export fn __sanitizer_cov_load1(ptr: *const u8) void {
    genericLoad(u8, ptr, null);
}

export fn __sanitizer_cov_load2(ptr: *const u16) void {
    genericLoad(u16, ptr, "const_vals2");
}

export fn __sanitizer_cov_load4(ptr: *const u32) void {
    genericLoad(u32, ptr, "const_vals4");
}

export fn __sanitizer_cov_load8(ptr: *const u64) void {
    genericLoad(u64, ptr, "const_vals8");
}

export fn __sanitizer_cov_load16(ptr: *const u128) void {
    genericLoad(u128, ptr, "const_vals16");
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
            fatal("could not resize shared input file: {s}", .{@errorName(e)});
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
                    .@"const" => out.appendSliceAssumeCapacity(mem.asBytes(
                        &data_ctx[rng.uintLessThanBiased(usize, data_ctx.len)],
                    )),
                    .small => out.appendSliceAssumeCapacity(mem.asBytes(
                        &mem.nativeTo(data_ctx[0], rng.int(SmallValue), data_ctx[1]),
                    )),
                    .few => out.appendSliceAssumeCapacity(mem.asBytes(
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
