const std = @import("std");
const testing = std.testing;

test "trailers" {
    const gpa = testing.allocator;

    var http_server = std.http.Server.init(.{
        .reuse_address = true,
    });
    const address = try std.net.Address.parseIp("127.0.0.1", 0);
    try http_server.listen(address);

    const port = http_server.socket.listen_address.in.getPort();

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

fn serverThread(http_server: *std.http.Server) anyerror!void {
    const gpa = testing.allocator;

    var header_buffer: [1024]u8 = undefined;
    var remaining: usize = 1;
    accept: while (remaining != 0) : (remaining -= 1) {
        var res = try http_server.accept(.{
            .allocator = gpa,
            .client_header_buffer = &header_buffer,
        });
        defer res.deinit();

        res.wait() catch |err| switch (err) {
            error.HttpHeadersInvalid => continue :accept,
            error.EndOfStream => continue,
            else => return err,
        };
        try serve(&res);

        try testing.expectEqual(.reset, res.reset());
    }
}

fn serve(res: *std.http.Server.Response) !void {
    try testing.expectEqualStrings(res.request.target, "/trailer");
    res.transfer_encoding = .chunked;

    try res.send();
    try res.writeAll("Hello, ");
    try res.writeAll("World!\n");
    try res.connection.writeAll("0\r\nX-Checksum: aaaa\r\n\r\n");
}
