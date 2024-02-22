const builtin = @import("builtin");
const std = @import("std");
const testing = std.testing;
const native_endian = builtin.cpu.arch.endian();

test "trailers" {
    if (builtin.single_threaded) return error.SkipZigTest;
    if (builtin.os.tag == .wasi) return error.SkipZigTest;

    const gpa = testing.allocator;

    const address = try std.net.Address.parseIp("127.0.0.1", 0);
    var http_server = try address.listen(.{
        .reuse_address = true,
    });

    const port = http_server.listen_address.in.getPort();

    const server_thread = try std.Thread.spawn(.{}, serverThread, .{&http_server});
    defer server_thread.join();

    var client: std.http.Client = .{ .allocator = gpa };
    defer client.deinit();

    const location = try std.fmt.allocPrint(gpa, "http://127.0.0.1:{d}/trailer", .{port});
    defer gpa.free(location);
    const uri = try std.Uri.parse(location);

    {
        var server_header_buffer: [1024]u8 = undefined;
        var req = try client.open(.GET, uri, .{
            .server_header_buffer = &server_header_buffer,
        });
        defer req.deinit();

        try req.send(.{});
        try req.wait();

        const body = try req.reader().readAllAlloc(gpa, 8192);
        defer gpa.free(body);

        try testing.expectEqualStrings("Hello, World!\n", body);

        var it = req.response.iterateHeaders();
        {
            const header = it.next().?;
            try testing.expect(!it.is_trailer);
            try testing.expectEqualStrings("connection", header.name);
            try testing.expectEqualStrings("keep-alive", header.value);
        }
        {
            const header = it.next().?;
            try testing.expect(!it.is_trailer);
            try testing.expectEqualStrings("transfer-encoding", header.name);
            try testing.expectEqualStrings("chunked", header.value);
        }
        {
            const header = it.next().?;
            try testing.expect(it.is_trailer);
            try testing.expectEqualStrings("X-Checksum", header.name);
            try testing.expectEqualStrings("aaaa", header.value);
        }
        try testing.expectEqual(null, it.next());
    }

    // connection has been kept alive
    try testing.expect(client.connection_pool.free_len == 1);
}

fn serverThread(http_server: *std.net.Server) anyerror!void {
    var header_buffer: [1024]u8 = undefined;
    var remaining: usize = 1;
    while (remaining != 0) : (remaining -= 1) {
        const conn = try http_server.accept();
        defer conn.stream.close();

        var server = std.http.Server.init(conn, &header_buffer);

        try testing.expectEqual(.ready, server.state);
        var request = try server.receiveHead();
        try serve(&request);
        try testing.expectEqual(.ready, server.state);
    }
}

fn serve(request: *std.http.Server.Request) !void {
    try testing.expectEqualStrings(request.head.target, "/trailer");

    var send_buffer: [1024]u8 = undefined;
    var response = request.respondStreaming(.{
        .send_buffer = &send_buffer,
    });
    try response.writeAll("Hello, ");
    try response.flush();
    try response.writeAll("World!\n");
    try response.flush();
    try response.endChunked(.{
        .trailers = &.{
            .{ .name = "X-Checksum", .value = "aaaa" },
        },
    });
}

test "HTTP server handles a chunked transfer coding request" {
    // This test requires spawning threads.
    if (builtin.single_threaded) {
        return error.SkipZigTest;
    }

    if (builtin.zig_backend == .stage2_llvm and native_endian == .big) {
        // https://github.com/ziglang/zig/issues/13782
        return error.SkipZigTest;
    }

    if (builtin.os.tag == .wasi) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    const expect = std.testing.expect;

    const max_header_size = 8192;

    const address = try std.net.Address.parseIp("127.0.0.1", 0);
    var socket_server = try address.listen(.{ .reuse_address = true });
    defer socket_server.deinit();
    const server_port = socket_server.listen_address.in.getPort();

    const server_thread = try std.Thread.spawn(.{}, (struct {
        fn apply(net_server: *std.net.Server) !void {
            var header_buffer: [max_header_size]u8 = undefined;
            const conn = try net_server.accept();
            defer conn.stream.close();

            var server = std.http.Server.init(conn, &header_buffer);
            var request = try server.receiveHead();

            try expect(request.head.transfer_encoding == .chunked);

            var buf: [128]u8 = undefined;
            const n = try request.reader().readAll(&buf);
            try expect(std.mem.eql(u8, buf[0..n], "ABCD"));

            try request.respond("message from server!\n", .{
                .extra_headers = &.{
                    .{ .name = "content-type", .value = "text/plain" },
                },
                .keep_alive = false,
            });
        }
    }).apply, .{&socket_server});

    const request_bytes =
        "POST / HTTP/1.1\r\n" ++
        "Content-Type: text/plain\r\n" ++
        "Transfer-Encoding: chunked\r\n" ++
        "\r\n" ++
        "1\r\n" ++
        "A\r\n" ++
        "1\r\n" ++
        "B\r\n" ++
        "2\r\n" ++
        "CD\r\n" ++
        "0\r\n" ++
        "\r\n";

    const stream = try std.net.tcpConnectToHost(allocator, "127.0.0.1", server_port);
    defer stream.close();
    try stream.writeAll(request_bytes);

    server_thread.join();
}

test "echo content server" {
    if (builtin.single_threaded) return error.SkipZigTest;
    if (builtin.os.tag == .wasi) return error.SkipZigTest;

    if (builtin.zig_backend == .stage2_llvm and native_endian == .big) {
        // https://github.com/ziglang/zig/issues/13782
        return error.SkipZigTest;
    }

    const gpa = std.testing.allocator;

    const address = try std.net.Address.parseIp("127.0.0.1", 0);
    var socket_server = try address.listen(.{ .reuse_address = true });
    defer socket_server.deinit();
    const port = socket_server.listen_address.in.getPort();

    const server_thread = try std.Thread.spawn(.{}, (struct {
        fn handleRequest(request: *std.http.Server.Request) !void {
            std.debug.print("server received {s} {s} {s}\n", .{
                @tagName(request.head.method),
                @tagName(request.head.version),
                request.head.target,
            });

            const body = try request.reader().readAllAlloc(std.testing.allocator, 8192);
            defer std.testing.allocator.free(body);

            try testing.expect(std.mem.startsWith(u8, request.head.target, "/echo-content"));
            try testing.expectEqualStrings("Hello, World!\n", body);
            try testing.expectEqualStrings("text/plain", request.head.content_type.?);

            var send_buffer: [100]u8 = undefined;
            var response = request.respondStreaming(.{
                .send_buffer = &send_buffer,
                .content_length = switch (request.head.transfer_encoding) {
                    .chunked => null,
                    .none => len: {
                        try testing.expectEqual(14, request.head.content_length.?);
                        break :len 14;
                    },
                },
            });

            try response.flush(); // Test an early flush to send the HTTP headers before the body.
            const w = response.writer();
            try w.writeAll("Hello, ");
            try w.writeAll("World!\n");
            try response.end();
            std.debug.print("  server finished responding\n", .{});
        }

        fn run(net_server: *std.net.Server) anyerror!void {
            var read_buffer: [1024]u8 = undefined;

            accept: while (true) {
                const conn = try net_server.accept();
                defer conn.stream.close();

                var http_server = std.http.Server.init(conn, &read_buffer);

                while (http_server.state == .ready) {
                    var request = http_server.receiveHead() catch |err| switch (err) {
                        error.HttpConnectionClosing => continue :accept,
                        else => |e| return e,
                    };
                    if (std.mem.eql(u8, request.head.target, "/end")) {
                        return request.respond("", .{ .keep_alive = false });
                    }
                    handleRequest(&request) catch |err| {
                        // This message helps the person troubleshooting determine whether
                        // output comes from the server thread or the client thread.
                        std.debug.print("handleRequest failed with '{s}'\n", .{@errorName(err)});
                        return err;
                    };
                }
            }
        }
    }).run, .{&socket_server});

    defer server_thread.join();

    {
        var client: std.http.Client = .{ .allocator = gpa };
        defer client.deinit();

        try echoTests(&client, port);
    }
}

fn echoTests(client: *std.http.Client, port: u16) !void {
    const gpa = testing.allocator;
    var location_buffer: [100]u8 = undefined;

    { // send content-length request
        const location = try std.fmt.allocPrint(gpa, "http://127.0.0.1:{d}/echo-content", .{port});
        defer gpa.free(location);
        const uri = try std.Uri.parse(location);

        var server_header_buffer: [1024]u8 = undefined;
        var req = try client.open(.POST, uri, .{
            .server_header_buffer = &server_header_buffer,
            .extra_headers = &.{
                .{ .name = "content-type", .value = "text/plain" },
            },
        });
        defer req.deinit();

        req.transfer_encoding = .{ .content_length = 14 };

        try req.send(.{});
        try req.writeAll("Hello, ");
        try req.writeAll("World!\n");
        try req.finish();

        try req.wait();

        const body = try req.reader().readAllAlloc(gpa, 8192);
        defer gpa.free(body);

        try testing.expectEqualStrings("Hello, World!\n", body);
    }

    // connection has been kept alive
    try testing.expect(client.http_proxy != null or client.connection_pool.free_len == 1);

    { // send chunked request
        const uri = try std.Uri.parse(try std.fmt.bufPrint(
            &location_buffer,
            "http://127.0.0.1:{d}/echo-content",
            .{port},
        ));

        var server_header_buffer: [1024]u8 = undefined;
        var req = try client.open(.POST, uri, .{
            .server_header_buffer = &server_header_buffer,
            .extra_headers = &.{
                .{ .name = "content-type", .value = "text/plain" },
            },
        });
        defer req.deinit();

        req.transfer_encoding = .chunked;

        try req.send(.{});
        try req.writeAll("Hello, ");
        try req.writeAll("World!\n");
        try req.finish();

        try req.wait();

        const body = try req.reader().readAllAlloc(gpa, 8192);
        defer gpa.free(body);

        try testing.expectEqualStrings("Hello, World!\n", body);
    }

    // connection has been kept alive
    try testing.expect(client.http_proxy != null or client.connection_pool.free_len == 1);

    { // Client.fetch()

        const location = try std.fmt.allocPrint(gpa, "http://127.0.0.1:{d}/echo-content#fetch", .{port});
        defer gpa.free(location);

        var body = std.ArrayList(u8).init(gpa);
        defer body.deinit();

        const res = try client.fetch(.{
            .location = .{ .url = location },
            .method = .POST,
            .payload = "Hello, World!\n",
            .extra_headers = &.{
                .{ .name = "content-type", .value = "text/plain" },
            },
            .response_storage = .{ .dynamic = &body },
        });
        try testing.expectEqual(.ok, res.status);
        try testing.expectEqualStrings("Hello, World!\n", body.items);
    }

    { // expect: 100-continue
        const location = try std.fmt.allocPrint(gpa, "http://127.0.0.1:{d}/echo-content#expect-100", .{port});
        defer gpa.free(location);
        const uri = try std.Uri.parse(location);

        var server_header_buffer: [1024]u8 = undefined;
        var req = try client.open(.POST, uri, .{
            .server_header_buffer = &server_header_buffer,
            .extra_headers = &.{
                .{ .name = "expect", .value = "100-continue" },
                .{ .name = "content-type", .value = "text/plain" },
            },
        });
        defer req.deinit();

        req.transfer_encoding = .chunked;

        try req.send(.{});
        try req.writeAll("Hello, ");
        try req.writeAll("World!\n");
        try req.finish();

        try req.wait();
        try testing.expectEqual(.ok, req.response.status);

        const body = try req.reader().readAllAlloc(gpa, 8192);
        defer gpa.free(body);

        try testing.expectEqualStrings("Hello, World!\n", body);
    }

    { // expect: garbage
        const location = try std.fmt.allocPrint(gpa, "http://127.0.0.1:{d}/echo-content#expect-garbage", .{port});
        defer gpa.free(location);
        const uri = try std.Uri.parse(location);

        var server_header_buffer: [1024]u8 = undefined;
        var req = try client.open(.POST, uri, .{
            .server_header_buffer = &server_header_buffer,
            .extra_headers = &.{
                .{ .name = "content-type", .value = "text/plain" },
                .{ .name = "expect", .value = "garbage" },
            },
        });
        defer req.deinit();

        req.transfer_encoding = .chunked;

        try req.send(.{});
        try req.wait();
        try testing.expectEqual(.expectation_failed, req.response.status);
    }

    _ = try client.fetch(.{
        .location = .{
            .url = try std.fmt.bufPrint(&location_buffer, "http://127.0.0.1:{d}/end", .{port}),
        },
    });
}
