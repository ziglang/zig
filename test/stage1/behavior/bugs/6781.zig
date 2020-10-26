const std = @import("std");
const assert = std.debug.assert;

const segfault = true;

pub const JournalHeader = packed struct {
    hash_chain_root: u128 = undefined,
    prev_hash_chain_root: u128,
    checksum: u128 = undefined,
    magic: u64,
    command: u32,
    size: u32,

    pub fn calculate_checksum(self: *const JournalHeader, entry: []const u8) u128 {
        assert(entry.len >= @sizeOf(JournalHeader));
        assert(entry.len == self.size);

        const checksum_offset = @byteOffsetOf(JournalHeader, "checksum");
        const checksum_size = @sizeOf(@TypeOf(self.checksum));
        assert(checksum_offset == 0 + 16 + 16);
        assert(checksum_size == 16);

        var target: [32]u8 = undefined;
        std.crypto.hash.Blake3.hash(entry[checksum_offset + checksum_size ..], target[0..], .{});
        return @bitCast(u128, target[0..checksum_size].*);
    }

    pub fn calculate_hash_chain_root(self: *const JournalHeader) u128 {
        const hash_chain_root_size = @sizeOf(@TypeOf(self.hash_chain_root));
        assert(hash_chain_root_size == 16);

        const prev_hash_chain_root_offset = @byteOffsetOf(JournalHeader, "prev_hash_chain_root");
        const prev_hash_chain_root_size = @sizeOf(@TypeOf(self.prev_hash_chain_root));
        assert(prev_hash_chain_root_offset == 0 + 16);
        assert(prev_hash_chain_root_size == 16);

        const checksum_offset = @byteOffsetOf(JournalHeader, "checksum");
        const checksum_size = @sizeOf(@TypeOf(self.checksum));
        assert(checksum_offset == 0 + 16 + 16);
        assert(checksum_size == 16);

        assert(prev_hash_chain_root_offset + prev_hash_chain_root_size == checksum_offset);

        const header = @bitCast([@sizeOf(JournalHeader)]u8, self.*);
        const source = header[prev_hash_chain_root_offset .. checksum_offset + checksum_size];
        assert(source.len == prev_hash_chain_root_size + checksum_size);
        var target: [32]u8 = undefined;
        std.crypto.hash.Blake3.hash(source, target[0..], .{});
        if (segfault) {
            return @bitCast(u128, target[0..hash_chain_root_size].*);
        } else {
            var array = target[0..hash_chain_root_size].*;
            return @bitCast(u128, array);
        }
    }

    pub fn set_checksum_and_hash_chain_root(self: *JournalHeader, entry: []const u8) void {
        self.checksum = self.calculate_checksum(entry);
        self.hash_chain_root = self.calculate_hash_chain_root();
    }
};

test "fixed" {
    var buffer = [_]u8{0} ** 65536;
    var entry = std.mem.bytesAsValue(JournalHeader, buffer[0..@sizeOf(JournalHeader)]);
    entry.* = .{
        .prev_hash_chain_root = 0,
        .magic = 0,
        .command = 0,
        .size = 64 + 128,
    };
    entry.set_checksum_and_hash_chain_root(buffer[0..entry.size]);
    try std.io.null_writer.print("{}\n", .{entry});
}
