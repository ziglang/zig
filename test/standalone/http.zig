const std = @import("std");

const http = std.http;

const mem = std.mem;
const testing = std.testing;

pub const std_options = .{
    .http_disable_tls = true,
};

const max_header_size = 8192;

var gpa_server = std.heap.GeneralPurposeAllocator(.{ .stack_trace_frames = 12 }){};
var gpa_client = std.heap.GeneralPurposeAllocator(.{ .stack_trace_frames = 12 }){};

const salloc = gpa_server.allocator();
const calloc = gpa_client.allocator();

fn handleRequest(request: *http.Server.Request, listen_port: u16) !void {
    const log = std.log.scoped(.server);

    log.info("{} {s} {s}", .{
        request.head.method,
        @tagName(request.head.version),
        request.head.target,
    });

    if (request.head.expect) |expect| {
        if (mem.eql(u8, expect, "100-continue")) {
            @panic("test failure, didn't handle expect 100-continue");
        } else {
            return request.respond("", .{
                .status = .expectation_failed,
            });
        }
    }

    const body = try request.reader().readAllAlloc(salloc, 8192);
    defer salloc.free(body);

    var send_buffer: [100]u8 = undefined;

    if (mem.startsWith(u8, request.head.target, "/get")) {
        var response = request.respondStreaming(.{
            .send_buffer = &send_buffer,
            .content_length = if (std.mem.indexOf(u8, request.head.target, "?chunked") == null)
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
        const location = try std.fmt.allocPrint(salloc, "http://127.0.0.1:{d}/redirect/2", .{
            listen_port,
        });
        defer salloc.free(location);

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
    } else if (mem.eql(u8, request.head.target, "/redirect/invalid")) {
        const invalid_port = try getUnusedTcpPort();
        const location = try std.fmt.allocPrint(salloc, "http://127.0.0.1:{d}", .{invalid_port});
        defer salloc.free(location);

        try request.respond("", .{
            .status = .found,
            .extra_headers = &.{
                .{ .name = "location", .value = location },
            },
        });
    } else {
        try request.respond("", .{ .status = .not_found });
    }
}

var handle_new_requests = true;

fn runServer(server: *std.net.Server) !void {
    var client_header_buffer: [1024]u8 = undefined;
    outer: while (handle_new_requests) {
        var connection = try server.accept();
        defer connection.stream.close();

        var http_server = http.Server.init(connection, &client_header_buffer);

        while (http_server.state == .ready) {
            var request = http_server.receiveHead() catch |err| switch (err) {
                error.HttpConnectionClosing => continue :outer,
                else => |e| return e,
            };

            try handleRequest(&request, server.listen_address.getPort());
        }
    }
}

fn serverThread(server: *std.net.Server) void {
    defer _ = gpa_server.deinit();

    runServer(server) catch |err| {
        std.debug.print("server error: {}\n", .{err});

        if (@errorReturnTrace()) |trace| {
            std.debug.dumpStackTrace(trace.*);
        }

        _ = gpa_server.deinit();
        std.os.exit(1);
    };
}

fn getUnusedTcpPort() !u16 {
    const addr = try std.net.Address.parseIp("127.0.0.1", 0);
    var s = try addr.listen(.{});
    defer s.deinit();
    return s.listen_address.in.getPort();
}

pub fn main() !void {
    const log = std.log.scoped(.client);

    defer _ = gpa_client.deinit();

    const addr = std.net.Address.parseIp("127.0.0.1", 0) catch unreachable;
    var server = try addr.listen(.{ .reuse_address = true });
    defer server.deinit();

    const port = server.listen_address.getPort();

    const server_thread = try std.Thread.spawn(.{}, serverThread, .{&server});

    var client: http.Client = .{ .allocator = calloc };
    errdefer client.deinit();
    // defer client.deinit(); handled below

    var arena_instance = std.heap.ArenaAllocator.init(calloc);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();

    try client.initDefaultProxies(arena);

    { // read content-length response
        const location = try std.fmt.allocPrint(calloc, "http://127.0.0.1:{d}/get", .{port});
        defer calloc.free(location);
        const uri = try std.Uri.parse(location);

        log.info("{s}", .{location});
        var server_header_buffer: [1024]u8 = undefined;
        var req = try client.open(.GET, uri, .{
            .server_header_buffer = &server_header_buffer,
        });
        defer req.deinit();

        try req.send(.{});
        try req.wait();

        const body = try req.reader().readAllAlloc(calloc, 8192);
        defer calloc.free(body);

        try testing.expectEqualStrings("Hello, World!\n", body);
        try testing.expectEqualStrings("text/plain", req.response.content_type.?);
    }

    // connection has been kept alive
    try testing.expect(client.http_proxy != null or client.connection_pool.free_len == 1);

    { // read large content-length response
        const location = try std.fmt.allocPrint(calloc, "http://127.0.0.1:{d}/large", .{port});
        defer calloc.free(location);
        const uri = try std.Uri.parse(location);

        log.info("{s}", .{location});
        var server_header_buffer: [1024]u8 = undefined;
        var req = try client.open(.GET, uri, .{
            .server_header_buffer = &server_header_buffer,
        });
        defer req.deinit();

        try req.send(.{});
        try req.wait();

        const body = try req.reader().readAllAlloc(calloc, 8192 * 1024);
        defer calloc.free(body);

        try testing.expectEqual(@as(usize, 14 * 1024 + 14 * 10), body.len);
    }

    // connection has been kept alive
    try testing.expect(client.http_proxy != null or client.connection_pool.free_len == 1);

    { // send head request and not read chunked
        const location = try std.fmt.allocPrint(calloc, "http://127.0.0.1:{d}/get", .{port});
        defer calloc.free(location);
        const uri = try std.Uri.parse(location);

        log.info("{s}", .{location});
        var server_header_buffer: [1024]u8 = undefined;
        var req = try client.open(.HEAD, uri, .{
            .server_header_buffer = &server_header_buffer,
        });
        defer req.deinit();

        try req.send(.{});
        try req.wait();

        const body = try req.reader().readAllAlloc(calloc, 8192);
        defer calloc.free(body);

        try testing.expectEqualStrings("", body);
        try testing.expectEqualStrings("text/plain", req.response.content_type.?);
        try testing.expectEqual(14, req.response.content_length.?);
    }

    // connection has been kept alive
    try testing.expect(client.http_proxy != null or client.connection_pool.free_len == 1);

    { // read chunked response
        const location = try std.fmt.allocPrint(calloc, "http://127.0.0.1:{d}/get?chunked", .{port});
        defer calloc.free(location);
        const uri = try std.Uri.parse(location);

        log.info("{s}", .{location});
        var server_header_buffer: [1024]u8 = undefined;
        var req = try client.open(.GET, uri, .{
            .server_header_buffer = &server_header_buffer,
        });
        defer req.deinit();

        try req.send(.{});
        try req.wait();

        const body = try req.reader().readAllAlloc(calloc, 8192);
        defer calloc.free(body);

        try testing.expectEqualStrings("Hello, World!\n", body);
        try testing.expectEqualStrings("text/plain", req.response.content_type.?);
    }

    // connection has been kept alive
    try testing.expect(client.http_proxy != null or client.connection_pool.free_len == 1);

    { // send head request and not read chunked
        const location = try std.fmt.allocPrint(calloc, "http://127.0.0.1:{d}/get?chunked", .{port});
        defer calloc.free(location);
        const uri = try std.Uri.parse(location);

        log.info("{s}", .{location});
        var server_header_buffer: [1024]u8 = undefined;
        var req = try client.open(.HEAD, uri, .{
            .server_header_buffer = &server_header_buffer,
        });
        defer req.deinit();

        try req.send(.{});
        try req.wait();

        const body = try req.reader().readAllAlloc(calloc, 8192);
        defer calloc.free(body);

        try testing.expectEqualStrings("", body);
        try testing.expectEqualStrings("text/plain", req.response.content_type.?);
        try testing.expect(req.response.transfer_encoding == .chunked);
    }

    // connection has been kept alive
    try testing.expect(client.http_proxy != null or client.connection_pool.free_len == 1);

    { // read content-length response with connection close
        const location = try std.fmt.allocPrint(calloc, "http://127.0.0.1:{d}/get", .{port});
        defer calloc.free(location);
        const uri = try std.Uri.parse(location);

        log.info("{s}", .{location});
        var server_header_buffer: [1024]u8 = undefined;
        var req = try client.open(.GET, uri, .{
            .server_header_buffer = &server_header_buffer,
            .keep_alive = false,
        });
        defer req.deinit();

        try req.send(.{});
        try req.wait();

        const body = try req.reader().readAllAlloc(calloc, 8192);
        defer calloc.free(body);

        try testing.expectEqualStrings("Hello, World!\n", body);
        try testing.expectEqualStrings("text/plain", req.response.content_type.?);
    }

    // connection has been closed
    try testing.expect(client.connection_pool.free_len == 0);

    { // relative redirect
        const location = try std.fmt.allocPrint(calloc, "http://127.0.0.1:{d}/redirect/1", .{port});
        defer calloc.free(location);
        const uri = try std.Uri.parse(location);

        log.info("{s}", .{location});
        var server_header_buffer: [1024]u8 = undefined;
        var req = try client.open(.GET, uri, .{
            .server_header_buffer = &server_header_buffer,
        });
        defer req.deinit();

        try req.send(.{});
        try req.wait();

        const body = try req.reader().readAllAlloc(calloc, 8192);
        defer calloc.free(body);

        try testing.expectEqualStrings("Hello, World!\n", body);
    }

    // connection has been kept alive
    try testing.expect(client.http_proxy != null or client.connection_pool.free_len == 1);

    { // redirect from root
        const location = try std.fmt.allocPrint(calloc, "http://127.0.0.1:{d}/redirect/2", .{port});
        defer calloc.free(location);
        const uri = try std.Uri.parse(location);

        log.info("{s}", .{location});
        var server_header_buffer: [1024]u8 = undefined;
        var req = try client.open(.GET, uri, .{
            .server_header_buffer = &server_header_buffer,
        });
        defer req.deinit();

        try req.send(.{});
        try req.wait();

        const body = try req.reader().readAllAlloc(calloc, 8192);
        defer calloc.free(body);

        try testing.expectEqualStrings("Hello, World!\n", body);
    }

    // connection has been kept alive
    try testing.expect(client.http_proxy != null or client.connection_pool.free_len == 1);

    { // absolute redirect
        const location = try std.fmt.allocPrint(calloc, "http://127.0.0.1:{d}/redirect/3", .{port});
        defer calloc.free(location);
        const uri = try std.Uri.parse(location);

        log.info("{s}", .{location});
        var server_header_buffer: [1024]u8 = undefined;
        var req = try client.open(.GET, uri, .{
            .server_header_buffer = &server_header_buffer,
        });
        defer req.deinit();

        try req.send(.{});
        try req.wait();

        const body = try req.reader().readAllAlloc(calloc, 8192);
        defer calloc.free(body);

        try testing.expectEqualStrings("Hello, World!\n", body);
    }

    // connection has been kept alive
    try testing.expect(client.http_proxy != null or client.connection_pool.free_len == 1);

    { // too many redirects
        const location = try std.fmt.allocPrint(calloc, "http://127.0.0.1:{d}/redirect/4", .{port});
        defer calloc.free(location);
        const uri = try std.Uri.parse(location);

        log.info("{s}", .{location});
        var server_header_buffer: [1024]u8 = undefined;
        var req = try client.open(.GET, uri, .{
            .server_header_buffer = &server_header_buffer,
        });
        defer req.deinit();

        try req.send(.{});
        req.wait() catch |err| switch (err) {
            error.TooManyHttpRedirects => {},
            else => return err,
        };
    }

    // connection has been kept alive
    try testing.expect(client.http_proxy != null or client.connection_pool.free_len == 1);

    { // check client without segfault by connection error after redirection
        const location = try std.fmt.allocPrint(calloc, "http://127.0.0.1:{d}/redirect/invalid", .{port});
        defer calloc.free(location);
        const uri = try std.Uri.parse(location);

        log.info("{s}", .{location});
        var server_header_buffer: [1024]u8 = undefined;
        var req = try client.open(.GET, uri, .{
            .server_header_buffer = &server_header_buffer,
        });
        defer req.deinit();

        try req.send(.{});
        const result = req.wait();

        // a proxy without an upstream is likely to return a 5xx status.
        if (client.http_proxy == null) {
            try testing.expectError(error.ConnectionRefused, result); // expects not segfault but the regular error
        }
    }

    // connection has been kept alive
    try testing.expect(client.http_proxy != null or client.connection_pool.free_len == 1);

    { // issue 16282 *** This test leaves the client in an invalid state, it must be last ***
        const location = try std.fmt.allocPrint(calloc, "http://127.0.0.1:{d}/get", .{port});
        defer calloc.free(location);
        const uri = try std.Uri.parse(location);

        const total_connections = client.connection_pool.free_size + 64;
        var requests = try calloc.alloc(http.Client.Request, total_connections);
        defer calloc.free(requests);

        var header_bufs = std.ArrayList([]u8).init(calloc);
        defer header_bufs.deinit();
        defer for (header_bufs.items) |item| calloc.free(item);

        for (0..total_connections) |i| {
            const headers_buf = try calloc.alloc(u8, 1024);
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
        try testing.expect(client.connection_pool.free_len == client.connection_pool.free_size);
    }

    client.deinit();

    {
        handle_new_requests = false;

        const conn = std.net.tcpConnectToAddress(server.listen_address) catch return;
        conn.close();
    }

    server_thread.join();
}
