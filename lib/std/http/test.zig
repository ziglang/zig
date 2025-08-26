const builtin = @import("builtin");
const std = @import("std");
const http = std.http;
const mem = std.mem;
const native_endian = builtin.cpu.arch.endian();
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;
const expectError = std.testing.expectError;

test "trailers" {
    const test_server = try createTestServer(struct {
        fn run(test_server: *TestServer) anyerror!void {
            const net_server = &test_server.net_server;
            var recv_buffer: [1024]u8 = undefined;
            var send_buffer: [1024]u8 = undefined;
            var remaining: usize = 1;
            while (remaining != 0) : (remaining -= 1) {
                const connection = try net_server.accept();
                defer connection.stream.close();

                var connection_br = connection.stream.reader(&recv_buffer);
                var connection_bw = connection.stream.writer(&send_buffer);
                var server = http.Server.init(connection_br.interface(), &connection_bw.interface);

                try expectEqual(.ready, server.reader.state);
                var request = try server.receiveHead();
                try serve(&request);
                try expectEqual(.ready, server.reader.state);
            }
        }

        fn serve(request: *http.Server.Request) !void {
            try expectEqualStrings(request.head.target, "/trailer");

            var response = try request.respondStreaming(&.{}, .{});
            try response.writer.writeAll("Hello, ");
            try response.flush();
            try response.writer.writeAll("World!\n");
            try response.flush();
            try response.endChunked(.{
                .trailers = &.{
                    .{ .name = "X-Checksum", .value = "aaaa" },
                },
            });
        }
    });
    defer test_server.destroy();

    const gpa = std.testing.allocator;

    var client: http.Client = .{ .allocator = gpa };
    defer client.deinit();

    const location = try std.fmt.allocPrint(gpa, "http://127.0.0.1:{d}/trailer", .{
        test_server.port(),
    });
    defer gpa.free(location);
    const uri = try std.Uri.parse(location);

    {
        var req = try client.request(.GET, uri, .{});
        defer req.deinit();

        try req.sendBodiless();
        var response = try req.receiveHead(&.{});

        {
            var it = response.head.iterateHeaders();
            const header = it.next().?;
            try expectEqualStrings("transfer-encoding", header.name);
            try expectEqualStrings("chunked", header.value);
            try expectEqual(null, it.next());
        }

        const body = try response.reader(&.{}).allocRemaining(gpa, .unlimited);
        defer gpa.free(body);

        try expectEqualStrings("Hello, World!\n", body);

        {
            var it = response.iterateTrailers();
            const header = it.next().?;
            try expectEqualStrings("X-Checksum", header.name);
            try expectEqualStrings("aaaa", header.value);
            try expectEqual(null, it.next());
        }
    }

    // connection has been kept alive
    try expect(client.connection_pool.free_len == 1);
}

test "HTTP server handles a chunked transfer coding request" {
    const test_server = try createTestServer(struct {
        fn run(test_server: *TestServer) anyerror!void {
            const net_server = &test_server.net_server;
            var recv_buffer: [8192]u8 = undefined;
            var send_buffer: [500]u8 = undefined;
            const connection = try net_server.accept();
            defer connection.stream.close();

            var connection_br = connection.stream.reader(&recv_buffer);
            var connection_bw = connection.stream.writer(&send_buffer);
            var server = http.Server.init(connection_br.interface(), &connection_bw.interface);
            var request = try server.receiveHead();

            try expect(request.head.transfer_encoding == .chunked);

            var buf: [128]u8 = undefined;
            var br = try request.readerExpectContinue(&.{});
            const n = try br.readSliceShort(&buf);
            try expectEqualStrings("ABCD", buf[0..n]);

            try request.respond("message from server!\n", .{
                .extra_headers = &.{
                    .{ .name = "content-type", .value = "text/plain" },
                },
                .keep_alive = false,
            });
        }
    });
    defer test_server.destroy();

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

    const gpa = std.testing.allocator;
    const stream = try std.net.tcpConnectToHost(gpa, "127.0.0.1", test_server.port());
    defer stream.close();
    var stream_writer = stream.writer(&.{});
    try stream_writer.interface.writeAll(request_bytes);

    const expected_response =
        "HTTP/1.1 200 OK\r\n" ++
        "connection: close\r\n" ++
        "content-length: 21\r\n" ++
        "content-type: text/plain\r\n" ++
        "\r\n" ++
        "message from server!\n";
    var stream_reader = stream.reader(&.{});
    const response = try stream_reader.interface().allocRemaining(gpa, .limited(expected_response.len + 1));
    defer gpa.free(response);
    try expectEqualStrings(expected_response, response);
}

test "echo content server" {
    const test_server = try createTestServer(struct {
        fn run(test_server: *TestServer) anyerror!void {
            const net_server = &test_server.net_server;
            var recv_buffer: [1024]u8 = undefined;
            var send_buffer: [100]u8 = undefined;

            accept: while (!test_server.shutting_down) {
                const connection = try net_server.accept();
                defer connection.stream.close();

                var connection_br = connection.stream.reader(&recv_buffer);
                var connection_bw = connection.stream.writer(&send_buffer);
                var http_server = http.Server.init(connection_br.interface(), &connection_bw.interface);

                while (http_server.reader.state == .ready) {
                    var request = http_server.receiveHead() catch |err| switch (err) {
                        error.HttpConnectionClosing => continue :accept,
                        else => |e| return e,
                    };
                    if (mem.eql(u8, request.head.target, "/end")) {
                        return request.respond("", .{ .keep_alive = false });
                    }
                    if (request.head.expect) |expect_header_value| {
                        if (mem.eql(u8, expect_header_value, "garbage")) {
                            try expectError(error.HttpExpectationFailed, request.readerExpectContinue(&.{}));
                            request.head.expect = null;
                            try request.respond("", .{
                                .keep_alive = false,
                                .status = .expectation_failed,
                            });
                            continue;
                        }
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

        fn handleRequest(request: *http.Server.Request) !void {
            //std.debug.print("server received {s} {s} {s}\n", .{
            //    @tagName(request.head.method),
            //    @tagName(request.head.version),
            //    request.head.target,
            //});

            try expect(mem.startsWith(u8, request.head.target, "/echo-content"));
            try expectEqualStrings("text/plain", request.head.content_type.?);

            // head strings expire here
            const body = try (try request.readerExpectContinue(&.{})).allocRemaining(std.testing.allocator, .unlimited);
            defer std.testing.allocator.free(body);

            try expectEqualStrings("Hello, World!\n", body);

            var response = try request.respondStreaming(&.{}, .{
                .content_length = switch (request.head.transfer_encoding) {
                    .chunked => null,
                    .none => len: {
                        try expectEqual(14, request.head.content_length.?);
                        break :len 14;
                    },
                },
            });
            try response.flush(); // Test an early flush to send the HTTP headers before the body.
            const w = &response.writer;
            try w.writeAll("Hello, ");
            try w.writeAll("World!\n");
            try response.end();
            //std.debug.print("  server finished responding\n", .{});
        }
    });
    defer test_server.destroy();

    {
        var client: http.Client = .{ .allocator = std.testing.allocator };
        defer client.deinit();

        try echoTests(&client, test_server.port());
    }
}

test "Server.Request.respondStreaming non-chunked, unknown content-length" {
    if (builtin.os.tag == .windows) {
        // https://github.com/ziglang/zig/issues/21457
        return error.SkipZigTest;
    }

    // In this case, the response is expected to stream until the connection is
    // closed, indicating the end of the body.
    const test_server = try createTestServer(struct {
        fn run(test_server: *TestServer) anyerror!void {
            const net_server = &test_server.net_server;
            var recv_buffer: [1000]u8 = undefined;
            var send_buffer: [500]u8 = undefined;
            var remaining: usize = 1;
            while (remaining != 0) : (remaining -= 1) {
                const connection = try net_server.accept();
                defer connection.stream.close();

                var connection_br = connection.stream.reader(&recv_buffer);
                var connection_bw = connection.stream.writer(&send_buffer);
                var server = http.Server.init(connection_br.interface(), &connection_bw.interface);

                try expectEqual(.ready, server.reader.state);
                var request = try server.receiveHead();
                try expectEqualStrings(request.head.target, "/foo");
                var buf: [30]u8 = undefined;
                var response = try request.respondStreaming(&buf, .{
                    .respond_options = .{
                        .transfer_encoding = .none,
                    },
                });
                const w = &response.writer;
                for (0..500) |i| {
                    try w.print("{d}, ah ha ha!\n", .{i});
                }
                try w.flush();
                try response.end();
                try expectEqual(.closing, server.reader.state);
            }
        }
    });
    defer test_server.destroy();

    const request_bytes = "GET /foo HTTP/1.1\r\n\r\n";
    const gpa = std.testing.allocator;
    const stream = try std.net.tcpConnectToHost(gpa, "127.0.0.1", test_server.port());
    defer stream.close();
    var stream_writer = stream.writer(&.{});
    try stream_writer.interface.writeAll(request_bytes);

    var stream_reader = stream.reader(&.{});
    const response = try stream_reader.interface().allocRemaining(gpa, .unlimited);
    defer gpa.free(response);

    var expected_response = std.array_list.Managed(u8).init(gpa);
    defer expected_response.deinit();

    try expected_response.appendSlice("HTTP/1.1 200 OK\r\nconnection: close\r\n\r\n");

    {
        var total: usize = 0;
        for (0..500) |i| {
            var buf: [30]u8 = undefined;
            const line = try std.fmt.bufPrint(&buf, "{d}, ah ha ha!\n", .{i});
            try expected_response.appendSlice(line);
            total += line.len;
        }
        try expectEqual(7390, total);
    }

    try expectEqualStrings(expected_response.items, response);
}

test "receiving arbitrary http headers from the client" {
    const test_server = try createTestServer(struct {
        fn run(test_server: *TestServer) anyerror!void {
            const net_server = &test_server.net_server;
            var recv_buffer: [666]u8 = undefined;
            var send_buffer: [777]u8 = undefined;
            var remaining: usize = 1;
            while (remaining != 0) : (remaining -= 1) {
                const connection = try net_server.accept();
                defer connection.stream.close();

                var connection_br = connection.stream.reader(&recv_buffer);
                var connection_bw = connection.stream.writer(&send_buffer);
                var server = http.Server.init(connection_br.interface(), &connection_bw.interface);

                try expectEqual(.ready, server.reader.state);
                var request = try server.receiveHead();
                try expectEqualStrings("/bar", request.head.target);
                var it = request.iterateHeaders();
                {
                    const header = it.next().?;
                    try expectEqualStrings("CoNneCtIoN", header.name);
                    try expectEqualStrings("close", header.value);
                    try expect(!it.is_trailer);
                }
                {
                    const header = it.next().?;
                    try expectEqualStrings("aoeu", header.name);
                    try expectEqualStrings("asdf", header.value);
                    try expect(!it.is_trailer);
                }
                try request.respond("", .{});
            }
        }
    });
    defer test_server.destroy();

    const request_bytes = "GET /bar HTTP/1.1\r\n" ++
        "CoNneCtIoN:close\r\n" ++
        "aoeu:  asdf \r\n" ++
        "\r\n";
    const gpa = std.testing.allocator;
    const stream = try std.net.tcpConnectToHost(gpa, "127.0.0.1", test_server.port());
    defer stream.close();
    var stream_writer = stream.writer(&.{});
    try stream_writer.interface.writeAll(request_bytes);

    var stream_reader = stream.reader(&.{});
    const response = try stream_reader.interface().allocRemaining(gpa, .unlimited);
    defer gpa.free(response);

    var expected_response = std.array_list.Managed(u8).init(gpa);
    defer expected_response.deinit();

    try expected_response.appendSlice("HTTP/1.1 200 OK\r\n");
    try expected_response.appendSlice("connection: close\r\n");
    try expected_response.appendSlice("content-length: 0\r\n\r\n");
    try expectEqualStrings(expected_response.items, response);
}

test "general client/server API coverage" {
    if (builtin.os.tag == .windows) {
        // This test was never passing on Windows.
        return error.SkipZigTest;
    }

    const test_server = try createTestServer(struct {
        fn run(test_server: *TestServer) anyerror!void {
            const net_server = &test_server.net_server;
            var recv_buffer: [1024]u8 = undefined;
            var send_buffer: [100]u8 = undefined;

            outer: while (!test_server.shutting_down) {
                var connection = try net_server.accept();
                defer connection.stream.close();

                var connection_br = connection.stream.reader(&recv_buffer);
                var connection_bw = connection.stream.writer(&send_buffer);
                var http_server = http.Server.init(connection_br.interface(), &connection_bw.interface);

                while (http_server.reader.state == .ready) {
                    var request = http_server.receiveHead() catch |err| switch (err) {
                        error.HttpConnectionClosing => continue :outer,
                        else => |e| return e,
                    };

                    try handleRequest(&request, net_server.listen_address.getPort());
                }
            }
        }

        fn handleRequest(request: *http.Server.Request, listen_port: u16) !void {
            const log = std.log.scoped(.server);
            const gpa = std.testing.allocator;

            log.info("{t} {t} {s}", .{ request.head.method, request.head.version, request.head.target });
            const target = try gpa.dupe(u8, request.head.target);
            defer gpa.free(target);

            const reader = (try request.readerExpectContinue(&.{}));
            const body = try reader.allocRemaining(gpa, .unlimited);
            defer gpa.free(body);

            if (mem.startsWith(u8, target, "/get")) {
                var response = try request.respondStreaming(&.{}, .{
                    .content_length = if (mem.indexOf(u8, target, "?chunked") == null)
                        14
                    else
                        null,
                    .respond_options = .{
                        .extra_headers = &.{
                            .{ .name = "content-type", .value = "text/plain" },
                        },
                    },
                });
                const w = &response.writer;
                try w.writeAll("Hello, ");
                try w.writeAll("World!\n");
                try response.end();
                // Writing again would cause an assertion failure.
            } else if (mem.startsWith(u8, target, "/large")) {
                var response = try request.respondStreaming(&.{}, .{
                    .content_length = 14 * 1024 + 14 * 10,
                });

                try response.flush(); // Test an early flush to send the HTTP headers before the body.

                const w = &response.writer;

                var i: u32 = 0;
                while (i < 5) : (i += 1) {
                    try w.writeAll("Hello, World!\n");
                }

                var vec: [1][]const u8 = .{"Hello, World!\n"};
                try w.writeSplatAll(&vec, 1024);

                i = 0;
                while (i < 5) : (i += 1) {
                    try w.writeAll("Hello, World!\n");
                }

                try response.end();
            } else if (mem.eql(u8, target, "/redirect/1")) {
                var response = try request.respondStreaming(&.{}, .{
                    .respond_options = .{
                        .status = .found,
                        .extra_headers = &.{
                            .{ .name = "location", .value = "../../get" },
                        },
                    },
                });

                const w = &response.writer;
                try w.writeAll("Hello, ");
                try w.writeAll("Redirected!\n");
                try response.end();
            } else if (mem.eql(u8, target, "/redirect/2")) {
                try request.respond("Hello, Redirected!\n", .{
                    .status = .found,
                    .extra_headers = &.{
                        .{ .name = "location", .value = "/redirect/1" },
                    },
                });
            } else if (mem.eql(u8, target, "/redirect/3")) {
                const location = try std.fmt.allocPrint(gpa, "http://127.0.0.1:{d}/redirect/2", .{
                    listen_port,
                });
                defer gpa.free(location);

                try request.respond("Hello, Redirected!\n", .{
                    .status = .found,
                    .extra_headers = &.{
                        .{ .name = "location", .value = location },
                    },
                });
            } else if (mem.eql(u8, target, "/redirect/4")) {
                try request.respond("Hello, Redirected!\n", .{
                    .status = .found,
                    .extra_headers = &.{
                        .{ .name = "location", .value = "/redirect/3" },
                    },
                });
            } else if (mem.eql(u8, target, "/redirect/5")) {
                try request.respond("Hello, Redirected!\n", .{
                    .status = .found,
                    .extra_headers = &.{
                        .{ .name = "location", .value = "/%2525" },
                    },
                });
            } else if (mem.eql(u8, target, "/%2525")) {
                try request.respond("Encoded redirect successful!\n", .{});
            } else if (mem.eql(u8, target, "/redirect/invalid")) {
                const invalid_port = try getUnusedTcpPort();
                const location = try std.fmt.allocPrint(gpa, "http://127.0.0.1:{d}", .{invalid_port});
                defer gpa.free(location);

                try request.respond("", .{
                    .status = .found,
                    .extra_headers = &.{
                        .{ .name = "location", .value = location },
                    },
                });
            } else if (mem.eql(u8, target, "/empty")) {
                try request.respond("", .{
                    .extra_headers = &.{
                        .{ .name = "empty", .value = "" },
                    },
                });
            } else {
                try request.respond("", .{ .status = .not_found });
            }
        }

        fn getUnusedTcpPort() !u16 {
            const addr = try std.net.Address.parseIp("127.0.0.1", 0);
            var s = try addr.listen(.{});
            defer s.deinit();
            return s.listen_address.in.getPort();
        }
    });
    defer test_server.destroy();

    const log = std.log.scoped(.client);

    const gpa = std.testing.allocator;
    var client: http.Client = .{ .allocator = gpa };
    defer client.deinit();

    const port = test_server.port();

    { // read content-length response
        const location = try std.fmt.allocPrint(gpa, "http://127.0.0.1:{d}/get", .{port});
        defer gpa.free(location);
        const uri = try std.Uri.parse(location);

        log.info("{s}", .{location});
        var redirect_buffer: [1024]u8 = undefined;
        var req = try client.request(.GET, uri, .{});
        defer req.deinit();

        try req.sendBodiless();
        var response = try req.receiveHead(&redirect_buffer);

        try expectEqualStrings("text/plain", response.head.content_type.?);

        const body = try response.reader(&.{}).allocRemaining(gpa, .unlimited);
        defer gpa.free(body);

        try expectEqualStrings("Hello, World!\n", body);
    }

    // connection has been kept alive
    try expect(client.http_proxy != null or client.connection_pool.free_len == 1);

    { // read large content-length response
        const location = try std.fmt.allocPrint(gpa, "http://127.0.0.1:{d}/large", .{port});
        defer gpa.free(location);
        const uri = try std.Uri.parse(location);

        log.info("{s}", .{location});
        var redirect_buffer: [1024]u8 = undefined;
        var req = try client.request(.GET, uri, .{});
        defer req.deinit();

        try req.sendBodiless();
        var response = try req.receiveHead(&redirect_buffer);

        const body = try response.reader(&.{}).allocRemaining(gpa, .unlimited);
        defer gpa.free(body);

        try expectEqual(@as(usize, 14 * 1024 + 14 * 10), body.len);
    }

    // connection has been kept alive
    try expect(client.http_proxy != null or client.connection_pool.free_len == 1);

    { // send head request and not read chunked
        const location = try std.fmt.allocPrint(gpa, "http://127.0.0.1:{d}/get", .{port});
        defer gpa.free(location);
        const uri = try std.Uri.parse(location);

        log.info("{s}", .{location});
        var redirect_buffer: [1024]u8 = undefined;
        var req = try client.request(.HEAD, uri, .{});
        defer req.deinit();

        try req.sendBodiless();
        var response = try req.receiveHead(&redirect_buffer);

        try expectEqualStrings("text/plain", response.head.content_type.?);
        try expectEqual(14, response.head.content_length.?);

        const body = try response.reader(&.{}).allocRemaining(gpa, .unlimited);
        defer gpa.free(body);

        try expectEqualStrings("", body);
    }

    // connection has been kept alive
    try expect(client.http_proxy != null or client.connection_pool.free_len == 1);

    { // read chunked response
        const location = try std.fmt.allocPrint(gpa, "http://127.0.0.1:{d}/get?chunked", .{port});
        defer gpa.free(location);
        const uri = try std.Uri.parse(location);

        log.info("{s}", .{location});
        var redirect_buffer: [1024]u8 = undefined;
        var req = try client.request(.GET, uri, .{});
        defer req.deinit();

        try req.sendBodiless();
        var response = try req.receiveHead(&redirect_buffer);

        try expectEqualStrings("text/plain", response.head.content_type.?);

        const body = try response.reader(&.{}).allocRemaining(gpa, .unlimited);
        defer gpa.free(body);

        try expectEqualStrings("Hello, World!\n", body);
    }

    // connection has been kept alive
    try expect(client.http_proxy != null or client.connection_pool.free_len == 1);

    { // send head request and not read chunked
        const location = try std.fmt.allocPrint(gpa, "http://127.0.0.1:{d}/get?chunked", .{port});
        defer gpa.free(location);
        const uri = try std.Uri.parse(location);

        log.info("{s}", .{location});
        var redirect_buffer: [1024]u8 = undefined;
        var req = try client.request(.HEAD, uri, .{});
        defer req.deinit();

        try req.sendBodiless();
        var response = try req.receiveHead(&redirect_buffer);

        try expectEqualStrings("text/plain", response.head.content_type.?);
        try expect(response.head.transfer_encoding == .chunked);

        const body = try response.reader(&.{}).allocRemaining(gpa, .unlimited);
        defer gpa.free(body);

        try expectEqualStrings("", body);
    }

    // connection has been kept alive
    try expect(client.http_proxy != null or client.connection_pool.free_len == 1);

    { // read content-length response with connection close
        const location = try std.fmt.allocPrint(gpa, "http://127.0.0.1:{d}/get", .{port});
        defer gpa.free(location);
        const uri = try std.Uri.parse(location);

        log.info("{s}", .{location});
        var redirect_buffer: [1024]u8 = undefined;
        var req = try client.request(.GET, uri, .{
            .keep_alive = false,
        });
        defer req.deinit();

        try req.sendBodiless();
        var response = try req.receiveHead(&redirect_buffer);

        try expectEqualStrings("text/plain", response.head.content_type.?);

        const body = try response.reader(&.{}).allocRemaining(gpa, .unlimited);
        defer gpa.free(body);

        try expectEqualStrings("Hello, World!\n", body);
    }

    // connection has been closed
    try expect(client.connection_pool.free_len == 0);

    { // handle empty header field value
        const location = try std.fmt.allocPrint(gpa, "http://127.0.0.1:{d}/empty", .{port});
        defer gpa.free(location);
        const uri = try std.Uri.parse(location);

        log.info("{s}", .{location});
        var redirect_buffer: [1024]u8 = undefined;
        var req = try client.request(.GET, uri, .{
            .extra_headers = &.{
                .{ .name = "empty", .value = "" },
            },
        });
        defer req.deinit();

        try req.sendBodiless();
        var response = try req.receiveHead(&redirect_buffer);

        try std.testing.expectEqual(.ok, response.head.status);

        var it = response.head.iterateHeaders();
        {
            const header = it.next().?;
            try expect(!it.is_trailer);
            try expectEqualStrings("content-length", header.name);
            try expectEqualStrings("0", header.value);
        }

        const body = try response.reader(&.{}).allocRemaining(gpa, .unlimited);
        defer gpa.free(body);

        try expectEqualStrings("", body);

        {
            const header = it.next().?;
            try expect(!it.is_trailer);
            try expectEqualStrings("empty", header.name);
            try expectEqualStrings("", header.value);
        }
        try expectEqual(null, it.next());
    }

    // connection has been kept alive
    try expect(client.http_proxy != null or client.connection_pool.free_len == 1);

    { // relative redirect
        const location = try std.fmt.allocPrint(gpa, "http://127.0.0.1:{d}/redirect/1", .{port});
        defer gpa.free(location);
        const uri = try std.Uri.parse(location);

        log.info("{s}", .{location});
        var redirect_buffer: [1024]u8 = undefined;
        var req = try client.request(.GET, uri, .{});
        defer req.deinit();

        try req.sendBodiless();
        var response = try req.receiveHead(&redirect_buffer);

        const body = try response.reader(&.{}).allocRemaining(gpa, .unlimited);
        defer gpa.free(body);

        try expectEqualStrings("Hello, World!\n", body);
    }

    // connection has been kept alive
    try expect(client.http_proxy != null or client.connection_pool.free_len == 1);

    { // redirect from root
        const location = try std.fmt.allocPrint(gpa, "http://127.0.0.1:{d}/redirect/2", .{port});
        defer gpa.free(location);
        const uri = try std.Uri.parse(location);

        log.info("{s}", .{location});
        var redirect_buffer: [1024]u8 = undefined;
        var req = try client.request(.GET, uri, .{});
        defer req.deinit();

        try req.sendBodiless();
        var response = try req.receiveHead(&redirect_buffer);

        const body = try response.reader(&.{}).allocRemaining(gpa, .unlimited);
        defer gpa.free(body);

        try expectEqualStrings("Hello, World!\n", body);
    }

    // connection has been kept alive
    try expect(client.http_proxy != null or client.connection_pool.free_len == 1);

    { // absolute redirect
        const location = try std.fmt.allocPrint(gpa, "http://127.0.0.1:{d}/redirect/3", .{port});
        defer gpa.free(location);
        const uri = try std.Uri.parse(location);

        log.info("{s}", .{location});
        var redirect_buffer: [1024]u8 = undefined;
        var req = try client.request(.GET, uri, .{});
        defer req.deinit();

        try req.sendBodiless();
        var response = try req.receiveHead(&redirect_buffer);

        const body = try response.reader(&.{}).allocRemaining(gpa, .unlimited);
        defer gpa.free(body);

        try expectEqualStrings("Hello, World!\n", body);
    }

    // connection has been kept alive
    try expect(client.http_proxy != null or client.connection_pool.free_len == 1);

    { // too many redirects
        const location = try std.fmt.allocPrint(gpa, "http://127.0.0.1:{d}/redirect/4", .{port});
        defer gpa.free(location);
        const uri = try std.Uri.parse(location);

        log.info("{s}", .{location});
        var redirect_buffer: [1024]u8 = undefined;
        var req = try client.request(.GET, uri, .{});
        defer req.deinit();

        try req.sendBodiless();
        if (req.receiveHead(&redirect_buffer)) |_| {
            return error.TestFailed;
        } else |err| switch (err) {
            error.TooManyHttpRedirects => {},
            else => return err,
        }
    }

    { // redirect to encoded url
        const location = try std.fmt.allocPrint(gpa, "http://127.0.0.1:{d}/redirect/5", .{port});
        defer gpa.free(location);
        const uri = try std.Uri.parse(location);

        log.info("{s}", .{location});
        var redirect_buffer: [1024]u8 = undefined;
        var req = try client.request(.GET, uri, .{});
        defer req.deinit();

        try req.sendBodiless();
        var response = try req.receiveHead(&redirect_buffer);

        const body = try response.reader(&.{}).allocRemaining(gpa, .unlimited);
        defer gpa.free(body);

        try expectEqualStrings("Encoded redirect successful!\n", body);
    }

    // connection has been kept alive
    try expect(client.http_proxy != null or client.connection_pool.free_len == 1);

    { // check client without segfault by connection error after redirection
        const location = try std.fmt.allocPrint(gpa, "http://127.0.0.1:{d}/redirect/invalid", .{port});
        defer gpa.free(location);
        const uri = try std.Uri.parse(location);

        log.info("{s}", .{location});
        var redirect_buffer: [1024]u8 = undefined;
        var req = try client.request(.GET, uri, .{});
        defer req.deinit();

        try req.sendBodiless();
        const result = req.receiveHead(&redirect_buffer);

        // a proxy without an upstream is likely to return a 5xx status.
        if (client.http_proxy == null) {
            try expectError(error.ConnectionRefused, result); // expects not segfault but the regular error
        }
    }

    // connection has been kept alive
    try expect(client.http_proxy != null or client.connection_pool.free_len == 1);
}

test "Server streams both reading and writing" {
    const test_server = try createTestServer(struct {
        fn run(test_server: *TestServer) anyerror!void {
            const net_server = &test_server.net_server;
            var recv_buffer: [1024]u8 = undefined;
            var send_buffer: [777]u8 = undefined;

            const connection = try net_server.accept();
            defer connection.stream.close();

            var connection_br = connection.stream.reader(&recv_buffer);
            var connection_bw = connection.stream.writer(&send_buffer);
            var server = http.Server.init(connection_br.interface(), &connection_bw.interface);
            var request = try server.receiveHead();
            var read_buffer: [100]u8 = undefined;
            var br = try request.readerExpectContinue(&read_buffer);
            var response = try request.respondStreaming(&.{}, .{
                .respond_options = .{
                    .transfer_encoding = .none, // Causes keep_alive=false
                },
            });
            const w = &response.writer;

            while (true) {
                try response.flush();
                const buf = br.peekGreedy(1) catch |err| switch (err) {
                    error.EndOfStream => break,
                    error.ReadFailed => return error.ReadFailed,
                };
                br.toss(buf.len);
                for (buf) |*b| b.* = std.ascii.toUpper(b.*);
                try w.writeAll(buf);
            }
            try response.end();
        }
    });
    defer test_server.destroy();

    var client: http.Client = .{ .allocator = std.testing.allocator };
    defer client.deinit();

    var redirect_buffer: [555]u8 = undefined;
    var req = try client.request(.POST, .{
        .scheme = "http",
        .host = .{ .raw = "127.0.0.1" },
        .port = test_server.port(),
        .path = .{ .percent_encoded = "/" },
    }, .{});
    defer req.deinit();

    req.transfer_encoding = .chunked;
    var body_writer = try req.sendBody(&.{});
    var response = try req.receiveHead(&redirect_buffer);

    try body_writer.writer.writeAll("one ");
    try body_writer.writer.writeAll("fish");
    try body_writer.end();

    const body = try response.reader(&.{}).allocRemaining(std.testing.allocator, .unlimited);
    defer std.testing.allocator.free(body);

    try expectEqualStrings("ONE FISH", body);
}

fn echoTests(client: *http.Client, port: u16) !void {
    const gpa = std.testing.allocator;
    var location_buffer: [100]u8 = undefined;

    { // send content-length request
        const location = try std.fmt.allocPrint(gpa, "http://127.0.0.1:{d}/echo-content", .{port});
        defer gpa.free(location);
        const uri = try std.Uri.parse(location);

        var redirect_buffer: [1024]u8 = undefined;
        var req = try client.request(.POST, uri, .{
            .extra_headers = &.{
                .{ .name = "content-type", .value = "text/plain" },
            },
        });
        defer req.deinit();

        req.transfer_encoding = .{ .content_length = 14 };

        var body_writer = try req.sendBody(&.{});
        try body_writer.writer.writeAll("Hello, ");
        try body_writer.writer.writeAll("World!\n");
        try body_writer.end();

        var response = try req.receiveHead(&redirect_buffer);

        const body = try response.reader(&.{}).allocRemaining(gpa, .unlimited);
        defer gpa.free(body);

        try expectEqualStrings("Hello, World!\n", body);
    }

    // connection has been kept alive
    try expect(client.http_proxy != null or client.connection_pool.free_len == 1);

    { // send chunked request
        const uri = try std.Uri.parse(try std.fmt.bufPrint(
            &location_buffer,
            "http://127.0.0.1:{d}/echo-content",
            .{port},
        ));

        var redirect_buffer: [1024]u8 = undefined;
        var req = try client.request(.POST, uri, .{
            .extra_headers = &.{
                .{ .name = "content-type", .value = "text/plain" },
            },
        });
        defer req.deinit();

        req.transfer_encoding = .chunked;

        var body_writer = try req.sendBody(&.{});
        try body_writer.writer.writeAll("Hello, ");
        try body_writer.writer.writeAll("World!\n");
        try body_writer.end();

        var response = try req.receiveHead(&redirect_buffer);

        const body = try response.reader(&.{}).allocRemaining(gpa, .unlimited);
        defer gpa.free(body);

        try expectEqualStrings("Hello, World!\n", body);
    }

    // connection has been kept alive
    try expect(client.http_proxy != null or client.connection_pool.free_len == 1);

    { // Client.fetch()

        const location = try std.fmt.allocPrint(gpa, "http://127.0.0.1:{d}/echo-content#fetch", .{port});
        defer gpa.free(location);

        var body: std.Io.Writer.Allocating = .init(gpa);
        defer body.deinit();
        try body.ensureUnusedCapacity(64);

        const res = try client.fetch(.{
            .location = .{ .url = location },
            .method = .POST,
            .payload = "Hello, World!\n",
            .extra_headers = &.{
                .{ .name = "content-type", .value = "text/plain" },
            },
            .response_writer = &body.writer,
        });
        try expectEqual(.ok, res.status);
        try expectEqualStrings("Hello, World!\n", body.written());
    }

    { // expect: 100-continue
        const location = try std.fmt.allocPrint(gpa, "http://127.0.0.1:{d}/echo-content#expect-100", .{port});
        defer gpa.free(location);
        const uri = try std.Uri.parse(location);

        var redirect_buffer: [1024]u8 = undefined;
        var req = try client.request(.POST, uri, .{
            .extra_headers = &.{
                .{ .name = "expect", .value = "100-continue" },
                .{ .name = "content-type", .value = "text/plain" },
            },
        });
        defer req.deinit();

        req.transfer_encoding = .chunked;

        var body_writer = try req.sendBody(&.{});
        try body_writer.writer.writeAll("Hello, ");
        try body_writer.writer.writeAll("World!\n");
        try body_writer.end();

        var response = try req.receiveHead(&redirect_buffer);
        try expectEqual(.ok, response.head.status);

        const body = try response.reader(&.{}).allocRemaining(gpa, .unlimited);
        defer gpa.free(body);

        try expectEqualStrings("Hello, World!\n", body);
    }

    { // expect: garbage
        const location = try std.fmt.allocPrint(gpa, "http://127.0.0.1:{d}/echo-content#expect-garbage", .{port});
        defer gpa.free(location);
        const uri = try std.Uri.parse(location);

        var redirect_buffer: [1024]u8 = undefined;
        var req = try client.request(.POST, uri, .{
            .extra_headers = &.{
                .{ .name = "content-type", .value = "text/plain" },
                .{ .name = "expect", .value = "garbage" },
            },
        });
        defer req.deinit();

        req.transfer_encoding = .chunked;

        var body_writer = try req.sendBody(&.{});
        try body_writer.flush();
        var response = try req.receiveHead(&redirect_buffer);
        try expectEqual(.expectation_failed, response.head.status);
        _ = try response.reader(&.{}).discardRemaining();
    }
}

const TestServer = struct {
    shutting_down: bool,
    server_thread: std.Thread,
    net_server: std.net.Server,

    fn destroy(self: *@This()) void {
        self.shutting_down = true;
        const conn = std.net.tcpConnectToAddress(self.net_server.listen_address) catch @panic("shutdown failure");
        conn.close();

        self.server_thread.join();
        self.net_server.deinit();
        std.testing.allocator.destroy(self);
    }

    fn port(self: @This()) u16 {
        return self.net_server.listen_address.in.getPort();
    }
};

fn createTestServer(S: type) !*TestServer {
    if (builtin.single_threaded) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_llvm and native_endian == .big) {
        // https://github.com/ziglang/zig/issues/13782
        return error.SkipZigTest;
    }

    const address = try std.net.Address.parseIp("127.0.0.1", 0);
    const test_server = try std.testing.allocator.create(TestServer);
    test_server.* = .{
        .net_server = try address.listen(.{ .reuse_address = true }),
        .server_thread = try std.Thread.spawn(.{}, S.run, .{test_server}),
        .shutting_down = false,
    };
    return test_server;
}

test "redirect to different connection" {
    const test_server_new = try createTestServer(struct {
        fn run(test_server: *TestServer) anyerror!void {
            const net_server = &test_server.net_server;
            var recv_buffer: [888]u8 = undefined;
            var send_buffer: [777]u8 = undefined;

            const connection = try net_server.accept();
            defer connection.stream.close();

            var connection_br = connection.stream.reader(&recv_buffer);
            var connection_bw = connection.stream.writer(&send_buffer);
            var server = http.Server.init(connection_br.interface(), &connection_bw.interface);
            var request = try server.receiveHead();
            try expectEqualStrings(request.head.target, "/ok");
            try request.respond("good job, you pass", .{});
        }
    });
    defer test_server_new.destroy();

    const global = struct {
        var other_port: ?u16 = null;
    };
    global.other_port = test_server_new.port();

    const test_server_orig = try createTestServer(struct {
        fn run(test_server: *TestServer) anyerror!void {
            const net_server = &test_server.net_server;
            var recv_buffer: [999]u8 = undefined;
            var send_buffer: [100]u8 = undefined;

            const connection = try net_server.accept();
            defer connection.stream.close();

            var loc_buf: [50]u8 = undefined;
            const new_loc = try std.fmt.bufPrint(&loc_buf, "http://127.0.0.1:{d}/ok", .{
                global.other_port.?,
            });

            var connection_br = connection.stream.reader(&recv_buffer);
            var connection_bw = connection.stream.writer(&send_buffer);
            var server = http.Server.init(connection_br.interface(), &connection_bw.interface);
            var request = try server.receiveHead();
            try expectEqualStrings(request.head.target, "/help");
            try request.respond("", .{
                .status = .found,
                .extra_headers = &.{
                    .{ .name = "location", .value = new_loc },
                },
            });
        }
    });
    defer test_server_orig.destroy();

    const gpa = std.testing.allocator;

    var client: http.Client = .{ .allocator = gpa };
    defer client.deinit();

    var loc_buf: [100]u8 = undefined;
    const location = try std.fmt.bufPrint(&loc_buf, "http://127.0.0.1:{d}/help", .{
        test_server_orig.port(),
    });
    const uri = try std.Uri.parse(location);

    {
        var redirect_buffer: [666]u8 = undefined;
        var req = try client.request(.GET, uri, .{});
        defer req.deinit();

        try req.sendBodiless();
        var response = try req.receiveHead(&redirect_buffer);
        var reader = response.reader(&.{});

        const body = try reader.allocRemaining(gpa, .unlimited);
        defer gpa.free(body);

        try expectEqualStrings("good job, you pass", body);
    }
}
