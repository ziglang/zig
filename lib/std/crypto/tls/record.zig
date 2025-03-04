const std = @import("std");
const assert = std.debug.assert;
const mem = std.mem;
const io = std.io;

const proto = @import("protocol.zig");
const cipher = @import("cipher.zig");
const Cipher = cipher.Cipher;
const record = @import("record.zig");

pub const header_len = 5;

pub inline fn int2(int: u16) [2]u8 {
    var arr: [2]u8 = undefined;
    std.mem.writeInt(u16, &arr, int, .big);
    return arr;
}

pub inline fn int3(int: u24) [3]u8 {
    var arr: [3]u8 = undefined;
    std.mem.writeInt(u24, &arr, int, .big);
    return arr;
}

pub fn header(content_type: proto.ContentType, payload_len: usize) [header_len]u8 {
    return [1]u8{@intFromEnum(content_type)} ++
        int2(@intFromEnum(proto.Version.tls_1_2)) ++
        int2(@intCast(payload_len));
}

pub fn handshakeHeader(handshake_type: proto.Handshake, payload_len: usize) [4]u8 {
    return [1]u8{@intFromEnum(handshake_type)} ++ int3(@intCast(payload_len));
}

pub fn reader(inner_reader: anytype) Reader(@TypeOf(inner_reader)) {
    return .{ .inner_reader = inner_reader };
}

pub fn bufferReader(buf: []u8) Reader([]u8) {
    return .{
        .inner_reader = undefined,
        .buffer = buf,
        .end = buf.len,
    };
}

pub fn Reader(comptime InnerReader: type) type {
    const is_slice = isSlice(InnerReader);
    return struct {
        inner_reader: if (is_slice) void else InnerReader,

        buffer: if (is_slice) InnerReader else [cipher.max_ciphertext_record_len]u8 = undefined,
        start: usize = 0,
        end: usize = 0,

        const ReaderT = @This();

        pub fn nextDecoder(r: *ReaderT) !Decoder {
            const rec = (try r.next()) orelse return error.EndOfStream;
            if (@intFromEnum(rec.protocol_version) != 0x0300 and
                @intFromEnum(rec.protocol_version) != 0x0301 and
                rec.protocol_version != .tls_1_2)
                return error.TlsBadVersion;
            return .{
                .content_type = rec.content_type,
                .payload = rec.payload,
            };
        }

        pub fn contentType(buf: []const u8) proto.ContentType {
            return @enumFromInt(buf[0]);
        }

        pub fn protocolVersion(buf: []const u8) proto.Version {
            return @enumFromInt(mem.readInt(u16, buf[1..3], .big));
        }

        pub fn next(r: *ReaderT) !?Record {
            while (true) {
                const buffer = r.buffer[r.start..r.end];
                // If we have 5 bytes header.
                if (buffer.len >= record.header_len) {
                    const record_header = buffer[0..record.header_len];
                    const payload_len = mem.readInt(u16, record_header[3..5], .big);
                    if (payload_len > cipher.max_ciphertext_len)
                        return error.TlsRecordOverflow;
                    const record_len = record.header_len + payload_len;
                    // If we have whole record
                    if (buffer.len >= record_len) {
                        r.start += record_len;
                        return Record.init(buffer[0..record_len]);
                    }
                }
                if (is_slice) return null;

                { // Move dirty part to the start of the buffer.
                    const n = r.end - r.start;
                    if (n > 0 and r.start > 0) {
                        if (r.start > n) {
                            @memcpy(r.buffer[0..n], r.buffer[r.start..][0..n]);
                        } else {
                            mem.copyForwards(u8, r.buffer[0..n], r.buffer[r.start..][0..n]);
                        }
                    }
                    r.start = 0;
                    r.end = n;
                }
                { // Read more from inner_reader.
                    const n = try r.inner_reader.read(r.buffer[r.end..]);
                    if (n == 0) return null;
                    r.end += n;
                }
            }
        }

        pub fn nextDecrypt(r: *ReaderT, cph: *Cipher) !?struct { proto.ContentType, []const u8 } {
            const rec = (try r.next()) orelse return null;
            if (rec.protocol_version != .tls_1_2) return error.TlsBadVersion;

            return try cph.decrypt(
                // Reuse reader buffer for cleartext. `rec.header` and
                // `rec.payload`(ciphertext) are also pointing somewhere in
                // this buffer. Decrypter is first reading then writing a
                // block, cleartext has less length then ciphertext,
                // cleartext starts from the beginning of the buffer, so
                // ciphertext is always ahead of cleartext.
                r.buffer[0..r.start],
                rec,
            );
        }

        pub fn hasMore(r: *ReaderT) bool {
            return r.end > r.start;
        }

        pub fn bytesRead(r: *ReaderT) usize {
            return r.start;
        }
    };
}

pub const Record = struct {
    content_type: proto.ContentType,
    protocol_version: proto.Version = .tls_1_2,
    header: []const u8,
    payload: []const u8,

    pub fn init(buffer: []const u8) Record {
        return .{
            .content_type = @enumFromInt(buffer[0]),
            .protocol_version = @enumFromInt(mem.readInt(u16, buffer[1..3], .big)),
            .header = buffer[0..record.header_len],
            .payload = buffer[record.header_len..],
        };
    }

    pub fn decoder(r: @This()) Decoder {
        return Decoder.init(r.content_type, @constCast(r.payload));
    }
};

pub const Decoder = struct {
    content_type: proto.ContentType,
    payload: []const u8,
    idx: usize = 0,

    pub fn init(content_type: proto.ContentType, payload: []u8) Decoder {
        return .{
            .content_type = content_type,
            .payload = payload,
        };
    }

    pub fn decode(d: *Decoder, comptime T: type) !T {
        switch (@typeInfo(T)) {
            .int => |info| switch (info.bits) {
                8 => {
                    try skip(d, 1);
                    return d.payload[d.idx - 1];
                },
                16 => {
                    try skip(d, 2);
                    const b0: u16 = d.payload[d.idx - 2];
                    const b1: u16 = d.payload[d.idx - 1];
                    return (b0 << 8) | b1;
                },
                24 => {
                    try skip(d, 3);
                    const b0: u24 = d.payload[d.idx - 3];
                    const b1: u24 = d.payload[d.idx - 2];
                    const b2: u24 = d.payload[d.idx - 1];
                    return (b0 << 16) | (b1 << 8) | b2;
                },
                else => @compileError("unsupported int type: " ++ @typeName(T)),
            },
            .@"enum" => |info| {
                const int = try d.decode(info.tag_type);
                if (info.is_exhaustive) @compileError("exhaustive enum cannot be used");
                return @as(T, @enumFromInt(int));
            },
            else => @compileError("unsupported type: " ++ @typeName(T)),
        }
    }

    pub fn array(d: *Decoder, comptime len: usize) ![len]u8 {
        try d.skip(len);
        return d.payload[d.idx - len ..][0..len].*;
    }

    pub fn slice(d: *Decoder, len: usize) ![]const u8 {
        try d.skip(len);
        return d.payload[d.idx - len ..][0..len];
    }

    pub fn skip(d: *Decoder, amt: usize) !void {
        if (d.idx + amt > d.payload.len) return error.TlsDecodeError;
        d.idx += amt;
    }

    pub fn rest(d: Decoder) []const u8 {
        return d.payload[d.idx..];
    }

    pub fn eof(d: Decoder) bool {
        return d.idx == d.payload.len;
    }

    pub fn expectContentType(d: *Decoder, content_type: proto.ContentType) !void {
        if (d.content_type == content_type) return;

        switch (d.content_type) {
            .alert => try d.raiseAlert(),
            else => return error.TlsUnexpectedMessage,
        }
    }

    pub fn raiseAlert(d: *Decoder) !void {
        if (d.payload.len < 2) return error.TlsUnexpectedMessage;
        try proto.Alert.parse(try d.array(2)).toError();
        return error.TlsAlertCloseNotify;
    }
};

const testing = std.testing;
const data12 = @import("testdata/tls12.zig");
const testu = @import("testu.zig");
const CipherSuite = @import("cipher.zig").CipherSuite;

test Reader {
    var fbs = io.fixedBufferStream(&data12.server_responses);
    var rdr = reader(fbs.reader());

    const expected = [_]struct {
        content_type: proto.ContentType,
        payload_len: usize,
    }{
        .{ .content_type = .handshake, .payload_len = 49 },
        .{ .content_type = .handshake, .payload_len = 815 },
        .{ .content_type = .handshake, .payload_len = 300 },
        .{ .content_type = .handshake, .payload_len = 4 },
        .{ .content_type = .change_cipher_spec, .payload_len = 1 },
        .{ .content_type = .handshake, .payload_len = 64 },
    };
    for (expected) |e| {
        const rec = (try rdr.next()).?;
        try testing.expectEqual(e.content_type, rec.content_type);
        try testing.expectEqual(e.payload_len, rec.payload.len);
        try testing.expectEqual(.tls_1_2, rec.protocol_version);
    }

    {
        var fr = bufferReader(@constCast(&data12.server_responses));
        var n: usize = 0;
        for (expected) |e| {
            const rec = (try fr.next()).?;
            try testing.expectEqual(e.content_type, rec.content_type);
            try testing.expectEqual(e.payload_len, rec.payload.len);
            try testing.expectEqual(.tls_1_2, rec.protocol_version);

            n += rec.payload.len + record.header_len;
            try testing.expectEqual(n, fr.bytesRead());
        }
        try testing.expectEqual(data12.server_responses.len, fr.bytesRead());
        try testing.expect(try fr.next() == null);
    }
}

test Decoder {
    var fbs = io.fixedBufferStream(&data12.server_responses);
    var rdr = reader(fbs.reader());

    var d = (try rdr.nextDecoder());
    try testing.expectEqual(.handshake, d.content_type);

    try testing.expectEqual(.server_hello, try d.decode(proto.Handshake));
    try testing.expectEqual(45, try d.decode(u24)); // length
    try testing.expectEqual(.tls_1_2, try d.decode(proto.Version));
    try testing.expectEqualStrings(
        &testu.hexToBytes("707172737475767778797a7b7c7d7e7f808182838485868788898a8b8c8d8e8f"),
        try d.slice(32),
    ); // server random
    try testing.expectEqual(0, try d.decode(u8)); // session id len
    try testing.expectEqual(.ECDHE_RSA_WITH_AES_128_CBC_SHA, try d.decode(CipherSuite));
    try testing.expectEqual(0, try d.decode(u8)); // compression method
    try testing.expectEqual(5, try d.decode(u16)); // extension length
    try testing.expectEqual(5, d.rest().len);
    try d.skip(5);
    try testing.expect(d.eof());
}

pub const Writer = struct {
    buf: []u8,
    pos: usize = 0,

    pub fn write(self: *Writer, data: []const u8) !void {
        if (self.pos + data.len > self.buf.len) return error.BufferOverflow;
        @memcpy(self.buf[self.pos..][0..data.len], data);
        self.pos += data.len;
    }

    pub fn writeByte(self: *Writer, b: u8) !void {
        if (self.pos == self.buf.len) return error.BufferOverflow;
        self.buf[self.pos] = b;
        self.pos += 1;
    }

    pub fn writeEnum(self: *Writer, value: anytype) !void {
        try self.writeInt(@intFromEnum(value));
    }

    pub fn writeInt(self: *Writer, value: anytype) !void {
        const IntT = @TypeOf(value);
        const bytes = @divExact(@typeInfo(IntT).int.bits, 8);
        const free = self.buf[self.pos..];
        if (free.len < bytes) return error.BufferOverflow;
        mem.writeInt(IntT, free[0..bytes], value, .big);
        self.pos += bytes;
    }

    pub fn writeHandshakeHeader(self: *Writer, handshake_type: proto.Handshake, payload_len: usize) !void {
        try self.write(&record.handshakeHeader(handshake_type, payload_len));
    }

    /// Should be used after writing handshake payload in buffer provided by `getHandshakePayload`.
    pub fn advanceHandshake(self: *Writer, handshake_type: proto.Handshake, payload_len: usize) !void {
        try self.write(&record.handshakeHeader(handshake_type, payload_len));
        self.pos += payload_len;
    }

    /// Record payload is already written by using buffer space from `getPayload`.
    /// Now when we know payload len we can write record header and advance over payload.
    pub fn advanceRecord(self: *Writer, content_type: proto.ContentType, payload_len: usize) !void {
        try self.write(&record.header(content_type, payload_len));
        self.pos += payload_len;
    }

    pub fn writeRecord(self: *Writer, content_type: proto.ContentType, payload: []const u8) !void {
        try self.write(&record.header(content_type, payload.len));
        try self.write(payload);
    }

    /// Preserves space for record header and returns buffer free space.
    pub fn getPayload(self: *Writer) []u8 {
        return self.buf[self.pos + record.header_len ..];
    }

    /// Preserves space for handshake header and returns buffer free space.
    pub fn getHandshakePayload(self: *Writer) []u8 {
        return self.buf[self.pos + 4 ..];
    }

    pub fn getWritten(self: *Writer) []const u8 {
        return self.buf[0..self.pos];
    }

    pub fn getFree(self: *Writer) []u8 {
        return self.buf[self.pos..];
    }

    pub fn writeEnumArray(self: *Writer, comptime E: type, tags: []const E) !void {
        assert(@sizeOf(E) == 2);
        try self.writeInt(@as(u16, @intCast(tags.len * 2)));
        for (tags) |t| {
            try self.writeEnum(t);
        }
    }

    pub fn writeExtension(
        self: *Writer,
        comptime et: proto.Extension,
        tags: anytype,
    ) !void {
        try self.writeEnum(et);
        if (et == .supported_versions) {
            try self.writeInt(@as(u16, @intCast(tags.len * 2 + 1)));
            try self.writeInt(@as(u8, @intCast(tags.len * 2)));
        } else {
            try self.writeInt(@as(u16, @intCast(tags.len * 2 + 2)));
            try self.writeInt(@as(u16, @intCast(tags.len * 2)));
        }
        for (tags) |t| {
            try self.writeEnum(t);
        }
    }

    pub fn writeKeyShare(
        self: *Writer,
        named_groups: []const proto.NamedGroup,
        keys: []const []const u8,
    ) !void {
        assert(named_groups.len == keys.len);
        try self.writeEnum(proto.Extension.key_share);
        var l: usize = 0;
        for (keys) |key| {
            l += key.len + 4;
        }
        try self.writeInt(@as(u16, @intCast(l + 2)));
        try self.writeInt(@as(u16, @intCast(l)));
        for (named_groups, 0..) |ng, i| {
            const key = keys[i];
            try self.writeEnum(ng);
            try self.writeInt(@as(u16, @intCast(key.len)));
            try self.write(key);
        }
    }

    pub fn writeServerName(self: *Writer, host: []const u8) !void {
        const host_len: u16 = @intCast(host.len);
        try self.writeEnum(proto.Extension.server_name);
        try self.writeInt(host_len + 5); // byte length of extension payload
        try self.writeInt(host_len + 3); // server_name_list byte count
        try self.writeByte(0); // name type
        try self.writeInt(host_len);
        try self.write(host);
    }
};

test "Writer" {
    var buf: [16]u8 = undefined;
    var w = Writer{ .buf = &buf };

    try w.write("ab");
    try w.writeEnum(proto.Curve.named_curve);
    try w.writeEnum(proto.NamedGroup.x25519);
    try w.writeInt(@as(u16, 0x1234));
    try testing.expectEqualSlices(u8, &[_]u8{ 'a', 'b', 0x03, 0x00, 0x1d, 0x12, 0x34 }, w.getWritten());
}

test isSlice {
    try comptime testing.expect(isSlice([]const u8));
    try comptime testing.expect(isSlice([]u8));
    try comptime testing.expect(!isSlice(io.FixedBufferStream([]u8)));
}

fn isSlice(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .pointer => |ptr_info| switch (ptr_info.size) {
            .slice => true,
            else => false,
        },
        else => false,
    };
}
