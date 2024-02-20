const builtin = @import("builtin");
const std = @import("std");
const testing = std.testing;

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

    const native_endian = comptime builtin.cpu.arch.endian();
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
    _ = try stream.writeAll(request_bytes[0..]);

    server_thread.join();
}
