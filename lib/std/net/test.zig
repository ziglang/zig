const std = @import("std");
const builtin = @import("builtin");
const net = std.net;
const mem = std.mem;
const testing = std.testing;

test "parse and render IP addresses at comptime" {
    comptime {
        const ipv6addr = net.Address.parseIp("::1", 0) catch unreachable;
        try std.testing.expectFmt("[::1]:0", "{f}", .{ipv6addr});

        const ipv4addr = net.Address.parseIp("127.0.0.1", 0) catch unreachable;
        try std.testing.expectFmt("127.0.0.1:0", "{f}", .{ipv4addr});

        try testing.expectError(error.InvalidIPAddressFormat, net.Address.parseIp("::123.123.123.123", 0));
        try testing.expectError(error.InvalidIPAddressFormat, net.Address.parseIp("127.01.0.1", 0));
        try testing.expectError(error.InvalidIPAddressFormat, net.Address.resolveIp("::123.123.123.123", 0));
        try testing.expectError(error.InvalidIPAddressFormat, net.Address.resolveIp("127.01.0.1", 0));
    }
}

test "format IPv6 address with no zero runs" {
    const addr = try std.net.Address.parseIp6("2001:db8:1:2:3:4:5:6", 0);
    try std.testing.expectFmt("[2001:db8:1:2:3:4:5:6]:0", "{f}", .{addr});
}

test "parse IPv6 addresses and check compressed form" {
    try std.testing.expectFmt("[2001:db8::1:0:0:2]:0", "{f}", .{
        try std.net.Address.parseIp6("2001:0db8:0000:0000:0001:0000:0000:0002", 0),
    });
    try std.testing.expectFmt("[2001:db8::1:2]:0", "{f}", .{
        try std.net.Address.parseIp6("2001:0db8:0000:0000:0000:0000:0001:0002", 0),
    });
    try std.testing.expectFmt("[2001:db8:1:0:1::2]:0", "{f}", .{
        try std.net.Address.parseIp6("2001:0db8:0001:0000:0001:0000:0000:0002", 0),
    });
}

test "parse IPv6 address, check raw bytes" {
    const expected_raw: [16]u8 = .{
        0x20, 0x01, 0x0d, 0xb8, // 2001:db8
        0x00, 0x00, 0x00, 0x00, // :0000:0000
        0x00, 0x01, 0x00, 0x00, // :0001:0000
        0x00, 0x00, 0x00, 0x02, // :0000:0002
    };

    const addr = try std.net.Address.parseIp6("2001:db8:0000:0000:0001:0000:0000:0002", 0);

    const actual_raw = addr.in6.sa.addr[0..];
    try std.testing.expectEqualSlices(u8, expected_raw[0..], actual_raw);
}

test "parse and render IPv6 addresses" {
    var buffer: [100]u8 = undefined;
    const ips = [_][]const u8{
        "FF01:0:0:0:0:0:0:FB",
        "FF01::Fb",
        "::1",
        "::",
        "1::",
        "2001:db8::",
        "::1234:5678",
        "2001:db8::1234:5678",
        "FF01::FB%1234",
        "::ffff:123.5.123.5",
    };
    const printed = [_][]const u8{
        "ff01::fb",
        "ff01::fb",
        "::1",
        "::",
        "1::",
        "2001:db8::",
        "::1234:5678",
        "2001:db8::1234:5678",
        "ff01::fb",
        "::ffff:123.5.123.5",
    };
    for (ips, 0..) |ip, i| {
        const addr = net.Address.parseIp6(ip, 0) catch unreachable;
        var newIp = std.fmt.bufPrint(buffer[0..], "{f}", .{addr}) catch unreachable;
        try std.testing.expect(std.mem.eql(u8, printed[i], newIp[1 .. newIp.len - 3]));

        if (builtin.os.tag == .linux) {
            const addr_via_resolve = net.Address.resolveIp6(ip, 0) catch unreachable;
            var newResolvedIp = std.fmt.bufPrint(buffer[0..], "{f}", .{addr_via_resolve}) catch unreachable;
            try std.testing.expect(std.mem.eql(u8, printed[i], newResolvedIp[1 .. newResolvedIp.len - 3]));
        }
    }

    try testing.expectError(error.InvalidCharacter, net.Address.parseIp6(":::", 0));
    try testing.expectError(error.Overflow, net.Address.parseIp6("FF001::FB", 0));
    try testing.expectError(error.InvalidCharacter, net.Address.parseIp6("FF01::Fb:zig", 0));
    try testing.expectError(error.InvalidEnd, net.Address.parseIp6("FF01:0:0:0:0:0:0:FB:", 0));
    try testing.expectError(error.Incomplete, net.Address.parseIp6("FF01:", 0));
    try testing.expectError(error.InvalidIpv4Mapping, net.Address.parseIp6("::123.123.123.123", 0));
    try testing.expectError(error.Incomplete, net.Address.parseIp6("1", 0));
    // TODO Make this test pass on other operating systems.
    if (builtin.os.tag == .linux or comptime builtin.os.tag.isDarwin() or builtin.os.tag == .windows) {
        try testing.expectError(error.Incomplete, net.Address.resolveIp6("ff01::fb%", 0));
        // Assumes IFNAMESIZE will always be a multiple of 2
        try testing.expectError(error.Overflow, net.Address.resolveIp6("ff01::fb%wlp3" ++ "s0" ** @divExact(std.posix.IFNAMESIZE - 4, 2), 0));
        try testing.expectError(error.Overflow, net.Address.resolveIp6("ff01::fb%12345678901234", 0));
    }
}

test "invalid but parseable IPv6 scope ids" {
    if (builtin.os.tag != .linux and comptime !builtin.os.tag.isDarwin() and builtin.os.tag != .windows) {
        // Currently, resolveIp6 with alphanumerical scope IDs only works on Linux.
        // TODO Make this test pass on other operating systems.
        return error.SkipZigTest;
    }

    try testing.expectError(error.InterfaceNotFound, net.Address.resolveIp6("ff01::fb%123s45678901234", 0));
}

test "parse and render IPv4 addresses" {
    var buffer: [18]u8 = undefined;
    for ([_][]const u8{
        "0.0.0.0",
        "255.255.255.255",
        "1.2.3.4",
        "123.255.0.91",
        "127.0.0.1",
    }) |ip| {
        const addr = net.Address.parseIp4(ip, 0) catch unreachable;
        var newIp = std.fmt.bufPrint(buffer[0..], "{f}", .{addr}) catch unreachable;
        try std.testing.expect(std.mem.eql(u8, ip, newIp[0 .. newIp.len - 2]));
    }

    try testing.expectError(error.Overflow, net.Address.parseIp4("256.0.0.1", 0));
    try testing.expectError(error.InvalidCharacter, net.Address.parseIp4("x.0.0.1", 0));
    try testing.expectError(error.InvalidEnd, net.Address.parseIp4("127.0.0.1.1", 0));
    try testing.expectError(error.Incomplete, net.Address.parseIp4("127.0.0.", 0));
    try testing.expectError(error.InvalidCharacter, net.Address.parseIp4("100..0.1", 0));
    try testing.expectError(error.NonCanonical, net.Address.parseIp4("127.01.0.1", 0));
}

test "parse and render UNIX addresses" {
    if (builtin.os.tag == .wasi) return error.SkipZigTest;
    if (!net.has_unix_sockets) return error.SkipZigTest;

    const addr = net.Address.initUnix("/tmp/testpath") catch unreachable;
    try std.testing.expectFmt("/tmp/testpath", "{f}", .{addr});

    const too_long = [_]u8{'a'} ** 200;
    try testing.expectError(error.NameTooLong, net.Address.initUnix(too_long[0..]));
}

test "resolve DNS" {
    if (builtin.os.tag == .wasi) return error.SkipZigTest;

    if (builtin.os.tag == .windows) {
        _ = try std.os.windows.WSAStartup(2, 2);
    }
    defer {
        if (builtin.os.tag == .windows) {
            std.os.windows.WSACleanup() catch unreachable;
        }
    }

    // Resolve localhost, this should not fail.
    {
        const localhost_v4 = try net.Address.parseIp("127.0.0.1", 80);
        const localhost_v6 = try net.Address.parseIp("::2", 80);

        const result = try net.getAddressList(testing.allocator, "localhost", 80);
        defer result.deinit();
        for (result.addrs) |addr| {
            if (addr.eql(localhost_v4) or addr.eql(localhost_v6)) break;
        } else @panic("unexpected address for localhost");
    }

    {
        // The tests are required to work even when there is no Internet connection,
        // so some of these errors we must accept and skip the test.
        const result = net.getAddressList(testing.allocator, "example.com", 80) catch |err| switch (err) {
            error.UnknownHostName => return error.SkipZigTest,
            error.TemporaryNameServerFailure => return error.SkipZigTest,
            else => return err,
        };
        result.deinit();
    }
}

test "listen on a port, send bytes, receive bytes" {
    if (builtin.single_threaded) return error.SkipZigTest;
    if (builtin.os.tag == .wasi) return error.SkipZigTest;

    if (builtin.os.tag == .windows) {
        _ = try std.os.windows.WSAStartup(2, 2);
    }
    defer {
        if (builtin.os.tag == .windows) {
            std.os.windows.WSACleanup() catch unreachable;
        }
    }

    // Try only the IPv4 variant as some CI builders have no IPv6 localhost
    // configured.
    const localhost = try net.Address.parseIp("127.0.0.1", 0);

    var server = try localhost.listen(.{});
    defer server.deinit();

    const S = struct {
        fn clientFn(server_address: net.Address) !void {
            const socket = try net.tcpConnectToAddress(server_address);
            defer socket.close();

            var stream_writer = socket.writer(&.{});
            try stream_writer.interface.writeAll("Hello world!");
        }
    };

    const t = try std.Thread.spawn(.{}, S.clientFn, .{server.listen_address});
    defer t.join();

    var client = try server.accept();
    defer client.stream.close();
    var buf: [16]u8 = undefined;
    var stream_reader = client.stream.reader(&.{});
    const n = try stream_reader.interface().readSliceShort(&buf);

    try testing.expectEqual(@as(usize, 12), n);
    try testing.expectEqualSlices(u8, "Hello world!", buf[0..n]);
}

test "listen on an in use port" {
    if (builtin.os.tag != .linux and comptime !builtin.os.tag.isDarwin() and builtin.os.tag != .windows) {
        // TODO build abstractions for other operating systems
        return error.SkipZigTest;
    }

    const localhost = try net.Address.parseIp("127.0.0.1", 0);

    var server1 = try localhost.listen(.{ .reuse_address = true });
    defer server1.deinit();

    var server2 = try server1.listen_address.listen(.{ .reuse_address = true });
    defer server2.deinit();
}

fn testClientToHost(allocator: mem.Allocator, name: []const u8, port: u16) anyerror!void {
    if (builtin.os.tag == .wasi) return error.SkipZigTest;

    const connection = try net.tcpConnectToHost(allocator, name, port);
    defer connection.close();

    var buf: [100]u8 = undefined;
    const len = try connection.read(&buf);
    const msg = buf[0..len];
    try testing.expect(mem.eql(u8, msg, "hello from server\n"));
}

fn testClient(addr: net.Address) anyerror!void {
    if (builtin.os.tag == .wasi) return error.SkipZigTest;

    const socket_file = try net.tcpConnectToAddress(addr);
    defer socket_file.close();

    var buf: [100]u8 = undefined;
    const len = try socket_file.read(&buf);
    const msg = buf[0..len];
    try testing.expect(mem.eql(u8, msg, "hello from server\n"));
}

fn testServer(server: *net.Server) anyerror!void {
    if (builtin.os.tag == .wasi) return error.SkipZigTest;

    var client = try server.accept();

    const stream = client.stream.writer();
    try stream.print("hello from server\n", .{});
}

test "listen on a unix socket, send bytes, receive bytes" {
    if (builtin.single_threaded) return error.SkipZigTest;
    if (!net.has_unix_sockets) return error.SkipZigTest;

    if (builtin.os.tag == .windows) {
        _ = try std.os.windows.WSAStartup(2, 2);
    }
    defer {
        if (builtin.os.tag == .windows) {
            std.os.windows.WSACleanup() catch unreachable;
        }
    }

    const socket_path = try generateFileName("socket.unix");
    defer testing.allocator.free(socket_path);

    const socket_addr = try net.Address.initUnix(socket_path);
    defer std.fs.cwd().deleteFile(socket_path) catch {};

    var server = try socket_addr.listen(.{});
    defer server.deinit();

    const S = struct {
        fn clientFn(path: []const u8) !void {
            const socket = try net.connectUnixSocket(path);
            defer socket.close();

            var stream_writer = socket.writer(&.{});
            try stream_writer.interface.writeAll("Hello world!");
        }
    };

    const t = try std.Thread.spawn(.{}, S.clientFn, .{socket_path});
    defer t.join();

    var client = try server.accept();
    defer client.stream.close();
    var buf: [16]u8 = undefined;
    var stream_reader = client.stream.reader(&.{});
    const n = try stream_reader.interface().readSliceShort(&buf);

    try testing.expectEqual(@as(usize, 12), n);
    try testing.expectEqualSlices(u8, "Hello world!", buf[0..n]);
}

test "listen on a unix socket with reuse_address option" {
    if (!net.has_unix_sockets) return error.SkipZigTest;
    // Windows doesn't implement reuse port option.
    if (builtin.os.tag == .windows) return error.SkipZigTest;

    const socket_path = try generateFileName("socket.unix");
    defer testing.allocator.free(socket_path);

    const socket_addr = try net.Address.initUnix(socket_path);
    defer std.fs.cwd().deleteFile(socket_path) catch {};

    var server = try socket_addr.listen(.{ .reuse_address = true });
    server.deinit();
}

fn generateFileName(base_name: []const u8) ![]const u8 {
    const random_bytes_count = 12;
    const sub_path_len = comptime std.fs.base64_encoder.calcSize(random_bytes_count);
    var random_bytes: [12]u8 = undefined;
    std.crypto.random.bytes(&random_bytes);
    var sub_path: [sub_path_len]u8 = undefined;
    _ = std.fs.base64_encoder.encode(&sub_path, &random_bytes);
    return std.fmt.allocPrint(testing.allocator, "{s}-{s}", .{ sub_path[0..], base_name });
}

test "non-blocking tcp server" {
    if (builtin.os.tag == .wasi) return error.SkipZigTest;
    if (true) {
        // https://github.com/ziglang/zig/issues/18315
        return error.SkipZigTest;
    }

    const localhost = try net.Address.parseIp("127.0.0.1", 0);
    var server = localhost.listen(.{ .force_nonblocking = true });
    defer server.deinit();

    const accept_err = server.accept();
    try testing.expectError(error.WouldBlock, accept_err);

    const socket_file = try net.tcpConnectToAddress(server.listen_address);
    defer socket_file.close();

    var client = try server.accept();
    defer client.stream.close();
    const stream = client.stream.writer();
    try stream.print("hello from server\n", .{});

    var buf: [100]u8 = undefined;
    const len = try socket_file.read(&buf);
    const msg = buf[0..len];
    try testing.expect(mem.eql(u8, msg, "hello from server\n"));
}
