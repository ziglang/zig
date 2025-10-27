const builtin = @import("builtin");

const std = @import("std");
const Io = std.Io;
const net = std.Io.net;
const mem = std.mem;
const testing = std.testing;

test "parse and render IP addresses at comptime" {
    comptime {
        const ipv6addr = net.IpAddress.parse("::1", 0) catch unreachable;
        try testing.expectFmt("[::1]:0", "{f}", .{ipv6addr});

        const ipv4addr = net.IpAddress.parse("127.0.0.1", 0) catch unreachable;
        try testing.expectFmt("127.0.0.1:0", "{f}", .{ipv4addr});

        try testing.expectError(error.ParseFailed, net.IpAddress.parse("::123.123.123.123", 0));
        try testing.expectError(error.ParseFailed, net.IpAddress.parse("127.01.0.1", 0));
    }
}

test "format IPv6 address with no zero runs" {
    const addr = try net.IpAddress.parseIp6("2001:db8:1:2:3:4:5:6", 0);
    try testing.expectFmt("[2001:db8:1:2:3:4:5:6]:0", "{f}", .{addr});
}

test "parse IPv6 addresses and check compressed form" {
    try testing.expectFmt("[2001:db8::1:0:0:2]:0", "{f}", .{
        try net.IpAddress.parseIp6("2001:0db8:0000:0000:0001:0000:0000:0002", 0),
    });
    try testing.expectFmt("[2001:db8::1:2]:0", "{f}", .{
        try net.IpAddress.parseIp6("2001:0db8:0000:0000:0000:0000:0001:0002", 0),
    });
    try testing.expectFmt("[2001:db8:1:0:1::2]:0", "{f}", .{
        try net.IpAddress.parseIp6("2001:0db8:0001:0000:0001:0000:0000:0002", 0),
    });
}

test "parse IPv6 address, check raw bytes" {
    const expected_raw: [16]u8 = .{
        0x20, 0x01, 0x0d, 0xb8, // 2001:db8
        0x00, 0x00, 0x00, 0x00, // :0000:0000
        0x00, 0x01, 0x00, 0x00, // :0001:0000
        0x00, 0x00, 0x00, 0x02, // :0000:0002
    };
    const addr = try net.IpAddress.parseIp6("2001:db8:0000:0000:0001:0000:0000:0002", 0);
    try testing.expectEqualSlices(u8, &expected_raw, &addr.ip6.bytes);
}

test "parse and render IPv6 addresses" {
    try testParseAndRenderIp6Address("FF01:0:0:0:0:0:0:FB", "ff01::fb");
    try testParseAndRenderIp6Address("FF01::Fb", "ff01::fb");
    try testParseAndRenderIp6Address("::1", "::1");
    try testParseAndRenderIp6Address("::", "::");
    try testParseAndRenderIp6Address("1::", "1::");
    try testParseAndRenderIp6Address("2001:db8::", "2001:db8::");
    try testParseAndRenderIp6Address("::1234:5678", "::1234:5678");
    try testParseAndRenderIp6Address("2001:db8::1234:5678", "2001:db8::1234:5678");
    try testParseAndRenderIp6Address("FF01::FB%1234", "ff01::fb%1234");
    try testParseAndRenderIp6Address("::ffff:123.5.123.5", "::ffff:123.5.123.5");
    try testParseAndRenderIp6Address("ff01::fb%12345678901234", "ff01::fb%12345678901234");
}

fn testParseAndRenderIp6Address(input: []const u8, expected_output: []const u8) !void {
    var buffer: [100]u8 = undefined;
    const parsed = net.Ip6Address.Unresolved.parse(input);
    const actual_printed = try std.fmt.bufPrint(&buffer, "{f}", .{parsed.success});
    try testing.expectEqualStrings(expected_output, actual_printed);
}

test "IPv6 address parse failures" {
    try testing.expectError(error.ParseFailed, net.IpAddress.parseIp6(":::", 0));

    const Unresolved = net.Ip6Address.Unresolved;

    try testing.expectEqual(Unresolved.Parsed{ .invalid_byte = 2 }, Unresolved.parse(":::"));
    try testing.expectEqual(Unresolved.Parsed{ .overflow = 4 }, Unresolved.parse("FF001::FB"));
    try testing.expectEqual(Unresolved.Parsed{ .invalid_byte = 9 }, Unresolved.parse("FF01::Fb:zig"));
    try testing.expectEqual(Unresolved.Parsed{ .junk_after_end = 19 }, Unresolved.parse("FF01:0:0:0:0:0:0:FB:"));
    try testing.expectEqual(Unresolved.Parsed.incomplete, Unresolved.parse("FF01:"));
    try testing.expectEqual(Unresolved.Parsed{ .invalid_byte = 5 }, Unresolved.parse("::123.123.123.123"));
    try testing.expectEqual(Unresolved.Parsed.incomplete, Unresolved.parse("1"));
    try testing.expectEqual(Unresolved.Parsed.incomplete, Unresolved.parse("ff01::fb%"));
}

test "invalid but parseable IPv6 scope ids" {
    const io = testing.io;

    if (builtin.os.tag != .linux and comptime !builtin.os.tag.isDarwin()) {
        return error.SkipZigTest; // TODO
    }

    try testing.expectError(error.InterfaceNotFound, net.IpAddress.resolveIp6(io, "ff01::fb%123s45678901234", 0));
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
        const addr = net.IpAddress.parseIp4(ip, 0) catch unreachable;
        var newIp = std.fmt.bufPrint(buffer[0..], "{f}", .{addr}) catch unreachable;
        try testing.expect(std.mem.eql(u8, ip, newIp[0 .. newIp.len - 2]));
    }

    try testing.expectError(error.Overflow, net.IpAddress.parseIp4("256.0.0.1", 0));
    try testing.expectError(error.InvalidCharacter, net.IpAddress.parseIp4("x.0.0.1", 0));
    try testing.expectError(error.InvalidEnd, net.IpAddress.parseIp4("127.0.0.1.1", 0));
    try testing.expectError(error.Incomplete, net.IpAddress.parseIp4("127.0.0.", 0));
    try testing.expectError(error.InvalidCharacter, net.IpAddress.parseIp4("100..0.1", 0));
    try testing.expectError(error.NonCanonical, net.IpAddress.parseIp4("127.01.0.1", 0));
}

test "resolve DNS" {
    if (builtin.os.tag == .wasi) return error.SkipZigTest;

    const io = testing.io;

    // Resolve localhost, this should not fail.
    {
        const localhost_v4 = try net.IpAddress.parse("127.0.0.1", 80);
        const localhost_v6 = try net.IpAddress.parse("::2", 80);

        var canonical_name_buffer: [net.HostName.max_len]u8 = undefined;
        var results_buffer: [32]net.HostName.LookupResult = undefined;
        var results: Io.Queue(net.HostName.LookupResult) = .init(&results_buffer);

        net.HostName.lookup(try .init("localhost"), io, &results, .{
            .port = 80,
            .canonical_name_buffer = &canonical_name_buffer,
        });

        var addresses_found: usize = 0;

        while (results.getOne(io)) |result| switch (result) {
            .address => |address| {
                if (address.eql(&localhost_v4) or address.eql(&localhost_v6))
                    addresses_found += 1;
            },
            .canonical_name => |canonical_name| try testing.expectEqualStrings("localhost", canonical_name.bytes),
            .end => |end| {
                try end;
                break;
            },
        } else |err| return err;

        try testing.expect(addresses_found != 0);
    }

    {
        // The tests are required to work even when there is no Internet connection,
        // so some of these errors we must accept and skip the test.
        var canonical_name_buffer: [net.HostName.max_len]u8 = undefined;
        var results_buffer: [16]net.HostName.LookupResult = undefined;
        var results: Io.Queue(net.HostName.LookupResult) = .init(&results_buffer);

        net.HostName.lookup(try .init("example.com"), io, &results, .{
            .port = 80,
            .canonical_name_buffer = &canonical_name_buffer,
        });

        while (results.getOne(io)) |result| switch (result) {
            .address => {},
            .canonical_name => {},
            .end => |end| {
                end catch |err| switch (err) {
                    error.UnknownHostName => return error.SkipZigTest,
                    error.NameServerFailure => return error.SkipZigTest,
                    else => return err,
                };
                break;
            },
        } else |err| return err;
    }
}

test "listen on a port, send bytes, receive bytes" {
    if (builtin.single_threaded) return error.SkipZigTest;
    if (builtin.os.tag == .wasi) return error.SkipZigTest;

    const io = testing.io;

    // Try only the IPv4 variant as some CI builders have no IPv6 localhost
    // configured.
    const localhost: net.IpAddress = .{ .ip4 = .loopback(0) };

    var server = try localhost.listen(io, .{});
    defer server.deinit(io);

    const S = struct {
        fn clientFn(server_address: net.IpAddress) !void {
            var stream = try server_address.connect(io, .{ .mode = .stream });
            defer stream.close(io);

            var stream_writer = stream.writer(io, &.{});
            try stream_writer.interface.writeAll("Hello world!");
        }
    };

    const t = try std.Thread.spawn(.{}, S.clientFn, .{server.socket.address});
    defer t.join();

    var stream = try server.accept(io);
    defer stream.close(io);
    var buf: [16]u8 = undefined;
    var stream_reader = stream.reader(io, &.{});
    const n = try stream_reader.interface.readSliceShort(&buf);

    try testing.expectEqual(@as(usize, 12), n);
    try testing.expectEqualSlices(u8, "Hello world!", buf[0..n]);
}

test "listen on an in use port" {
    if (builtin.os.tag != .linux and comptime !builtin.os.tag.isDarwin() and builtin.os.tag != .windows) {
        // TODO build abstractions for other operating systems
        return error.SkipZigTest;
    }

    const io = testing.io;

    const localhost: net.IpAddress = .{ .ip4 = .loopback(0) };

    var server1 = try localhost.listen(io, .{ .reuse_address = true });
    defer server1.deinit(io);

    var server2 = try server1.socket.address.listen(io, .{ .reuse_address = true });
    defer server2.deinit(io);
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

fn testClient(addr: net.IpAddress) anyerror!void {
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

    const io = testing.io;

    var stream = try server.accept(io);
    var writer = stream.writer(io, &.{});
    try writer.interface.print("hello from server\n", .{});
}

test "listen on a unix socket, send bytes, receive bytes" {
    if (builtin.single_threaded) return error.SkipZigTest;
    if (!net.has_unix_sockets) return error.SkipZigTest;

    const io = testing.io;

    const socket_path = try generateFileName("socket.unix");
    defer testing.allocator.free(socket_path);

    const socket_addr = try net.UnixAddress.init(socket_path);
    defer std.fs.cwd().deleteFile(socket_path) catch {};

    var server = try socket_addr.listen(io, .{});
    defer server.socket.close(io);

    const S = struct {
        fn clientFn(path: []const u8) !void {
            const server_path: net.UnixAddress = try .init(path);
            var stream = try server_path.connect(io);
            defer stream.close(io);

            var stream_writer = stream.writer(io, &.{});
            try stream_writer.interface.writeAll("Hello world!");
        }
    };

    const t = try std.Thread.spawn(.{}, S.clientFn, .{socket_path});
    defer t.join();

    var stream = try server.accept(io);
    defer stream.close(io);
    var buf: [16]u8 = undefined;
    var stream_reader = stream.reader(io, &.{});
    const n = try stream_reader.interface.readSliceShort(&buf);

    try testing.expectEqual(@as(usize, 12), n);
    try testing.expectEqualSlices(u8, "Hello world!", buf[0..n]);
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

    const io = testing.io;

    const localhost: net.IpAddress = .{ .ip4 = .loopback(0) };
    var server = localhost.listen(io, .{ .force_nonblocking = true });
    defer server.deinit(io);

    const accept_err = server.accept(io);
    try testing.expectError(error.WouldBlock, accept_err);

    const socket_file = try net.tcpConnectToAddress(server.socket.address);
    defer socket_file.close();

    var stream = try server.accept(io);
    defer stream.close(io);
    var writer = stream.writer(io, .{});
    try writer.interface.print("hello from server\n", .{});

    var buf: [100]u8 = undefined;
    const len = try socket_file.read(&buf);
    const msg = buf[0..len];
    try testing.expect(mem.eql(u8, msg, "hello from server\n"));
}
