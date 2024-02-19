stream: std.net.Stream,

read_buf: [buffer_size]u8,
read_start: u16,
read_end: u16,

pub const buffer_size = std.crypto.tls.max_ciphertext_record_len;

pub fn rawReadAtLeast(conn: *Connection, buffer: []u8, len: usize) ReadError!usize {
    return conn.stream.readAtLeast(buffer, len) catch |err| {
        switch (err) {
            error.ConnectionResetByPeer, error.BrokenPipe => return error.ConnectionResetByPeer,
            else => return error.UnexpectedReadFailure,
        }
    };
}

pub fn fill(conn: *Connection) ReadError!void {
    if (conn.read_end != conn.read_start) return;

    const nread = try conn.rawReadAtLeast(conn.read_buf[0..], 1);
    if (nread == 0) return error.EndOfStream;
    conn.read_start = 0;
    conn.read_end = @intCast(nread);
}

pub fn peek(conn: *Connection) []const u8 {
    return conn.read_buf[conn.read_start..conn.read_end];
}

pub fn drop(conn: *Connection, num: u16) void {
    conn.read_start += num;
}

pub fn readAtLeast(conn: *Connection, buffer: []u8, len: usize) ReadError!usize {
    assert(len <= buffer.len);

    var out_index: u16 = 0;
    while (out_index < len) {
        const available_read = conn.read_end - conn.read_start;
        const available_buffer = buffer.len - out_index;

        if (available_read > available_buffer) { // partially read buffered data
            @memcpy(buffer[out_index..], conn.read_buf[conn.read_start..conn.read_end][0..available_buffer]);
            out_index += @as(u16, @intCast(available_buffer));
            conn.read_start += @as(u16, @intCast(available_buffer));

            break;
        } else if (available_read > 0) { // fully read buffered data
            @memcpy(buffer[out_index..][0..available_read], conn.read_buf[conn.read_start..conn.read_end]);
            out_index += available_read;
            conn.read_start += available_read;

            if (out_index >= len) break;
        }

        const leftover_buffer = available_buffer - available_read;
        const leftover_len = len - out_index;

        if (leftover_buffer > conn.read_buf.len) {
            // skip the buffer if the output is large enough
            return conn.rawReadAtLeast(buffer[out_index..], leftover_len);
        }

        try conn.fill();
    }

    return out_index;
}

pub fn read(conn: *Connection, buffer: []u8) ReadError!usize {
    return conn.readAtLeast(buffer, 1);
}

pub const ReadError = error{
    ConnectionTimedOut,
    ConnectionResetByPeer,
    UnexpectedReadFailure,
    EndOfStream,
};

pub const Reader = std.io.Reader(*Connection, ReadError, read);

pub fn reader(conn: *Connection) Reader {
    return .{ .context = conn };
}

pub fn writeAll(conn: *Connection, buffer: []const u8) WriteError!void {
    return conn.stream.writeAll(buffer) catch |err| switch (err) {
        error.BrokenPipe, error.ConnectionResetByPeer => return error.ConnectionResetByPeer,
        else => return error.UnexpectedWriteFailure,
    };
}

pub fn write(conn: *Connection, buffer: []const u8) WriteError!usize {
    return conn.stream.write(buffer) catch |err| switch (err) {
        error.BrokenPipe, error.ConnectionResetByPeer => return error.ConnectionResetByPeer,
        else => return error.UnexpectedWriteFailure,
    };
}

pub const WriteError = error{
    ConnectionResetByPeer,
    UnexpectedWriteFailure,
};

pub const Writer = std.io.Writer(*Connection, WriteError, write);

pub fn writer(conn: *Connection) Writer {
    return .{ .context = conn };
}

pub fn close(conn: *Connection) void {
    conn.stream.close();
}

const Connection = @This();
const std = @import("../../std.zig");
const assert = std.debug.assert;
