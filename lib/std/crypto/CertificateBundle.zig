//! A set of certificates. Typically pre-installed on every operating system,
//! these are "Certificate Authorities" used to validate SSL certificates.
//! This data structure stores certificates in DER-encoded form, all of them
//! concatenated together in the `bytes` array. The `map` field contains an
//! index from the DER-encoded subject name to the index within `bytes`.

map: std.HashMapUnmanaged(Key, u32, MapContext, std.hash_map.default_max_load_percentage) = .{},
bytes: std.ArrayListUnmanaged(u8) = .{},

pub const Key = struct {
    subject_start: u32,
    subject_end: u32,
};

/// The returned bytes become invalid after calling any of the rescan functions
/// or add functions.
pub fn find(cb: CertificateBundle, subject_name: []const u8) ?[]const u8 {
    const Adapter = struct {
        cb: CertificateBundle,

        pub fn hash(ctx: @This(), k: []const u8) u64 {
            _ = ctx;
            return std.hash_map.hashString(k);
        }

        pub fn eql(ctx: @This(), a: []const u8, b_key: Key) bool {
            const b = ctx.cb.bytes.items[b_key.subject_start..b_key.subject_end];
            return mem.eql(u8, a, b);
        }
    };
    const index = cb.map.getAdapted(subject_name, Adapter{ .cb = cb }) orelse return null;
    return cb.bytes.items[index..];
}

pub fn deinit(cb: *CertificateBundle, gpa: Allocator) void {
    cb.map.deinit(gpa);
    cb.bytes.deinit(gpa);
    cb.* = undefined;
}

/// Empties the set of certificates and then scans the host operating system
/// file system standard locations for certificates.
pub fn rescan(cb: *CertificateBundle, gpa: Allocator) !void {
    switch (builtin.os.tag) {
        .linux => return rescanLinux(cb, gpa),
        else => @compileError("it is unknown where the root CA certificates live on this OS"),
    }
}

pub fn rescanLinux(cb: *CertificateBundle, gpa: Allocator) !void {
    var dir = fs.openIterableDirAbsolute("/etc/ssl/certs", .{}) catch |err| switch (err) {
        error.FileNotFound => return,
        else => |e| return e,
    };
    defer dir.close();

    cb.bytes.clearRetainingCapacity();
    cb.map.clearRetainingCapacity();

    var it = dir.iterate();
    while (try it.next()) |entry| {
        switch (entry.kind) {
            .File, .SymLink => {},
            else => continue,
        }

        try addCertsFromFile(cb, gpa, dir.dir, entry.name);
    }

    cb.bytes.shrinkAndFree(gpa, cb.bytes.items.len);
}

pub fn addCertsFromFile(
    cb: *CertificateBundle,
    gpa: Allocator,
    dir: fs.Dir,
    sub_file_path: []const u8,
) !void {
    var file = try dir.openFile(sub_file_path, .{});
    defer file.close();

    const size = try file.getEndPos();

    // We borrow `bytes` as a temporary buffer for the base64-encoded data.
    // This is possible by computing the decoded length and reserving the space
    // for the decoded bytes first.
    const decoded_size_upper_bound = size / 4 * 3;
    try cb.bytes.ensureUnusedCapacity(gpa, decoded_size_upper_bound + size);
    const end_reserved = cb.bytes.items.len + decoded_size_upper_bound;
    const buffer = cb.bytes.allocatedSlice()[end_reserved..];
    const end_index = try file.readAll(buffer);
    const encoded_bytes = buffer[0..end_index];

    const begin_marker = "-----BEGIN CERTIFICATE-----";
    const end_marker = "-----END CERTIFICATE-----";

    var start_index: usize = 0;
    while (mem.indexOfPos(u8, encoded_bytes, start_index, begin_marker)) |begin_marker_start| {
        const cert_start = begin_marker_start + begin_marker.len;
        const cert_end = mem.indexOfPos(u8, encoded_bytes, cert_start, end_marker) orelse
            return error.MissingEndCertificateMarker;
        start_index = cert_end + end_marker.len;
        const encoded_cert = mem.trim(u8, encoded_bytes[cert_start..cert_end], " \t\r\n");
        const decoded_start = @intCast(u32, cb.bytes.items.len);
        const dest_buf = cb.bytes.allocatedSlice()[decoded_start..];
        cb.bytes.items.len += try base64.decode(dest_buf, encoded_cert);
        const k = try key(cb, decoded_start);
        try cb.map.putContext(gpa, k, decoded_start, .{ .cb = cb });
    }
}

pub fn key(cb: *CertificateBundle, bytes_index: u32) !Key {
    const bytes = cb.bytes.items;
    const certificate = try Der.parseElement(bytes, bytes_index);
    const tbs_certificate = try Der.parseElement(bytes, certificate.start);
    const version = try Der.parseElement(bytes, tbs_certificate.start);
    if (@bitCast(u8, version.identifier) != 0xa0 or
        !mem.eql(u8, bytes[version.start..version.end], "\x02\x01\x02"))
    {
        return error.UnsupportedCertificateVersion;
    }

    const serial_number = try Der.parseElement(bytes, version.end);

    // RFC 5280, section 4.1.2.3:
    // "This field MUST contain the same algorithm identifier as
    // the signatureAlgorithm field in the sequence Certificate."
    const signature = try Der.parseElement(bytes, serial_number.end);
    const issuer = try Der.parseElement(bytes, signature.end);
    const validity = try Der.parseElement(bytes, issuer.end);
    const subject = try Der.parseElement(bytes, validity.end);
    //const subject_pub_key = try Der.parseElement(bytes, subject.end);
    //const extensions = try Der.parseElement(bytes, subject_pub_key.end);

    return .{
        .subject_start = subject.start,
        .subject_end = subject.end,
    };
}

const builtin = @import("builtin");
const std = @import("../std.zig");
const fs = std.fs;
const mem = std.mem;
const Allocator = std.mem.Allocator;
const Der = std.crypto.Der;
const CertificateBundle = @This();

const base64 = std.base64.standard.decoderWithIgnore(" \t\r\n");

const MapContext = struct {
    cb: *const CertificateBundle,

    pub fn hash(ctx: MapContext, k: Key) u64 {
        return std.hash_map.hashString(ctx.cb.bytes.items[k.subject_start..k.subject_end]);
    }

    pub fn eql(ctx: MapContext, a: Key, b: Key) bool {
        const bytes = ctx.cb.bytes.items;
        return mem.eql(
            u8,
            bytes[a.subject_start..a.subject_end],
            bytes[b.subject_start..b.subject_end],
        );
    }
};

test {
    var bundle: CertificateBundle = .{};
    defer bundle.deinit(std.testing.allocator);

    try bundle.rescan(std.testing.allocator);
}
