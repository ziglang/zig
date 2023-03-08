const std = @import("std");
const http = std.http;
const Uri = std.Uri;
const mem = std.mem;
const assert = std.debug.assert;

const Client = @import("../Client.zig");
const Connection = Client.Connection;
const ConnectionNode = Client.ConnectionPool.Node;
const Response = @import("Response.zig");

const Request = @This();

const read_buffer_size = 8192;
const ReadBufferIndex = std.math.IntFittingRange(0, read_buffer_size);

uri: Uri,
client: *Client,
connection: *ConnectionNode,
response: Response,
/// These are stored in Request so that they are available when following
/// redirects.
headers: Headers,

redirects_left: u32,
handle_redirects: bool,
compression_init: bool,

/// Used as a allocator for resolving redirects locations.
arena: std.heap.ArenaAllocator,

/// Read buffer for the connection. This is used to pull in large amounts of data from the connection even if the user asks for a small amount. This can probably be removed with careful planning.
read_buffer: [read_buffer_size]u8 = undefined,
read_buffer_start: ReadBufferIndex = 0,
read_buffer_len: ReadBufferIndex = 0,

pub const RequestTransfer = union(enum) {
    content_length: u64,
    chunked: void,
    none: void,
};

pub const Headers = struct {
    version: http.Version = .@"HTTP/1.1",
    method: http.Method = .GET,
    user_agent: []const u8 = "zig (std.http)",
    connection: http.Connection = .keep_alive,
    transfer_encoding: RequestTransfer = .none,

    custom: []const http.CustomHeader = &[_]http.CustomHeader{},
};

pub const Options = struct {
    handle_redirects: bool = true,
    max_redirects: u32 = 3,
    header_strategy: HeaderStrategy = .{ .dynamic = 16 * 1024 },

    pub const HeaderStrategy = union(enum) {
        /// In this case, the client's Allocator will be used to store the
        /// entire HTTP header. This value is the maximum total size of
        /// HTTP headers allowed, otherwise
        /// error.HttpHeadersExceededSizeLimit is returned from read().
        dynamic: usize,
        /// This is used to store the entire HTTP header. If the HTTP
        /// header is too big to fit, `error.HttpHeadersExceededSizeLimit`
        /// is returned from read(). When this is used, `error.OutOfMemory`
        /// cannot be returned from `read()`.
        static: []u8,
    };
};

/// Frees all resources associated with the request.
pub fn deinit(req: *Request) void {
    switch (req.response.compression) {
        .none => {},
        .deflate => |*deflate| deflate.deinit(),
        .gzip => |*gzip| gzip.deinit(),
        .zstd => |*zstd| zstd.deinit(),
    }

    if (req.response.header_bytes_owned) {
        req.response.header_bytes.deinit(req.client.allocator);
    }

    if (!req.response.done) {
        // If the response wasn't fully read, then we need to close the connection.
        req.connection.data.closing = true;
        req.client.connection_pool.release(req.client, req.connection);
    }

    req.arena.deinit();
    req.* = undefined;
}

pub const ReadRawError = Connection.ReadError || Uri.ParseError || Client.RequestError || error{
    UnexpectedEndOfStream,
    TooManyHttpRedirects,
    HttpRedirectMissingLocation,
    HttpHeadersInvalid,
};

pub const ReaderRaw = std.io.Reader(*Request, ReadRawError, readRaw);

/// Read from the underlying stream, without decompressing or parsing the headers. Must be called
/// after waitForCompleteHead() has returned successfully.
pub fn readRaw(req: *Request, buffer: []u8) ReadRawError!usize {
    assert(req.response.state.isContent());

    var index: usize = 0;
    while (index == 0) {
        const amt = try req.readRawAdvanced(buffer[index..]);
        if (amt == 0 and req.response.done) break;
        index += amt;
    }

    return index;
}

fn checkForCompleteHead(req: *Request, buffer: []u8) !usize {
    switch (req.response.state) {
        .invalid => unreachable,
        .start, .seen_r, .seen_rn, .seen_rnr => {},
        else => return 0, // No more headers to read.
    }

    const i = req.response.findHeadersEnd(buffer[0..]);
    if (req.response.state == .invalid) return error.HttpHeadersInvalid;

    const headers_data = buffer[0..i];
    if (req.response.header_bytes.items.len + headers_data.len > req.response.max_header_bytes) {
        return error.HttpHeadersExceededSizeLimit;
    }
    try req.response.header_bytes.appendSlice(req.client.allocator, headers_data);

    if (req.response.state == .finished) {
        req.response.headers = try Response.Headers.parse(req.response.header_bytes.items);

        if (req.response.headers.upgrade) |_| {
            req.connection.data.closing = false;
            req.response.done = true;
            return i;
        }

        if (req.response.headers.connection == .keep_alive) {
            req.connection.data.closing = false;
        } else {
            req.connection.data.closing = true;
        }

        if (req.response.headers.transfer_encoding) |transfer_encoding| {
            switch (transfer_encoding) {
                .chunked => {
                    req.response.next_chunk_length = 0;
                    req.response.state = .chunk_size;
                },
            }
        } else if (req.response.headers.content_length) |content_length| {
            req.response.next_chunk_length = content_length;

            if (content_length == 0) req.response.done = true;
        } else {
            req.response.done = true;
        }

        return i;
    }

    return 0;
}

pub const WaitForCompleteHeadError = ReadRawError || error{
    UnexpectedEndOfStream,

    HttpHeadersExceededSizeLimit,
    ShortHttpStatusLine,
    BadHttpVersion,
    HttpHeaderContinuationsUnsupported,
    HttpTransferEncodingUnsupported,
    HttpConnectionHeaderUnsupported,
};

/// Reads a complete response head. Any leftover data is stored in the request. This function is idempotent.
pub fn waitForCompleteHead(req: *Request) WaitForCompleteHeadError!void {
    if (req.response.state.isContent()) return;

    while (true) {
        const nread = try req.connection.data.read(req.read_buffer[0..]);
        const amt = try checkForCompleteHead(req, req.read_buffer[0..nread]);

        if (amt != 0) {
            req.read_buffer_start = @intCast(ReadBufferIndex, amt);
            req.read_buffer_len = @intCast(ReadBufferIndex, nread);
            return;
        } else if (nread == 0) {
            return error.UnexpectedEndOfStream;
        }
    }
}

/// This one can return 0 without meaning EOF.
fn readRawAdvanced(req: *Request, buffer: []u8) !usize {
    assert(req.response.state.isContent());
    if (req.response.done) return 0;

    // var in: []const u8 = undefined;
    if (req.read_buffer_start == req.read_buffer_len) {
        const nread = try req.connection.data.read(req.read_buffer[0..]);
        if (nread == 0) return error.UnexpectedEndOfStream;

        req.read_buffer_start = 0;
        req.read_buffer_len = @intCast(ReadBufferIndex, nread);
    }

    var out_index: usize = 0;
    while (true) {
        switch (req.response.state) {
            .invalid, .start, .seen_r, .seen_rn, .seen_rnr => unreachable,
            .finished => {
                // TODO https://github.com/ziglang/zig/issues/14039
                const buf_avail = req.read_buffer_len - req.read_buffer_start;
                const data_avail = req.response.next_chunk_length;
                const out_avail = buffer.len;

                if (req.handle_redirects and req.response.headers.status.class() == .redirect) {
                    const can_read = @intCast(usize, @min(buf_avail, data_avail));
                    req.response.next_chunk_length -= can_read;

                    if (req.response.next_chunk_length == 0) {
                        req.client.connection_pool.release(req.client, req.connection);
                        req.connection = undefined;
                        req.response.done = true;
                    }

                    return 0; // skip over as much data as possible
                }

                const can_read = @intCast(usize, @min(@min(buf_avail, data_avail), out_avail));
                req.response.next_chunk_length -= can_read;

                mem.copy(u8, buffer[0..], req.read_buffer[req.read_buffer_start..][0..can_read]);
                req.read_buffer_start += @intCast(ReadBufferIndex, can_read);

                if (req.response.next_chunk_length == 0) {
                    req.client.connection_pool.release(req.client, req.connection);
                    req.connection = undefined;
                    req.response.done = true;
                }

                return can_read;
            },
            .chunk_size_prefix_r => switch (req.read_buffer_len - req.read_buffer_start) {
                0 => return out_index,
                1 => switch (req.read_buffer[req.read_buffer_start]) {
                    '\r' => {
                        req.response.state = .chunk_size_prefix_n;
                        return out_index;
                    },
                    else => {
                        req.response.state = .invalid;
                        return error.HttpHeadersInvalid;
                    },
                },
                else => switch (int16(req.read_buffer[req.read_buffer_start..][0..2])) {
                    int16("\r\n") => {
                        req.read_buffer_start += 2;
                        req.response.state = .chunk_size;
                        continue;
                    },
                    else => {
                        req.response.state = .invalid;
                        return error.HttpHeadersInvalid;
                    },
                },
            },
            .chunk_size_prefix_n => switch (req.read_buffer_len - req.read_buffer_start) {
                0 => return out_index,
                else => switch (req.read_buffer[req.read_buffer_start]) {
                    '\n' => {
                        req.read_buffer_start += 1;
                        req.response.state = .chunk_size;
                        continue;
                    },
                    else => {
                        req.response.state = .invalid;
                        return error.HttpHeadersInvalid;
                    },
                },
            },
            .chunk_size, .chunk_r => {
                const i = req.response.findChunkedLen(req.read_buffer[req.read_buffer_start..req.read_buffer_len]);
                switch (req.response.state) {
                    .invalid => return error.HttpHeadersInvalid,
                    .chunk_data => {
                        if (req.response.next_chunk_length == 0) {
                            req.response.done = true;
                            req.client.connection_pool.release(req.client, req.connection);
                            req.connection = undefined;

                            return out_index;
                        }

                        req.read_buffer_start += @intCast(ReadBufferIndex, i);
                        continue;
                    },
                    .chunk_size => return out_index,
                    else => unreachable,
                }
            },
            .chunk_data => {
                // TODO https://github.com/ziglang/zig/issues/14039
                const buf_avail = req.read_buffer_len - req.read_buffer_start;
                const data_avail = req.response.next_chunk_length;
                const out_avail = buffer.len - out_index;

                if (req.handle_redirects and req.response.headers.status.class() == .redirect) {
                    const can_read = @intCast(usize, @min(buf_avail, data_avail));
                    req.response.next_chunk_length -= can_read;

                    if (req.response.next_chunk_length == 0) {
                        req.client.connection_pool.release(req.client, req.connection);
                        req.connection = undefined;
                        req.response.done = true;
                        continue;
                    }

                    return 0; // skip over as much data as possible
                }

                const can_read = @intCast(usize, @min(@min(buf_avail, data_avail), out_avail));
                req.response.next_chunk_length -= can_read;

                mem.copy(u8, buffer[out_index..], req.read_buffer[req.read_buffer_start..][0..can_read]);
                req.read_buffer_start += @intCast(ReadBufferIndex, can_read);
                out_index += can_read;

                if (req.response.next_chunk_length == 0) {
                    req.response.state = .chunk_size_prefix_r;

                    continue;
                }

                return out_index;
            },
        }
    }
}

pub const ReadError = Client.DeflateDecompressor.Error || Client.GzipDecompressor.Error || Client.ZstdDecompressor.Error || WaitForCompleteHeadError || error{ BadHeader, InvalidCompression, StreamTooLong, InvalidWindowSize, CompressionNotSupported };

pub const Reader = std.io.Reader(*Request, ReadError, read);

pub fn reader(req: *Request) Reader {
    return .{ .context = req };
}

pub fn read(req: *Request, buffer: []u8) ReadError!usize {
    while (true) {
        if (!req.response.state.isContent()) try req.waitForCompleteHead();

        if (req.handle_redirects and req.response.headers.status.class() == .redirect) {
            assert(try req.readRaw(buffer) == 0);

            if (req.redirects_left == 0) return error.TooManyHttpRedirects;

            const location = req.response.headers.location orelse
                return error.HttpRedirectMissingLocation;
            const new_url = Uri.parse(location) catch try Uri.parseWithoutScheme(location);

            var new_arena = std.heap.ArenaAllocator.init(req.client.allocator);
            const resolved_url = try req.uri.resolve(new_url, false, new_arena.allocator());
            errdefer new_arena.deinit();

            req.arena.deinit();
            req.arena = new_arena;

            const new_req = try req.client.request(resolved_url, req.headers, .{
                .max_redirects = req.redirects_left - 1,
                .header_strategy = if (req.response.header_bytes_owned) .{
                    .dynamic = req.response.max_header_bytes,
                } else .{
                    .static = req.response.header_bytes.unusedCapacitySlice(),
                },
            });
            req.deinit();
            req.* = new_req;
        } else {
            break;
        }
    }

    if (req.response.compression == .none) {
        if (req.response.headers.transfer_compression) |compression| {
            switch (compression) {
                .compress => return error.CompressionNotSupported,
                .deflate => req.response.compression = .{
                    .deflate = try std.compress.zlib.zlibStream(req.client.allocator, ReaderRaw{ .context = req }),
                },
                .gzip => req.response.compression = .{
                    .gzip = try std.compress.gzip.decompress(req.client.allocator, ReaderRaw{ .context = req }),
                },
                .zstd => req.response.compression = .{
                    .zstd = std.compress.zstd.decompressStream(req.client.allocator, ReaderRaw{ .context = req }),
                },
            }
        }
    }

    return switch (req.response.compression) {
        .deflate => |*deflate| try deflate.read(buffer),
        .gzip => |*gzip| try gzip.read(buffer),
        .zstd => |*zstd| try zstd.read(buffer),
        else => try req.readRaw(buffer),
    };
}

pub fn readAll(req: *Request, buffer: []u8) !usize {
    var index: usize = 0;
    while (index < buffer.len) {
        const amt = try read(req, buffer[index..]);
        if (amt == 0) break;
        index += amt;
    }
    return index;
}

pub const WriteError = Connection.WriteError || error{MessageTooLong};

pub const Writer = std.io.Writer(*Request, WriteError, write);

pub fn writer(req: *Request) Writer {
    return .{ .context = req };
}

/// Write `bytes` to the server. The `transfer_encoding` request header determines how data will be sent.
pub fn write(req: *Request, bytes: []const u8) !usize {
    switch (req.headers.transfer_encoding) {
        .chunked => {
            try req.connection.data.writer().print("{x}\r\n", .{bytes.len});
            try req.connection.data.writeAll(bytes);
            try req.connection.data.writeAll("\r\n");

            return bytes.len;
        },
        .content_length => |*len| {
            if (len.* < bytes.len) return error.MessageTooLong;

            const amt = try req.connection.data.write(bytes);
            len.* -= amt;
            return amt;
        },
        .none => return error.NotWriteable,
    }
}

/// Finish the body of a request. This notifies the server that you have no more data to send.
pub fn finish(req: *Request) !void {
    switch (req.headers.transfer_encoding) {
        .chunked => try req.connection.data.writeAll("0\r\n"),
        .content_length => |len| if (len != 0) return error.MessageNotCompleted,
        .none => {},
    }
}

inline fn int16(array: *const [2]u8) u16 {
    return @bitCast(u16, array.*);
}

inline fn int32(array: *const [4]u8) u32 {
    return @bitCast(u32, array.*);
}

inline fn int64(array: *const [8]u8) u64 {
    return @bitCast(u64, array.*);
}

test {
    const builtin = @import("builtin");

    if (builtin.os.tag == .wasi) return error.SkipZigTest;

    _ = Response;
}
