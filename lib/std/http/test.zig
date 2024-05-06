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
        fn run(net_server: *std.net.Server) anyerror!void {
            var header_buffer: [1024]u8 = undefined;
            var remaining: usize = 1;
            while (remaining != 0) : (remaining -= 1) {
                const conn = try net_server.accept();
                defer conn.stream.close();

                var server = http.Server.init(conn, &header_buffer);

                try expectEqual(.ready, server.state);
                var request = try server.receiveHead();
                try serve(&request);
                try expectEqual(.ready, server.state);
            }
        }

        fn serve(request: *http.Server.Request) !void {
            try expectEqualStrings(request.head.target, "/trailer");

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
        var server_header_buffer: [1024]u8 = undefined;
        var req = try client.open(.GET, uri, .{
            .server_header_buffer = &server_header_buffer,
        });
        defer req.deinit();

        try req.send();
        try req.wait();

        const body = try req.reader().readAllAlloc(gpa, 8192);
        defer gpa.free(body);

        try expectEqualStrings("Hello, World!\n", body);

        var it = req.response.iterateHeaders();
        {
            const header = it.next().?;
            try expect(!it.is_trailer);
            try expectEqualStrings("transfer-encoding", header.name);
            try expectEqualStrings("chunked", header.value);
        }
        {
            const header = it.next().?;
            try expect(it.is_trailer);
            try expectEqualStrings("X-Checksum", header.name);
            try expectEqualStrings("aaaa", header.value);
        }
        try expectEqual(null, it.next());
    }

    // connection has been kept alive
    try expect(client.connection_pool.free_len == 1);
}

test "HTTP server handles a chunked transfer coding request" {
    const test_server = try createTestServer(struct {
        fn run(net_server: *std.net.Server) !void {
            var header_buffer: [8192]u8 = undefined;
            const conn = try net_server.accept();
            defer conn.stream.close();

            var server = http.Server.init(conn, &header_buffer);
            var request = try server.receiveHead();

            try expect(request.head.transfer_encoding == .chunked);

            var buf: [128]u8 = undefined;
            const n = try (try request.reader()).readAll(&buf);
            try expect(mem.eql(u8, buf[0..n], "ABCD"));

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
    try stream.writeAll(request_bytes);

    const expected_response =
        "HTTP/1.1 200 OK\r\n" ++
        "connection: close\r\n" ++
        "content-length: 21\r\n" ++
        "content-type: text/plain\r\n" ++
        "\r\n" ++
        "message from server!\n";
    const response = try stream.reader().readAllAlloc(gpa, expected_response.len);
    defer gpa.free(response);
    try expectEqualStrings(expected_response, response);
}

test "echo content server" {
    const test_server = try createTestServer(struct {
        fn run(net_server: *std.net.Server) anyerror!void {
            var read_buffer: [1024]u8 = undefined;

            accept: while (true) {
                const conn = try net_server.accept();
                defer conn.stream.close();

                var http_server = http.Server.init(conn, &read_buffer);

                while (http_server.state == .ready) {
                    var request = http_server.receiveHead() catch |err| switch (err) {
                        error.HttpConnectionClosing => continue :accept,
                        else => |e| return e,
                    };
                    if (mem.eql(u8, request.head.target, "/end")) {
                        return request.respond("", .{ .keep_alive = false });
                    }
                    if (request.head.expect) |expect_header_value| {
                        if (mem.eql(u8, expect_header_value, "garbage")) {
                            try expectError(error.HttpExpectationFailed, request.reader());
                            try request.respond("", .{ .keep_alive = false });
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

            const body = try (try request.reader()).readAllAlloc(std.testing.allocator, 8192);
            defer std.testing.allocator.free(body);

            try expect(mem.startsWith(u8, request.head.target, "/echo-content"));
            try expectEqualStrings("Hello, World!\n", body);
            try expectEqualStrings("text/plain", request.head.content_type.?);

            var send_buffer: [100]u8 = undefined;
            var response = request.respondStreaming(.{
                .send_buffer = &send_buffer,
                .content_length = switch (request.head.transfer_encoding) {
                    .chunked => null,
                    .none => len: {
                        try expectEqual(14, request.head.content_length.?);
                        break :len 14;
                    },
                },
            });

            try response.flush(); // Test an early flush to send the HTTP headers before the body.
            const w = response.writer();
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
    // In this case, the response is expected to stream until the connection is
    // closed, indicating the end of the body.
    const test_server = try createTestServer(struct {
        fn run(net_server: *std.net.Server) anyerror!void {
            var header_buffer: [1000]u8 = undefined;
            var remaining: usize = 1;
            while (remaining != 0) : (remaining -= 1) {
                const conn = try net_server.accept();
                defer conn.stream.close();

                var server = http.Server.init(conn, &header_buffer);

                try expectEqual(.ready, server.state);
                var request = try server.receiveHead();
                try expectEqualStrings(request.head.target, "/foo");
                var send_buffer: [500]u8 = undefined;
                var response = request.respondStreaming(.{
                    .send_buffer = &send_buffer,
                    .respond_options = .{
                        .transfer_encoding = .none,
                    },
                });
                var total: usize = 0;
                for (0..500) |i| {
                    var buf: [30]u8 = undefined;
                    const line = try std.fmt.bufPrint(&buf, "{d}, ah ha ha!\n", .{i});
                    try response.writeAll(line);
                    total += line.len;
                }
                try expectEqual(7390, total);
                try response.end();
                try expectEqual(.closing, server.state);
            }
        }
    });
    defer test_server.destroy();

    const request_bytes = "GET /foo HTTP/1.1\r\n\r\n";
    const gpa = std.testing.allocator;
    const stream = try std.net.tcpConnectToHost(gpa, "127.0.0.1", test_server.port());
    defer stream.close();
    try stream.writeAll(request_bytes);

    const response = try stream.reader().readAllAlloc(gpa, 8192);
    defer gpa.free(response);

    var expected_response = std.ArrayList(u8).init(gpa);
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
        fn run(net_server: *std.net.Server) anyerror!void {
            var read_buffer: [666]u8 = undefined;
            var remaining: usize = 1;
            while (remaining != 0) : (remaining -= 1) {
                const conn = try net_server.accept();
                defer conn.stream.close();

                var server = http.Server.init(conn, &read_buffer);
                try expectEqual(.ready, server.state);
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
    try stream.writeAll(request_bytes);

    const response = try stream.reader().readAllAlloc(gpa, 8192);
    defer gpa.free(response);

    var expected_response = std.ArrayList(u8).init(gpa);
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

    const global = struct {
        var handle_new_requests = true;
    };
    const test_server = try createTestServer(struct {
        fn run(net_server: *std.net.Server) anyerror!void {
            var client_header_buffer: [1024]u8 = undefined;
            outer: while (global.handle_new_requests) {
                var connection = try net_server.accept();
                defer connection.stream.close();

                var http_server = http.Server.init(connection, &client_header_buffer);

                while (http_server.state == .ready) {
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

            log.info("{} {s} {s}", .{
                request.head.method,
                @tagName(request.head.version),
                request.head.target,
            });

            const gpa = std.testing.allocator;
            const body = try (try request.reader()).readAllAlloc(gpa, 8192);
            defer gpa.free(body);

            var send_buffer: [100]u8 = undefined;

            if (mem.startsWith(u8, request.head.target, "/get")) {
                var response = request.respondStreaming(.{
                    .send_buffer = &send_buffer,
                    .content_length = if (mem.indexOf(u8, request.head.target, "?chunked") == null)
                        14
                    else
                        null,
                    .respond_options = .{
                        .extra_headers = &.{
                            .{ .name = "content-type", .value = "text/plain" },
                        },
                    },
                });
                const w = response.writer();
                try w.writeAll("Hello, ");
                try w.writeAll("World!\n");
                try response.end();
                // Writing again would cause an assertion failure.
            } else if (mem.startsWith(u8, request.head.target, "/large")) {
                var response = request.respondStreaming(.{
                    .send_buffer = &send_buffer,
                    .content_length = 14 * 1024 + 14 * 10,
                });

                try response.flush(); // Test an early flush to send the HTTP headers before the body.

                const w = response.writer();

                var i: u32 = 0;
                while (i < 5) : (i += 1) {
                    try w.writeAll("Hello, World!\n");
                }

                try w.writeAll("Hello, World!\n" ** 1024);

                i = 0;
                while (i < 5) : (i += 1) {
                    try w.writeAll("Hello, World!\n");
                }

                try response.end();
            } else if (mem.eql(u8, request.head.target, "/redirect/1")) {
                var response = request.respondStreaming(.{
                    .send_buffer = &send_buffer,
                    .respond_options = .{
                        .status = .found,
                        .extra_headers = &.{
                            .{ .name = "location", .value = "../../get" },
                        },
                    },
                });

                const w = response.writer();
                try w.writeAll("Hello, ");
                try w.writeAll("Redirected!\n");
                try response.end();
            } else if (mem.eql(u8, request.head.target, "/redirect/2")) {
                try request.respond("Hello, Redirected!\n", .{
                    .status = .found,
                    .extra_headers = &.{
                        .{ .name = "location", .value = "/redirect/1" },
                    },
                });
            } else if (mem.eql(u8, request.head.target, "/redirect/3")) {
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
            } else if (mem.eql(u8, request.head.target, "/redirect/4")) {
                try request.respond("Hello, Redirected!\n", .{
                    .status = .found,
                    .extra_headers = &.{
                        .{ .name = "location", .value = "/redirect/3" },
                    },
                });
            } else if (mem.eql(u8, request.head.target, "/redirect/5")) {
                try request.respond("Hello, Redirected!\n", .{
                    .status = .found,
                    .extra_headers = &.{
                        .{ .name = "location", .value = "/%2525" },
                    },
                });
            } else if (mem.eql(u8, request.head.target, "/%2525")) {
                try request.respond("Encoded redirect successful!\n", .{});
            } else if (mem.eql(u8, request.head.target, "/redirect/invalid")) {
                const invalid_port = try getUnusedTcpPort();
                const location = try std.fmt.allocPrint(gpa, "http://127.0.0.1:{d}", .{invalid_port});
                defer gpa.free(location);

                try request.respond("", .{
                    .status = .found,
                    .extra_headers = &.{
                        .{ .name = "location", .value = location },
                    },
                });
            } else if (mem.eql(u8, request.head.target, "/empty")) {
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
    defer {
        global.handle_new_requests = false;
        test_server.destroy();
    }

    const log = std.log.scoped(.client);

    const gpa = std.testing.allocator;
    var client: http.Client = .{ .allocator = gpa };
    errdefer client.deinit();
    // defer client.deinit(); handled below

    const port = test_server.port();

    { // read content-length response
        const location = try std.fmt.allocPrint(gpa, "http://127.0.0.1:{d}/get", .{port});
        defer gpa.free(location);
        const uri = try std.Uri.parse(location);

        log.info("{s}", .{location});
        var server_header_buffer: [1024]u8 = undefined;
        var req = try client.open(.GET, uri, .{
            .server_header_buffer = &server_header_buffer,
        });
        defer req.deinit();

        try req.send();
        try req.wait();

        const body = try req.reader().readAllAlloc(gpa, 8192);
        defer gpa.free(body);

        try expectEqualStrings("Hello, World!\n", body);
        try expectEqualStrings("text/plain", req.response.content_type.?);
    }

    // connection has been kept alive
    try expect(client.http_proxy != null or client.connection_pool.free_len == 1);

    { // read large content-length response
        const location = try std.fmt.allocPrint(gpa, "http://127.0.0.1:{d}/large", .{port});
        defer gpa.free(location);
        const uri = try std.Uri.parse(location);

        log.info("{s}", .{location});
        var server_header_buffer: [1024]u8 = undefined;
        var req = try client.open(.GET, uri, .{
            .server_header_buffer = &server_header_buffer,
        });
        defer req.deinit();

        try req.send();
        try req.wait();

        const body = try req.reader().readAllAlloc(gpa, 8192 * 1024);
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
        var server_header_buffer: [1024]u8 = undefined;
        var req = try client.open(.HEAD, uri, .{
            .server_header_buffer = &server_header_buffer,
        });
        defer req.deinit();

        try req.send();
        try req.wait();

        const body = try req.reader().readAllAlloc(gpa, 8192);
        defer gpa.free(body);

        try expectEqualStrings("", body);
        try expectEqualStrings("text/plain", req.response.content_type.?);
        try expectEqual(14, req.response.content_length.?);
    }

    // connection has been kept alive
    try expect(client.http_proxy != null or client.connection_pool.free_len == 1);

    { // read chunked response
        const location = try std.fmt.allocPrint(gpa, "http://127.0.0.1:{d}/get?chunked", .{port});
        defer gpa.free(location);
        const uri = try std.Uri.parse(location);

        log.info("{s}", .{location});
        var server_header_buffer: [1024]u8 = undefined;
        var req = try client.open(.GET, uri, .{
            .server_header_buffer = &server_header_buffer,
        });
        defer req.deinit();

        try req.send();
        try req.wait();

        const body = try req.reader().readAllAlloc(gpa, 8192);
        defer gpa.free(body);

        try expectEqualStrings("Hello, World!\n", body);
        try expectEqualStrings("text/plain", req.response.content_type.?);
    }

    // connection has been kept alive
    try expect(client.http_proxy != null or client.connection_pool.free_len == 1);

    { // send head request and not read chunked
        const location = try std.fmt.allocPrint(gpa, "http://127.0.0.1:{d}/get?chunked", .{port});
        defer gpa.free(location);
        const uri = try std.Uri.parse(location);

        log.info("{s}", .{location});
        var server_header_buffer: [1024]u8 = undefined;
        var req = try client.open(.HEAD, uri, .{
            .server_header_buffer = &server_header_buffer,
        });
        defer req.deinit();

        try req.send();
        try req.wait();

        const body = try req.reader().readAllAlloc(gpa, 8192);
        defer gpa.free(body);

        try expectEqualStrings("", body);
        try expectEqualStrings("text/plain", req.response.content_type.?);
        try expect(req.response.transfer_encoding == .chunked);
    }

    // connection has been kept alive
    try expect(client.http_proxy != null or client.connection_pool.free_len == 1);

    { // read content-length response with connection close
        const location = try std.fmt.allocPrint(gpa, "http://127.0.0.1:{d}/get", .{port});
        defer gpa.free(location);
        const uri = try std.Uri.parse(location);

        log.info("{s}", .{location});
        var server_header_buffer: [1024]u8 = undefined;
        var req = try client.open(.GET, uri, .{
            .server_header_buffer = &server_header_buffer,
            .keep_alive = false,
        });
        defer req.deinit();

        try req.send();
        try req.wait();

        const body = try req.reader().readAllAlloc(gpa, 8192);
        defer gpa.free(body);

        try expectEqualStrings("Hello, World!\n", body);
        try expectEqualStrings("text/plain", req.response.content_type.?);
    }

    // connection has been closed
    try expect(client.connection_pool.free_len == 0);

    { // handle empty header field value
        const location = try std.fmt.allocPrint(gpa, "http://127.0.0.1:{d}/empty", .{port});
        defer gpa.free(location);
        const uri = try std.Uri.parse(location);

        log.info("{s}", .{location});
        var server_header_buffer: [1024]u8 = undefined;
        var req = try client.open(.GET, uri, .{
            .server_header_buffer = &server_header_buffer,
            .extra_headers = &.{
                .{ .name = "empty", .value = "" },
            },
        });
        defer req.deinit();

        try req.send();
        try req.wait();

        try std.testing.expectEqual(.ok, req.response.status);

        const body = try req.reader().readAllAlloc(gpa, 8192);
        defer gpa.free(body);

        try expectEqualStrings("", body);

        var it = req.response.iterateHeaders();
        {
            const header = it.next().?;
            try expect(!it.is_trailer);
            try expectEqualStrings("content-length", header.name);
            try expectEqualStrings("0", header.value);
        }
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
        var server_header_buffer: [1024]u8 = undefined;
        var req = try client.open(.GET, uri, .{
            .server_header_buffer = &server_header_buffer,
        });
        defer req.deinit();

        try req.send();
        try req.wait();

        const body = try req.reader().readAllAlloc(gpa, 8192);
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
        var server_header_buffer: [1024]u8 = undefined;
        var req = try client.open(.GET, uri, .{
            .server_header_buffer = &server_header_buffer,
        });
        defer req.deinit();

        try req.send();
        try req.wait();

        const body = try req.reader().readAllAlloc(gpa, 8192);
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
        var server_header_buffer: [1024]u8 = undefined;
        var req = try client.open(.GET, uri, .{
            .server_header_buffer = &server_header_buffer,
        });
        defer req.deinit();

        try req.send();
        try req.wait();

        const body = try req.reader().readAllAlloc(gpa, 8192);
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
        var server_header_buffer: [1024]u8 = undefined;
        var req = try client.open(.GET, uri, .{
            .server_header_buffer = &server_header_buffer,
        });
        defer req.deinit();

        try req.send();
        req.wait() catch |err| switch (err) {
            error.TooManyHttpRedirects => {},
            else => return err,
        };
    }

    { // redirect to encoded url
        const location = try std.fmt.allocPrint(gpa, "http://127.0.0.1:{d}/redirect/5", .{port});
        defer gpa.free(location);
        const uri = try std.Uri.parse(location);

        log.info("{s}", .{location});
        var server_header_buffer: [1024]u8 = undefined;
        var req = try client.open(.GET, uri, .{
            .server_header_buffer = &server_header_buffer,
        });
        defer req.deinit();

        try req.send();
        try req.wait();

        const body = try req.reader().readAllAlloc(gpa, 8192);
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
        var server_header_buffer: [1024]u8 = undefined;
        var req = try client.open(.GET, uri, .{
            .server_header_buffer = &server_header_buffer,
        });
        defer req.deinit();

        try req.send();
        const result = req.wait();

        // a proxy without an upstream is likely to return a 5xx status.
        if (client.http_proxy == null) {
            try expectError(error.ConnectionRefused, result); // expects not segfault but the regular error
        }
    }

    // connection has been kept alive
    try expect(client.http_proxy != null or client.connection_pool.free_len == 1);

    { // issue 16282 *** This test leaves the client in an invalid state, it must be last ***
        const location = try std.fmt.allocPrint(gpa, "http://127.0.0.1:{d}/get", .{port});
        defer gpa.free(location);
        const uri = try std.Uri.parse(location);

        const total_connections = client.connection_pool.free_size + 64;
        var requests = try gpa.alloc(http.Client.Request, total_connections);
        defer gpa.free(requests);

        var header_bufs = std.ArrayList([]u8).init(gpa);
        defer header_bufs.deinit();
        defer for (header_bufs.items) |item| gpa.free(item);

        for (0..total_connections) |i| {
            const headers_buf = try gpa.alloc(u8, 1024);
            try header_bufs.append(headers_buf);
            var req = try client.open(.GET, uri, .{
                .server_header_buffer = headers_buf,
            });
            req.response.parser.done = true;
            req.connection.?.closing = false;
            requests[i] = req;
        }

        for (0..total_connections) |i| {
            requests[i].deinit();
        }

        // free connections should be full now
        try expect(client.connection_pool.free_len == client.connection_pool.free_size);
    }

    client.deinit();

    {
        global.handle_new_requests = false;

        const conn = try std.net.tcpConnectToAddress(test_server.net_server.listen_address);
        conn.close();
    }
}

test "Server streams both reading and writing" {
    const test_server = try createTestServer(struct {
        fn run(net_server: *std.net.Server) anyerror!void {
            var header_buffer: [1024]u8 = undefined;
            const conn = try net_server.accept();
            defer conn.stream.close();

            var server = http.Server.init(conn, &header_buffer);
            var request = try server.receiveHead();
            const reader = try request.reader();

            var send_buffer: [777]u8 = undefined;
            var response = request.respondStreaming(.{
                .send_buffer = &send_buffer,
                .respond_options = .{
                    .transfer_encoding = .none, // Causes keep_alive=false
                },
            });
            const writer = response.writer();

            while (true) {
                try response.flush();
                var buf: [100]u8 = undefined;
                const n = try reader.read(&buf);
                if (n == 0) break;
                const sub_buf = buf[0..n];
                for (sub_buf) |*b| b.* = std.ascii.toUpper(b.*);
                try writer.writeAll(sub_buf);
            }
            try response.end();
        }
    });
    defer test_server.destroy();

    var client: http.Client = .{ .allocator = std.testing.allocator };
    defer client.deinit();

    var server_header_buffer: [555]u8 = undefined;
    var req = try client.open(.POST, .{
        .scheme = "http",
        .host = .{ .raw = "127.0.0.1" },
        .port = test_server.port(),
        .path = .{ .percent_encoded = "/" },
    }, .{
        .server_header_buffer = &server_header_buffer,
    });
    defer req.deinit();

    req.transfer_encoding = .chunked;
    try req.send();
    try req.wait();

    try req.writeAll("one ");
    try req.writeAll("fish");

    try req.finish();

    const body = try req.reader().readAllAlloc(std.testing.allocator, 8192);
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

        var server_header_buffer: [1024]u8 = undefined;
        var req = try client.open(.POST, uri, .{
            .server_header_buffer = &server_header_buffer,
            .extra_headers = &.{
                .{ .name = "content-type", .value = "text/plain" },
            },
        });
        defer req.deinit();

        req.transfer_encoding = .{ .content_length = 14 };

        try req.send();
        try req.writeAll("Hello, ");
        try req.writeAll("World!\n");
        try req.finish();

        try req.wait();

        const body = try req.reader().readAllAlloc(gpa, 8192);
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

        var server_header_buffer: [1024]u8 = undefined;
        var req = try client.open(.POST, uri, .{
            .server_header_buffer = &server_header_buffer,
            .extra_headers = &.{
                .{ .name = "content-type", .value = "text/plain" },
            },
        });
        defer req.deinit();

        req.transfer_encoding = .chunked;

        try req.send();
        try req.writeAll("Hello, ");
        try req.writeAll("World!\n");
        try req.finish();

        try req.wait();

        const body = try req.reader().readAllAlloc(gpa, 8192);
        defer gpa.free(body);

        try expectEqualStrings("Hello, World!\n", body);
    }

    // connection has been kept alive
    try expect(client.http_proxy != null or client.connection_pool.free_len == 1);

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
        try expectEqual(.ok, res.status);
        try expectEqualStrings("Hello, World!\n", body.items);
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

        try req.send();
        try req.writeAll("Hello, ");
        try req.writeAll("World!\n");
        try req.finish();

        try req.wait();
        try expectEqual(.ok, req.response.status);

        const body = try req.reader().readAllAlloc(gpa, 8192);
        defer gpa.free(body);

        try expectEqualStrings("Hello, World!\n", body);
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

        try req.send();
        try req.wait();
        try expectEqual(.expectation_failed, req.response.status);
    }

    _ = try client.fetch(.{
        .location = .{
            .url = try std.fmt.bufPrint(&location_buffer, "http://127.0.0.1:{d}/end", .{port}),
        },
    });
}

const TestServer = struct {
    server_thread: std.Thread,
    net_server: std.net.Server,

    fn destroy(self: *@This()) void {
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
    test_server.net_server = try address.listen(.{ .reuse_address = true });
    test_server.server_thread = try std.Thread.spawn(.{}, S.run, .{&test_server.net_server});
    return test_server;
}

test "redirect to different connection" {
    const test_server_new = try createTestServer(struct {
        fn run(net_server: *std.net.Server) anyerror!void {
            var header_buffer: [888]u8 = undefined;

            const conn = try net_server.accept();
            defer conn.stream.close();

            var server = http.Server.init(conn, &header_buffer);
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
        fn run(net_server: *std.net.Server) anyerror!void {
            var header_buffer: [999]u8 = undefined;
            var send_buffer: [100]u8 = undefined;

            const conn = try net_server.accept();
            defer conn.stream.close();

            const new_loc = try std.fmt.bufPrint(&send_buffer, "http://127.0.0.1:{d}/ok", .{
                global.other_port.?,
            });

            var server = http.Server.init(conn, &header_buffer);
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
        var server_header_buffer: [666]u8 = undefined;
        var req = try client.open(.GET, uri, .{
            .server_header_buffer = &server_header_buffer,
        });
        defer req.deinit();

        try req.send();
        try req.wait();

        const body = try req.reader().readAllAlloc(gpa, 8192);
        defer gpa.free(body);

        try expectEqualStrings("good job, you pass", body);
    }
}
