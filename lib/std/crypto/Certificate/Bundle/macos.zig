const std = @import("std");
const assert = std.debug.assert;
const mem = std.mem;
const fs = std.fs;
const Allocator = std.mem.Allocator;
const Bundle = @import("../Bundle.zig");

pub fn rescanMac(cb: *Bundle, gpa: Allocator) !void {
    const file = try fs.openFileAbsolute("/System/Library/Keychains/SystemRootCertificates.keychain", .{});
    defer file.close();

    const bytes = try file.readToEndAlloc(gpa, std.math.maxInt(u32));
    defer gpa.free(bytes);

    var stream = std.io.fixedBufferStream(bytes);
    const reader = stream.reader();

    const db_header = try reader.readStructBig(ApplDbHeader);
    assert(mem.eql(u8, "kych", &@bitCast([4]u8, db_header.signature)));

    try stream.seekTo(db_header.schema_offset);

    const db_schema = try reader.readStructBig(ApplDbSchema);

    var table_list = try gpa.alloc(u32, db_schema.table_count);
    defer gpa.free(table_list);

    var table_idx: u32 = 0;
    while (table_idx < table_list.len) : (table_idx += 1) {
        table_list[table_idx] = try reader.readIntBig(u32);
    }

    const now_sec = std.time.timestamp();

    for (table_list) |table_offset| {
        try stream.seekTo(db_header.schema_offset + table_offset);

        const table_header = try reader.readStructBig(TableHeader);

        if (@intToEnum(TableId, table_header.table_id) != TableId.CSSM_DL_DB_RECORD_X509_CERTIFICATE) {
            continue;
        }

        var record_list = try gpa.alloc(u32, table_header.record_count);
        defer gpa.free(record_list);

        var record_idx: u32 = 0;
        while (record_idx < record_list.len) : (record_idx += 1) {
            record_list[record_idx] = try reader.readIntBig(u32);
        }

        for (record_list) |record_offset| {
            try stream.seekTo(db_header.schema_offset + table_offset + record_offset);

            const cert_header = try reader.readStructBig(X509CertHeader);

            try cb.bytes.ensureUnusedCapacity(gpa, cert_header.cert_size);

            const cert_start = @intCast(u32, cb.bytes.items.len);
            const dest_buf = cb.bytes.allocatedSlice()[cert_start..];
            cb.bytes.items.len += try reader.readAtLeast(dest_buf, cert_header.cert_size);

            try cb.parseCert(gpa, cert_start, now_sec);
        }
    }
}

const ApplDbHeader = extern struct {
    signature: @Vector(4, u8),
    version: u32,
    header_size: u32,
    schema_offset: u32,
    auth_offset: u32,
};

const ApplDbSchema = extern struct {
    schema_size: u32,
    table_count: u32,
};

const TableHeader = extern struct {
    table_size: u32,
    table_id: u32,
    record_count: u32,
    records: u32,
    indexes_offset: u32,
    free_list_head: u32,
    record_numbers_count: u32,
};

const TableId = enum(u32) {
    CSSM_DL_DB_SCHEMA_INFO = 0x00000000,
    CSSM_DL_DB_SCHEMA_INDEXES = 0x00000001,
    CSSM_DL_DB_SCHEMA_ATTRIBUTES = 0x00000002,
    CSSM_DL_DB_SCHEMA_PARSING_MODULE = 0x00000003,

    CSSM_DL_DB_RECORD_ANY = 0x0000000a,
    CSSM_DL_DB_RECORD_CERT = 0x0000000b,
    CSSM_DL_DB_RECORD_CRL = 0x0000000c,
    CSSM_DL_DB_RECORD_POLICY = 0x0000000d,
    CSSM_DL_DB_RECORD_GENERIC = 0x0000000e,
    CSSM_DL_DB_RECORD_PUBLIC_KEY = 0x0000000f,
    CSSM_DL_DB_RECORD_PRIVATE_KEY = 0x00000010,
    CSSM_DL_DB_RECORD_SYMMETRIC_KEY = 0x00000011,
    CSSM_DL_DB_RECORD_ALL_KEYS = 0x00000012,

    CSSM_DL_DB_RECORD_GENERIC_PASSWORD = 0x80000000,
    CSSM_DL_DB_RECORD_INTERNET_PASSWORD = 0x80000001,
    CSSM_DL_DB_RECORD_APPLESHARE_PASSWORD = 0x80000002,
    CSSM_DL_DB_RECORD_USER_TRUST = 0x80000003,
    CSSM_DL_DB_RECORD_X509_CRL = 0x80000004,
    CSSM_DL_DB_RECORD_UNLOCK_REFERRAL = 0x80000005,
    CSSM_DL_DB_RECORD_EXTENDED_ATTRIBUTE = 0x80000006,
    CSSM_DL_DB_RECORD_X509_CERTIFICATE = 0x80001000,
    CSSM_DL_DB_RECORD_METADATA = 0x80008000,

    _,
};

const X509CertHeader = extern struct {
    record_size: u32,
    record_number: u32,
    unknown1: u32,
    unknown2: u32,
    cert_size: u32,
    unknown3: u32,
    cert_type: u32,
    cert_encoding: u32,
    print_name: u32,
    alias: u32,
    subject: u32,
    issuer: u32,
    serial_number: u32,
    subject_key_identifier: u32,
    public_key_hash: u32,
};
