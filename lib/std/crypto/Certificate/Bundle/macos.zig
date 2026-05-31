const std = @import("std");
const Io = std.Io;
const assert = std.debug.assert;
const fs = std.fs;
const mem = std.mem;
const Allocator = std.mem.Allocator;
const Bundle = @import("../Bundle.zig");

pub const RescanMacError = Allocator.Error || fs.File.OpenError || fs.File.ReadError || fs.File.SeekError || Bundle.ParseCertError || error{EndOfStream};

pub fn rescanMac(cb: *Bundle, gpa: Allocator, io: Io, now: Io.Timestamp) RescanMacError!void {
    cb.bytes.clearRetainingCapacity();
    cb.map.clearRetainingCapacity();

    const keychain_paths = [2][]const u8{
        "/System/Library/Keychains/SystemRootCertificates.keychain",
        "/Library/Keychains/System.keychain",
    };

    _ = io; // TODO migrate file system to use std.Io
    for (keychain_paths) |keychain_path| {
        const bytes = std.fs.cwd().readFileAlloc(keychain_path, gpa, .limited(std.math.maxInt(u32))) catch |err| switch (err) {
            error.StreamTooLong => return error.FileTooBig,
            else => |e| return e,
        };
        defer gpa.free(bytes);

        var reader: Io.Reader = .fixed(bytes);
        scanReader(cb, gpa, &reader, now.toSeconds()) catch |err| switch (err) {
            error.ReadFailed => unreachable, // prebuffered
            else => |e| return e,
        };
    }

    cb.bytes.shrinkAndFree(gpa, cb.bytes.items.len);
}

fn scanReader(cb: *Bundle, gpa: Allocator, reader: *Io.Reader, now_sec: i64) !void {
    const db_header = try reader.takeStruct(ApplDbHeader, .big);
    assert(mem.eql(u8, &db_header.signature, "kych"));

    reader.seek = db_header.schema_offset;

    const db_schema = try reader.takeStruct(ApplDbSchema, .big);

    var table_list = try gpa.alloc(u32, db_schema.table_count);
    defer gpa.free(table_list);

    var table_idx: u32 = 0;
    while (table_idx < table_list.len) : (table_idx += 1) {
        table_list[table_idx] = try reader.takeInt(u32, .big);
    }

    for (table_list) |table_offset| {
        reader.seek = db_header.schema_offset + table_offset;

        const table_header = try reader.takeStruct(TableHeader, .big);

        if (@as(std.c.DB_RECORDTYPE, @enumFromInt(table_header.table_id)) != .X509_CERTIFICATE) {
            continue;
        }

        var record_list = try gpa.alloc(u32, table_header.record_count);
        defer gpa.free(record_list);

        var record_idx: u32 = 0;
        while (record_idx < record_list.len) : (record_idx += 1) {
            record_list[record_idx] = try reader.takeInt(u32, .big);
        }

        for (record_list) |record_offset| {
            // An offset of zero means that the record is not present.
            // An offset that is not 4-byte-aligned is invalid.
            if (record_offset == 0 or record_offset % 4 != 0) continue;

            reader.seek = db_header.schema_offset + table_offset + record_offset;

            const cert_header = try reader.takeStruct(X509CertHeader, .big);

            if (cert_header.cert_size == 0) continue;

            const cert_start: u32 = @intCast(cb.bytes.items.len);
            const dest_buf = try cb.bytes.addManyAsSlice(gpa, cert_header.cert_size);
            try reader.readSliceAll(dest_buf);

            try cb.parseCert(gpa, cert_start, now_sec);
        }
    }
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
