//! This API is a barely-touched, barely-functional http client, just the
//! absolute minimum thing I needed in order to test `std.crypto.tls`. Bear
//! with me and I promise the API will become useful and streamlined.

const std = @import("../std.zig");
const assert = std.debug.assert;
const http = std.http;
const net = std.net;
const Client = @This();
const Url = std.Url;

/// TODO: remove this field (currently required due to tcpConnectToHost)
allocator: std.mem.Allocator,
ca_bundle: std.crypto.Certificate.Bundle = .{},

/// TODO: emit error.UnexpectedEndOfStream or something like that when the read
/// data does not match the content length. This is necessary since HTTPS disables
/// close_notify protection on underlying TLS streams.
pub const Request = struct {
    client: *Client,
    stream: net.Stream,
    tls_client: std.crypto.tls.Client,
    protocol: Protocol,
    response_headers: http.Headers,
    redirects_left: u32,

    pub const Headers = struct {
        method: http.Method = .GET,
        connection: Connection,

        pub const Connection = enum {
            close,
            @"keep-alive",
        };
    };

    pub const Protocol = enum { http, https };

    pub const Options = struct {
        max_redirects: u32 = 3,
    };

    pub fn readAll(req: *Request, buffer: []u8) !usize {
        return readAtLeast(req, buffer, buffer.len);
    }

    pub fn read(req: *Request, buffer: []u8) !usize {
        return readAtLeast(req, buffer, 1);
    }

    pub fn readAtLeast(req: *Request, buffer: []u8, len: usize) !usize {
        assert(len <= buffer.len);
        var index: usize = 0;
        while (index < len) {
            const headers_finished = req.response_headers.state == .finished;
            const amt = try readAdvanced(req, buffer[index..]);
            if (amt == 0 and headers_finished) break;
            index += amt;
        }
        return index;
    }

    /// This one can return 0 without meaning EOF.
    /// TODO change to readvAdvanced
    pub fn readAdvanced(req: *Request, buffer: []u8) !usize {
        if (req.response_headers.state == .finished) return readRaw(req, buffer);

        const amt = try readRaw(req, buffer);
        const data = buffer[0..amt];
        const i = req.response_headers.feed(data);
        if (req.response_headers.state == .invalid) return error.InvalidHttpHeaders;
        if (i < data.len) {
            const rest = data[i..];
            std.mem.copy(u8, buffer, rest);
            return rest.len;
        }
        return 0;
    }

    /// Only abstracts over http/https.
    fn readRaw(req: *Request, buffer: []u8) !usize {
        switch (req.protocol) {
            .http => return req.stream.read(buffer),
            .https => return req.tls_client.read(req.stream, buffer),
        }
    }

    /// Only abstracts over http/https.
    fn readAtLeastRaw(req: *Request, buffer: []u8, len: usize) !usize {
        switch (req.protocol) {
            .http => return req.stream.readAtLeast(buffer, len),
            .https => return req.tls_client.readAtLeast(req.stream, buffer, len),
        }
    }
};

pub fn deinit(client: *Client, gpa: std.mem.Allocator) void {
    client.ca_bundle.deinit(gpa);
    client.* = undefined;
}

pub fn request(client: *Client, url: Url, headers: Request.Headers, options: Request.Options) !Request {
    const protocol = std.meta.stringToEnum(Request.Protocol, url.scheme) orelse
        return error.UnsupportedUrlScheme;
    const port: u16 = url.port orelse switch (protocol) {
        .http => 80,
        .https => 443,
    };

    var req: Request = .{
        .client = client,
        .stream = try net.tcpConnectToHost(client.allocator, url.host, port),
        .protocol = protocol,
        .tls_client = undefined,
        .redirects_left = options.max_redirects,
    };

    switch (protocol) {
        .http => {},
        .https => {
            req.tls_client = try std.crypto.tls.Client.init(req.stream, client.ca_bundle, url.host);
            // This is appropriate for HTTPS because the HTTP headers contain
            // the content length which is used to detect truncation attacks.
            req.tls_client.allow_truncation_attacks = true;
        },
    }

    {
        var h = try std.BoundedArray(u8, 1000).init(0);
        try h.appendSlice(@tagName(headers.method));
        try h.appendSlice(" ");
        try h.appendSlice(url.path);
        try h.appendSlice(" HTTP/1.1\r\nHost: ");
        try h.appendSlice(url.host);
        switch (protocol) {
            .https => try h.appendSlice("\r\nUpgrade-Insecure-Requests: 1\r\n"),
            .http => try h.appendSlice("\r\n"),
        }
        try h.writer().print("Connection: {s}\r\n", .{@tagName(headers.connection)});
        try h.appendSlice("\r\n");

        const header_bytes = h.slice();
        switch (req.protocol) {
            .http => {
                try req.stream.writeAll(header_bytes);
            },
            .https => {
                try req.tls_client.writeAll(req.stream, header_bytes);
            },
        }
    }

    return req;
}
