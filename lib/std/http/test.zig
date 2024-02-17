const std = @import("std");

test "trailers" {
    const gpa = std.testing.allocator;

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

    var server_header_buffer: [1024]u8 = undefined;
    var req = try client.open(.GET, uri, .{
        .server_header_buffer = &server_header_buffer,
    });
    defer req.deinit();

    try req.send(.{});
    try req.wait();

    const body = try req.reader().readAllAlloc(gpa, 8192);
    defer gpa.free(body);

    try std.testing.expectEqualStrings("Hello, World!\n", body);
    if (true) @panic("TODO implement inspecting custom headers in responses");
    //try testing.expectEqualStrings("aaaa", req.response.headers.getFirstValue("x-checksum").?);

    // connection has been kept alive
    try std.testing.expect(client.connection_pool.free_len == 1);
}

fn serverThread(http_server: *std.http.Server) anyerror!void {
    const gpa = std.testing.allocator;

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

        try std.testing.expectEqual(.reset, res.reset());
    }
}

fn serve(res: *std.http.Server.Response) !void {
    try std.testing.expectEqualStrings(res.request.target, "/trailer");
    res.transfer_encoding = .chunked;

    try res.send();
    try res.writeAll("Hello, ");
    try res.writeAll("World!\n");
    // try res.finish();
    try res.connection.writeAll("0\r\nX-Checksum: aaaa\r\n\r\n");
}
