const std = @import("../std.zig");
const net = std.net;
const mem = std.mem;
const testing = std.testing;

test "std.net.parseIp4" {
    testing.expect((try net.parseIp4("127.0.0.1")) == mem.bigToNative(u32, 0x7f000001));

    testParseIp4Fail("256.0.0.1", error.Overflow);
    testParseIp4Fail("x.0.0.1", error.InvalidCharacter);
    testParseIp4Fail("127.0.0.1.1", error.InvalidEnd);
    testParseIp4Fail("127.0.0.", error.Incomplete);
    testParseIp4Fail("100..0.1", error.InvalidCharacter);
}

fn testParseIp4Fail(buf: []const u8, expected_err: anyerror) void {
    if (net.parseIp4(buf)) |_| {
        @panic("expected error");
    } else |e| {
        testing.expect(e == expected_err);
    }
}

test "std.net.parseIp6" {
    const ip6 = try net.parseIp6("FF01:0:0:0:0:0:0:FB");
    const addr = net.Address.initIp6(ip6, 80);
    var buf: [100]u8 = undefined;
    const printed = try std.fmt.bufPrint(&buf, "{}", addr);
    std.testing.expect(mem.eql(u8, "[ff01::fb]:80", printed));
}

test "resolve DNS" {
    if (std.builtin.os == .windows) {
        // DNS resolution not implemented on Windows yet.
        return error.SkipZigTest;
    }
    var buf: [1000 * 10]u8 = undefined;
    const a = &std.heap.FixedBufferAllocator.init(&buf).allocator;

    const address_list = net.getAddressList(a, "example.com", 80) catch |err| switch (err) {
        // The tests are required to work even when there is no Internet connection,
        // so some of these errors we must accept and skip the test.
        error.UnknownHostName => return error.SkipZigTest,
        error.TemporaryNameServerFailure => return error.SkipZigTest,
        else => return err,
    };
    address_list.deinit();
}

test "listen on a port, send bytes, receive bytes" {
    if (std.builtin.os != .linux) {
        // TODO build abstractions for other operating systems
        return error.SkipZigTest;
    }
    if (std.io.mode != .evented) {
        // TODO add ability to run tests in non-blocking I/O mode
        return error.SkipZigTest;
    }

    // TODO doing this at comptime crashed the compiler
    const localhost = net.Address.initIp4(net.parseIp4("127.0.0.1") catch unreachable, 0);

    var server = net.TcpServer.init(net.TcpServer.Options{});
    defer server.deinit();
    try server.listen(localhost);

    var server_frame = async testServer(&server);
    var client_frame = async testClient(server.listen_address);

    try await server_frame;
    try await client_frame;
}

fn testClient(addr: net.Address) anyerror!void {
    const socket_file = try net.tcpConnectToAddress(addr);
    defer socket_file.close();

    var buf: [100]u8 = undefined;
    const len = try socket_file.read(&buf);
    const msg = buf[0..len];
    testing.expect(mem.eql(u8, msg, "hello from server\n"));
}

fn testServer(server: *net.TcpServer) anyerror!void {
    var client_file = try server.accept();

    const stream = &client_file.outStream().stream;
    try stream.print("hello from server\n");
}
