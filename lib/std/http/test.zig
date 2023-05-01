const std = @import("std");
const expect = std.testing.expect;

test "client requests server" {
    const builtin = @import("builtin");

    // This test requires spawning threads.
    if (builtin.single_threaded) {
        return error.SkipZigTest;
    }

    const native_endian = comptime builtin.cpu.arch.endian();
    if (builtin.zig_backend == .stage2_llvm and native_endian == .Big) {
        // https://github.com/ziglang/zig/issues/13782
        return error.SkipZigTest;
    }

    if (builtin.os.tag == .wasi) return error.SkipZigTest;

    const allocator = std.testing.allocator;

    const max_header_size = 8192;
    var server = std.http.Server.init(allocator, .{ .reuse_address = true });
    defer server.deinit();

    const address = try std.net.Address.parseIp("127.0.0.1", 0);
    try server.listen(address);
    const server_port = server.socket.listen_address.in.getPort();

    const server_thread = try std.Thread.spawn(.{}, (struct {
        fn apply(s: *std.http.Server) !void {
            const res = try s.accept(.{ .dynamic = max_header_size });
            defer res.deinit();
            defer res.reset();
            try res.wait();

            const server_body: []const u8 = "message from server!\n";
            res.transfer_encoding = .{ .content_length = server_body.len };
            try res.headers.append("content-type", "text/plain");
            try res.headers.append("connection", "close");
            try res.do();

            var buf: [128]u8 = undefined;
            const n = try res.readAll(&buf);
            try expect(std.mem.eql(u8, buf[0..n], "Hello, World!\n"));
            _ = try res.writer().writeAll(server_body);
            try res.finish();
        }
    }).apply, .{&server});

    var uri_buf: [22]u8 = undefined;
    const uri = try std.Uri.parse(try std.fmt.bufPrint(&uri_buf, "http://127.0.0.1:{d}", .{server_port}));
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();
    var client_headers = std.http.Headers{ .allocator = allocator };
    defer client_headers.deinit();
    var client_req = try client.request(.POST, uri, client_headers, .{});
    defer client_req.deinit();

    client_req.transfer_encoding = .{ .content_length = 14 }; // this will be checked to ensure you sent exactly 14 bytes
    try client_req.start(); // this sends the request
    try client_req.writeAll("Hello, ");
    try client_req.writeAll("World!\n");
    try client_req.finish();
    try client_req.wait(); // this waits for a response

    const body = try client_req.reader().readAllAlloc(allocator, 8192 * 1024);
    defer allocator.free(body);
    try expect(std.mem.eql(u8, body, "message from server!\n"));

    server_thread.join();
}
