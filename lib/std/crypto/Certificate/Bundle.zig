//! Bundle of trusted root certificates for validating untrusted SSL certificates.

/// Authoritative certificates (CAs).
issuers: std.HashMapUnmanaged(Certificate.Name, Certificate, MapContext, std.hash_map.default_max_load_percentage) = .{},
/// Backing DER encoded array of `issuers`.
bytes: std.ArrayListUnmanaged(u8) = .{},

const log = std.log.scoped(.certificate_bundle);

pub fn deinit(self: *Bundle, gpa: Allocator) void {
    self.issuers.deinit(gpa);
    self.bytes.deinit(gpa);
    self.* = undefined;
}

/// Replaces `issuers` by parsing the host operating system file system standard location.
///
/// Only adds certificates with proper CA fields set.
pub fn rescan(self: *Bundle, gpa: Allocator) !void {
    self.issuers.clearRetainingCapacity();
    self.bytes.clearRetainingCapacity();
    switch (builtin.os.tag) {
        .linux => return rescanLinux(self, gpa),
        .macos => return rescanMac(self, gpa),
        .freebsd, .openbsd => return rescanBSD(self, gpa, "/etc/ssl/cert.pem"),
        .netbsd => return rescanBSD(self, gpa, "/etc/openssl/certs/ca-certificates.crt"),
        .dragonfly => return rescanBSD(self, gpa, "/usr/local/etc/ssl/cert.pem"),
        .solaris, .illumos => return rescanBSD(self, gpa, "/etc/ssl/cacert.pem"),
        .windows => return rescanWindows(self, gpa),
        else => {},
    }

    self.bytes.shrinkAndFree(gpa, self.bytes.items.len);
}

const rescanMac = @import("Bundle/macos.zig").rescanMac;

fn rescanLinux(cb: *Bundle, gpa: Allocator) !void {
    // Possible certificate files; stop after finding one.
    const cert_file_paths = [_][]const u8{
        "/etc/ssl/certs/ca-certificates.crt", // Debian/Ubuntu/Gentoo etc.
        "/etc/pki/tls/certs/ca-bundle.crt", // Fedora/RHEL 6
        "/etc/ssl/ca-bundle.pem", // OpenSUSE
        "/etc/pki/tls/cacert.pem", // OpenELEC
        "/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem", // CentOS/RHEL 7
        "/etc/ssl/cert.pem", // Alpine Linux
    };

    // Possible directories with certificate files; all will be read.
    const cert_dir_paths = [_][]const u8{
        "/etc/ssl/certs", // SLES10/SLES11
        "/etc/pki/tls/certs", // Fedora/RHEL
        "/system/etc/security/cacerts", // Android
    };

    scan: {
        for (cert_file_paths) |cert_file_path| {
            if (addCertsFromFilePathAbsolute(cb, gpa, cert_file_path)) |_| {
                break :scan;
            } else |err| switch (err) {
                error.FileNotFound => continue,
                else => |e| return e,
            }
        }

        for (cert_dir_paths) |cert_dir_path| {
            addCertsFromDirPathAbsolute(cb, gpa, cert_dir_path) catch |err| switch (err) {
                error.FileNotFound => continue,
                else => |e| return e,
            };
        }
    }
}

fn rescanBSD(cb: *Bundle, gpa: Allocator, cert_file_path: []const u8) !void {
    try addCertsFromFilePathAbsolute(cb, gpa, cert_file_path);
}

fn rescanWindows(cb: *Bundle, gpa: Allocator) !void {
    const w = std.os.windows;
    const GetLastError = w.kernel32.GetLastError;
    const root = [4:0]u16{ 'R', 'O', 'O', 'T' };
    const store = w.crypt32.CertOpenSystemStoreW(null, &root) orelse switch (GetLastError()) {
        .FILE_NOT_FOUND => return error.FileNotFound,
        else => |err| return w.unexpectedError(err),
    };
    defer _ = w.crypt32.CertCloseStore(store, 0);

    const now_sec = std.time.timestamp();

    var ctx = w.crypt32.CertEnumCertificatesInStore(store, null);
    while (ctx) |context| : (ctx = w.crypt32.CertEnumCertificatesInStore(store, ctx)) {
        const decoded_start = @as(u32, @intCast(cb.bytes.items.len));
        const encoded_cert = context.pbCertEncoded[0..context.cbCertEncoded];
        try cb.bytes.appendSlice(gpa, encoded_cert);
        try cb.parseCert(gpa, decoded_start, now_sec);
    }
}

pub fn addCertsFromDirPath(
    cb: *Bundle,
    gpa: Allocator,
    dir: fs.Dir,
    sub_dir_path: []const u8,
) !void {
    var iterable_dir = try dir.openDir(sub_dir_path, .{ .iterate = true });
    defer iterable_dir.close();
    return addCertsFromDir(cb, gpa, iterable_dir);
}

pub fn addCertsFromDirPathAbsolute(
    cb: *Bundle,
    gpa: Allocator,
    abs_dir_path: []const u8,
) !void {
    var iterable_dir = try fs.openDirAbsolute(abs_dir_path, .{ .iterate = true });
    defer iterable_dir.close();
    return addCertsFromDir(cb, gpa, iterable_dir);
}

pub fn addCertsFromDir(cb: *Bundle, gpa: Allocator, iterable_dir: fs.Dir) !void {
    var it = iterable_dir.iterate();
    while (try it.next()) |entry| {
        switch (entry.kind) {
            .file, .sym_link => {},
            else => continue,
        }

        try addCertsFromFilePath(cb, gpa, iterable_dir, entry.name);
    }
}

pub fn addCertsFromFilePathAbsolute(self: *Bundle, gpa: Allocator, path: []const u8) !void {
    var file = try fs.openFileAbsolute(path, .{});
    defer file.close();
    return addCertsFromFile(self, gpa, file);
}

pub fn addCertsFromFilePath(cb: *Bundle, gpa: Allocator, dir: fs.Dir, path: []const u8) !void {
    var file = try dir.openFile(path, .{});
    defer file.close();
    return addCertsFromFile(cb, gpa, file);
}

/// Convert PEM to owned DER, add Certificate to map.
pub fn addCertsFromFile(cb: *Bundle, gpa: Allocator, file: fs.File) !void {
    const size = try file.getEndPos();

    // We borrow `bytes` as a temporary buffer for the base64-encoded data.
    // This is possible by computing the decoded length and reserving the space
    // for the decoded bytes first.
    const decoded_size_upper_bound = size / 4 * 3;
    const needed_capacity = std.math.cast(u32, decoded_size_upper_bound + size) orelse
        return error.CertificateAuthorityBundleTooBig;
    try cb.bytes.ensureUnusedCapacity(gpa, needed_capacity);
    const end_reserved: u32 = @intCast(cb.bytes.items.len + decoded_size_upper_bound);
    const buffer = cb.bytes.allocatedSlice()[end_reserved..];
    const end_index = try file.readAll(buffer);
    const pem = buffer[0..end_index];

    return try cb.addCertsFromPem(gpa, pem);
}

pub fn addCertsFromPem(cb: *Bundle, gpa: Allocator, pem: []const u8) !void {
    const begin_marker = "-----BEGIN CERTIFICATE-----";
    const end_marker = "-----END CERTIFICATE-----";

    const decoded_size_upper_bound = pem.len / 4 * 3;
    try cb.bytes.ensureUnusedCapacity(gpa, pem.len + decoded_size_upper_bound);

    var start_index: usize = 0;
    while (mem.indexOfPos(u8, pem, start_index, begin_marker)) |begin_marker_start| {
        const cert_start = begin_marker_start + begin_marker.len;
        const cert_end = mem.indexOfPos(u8, pem, cert_start, end_marker) orelse
            return error.MissingEndCertificateMarker;
        start_index = cert_end + end_marker.len;
        const encoded_cert = mem.trim(u8, pem[cert_start..cert_end], " \t\r\n");
        const decoded_start: u32 = @intCast(cb.bytes.items.len);
        const dest_buf = cb.bytes.allocatedSlice()[decoded_start..];
        cb.bytes.items.len += try base64.decode(dest_buf, encoded_cert);
        try cb.parseCert(gpa, decoded_start);
    }
}

inline fn fmtCert(cert: Certificate) []const u8 {
    var buf: [256]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    cert.print(writer) catch {};

    return stream.getWritten();
}

pub fn parseCert(cb: *Bundle, gpa: Allocator, decoded_start: u32) !void {
    const cert = Certificate.fromDer(cb.bytes.items[decoded_start..]) catch |err| {
        log.warn("parse: {}", .{err});
        return;
    };
    if (!cert.basic_constraints.is_ca) {
        log.debug("skipping {s} that is not a CA", .{fmtCert(cert)});
        return;
    }
    cert.validate(0) catch |err| switch (err) {
        // We don't know what times users may want to validate certificates against.
        error.CertificateExpired, error.CertificateNotYetValid => {},
        else => {
            log.debug("skipping {s}: {}", .{ fmtCert(cert), err });
            return;
        },
    };

    const gop = try cb.issuers.getOrPut(gpa, cert.subject);
    gop.value_ptr.* = cert;
    if (gop.found_existing) log.warn("overwriting {}\n", .{cert});
}

const builtin = @import("builtin");
const std = @import("../../std.zig");
const fs = std.fs;
const mem = std.mem;
const crypto = std.crypto;
const Allocator = std.mem.Allocator;
const Certificate = std.crypto.Certificate;
const Bundle = @This();

const base64 = std.base64.standard.decoderWithIgnore(" \t\r\n");

const MapContext = struct {
    pub fn hash(_: MapContext, k: Certificate.Name) u64 {
        var hasher = std.hash.Wyhash.init(0);
        inline for (std.meta.fields(Certificate.Name)) |field| {
            const v = @field(k, field.name);
            if (field.type == Certificate.DirectoryString) {
                hasher.update(&[_]u8{@intFromEnum(v.tag)});
                hasher.update(v.data);
            } else if (field.type == []const u8) {
                hasher.update(v);
            } else if (field.type == u8) {
                hasher.update(&[_]u8{v});
            } else if (field.type == Certificate.Name.KVs) {
                for (v) |s| hasher.update(s);
            } else {
                @compileError("check field type " ++ @typeName(field.type));
            }
        }
        return hasher.final();
    }

    pub fn eql(_: MapContext, a: Certificate.Name, b: Certificate.Name) bool {
        return a.eql(b);
    }
};

test rescan {
    if (builtin.os.tag == .wasi) return error.SkipZigTest;

    const allocator = std.testing.allocator;

    var bundle: Bundle = .{};
    defer bundle.deinit(allocator);

    try bundle.rescan(allocator);
}
