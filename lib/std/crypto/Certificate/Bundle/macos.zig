const std = @import("std");
const assert = std.debug.assert;
const fs = std.fs;
const mem = std.mem;
const Allocator = std.mem.Allocator;
const Bundle = @import("../Bundle.zig");

pub const RescanMacError = Allocator.Error || fs.File.OpenError || fs.File.ReadError || fs.File.SeekError || Bundle.ParseCertError || error{EndOfStream};

pub fn rescanMac(cb: *Bundle, gpa: Allocator) RescanMacError!void {
    cb.bytes.clearRetainingCapacity();
    cb.map.clearRetainingCapacity();

    const keychainPaths = [2][]const u8{
        "/System/Library/Keychains/SystemRootCertificates.keychain",
        "/Library/Keychains/System.keychain",
    };

    const now_sec = std.time.timestamp();

    var records: std.ArrayListUnmanaged(u32) = .empty;
    defer records.deinit(gpa);

    var tables: std.ArrayListUnmanaged(u32) = .empty;
    defer tables.deinit(gpa);

    for (keychainPaths) |keychainPath| {
        const file = try fs.openFileAbsolute(keychainPath, .{});
        defer file.close();

        var in_buffer: [256]u8 = undefined;
        comptime assert(in_buffer.len > @sizeOf(ApplDbHeader));
        comptime assert(in_buffer.len > @sizeOf(ApplDbSchema));
        comptime assert(in_buffer.len > @sizeOf(TableHeader));
        comptime assert(in_buffer.len > @sizeOf(X509CertHeader));
        var file_reader = file.reader();
        var br = file_reader.interface().buffered(&in_buffer);

        const db_header = try br.takeStructEndian(ApplDbHeader, .big);
        if (!mem.eql(u8, &db_header.signature, "kych")) continue;

        try file_reader.seekTo(db_header.schema_offset);
        br = file_reader.interface().buffered(&in_buffer);

        const db_schema = try br.takeStructEndian(ApplDbSchema, .big);

        try tables.resize(db_schema.table_count);
        for (tables.items) |*offset| offset.* = try br.takeInt(u32, .big);

        for (tables.items) |table_offset| {
            try file_reader.seekTo(db_header.schema_offset + table_offset);
            br = file_reader.interface().buffered(&in_buffer);

            const table_header = try br.takeStructEndian(TableHeader, .big);

            if (@as(std.c.DB_RECORDTYPE, @enumFromInt(table_header.table_id)) != .X509_CERTIFICATE) {
                continue;
            }

            try records.resize(gpa, table_header.record_count);
            for (records.items) |*offset| offset.* = try br.takeInt(u32, .big);

            for (records.items) |record_offset| {
                // An offset of zero means that the record is not present.
                // An offset that is not 4-byte-aligned is invalid.
                if (record_offset == 0 or record_offset % 4 != 0) continue;

                try file_reader.seekTo(db_header.schema_offset + table_offset + record_offset);
                br = file_reader.interface().buffered(&in_buffer);

                const cert_header = try br.takeStructEndian(X509CertHeader, .big);
                if (cert_header.cert_size == 0) continue;

                const cert_start: u32 = @intCast(cb.bytes.items.len);
                const dest_buf = try cb.bytes.addManyAsSlice(gpa, cert_header.cert_size);
                try br.readSlice(dest_buf);

                try cb.parseCert(gpa, cert_start, now_sec);
            }
        }
    }

    cb.bytes.shrinkAndFree(gpa, cb.bytes.items.len);
}

const ApplDbHeader = extern struct {
    signature: [4]u8,
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
