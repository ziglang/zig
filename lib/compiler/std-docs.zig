const builtin = @import("builtin");
const std = @import("std");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const Cache = std.Build.Cache;

fn usage() noreturn {
    std.fs.File.stdout().writeAll(
        \\Usage: zig std [options]
        \\
        \\Options:
        \\  -h, --help                Print this help and exit
        \\  -p [port], --port [port]  Port to listen on. Default is 0, meaning an ephemeral port chosen by the system.
        \\  --[no-]open-browser       Force enabling or disabling opening a browser tab to the served website.
        \\                            By default, enabled unless a port is specified.
        \\
    ) catch {};
    std.process.exit(1);
}

pub fn main() !void {
    var arena_instance = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();

    var general_purpose_allocator: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const gpa = general_purpose_allocator.allocator();

    var argv = try std.process.argsWithAllocator(arena);
    defer argv.deinit();
    assert(argv.skip());
    const zig_lib_directory = argv.next().?;
    const zig_exe_path = argv.next().?;
    const global_cache_path = argv.next().?;

    var lib_dir = try std.fs.cwd().openDir(zig_lib_directory, .{});
    defer lib_dir.close();

    var listen_port: u16 = 0;
    var force_open_browser: ?bool = null;
    while (argv.next()) |arg| {
        if (mem.eql(u8, arg, "-h") or mem.eql(u8, arg, "--help")) {
            usage();
        } else if (mem.eql(u8, arg, "-p") or mem.eql(u8, arg, "--port")) {
            listen_port = std.fmt.parseInt(u16, argv.next() orelse usage(), 10) catch |err| {
                std.log.err("expected port number: {}", .{err});
                usage();
            };
        } else if (mem.eql(u8, arg, "--open-browser")) {
            force_open_browser = true;
        } else if (mem.eql(u8, arg, "--no-open-browser")) {
            force_open_browser = false;
        } else {
            std.log.err("unrecognized argument: {s}", .{arg});
            usage();
        }
    }
    const should_open_browser = force_open_browser orelse (listen_port == 0);

    const address = std.net.Address.parseIp("127.0.0.1", listen_port) catch unreachable;
    var http_server = try address.listen(.{});
    const port = http_server.listen_address.in.getPort();
    const url_with_newline = try std.fmt.allocPrint(arena, "http://127.0.0.1:{d}/\n", .{port});
    std.fs.File.stdout().writeAll(url_with_newline) catch {};
    if (should_open_browser) {
        openBrowserTab(gpa, url_with_newline[0 .. url_with_newline.len - 1 :'\n']) catch |err| {
            std.log.err("unable to open browser: {s}", .{@errorName(err)});
        };
    }

    var context: Context = .{
        .gpa = gpa,
        .zig_exe_path = zig_exe_path,
        .global_cache_path = global_cache_path,
        .lib_dir = lib_dir,
        .zig_lib_directory = zig_lib_directory,
    };

    while (true) {
        const connection = try http_server.accept();
        _ = std.Thread.spawn(.{}, accept, .{ &context, connection }) catch |err| {
            std.log.err("unable to accept connection: {s}", .{@errorName(err)});
            connection.stream.close();
            continue;
        };
    }
}

fn accept(context: *Context, connection: std.net.Server.Connection) void {
    defer connection.stream.close();

    var recv_buffer: [8000]u8 = undefined;
    var send_buffer: [4000]u8 = undefined;
    var stream_reader = connection.stream.reader();
    var stream_writer = connection.stream.writer();
    var connection_br = stream_reader.interface().buffered(&recv_buffer);
    var connection_bw = stream_writer.interface().buffered(&send_buffer);
    var server = std.http.Server.init(&connection_br, &connection_bw);

    while (server.state == .ready) {
        var request = server.receiveHead() catch |err| switch (err) {
            error.HttpConnectionClosing => return,
            else => {
                std.log.err("closing http connection: {s}", .{@errorName(err)});
                return;
            },
        };
        serveRequest(&request, context) catch |err| {
            std.log.err("unable to serve {s}: {s}", .{ request.head.target, @errorName(err) });
            return;
        };
    }
}

const Context = struct {
    gpa: Allocator,
    lib_dir: std.fs.Dir,
    zig_lib_directory: []const u8,
    zig_exe_path: []const u8,
    global_cache_path: []const u8,
};

fn serveRequest(request: *std.http.Server.Request, context: *Context) !void {
    if (std.mem.eql(u8, request.head.target, "/") or
        std.mem.eql(u8, request.head.target, "/debug") or
        std.mem.eql(u8, request.head.target, "/debug/"))
    {
        try serveDocsFile(request, context, "docs/index.html", "text/html");
    } else if (std.mem.eql(u8, request.head.target, "/main.js") or
        std.mem.eql(u8, request.head.target, "/debug/main.js"))
    {
        try serveDocsFile(request, context, "docs/main.js", "application/javascript");
    } else if (std.mem.eql(u8, request.head.target, "/main.wasm")) {
        try serveWasm(request, context, .ReleaseFast);
    } else if (std.mem.eql(u8, request.head.target, "/debug/main.wasm")) {
        try serveWasm(request, context, .Debug);
    } else if (std.mem.eql(u8, request.head.target, "/sources.tar") or
        std.mem.eql(u8, request.head.target, "/debug/sources.tar"))
    {
        try serveSourcesTar(request, context);
    } else {
        try request.respond("not found", .{
            .status = .not_found,
            .extra_headers = &.{
                .{ .name = "content-type", .value = "text/plain" },
            },
        });
    }
}

const cache_control_header: std.http.Header = .{
    .name = "cache-control",
    .value = "max-age=0, must-revalidate",
};

fn serveDocsFile(
    request: *std.http.Server.Request,
    context: *Context,
    name: []const u8,
    content_type: []const u8,
) !void {
    // Open the file with every request so that the user can make changes to
    // the file and refresh the HTML page without restarting this server.
    var file = try context.lib_dir.openFile(name, .{});
    defer file.close();
    const content_length = std.math.cast(usize, (try file.stat()).size) orelse return error.FileTooBig;

    var response = try request.respondStreaming(.{
        .content_length = content_length,
        .respond_options = .{
            .extra_headers = &.{
                .{ .name = "content-type", .value = content_type },
                cache_control_header,
            },
        },
    });

    var bw = response.writer().unbuffered();
    try bw.writeFileAll(file, .{
        .offset = .zero,
        .limit = .limited(content_length),
    });
    try response.end();
}

fn serveSourcesTar(request: *std.http.Server.Request, context: *Context) !void {
    const gpa = context.gpa;

    var response = try request.respondStreaming(.{
        .respond_options = .{
            .extra_headers = &.{
                .{ .name = "content-type", .value = "application/x-tar" },
                cache_control_header,
            },
        },
    });

    var std_dir = try context.lib_dir.openDir("std", .{ .iterate = true });
    defer std_dir.close();

    var walker = try std_dir.walk(gpa);
    defer walker.deinit();

    var archiver = std.tar.writer(response.writer());
    archiver.prefix = "std";

    while (try walker.next()) |entry| {
        switch (entry.kind) {
            .file => {
                if (!std.mem.endsWith(u8, entry.basename, ".zig"))
                    continue;
                if (std.mem.endsWith(u8, entry.basename, "test.zig"))
                    continue;
            },
            else => continue,
        }
        var file = try entry.dir.openFile(entry.basename, .{});
        defer file.close();
        try archiver.writeFile(entry.path, file);
    }

    {
        // Since this command is JIT compiled, the builtin module available in
        // this source file corresponds to the user's host system.
        const builtin_zig = @embedFile("builtin");
        archiver.prefix = "builtin";
        try archiver.writeFileBytes("builtin.zig", builtin_zig, .{});
    }

    // intentionally omitting the pointless trailer
    //try archiver.finish();
    try response.end();
}

fn serveWasm(
    request: *std.http.Server.Request,
    context: *Context,
    optimize_mode: std.builtin.OptimizeMode,
) !void {
    const gpa = context.gpa;

    var arena_instance = std.heap.ArenaAllocator.init(gpa);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();

    // Do the compilation every request, so that the user can edit the files
    // and see the changes without restarting the server.
    const wasm_base_path = try buildWasmBinary(arena, context, optimize_mode);
    const bin_name = try std.zig.binNameAlloc(arena, .{
        .root_name = autodoc_root_name,
        .target = &(std.zig.system.resolveTargetQuery(std.Build.parseTargetQuery(.{
            .arch_os_abi = autodoc_arch_os_abi,
            .cpu_features = autodoc_cpu_features,
        }) catch unreachable) catch unreachable),
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

const autodoc_root_name = "autodoc";
const autodoc_arch_os_abi = "wasm32-freestanding";
const autodoc_cpu_features = "baseline+atomics+bulk_memory+multivalue+mutable_globals+nontrapping_fptoint+reference_types+sign_ext";

fn buildWasmBinary(
    arena: Allocator,
    context: *Context,
    optimize_mode: std.builtin.OptimizeMode,
) !Cache.Path {
    const gpa = context.gpa;

    var argv: std.ArrayListUnmanaged([]const u8) = .empty;

    try argv.appendSlice(arena, &.{
        context.zig_exe_path, //
        "build-exe", //
        "-fno-entry", //
        "-O", @tagName(optimize_mode), //
        "-target", autodoc_arch_os_abi, //
        "-mcpu", autodoc_cpu_features, //
        "--cache-dir", context.global_cache_path, //
        "--global-cache-dir", context.global_cache_path, //
        "--name", autodoc_root_name, //
        "-rdynamic", //
        "--dep", "Walk", //
        try std.fmt.allocPrint(
            arena,
            "-Mroot={s}/docs/wasm/main.zig",
            .{context.zig_lib_directory},
        ),
        try std.fmt.allocPrint(
            arena,
            "-MWalk={s}/docs/wasm/Walk.zig",
            .{context.zig_lib_directory},
        ),
        "--listen=-", //
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

    var result: ?Cache.Path = null;
    var result_error_bundle = std.zig.ErrorBundle.empty;

    while (true) {
        receiveWasmMessage(arena, context, poller.reader(.stdout), &result, &result_error_bundle) catch |err| switch (err) {
            error.EndOfStream => break,
            error.ReadFailed => if (!(try poller.poll())) break,
            else => |e| return e,
        };
    }

    if (poller.reader(.stderr).buffer.len > 0) {
        std.debug.print("{s}", .{poller.reader(.stderr).bufferContents()});
    }

    // Send EOF to stdin.
    child.stdin.?.close();
    child.stdin = null;

    switch (try child.wait()) {
        .Exited => |code| {
            if (code != 0) {
                std.log.err(
                    "the following command exited with error code {d}:\n{s}",
                    .{ code, try std.Build.Step.allocPrintCmd(arena, null, argv.items) },
                );
                return error.WasmCompilationFailed;
            }
        },
        .Signal, .Stopped, .Unknown => {
            std.log.err(
                "the following command terminated unexpectedly:\n{s}",
                .{try std.Build.Step.allocPrintCmd(arena, null, argv.items)},
            );
            return error.WasmCompilationFailed;
        },
    }

    if (result_error_bundle.errorMessageCount() > 0) {
        const color = std.zig.Color.auto;
        result_error_bundle.renderToStdErr(color.renderOptions());
        std.log.err("the following command failed with {d} compilation errors:\n{s}", .{
            result_error_bundle.errorMessageCount(),
            try std.Build.Step.allocPrintCmd(arena, null, argv.items),
        });
        return error.WasmCompilationFailed;
    }

    return result orelse {
        std.log.err("child process failed to report result\n{s}", .{
            try std.Build.Step.allocPrintCmd(arena, null, argv.items),
        });
        return error.WasmCompilationFailed;
    };
}

fn receiveWasmMessage(
    arena: Allocator,
    context: *Context,
    br: *std.io.BufferedReader,
    result: *?Cache.Path,
    result_error_bundle: *std.zig.ErrorBundle,
) !void {
    // Ensure that we will be able to read the entire message without blocking.
    const header = try br.peekStructEndian(std.zig.Server.Message.Header, .little);
    try br.fill(@sizeOf(std.zig.Server.Message.Header) + header.bytes_len);
    br.toss(@sizeOf(std.zig.Server.Message.Header));
    switch (header.tag) {
        .zig_version => {
            const body = try br.take(header.bytes_len);
            if (!std.mem.eql(u8, builtin.zig_version_string, body)) {
                return error.ZigProtocolVersionMismatch;
            }
        },
        .error_bundle => {
            const eb_hdr = try br.takeStructEndian(std.zig.Server.Message.ErrorBundle, .little);
            const extra_array = try br.readArrayEndianAlloc(arena, u32, eb_hdr.extra_len, .little);
            const string_bytes = try br.readAlloc(arena, eb_hdr.string_bytes_len);
            result_error_bundle.* = .{
                .string_bytes = string_bytes,
                .extra = extra_array,
            };
        },
        .emit_digest => {
            const emit_digest = try br.takeStructEndian(std.zig.Server.Message.EmitDigest, .little);
            if (!emit_digest.flags.cache_hit) {
                std.log.info("source changes detected; rebuilt wasm component", .{});
            }
            const digest = try br.takeArray(Cache.bin_digest_len);
            result.* = .{
                .root_dir = Cache.Directory.cwd(),
                .sub_path = try std.fs.path.join(arena, &.{
                    context.global_cache_path, "o" ++ std.fs.path.sep_str ++ Cache.binToHex(digest.*),
                }),
            };
        },
        else => {
            // Ignore other messages.
            try br.discard(header.bytes_len);
        },
    }
}

fn sendMessage(file: std.fs.File, tag: std.zig.Client.Message.Tag) !void {
    const header: std.zig.Client.Message.Header = .{
        .tag = tag,
        .bytes_len = 0,
    };
    try file.writeAll(std.mem.asBytes(&header));
}

fn openBrowserTab(gpa: Allocator, url: []const u8) !void {
    // Until https://github.com/ziglang/zig/issues/19205 is implemented, we
    // spawn a thread for this child process.
    _ = try std.Thread.spawn(.{}, openBrowserTabThread, .{ gpa, url });
}

fn openBrowserTabThread(gpa: Allocator, url: []const u8) !void {
    const main_exe = switch (builtin.os.tag) {
        .windows => "explorer",
        .macos => "open",
        else => "xdg-open",
    };
    var child = std.process.Child.init(&.{ main_exe, url }, gpa);
    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Ignore;
    child.stderr_behavior = .Ignore;
    try child.spawn();
    _ = try child.wait();
}
