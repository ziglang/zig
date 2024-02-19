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

fn handleRequest(res: *http.Server, listen_port: u16) !void {
    const log = std.log.scoped(.server);

    log.info("{} {s} {s}", .{ res.request.method, @tagName(res.request.version), res.request.target });

    if (res.request.expect) |expect| {
        if (mem.eql(u8, expect, "100-continue")) {
            res.status = .@"continue";
            try res.send();
            res.status = .ok;
        } else {
            res.status = .expectation_failed;
            try res.send();
            return;
        }
    }

    const body = try res.reader().readAllAlloc(salloc, 8192);
    defer salloc.free(body);

    if (res.request.keep_alive) {
        res.keep_alive = true;
    }

    if (mem.startsWith(u8, res.request.target, "/get")) {
        if (std.mem.indexOf(u8, res.request.target, "?chunked") != null) {
            res.transfer_encoding = .chunked;
        } else {
            res.transfer_encoding = .{ .content_length = 14 };
        }

        res.extra_headers = &.{
            .{ .name = "content-type", .value = "text/plain" },
        };

        try res.send();
        if (res.request.method != .HEAD) {
            try res.writeAll("Hello, ");
            try res.writeAll("World!\n");
            try res.finish();
        } else {
            try testing.expectEqual(res.writeAll("errors"), error.NotWriteable);
        }
    } else if (mem.startsWith(u8, res.request.target, "/large")) {
        res.transfer_encoding = .{ .content_length = 14 * 1024 + 14 * 10 };

        try res.send();

        var i: u32 = 0;
        while (i < 5) : (i += 1) {
            try res.writeAll("Hello, World!\n");
        }

        try res.writeAll("Hello, World!\n" ** 1024);

        i = 0;
        while (i < 5) : (i += 1) {
            try res.writeAll("Hello, World!\n");
        }

        try res.finish();
    } else if (mem.startsWith(u8, res.request.target, "/echo-content")) {
        try testing.expectEqualStrings("Hello, World!\n", body);
        try testing.expectEqualStrings("text/plain", res.request.content_type.?);

        switch (res.request.transfer_encoding) {
            .chunked => res.transfer_encoding = .chunked,
            .none => {
                res.transfer_encoding = .{ .content_length = 14 };
                try testing.expectEqual(14, res.request.content_length.?);
            },
        }

        try res.send();
        try res.writeAll("Hello, ");
        try res.writeAll("World!\n");
        try res.finish();
    } else if (mem.eql(u8, res.request.target, "/redirect/1")) {
        res.transfer_encoding = .chunked;

        res.status = .found;
        res.extra_headers = &.{
            .{ .name = "location", .value = "../../get" },
        };

        try res.send();
        try res.writeAll("Hello, ");
        try res.writeAll("Redirected!\n");
        try res.finish();
    } else if (mem.eql(u8, res.request.target, "/redirect/2")) {
        res.transfer_encoding = .chunked;

        res.status = .found;
        res.extra_headers = &.{
            .{ .name = "location", .value = "/redirect/1" },
        };

        try res.send();
        try res.writeAll("Hello, ");
        try res.writeAll("Redirected!\n");
        try res.finish();
    } else if (mem.eql(u8, res.request.target, "/redirect/3")) {
        res.transfer_encoding = .chunked;

        const location = try std.fmt.allocPrint(salloc, "http://127.0.0.1:{d}/redirect/2", .{
            listen_port,
        });
        defer salloc.free(location);

        res.status = .found;
        res.extra_headers = &.{
            .{ .name = "location", .value = location },
        };

        try res.send();
        try res.writeAll("Hello, ");
        try res.writeAll("Redirected!\n");
        try res.finish();
    } else if (mem.eql(u8, res.request.target, "/redirect/4")) {
        res.transfer_encoding = .chunked;

        res.status = .found;
        res.extra_headers = &.{
            .{ .name = "location", .value = "/redirect/3" },
        };

        try res.send();
        try res.writeAll("Hello, ");
        try res.writeAll("Redirected!\n");
        try res.finish();
    } else if (mem.eql(u8, res.request.target, "/redirect/invalid")) {
        const invalid_port = try getUnusedTcpPort();
        const location = try std.fmt.allocPrint(salloc, "http://127.0.0.1:{d}", .{invalid_port});
        defer salloc.free(location);

        res.status = .found;
        res.extra_headers = &.{
            .{ .name = "location", .value = location },
        };
        try res.send();
        try res.finish();
    } else {
        res.status = .not_found;
        try res.send();
    }
}

var handle_new_requests = true;

fn runServer(server: *std.net.Server) !void {
    var client_header_buffer: [1024]u8 = undefined;
    outer: while (handle_new_requests) {
        var connection = try server.accept();
        defer connection.stream.close();

        var res = http.Server.init(connection, .{
            .client_header_buffer = &client_header_buffer,
        });

        while (res.reset() != .closing) {
            res.wait() catch |err| switch (err) {
                error.HttpHeadersInvalid => continue :outer,
                error.EndOfStream => continue,
                else => return err,
            };

            try handleRequest(&res, server.listen_address.getPort());
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

    { // send content-length request
        const location = try std.fmt.allocPrint(calloc, "http://127.0.0.1:{d}/echo-content", .{port});
        defer calloc.free(location);
        const uri = try std.Uri.parse(location);

        log.info("{s}", .{location});
        var server_header_buffer: [1024]u8 = undefined;
        var req = try client.open(.POST, uri, .{
            .server_header_buffer = &server_header_buffer,
            .extra_headers = &.{
                .{ .name = "content-type", .value = "text/plain" },
            },
        });
        defer req.deinit();

        req.transfer_encoding = .{ .content_length = 14 };

        try req.send(.{});
        try req.writeAll("Hello, ");
        try req.writeAll("World!\n");
        try req.finish();

        try req.wait();

        const body = try req.reader().readAllAlloc(calloc, 8192);
        defer calloc.free(body);

        try testing.expectEqualStrings("Hello, World!\n", body);
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

    { // send chunked request
        const location = try std.fmt.allocPrint(calloc, "http://127.0.0.1:{d}/echo-content", .{port});
        defer calloc.free(location);
        const uri = try std.Uri.parse(location);

        log.info("{s}", .{location});
        var server_header_buffer: [1024]u8 = undefined;
        var req = try client.open(.POST, uri, .{
            .server_header_buffer = &server_header_buffer,
            .extra_headers = &.{
                .{ .name = "content-type", .value = "text/plain" },
            },
        });
        defer req.deinit();

        req.transfer_encoding = .chunked;

        try req.send(.{});
        try req.writeAll("Hello, ");
        try req.writeAll("World!\n");
        try req.finish();

        try req.wait();

        const body = try req.reader().readAllAlloc(calloc, 8192);
        defer calloc.free(body);

        try testing.expectEqualStrings("Hello, World!\n", body);
    }

    // connection has been kept alive
    try testing.expect(client.http_proxy != null or client.connection_pool.free_len == 1);

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

    { // Client.fetch()

        const location = try std.fmt.allocPrint(calloc, "http://127.0.0.1:{d}/echo-content#fetch", .{port});
        defer calloc.free(location);

        log.info("{s}", .{location});
        var body = std.ArrayList(u8).init(calloc);
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
        try testing.expectEqual(.ok, res.status);
        try testing.expectEqualStrings("Hello, World!\n", body.items);
    }

    { // expect: 100-continue
        const location = try std.fmt.allocPrint(calloc, "http://127.0.0.1:{d}/echo-content#expect-100", .{port});
        defer calloc.free(location);
        const uri = try std.Uri.parse(location);

        log.info("{s}", .{location});
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

        try req.send(.{});
        try req.writeAll("Hello, ");
        try req.writeAll("World!\n");
        try req.finish();

        try req.wait();
        try testing.expectEqual(http.Status.ok, req.response.status);

        const body = try req.reader().readAllAlloc(calloc, 8192);
        defer calloc.free(body);

        try testing.expectEqualStrings("Hello, World!\n", body);
    }

    { // expect: garbage
        const location = try std.fmt.allocPrint(calloc, "http://127.0.0.1:{d}/echo-content#expect-garbage", .{port});
        defer calloc.free(location);
        const uri = try std.Uri.parse(location);

        log.info("{s}", .{location});
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

        try req.send(.{});
        try req.wait();
        try testing.expectEqual(http.Status.expectation_failed, req.response.status);
    }

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
