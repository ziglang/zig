const builtin = @import("builtin");
const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn main() !void {
    var arena_instance = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();

    var general_purpose_allocator: std.heap.GeneralPurposeAllocator(.{}) = .{};
    const gpa = general_purpose_allocator.allocator();

    const args = try std.process.argsAlloc(arena);
    const zig_lib_directory = args[1];
    const zig_exe_path = args[2];
    const global_cache_path = args[3];

    const docs_path = try std.fs.path.join(arena, &.{ zig_lib_directory, "docs" });
    var docs_dir = try std.fs.cwd().openDir(docs_path, .{});
    defer docs_dir.close();

    const listen_port: u16 = 0;
    const address = std.net.Address.parseIp("127.0.0.1", listen_port) catch unreachable;
    var http_server = try address.listen(.{});
    const port = http_server.listen_address.in.getPort();
    const url = try std.fmt.allocPrint(arena, "http://127.0.0.1:{d}/\n", .{port});
    std.io.getStdOut().writeAll(url) catch {};
    openBrowserTab(gpa, url[0 .. url.len - 1 :'\n']) catch |err| {
        std.log.err("unable to open browser: {s}", .{@errorName(err)});
    };

    var read_buffer: [8000]u8 = undefined;
    accept: while (true) {
        const connection = try http_server.accept();
        defer connection.stream.close();

        var server = std.http.Server.init(connection, &read_buffer);
        while (server.state == .ready) {
            var request = server.receiveHead() catch |err| switch (err) {
                error.HttpConnectionClosing => continue :accept,
                else => {
                    std.log.err("closing http connection: {s}", .{@errorName(err)});
                    continue :accept;
                },
            };
            serveRequest(&request, gpa, docs_dir, zig_exe_path, global_cache_path) catch |err| {
                std.log.err("unable to serve {s}: {s}", .{ request.head.target, @errorName(err) });
                continue :accept;
            };
        }
    }
}

fn serveRequest(
    request: *std.http.Server.Request,
    gpa: Allocator,
    docs_dir: std.fs.Dir,
    zig_exe_path: []const u8,
    global_cache_path: []const u8,
) !void {
    if (std.mem.eql(u8, request.head.target, "/") or
        std.mem.eql(u8, request.head.target, "/debug/"))
    {
        try serveDocsFile(request, gpa, docs_dir, "index.html", "text/html");
    } else if (std.mem.eql(u8, request.head.target, "/main.js") or
        std.mem.eql(u8, request.head.target, "/debug/main.js"))
    {
        try serveDocsFile(request, gpa, docs_dir, "main.js", "application/javascript");
    } else if (std.mem.eql(u8, request.head.target, "/main.wasm")) {
        try serveWasm(request, gpa, zig_exe_path, global_cache_path, .ReleaseFast);
    } else if (std.mem.eql(u8, request.head.target, "/debug/main.wasm")) {
        try serveWasm(request, gpa, zig_exe_path, global_cache_path, .Debug);
    } else {
        try request.respond("not found", .{
            .status = .not_found,
            .extra_headers = &.{
                .{ .name = "content-type", .value = "text/plain" },
            },
        });
    }
}

fn serveDocsFile(
    request: *std.http.Server.Request,
    gpa: Allocator,
    docs_dir: std.fs.Dir,
    name: []const u8,
    content_type: []const u8,
) !void {
    // The desired API is actually sendfile, which will require enhancing std.http.Server.
    // We load the file with every request so that the user can make changes to the file
    // and refresh the HTML page without restarting this server.
    const file_contents = try docs_dir.readFileAlloc(gpa, name, 10 * 1024 * 1024);
    defer gpa.free(file_contents);
    try request.respond(file_contents, .{
        .status = .ok,
        .extra_headers = &.{
            .{ .name = "content-type", .value = content_type },
        },
    });
}

fn serveWasm(
    request: *std.http.Server.Request,
    gpa: Allocator,
    zig_exe_path: []const u8,
    global_cache_path: []const u8,
    optimize_mode: std.builtin.OptimizeMode,
) !void {
    _ = request;
    _ = gpa;
    _ = zig_exe_path;
    _ = global_cache_path;
    _ = optimize_mode;
    @panic("TODO serve wasm");
}

const BuildWasmBinaryOptions = struct {
    zig_exe_path: []const u8,
    global_cache_path: []const u8,
    main_src_path: []const u8,
};

fn buildWasmBinary(arena: Allocator, options: BuildWasmBinaryOptions) ![]const u8 {
    var argv: std.ArrayListUnmanaged([]const u8) = .{};
    try argv.appendSlice(arena, &.{
        options.zig_exe_path,
        "build-exe",
        "-fno-entry",
        "-OReleaseSmall",
        "-target",
        "wasm32-freestanding",
        "-mcpu",
        "baseline+atomics+bulk_memory+multivalue+mutable_globals+nontrapping_fptoint+reference_types+sign_ext",
        "--cache-dir",
        options.global_cache_path,
        "--global-cache-dir",
        options.global_cache_path,
        "--name",
        "autodoc",
        "-rdynamic",
        options.main_src_path,
        "--listen=-",
    });
}

fn openBrowserTab(gpa: Allocator, url: []const u8) !void {
    // Until https://github.com/ziglang/zig/issues/19205 is implemented, we
    // spawn a thread for this child process.
    _ = try std.Thread.spawn(.{}, openBrowserTabThread, .{ gpa, url });
}

fn openBrowserTabThread(gpa: Allocator, url: []const u8) !void {
    const main_exe = switch (builtin.os.tag) {
        .windows => "explorer",
        else => "xdg-open",
    };
    var child = std.ChildProcess.init(&.{ main_exe, url }, gpa);
    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Ignore;
    child.stderr_behavior = .Ignore;
    try child.spawn();
    _ = try child.wait();
}
