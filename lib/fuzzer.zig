const builtin = @import("builtin");
const std = @import("std");
const mem = std.mem;
const math = std.math;
const assert = std.debug.assert;
const panic = std.debug.panic;
const abi = std.Build.abi.fuzz;
const Uid = abi.Uid;

pub const std_options = std.Options{
    .logFn = logOverride,
};

fn logOverride(
    comptime level: std.log.Level,
    comptime scope: @Type(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    const f = log_f orelse panic("log before initialization, message:\n" ++ format, args);
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

// Seperate from `exec` to allow initialization before `exec` is.
var log_f: ?std.fs.File = null;
var exec: Executable = undefined;
var fuzzer: Fuzzer = undefined;
var current_test_name: ?[]const u8 = null;

fn bitsetUsizes(elems: usize) usize {
    return math.divCeil(usize, elems, @bitSizeOf(usize)) catch unreachable;
}

const Executable = struct {
    /// Tracks the hit count for each pc as updated by the test's instrumentation.
    pc_counters: []u8,

    cache_f: std.fs.Dir,
    /// Shared copy of all pcs that have been hit stored in a memory-mapped file that can viewed
    /// while the fuzzer is running.
    shared_seen_pcs: []align(std.heap.page_size_min) volatile u8,
    /// Hash of pcs used to uniquely identify the shared coverage file
    pc_digest: u64,

    fn getCoverageMap(
        cache_dir: std.fs.Dir,
        pcs: []const usize,
        pc_digest: u64,
    ) []align(std.heap.page_size_min) volatile u8 {
        const pc_bitset_usizes = bitsetUsizes(pcs.len);
        const coverage_file_name = std.fmt.hex(pc_digest);
        comptime assert(abi.SeenPcsHeader.trailing[0] == .pc_bits_usize);
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
            coverage_file.setEndPos(coverage_file_len) catch |e|
                panic("failed to resize new coverage file '{s}': {t}", .{ &coverage_file_name, e });
            var map = fileMap(coverage_file, coverage_file_len) catch |e|
                panic("failed to memmap coverage file '{s}': {t}", .{ &coverage_file_name, e });
            mem.bytesAsValue(abi.SeenPcsHeader, map[0..@sizeOf(abi.SeenPcsHeader)]).* = .{
                .n_runs = 0,
                .unique_runs = 0,
                .pcs_len = pcs.len,
            };
            const trailing = map[@sizeOf(abi.SeenPcsHeader)..];
            @memset(mem.bytesAsSlice(usize, trailing[0 .. pc_bitset_usizes * @sizeOf(usize)]), 0);
            @memcpy(mem.bytesAsSlice(usize, trailing[pc_bitset_usizes * @sizeOf(usize) ..]), pcs);
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

            const map = fileMap(coverage_file, coverage_file_len) catch |e| panic(
                "failed to memmap coverage file '{s}': {t}",
                .{ &coverage_file_name, e },
            );

            const seen_pcs_header: *const abi.SeenPcsHeader = @ptrCast(@volatileCast(map));
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

        self.pc_digest = std.hash.Wyhash.hash(0, mem.sliceAsBytes(pcs));
        self.shared_seen_pcs = getCoverageMap(cache_dir, pcs, self.pc_digest);

        return self;
    }

    pub fn pcBitsetIterator(self: Executable) PcBitsetIterator {
        return .{ .pc_counters = self.pc_counters };
    }

    /// Iterates over pc_counters returning a bitset for if each of them have been hit
    pub const PcBitsetIterator = struct {
        index: usize = 0,
        pc_counters: []u8,

        pub fn next(i: *PcBitsetIterator) usize {
            const rest = i.pc_counters[i.index..];
            if (rest.len >= @bitSizeOf(usize)) {
                defer i.index += @bitSizeOf(usize);
                const V = @Vector(@bitSizeOf(usize), u8);
                return @as(usize, @bitCast(@as(V, @splat(0)) != rest[0..@bitSizeOf(usize)].*));
            } else if (rest.len != 0) {
                defer i.index += rest.len;
                var res: usize = 0;
                for (0.., rest) |bit_index, byte| {
                    res |= @shlExact(@as(usize, @intFromBool(byte != 0)), @intCast(bit_index));
                }
                return res;
            } else unreachable;
        }
    };

    pub fn seenPcsHeader(e: Executable) *align(std.heap.page_size_min) volatile abi.SeenPcsHeader {
        return mem.bytesAsValue(
            abi.SeenPcsHeader,
            e.shared_seen_pcs[0..@sizeOf(abi.SeenPcsHeader)],
        );
    }
};

const Fuzzer = struct {
    // The default PRNG is not used here since going through `Random` can be very expensive
    // since LLVM often fails to devirtualize and inline `fill`. Additionally, optimization
    // is simpler since integers are not serialized then deserialized in the random stream.
    //
    // This acounts for a 30% performance improvement with LLVM 21.
    xoshiro: std.Random.Xoshiro256,
    test_one: abi.TestOne,

    seen_pcs: []usize,
    bests: struct {
        len: u32,
        quality_buf: []Input.Best,
        input_buf: []Input.Best.Map,
    },
    seen_uids: std.ArrayHashMapUnmanaged(Uid, struct {
        slices: union {
            ints: std.ArrayList([]u64),
            bytes: std.ArrayList(Input.Data.Bytes),
        },
    }, Uid.hashmap_ctx, false),

    /// Past inputs leading to new pc or uid hits.
    /// These are randomly mutated in round-robin fashion.
    corpus: std.MultiArrayList(Input),
    corpus_pos: Input.Index,

    bytes_input: std.testing.Smith,
    input_builder: Input.Builder,
    /// Number of data calls the current run has made.
    req_values: u32,
    /// Number of bytes provided to the current run.
    req_bytes: u32,
    /// Index into the uid slices the current run is at.
    /// `uid_data_i[i]` corresponds to `corpus[corpus_pos].data.uid_slices.values()[i]`.
    uid_data_i: std.ArrayList(u32),
    mut_data: struct {
        /// Untyped indexes of `corpus[corpus_pos].data` that should be mutated.
        ///
        /// If an index appears multiple times, the first should be prioritized.
        i: [4]u32,
        /// For mutations which are a sequential mutation, the state is stored here.
        seq: [4]struct {
            kind: packed struct {
                class: enum(u1) { replace, insert },
                copy: bool,
                /// If set then `.copy = true` and `.class = .replace`
                ordered_mutate: bool,
                /// If set then all other bits are undefined
                none: bool,
            },
            len: u32,
            copy: SeqCopy,
        },
    },

    /// As values are provided to the Smith, they are appended to this. If the test
    /// crashes, this can be recovered and used to obtain the crashing values.
    mmap_input: MemoryMappedInput,
    /// Filesystem directory containing found inputs for future runs
    corpus_dir: std.fs.Dir,
    /// The values in `corpus` past this point directly correspond to what is found
    /// in `corpus_dir`.
    start_corpus_dir: u32,

    const SeqCopy = union {
        order_i: u32,
        ints: []u64,
        bytes: Input.Data.Bytes,
    };

    const Input = struct {
        /// Untyped indexes into this are formed as follows: If the index is less than `ints.len`
        /// it indexes into `ints`, otherwise it indexes into `bytes` subtracted by `ints.len`.
        /// `math.maxInt(u32)` is reserved and impossible normally.
        data: Data,
        /// Corresponds with `data.uid_slices`.
        /// Values are the indexes of `seen_uids` with the same uid.
        seen_uid_i: []u32,
        /// Used to select a random uid to mutate from.
        ///
        /// The number of times a uid is present in this array is logarithmic
        /// to its data length in order to avoid long inputs from only being
        /// selected while still having some bias towards longer ones.
        weighted_uid_slice_i: []u32,

        ref: struct {
            /// Values are indexes of `Fuzzer.bests`.
            best_i_buf: []u32,
            best_i_len: u32,
        },

        pub const Data = struct {
            uid_slices: Data.UidSlices,
            ints: []u64,
            bytes: Bytes,
            /// Contains untyped indexes in the order they were requested.
            order: []u32,

            pub const Bytes = struct {
                entries: []Entry,
                table: []u8,

                pub const Entry = struct {
                    off: u32,
                    len: u32,
                };

                pub fn deinit(b: Bytes) void {
                    gpa.free(b.entries);
                    gpa.free(b.table);
                }
            };

            pub const UidSlices = std.ArrayHashMapUnmanaged(Uid, struct {
                base: u32,
                len: u32,
            }, Uid.hashmap_ctx, false);
        };

        pub fn deinit(i: *Input) void {
            i.data.uid_slices.deinit(gpa);
            gpa.free(i.data.ints);
            i.data.bytes.deinit();
            gpa.free(i.data.order);
            gpa.free(i.seen_uid_i);
            gpa.free(i.weighted_uid_slice_i);
            gpa.free(i.ref.best_i_buf);
            i.* = undefined;
        }

        pub const none: Input = .{
            .data = .{
                .uid_slices = .empty,
                .ints = &.{},
                .bytes = .{
                    .entries = &.{},
                    .table = undefined,
                },
                .order = &.{},
            },
            .seen_uid_i = &.{},
            .weighted_uid_slice_i = &.{},

            // Empty input is not referenced by `Fuzzer`
            .ref = undefined,
        };

        pub const Index = enum(u32) {
            pub const reserved_start: Index = .bytes_dry;
            /// Only touches `Fuzzer.smith`.
            bytes_dry = math.maxInt(u32) - 1,
            /// Only touches `Fuzzer.smith` and `Fuzzer.input_builder`.
            bytes_fresh = math.maxInt(u32),
            _,
        };

        pub const Best = struct {
            pc: u32,
            min: Quality,
            max: Quality,

            /// Order of significance:
            /// * n_pcs
            /// * req.values
            /// * req.bytes
            pub const Quality = struct {
                n_pcs: u32,
                req: packed struct(u64) {
                    bytes: u32,
                    values: u32,

                    pub fn int(r: @This()) u64 {
                        return @bitCast(r);
                    }
                },

                pub fn betterLess(a: Quality, b: Quality) bool {
                    return (a.n_pcs < b.n_pcs) | ((a.n_pcs == b.n_pcs) & (a.req.int() < b.req.int()));
                }

                pub fn betterMore(a: Quality, b: Quality) bool {
                    return (a.n_pcs > b.n_pcs) | ((a.n_pcs == b.n_pcs) & (a.req.int() < b.req.int()));
                }
            };

            pub const Map = struct {
                min: Input.Index,
                max: Input.Index,
            };
        };

        pub const Builder = struct {
            uid_slices: std.ArrayHashMapUnmanaged(Uid, union {
                ints: std.MultiArrayList(struct {
                    value: u64,
                    order_i: u32,
                }),
                bytes: std.MultiArrayList(struct {
                    value: Data.Bytes.Entry,
                    order_i: u32,
                }),
            }, Uid.hashmap_ctx, false),
            bytes_table: std.ArrayList(u8),
            // These will not overflow due to the 32-bit constraint on `MemoryMappedInput`
            total_ints: u32,
            total_bytes: u32,
            weighted_len: u32,
            /// Used to ensure that the 32-bit constraint in
            /// `MemoryMappedInput` applies to this run.
            smithed_len: u32,

            pub const init: Builder = .{
                .uid_slices = .empty,
                .bytes_table = .empty,
                .total_ints = 0,
                .total_bytes = 0,
                .weighted_len = 0,
                .smithed_len = 4,
            };

            pub fn addInt(b: *Builder, uid: Uid, int: u64) void {
                const u = &b.uid_slices;
                const gop = u.getOrPutValue(gpa, uid, .{ .ints = .empty }) catch @panic("OOM");
                gop.value_ptr.ints.append(gpa, .{
                    .value = int,
                    .order_i = b.total_ints + b.total_bytes,
                }) catch @panic("OOM");
                b.total_ints += 1;
                b.weighted_len += @intFromBool(math.isPowerOfTwo(gop.value_ptr.ints.len));
            }

            pub fn addBytes(b: *Builder, uid: Uid, bytes: []const u8) void {
                const u = &b.uid_slices;
                const gop = u.getOrPutValue(gpa, uid, .{ .bytes = .empty }) catch @panic("OOM");
                gop.value_ptr.bytes.append(gpa, .{
                    .value = .{
                        .off = @intCast(b.bytes_table.items.len),
                        .len = @intCast(bytes.len),
                    },
                    .order_i = b.total_ints + b.total_bytes,
                }) catch @panic("OOM");
                b.bytes_table.appendSlice(gpa, bytes) catch @panic("OOM");
                b.total_bytes += 1;
                b.weighted_len += @intFromBool(math.isPowerOfTwo(gop.value_ptr.bytes.len));
            }

            pub fn checkSmithedLen(b: *Builder, n: usize) void {
                const n32 = @min(n, math.maxInt(u32)); // second will overflow
                b.smithed_len, const ov = @addWithOverflow(b.smithed_len, n32);
                if (ov == 1) @panic("too much smith data requested (non-deterministic)");
            }

            /// Additionally resets the state of this structure.
            ///
            /// The callee must populate
            /// * `.seen_uid_i`
            /// * `.ref`
            pub fn build(b: *Builder) Input {
                const uid_slices = b.uid_slices.entries.slice();
                var input: Input = .{
                    .data = .{
                        .uid_slices = Data.UidSlices.init(gpa, uid_slices.items(.key), &.{}) catch
                            @panic("OOM"),
                        .ints = gpa.alloc(u64, b.total_ints) catch @panic("OOM"),
                        .bytes = .{
                            .entries = gpa.alloc(Data.Bytes.Entry, b.total_bytes) catch @panic("OOM"),
                            .table = b.bytes_table.toOwnedSlice(gpa) catch @panic("OOM"),
                        },
                        .order = gpa.alloc(u32, b.total_ints + b.total_bytes) catch @panic("OOM"),
                    },
                    .seen_uid_i = gpa.alloc(u32, uid_slices.len) catch @panic("OOM"),
                    .weighted_uid_slice_i = gpa.alloc(u32, b.weighted_len) catch @panic("OOM"),
                    .ref = undefined,
                };
                var ints_pos: u32 = 0;
                var bytes_pos: u32 = 0;
                var weighted_pos: u32 = 0;

                assert(mem.eql(Uid, uid_slices.items(.key), input.data.uid_slices.keys()));
                for (
                    0..,
                    uid_slices.items(.key),
                    uid_slices.items(.value),
                    input.data.uid_slices.values(),
                ) |uid_i, uid, *uid_data, *slice| {
                    const weighted_len = 1 + math.log2_int(u32, len: switch (uid.kind) {
                        .int => {
                            const ints = uid_data.ints.slice();
                            @memcpy(input.data.ints[ints_pos..][0..ints.len], ints.items(.value));
                            for (ints.items(.order_i), ints_pos..) |order_i, data_i| {
                                input.data.order[order_i] = @intCast(data_i);
                            }
                            uid_data.ints.deinit(gpa);
                            slice.* = .{ .base = ints_pos, .len = @intCast(ints.len) };
                            ints_pos += @intCast(ints.len);
                            break :len @intCast(ints.len);
                        },
                        .bytes => {
                            const bytes = uid_data.bytes.slice();
                            @memcpy(
                                input.data.bytes.entries[bytes_pos..][0..bytes.len],
                                bytes.items(.value),
                            );
                            for (
                                bytes.items(.order_i),
                                b.total_ints + bytes_pos..,
                            ) |order_i, data_i| {
                                input.data.order[order_i] = @intCast(data_i);
                            }
                            uid_data.bytes.deinit(gpa);
                            slice.* = .{ .base = bytes_pos, .len = @intCast(bytes.len) };
                            bytes_pos += @intCast(bytes.len);
                            break :len @intCast(bytes.len);
                        },
                    });
                    const weighted = input.weighted_uid_slice_i[weighted_pos..][0..weighted_len];
                    @memset(weighted, @intCast(uid_i));
                    weighted_pos += weighted_len;
                }

                assert(ints_pos == b.total_ints);
                assert(bytes_pos == b.total_bytes);
                assert(weighted_pos == b.weighted_len);

                b.uid_slices.clearRetainingCapacity();
                b.total_ints = 0;
                b.total_bytes = 0;
                b.weighted_len = 0;
                b.smithed_len = 4;
                return input;
            }
        };
    };

    pub fn init() Fuzzer {
        if (exec.pc_counters.len > math.maxInt(u32)) @panic("too many pcs");
        const f: Fuzzer = .{
            .xoshiro = .init(0),
            .test_one = undefined,

            .seen_pcs = gpa.alloc(usize, bitsetUsizes(exec.pc_counters.len)) catch @panic("OOM"),
            .bests = .{
                .len = 0,
                .quality_buf = gpa.alloc(Input.Best, exec.pc_counters.len) catch @panic("OOM"),
                .input_buf = gpa.alloc(Input.Best.Map, exec.pc_counters.len) catch @panic("OOM"),
            },
            .seen_uids = .empty,

            .corpus = .empty,
            .corpus_pos = undefined,

            .bytes_input = undefined,
            .input_builder = .init,
            .req_values = undefined,
            .req_bytes = undefined,
            .uid_data_i = .empty,
            .mut_data = undefined,

            .mmap_input = undefined,
            .corpus_dir = undefined,
            .start_corpus_dir = undefined,
        };
        @memset(f.seen_pcs, 0);
        return f;
    }

    /// May only be called after `f.setTest` has been called
    pub fn reset(f: *Fuzzer) void {
        f.test_one = undefined;

        @memset(f.seen_pcs, 0);
        f.bests.len = 0;
        @memset(f.bests.quality_buf, undefined);
        @memset(f.bests.input_buf, undefined);
        for (f.seen_uids.keys(), f.seen_uids.values()) |uid, *u| {
            switch (uid.kind) {
                .int => u.slices.ints.deinit(gpa),
                .bytes => u.slices.bytes.deinit(gpa),
            }
        }
        f.seen_uids.clearRetainingCapacity();

        f.corpus.clearRetainingCapacity();
        f.corpus_pos = undefined;

        f.uid_data_i.clearRetainingCapacity();

        f.mmap_input.deinit();
        f.corpus_dir.close();
        f.start_corpus_dir = undefined;
    }

    pub fn setTest(f: *Fuzzer, test_one: abi.TestOne, unit_test_name: []const u8) void {
        f.test_one = test_one;
        f.corpus_dir = exec.cache_f.makeOpenPath(unit_test_name, .{}) catch |e|
            panic("failed to open directory '{s}': {t}", .{ unit_test_name, e });
        f.mmap_input = map: {
            const input = f.corpus_dir.createFile("in", .{
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

            var size = input.getEndPos() catch |e| panic("failed to stat input file 'in': {t}", .{e});
            if (size < std.heap.page_size_max) {
                size = std.heap.page_size_max;
                input.setEndPos(size) catch |e| panic("failed to resize input file 'in': {t}", .{e});
            }

            break :map MemoryMappedInput.init(input, size) catch |e|
                panic("failed to memmap input file 'in': {t}", .{e});
        };

        // Perform a dry-run of the stored input in case it might reproduce a crash.
        const len = mem.readInt(u32, @volatileCast(f.mmap_input.buffer[0..4]), .little);
        if (len < f.mmap_input.buffer[4..].len) {
            f.mmap_input.len = len;
            f.runBytes(f.mmap_input.constSlice(), .bytes_dry);
            f.mmap_input.clearRetainingCapacity();
        }
    }

    pub fn loadCorpus(f: *Fuzzer) void {
        f.corpus_pos = @enumFromInt(f.corpus.len);
        f.corpus.append(gpa, .none) catch @panic("OOM"); // Also ensures the corpus is not empty
        f.start_corpus_dir = @intCast(f.corpus.len);
        while (true) {
            var name_buf: [8]u8 = undefined;
            const name = f.corpusFileName(&name_buf, @enumFromInt(f.corpus.len));
            const bytes = f.corpus_dir.readFileAlloc(name, gpa, .unlimited) catch |e| switch (e) {
                error.FileNotFound => break,
                else => panic("failed to read corpus file '{s}': {t}", .{ name, e }),
            };
            defer gpa.free(bytes);
            f.newInput(bytes, false);
        }
        f.corpus_pos = @enumFromInt(0);
    }

    fn corpusFileName(f: *Fuzzer, buf: *[8]u8, i: Input.Index) []u8 {
        const dir_i = @intFromEnum(i) - f.start_corpus_dir;
        return std.fmt.bufPrint(buf, "{x}", .{dir_i}) catch unreachable;
    }

    fn rngInt(f: *Fuzzer, T: type) T {
        comptime assert(@bitSizeOf(T) <= 64);
        const Unsigned = std.meta.Int(.unsigned, @bitSizeOf(T));
        return @bitCast(@as(Unsigned, @truncate(f.xoshiro.next())));
    }

    fn rngLessThan(f: *Fuzzer, T: type, limit: T) T {
        return std.Random.limitRangeBiased(T, f.rngInt(T), limit);
    }

    /// Used for generating small values rather than making many calls into the prng.
    const SmallEntronopy = struct {
        bits: u64,

        pub fn take(e: *SmallEntronopy, T: type) T {
            defer e.bits >>= @bitSizeOf(T);
            return @truncate(e.bits);
        }
    };

    fn isFresh(f: *Fuzzer) bool {
        // Store as a bool instead of returning immediately to aid optimizations
        // by reducing branching since a fresh input is the unlikely case.
        var fresh: bool = false;

        var n_pcs: u32 = 0;
        var hit_pcs = exec.pcBitsetIterator();
        for (f.seen_pcs) |seen| {
            const hits = hit_pcs.next();
            fresh |= hits & ~seen != 0;
            n_pcs += @popCount(hits);
        }

        const quality: Input.Best.Quality = .{
            .n_pcs = n_pcs,
            .req = .{
                .values = f.req_values,
                .bytes = f.req_bytes,
            },
        };
        for (f.bests.quality_buf[0..f.bests.len]) |best| {
            if (exec.pc_counters[best.pc] == 0) continue;
            fresh |= quality.betterLess(best.min) | quality.betterMore(best.max);
        }

        return fresh;
    }

    fn runBytes(f: *Fuzzer, bytes: []const u8, mode: Input.Index) void {
        assert(mode == .bytes_dry or mode == .bytes_fresh);

        f.bytes_input = .{ .in = bytes };
        f.corpus_pos = mode;
        f.run(0); // 0 since `f.uid_data` is unused
    }

    fn updateSeenPcs(f: *Fuzzer) void {
        comptime assert(abi.SeenPcsHeader.trailing[0] == .pc_bits_usize);
        const shared_seen_pcs: [*]volatile usize = @ptrCast(
            exec.shared_seen_pcs[@sizeOf(abi.SeenPcsHeader)..].ptr,
        );

        var hit_pcs = exec.pcBitsetIterator();
        for (f.seen_pcs, shared_seen_pcs) |*seen, *shared_seen| {
            const new = hit_pcs.next() & ~seen.*;
            if (new != 0) {
                seen.* |= new;
                _ = @atomicRmw(usize, shared_seen, .Or, new, .monotonic);
            }
        }
    }

    fn removeBest(f: *Fuzzer, i: Input.Index, best_i: u32, modify_fs_corpus: bool) void {
        const ref = &f.corpus.items(.ref)[@intFromEnum(i)];
        const list_i = mem.indexOfScalar(u32, ref.best_i_buf[0..ref.best_i_len], best_i).?;
        ref.best_i_len -= 1;
        ref.best_i_buf[list_i] = ref.best_i_buf[ref.best_i_len];

        if (ref.best_i_len == 0 and @intFromEnum(i) >= f.start_corpus_dir and modify_fs_corpus) {
            // The input is no longer valuable, so remove it.
            var removed_input = f.corpus.get(@intFromEnum(i));
            for (
                removed_input.data.uid_slices.keys(),
                removed_input.data.uid_slices.values(),
                removed_input.seen_uid_i,
            ) |uid, slice, seen_uid_i| {
                switch (uid.kind) {
                    .int => {
                        const seen_ints = &f.seen_uids.values()[seen_uid_i].slices.ints;
                        const removed_ints = removed_input.data.ints[slice.base..][0..slice.len];
                        _ = seen_ints.swapRemove(for (0.., seen_ints.items) |idx, ints| {
                            if (removed_ints.ptr == ints.ptr) {
                                assert(removed_ints.len == ints.len);
                                break idx;
                            }
                        } else unreachable);
                    },
                    .bytes => {
                        const seen_bytes = &f.seen_uids.values()[seen_uid_i].slices.bytes;
                        const removed_bytes: Input.Data.Bytes = .{
                            .entries = removed_input.data.bytes.entries[slice.base..][0..slice.len],
                            .table = removed_input.data.bytes.table,
                        };
                        _ = seen_bytes.swapRemove(for (0.., seen_bytes.items) |idx, bytes| {
                            if (removed_bytes.entries.ptr == bytes.entries.ptr) {
                                assert(removed_bytes.entries.len == bytes.entries.len);
                                assert(removed_bytes.table.ptr == bytes.table.ptr);
                                assert(removed_bytes.table.len == bytes.table.len);
                                break idx;
                            }
                        } else unreachable);
                    },
                }
            }
            removed_input.deinit();
            f.corpus.swapRemove(@intFromEnum(i));

            var removed_name_buf: [8]u8 = undefined;
            const removed_name = f.corpusFileName(&removed_name_buf, i);

            if (@intFromEnum(i) == f.corpus.len) {
                f.corpus_dir.deleteFile(removed_name) catch |e| panic(
                    "failed to remove corpus file '{s}': {t}",
                    .{ removed_name, e },
                );
                return; // No item moved so no refs to update
            }

            var swapped_name_buf: [8]u8 = undefined;
            const swapped_name = f.corpusFileName(&swapped_name_buf, @enumFromInt(f.corpus.len));

            f.corpus_dir.rename(swapped_name, removed_name) catch |e| panic(
                "failed to rename corpus file '{s}' to '{s}': {t}",
                .{ swapped_name, removed_name, e },
            );

            // Update refrences. `ref` can be reused since it was a swap remove
            for (ref.best_i_buf[0..ref.best_i_len]) |update_pc_i| {
                const best = &f.bests.input_buf[update_pc_i];
                assert(@intFromEnum(best.min) == f.corpus.len or
                    @intFromEnum(best.max) == f.corpus.len);

                if (@intFromEnum(best.min) == f.corpus.len) best.min = i;
                if (@intFromEnum(best.max) == f.corpus.len) best.max = i;
            }
        }
    }

    pub fn newInput(f: *Fuzzer, bytes: []const u8, modify_fs_corpus: bool) void {
        f.runBytes(bytes, .bytes_fresh);
        f.req_values = f.input_builder.total_ints + f.input_builder.total_bytes;
        f.req_bytes = @intCast(f.input_builder.bytes_table.items.len);
        var input = f.input_builder.build();

        f.uid_data_i.ensureTotalCapacity(gpa, input.data.uid_slices.entries.len) catch @panic("OOM");
        for (
            input.seen_uid_i,
            input.data.uid_slices.keys(),
            input.data.uid_slices.values(),
        ) |*i, uid, slice| {
            const gop = f.seen_uids.getOrPutValue(gpa, uid, switch (uid.kind) {
                .int => .{ .slices = .{ .ints = .empty } },
                .bytes => .{ .slices = .{ .bytes = .empty } },
            }) catch @panic("OOM");
            switch (uid.kind) {
                .int => f.seen_uids.values()[gop.index].slices.ints.append(
                    gpa,
                    input.data.ints[slice.base..][0..slice.len],
                ) catch @panic("OOM"),
                .bytes => f.seen_uids.values()[gop.index].slices.bytes.append(gpa, .{
                    .entries = input.data.bytes.entries[slice.base..][0..slice.len],
                    .table = input.data.bytes.table,
                }) catch @panic("OOM"),
            }
            i.* = @intCast(gop.index);
        }

        const quality: Input.Best.Quality = .{
            .n_pcs = n_pcs: {
                @setRuntimeSafety(builtin.mode == .Debug); // Necessary for vectorization
                var n: u32 = 0;
                for (exec.pc_counters) |c| {
                    n += @intFromBool(c != 0);
                }
                break :n_pcs n;
            },
            .req = .{
                .values = f.req_values,
                .bytes = f.req_bytes,
            },
        };

        var best_i_list: std.ArrayList(u32) = .empty;
        for (0.., f.bests.quality_buf[0..f.bests.len]) |best_i, best| {
            if (exec.pc_counters[best.pc] == 0) continue;

            const better_min = quality.betterLess(best.min);
            const better_max = quality.betterMore(best.max);
            if (!better_min and !better_max) {
                @branchHint(.likely);
                continue;
            }
            best_i_list.append(gpa, @intCast(best_i)) catch @panic("OOM");

            const map = &f.bests.input_buf[best_i];
            if (map.min != map.max) {
                if (better_min) {
                    f.removeBest(map.min, @intCast(best_i), modify_fs_corpus);
                }
                if (better_max) {
                    f.removeBest(map.max, @intCast(best_i), modify_fs_corpus);
                }
            } else {
                if (better_min and better_max) {
                    f.removeBest(map.min, @intCast(best_i), modify_fs_corpus);
                }
            }
        }

        // Must come after the above since some inputs may be removed
        const input_i: Input.Index = @enumFromInt(f.corpus.len);
        if (input_i == Input.Index.reserved_start) {
            @panic("corpus size limit exceeded");
        }

        for (best_i_list.items) |i| {
            const best_qual = &f.bests.quality_buf[i];
            const best_map = &f.bests.input_buf[i];

            if (quality.betterLess(best_qual.min)) {
                best_qual.min = quality;
                best_map.min = input_i;
            }
            if (quality.betterMore(best_qual.max)) {
                best_qual.max = quality;
                best_map.max = input_i;
            }
        }

        for (0.., exec.pc_counters) |i, hits| {
            if (hits == 0) {
                @branchHint(.likely);
                continue;
            }

            if ((f.seen_pcs[i / @bitSizeOf(usize)] >> @intCast(i % @bitSizeOf(usize))) & 1 == 0) {
                @branchHint(.unlikely);
                best_i_list.append(gpa, f.bests.len) catch @panic("OOM");
                f.bests.quality_buf[f.bests.len] = .{
                    .pc = @intCast(i),
                    .min = quality,
                    .max = quality,
                };
                f.bests.input_buf[f.bests.len] = .{ .min = input_i, .max = input_i };
                f.bests.len += 1;
            }
        }

        if (best_i_list.items.len == 0 and
            modify_fs_corpus // Found by freshness; otherwise, it does not need to be better
        ) {
            @branchHint(.cold); // Nondeterministic test
            std.log.warn("nondeterministic rerun", .{});
            return;
        }

        input.ref.best_i_buf = best_i_list.toOwnedSlice(gpa) catch @panic("OOM");
        input.ref.best_i_len = @intCast(input.ref.best_i_buf.len);
        f.corpus.append(gpa, input) catch @panic("OOM");
        f.corpus_pos = input_i;

        // Must come after the above since `seen_pcs` is used
        f.updateSeenPcs();

        if (!modify_fs_corpus) return;

        // Write new input to cache
        var name_buf: [8]u8 = undefined;
        const name = f.corpusFileName(&name_buf, input_i);
        f.corpus_dir.writeFile(.{ .sub_path = name, .data = bytes }) catch |e|
            panic("failed to write corpus file '{s}': {t}", .{ name, e });
    }

    fn run(f: *Fuzzer, input_uids: usize) void {
        @memset(exec.pc_counters, 0);
        f.uid_data_i.items.len = input_uids;
        @memset(f.uid_data_i.items, 0);
        f.req_values = 0;
        f.req_bytes = 0;

        f.test_one();
        _ = @atomicRmw(usize, &exec.seenPcsHeader().n_runs, .Add, 1, .monotonic);
    }

    /// Returns a number of mutations to perform from 1-4
    /// with smaller values exponentially more likely.
    pub fn mutCount(rng: u16) u8 {
        // The below provides the following distribution
        // @clz(@clz(    range       mapped   percentage         ratio
        //          0 ->     0         -> 4  1 = 93.750%  (15 / 16   )
        //          1 ->     1 - 255   -> 3  2 =  5.859%  (15 / 256  )
        //          2 ->   256 - 4095  -> 2  3 =   .391%  (<1 / 256  )
        //          3 ->  4096 - 16383 -> 1  4 =   .002%  ( 1 / 65536)
        //          4 -> 16384 - 32767 -> 1
        //          5 -> 32768 - 65535 -> 1
        return @as(u8, 4) - @min(@clz(@clz(rng)), 3);
    }

    pub fn cycle(f: *Fuzzer) void {
        assert(f.mmap_input.len == 0);
        const corpus = f.corpus.slice();
        const corpus_i = @intFromEnum(f.corpus_pos);

        var small_entronopy: SmallEntronopy = .{ .bits = f.rngInt(u64) };
        var n_mutate = mutCount(small_entronopy.take(u16));
        const data = &corpus.items(.data)[corpus_i];
        const weighted_uid_slice_i = corpus.items(.weighted_uid_slice_i)[corpus_i];
        n_mutate *= @intFromBool(weighted_uid_slice_i.len != 0); // No static mutations on empty

        f.mut_data = .{
            .i = @splat(math.maxInt(u32)),
            .seq = @splat(.{
                .kind = .{
                    .class = undefined,
                    .copy = undefined,
                    .ordered_mutate = undefined,
                    .none = true,
                },
                .len = undefined,
                .copy = undefined,
            }),
        };

        const uid_slices = data.uid_slices.entries.slice();
        for (
            f.mut_data.i[0..n_mutate],
            f.mut_data.seq[0..n_mutate],
        ) |*i, *s| if ((data.order.len < 2) | (small_entronopy.take(u3) != 0)) {
            // Mutation on uid
            const uid_slice_wi = f.rngLessThan(u32, @intCast(weighted_uid_slice_i.len));
            const uid_slice_i = weighted_uid_slice_i[uid_slice_wi];

            const is_bytes = uid_slices.items(.key)[uid_slice_i].kind == .bytes;
            const data_slice = uid_slices.items(.value)[uid_slice_i];
            i.* = @as(u32, @intCast(data.ints.len)) * @intFromBool(is_bytes) +
                data_slice.base + f.rngLessThan(u32, data_slice.len);
        } else {
            // Sequence mutation on order
            const order_len: u32 = @intCast(data.order.len);
            const order_i = f.rngLessThan(u32, order_len - 1);
            s.* = .{
                .kind = .{
                    .class = .replace,
                    .copy = true,
                    .ordered_mutate = true,
                    .none = false,
                },
                .len = @min(@clz(f.rngInt(u16)) + 1, order_len - order_i),
                .copy = .{ .order_i = order_i },
            };
            i.* = data.order[order_i];
        };

        f.run(data.uid_slices.entries.len);
        if (f.isFresh()) {
            @branchHint(.unlikely);

            _ = @atomicRmw(usize, &exec.seenPcsHeader().unique_runs, .Add, 1, .monotonic);
            f.newInput(f.mmap_input.constSlice(), true);
        }
        f.mmap_input.clearRetainingCapacity();

        assert(@intFromEnum(f.corpus_pos) < f.corpus.len);
        f.corpus_pos = @enumFromInt((@intFromEnum(f.corpus_pos) + 1) % f.corpus.len);
    }

    fn weightsContain(int: u64, weights: []const abi.Weight) bool {
        var contains: bool = false;
        for (weights) |w| {
            contains |= w.min <= int and int <= w.max;
        }
        return contains;
    }

    fn weightsContainBytes(bytes: []const u8, weights: []const abi.Weight) bool {
        if (weights[0].min == 0 and weights[0].max == 0xff) {
            // Fast path: all bytes are valid
            return true;
        }

        var contains: bool = true;
        for (bytes) |b| {
            contains &= weightsContain(b, weights);
        }
        return contains;
    }

    fn sumWeightsInclusive(weights: []const abi.Weight) u64 {
        var sum: u64 = math.maxInt(u64);
        for (weights) |w| {
            sum +%= (w.max - w.min +% 1) *% w.weight;
        }
        return sum;
    }

    fn weightedValue(f: *Fuzzer, weights: []const abi.Weight, incl_sum: u64) u64 {
        var incl_n: u64 = f.rngInt(u64);
        const limit = incl_sum +% 1;
        if (limit != 0) incl_n = std.Random.limitRangeBiased(u64, incl_n, limit);

        for (weights) |w| {
            // (w.max - w.min + 1) * w.weight - 1
            const incl_vals = (w.max - w.min) * w.weight + (w.weight - 1);
            if (incl_n > incl_vals) {
                incl_n -= incl_vals + 1;
            } else {
                const val = w.min + incl_n / w.weight;
                assert(val <= w.max);
                return val;
            }
        } else unreachable;
    }

    const Untyped = union {
        int: u64,
        bytes: []u8,
    };

    fn nextUntyped(f: *Fuzzer, uid: Uid, weights: []const abi.Weight) union(enum) {
        copy: Untyped,
        mutate: Untyped,
        fresh: void,
    } {
        const corpus = f.corpus.slice();
        const corpus_i = @intFromEnum(f.corpus_pos);
        const data = &corpus.items(.data)[corpus_i];
        var small_entronopy: SmallEntronopy = .{ .bits = f.rngInt(u64) };

        const uid_i = data.uid_slices.getIndex(uid) orelse {
            @branchHint(.unlikely);
            return .fresh;
        };
        const data_slice = data.uid_slices.values()[uid_i];
        var slice_i = f.uid_data_i.items[uid_i];
        var data_i = data_slice.base + slice_i;

        new_data: while (true) {
            assert(slice_i == f.uid_data_i.items[uid_i] and data_i == data_slice.base + slice_i);
            if (slice_i == data_slice.len) break :new_data;
            assert(slice_i < data_slice.len);

            f.uid_data_i.items[uid_i] += 1;
            const mut_i = std.simd.firstIndexOfValue(
                @as(@Vector(4, u32), f.mut_data.i),
                data_i + @as(u32, @intCast(data.ints.len)) * @intFromEnum(uid.kind),
            ) orelse {
                @branchHint(.likely);
                switch (uid.kind) {
                    .int => {
                        const int = data.ints[data_i];
                        if (weightsContain(int, weights)) {
                            @branchHint(.likely);
                            return .{ .copy = .{ .int = int } };
                        }
                    },
                    .bytes => {
                        const entry = data.bytes.entries[data_i];
                        const bytes = data.bytes.table[entry.off..][0..entry.len];
                        if (weightsContainBytes(bytes, weights)) {
                            @branchHint(.likely);
                            return .{ .copy = .{ .bytes = bytes } };
                        }
                    },
                }
                break :new_data;
            };

            const seq = &f.mut_data.seq[mut_i];
            new_seq: {
                if (!seq.kind.none) break :new_seq;

                var opts: packed struct(u6) {
                    // Matches layout as `mut_data.seq.kind`
                    insert: bool,
                    copy: bool,

                    seq: u2,
                    delete: bool,
                    splice: bool,
                } = @bitCast(small_entronopy.take(u6));
                if (opts.seq != 0) break :new_data;

                const max_consume = data_slice.len - slice_i; // inclusive
                if (opts.delete) {
                    f.uid_data_i.items[uid_i] += f.rngLessThan(u32, max_consume);
                    slice_i = f.uid_data_i.items[uid_i];
                    data_i = data_slice.base + slice_i;
                    continue;
                }
                opts.insert |= max_consume == 0;
                seq.kind = .{
                    .class = if (opts.insert) .replace else .insert,
                    .copy = opts.copy,
                    .ordered_mutate = false,
                    .none = false,
                };

                if (!seq.kind.copy) {
                    seq.len = switch (seq.kind.class) {
                        .replace => f.rngLessThan(u32, max_consume) + 1,
                        .insert => @clz(f.rngInt(u16)) + 1,
                    };
                    seq.copy = undefined;
                } else {
                    const src: SeqCopy, const src_len: u32 = if (!opts.splice) .{
                        switch (uid.kind) {
                            .int => .{ .ints = data.ints[data_slice.base..][0..data_slice.len] },
                            .bytes => .{ .bytes = .{
                                .entries = data.bytes.entries[data_slice.base..][0..data_slice.len],
                                .table = data.bytes.table,
                            } },
                        },
                        data_slice.len,
                    } else src: {
                        const seen_uid_i = corpus.items(.seen_uid_i)[corpus_i][uid_i];
                        const untyped_slices = f.seen_uids.values()[seen_uid_i].slices;
                        switch (uid.kind) {
                            .int => {
                                const slices = untyped_slices.ints.items;
                                const i = f.rngLessThan(u32, @intCast(slices.len));
                                break :src .{
                                    .{ .ints = slices[i] },
                                    @intCast(slices[i].len),
                                };
                            },
                            .bytes => {
                                const slices = untyped_slices.bytes.items;
                                const i = f.rngLessThan(u32, @intCast(slices.len));
                                break :src .{
                                    .{ .bytes = slices[i] },
                                    @intCast(slices[i].entries.len),
                                };
                            },
                        }
                    };

                    const off = f.rngLessThan(u32, src_len);
                    seq.len = f.rngLessThan(u32, src_len - off) + 1;
                    if (seq.kind.class == .replace) seq.len = @min(seq.len, max_consume);
                    seq.copy = switch (uid.kind) {
                        .int => .{ .ints = src.ints[off..][0..seq.len] },
                        .bytes => .{ .bytes = .{
                            .entries = src.bytes.entries[off..][0..seq.len],
                            .table = src.bytes.table,
                        } },
                    };
                }
            }

            assert(!seq.kind.none);
            f.uid_data_i.items[uid_i] -= @intFromBool(seq.kind.class == .insert);
            seq.len -= 1;
            seq.kind.none |= seq.len == 0;
            f.mut_data.i[mut_i] += @intFromBool(seq.kind.class == .replace and seq.len != 0);

            if (!seq.kind.copy) {
                assert(!seq.kind.ordered_mutate);
                break :new_data;
            }
            if (seq.kind.ordered_mutate) {
                assert(seq.kind.class == .replace);
                seq.copy.order_i += @intFromBool(seq.len != 0);
                f.mut_data.i[mut_i] = data.order[seq.copy.order_i];
                break :new_data;
            }
            switch (uid.kind) {
                .int => {
                    const int = seq.copy.ints[0];
                    seq.copy.ints = seq.copy.ints[1..];
                    if (weightsContain(int, weights)) {
                        @branchHint(.likely);
                        return .{ .copy = .{ .int = int } };
                    }
                },
                .bytes => {
                    const entry = seq.copy.bytes.entries[0];
                    const bytes = seq.copy.bytes.table[entry.off..][0..entry.len];
                    seq.copy.bytes.entries = seq.copy.bytes.entries[1..];
                    if (weightsContainBytes(bytes, weights)) {
                        @branchHint(.likely);
                        return .{ .copy = .{ .bytes = bytes } };
                    }
                },
            }
            break;
        }

        const opts: packed struct(u10) {
            copy: u2,
            fresh: u2,
            splice: bool,
            local_far: bool,
            local_off: i4,
        } = @bitCast(small_entronopy.take(u10));

        if (opts.copy != 0) {
            if (opts.fresh == 0 or slice_i == data_slice.len) return .fresh;
            return .{ .mutate = switch (uid.kind) {
                .int => .{ .int = data.ints[data_i] },
                .bytes => .{ .bytes = b: {
                    const entry = data.bytes.entries[data_i];
                    break :b data.bytes.table[entry.off..][0..entry.len];
                } },
            } };
        }

        if (!opts.splice) {
            const src_data_i = data_slice.base + if (!opts.local_far) i: {
                const off = opts.local_off;
                break :i if (off >= 0) @min(
                    f.uid_data_i.items[uid_i] +| @as(u4, @intCast(off)),
                    data_slice.len - 1,
                ) else f.uid_data_i.items[uid_i] -| @abs(off);
            } else f.rngLessThan(u32, data_slice.len);
            switch (uid.kind) {
                .int => {
                    const int = data.ints[src_data_i];
                    if (weightsContain(int, weights)) {
                        @branchHint(.likely);
                        return .{ .copy = .{ .int = int } };
                    }
                },
                .bytes => {
                    const entry = data.bytes.entries[src_data_i];
                    const bytes = data.bytes.table[entry.off..][0..entry.len];
                    if (weightsContainBytes(bytes, weights)) {
                        @branchHint(.likely);
                        return .{ .copy = .{ .bytes = bytes } };
                    }
                },
            }
        } else {
            const seen_uid_i = corpus.items(.seen_uid_i)[corpus_i][uid_i];
            const untyped_slices = f.seen_uids.values()[seen_uid_i].slices;
            switch (uid.kind) {
                .int => {
                    const slices = untyped_slices.ints.items;
                    const from = slices[f.rngLessThan(u32, @intCast(slices.len))];
                    const int = from[f.rngLessThan(u32, @intCast(from.len))];
                    if (weightsContain(int, weights)) {
                        @branchHint(.likely);
                        return .{ .copy = .{ .int = int } };
                    }
                },
                .bytes => {
                    const slices = untyped_slices.bytes.items;
                    const from = slices[f.rngLessThan(u32, @intCast(slices.len))];
                    const entry_i = f.rngLessThan(u32, @intCast(from.entries.len));
                    const entry = from.entries[entry_i];
                    const bytes = from.table[entry.off..][0..entry.len];
                    if (weightsContainBytes(bytes, weights)) {
                        @branchHint(.likely);
                        return .{ .copy = .{ .bytes = bytes } };
                    }
                },
            }
        }
        return .fresh;
    }

    pub fn nextInt(f: *Fuzzer, uid: Uid, weights: []const abi.Weight) u64 {
        f.req_values += 1;
        if (@intFromEnum(f.corpus_pos) >= @intFromEnum(Input.Index.reserved_start)) {
            @branchHint(.unlikely);
            const int = f.bytes_input.valueWeightedWithHash(u64, weights, undefined);
            if (f.corpus_pos == .bytes_fresh) {
                f.input_builder.checkSmithedLen(8);
                f.input_builder.addInt(uid, int);
            }
            return int;
        }
        const int = f.nextIntInner(uid, weights);
        f.mmap_input.appendLittleInt(u64, int);
        return int;
    }

    fn nextIntInner(f: *Fuzzer, uid: Uid, weights: []const abi.Weight) u64 {
        return switch (f.nextUntyped(uid, weights)) {
            .copy => |u| u.int,
            .mutate, .fresh => f.weightedValue(weights, sumWeightsInclusive(weights)),
        };
    }

    pub fn nextEos(f: *Fuzzer, uid: Uid, weights: []const abi.Weight) bool {
        f.req_values += 1;
        if (@intFromEnum(f.corpus_pos) >= @intFromEnum(Input.Index.reserved_start)) {
            @branchHint(.unlikely);
            const eos = f.bytes_input.eosWeightedWithHash(weights, undefined);
            if (f.corpus_pos == .bytes_fresh) {
                f.input_builder.checkSmithedLen(1);
                f.input_builder.addInt(uid, @intFromBool(eos));
            }
            return eos;
        }
        // `nextIntInner` is already gauraunteed to eventually return `1`
        const eos = @as(u1, @intCast(f.nextIntInner(uid, weights))) != 0;
        f.mmap_input.appendLittleInt(u8, @intFromBool(eos));
        return eos;
    }

    fn mutateBytes(f: *Fuzzer, in: []u8, out: []u8, weights: []const abi.Weight) void {
        assert(in.len != 0);
        const weights_incl_sum = sumWeightsInclusive(weights);

        var small_entronopy: SmallEntronopy = .{ .bits = f.rngInt(u64) };
        var muts = mutCount(small_entronopy.take(u16));
        var rem_out = out;
        var rem_copy = in;
        while (rem_out.len != 0 and muts != 0) {
            muts -= 1;
            const opts: packed struct(u4) {
                kind: enum(u2) {
                    random,
                    stream_copy,
                    stream_discard,
                    absolute_copy,
                },
                small: u2,

                pub fn limitSmall(o: @This(), n: usize) u32 {
                    return @min(
                        @as(u32, @intCast(n)),
                        @as(u32, if (o.small != 0) 8 else math.maxInt(u32)),
                    );
                }
            } = @bitCast(small_entronopy.take(u4));
            s: switch (opts.kind) {
                .random => {
                    const n = f.rngLessThan(u32, opts.limitSmall(rem_out.len)) + 1;
                    for (rem_out[0..n]) |*o| {
                        o.* = @intCast(f.weightedValue(weights, weights_incl_sum));
                    }
                    rem_out = rem_out[n..];
                },
                .stream_copy => {
                    if (rem_copy.len == 0) continue :s .random;
                    const n = @min(
                        f.rngLessThan(u32, opts.limitSmall(rem_copy.len)) + 1,
                        rem_out.len,
                    );
                    @memcpy(rem_out[0..n], rem_copy[0..n]);
                    rem_out = rem_out[n..];
                    rem_copy = rem_copy[n..];
                },
                .stream_discard => {
                    if (rem_copy.len == 0) continue :s .random;
                    const n = f.rngLessThan(u32, opts.limitSmall(rem_copy.len)) + 1;
                    rem_copy = rem_copy[n..];
                },
                .absolute_copy => {
                    const in_len: u32 = @intCast(in.len);
                    const off = f.rngLessThan(u32, in_len);
                    const len = @min(
                        f.rngLessThan(u32, in_len - off) + 1,
                        opts.limitSmall(rem_out.len),
                    );
                    @memcpy(rem_out[0..len], in[off..][0..len]);
                    rem_out = rem_out[len..];
                },
            }
        }

        const copy = @min(rem_out.len, rem_copy.len);
        @memcpy(rem_out[0..copy], rem_copy[0..copy]);
        for (rem_out[copy..]) |*o| {
            o.* = @intCast(f.weightedValue(weights, weights_incl_sum));
        }
    }

    fn nextBytesInner(f: *Fuzzer, uid: Uid, out: []u8, weights: []const abi.Weight) void {
        so: switch (f.nextUntyped(uid, weights)) {
            .copy => |u| {
                if (u.bytes.len >= out.len) {
                    @branchHint(.likely);
                    @memcpy(out, u.bytes[0..out.len]);
                    return;
                }

                @memcpy(out[0..u.bytes.len], u.bytes);
                const weights_incl_sum = sumWeightsInclusive(weights);
                for (out[u.bytes.len..]) |*o| {
                    o.* = @intCast(f.weightedValue(weights, weights_incl_sum));
                }
            },
            .mutate => |u| {
                if (u.bytes.len == 0) continue :so .fresh;
                f.mutateBytes(u.bytes, out, weights);
            },
            .fresh => {
                const weights_incl_sum = sumWeightsInclusive(weights);
                for (out) |*o| {
                    o.* = @intCast(f.weightedValue(weights, weights_incl_sum));
                }
            },
        }
    }

    pub fn nextBytes(f: *Fuzzer, uid: Uid, out: []u8, weights: []const abi.Weight) void {
        f.req_values += 1;
        f.req_bytes +%= @truncate(out.len); // This function should panic since the 32-bit
        // data limit is exceeded, so wrapping is fine.
        if (@intFromEnum(f.corpus_pos) >= @intFromEnum(Input.Index.reserved_start)) {
            @branchHint(.unlikely);
            f.bytes_input.bytesWeightedWithHash(out, weights, undefined);
            if (f.corpus_pos == .bytes_fresh) {
                f.input_builder.checkSmithedLen(out.len);
                f.input_builder.addBytes(uid, out);
            }
            return;
        }

        f.nextBytesInner(uid, out, weights);
        f.mmap_input.appendSlice(out);
    }

    fn nextSliceInner(
        f: *Fuzzer,
        uid: Uid,
        buf: []u8,
        len_weights: []const abi.Weight,
        byte_weights: []const abi.Weight,
    ) u32 {
        so: switch (f.nextUntyped(uid, byte_weights)) {
            .copy => |u| {
                var len: u32 = @intCast(u.bytes.len);
                if (!weightsContain(len, len_weights)) {
                    @branchHint(.unlikely);
                    len = @intCast(f.weightedValue(len_weights, sumWeightsInclusive(len_weights)));
                }

                if (u.bytes.len >= len) {
                    @branchHint(.likely);
                    @memcpy(buf[0..len], u.bytes[0..len]);
                    return len;
                }

                @memcpy(buf[0..u.bytes.len], u.bytes);
                const weights_incl_sum = sumWeightsInclusive(byte_weights);
                for (buf[u.bytes.len..len]) |*o| {
                    o.* = @intCast(f.weightedValue(byte_weights, weights_incl_sum));
                }
                return len;
            },
            .mutate => |u| {
                if (u.bytes.len == 0) continue :so .fresh;
                const len: u32 = len: {
                    const offseted: packed struct {
                        is: u3,
                        sub: bool,
                        by: u3,
                    } = @bitCast(f.rngInt(u7));
                    if (offseted.is != 0) {
                        const len = if (offseted.sub)
                            @as(u32, @intCast(u.bytes.len)) -| offseted.by
                        else
                            @min(u.bytes.len + offseted.by, @as(u32, @intCast(buf.len)));
                        if (weightsContain(len, len_weights)) {
                            break :len len;
                        }
                    }
                    break :len @intCast(f.weightedValue(
                        len_weights,
                        sumWeightsInclusive(len_weights),
                    ));
                };
                f.mutateBytes(u.bytes, buf[0..len], byte_weights);
                return len;
            },
            .fresh => {
                const len: u32 = @intCast(f.weightedValue(
                    len_weights,
                    sumWeightsInclusive(len_weights),
                ));
                const weights_incl_sum = sumWeightsInclusive(byte_weights);
                for (buf[0..len]) |*o| {
                    o.* = @intCast(f.weightedValue(byte_weights, weights_incl_sum));
                }
                return len;
            },
        }
    }

    pub fn nextSlice(
        f: *Fuzzer,
        uid: Uid,
        buf: []u8,
        len_weights: []const abi.Weight,
        byte_weights: []const abi.Weight,
    ) u32 {
        f.req_values += 1;
        if (@intFromEnum(f.corpus_pos) >= @intFromEnum(Input.Index.reserved_start)) {
            @branchHint(.unlikely);
            const n = f.bytes_input.sliceWeightedWithHash(
                buf,
                len_weights,
                byte_weights,
                undefined,
            );
            if (f.corpus_pos == .bytes_fresh) {
                f.input_builder.checkSmithedLen(@as(usize, 4) + n);
                f.input_builder.addBytes(uid, buf[0..n]);
            }
            return n;
        }

        const n = f.nextSliceInner(uid, buf, len_weights, byte_weights);
        f.mmap_input.appendLittleInt(u32, n);
        f.mmap_input.appendSlice(buf[0..n]);
        f.req_bytes += n;
        return n;
    }
};

export fn fuzzer_init(cache_dir_path: abi.Slice) void {
    exec = .init(cache_dir_path.toSlice());
    fuzzer = .init();
}

export fn fuzzer_coverage() abi.Coverage {
    const coverage_id = exec.pc_digest;
    const header = @volatileCast(exec.seenPcsHeader());

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

export fn fuzzer_set_test(test_one: abi.TestOne, unit_test_name: abi.Slice) void {
    current_test_name = unit_test_name.toSlice();
    fuzzer.setTest(test_one, unit_test_name.toSlice());
}

export fn fuzzer_new_input(bytes: abi.Slice) void {
    if (bytes.len == 0) return; // An entry of length zero is always present
    fuzzer.newInput(bytes.toSlice(), false);
}

export fn fuzzer_main(limit_kind: abi.LimitKind, amount: u64) void {
    fuzzer.loadCorpus();
    switch (limit_kind) {
        .forever => while (true) fuzzer.cycle(),
        .iterations => for (0..amount) |_| fuzzer.cycle(),
    }
    fuzzer.reset();
}

export fn fuzzer_int(uid: Uid, weights: abi.Weights) u64 {
    assert(uid.kind == .int);
    return fuzzer.nextInt(uid, weights.toSlice());
}

export fn fuzzer_eos(uid: Uid, weights: abi.Weights) bool {
    assert(uid.kind == .int);
    return fuzzer.nextEos(uid, weights.toSlice());
}

export fn fuzzer_bytes(uid: Uid, out: abi.MutSlice, weights: abi.Weights) void {
    assert(uid.kind == .bytes);
    return fuzzer.nextBytes(uid, out.toSlice(), weights.toSlice());
}

export fn fuzzer_slice(
    uid: Uid,
    buf: abi.MutSlice,
    len_weights: abi.Weights,
    byte_weights: abi.Weights,
) u32 {
    assert(uid.kind == .bytes);
    return fuzzer.nextSlice(uid, buf.toSlice(), len_weights.toSlice(), byte_weights.toSlice());
}

/// Helps determine run uniqueness in the face of recursion.
/// Currently not used by the fuzzer.
export threadlocal var __sancov_lowest_stack: usize = 0;

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

fn fileMap(
    f: std.fs.File,
    size: usize,
) std.posix.MMapError![]align(std.heap.page_size_min) volatile u8 {
    return std.posix.mmap(
        null,
        size,
        std.posix.PROT.READ | std.posix.PROT.WRITE,
        .{ .TYPE = .SHARED },
        f.handle,
        0,
    );
}

fn fileUnmap(buf: []align(std.heap.page_size_min) volatile u8) void {
    std.posix.munmap(@volatileCast(buf));
}

/// Reusable and recoverable input.
///
/// Has a 32-bit limit on the input length. This has the side
/// effect that `u32` can be used in most placed in `fuzzer`
/// with the last four values reserved.
const MemoryMappedInput = struct {
    /// Memory-mapped file contents containing the input.
    ///
    /// Starts with the length of the input as a little-endian 32-bit value.
    buffer: []align(std.heap.page_size_min) volatile u8,
    len: u32,
    /// The file backing `buffer`, kept so it can be resized if necessary.
    file: std.fs.File,

    pub fn init(file: std.fs.File, size: usize) !MemoryMappedInput {
        assert(size >= std.heap.page_size_max);
        return .{
            .buffer = try fileMap(file, size),
            .len = 0,
            .file = file,
        };
    }

    pub fn deinit(l: *MemoryMappedInput) void {
        fileUnmap(l.buffer);
        l.file.close();
        l.* = undefined;
    }

    /// Modify the array so that it can hold at least `additional_count` **more** items.
    ///
    /// Invalidates element pointers if additional memory is needed.
    pub fn ensureUnusedCapacity(l: *MemoryMappedInput, additional_count: usize) void {
        return l.ensureTotalCapacity(4 + l.len + additional_count);
    }

    /// If the current capacity is less than `min_capacity`, this function will
    /// modify the array so that it can hold at least `min_capacity` items.
    ///
    /// Invalidates element pointers if additional memory is needed.
    pub fn ensureTotalCapacity(l: *MemoryMappedInput, min_capacity: usize) void {
        if (l.buffer.len < min_capacity) {
            @branchHint(.unlikely);
            const max_capacity = 1 << 32; // The size of the length header is not added
            // in order to keep the capacity page aligned and to allow those values to
            // reserved for other places.
            if (min_capacity > max_capacity) @panic("too much smith data requested");
            const new_capacity = @min(growCapacity(min_capacity), max_capacity);
            fileUnmap(l.buffer);
            l.file.setEndPos(new_capacity) catch |e|
                panic("failed to resize input file 'in': {t}", .{e});
            l.buffer = fileMap(l.file, new_capacity) catch |e|
                panic("failed to memmap input file 'in': {t}", .{e});
        }
    }

    fn updateLen(l: *MemoryMappedInput, new: u32) void {
        l.len = new;
        l.buffer[0..4].* = @bitCast(mem.nativeToLittle(u32, l.len));
    }

    pub fn constSlice(l: *MemoryMappedInput) []const u8 {
        // Only writing has side effects, so `@volatileCast` is safe.
        return @volatileCast(l.buffer[4..][0..l.len]);
    }

    /// Invalidates all element pointers.
    pub fn clearRetainingCapacity(l: *MemoryMappedInput) void {
        l.updateLen(0);
    }

    /// Append the slice of items to the list.
    ///
    /// Invalidates item pointers if more space is required.
    pub fn appendSlice(l: *MemoryMappedInput, items: []const u8) void {
        l.ensureUnusedCapacity(items.len);
        @memcpy(l.buffer[4..][l.len..][0..items.len], items);
        l.updateLen(l.len + @as(u32, @intCast(items.len)));
    }

    /// Append the little-endian integer to the list.
    ///
    /// Invalidates item pointers if more space is required.
    pub fn appendLittleInt(l: *MemoryMappedInput, T: type, x: T) void {
        l.ensureUnusedCapacity(@sizeOf(T));
        l.buffer[4..][l.len..][0..@sizeOf(T)].* = @bitCast(mem.nativeToLittle(T, x));
        l.updateLen(l.len + @sizeOf(T));
    }

    /// Called when memory growth is necessary. Returns a capacity larger than
    /// minimum that grows super-linearly.
    fn growCapacity(minimum: usize) usize {
        return mem.alignForward(
            usize,
            minimum +| (minimum / 2 + std.heap.page_size_max),
            std.heap.page_size_max,
        );
    }
};
