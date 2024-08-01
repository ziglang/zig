const builtin = @import("builtin");
const std = @import("../std.zig");
const Build = std.Build;
const Step = std.Build.Step;
const assert = std.debug.assert;
const fatal = std.process.fatal;
const Allocator = std.mem.Allocator;
const log = std.log;

const Fuzz = @This();
const build_runner = @import("root");

pub fn start(
    gpa: Allocator,
    arena: Allocator,
    global_cache_directory: Build.Cache.Directory,
    zig_lib_directory: Build.Cache.Directory,
    zig_exe_path: []const u8,
    thread_pool: *std.Thread.Pool,
    all_steps: []const *Step,
    ttyconf: std.io.tty.Config,
    listen_address: std.net.Address,
    prog_node: std.Progress.Node,
) Allocator.Error!void {
    const fuzz_run_steps = block: {
        const rebuild_node = prog_node.start("Rebuilding Unit Tests", 0);
        defer rebuild_node.end();
        var wait_group: std.Thread.WaitGroup = .{};
        defer wait_group.wait();
        var fuzz_run_steps: std.ArrayListUnmanaged(*Step.Run) = .{};
        defer fuzz_run_steps.deinit(gpa);
        for (all_steps) |step| {
            const run = step.cast(Step.Run) orelse continue;
            if (run.fuzz_tests.items.len > 0 and run.producer != null) {
                thread_pool.spawnWg(&wait_group, rebuildTestsWorkerRun, .{ run, ttyconf, rebuild_node });
                try fuzz_run_steps.append(gpa, run);
            }
        }
        if (fuzz_run_steps.items.len == 0) fatal("no fuzz tests found", .{});
        rebuild_node.setEstimatedTotalItems(fuzz_run_steps.items.len);
        break :block try arena.dupe(*Step.Run, fuzz_run_steps.items);
    };

    // Detect failure.
    for (fuzz_run_steps) |run| {
        assert(run.fuzz_tests.items.len > 0);
        if (run.rebuilt_executable == null)
            fatal("one or more unit tests failed to be rebuilt in fuzz mode", .{});
    }

    var web_server: WebServer = .{
        .gpa = gpa,
        .global_cache_directory = global_cache_directory,
        .zig_lib_directory = zig_lib_directory,
        .zig_exe_path = zig_exe_path,
        .msg_queue = .{},
        .mutex = .{},
        .listen_address = listen_address,
        .fuzz_run_steps = fuzz_run_steps,
    };

    const web_server_thread = std.Thread.spawn(.{}, WebServer.run, .{&web_server}) catch |err| {
        fatal("unable to spawn web server thread: {s}", .{@errorName(err)});
    };
    defer web_server_thread.join();

    {
        const fuzz_node = prog_node.start("Fuzzing", fuzz_run_steps.len);
        defer fuzz_node.end();
        var wait_group: std.Thread.WaitGroup = .{};
        defer wait_group.wait();

        for (fuzz_run_steps) |run| {
            for (run.fuzz_tests.items) |unit_test_index| {
                assert(run.rebuilt_executable != null);
                thread_pool.spawnWg(&wait_group, fuzzWorkerRun, .{
                    run, &web_server, unit_test_index, ttyconf, fuzz_node,
                });
            }
        }
    }

    log.err("all fuzz workers crashed", .{});
}

pub const WebServer = struct {
    gpa: Allocator,
    global_cache_directory: Build.Cache.Directory,
    zig_lib_directory: Build.Cache.Directory,
    zig_exe_path: []const u8,
    /// Messages from fuzz workers. Protected by mutex.
    msg_queue: std.ArrayListUnmanaged(Msg),
    mutex: std.Thread.Mutex,
    listen_address: std.net.Address,
    fuzz_run_steps: []const *Step.Run,

    const Msg = union(enum) {
        coverage_id: u64,
    };

    fn run(ws: *WebServer) void {
        var http_server = ws.listen_address.listen(.{
            .reuse_address = true,
        }) catch |err| {
            log.err("failed to listen to port {d}: {s}", .{ ws.listen_address.in.getPort(), @errorName(err) });
            return;
        };
        const port = http_server.listen_address.in.getPort();
        log.info("web interface listening at http://127.0.0.1:{d}/", .{port});

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

    fn accept(ws: *WebServer, connection: std.net.Server.Connection) void {
        defer connection.stream.close();

        var read_buffer: [8000]u8 = undefined;
        var server = std.http.Server.init(connection, &read_buffer);
        while (server.state == .ready) {
            var request = server.receiveHead() catch |err| switch (err) {
                error.HttpConnectionClosing => return,
                else => {
                    log.err("closing http connection: {s}", .{@errorName(err)});
                    return;
                },
            };
            serveRequest(ws, &request) catch |err| switch (err) {
                error.AlreadyReported => return,
                else => |e| {
                    log.err("unable to serve {s}: {s}", .{ request.head.target, @errorName(e) });
                    return;
                },
            };
        }
    }

    fn serveRequest(ws: *WebServer, request: *std.http.Server.Request) !void {
        if (std.mem.eql(u8, request.head.target, "/") or
            std.mem.eql(u8, request.head.target, "/debug") or
            std.mem.eql(u8, request.head.target, "/debug/"))
        {
            try serveFile(ws, request, "fuzzer/index.html", "text/html");
        } else if (std.mem.eql(u8, request.head.target, "/main.js") or
            std.mem.eql(u8, request.head.target, "/debug/main.js"))
        {
            try serveFile(ws, request, "fuzzer/main.js", "application/javascript");
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
        const wasm_binary_path = try buildWasmBinary(ws, arena, optimize_mode);
        // std.http.Server does not have a sendfile API yet.
        const file_contents = try std.fs.cwd().readFileAlloc(gpa, wasm_binary_path, 10 * 1024 * 1024);
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
    ) ![]const u8 {
        const gpa = ws.gpa;

        const main_src_path: Build.Cache.Path = .{
            .root_dir = ws.zig_lib_directory,
            .sub_path = "fuzzer/wasm/main.zig",
        };
        const walk_src_path: Build.Cache.Path = .{
            .root_dir = ws.zig_lib_directory,
            .sub_path = "docs/wasm/Walk.zig",
        };
        const html_render_src_path: Build.Cache.Path = .{
            .root_dir = ws.zig_lib_directory,
            .sub_path = "docs/wasm/html_render.zig",
        };

        var argv: std.ArrayListUnmanaged([]const u8) = .{};

        try argv.appendSlice(arena, &.{
            ws.zig_exe_path, "build-exe", //
            "-fno-entry", //
            "-O", @tagName(optimize_mode), //
            "-target", "wasm32-freestanding", //
            "-mcpu", "baseline+atomics+bulk_memory+multivalue+mutable_globals+nontrapping_fptoint+reference_types+sign_ext", //
            "--cache-dir", ws.global_cache_directory.path orelse ".", //
            "--global-cache-dir", ws.global_cache_directory.path orelse ".", //
            "--name", "fuzzer", //
            "-rdynamic", //
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
        var result: ?[]const u8 = null;
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
                .emit_bin_path => {
                    const EbpHdr = std.zig.Server.Message.EmitBinPath;
                    const ebp_hdr = @as(*align(1) const EbpHdr, @ptrCast(body));
                    if (!ebp_hdr.flags.cache_hit) {
                        log.info("source changes detected; rebuilt wasm component", .{});
                    }
                    result = try arena.dupe(u8, body[@sizeOf(EbpHdr)..]);
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
        const w = response.writer();

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

        for (deduped_paths) |joined_path| {
            var file = joined_path.root_dir.handle.openFile(joined_path.sub_path, .{}) catch |err| {
                log.err("failed to open {}: {s}", .{ joined_path, @errorName(err) });
                continue;
            };
            defer file.close();

            const stat = file.stat() catch |err| {
                log.err("failed to stat {}: {s}", .{ joined_path, @errorName(err) });
                continue;
            };
            if (stat.kind != .file)
                continue;

            const padding = p: {
                const remainder = stat.size % 512;
                break :p if (remainder > 0) 512 - remainder else 0;
            };

            var file_header = std.tar.output.Header.init();
            file_header.typeflag = .regular;
            try file_header.setPath(joined_path.root_dir.path orelse ".", joined_path.sub_path);
            try file_header.setSize(stat.size);
            try file_header.updateChecksum();
            try w.writeAll(std.mem.asBytes(&file_header));
            try w.writeFile(file);
            try w.writeByteNTimes(0, padding);
        }

        // intentionally omitting the pointless trailer
        //try w.writeByteNTimes(0, 512 * 2);
        try response.end();
    }

    const cache_control_header: std.http.Header = .{
        .name = "cache-control",
        .value = "max-age=0, must-revalidate",
    };
};

fn rebuildTestsWorkerRun(run: *Step.Run, ttyconf: std.io.tty.Config, parent_prog_node: std.Progress.Node) void {
    const gpa = run.step.owner.allocator;
    const stderr = std.io.getStdErr();

    const compile = run.producer.?;
    const prog_node = parent_prog_node.start(compile.step.name, 0);
    defer prog_node.end();

    const result = compile.rebuildInFuzzMode(prog_node);

    const show_compile_errors = compile.step.result_error_bundle.errorMessageCount() > 0;
    const show_error_msgs = compile.step.result_error_msgs.items.len > 0;
    const show_stderr = compile.step.result_stderr.len > 0;

    if (show_error_msgs or show_compile_errors or show_stderr) {
        std.debug.lockStdErr();
        defer std.debug.unlockStdErr();
        build_runner.printErrorMessages(gpa, &compile.step, ttyconf, stderr, false) catch {};
    }

    if (result) |rebuilt_bin_path| {
        run.rebuilt_executable = rebuilt_bin_path;
    } else |err| switch (err) {
        error.MakeFailed => {},
        else => {
            std.debug.print("step '{s}': failed to rebuild in fuzz mode: {s}\n", .{
                compile.step.name, @errorName(err),
            });
        },
    }
}

fn fuzzWorkerRun(
    run: *Step.Run,
    web_server: *WebServer,
    unit_test_index: u32,
    ttyconf: std.io.tty.Config,
    parent_prog_node: std.Progress.Node,
) void {
    const gpa = run.step.owner.allocator;
    const test_name = run.cached_test_metadata.?.testName(unit_test_index);

    const prog_node = parent_prog_node.start(test_name, 0);
    defer prog_node.end();

    run.rerunInFuzzMode(web_server, unit_test_index, prog_node) catch |err| switch (err) {
        error.MakeFailed => {
            const stderr = std.io.getStdErr();
            std.debug.lockStdErr();
            defer std.debug.unlockStdErr();
            build_runner.printErrorMessages(gpa, &run.step, ttyconf, stderr, false) catch {};
        },
        else => {
            std.debug.print("step '{s}': failed to rebuild '{s}' in fuzz mode: {s}\n", .{
                run.step.name, test_name, @errorName(err),
            });
        },
    };
}
