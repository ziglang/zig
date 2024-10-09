//! See https://tools.ietf.org/html/rfc6455

const builtin = @import("builtin");
const std = @import("std");
const WebSocket = @This();
const assert = std.debug.assert;
const native_endian = builtin.cpu.arch.endian();

key: []const u8,
request: *std.http.Server.Request,
recv_fifo: std.fifo.LinearFifo(u8, .Slice),
reader: std.io.AnyReader,
response: std.http.Server.Response,
/// Number of bytes that have been peeked but not discarded yet.
outstanding_len: usize,

pub const InitError = error{WebSocketUpgradeMissingKey} ||
    std.http.Server.Request.ReaderError;

pub fn init(
    ws: *WebSocket,
    request: *std.http.Server.Request,
    send_buffer: []u8,
    recv_buffer: []align(4) u8,
) InitError!bool {
    var sec_websocket_key: ?[]const u8 = null;
    var upgrade_websocket: bool = false;
    var it = request.iterateHeaders();
    while (it.next()) |header| {
        if (std.ascii.eqlIgnoreCase(header.name, "sec-websocket-key")) {
            sec_websocket_key = header.value;
        } else if (std.ascii.eqlIgnoreCase(header.name, "upgrade")) {
            if (!std.ascii.eqlIgnoreCase(header.value, "websocket"))
                return false;
            upgrade_websocket = true;
        }
    }
    if (!upgrade_websocket)
        return false;

    const key = sec_websocket_key orelse return error.WebSocketUpgradeMissingKey;

    var sha1 = std.crypto.hash.Sha1.init(.{});
    sha1.update(key);
    sha1.update("258EAFA5-E914-47DA-95CA-C5AB0DC85B11");
    var digest: [std.crypto.hash.Sha1.digest_length]u8 = undefined;
    sha1.final(&digest);
    var base64_digest: [28]u8 = undefined;
    assert(std.base64.standard.Encoder.encode(&base64_digest, &digest).len == base64_digest.len);

    request.head.content_length = std.math.maxInt(u64);

    ws.* = .{
        .key = key,
        .recv_fifo = std.fifo.LinearFifo(u8, .Slice).init(recv_buffer),
        .reader = try request.reader(),
        .response = request.respondStreaming(.{
            .send_buffer = send_buffer,
            .respond_options = .{
                .status = .switching_protocols,
                .extra_headers = &.{
                    .{ .name = "upgrade", .value = "websocket" },
                    .{ .name = "connection", .value = "upgrade" },
                    .{ .name = "sec-websocket-accept", .value = &base64_digest },
                },
                .transfer_encoding = .none,
            },
        }),
        .request = request,
        .outstanding_len = 0,
    };
    return true;
}

pub const Header0 = packed struct(u8) {
    opcode: Opcode,
    rsv3: u1 = 0,
    rsv2: u1 = 0,
    rsv1: u1 = 0,
    fin: bool,
};

pub const Header1 = packed struct(u8) {
    payload_len: enum(u7) {
        len16 = 126,
        len64 = 127,
        _,
    },
    mask: bool,
};

pub const Opcode = enum(u4) {
    continuation = 0,
    text = 1,
    binary = 2,
    connection_close = 8,
    ping = 9,
    /// "A Pong frame MAY be sent unsolicited. This serves as a unidirectional
    /// heartbeat. A response to an unsolicited Pong frame is not expected."
    pong = 10,
    _,
};

pub const ReadSmallTextMessageError = error{
    ConnectionClose,
    UnexpectedOpCode,
    MessageTooBig,
    MissingMaskBit,
} || RecvError;

pub const SmallMessage = struct {
    /// Can be text, binary, or ping.
    opcode: Opcode,
    data: []u8,
};

/// Reads the next message from the WebSocket stream, failing if the message does not fit
/// into `recv_buffer`.
pub fn readSmallMessage(ws: *WebSocket) ReadSmallTextMessageError!SmallMessage {
    while (true) {
        const header_bytes = (try recv(ws, 2))[0..2];
        const h0: Header0 = @bitCast(header_bytes[0]);
        const h1: Header1 = @bitCast(header_bytes[1]);

        switch (h0.opcode) {
            .text, .binary, .pong, .ping => {},
            .connection_close => return error.ConnectionClose,
            .continuation => return error.UnexpectedOpCode,
            _ => return error.UnexpectedOpCode,
        }

        if (!h0.fin) return error.MessageTooBig;
        if (!h1.mask) return error.MissingMaskBit;

        const len: usize = switch (h1.payload_len) {
            .len16 => try recvReadInt(ws, u16),
            .len64 => std.math.cast(usize, try recvReadInt(ws, u64)) orelse return error.MessageTooBig,
            else => @intFromEnum(h1.payload_len),
        };
        if (len > ws.recv_fifo.buf.len) return error.MessageTooBig;

        const mask: u32 = @bitCast((try recv(ws, 4))[0..4].*);
        const payload = try recv(ws, len);

        // Skip pongs.
        if (h0.opcode == .pong) continue;

        // The last item may contain a partial word of unused data.
        const floored_len = (payload.len / 4) * 4;
        const u32_payload: []align(1) u32 = @alignCast(std.mem.bytesAsSlice(u32, payload[0..floored_len]));
        for (u32_payload) |*elem| elem.* ^= mask;
        const mask_bytes = std.mem.asBytes(&mask)[0 .. payload.len - floored_len];
        for (payload[floored_len..], mask_bytes) |*leftover, m| leftover.* ^= m;

        return .{
            .opcode = h0.opcode,
            .data = payload,
        };
    }
}

const RecvError = std.http.Server.Request.ReadError || error{EndOfStream};

fn recv(ws: *WebSocket, len: usize) RecvError![]u8 {
    ws.recv_fifo.discard(ws.outstanding_len);
    assert(len <= ws.recv_fifo.buf.len);
    if (len > ws.recv_fifo.count) {
        const small_buf = ws.recv_fifo.writableSlice(0);
        const needed = len - ws.recv_fifo.count;
        const buf = if (small_buf.len >= needed) small_buf else b: {
            ws.recv_fifo.realign();
            break :b ws.recv_fifo.writableSlice(0);
        };
        const n = try @as(RecvError!usize, @errorCast(ws.reader.readAtLeast(buf, needed)));
        if (n < needed) return error.EndOfStream;
        ws.recv_fifo.update(n);
    }
    ws.outstanding_len = len;
    // TODO: improve the std lib API so this cast isn't necessary.
    return @constCast(ws.recv_fifo.readableSliceOfLen(len));
}

fn recvReadInt(ws: *WebSocket, comptime I: type) !I {
    const unswapped: I = @bitCast((try recv(ws, @sizeOf(I)))[0..@sizeOf(I)].*);
    return switch (native_endian) {
        .little => @byteSwap(unswapped),
        .big => unswapped,
    };
}

pub const WriteError = std.http.Server.Response.WriteError;

pub fn writeMessage(ws: *WebSocket, message: []const u8, opcode: Opcode) WriteError!void {
    const iovecs: [1]std.posix.iovec_const = .{
        .{ .base = message.ptr, .len = message.len },
    };
    return writeMessagev(ws, &iovecs, opcode);
}

pub fn writeMessagev(ws: *WebSocket, message: []const std.posix.iovec_const, opcode: Opcode) WriteError!void {
    const total_len = l: {
        var total_len: u64 = 0;
        for (message) |iovec| total_len += iovec.len;
        break :l total_len;
    };

    var header_buf: [2 + 8]u8 = undefined;
    header_buf[0] = @bitCast(@as(Header0, .{
        .opcode = opcode,
        .fin = true,
    }));
    const header = switch (total_len) {
        0...125 => blk: {
            header_buf[1] = @bitCast(@as(Header1, .{
                .payload_len = @enumFromInt(total_len),
                .mask = false,
            }));
            break :blk header_buf[0..2];
        },
        126...0xffff => blk: {
            header_buf[1] = @bitCast(@as(Header1, .{
                .payload_len = .len16,
                .mask = false,
            }));
            std.mem.writeInt(u16, header_buf[2..4], @intCast(total_len), .big);
            break :blk header_buf[0..4];
        },
        else => blk: {
            header_buf[1] = @bitCast(@as(Header1, .{
                .payload_len = .len64,
                .mask = false,
            }));
            std.mem.writeInt(u64, header_buf[2..10], total_len, .big);
            break :blk header_buf[0..10];
        },
    };

    const response = &ws.response;
    try response.writeAll(header);
    for (message) |iovec|
        try response.writeAll(iovec.base[0..iovec.len]);
    try response.flush();
}
