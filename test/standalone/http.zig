const std = @import("std");

const http = std.http;
const Server = http.Server;
const Client = http.Client;

const mem = std.mem;
const testing = std.testing;

pub const std_options = struct {
    pub const http_disable_tls = true;
};

const max_header_size = 8192;

var gpa_server = std.heap.GeneralPurposeAllocator(.{ .stack_trace_frames = 12 }){};
var gpa_client = std.heap.GeneralPurposeAllocator(.{ .stack_trace_frames = 12 }){};

const salloc = gpa_server.allocator();
const calloc = gpa_client.allocator();

var server: Server = undefined;

fn handleRequest(res: *Server.Response) !void {
    const log = std.log.scoped(.server);

    log.info("{} {s} {s}", .{ res.request.method, @tagName(res.request.version), res.request.target });

    if (res.request.headers.contains("expect")) {
        if (mem.eql(u8, res.request.headers.getFirstValue("expect").?, "100-continue")) {
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

    if (res.request.headers.contains("connection")) {
        try res.headers.append("connection", "keep-alive");
    }

    if (mem.startsWith(u8, res.request.target, "/get")) {
        if (std.mem.indexOf(u8, res.request.target, "?chunked") != null) {
            res.transfer_encoding = .chunked;
        } else {
            res.transfer_encoding = .{ .content_length = 14 };
        }

        try res.headers.append("content-type", "text/plain");

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
        try testing.expectEqualStrings("text/plain", res.request.headers.getFirstValue("content-type").?);

        if (res.request.headers.contains("transfer-encoding")) {
            try testing.expectEqualStrings("chunked", res.request.headers.getFirstValue("transfer-encoding").?);
            res.transfer_encoding = .chunked;
        } else {
            res.transfer_encoding = .{ .content_length = 14 };
            try testing.expectEqualStrings("14", res.request.headers.getFirstValue("content-length").?);
        }

        try res.send();
        try res.writeAll("Hello, ");
        try res.writeAll("World!\n");
        try res.finish();
    } else if (mem.eql(u8, res.request.target, "/trailer")) {
        res.transfer_encoding = .chunked;

        try res.send();
        try res.writeAll("Hello, ");
        try res.writeAll("World!\n");
        // try res.finish();
        try res.connection.writeAll("0\r\nX-Checksum: aaaa\r\n\r\n");
    } else if (mem.eql(u8, res.request.target, "/redirect/1")) {
        res.transfer_encoding = .chunked;

        res.status = .found;
        try res.headers.append("location", "../../get");

        try res.send();
        try res.writeAll("Hello, ");
        try res.writeAll("Redirected!\n");
        try res.finish();
    } else if (mem.eql(u8, res.request.target, "/redirect/2")) {
        res.transfer_encoding = .chunked;

        res.status = .found;
        try res.headers.append("location", "/redirect/1");

        try res.send();
        try res.writeAll("Hello, ");
        try res.writeAll("Redirected!\n");
        try res.finish();
    } else if (mem.eql(u8, res.request.target, "/redirect/3")) {
        res.transfer_encoding = .chunked;

        const location = try std.fmt.allocPrint(salloc, "http://127.0.0.1:{d}/redirect/2", .{server.socket.listen_address.getPort()});
        defer salloc.free(location);

        res.status = .found;
        try res.headers.append("location", location);

        try res.send();
        try res.writeAll("Hello, ");
        try res.writeAll("Redirected!\n");
        try res.finish();
    } else if (mem.eql(u8, res.request.target, "/redirect/4")) {
        res.transfer_encoding = .chunked;

        res.status = .found;
        try res.headers.append("location", "/redirect/3");

        try res.send();
        try res.writeAll("Hello, ");
        try res.writeAll("Redirected!\n");
        try res.finish();
    } else if (mem.eql(u8, res.request.target, "/redirect/invalid")) {
        const invalid_port = try getUnusedTcpPort();
        const location = try std.fmt.allocPrint(salloc, "http://127.0.0.1:{d}", .{invalid_port});
        defer salloc.free(location);

        res.status = .found;
        try res.headers.append("location", location);
        try res.send();
        try res.finish();
    } else {
        res.status = .not_found;
        try res.send();
    }
}

var handle_new_requests = true;

fn runServer(srv: *Server) !void {
    outer: while (handle_new_requests) {
        var res = try srv.accept(.{
            .allocator = salloc,
            .header_strategy = .{ .dynamic = max_header_size },
        });
        defer res.deinit();

        while (res.reset() != .closing) {
            res.wait() catch |err| switch (err) {
                error.HttpHeadersInvalid => continue :outer,
                error.EndOfStream => continue,
                else => return err,
            };

            try handleRequest(&res);
        }
    }
}

fn serverThread(srv: *Server) void {
    defer srv.deinit();
    defer _ = gpa_server.deinit();

    runServer(srv) catch |err| {
        std.debug.print("server error: {}\n", .{err});

        if (@errorReturnTrace()) |trace| {
            std.debug.dumpStackTrace(trace.*);
        }

        _ = gpa_server.deinit();
        std.os.exit(1);
    };
}

fn killServer(addr: std.net.Address) void {
    handle_new_requests = false;

    const conn = std.net.tcpConnectToAddress(addr) catch return;
    conn.close();
}

fn getUnusedTcpPort() !u16 {
    const addr = try std.net.Address.parseIp("127.0.0.1", 0);
    var s = std.net.StreamServer.init(.{});
    defer s.deinit();
    try s.listen(addr);
    return s.listen_address.in.getPort();
}

pub fn main() !void {
    const log = std.log.scoped(.client);

    defer _ = gpa_client.deinit();

    server = Server.init(salloc, .{ .reuse_address = true });

    const addr = std.net.Address.parseIp("127.0.0.1", 0) catch unreachable;
    try server.listen(addr);

    const port = server.socket.listen_address.getPort();

    const server_thread = try std.Thread.spawn(.{}, serverThread, .{&server});

    var client = Client{ .allocator = calloc };
    errdefer client.deinit();
    // defer client.deinit(); handled below

    try client.loadDefaultProxies();

    { // read content-length response
        var h = http.Headers{ .allocator = calloc };
        defer h.deinit();

        const location = try std.fmt.allocPrint(calloc, "http://127.0.0.1:{d}/get", .{port});
        defer calloc.free(location);
        const uri = try std.Uri.parse(location);

        log.info("{s}", .{location});
        var req = try client.open(.GET, uri, h, .{});
        defer req.deinit();

        try req.send(.{});
        try req.wait();

        const body = try req.reader().readAllAlloc(calloc, 8192);
        defer calloc.free(body);

        try testing.expectEqualStrings("Hello, World!\n", body);
        try testing.expectEqualStrings("text/plain", req.response.headers.getFirstValue("content-type").?);
    }

    // connection has been kept alive
    try testing.expect(client.http_proxy != null or client.connection_pool.free_len == 1);

    { // read large content-length response
        var h = http.Headers{ .allocator = calloc };
        defer h.deinit();

        const location = try std.fmt.allocPrint(calloc, "http://127.0.0.1:{d}/large", .{port});
        defer calloc.free(location);
        const uri = try std.Uri.parse(location);

        log.info("{s}", .{location});
        var req = try client.open(.GET, uri, h, .{});
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
        var h = http.Headers{ .allocator = calloc };
        defer h.deinit();

        const location = try std.fmt.allocPrint(calloc, "http://127.0.0.1:{d}/get", .{port});
        defer calloc.free(location);
        const uri = try std.Uri.parse(location);

        log.info("{s}", .{location});
        var req = try client.open(.HEAD, uri, h, .{});
        defer req.deinit();

        try req.send(.{});
        try req.wait();

        const body = try req.reader().readAllAlloc(calloc, 8192);
        defer calloc.free(body);

        try testing.expectEqualStrings("", body);
        try testing.expectEqualStrings("text/plain", req.response.headers.getFirstValue("content-type").?);
        try testing.expectEqualStrings("14", req.response.headers.getFirstValue("content-length").?);
    }

    // connection has been kept alive
    try testing.expect(client.http_proxy != null or client.connection_pool.free_len == 1);

    { // read chunked response
        var h = http.Headers{ .allocator = calloc };
        defer h.deinit();

        const location = try std.fmt.allocPrint(calloc, "http://127.0.0.1:{d}/get?chunked", .{port});
        defer calloc.free(location);
        const uri = try std.Uri.parse(location);

        log.info("{s}", .{location});
        var req = try client.open(.GET, uri, h, .{});
        defer req.deinit();

        try req.send(.{});
        try req.wait();

        const body = try req.reader().readAllAlloc(calloc, 8192);
        defer calloc.free(body);

        try testing.expectEqualStrings("Hello, World!\n", body);
        try testing.expectEqualStrings("text/plain", req.response.headers.getFirstValue("content-type").?);
    }

    // connection has been kept alive
    try testing.expect(client.http_proxy != null or client.connection_pool.free_len == 1);

    { // send head request and not read chunked
        var h = http.Headers{ .allocator = calloc };
        defer h.deinit();

        const location = try std.fmt.allocPrint(calloc, "http://127.0.0.1:{d}/get?chunked", .{port});
        defer calloc.free(location);
        const uri = try std.Uri.parse(location);

        log.info("{s}", .{location});
        var req = try client.open(.HEAD, uri, h, .{});
        defer req.deinit();

        try req.send(.{});
        try req.wait();

        const body = try req.reader().readAllAlloc(calloc, 8192);
        defer calloc.free(body);

        try testing.expectEqualStrings("", body);
        try testing.expectEqualStrings("text/plain", req.response.headers.getFirstValue("content-type").?);
        try testing.expectEqualStrings("chunked", req.response.headers.getFirstValue("transfer-encoding").?);
    }

    // connection has been kept alive
    try testing.expect(client.http_proxy != null or client.connection_pool.free_len == 1);

    { // check trailing headers
        var h = http.Headers{ .allocator = calloc };
        defer h.deinit();

        const location = try std.fmt.allocPrint(calloc, "http://127.0.0.1:{d}/trailer", .{port});
        defer calloc.free(location);
        const uri = try std.Uri.parse(location);

        log.info("{s}", .{location});
        var req = try client.open(.GET, uri, h, .{});
        defer req.deinit();

        try req.send(.{});
        try req.wait();

        const body = try req.reader().readAllAlloc(calloc, 8192);
        defer calloc.free(body);

        try testing.expectEqualStrings("Hello, World!\n", body);
        try testing.expectEqualStrings("aaaa", req.response.headers.getFirstValue("x-checksum").?);
    }

    // connection has been kept alive
    try testing.expect(client.http_proxy != null or client.connection_pool.free_len == 1);

    { // send content-length request
        var h = http.Headers{ .allocator = calloc };
        defer h.deinit();

        try h.append("content-type", "text/plain");

        const location = try std.fmt.allocPrint(calloc, "http://127.0.0.1:{d}/echo-content", .{port});
        defer calloc.free(location);
        const uri = try std.Uri.parse(location);

        log.info("{s}", .{location});
        var req = try client.open(.POST, uri, h, .{});
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
        var h = http.Headers{ .allocator = calloc };
        defer h.deinit();

        try h.append("connection", "close");

        const location = try std.fmt.allocPrint(calloc, "http://127.0.0.1:{d}/get", .{port});
        defer calloc.free(location);
        const uri = try std.Uri.parse(location);

        log.info("{s}", .{location});
        var req = try client.open(.GET, uri, h, .{});
        defer req.deinit();

        try req.send(.{});
        try req.wait();

        const body = try req.reader().readAllAlloc(calloc, 8192);
        defer calloc.free(body);

        try testing.expectEqualStrings("Hello, World!\n", body);
        try testing.expectEqualStrings("text/plain", req.response.headers.getFirstValue("content-type").?);
    }

    // connection has been closed
    try testing.expect(client.connection_pool.free_len == 0);

    { // send chunked request
        var h = http.Headers{ .allocator = calloc };
        defer h.deinit();

        try h.append("content-type", "text/plain");

        const location = try std.fmt.allocPrint(calloc, "http://127.0.0.1:{d}/echo-content", .{port});
        defer calloc.free(location);
        const uri = try std.Uri.parse(location);

        log.info("{s}", .{location});
        var req = try client.open(.POST, uri, h, .{});
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
        var h = http.Headers{ .allocator = calloc };
        defer h.deinit();

        const location = try std.fmt.allocPrint(calloc, "http://127.0.0.1:{d}/redirect/1", .{port});
        defer calloc.free(location);
        const uri = try std.Uri.parse(location);

        log.info("{s}", .{location});
        var req = try client.open(.GET, uri, h, .{});
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
        var h = http.Headers{ .allocator = calloc };
        defer h.deinit();

        const location = try std.fmt.allocPrint(calloc, "http://127.0.0.1:{d}/redirect/2", .{port});
        defer calloc.free(location);
        const uri = try std.Uri.parse(location);

        log.info("{s}", .{location});
        var req = try client.open(.GET, uri, h, .{});
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
        var h = http.Headers{ .allocator = calloc };
        defer h.deinit();

        const location = try std.fmt.allocPrint(calloc, "http://127.0.0.1:{d}/redirect/3", .{port});
        defer calloc.free(location);
        const uri = try std.Uri.parse(location);

        log.info("{s}", .{location});
        var req = try client.open(.GET, uri, h, .{});
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
        var h = http.Headers{ .allocator = calloc };
        defer h.deinit();

        const location = try std.fmt.allocPrint(calloc, "http://127.0.0.1:{d}/redirect/4", .{port});
        defer calloc.free(location);
        const uri = try std.Uri.parse(location);

        log.info("{s}", .{location});
        var req = try client.open(.GET, uri, h, .{});
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
        var h = http.Headers{ .allocator = calloc };
        defer h.deinit();

        const location = try std.fmt.allocPrint(calloc, "http://127.0.0.1:{d}/redirect/invalid", .{port});
        defer calloc.free(location);
        const uri = try std.Uri.parse(location);

        log.info("{s}", .{location});
        var req = try client.open(.GET, uri, h, .{});
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
        var h = http.Headers{ .allocator = calloc };
        defer h.deinit();

        try h.append("content-type", "text/plain");

        const location = try std.fmt.allocPrint(calloc, "http://127.0.0.1:{d}/echo-content#fetch", .{port});
        defer calloc.free(location);

        log.info("{s}", .{location});
        var res = try client.fetch(calloc, .{
            .location = .{ .url = location },
            .method = .POST,
            .headers = h,
            .payload = .{ .string = "Hello, World!\n" },
        });
        defer res.deinit();

        try testing.expectEqualStrings("Hello, World!\n", res.body.?);
    }

    { // expect: 100-continue
        var h = http.Headers{ .allocator = calloc };
        defer h.deinit();

        try h.append("expect", "100-continue");
        try h.append("content-type", "text/plain");

        const location = try std.fmt.allocPrint(calloc, "http://127.0.0.1:{d}/echo-content#expect-100", .{port});
        defer calloc.free(location);
        const uri = try std.Uri.parse(location);

        log.info("{s}", .{location});
        var req = try client.open(.POST, uri, h, .{});
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
        var h = http.Headers{ .allocator = calloc };
        defer h.deinit();

        try h.append("content-type", "text/plain");
        try h.append("expect", "garbage");

        const location = try std.fmt.allocPrint(calloc, "http://127.0.0.1:{d}/echo-content#expect-garbage", .{port});
        defer calloc.free(location);
        const uri = try std.Uri.parse(location);

        log.info("{s}", .{location});
        var req = try client.open(.POST, uri, h, .{});
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

        for (0..total_connections) |i| {
            var req = try client.open(.GET, uri, .{ .allocator = calloc }, .{});
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

    killServer(server.socket.listen_address);
    server_thread.join();
}
