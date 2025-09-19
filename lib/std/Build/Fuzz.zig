const std = @import("../std.zig");
const Build = std.Build;
const Cache = Build.Cache;
const Step = std.Build.Step;
const assert = std.debug.assert;
const fatal = std.process.fatal;
const Allocator = std.mem.Allocator;
const log = std.log;
const Coverage = std.debug.Coverage;
const abi = Build.abi.fuzz;

const Fuzz = @This();
const build_runner = @import("root");

ws: *Build.WebServer,

/// Allocated into `ws.gpa`.
run_steps: []const *Step.Run,

wait_group: std.Thread.WaitGroup,
prog_node: std.Progress.Node,

/// Protects `coverage_files`.
coverage_mutex: std.Thread.Mutex,
coverage_files: std.AutoArrayHashMapUnmanaged(u64, CoverageMap),

queue_mutex: std.Thread.Mutex,
queue_cond: std.Thread.Condition,
msg_queue: std.ArrayListUnmanaged(Msg),

const Msg = union(enum) {
    coverage: struct {
        id: u64,
        run: *Step.Run,
    },
    entry_point: struct {
        coverage_id: u64,
        addr: u64,
    },
};

const CoverageMap = struct {
    mapped_memory: []align(std.heap.page_size_min) const u8,
    coverage: Coverage,
    source_locations: []Coverage.SourceLocation,
    /// Elements are indexes into `source_locations` pointing to the unit tests that are being fuzz tested.
    entry_points: std.ArrayListUnmanaged(u32),
    start_timestamp: i64,

    fn deinit(cm: *CoverageMap, gpa: Allocator) void {
        std.posix.munmap(cm.mapped_memory);
        cm.coverage.deinit(gpa);
        cm.* = undefined;
    }
};

pub fn init(ws: *Build.WebServer) Allocator.Error!Fuzz {
    const gpa = ws.gpa;

    const run_steps: []const *Step.Run = steps: {
        var steps: std.ArrayListUnmanaged(*Step.Run) = .empty;
        defer steps.deinit(gpa);
        const rebuild_node = ws.root_prog_node.start("Rebuilding Unit Tests", 0);
        defer rebuild_node.end();
        var rebuild_wg: std.Thread.WaitGroup = .{};
        defer rebuild_wg.wait();

        for (ws.all_steps) |step| {
            const run = step.cast(Step.Run) orelse continue;
            if (run.producer == null) continue;
            if (run.fuzz_tests.items.len == 0) continue;
            try steps.append(gpa, run);
            ws.thread_pool.spawnWg(&rebuild_wg, rebuildTestsWorkerRun, .{ run, gpa, ws.ttyconf, rebuild_node });
        }

        if (steps.items.len == 0) fatal("no fuzz tests found", .{});
        rebuild_node.setEstimatedTotalItems(steps.items.len);
        break :steps try gpa.dupe(*Step.Run, steps.items);
    };
    errdefer gpa.free(run_steps);

    for (run_steps) |run| {
        assert(run.fuzz_tests.items.len > 0);
        if (run.rebuilt_executable == null)
            fatal("one or more unit tests failed to be rebuilt in fuzz mode", .{});
    }

    return .{
        .ws = ws,
        .run_steps = run_steps,
        .wait_group = .{},
        .prog_node = .none,
        .coverage_files = .empty,
        .coverage_mutex = .{},
        .queue_mutex = .{},
        .queue_cond = .{},
        .msg_queue = .empty,
    };
}

pub fn start(fuzz: *Fuzz) void {
    const ws = fuzz.ws;
    fuzz.prog_node = ws.root_prog_node.start("Fuzzing", fuzz.run_steps.len);

    // For polling messages and sending updates to subscribers.
    fuzz.wait_group.start();
    _ = std.Thread.spawn(.{}, coverageRun, .{fuzz}) catch |err| {
        fuzz.wait_group.finish();
        fatal("unable to spawn coverage thread: {s}", .{@errorName(err)});
    };

    for (fuzz.run_steps) |run| {
        for (run.fuzz_tests.items) |unit_test_index| {
            assert(run.rebuilt_executable != null);
            ws.thread_pool.spawnWg(&fuzz.wait_group, fuzzWorkerRun, .{
                fuzz, run, unit_test_index,
            });
        }
    }
}
pub fn deinit(fuzz: *Fuzz) void {
    if (true) @panic("TODO: terminate the fuzzer processes");
    fuzz.wait_group.wait();
    fuzz.prog_node.end();

    const gpa = fuzz.ws.gpa;
    gpa.free(fuzz.run_steps);
}

fn rebuildTestsWorkerRun(run: *Step.Run, gpa: Allocator, ttyconf: std.Io.tty.Config, parent_prog_node: std.Progress.Node) void {
    rebuildTestsWorkerRunFallible(run, gpa, ttyconf, parent_prog_node) catch |err| {
        const compile = run.producer.?;
        log.err("step '{s}': failed to rebuild in fuzz mode: {s}", .{
            compile.step.name, @errorName(err),
        });
    };
}

fn rebuildTestsWorkerRunFallible(run: *Step.Run, gpa: Allocator, ttyconf: std.Io.tty.Config, parent_prog_node: std.Progress.Node) !void {
    const compile = run.producer.?;
    const prog_node = parent_prog_node.start(compile.step.name, 0);
    defer prog_node.end();

    const result = compile.rebuildInFuzzMode(gpa, prog_node);

    const show_compile_errors = compile.step.result_error_bundle.errorMessageCount() > 0;
    const show_error_msgs = compile.step.result_error_msgs.items.len > 0;
    const show_stderr = compile.step.result_stderr.len > 0;

    if (show_error_msgs or show_compile_errors or show_stderr) {
        var buf: [256]u8 = undefined;
        const w = std.debug.lockStderrWriter(&buf);
        defer std.debug.unlockStderrWriter();
        build_runner.printErrorMessages(gpa, &compile.step, .{ .ttyconf = ttyconf }, w, false) catch {};
    }

    const rebuilt_bin_path = result catch |err| switch (err) {
        error.MakeFailed => return,
        else => |other| return other,
    };
    run.rebuilt_executable = try rebuilt_bin_path.join(gpa, compile.out_filename);
}

fn fuzzWorkerRun(
    fuzz: *Fuzz,
    run: *Step.Run,
    unit_test_index: u32,
) void {
    const gpa = run.step.owner.allocator;
    const test_name = run.cached_test_metadata.?.testName(unit_test_index);

    const prog_node = fuzz.prog_node.start(test_name, 0);
    defer prog_node.end();

    run.rerunInFuzzMode(fuzz, unit_test_index, prog_node) catch |err| switch (err) {
        error.MakeFailed => {
            var buf: [256]u8 = undefined;
            const w = std.debug.lockStderrWriter(&buf);
            defer std.debug.unlockStderrWriter();
            build_runner.printErrorMessages(gpa, &run.step, .{ .ttyconf = fuzz.ws.ttyconf }, w, false) catch {};
            return;
        },
        else => {
            log.err("step '{s}': failed to rerun '{s}' in fuzz mode: {s}", .{
                run.step.name, test_name, @errorName(err),
            });
            return;
        },
    };
}

pub fn serveSourcesTar(fuzz: *Fuzz, req: *std.http.Server.Request) !void {
    const gpa = fuzz.ws.gpa;

    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const DedupTable = std.ArrayHashMapUnmanaged(Build.Cache.Path, void, Build.Cache.Path.TableAdapter, false);
    var dedup_table: DedupTable = .empty;
    defer dedup_table.deinit(gpa);

    for (fuzz.run_steps) |run_step| {
        const compile_inputs = run_step.producer.?.step.inputs.table;
        for (compile_inputs.keys(), compile_inputs.values()) |dir_path, *file_list| {
            try dedup_table.ensureUnusedCapacity(gpa, file_list.items.len);
            for (file_list.items) |sub_path| {
                if (!std.mem.endsWith(u8, sub_path, ".zig")) continue;
                const joined_path = try dir_path.join(arena, sub_path);
                dedup_table.putAssumeCapacity(joined_path, {});
            }
        }
    }

    const deduped_paths = dedup_table.keys();
    const SortContext = struct {
        pub fn lessThan(this: @This(), lhs: Build.Cache.Path, rhs: Build.Cache.Path) bool {
            _ = this;
            return switch (std.mem.order(u8, lhs.root_dir.path orelse ".", rhs.root_dir.path orelse ".")) {
                .lt => true,
                .gt => false,
                .eq => std.mem.lessThan(u8, lhs.sub_path, rhs.sub_path),
            };
        }
    };
    std.mem.sortUnstable(Build.Cache.Path, deduped_paths, SortContext{}, SortContext.lessThan);
    return fuzz.ws.serveTarFile(req, deduped_paths);
}

pub const Previous = struct {
    unique_runs: usize,
    entry_points: usize,
    pub const init: Previous = .{ .unique_runs = 0, .entry_points = 0 };
};
pub fn sendUpdate(
    fuzz: *Fuzz,
    socket: *std.http.Server.WebSocket,
    prev: *Previous,
) !void {
    fuzz.coverage_mutex.lock();
    defer fuzz.coverage_mutex.unlock();

    const coverage_maps = fuzz.coverage_files.values();
    if (coverage_maps.len == 0) return;
    // TODO: handle multiple fuzz steps in the WebSocket packets
    const coverage_map = &coverage_maps[0];
    const cov_header: *const abi.SeenPcsHeader = @ptrCast(coverage_map.mapped_memory[0..@sizeOf(abi.SeenPcsHeader)]);
    // TODO: this isn't sound! We need to do volatile reads of these bits rather than handing the
    // buffer off to the kernel, because we might race with the fuzzer process[es]. This brings the
    // whole mmap strategy into question. Incidentally, I wonder if post-writergate we could pass
    // this data straight to the socket with sendfile...
    const seen_pcs = cov_header.seenBits();
    const n_runs = @atomicLoad(usize, &cov_header.n_runs, .monotonic);
    const unique_runs = @atomicLoad(usize, &cov_header.unique_runs, .monotonic);
    {
        if (unique_runs != 0 and prev.unique_runs == 0) {
            // We need to send initial context.
            const header: abi.SourceIndexHeader = .{
                .directories_len = @intCast(coverage_map.coverage.directories.entries.len),
                .files_len = @intCast(coverage_map.coverage.files.entries.len),
                .source_locations_len = @intCast(coverage_map.source_locations.len),
                .string_bytes_len = @intCast(coverage_map.coverage.string_bytes.items.len),
                .start_timestamp = coverage_map.start_timestamp,
            };
            var iovecs: [5][]const u8 = .{
                @ptrCast(&header),
                @ptrCast(coverage_map.coverage.directories.keys()),
                @ptrCast(coverage_map.coverage.files.keys()),
                @ptrCast(coverage_map.source_locations),
                coverage_map.coverage.string_bytes.items,
            };
            try socket.writeMessageVec(&iovecs, .binary);
        }

        const header: abi.CoverageUpdateHeader = .{
            .n_runs = n_runs,
            .unique_runs = unique_runs,
        };
        var iovecs: [2][]const u8 = .{
            @ptrCast(&header),
            @ptrCast(seen_pcs),
        };
        try socket.writeMessageVec(&iovecs, .binary);

        prev.unique_runs = unique_runs;
    }

    if (prev.entry_points != coverage_map.entry_points.items.len) {
        const header: abi.EntryPointHeader = .init(@intCast(coverage_map.entry_points.items.len));
        var iovecs: [2][]const u8 = .{
            @ptrCast(&header),
            @ptrCast(coverage_map.entry_points.items),
        };
        try socket.writeMessageVec(&iovecs, .binary);

        prev.entry_points = coverage_map.entry_points.items.len;
    }
}

fn coverageRun(fuzz: *Fuzz) void {
    defer fuzz.wait_group.finish();

    fuzz.queue_mutex.lock();
    defer fuzz.queue_mutex.unlock();

    while (true) {
        fuzz.queue_cond.wait(&fuzz.queue_mutex);
        for (fuzz.msg_queue.items) |msg| switch (msg) {
            .coverage => |coverage| prepareTables(fuzz, coverage.run, coverage.id) catch |err| switch (err) {
                error.AlreadyReported => continue,
                else => |e| log.err("failed to prepare code coverage tables: {s}", .{@errorName(e)}),
            },
            .entry_point => |entry_point| addEntryPoint(fuzz, entry_point.coverage_id, entry_point.addr) catch |err| switch (err) {
                error.AlreadyReported => continue,
                else => |e| log.err("failed to prepare code coverage tables: {s}", .{@errorName(e)}),
            },
        };
        fuzz.msg_queue.clearRetainingCapacity();
    }
}
fn prepareTables(fuzz: *Fuzz, run_step: *Step.Run, coverage_id: u64) error{ OutOfMemory, AlreadyReported }!void {
    const ws = fuzz.ws;
    const gpa = ws.gpa;

    fuzz.coverage_mutex.lock();
    defer fuzz.coverage_mutex.unlock();

    const gop = try fuzz.coverage_files.getOrPut(gpa, coverage_id);
    if (gop.found_existing) {
        // We are fuzzing the same executable with multiple threads.
        // Perhaps the same unit test; perhaps a different one. In any
        // case, since the coverage file is the same, we only have to
        // notice changes to that one file in order to learn coverage for
        // this particular executable.
        return;
    }
    errdefer _ = fuzz.coverage_files.pop();

    gop.value_ptr.* = .{
        .coverage = std.debug.Coverage.init,
        .mapped_memory = undefined, // populated below
        .source_locations = undefined, // populated below
        .entry_points = .{},
        .start_timestamp = ws.now(),
    };
    errdefer gop.value_ptr.coverage.deinit(gpa);

    const rebuilt_exe_path = run_step.rebuilt_executable.?;
    var debug_info = std.debug.Info.load(gpa, rebuilt_exe_path, &gop.value_ptr.coverage) catch |err| {
        log.err("step '{s}': failed to load debug information for '{f}': {s}", .{
            run_step.step.name, rebuilt_exe_path, @errorName(err),
        });
        return error.AlreadyReported;
    };
    defer debug_info.deinit(gpa);

    const coverage_file_path: Build.Cache.Path = .{
        .root_dir = run_step.step.owner.cache_root,
        .sub_path = "v/" ++ std.fmt.hex(coverage_id),
    };
    var coverage_file = coverage_file_path.root_dir.handle.openFile(coverage_file_path.sub_path, .{}) catch |err| {
        log.err("step '{s}': failed to load coverage file '{f}': {s}", .{
            run_step.step.name, coverage_file_path, @errorName(err),
        });
        return error.AlreadyReported;
    };
    defer coverage_file.close();

    const file_size = coverage_file.getEndPos() catch |err| {
        log.err("unable to check len of coverage file '{f}': {s}", .{ coverage_file_path, @errorName(err) });
        return error.AlreadyReported;
    };

    const mapped_memory = std.posix.mmap(
        null,
        file_size,
        std.posix.PROT.READ,
        .{ .TYPE = .SHARED },
        coverage_file.handle,
        0,
    ) catch |err| {
        log.err("failed to map coverage file '{f}': {s}", .{ coverage_file_path, @errorName(err) });
        return error.AlreadyReported;
    };
    gop.value_ptr.mapped_memory = mapped_memory;

    const header: *const abi.SeenPcsHeader = @ptrCast(mapped_memory[0..@sizeOf(abi.SeenPcsHeader)]);
    const pcs = header.pcAddrs();
    const source_locations = try gpa.alloc(Coverage.SourceLocation, pcs.len);
    errdefer gpa.free(source_locations);

    // Unfortunately the PCs array that LLVM gives us from the 8-bit PC
    // counters feature is not sorted.
    var sorted_pcs: std.MultiArrayList(struct { pc: u64, index: u32, sl: Coverage.SourceLocation }) = .{};
    defer sorted_pcs.deinit(gpa);
    try sorted_pcs.resize(gpa, pcs.len);
    @memcpy(sorted_pcs.items(.pc), pcs);
    for (sorted_pcs.items(.index), 0..) |*v, i| v.* = @intCast(i);
    sorted_pcs.sortUnstable(struct {
        addrs: []const u64,

        pub fn lessThan(ctx: @This(), a_index: usize, b_index: usize) bool {
            return ctx.addrs[a_index] < ctx.addrs[b_index];
        }
    }{ .addrs = sorted_pcs.items(.pc) });

    debug_info.resolveAddresses(gpa, sorted_pcs.items(.pc), sorted_pcs.items(.sl)) catch |err| {
        log.err("failed to resolve addresses to source locations: {s}", .{@errorName(err)});
        return error.AlreadyReported;
    };

    for (sorted_pcs.items(.index), sorted_pcs.items(.sl)) |i, sl| source_locations[i] = sl;
    gop.value_ptr.source_locations = source_locations;

    ws.notifyUpdate();
}
fn addEntryPoint(fuzz: *Fuzz, coverage_id: u64, addr: u64) error{ AlreadyReported, OutOfMemory }!void {
    fuzz.coverage_mutex.lock();
    defer fuzz.coverage_mutex.unlock();

    const coverage_map = fuzz.coverage_files.getPtr(coverage_id).?;
    const header: *const abi.SeenPcsHeader = @ptrCast(coverage_map.mapped_memory[0..@sizeOf(abi.SeenPcsHeader)]);
    const pcs = header.pcAddrs();

    // Since this pcs list is unsorted, we must linear scan for the best index.
    const index = i: {
        var best: usize = 0;
        for (pcs[1..], 1..) |elem_addr, i| {
            if (elem_addr == addr) break :i i;
            if (elem_addr > addr) continue;
            if (elem_addr > pcs[best]) best = i;
        }
        break :i best;
    };
    if (index >= pcs.len) {
        log.err("unable to find unit test entry address 0x{x} in source locations (range: 0x{x} to 0x{x})", .{
            addr, pcs[0], pcs[pcs.len - 1],
        });
        return error.AlreadyReported;
    }
    if (false) {
        const sl = coverage_map.source_locations[index];
        const file_name = coverage_map.coverage.stringAt(coverage_map.coverage.fileAt(sl.file).basename);
        log.debug("server found entry point for 0x{x} at {s}:{d}:{d} - index {d} between {x} and {x}", .{
            addr, file_name, sl.line, sl.column, index, pcs[index - 1], pcs[index + 1],
        });
    }
    try coverage_map.entry_points.append(fuzz.ws.gpa, @intCast(index));
}
