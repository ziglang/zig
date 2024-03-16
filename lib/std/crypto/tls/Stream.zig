//! Abstraction over TLS record layer (RFC 8446 S5).
//!
//! After writing must call `flush` before reading or contents will not be written.
//!
//! Handles:
//!   * Fragmentation
//!   * Encryption and decryption of handshake and application data messages
//!   * Reading and writing prefix length arrays
//!   * Reading and writing TLS types
//!   * Alerts
const std = @import("../../std.zig");
const tls = std.crypto.tls;

stream: std.io.AnyStream,
/// Used for both reading and writing.
/// Stores plaintext or briefly ciphertext, but not Plaintext headers.
buffer: [fragment_size]u8 = undefined,
/// Unread or unwritten view of `buffer`. May contain multiple handshakes.
view: []const u8 = "",

/// When sending this is the record type that will be flushed.
/// When receiving this is the next fragment's expected record type.
content_type: ContentType = .handshake,
/// When sending this is the flushed version.
version: Version = .tls_1_0,
/// When receiving a handshake message will be expected with this type.
handshake_type: ?HandshakeType = .client_hello,

/// Used to decrypt .application_data messages.
/// Used to encrypt messages that aren't alert or change_cipher_spec.
cipher: Cipher = .none,

/// True when we send or receive a close_notify alert.
closed: bool = false,

/// True if we're being used as a client. This changes:
///     * Certain shared struct formats (like Extension)
///     * Which ciphers are used for encoding/decoding handshake and application messages.
is_client: bool,

/// When > 0 won't actually do anything with writes. Used to discover prefix lengths.
nocommit: usize = 0,

/// Client and server implementations can set this. While set sent or received handshake messages
/// will update the hash.
transcript_hash: ?*MultiHash,

const Self = @This();
const ContentType = tls.ContentType;
const Version = tls.Version;
const HandshakeType = tls.HandshakeType;
const MultiHash = tls.MultiHash;
const Plaintext = tls.Plaintext;
const HandshakeCipher = tls.HandshakeCipher;
const ApplicationCipher = tls.ApplicationCipher;
const Alert = tls.Alert;
const Extension = tls.Extension;

const fragment_size = Plaintext.max_length;

const Cipher = union(enum) {
    none: void,
    application: ApplicationCipher,
    handshake: HandshakeCipher,
};

pub const ReadError = anyerror || tls.Error || error{EndOfStream};
pub const WriteError = anyerror || error{TlsEncodeError};

fn ciphertextOverhead(self: Self) usize {
    return switch (self.cipher) {
        inline .application, .handshake => |c| switch (c) {
            inline else => |t| @TypeOf(t).AEAD.tag_length + @sizeOf(ContentType),
        },
        else => 0,
    };
}

fn maxFragmentSize(self: Self) usize {
    return self.buffer.len - self.ciphertextOverhead();
}

const EncryptionMethod = enum { none, handshake, application };
fn encryptionMethod(self: Self, content_type: ContentType) EncryptionMethod {
    switch (content_type) {
        .alert, .change_cipher_spec => {},
        else => {
            if (self.cipher == .application) return .application;
            if (self.cipher == .handshake) return .handshake;
        },
    }
    return .none;
}

pub fn flush(self: *Self) WriteError!void {
    if (self.view.len == 0) return;
    if (self.transcript_hash) |t| {
        if (self.content_type == .handshake) t.update(self.view);
    }

    var plaintext = Plaintext{
        .type = self.content_type,
        .version = self.version,
        .len = @intCast(self.view.len),
    };

    var header: [Plaintext.size]u8 = Encoder.encode(Plaintext, plaintext);
    var aead: []const u8 = "";
    switch (self.cipher) {
        .none => {},
        inline .application, .handshake => |*cipher| {
            plaintext.type = .application_data;
            plaintext.len += @intCast(self.ciphertextOverhead());
            header = Encoder.encode(Plaintext, plaintext);
            switch (cipher.*) {
                inline else => |*c| {
                    std.debug.assert(self.view.ptr == &self.buffer);
                    self.buffer[self.view.len] = @intFromEnum(self.content_type);
                    self.view = self.buffer[0 .. self.view.len + 1];
                    aead = &c.encrypt(self.view, &header, self.is_client, @constCast(self.view));
                },
            }
        },
    }

    // TODO: contiguous buffer management
    try self.stream.writer().writeAll(&header);
    try self.stream.writer().writeAll(self.view);
    try self.stream.writer().writeAll(aead);
    self.view = self.buffer[0..0];
}

/// Flush a change cipher spec message to the underlying stream.
pub fn changeCipherSpec(self: *Self) WriteError!void {
    self.version = .tls_1_2;

    const plaintext = Plaintext{
        .type = .change_cipher_spec,
        .version = self.version,
        .len = 1,
    };
    const msg = [_]u8{1};
    const header: [Plaintext.size]u8 = Encoder.encode(Plaintext, plaintext);
    // TODO: contiguous buffer management
    try self.stream.writer().writeAll(&header);
    try self.stream.writer().writeAll(&msg);
}

/// Write an alert to stream and call `close_notify` after. Returns Zig error.
pub fn writeError(self: *Self, err: Alert.Description) tls.Error {
    const alert = Alert{ .level = .fatal, .description = err };

    self.view = self.buffer[0..0];
    self.content_type = .alert;
    _ = self.write(Alert, alert) catch {};
    self.flush() catch {};

    self.close();
    @panic("TODO: fixme");
    // return err.toError();
}

pub fn close(self: *Self) void {
    const alert = Alert{ .level = .fatal, .description = .close_notify };
    _ = self.write(Alert, alert) catch {};
    self.content_type = .alert;
    self.flush() catch {};
    self.closed = true;
}

/// Write bytes to `stream`, potentially flushing once `self.buffer` is full.
pub fn writeBytes(self: *Self, bytes: []const u8) WriteError!usize {
    if (self.nocommit > 0) return bytes.len;

    const available = self.buffer.len - self.view.len;
    const to_consume = bytes[0..@min(available, bytes.len)];

    @memcpy(self.buffer[self.view.len..][0..bytes.len], to_consume);
    self.view = self.buffer[0 .. self.view.len + to_consume.len];

    if (self.view.len == self.buffer.len) try self.flush();

    return to_consume.len;
}

pub fn writeAll(self: *Self, bytes: []const u8) WriteError!usize {
    var index: usize = 0;
    while (index != bytes.len) {
        index += try self.writeBytes(bytes[index..]);
    }
    return index;
}

pub fn writeArray(self: *Self, comptime PrefixT: type, comptime T: type, values: []const T) WriteError!usize {
    var res: usize = 0;
    for (values) |v| res += self.length(T, v);

    if (PrefixT != void) {
        if (res > std.math.maxInt(PrefixT)) {
            self.close();
            return error.TlsEncodeError; // Prefix length overflow
        }
        res += try self.write(PrefixT, @intCast(res));
    }

    for (values) |v| _ = try self.write(T, v);

    return res;
}

pub fn write(self: *Self, comptime T: type, value: T) WriteError!usize {
    switch (@typeInfo(T)) {
        .Int, .Enum => {
            const encoded = Encoder.encode(T, value);
            return try self.writeAll(&encoded);
        },
        .Struct, .Union => {
            return try T.write(value, self);
        },
        .Void => return 0,
        else => @compileError("cannot write " ++ @typeName(T)),
    }
}

pub fn length(self: *Self, comptime T: type, value: T) usize {
    if (T == void) return 0;
    self.nocommit += 1;
    defer self.nocommit -= 1;
    return self.write(T, value) catch unreachable;
}

pub fn arrayLength(
    self: *Self,
    comptime PrefixT: type,
    comptime T: type,
    values: []const T,
) usize {
    var res: usize = if (PrefixT == void) 0 else @divExact(@typeInfo(PrefixT).Int.bits, 8);
    for (values) |v| res += self.length(T, v);
    return res;
}

/// Reads bytes from `view`, potentially reading more fragments from `stream`.
///
/// A return value of 0 indicates EOF.
pub fn readv(self: *Self, buffers: []const std.os.iovec) ReadError!usize {
    // > Any data received after a closure alert has been received MUST be ignored.
    if (self.eof()) return 0;

    if (self.view.len == 0) try self.expectInnerPlaintext(self.content_type, self.handshake_type);

    var bytes_read: usize = 0;

    for (buffers) |b| {
        var bytes_read_buffer: usize = 0;
        while (bytes_read_buffer != b.iov_len) {
            const to_read = @min(b.iov_len, self.view.len);
            if (to_read == 0) return bytes_read;

            @memcpy(b.iov_base[0..to_read], self.view[0..to_read]);

            self.view = self.view[to_read..];
            bytes_read_buffer += to_read;
            bytes_read += bytes_read_buffer;
        }
    }

    return bytes_read;
}

/// Reads bytes from `view`, potentially reading more fragments from `stream`.
/// A return value of 0 indicates EOF.
pub fn readBytes(self: *Self, buf: []u8) ReadError!usize {
    const buffers = [_]std.os.iovec{.{ .iov_base = buf.ptr, .iov_len = buf.len }};
    return try self.readv(&buffers);
}

/// Reads plaintext from `stream` into `buffer` and updates `view`.
/// Skips non-fatal alert and change_cipher_spec messages.
/// Will decrypt according to `encryptionMethod` if receiving application_data message.
pub fn readPlaintext(self: *Self) ReadError!Plaintext {
    std.debug.assert(self.view.len == 0); // last read should have completed
    var plaintext_bytes: [Plaintext.size]u8 = undefined;
    var n_read: usize = 0;

    while (true) {
        n_read = try self.stream.reader().readAll(&plaintext_bytes);
        if (n_read != plaintext_bytes.len) return self.writeError(.decode_error);

        var res = Plaintext.init(plaintext_bytes);
        if (res.len > Plaintext.max_length) return self.writeError(.record_overflow);

        self.view = self.buffer[0..res.len];
        n_read = try self.stream.reader().readAll(@constCast(self.view));
        if (n_read != res.len) return self.writeError(.decode_error);

        const encryption_method = self.encryptionMethod(res.type);
        if (encryption_method != .none) {
            if (res.len < self.ciphertextOverhead()) return self.writeError(.decode_error);

            switch (self.cipher) {
                inline .handshake, .application => |*cipher| {
                    switch (cipher.*) {
                        inline else => |*c| {
                            const C = @TypeOf(c.*);
                            const tag_len = C.AEAD.tag_length;

                            const ciphertext = self.view[0 .. self.view.len - tag_len];
                            const tag = self.view[self.view.len - tag_len ..][0..tag_len].*;
                            const out: []u8 = @constCast(self.view[0..ciphertext.len]);
                            c.decrypt(ciphertext, &plaintext_bytes, tag, self.is_client, out) catch
                                return self.writeError(.bad_record_mac);
                            const padding_start = std.mem.lastIndexOfNone(u8, out, &[_]u8{0});
                            if (padding_start) |s| {
                                res.type = @enumFromInt(self.view[s]);
                                self.view = self.view[0..s];
                            } else {
                                return self.writeError(.decode_error);
                            }
                        },
                    }
                },
                else => unreachable,
            }
        }

        switch (res.type) {
            .alert => {
                const level = try self.read(Alert.Level);
                const description = try self.read(Alert.Description);
                std.log.debug("TLS alert {} {}", .{ level, description });

                if (description == .close_notify) {
                    self.closed = true;
                    return res;
                }
                if (level == .fatal) return self.writeError(.unexpected_message);
            },
            // > An implementation may receive an unencrypted record of type
            // > change_cipher_spec consisting of the single byte value 0x01 at any
            // > time after the first ClientHello message has been sent or received
            // > and before the peer's Finished message has been received and MUST
            // > simply drop it without further processing.
            .change_cipher_spec => {
                if (!std.mem.eql(u8, self.view, &[_]u8{1})) {
                    return self.writeError(.unexpected_message);
                }
            },
            else => {
                return res;
            },
        }
    }
}

pub fn readInnerPlaintext(self: *Self) ReadError!InnerPlaintext {
    var res: InnerPlaintext = .{
        .type = self.content_type,
        .handshake_type = if (self.handshake_type) |h| h else undefined,
        .len = undefined,
    };
    if (self.view.len == 0) {
        const plaintext = try self.readPlaintext();
        res.type = plaintext.type;
        res.len = plaintext.len;

        self.content_type = res.type;
    }

    if (res.type == .handshake) {
        if (self.transcript_hash) |t| t.update(self.view[0..4]);
        res.handshake_type = try self.read(HandshakeType);
        res.len = try self.read(u24);
        if (self.transcript_hash) |t| t.update(self.view[0..res.len]);

        self.handshake_type = res.handshake_type;
    }

    return res;
}

pub fn expectInnerPlaintext(
    self: *Self,
    expected_content: ContentType,
    expected_handshake: ?HandshakeType,
) ReadError!void {
    const inner_plaintext = try self.readInnerPlaintext();
    if (expected_content != inner_plaintext.type) {
        std.debug.print("expected {} got {}\n", .{ expected_content, inner_plaintext });
        return self.writeError(.unexpected_message);
    }
    if (expected_handshake) |expected| {
        if (expected != inner_plaintext.handshake_type) return self.writeError(.decode_error);
    }
}

pub fn read(self: *Self, comptime T: type) ReadError!T {
    comptime std.debug.assert(@sizeOf(T) < fragment_size);
    switch (@typeInfo(T)) {
        .Int => return self.reader().readInt(T, .big) catch |err| switch (err) {
            error.EndOfStream => return self.writeError(.decode_error),
            else => |e| return e,
        },
        .Enum => |info| {
            if (info.is_exhaustive) @compileError("exhaustive enum cannot be used");
            const int = try self.read(info.tag_type);
            return @enumFromInt(int);
        },
        else => {
            return T.read(self) catch |err| switch (err) {
                error.TlsUnexpectedMessage => return self.writeError(.unexpected_message),
                error.TlsBadRecordMac => return self.writeError(.bad_record_mac),
                error.TlsRecordOverflow => return self.writeError(.record_overflow),
                error.TlsHandshakeFailure => return self.writeError(.handshake_failure),
                error.TlsBadCertificate => return self.writeError(.bad_certificate),
                error.TlsUnsupportedCertificate => return self.writeError(.unsupported_certificate),
                error.TlsCertificateRevoked => return self.writeError(.certificate_revoked),
                error.TlsCertificateExpired => return self.writeError(.certificate_expired),
                error.TlsCertificateUnknown => return self.writeError(.certificate_unknown),
                error.TlsIllegalParameter => return self.writeError(.illegal_parameter),
                error.TlsUnknownCa => return self.writeError(.unknown_ca),
                error.TlsAccessDenied => return self.writeError(.access_denied),
                error.TlsDecodeError => return self.writeError(.decode_error),
                error.TlsDecryptError => return self.writeError(.decrypt_error),
                error.TlsProtocolVersion => return self.writeError(.protocol_version),
                error.TlsInsufficientSecurity => return self.writeError(.insufficient_security),
                error.TlsInternalError => return self.writeError(.internal_error),
                error.TlsInappropriateFallback => return self.writeError(.inappropriate_fallback),
                error.TlsMissingExtension => return self.writeError(.missing_extension),
                error.TlsUnsupportedExtension => return self.writeError(.unsupported_extension),
                error.TlsUnrecognizedName => return self.writeError(.unrecognized_name),
                error.TlsBadCertificateStatusResponse => return self.writeError(.bad_certificate_status_response),
                error.TlsUnknownPskIdentity => return self.writeError(.unknown_psk_identity),
                error.TlsCertificateRequired => return self.writeError(.certificate_required),
                error.TlsNoApplicationProtocol => return self.writeError(.no_application_protocol),
                error.TlsUnknown => |e| {
                    self.close();
                    return e;
                },
                else => return self.writeError(.decode_error),
            };
        },
    }
}

fn Iterator(comptime T: type) type {
    return struct {
        stream: *Self,
        end: usize,

        pub fn next(self: *@This()) ReadError!?T {
            const cur_offset = self.stream.buffer.len - self.stream.view.len;
            if (cur_offset > self.end) return null;
            return try self.stream.read(T);
        }
    };
}

pub fn iterator(self: *Self, comptime Len: type, comptime Tag: type) ReadError!Iterator(Tag) {
    const offset = self.buffer.len - self.view.len;
    const len = try self.read(Len);
    return Iterator(Tag){
        .stream = self,
        .end = offset + len,
    };
}

pub fn extensions(self: *Self) ReadError!Iterator(Extension.Header) {
    return self.iterator(u16, Extension.Header);
}

pub fn eof(self: Self) bool {
    return self.closed and self.view.len == 0;
}

pub const Reader = std.io.Reader(*Self, ReadError, readBytes);
pub const Writer = std.io.Writer(*Self, WriteError, writeBytes);

pub fn reader(self: *Self) Reader {
    return .{ .context = self };
}

pub fn writer(self: *Self) Writer {
    return .{ .context = self };
}

const Encoder = struct {
    fn RetType(comptime T: type) type {
        switch (@typeInfo(T)) {
            .Int => |info| switch (info.bits) {
                8 => return [1]u8,
                16 => return [2]u8,
                24 => return [3]u8,
                else => @compileError("unsupported int type: " ++ @typeName(T)),
            },
            .Enum => |info| {
                if (info.is_exhaustive) @compileError("exhaustive enum cannot be used");
                return RetType(info.tag_type);
            },
            .Struct => |info| {
                var len: usize = 0;
                inline for (info.fields) |f| len += @typeInfo(RetType(f.type)).Array.len;
                return [len]u8;
            },
            else => @compileError("don't know how to encode " ++ @tagName(T)),
        }
    }
    fn encode(comptime T: type, value: T) RetType(T) {
        return switch (@typeInfo(T)) {
            .Int => |info| switch (info.bits) {
                8 => .{value},
                16 => .{
                    @as(u8, @truncate(value >> 8)),
                    @as(u8, @truncate(value)),
                },
                24 => .{
                    @as(u8, @truncate(value >> 16)),
                    @as(u8, @truncate(value >> 8)),
                    @as(u8, @truncate(value)),
                },
                else => @compileError("unsupported int type: " ++ @typeName(T)),
            },
            .Enum => |info| encode(info.tag_type, @intFromEnum(value)),
            .Struct => |info| brk: {
                const Ret = RetType(T);

                var offset: usize = 0;
                var res: Ret = undefined;
                inline for (info.fields) |f| {
                    const encoded = encode(f.type, @field(value, f.name));
                    @memcpy(res[offset..][0..encoded.len], &encoded);
                    offset += encoded.len;
                }

                break :brk res;
            },
            else => @compileError("cannot encode type " ++ @typeName(T)),
        };
    }
};

const InnerPlaintext = struct {
    type: ContentType,
    handshake_type: HandshakeType,
    len: u24,
};

