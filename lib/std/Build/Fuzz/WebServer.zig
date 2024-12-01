const builtin = @import("builtin");

const std = @import("../../std.zig");
const Allocator = std.mem.Allocator;
const Build = std.Build;
const Step = std.Build.Step;
const Coverage = std.debug.Coverage;
const abi = std.Build.Fuzz.abi;
const log = std.log;
const assert = std.debug.assert;
const Cache = std.Build.Cache;
const Path = Cache.Path;

const WebServer = @This();

gpa: Allocator,
global_cache_directory: Build.Cache.Directory,
zig_lib_directory: Build.Cache.Directory,
zig_exe_path: []const u8,
listen_address: std.net.Address,
fuzz_run_steps: []const *Step.Run,

/// Messages from fuzz workers. Protected by mutex.
msg_queue: std.ArrayListUnmanaged(Msg),
/// Protects `msg_queue` only.
mutex: std.Thread.Mutex,
/// Signaled when there is a message in `msg_queue`.
condition: std.Thread.Condition,

coverage_files: std.AutoArrayHashMapUnmanaged(u64, CoverageMap),
/// Protects `coverage_files` only.
coverage_mutex: std.Thread.Mutex,
/// Signaled when `coverage_files` changes.
coverage_condition: std.Thread.Condition,

/// Time at initialization of WebServer.
base_timestamp: i128,

const fuzzer_bin_name = "fuzzer";
const fuzzer_arch_os_abi = "wasm32-freestanding";
const fuzzer_cpu_features = "baseline+atomics+bulk_memory+multivalue+mutable_globals+nontrapping_fptoint+reference_types+sign_ext";

const CoverageMap = struct {
    mapped_memory: []align(std.mem.page_size) const u8,
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

pub fn run(ws: *WebServer) void {
    var http_server = ws.listen_address.listen(.{
        .reuse_address = true,
    }) catch |err| {
        log.err("failed to listen to port {d}: {s}", .{ ws.listen_address.in.getPort(), @errorName(err) });
        return;
    };
    const port = http_server.listen_address.in.getPort();
    log.info("web interface listening at http://127.0.0.1:{d}/", .{port});
    if (ws.listen_address.in.getPort() == 0)
        log.info("hint: pass --port {d} to use this same port next time", .{port});

    while (true) {
        const connection = http_server.accept() catch |err| {
            log.err("failed to accept connection: {s}", .{@errorName(err)});
            return;
        };
        _ = std.Thread.spawn(.{}, accept, .{ ws, connection }) catch |err| {
            log.err("unable to spawn connection thread: {s}", .{@errorName(err)});
            connection.stream.close();
            continue;
        };
    }
}

fn now(s: *const WebServer) i64 {
    return @intCast(std.time.nanoTimestamp() - s.base_timestamp);
}

fn accept(ws: *WebServer, connection: std.net.Server.Connection) void {
    defer connection.stream.close();

    var read_buffer: [0x4000]u8 = undefined;
    var server = std.http.Server.init(connection, &read_buffer);
    var web_socket: std.http.WebSocket = undefined;
    var send_buffer: [0x4000]u8 = undefined;
    var ws_recv_buffer: [0x4000]u8 align(4) = undefined;
    while (server.state == .ready) {
        var request = server.receiveHead() catch |err| switch (err) {
            error.HttpConnectionClosing => return,
            else => {
                log.err("closing http connection: {s}", .{@errorName(err)});
                return;
            },
        };
        if (web_socket.init(&request, &send_buffer, &ws_recv_buffer) catch |err| {
            log.err("initializing web socket: {s}", .{@errorName(err)});
            return;
        }) {
            serveWebSocket(ws, &web_socket) catch |err| {
                log.err("unable to serve web socket connection: {s}", .{@errorName(err)});
                return;
            };
        } else {
            serveRequest(ws, &request) catch |err| switch (err) {
                error.AlreadyReported => return,
                else => |e| {
                    log.err("unable to serve {s}: {s}", .{ request.head.target, @errorName(e) });
                    return;
                },
            };
        }
    }
}

fn serveRequest(ws: *WebServer, request: *std.http.Server.Request) !void {
    if (std.mem.eql(u8, request.head.target, "/") or
        std.mem.eql(u8, request.head.target, "/debug") or
        std.mem.eql(u8, request.head.target, "/debug/"))
    {
        try serveFile(ws, request, "fuzzer/web/index.html", "text/html");
    } else if (std.mem.eql(u8, request.head.target, "/main.js") or
        std.mem.eql(u8, request.head.target, "/debug/main.js"))
    {
        try serveFile(ws, request, "fuzzer/web/main.js", "application/javascript");
    } else if (std.mem.eql(u8, request.head.target, "/main.wasm")) {
        try serveWasm(ws, request, .ReleaseFast);
    } else if (std.mem.eql(u8, request.head.target, "/debug/main.wasm")) {
        try serveWasm(ws, request, .Debug);
    } else if (std.mem.eql(u8, request.head.target, "/sources.tar") or
        std.mem.eql(u8, request.head.target, "/debug/sources.tar"))
    {
        try serveSourcesTar(ws, request);
    } else {
        try request.respond("not found", .{
            .status = .not_found,
            .extra_headers = &.{
                .{ .name = "content-type", .value = "text/plain" },
            },
        });
    }
}

fn serveFile(
    ws: *WebServer,
    request: *std.http.Server.Request,
    name: []const u8,
    content_type: []const u8,
) !void {
    const gpa = ws.gpa;
    // The desired API is actually sendfile, which will require enhancing std.http.Server.
    // We load the file with every request so that the user can make changes to the file
    // and refresh the HTML page without restarting this server.
    const file_contents = ws.zig_lib_directory.handle.readFileAlloc(gpa, name, 10 * 1024 * 1024) catch |err| {
        log.err("failed to read '{}{s}': {s}", .{ ws.zig_lib_directory, name, @errorName(err) });
        return error.AlreadyReported;
    };
    defer gpa.free(file_contents);
    try request.respond(file_contents, .{
        .extra_headers = &.{
            .{ .name = "content-type", .value = content_type },
            cache_control_header,
        },
    });
}

fn serveWasm(
    ws: *WebServer,
    request: *std.http.Server.Request,
    optimize_mode: std.builtin.OptimizeMode,
) !void {
    const gpa = ws.gpa;

    var arena_instance = std.heap.ArenaAllocator.init(gpa);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();

    // Do the compilation every request, so that the user can edit the files
    // and see the changes without restarting the server.
    const wasm_base_path = try buildWasmBinary(ws, arena, optimize_mode);
    const bin_name = try std.zig.binNameAlloc(arena, .{
        .root_name = fuzzer_bin_name,
        .target = std.zig.system.resolveTargetQuery(std.Build.parseTargetQuery(.{
            .arch_os_abi = fuzzer_arch_os_abi,
            .cpu_features = fuzzer_cpu_features,
        }) catch unreachable) catch unreachable,
        .output_mode = .Exe,
    });
    // std.http.Server does not have a sendfile API yet.
    const bin_path = try wasm_base_path.join(arena, bin_name);
    const file_contents = try bin_path.root_dir.handle.readFileAlloc(gpa, bin_path.sub_path, 10 * 1024 * 1024);
    defer gpa.free(file_contents);
    try request.respond(file_contents, .{
        .extra_headers = &.{
            .{ .name = "content-type", .value = "application/wasm" },
            cache_control_header,
        },
    });
}

fn buildWasmBinary(
    ws: *WebServer,
    arena: Allocator,
    optimize_mode: std.builtin.OptimizeMode,
) !Path {
    const gpa = ws.gpa;

    const main_src_path: Build.Cache.Path = .{
        .root_dir = ws.zig_lib_directory,
        .sub_path = "fuzzer/web/main.zig",
    };
    const walk_src_path: Build.Cache.Path = .{
        .root_dir = ws.zig_lib_directory,
        .sub_path = "docs/wasm/Walk.zig",
    };
    const html_render_src_path: Build.Cache.Path = .{
        .root_dir = ws.zig_lib_directory,
        .sub_path = "docs/wasm/html_render.zig",
    };

    var argv: std.ArrayListUnmanaged([]const u8) = .empty;

    try argv.appendSlice(arena, &.{
        ws.zig_exe_path, "build-exe", //
        "-fno-entry", //
        "-O", @tagName(optimize_mode), //
        "-target", fuzzer_arch_os_abi, //
        "-mcpu", fuzzer_cpu_features, //
        "--cache-dir", ws.global_cache_directory.path orelse ".", //
        "--global-cache-dir", ws.global_cache_directory.path orelse ".", //
        "--name", fuzzer_bin_name, //
        "-rdynamic", //
        "-fsingle-threaded", //
        "--dep", "Walk", //
        "--dep", "html_render", //
        try std.fmt.allocPrint(arena, "-Mroot={}", .{main_src_path}), //
        try std.fmt.allocPrint(arena, "-MWalk={}", .{walk_src_path}), //
        "--dep", "Walk", //
        try std.fmt.allocPrint(arena, "-Mhtml_render={}", .{html_render_src_path}), //
        "--listen=-",
    });

    var child = std.process.Child.init(argv.items, gpa);
    child.stdin_behavior = .Pipe;
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    try child.spawn();

    var poller = std.io.poll(gpa, enum { stdout, stderr }, .{
        .stdout = child.stdout.?,
        .stderr = child.stderr.?,
    });
    defer poller.deinit();

    try sendMessage(child.stdin.?, .update);
    try sendMessage(child.stdin.?, .exit);

    const Header = std.zig.Server.Message.Header;
    var result: ?Path = null;
    var result_error_bundle = std.zig.ErrorBundle.empty;

    const stdout = poller.fifo(.stdout);

    poll: while (true) {
        while (stdout.readableLength() < @sizeOf(Header)) {
            if (!(try poller.poll())) break :poll;
        }
        const header = stdout.reader().readStruct(Header) catch unreachable;
        while (stdout.readableLength() < header.bytes_len) {
            if (!(try poller.poll())) break :poll;
        }
        const body = stdout.readableSliceOfLen(header.bytes_len);

        switch (header.tag) {
            .zig_version => {
                if (!std.mem.eql(u8, builtin.zig_version_string, body)) {
                    return error.ZigProtocolVersionMismatch;
                }
            },
            .error_bundle => {
                const EbHdr = std.zig.Server.Message.ErrorBundle;
                const eb_hdr = @as(*align(1) const EbHdr, @ptrCast(body));
                const extra_bytes =
                    body[@sizeOf(EbHdr)..][0 .. @sizeOf(u32) * eb_hdr.extra_len];
                const string_bytes =
                    body[@sizeOf(EbHdr) + extra_bytes.len ..][0..eb_hdr.string_bytes_len];
                // TODO: use @ptrCast when the compiler supports it
                const unaligned_extra = std.mem.bytesAsSlice(u32, extra_bytes);
                const extra_array = try arena.alloc(u32, unaligned_extra.len);
                @memcpy(extra_array, unaligned_extra);
                result_error_bundle = .{
                    .string_bytes = try arena.dupe(u8, string_bytes),
                    .extra = extra_array,
                };
            },
            .emit_digest => {
                const EmitDigest = std.zig.Server.Message.EmitDigest;
                const ebp_hdr = @as(*align(1) const EmitDigest, @ptrCast(body));
                if (!ebp_hdr.flags.cache_hit) {
                    log.info("source changes detected; rebuilt wasm component", .{});
                }
                const digest = body[@sizeOf(EmitDigest)..][0..Cache.bin_digest_len];
                result = .{
                    .root_dir = ws.global_cache_directory,
                    .sub_path = try arena.dupe(u8, "o" ++ std.fs.path.sep_str ++ Cache.binToHex(digest.*)),
                };
            },
            else => {}, // ignore other messages
        }

        stdout.discard(body.len);
    }

    const stderr = poller.fifo(.stderr);
    if (stderr.readableLength() > 0) {
        const owned_stderr = try stderr.toOwnedSlice();
        defer gpa.free(owned_stderr);
        std.debug.print("{s}", .{owned_stderr});
    }

    // Send EOF to stdin.
    child.stdin.?.close();
    child.stdin = null;

    switch (try child.wait()) {
        .Exited => |code| {
            if (code != 0) {
                log.err(
                    "the following command exited with error code {d}:\n{s}",
                    .{ code, try Build.Step.allocPrintCmd(arena, null, argv.items) },
                );
                return error.WasmCompilationFailed;
            }
        },
        .Signal, .Stopped, .Unknown => {
            log.err(
                "the following command terminated unexpectedly:\n{s}",
                .{try Build.Step.allocPrintCmd(arena, null, argv.items)},
            );
            return error.WasmCompilationFailed;
        },
    }

    if (result_error_bundle.errorMessageCount() > 0) {
        const color = std.zig.Color.auto;
        result_error_bundle.renderToStdErr(color.renderOptions());
        log.err("the following command failed with {d} compilation errors:\n{s}", .{
            result_error_bundle.errorMessageCount(),
            try Build.Step.allocPrintCmd(arena, null, argv.items),
        });
        return error.WasmCompilationFailed;
    }

    return result orelse {
        log.err("child process failed to report result\n{s}", .{
            try Build.Step.allocPrintCmd(arena, null, argv.items),
        });
        return error.WasmCompilationFailed;
    };
}

fn sendMessage(file: std.fs.File, tag: std.zig.Client.Message.Tag) !void {
    const header: std.zig.Client.Message.Header = .{
        .tag = tag,
        .bytes_len = 0,
    };
    try file.writeAll(std.mem.asBytes(&header));
}

fn serveWebSocket(ws: *WebServer, web_socket: *std.http.WebSocket) !void {
    ws.coverage_mutex.lock();
    defer ws.coverage_mutex.unlock();

    // On first connection, the client needs to know what time the server
    // thinks it is to rebase timestamps.
    {
        const timestamp_message: abi.CurrentTime = .{ .base = ws.now() };
        try web_socket.writeMessage(std.mem.asBytes(&timestamp_message), .binary);
    }

    // On first connection, the client needs all the coverage information
    // so that subsequent updates can contain only the updated bits.
    var prev_unique_runs: usize = 0;
    var prev_entry_points: usize = 0;
    try sendCoverageContext(ws, web_socket, &prev_unique_runs, &prev_entry_points);
    while (true) {
        ws.coverage_condition.timedWait(&ws.coverage_mutex, std.time.ns_per_ms * 500) catch {};
        try sendCoverageContext(ws, web_socket, &prev_unique_runs, &prev_entry_points);
    }
}

fn sendCoverageContext(
    ws: *WebServer,
    web_socket: *std.http.WebSocket,
    prev_unique_runs: *usize,
    prev_entry_points: *usize,
) !void {
    const coverage_maps = ws.coverage_files.values();
    if (coverage_maps.len == 0) return;
    // TODO: make each events URL correspond to one coverage map
    const coverage_map = &coverage_maps[0];
    const cov_header: *const abi.SeenPcsHeader = @ptrCast(coverage_map.mapped_memory[0..@sizeOf(abi.SeenPcsHeader)]);
    const seen_pcs = cov_header.seenBits();
    const n_runs = @atomicLoad(usize, &cov_header.n_runs, .monotonic);
    const unique_runs = @atomicLoad(usize, &cov_header.unique_runs, .monotonic);
    if (prev_unique_runs.* != unique_runs) {
        // There has been an update.
        if (prev_unique_runs.* == 0) {
            // We need to send initial context.
            const header: abi.SourceIndexHeader = .{
                .flags = .{},
                .directories_len = @intCast(coverage_map.coverage.directories.entries.len),
                .files_len = @intCast(coverage_map.coverage.files.entries.len),
                .source_locations_len = @intCast(coverage_map.source_locations.len),
                .string_bytes_len = @intCast(coverage_map.coverage.string_bytes.items.len),
                .start_timestamp = coverage_map.start_timestamp,
            };
            const iovecs: [5]std.posix.iovec_const = .{
                makeIov(std.mem.asBytes(&header)),
                makeIov(std.mem.sliceAsBytes(coverage_map.coverage.directories.keys())),
                makeIov(std.mem.sliceAsBytes(coverage_map.coverage.files.keys())),
                makeIov(std.mem.sliceAsBytes(coverage_map.source_locations)),
                makeIov(coverage_map.coverage.string_bytes.items),
            };
            try web_socket.writeMessagev(&iovecs, .binary);
        }

        const header: abi.CoverageUpdateHeader = .{
            .n_runs = n_runs,
            .unique_runs = unique_runs,
        };
        const iovecs: [2]std.posix.iovec_const = .{
            makeIov(std.mem.asBytes(&header)),
            makeIov(std.mem.sliceAsBytes(seen_pcs)),
        };
        try web_socket.writeMessagev(&iovecs, .binary);

        prev_unique_runs.* = unique_runs;
    }

    if (prev_entry_points.* != coverage_map.entry_points.items.len) {
        const header: abi.EntryPointHeader = .{
            .flags = .{
                .locs_len = @intCast(coverage_map.entry_points.items.len),
            },
        };
        const iovecs: [2]std.posix.iovec_const = .{
            makeIov(std.mem.asBytes(&header)),
            makeIov(std.mem.sliceAsBytes(coverage_map.entry_points.items)),
        };
        try web_socket.writeMessagev(&iovecs, .binary);

        prev_entry_points.* = coverage_map.entry_points.items.len;
    }
}

fn serveSourcesTar(ws: *WebServer, request: *std.http.Server.Request) !void {
    const gpa = ws.gpa;

    var arena_instance = std.heap.ArenaAllocator.init(gpa);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();

    var send_buffer: [0x4000]u8 = undefined;
    var response = request.respondStreaming(.{
        .send_buffer = &send_buffer,
        .respond_options = .{
            .extra_headers = &.{
                .{ .name = "content-type", .value = "application/x-tar" },
                cache_control_header,
            },
        },
    });

    const DedupeTable = std.ArrayHashMapUnmanaged(Build.Cache.Path, void, Build.Cache.Path.TableAdapter, false);
    var dedupe_table: DedupeTable = .{};
    defer dedupe_table.deinit(gpa);

    for (ws.fuzz_run_steps) |run_step| {
        const compile_step_inputs = run_step.producer.?.step.inputs.table;
        for (compile_step_inputs.keys(), compile_step_inputs.values()) |dir_path, *file_list| {
            try dedupe_table.ensureUnusedCapacity(gpa, file_list.items.len);
            for (file_list.items) |sub_path| {
                // Special file "." means the entire directory.
                if (std.mem.eql(u8, sub_path, ".")) continue;
                const joined_path = try dir_path.join(arena, sub_path);
                _ = dedupe_table.getOrPutAssumeCapacity(joined_path);
            }
        }
    }

    const deduped_paths = dedupe_table.keys();
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

    var cwd_cache: ?[]const u8 = null;

    var archiver = std.tar.writer(response.writer());

    for (deduped_paths) |joined_path| {
        var file = joined_path.root_dir.handle.openFile(joined_path.sub_path, .{}) catch |err| {
            log.err("failed to open {}: {s}", .{ joined_path, @errorName(err) });
            continue;
        };
        defer file.close();

        archiver.prefix = joined_path.root_dir.path orelse try memoizedCwd(arena, &cwd_cache);
        try archiver.writeFile(joined_path.sub_path, file);
    }

    // intentionally omitting the pointless trailer
    //try archiver.finish();
    try response.end();
}

fn memoizedCwd(arena: Allocator, opt_ptr: *?[]const u8) ![]const u8 {
    if (opt_ptr.*) |cached| return cached;
    const result = try std.process.getCwdAlloc(arena);
    opt_ptr.* = result;
    return result;
}

const cache_control_header: std.http.Header = .{
    .name = "cache-control",
    .value = "max-age=0, must-revalidate",
};

pub fn coverageRun(ws: *WebServer) void {
    ws.mutex.lock();
    defer ws.mutex.unlock();

    while (true) {
        ws.condition.wait(&ws.mutex);
        for (ws.msg_queue.items) |msg| switch (msg) {
            .coverage => |coverage| prepareTables(ws, coverage.run, coverage.id) catch |err| switch (err) {
                error.AlreadyReported => continue,
                else => |e| log.err("failed to prepare code coverage tables: {s}", .{@errorName(e)}),
            },
            .entry_point => |entry_point| addEntryPoint(ws, entry_point.coverage_id, entry_point.addr) catch |err| switch (err) {
                error.AlreadyReported => continue,
                else => |e| log.err("failed to prepare code coverage tables: {s}", .{@errorName(e)}),
            },
        };
        ws.msg_queue.clearRetainingCapacity();
    }
}

fn prepareTables(
    ws: *WebServer,
    run_step: *Step.Run,
    coverage_id: u64,
) error{ OutOfMemory, AlreadyReported }!void {
    const gpa = ws.gpa;

    ws.coverage_mutex.lock();
    defer ws.coverage_mutex.unlock();

    const gop = try ws.coverage_files.getOrPut(gpa, coverage_id);
    if (gop.found_existing) {
        // We are fuzzing the same executable with multiple threads.
        // Perhaps the same unit test; perhaps a different one. In any
        // case, since the coverage file is the same, we only have to
        // notice changes to that one file in order to learn coverage for
        // this particular executable.
        return;
    }
    errdefer _ = ws.coverage_files.pop();

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
        log.err("step '{s}': failed to load debug information for '{}': {s}", .{
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
        log.err("step '{s}': failed to load coverage file '{}': {s}", .{
            run_step.step.name, coverage_file_path, @errorName(err),
        });
        return error.AlreadyReported;
    };
    defer coverage_file.close();

    const file_size = coverage_file.getEndPos() catch |err| {
        log.err("unable to check len of coverage file '{}': {s}", .{ coverage_file_path, @errorName(err) });
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
        log.err("failed to map coverage file '{}': {s}", .{ coverage_file_path, @errorName(err) });
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

    ws.coverage_condition.broadcast();
}

fn addEntryPoint(ws: *WebServer, coverage_id: u64, addr: u64) error{ AlreadyReported, OutOfMemory }!void {
    ws.coverage_mutex.lock();
    defer ws.coverage_mutex.unlock();

    const coverage_map = ws.coverage_files.getPtr(coverage_id).?;
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
    const gpa = ws.gpa;
    try coverage_map.entry_points.append(gpa, @intCast(index));
}

fn makeIov(s: []const u8) std.posix.iovec_const {
    return .{
        .base = s.ptr,
        .len = s.len,
    };
}
