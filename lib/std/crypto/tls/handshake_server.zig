const std = @import("std");
const assert = std.debug.assert;
const crypto = std.crypto;
const mem = std.mem;
const Certificate = crypto.Certificate;

const cipher = @import("cipher.zig");
const Cipher = cipher.Cipher;
const CipherSuite = @import("cipher.zig").CipherSuite;
const cipher_suites = @import("cipher.zig").cipher_suites;
const Transcript = @import("transcript.zig").Transcript;
const record = @import("record.zig");
const PrivateKey = @import("PrivateKey.zig");
const proto = @import("protocol.zig");

const common = @import("handshake_common.zig");
const dupe = common.dupe;
const CertificateBuilder = common.CertificateBuilder;
const CertificateParser = common.CertificateParser;
const DhKeyPair = common.DhKeyPair;
const CertBundle = common.CertBundle;
const CertKeyPair = common.CertKeyPair;

const log = std.log.scoped(.tls);

pub const Options = struct {
    /// Server authentication. If null server will not send Certificate and
    /// CertificateVerify message.
    auth: ?*CertKeyPair,

    /// If not null server will request client certificate. If auth_type is
    /// .request empty client certificate message will be accepted.
    /// Client certificate will be verified with root_ca certificates.
    client_auth: ?ClientAuth = null,
};

pub const ClientAuth = struct {
    /// Set of root certificate authorities that server use when verifying
    /// client certificates.
    root_ca: CertBundle,

    auth_type: Type = .require,

    pub const Type = enum {
        /// Client certificate will be requested during the handshake, but does
        /// not require that the client send any certificates.
        request,
        /// Client certificate will be requested during the handshake, and client
        /// has to send valid certificate.
        require,
    };
};

pub fn Handshake(comptime Stream: type) type {
    const RecordReaderT = record.Reader(Stream);
    return struct {
        // public key len: x25519 = 32, secp256r1 = 65, secp384r1 = 97
        const max_pub_key_len = 98;
        const supported_named_groups = &[_]proto.NamedGroup{ .x25519, .secp256r1, .secp384r1 };

        server_random: [32]u8 = undefined,
        client_random: [32]u8 = undefined,
        legacy_session_id_buf: [32]u8 = undefined,
        legacy_session_id: []u8 = "",
        cipher_suite: CipherSuite = @enumFromInt(0),
        signature_scheme: proto.SignatureScheme = @enumFromInt(0),
        named_group: proto.NamedGroup = @enumFromInt(0),
        client_pub_key_buf: [max_pub_key_len]u8 = undefined,
        client_pub_key: []u8 = "",
        server_pub_key_buf: [max_pub_key_len]u8 = undefined,
        server_pub_key: []u8 = "",

        cipher: Cipher = undefined,
        transcript: Transcript = .{},
        rec_rdr: *RecordReaderT,
        buffer: []u8,

        const HandshakeT = @This();

        pub fn init(buf: []u8, rec_rdr: *RecordReaderT) HandshakeT {
            return .{
                .rec_rdr = rec_rdr,
                .buffer = buf,
            };
        }

        fn writeAlert(h: *HandshakeT, stream: Stream, cph: ?*Cipher, err: anyerror) !void {
            if (cph) |c| {
                const cleartext = proto.alertFromError(err);
                const ciphertext = try c.encrypt(h.buffer, .alert, &cleartext);
                stream.writeAll(ciphertext) catch {};
            } else {
                const alert = record.header(.alert, 2) ++ proto.alertFromError(err);
                stream.writeAll(&alert) catch {};
            }
        }

        pub fn handshake(h: *HandshakeT, stream: Stream, opt: Options) !Cipher {
            h.initKeys(opt);

            h.readClientHello() catch |err| {
                try h.writeAlert(stream, null, err);
                return err;
            };
            h.transcript.use(h.cipher_suite.hash());

            const server_flight = h.serverFlight(opt) catch |err| {
                try h.writeAlert(stream, null, err);
                return err;
            };
            try stream.writeAll(server_flight);

            h.clientFlight2(opt) catch |err| {
                // Alert received from client
                if (!mem.startsWith(u8, @errorName(err), "TlsAlert")) {
                    try h.writeAlert(stream, &h.cipher, err);
                }
                return err;
            };
            return h.cipher;
        }

        fn initKeys(h: *HandshakeT, opt: Options) void {
            crypto.random.bytes(&h.server_random);
            if (opt.auth) |a| {
                // required signature scheme in client hello
                h.signature_scheme = a.key.signature_scheme;
            }
        }

        fn clientFlight1(h: *HandshakeT) !void {
            try h.readClientHello();
            h.transcript.use(h.cipher_suite.hash());
        }

        fn clientFlight2(h: *HandshakeT, opt: Options) !void {
            const app_cipher = brk: {
                const application_secret = h.transcript.applicationSecret();
                break :brk try Cipher.initTls13(h.cipher_suite, application_secret, .server);
            };
            defer h.cipher = app_cipher;
            try h.readClientFlight2(opt);
        }

        fn serverFlight(h: *HandshakeT, opt: Options) ![]const u8 {
            var w = record.Writer{ .buf = h.buffer };

            const shared_key = try h.sharedKey();
            {
                const hello = try h.makeServerHello(w.getFree());
                h.transcript.update(hello[record.header_len..]);
                w.pos += hello.len;
            }
            {
                const handshake_secret = h.transcript.handshakeSecret(shared_key);
                h.cipher = try Cipher.initTls13(h.cipher_suite, handshake_secret, .server);
            }
            try w.writeRecord(.change_cipher_spec, &[_]u8{1});
            {
                const encrypted_extensions = &record.handshakeHeader(.encrypted_extensions, 2) ++ [_]u8{ 0, 0 };
                h.transcript.update(encrypted_extensions);
                try h.writeEncrypted(&w, encrypted_extensions);
            }
            if (opt.client_auth) |_| {
                const certificate_request = try makeCertificateRequest(w.getPayload());
                h.transcript.update(certificate_request);
                try h.writeEncrypted(&w, certificate_request);
            }
            if (opt.auth) |a| {
                const cm = CertificateBuilder{
                    .bundle = a.bundle,
                    .key = a.key,
                    .transcript = &h.transcript,
                    .side = .server,
                };
                {
                    const certificate = try cm.makeCertificate(w.getPayload());
                    h.transcript.update(certificate);
                    try h.writeEncrypted(&w, certificate);
                }
                {
                    const certificate_verify = try cm.makeCertificateVerify(w.getPayload());
                    h.transcript.update(certificate_verify);
                    try h.writeEncrypted(&w, certificate_verify);
                }
            }
            {
                const finished = try h.makeFinished(w.getPayload());
                h.transcript.update(finished);
                try h.writeEncrypted(&w, finished);
            }
            return w.getWritten();
        }

        inline fn sharedKey(h: *HandshakeT) ![]const u8 {
            var seed: [DhKeyPair.seed_len]u8 = undefined;
            crypto.random.bytes(&seed);
            var kp = try DhKeyPair.init(seed, supported_named_groups);
            h.server_pub_key = dupe(&h.server_pub_key_buf, try kp.publicKey(h.named_group));
            return try kp.sharedKey(h.named_group, h.client_pub_key);
        }

        fn readClientFlight2(h: *HandshakeT, opt: Options) !void {
            var cleartext_buf = h.buffer;
            var cleartext_buf_head: usize = 0;
            var cleartext_buf_tail: usize = 0;
            var handshake_state: proto.Handshake = .finished;
            var cert: CertificateParser = undefined;
            if (opt.client_auth) |client_auth| {
                cert = .{ .root_ca = client_auth.root_ca.bundle, .host = "" };
                handshake_state = .certificate;
            }

            outer: while (true) {
                const rec = (try h.rec_rdr.next() orelse return error.EndOfStream);
                if (rec.protocol_version != .tls_1_2 and rec.content_type != .alert)
                    return error.TlsProtocolVersion;

                switch (rec.content_type) {
                    .change_cipher_spec => {
                        if (rec.payload.len != 1) return error.TlsUnexpectedMessage;
                    },
                    .application_data => {
                        const content_type, const cleartext = try h.cipher.decrypt(
                            cleartext_buf[cleartext_buf_tail..],
                            rec,
                        );
                        cleartext_buf_tail += cleartext.len;
                        if (cleartext_buf_tail > cleartext_buf.len) return error.TlsRecordOverflow;

                        var d = record.Decoder.init(content_type, cleartext_buf[cleartext_buf_head..cleartext_buf_tail]);
                        try d.expectContentType(.handshake);
                        while (!d.eof()) {
                            const start_idx = d.idx;
                            const handshake_type = try d.decode(proto.Handshake);
                            const length = try d.decode(u24);

                            if (length > cipher.max_cleartext_len)
                                return error.TlsRecordOverflow;
                            if (length > d.rest().len)
                                continue :outer; // fragmented handshake into multiple records

                            defer {
                                const handshake_payload = d.payload[start_idx..d.idx];
                                h.transcript.update(handshake_payload);
                                cleartext_buf_head += handshake_payload.len;
                            }

                            if (handshake_state != handshake_type)
                                return error.TlsUnexpectedMessage;

                            switch (handshake_type) {
                                .certificate => {
                                    if (length == 4) {
                                        // got empty certificate message
                                        if (opt.client_auth.?.auth_type == .require)
                                            return error.TlsCertificateRequired;
                                        try d.skip(length);
                                        handshake_state = .finished;
                                    } else {
                                        try cert.parseCertificate(&d, .tls_1_3);
                                        handshake_state = .certificate_verify;
                                    }
                                },
                                .certificate_verify => {
                                    try cert.parseCertificateVerify(&d);
                                    cert.verifySignature(h.transcript.clientCertificateVerify()) catch |err| return switch (err) {
                                        error.TlsUnknownSignatureScheme => error.TlsIllegalParameter,
                                        else => error.TlsDecryptError,
                                    };
                                    handshake_state = .finished;
                                },
                                .finished => {
                                    const actual = try d.slice(length);
                                    var buf: [Transcript.max_mac_length]u8 = undefined;
                                    const expected = h.transcript.clientFinishedTls13(&buf);
                                    if (!mem.eql(u8, expected, actual))
                                        return if (expected.len == actual.len)
                                            error.TlsDecryptError
                                        else
                                            error.TlsDecodeError;
                                    return;
                                },
                                else => return error.TlsUnexpectedMessage,
                            }
                        }
                        cleartext_buf_head = 0;
                        cleartext_buf_tail = 0;
                    },
                    .alert => {
                        var d = rec.decoder();
                        return d.raiseAlert();
                    },
                    else => return error.TlsUnexpectedMessage,
                }
            }
        }

        fn makeFinished(h: *HandshakeT, buf: []u8) ![]const u8 {
            var w = record.Writer{ .buf = buf };
            const verify_data = h.transcript.serverFinishedTls13(w.getHandshakePayload());
            try w.advanceHandshake(.finished, verify_data.len);
            return w.getWritten();
        }

        /// Write encrypted handshake message into `w`
        fn writeEncrypted(h: *HandshakeT, w: *record.Writer, cleartext: []const u8) !void {
            const ciphertext = try h.cipher.encrypt(w.getFree(), .handshake, cleartext);
            w.pos += ciphertext.len;
        }

        fn makeServerHello(h: *HandshakeT, buf: []u8) ![]const u8 {
            const header_len = 9; // tls record header (5 bytes) and handshake header (4 bytes)
            var w = record.Writer{ .buf = buf[header_len..] };

            try w.writeEnum(proto.Version.tls_1_2);
            try w.write(&h.server_random);
            {
                try w.writeInt(@as(u8, @intCast(h.legacy_session_id.len)));
                if (h.legacy_session_id.len > 0) try w.write(h.legacy_session_id);
            }
            try w.writeEnum(h.cipher_suite);
            try w.write(&[_]u8{0}); // compression method

            var e = record.Writer{ .buf = buf[header_len + w.pos + 2 ..] };
            { // supported versions extension
                try e.writeEnum(proto.Extension.supported_versions);
                try e.writeInt(@as(u16, 2));
                try e.writeEnum(proto.Version.tls_1_3);
            }
            { // key share extension
                const key_len: u16 = @intCast(h.server_pub_key.len);
                try e.writeEnum(proto.Extension.key_share);
                try e.writeInt(key_len + 4);
                try e.writeEnum(h.named_group);
                try e.writeInt(key_len);
                try e.write(h.server_pub_key);
            }
            try w.writeInt(@as(u16, @intCast(e.pos))); // extensions length

            const payload_len = w.pos + e.pos;
            buf[0..header_len].* = record.header(.handshake, 4 + payload_len) ++
                record.handshakeHeader(.server_hello, payload_len);

            return buf[0 .. header_len + payload_len];
        }

        fn makeCertificateRequest(buf: []u8) ![]const u8 {
            // handshake header + context length + extensions length
            const header_len = 4 + 1 + 2;

            // First write extensions, leave space for header.
            var ext = record.Writer{ .buf = buf[header_len..] };
            try ext.writeExtension(.signature_algorithms, common.supported_signature_algorithms);

            var w = record.Writer{ .buf = buf };
            try w.writeHandshakeHeader(.certificate_request, ext.pos + 3);
            try w.writeInt(@as(u8, 0)); // certificate request context length = 0
            try w.writeInt(@as(u16, @intCast(ext.pos))); // extensions length
            assert(w.pos == header_len);
            w.pos += ext.pos;

            return w.getWritten();
        }

        fn readClientHello(h: *HandshakeT) !void {
            var d = try h.rec_rdr.nextDecoder();
            try d.expectContentType(.handshake);
            h.transcript.update(d.payload);

            const handshake_type = try d.decode(proto.Handshake);
            if (handshake_type != .client_hello) return error.TlsUnexpectedMessage;
            _ = try d.decode(u24); // handshake length
            if (try d.decode(proto.Version) != .tls_1_2) return error.TlsProtocolVersion;

            h.client_random = try d.array(32);
            { // legacy session id
                const len = try d.decode(u8);
                h.legacy_session_id = dupe(&h.legacy_session_id_buf, try d.slice(len));
            }
            { // cipher suites
                const end_idx = try d.decode(u16) + d.idx;

                while (d.idx < end_idx) {
                    const cipher_suite = try d.decode(CipherSuite);
                    if (cipher_suites.includes(cipher_suites.tls13, cipher_suite) and
                        @intFromEnum(h.cipher_suite) == 0)
                    {
                        h.cipher_suite = cipher_suite;
                    }
                }
                if (@intFromEnum(h.cipher_suite) == 0)
                    return error.TlsHandshakeFailure;
            }
            try d.skip(2); // compression methods

            var key_share_received = false;
            // extensions
            const extensions_end_idx = try d.decode(u16) + d.idx;
            while (d.idx < extensions_end_idx) {
                const extension_type = try d.decode(proto.Extension);
                const extension_len = try d.decode(u16);

                switch (extension_type) {
                    .supported_versions => {
                        var tls_1_3_supported = false;
                        const end_idx = try d.decode(u8) + d.idx;
                        while (d.idx < end_idx) {
                            if (try d.decode(proto.Version) == proto.Version.tls_1_3) {
                                tls_1_3_supported = true;
                            }
                        }
                        if (!tls_1_3_supported) return error.TlsProtocolVersion;
                    },
                    .key_share => {
                        if (extension_len == 0) return error.TlsDecodeError;
                        key_share_received = true;
                        var selected_named_group_idx = supported_named_groups.len;
                        const end_idx = try d.decode(u16) + d.idx;
                        while (d.idx < end_idx) {
                            const named_group = try d.decode(proto.NamedGroup);
                            switch (@intFromEnum(named_group)) {
                                0x0001...0x0016,
                                0x001a...0x001c,
                                0xff01...0xff02,
                                => return error.TlsIllegalParameter,
                                else => {},
                            }
                            const client_pub_key = try d.slice(try d.decode(u16));
                            for (supported_named_groups, 0..) |supported, idx| {
                                if (named_group == supported and idx < selected_named_group_idx) {
                                    h.named_group = named_group;
                                    h.client_pub_key = dupe(&h.client_pub_key_buf, client_pub_key);
                                    selected_named_group_idx = idx;
                                }
                            }
                        }
                        if (@intFromEnum(h.named_group) == 0)
                            return error.TlsIllegalParameter;
                    },
                    .supported_groups => {
                        const end_idx = try d.decode(u16) + d.idx;
                        while (d.idx < end_idx) {
                            const named_group = try d.decode(proto.NamedGroup);
                            switch (@intFromEnum(named_group)) {
                                0x0001...0x0016,
                                0x001a...0x001c,
                                0xff01...0xff02,
                                => return error.TlsIllegalParameter,
                                else => {},
                            }
                        }
                    },
                    .signature_algorithms => {
                        if (@intFromEnum(h.signature_scheme) == 0) {
                            try d.skip(extension_len);
                        } else {
                            var found = false;
                            const list_len = try d.decode(u16);
                            if (list_len == 0) return error.TlsDecodeError;
                            const end_idx = list_len + d.idx;
                            while (d.idx < end_idx) {
                                const signature_scheme = try d.decode(proto.SignatureScheme);
                                if (signature_scheme == h.signature_scheme) found = true;
                            }
                            if (!found) return error.TlsHandshakeFailure;
                        }
                    },
                    else => {
                        try d.skip(extension_len);
                    },
                }
            }
            if (!key_share_received) return error.TlsMissingExtension;
            if (@intFromEnum(h.named_group) == 0) return error.TlsIllegalParameter;
        }
    };
}

const testing = std.testing;
const data13 = @import("testdata/tls13.zig");
const testu = @import("testu.zig");

fn testReader(data: []const u8) record.Reader(std.io.FixedBufferStream([]const u8)) {
    return record.reader(std.io.fixedBufferStream(data));
}
const TestHandshake = Handshake(std.io.FixedBufferStream([]const u8));

test "read client hello" {
    var buffer: [1024]u8 = undefined;
    var rec_rdr = testReader(&data13.client_hello);
    var h = TestHandshake.init(&buffer, &rec_rdr);
    h.signature_scheme = .ecdsa_secp521r1_sha512; // this must be supported in signature_algorithms extension
    try h.readClientHello();

    try testing.expectEqual(CipherSuite.AES_256_GCM_SHA384, h.cipher_suite);
    try testing.expectEqual(.x25519, h.named_group);
    try testing.expectEqualSlices(u8, &data13.client_random, &h.client_random);
    try testing.expectEqualSlices(u8, &data13.client_public_key, h.client_pub_key);
}

test "make server hello" {
    var buffer: [128]u8 = undefined;
    var h = TestHandshake.init(&buffer, undefined);
    h.cipher_suite = .AES_256_GCM_SHA384;
    testu.fillFrom(&h.server_random, 0);
    testu.fillFrom(&h.server_pub_key_buf, 0x20);
    h.named_group = .x25519;
    h.server_pub_key = h.server_pub_key_buf[0..32];

    const actual = try h.makeServerHello(&buffer);
    const expected = &testu.hexToBytes(
        \\ 16 03 03 00 5a 02 00 00 56
        \\ 03 03
        \\ 00 01 02 03 04 05 06 07 08 09 0a 0b 0c 0d 0e 0f 10 11 12 13 14 15 16 17 18 19 1a 1b 1c 1d 1e 1f
        \\ 00
        \\ 13 02 00
        \\ 00 2e 00 2b 00 02 03 04
        \\ 00 33 00 24 00 1d 00 20
        \\ 20 21 22 23 24 25 26 27 28 29 2a 2b 2c 2d 2e 2f 30 31 32 33 34 35 36 37 38 39 3a 3b 3c 3d 3e 3f
    );
    try testing.expectEqualSlices(u8, expected, actual);
}

test "make certificate request" {
    var buffer: [32]u8 = undefined;

    const expected = testu.hexToBytes("0d 00 00 1b" ++ // handshake header
        "00 00 18" ++ // extension length
        "00 0d" ++ // signature algorithms extension
        "00 14" ++ // extension length
        "00 12" ++ // list length 6 * 2 bytes
        "04 03 05 03 08 04 08 05 08 06 08 07 02 01 04 01 05 01" // signature schemes
    );
    const actual = try TestHandshake.makeCertificateRequest(&buffer);
    try testing.expectEqualSlices(u8, &expected, actual);
}
