const std = @import("../std.zig");
const PositionalReader = @This();
const assert = std.debug.assert;

context: ?*anyopaque,
vtable: *const VTable,

pub const VTable = struct {
    /// Writes bytes starting from `offset` to `bw`.
    ///
    /// Returns the number of bytes written, which will be at minimum `0` and
    /// at most `limit`. The number of bytes written, including zero, does not
    /// indicate end of stream.
    ///
    /// If the resource represented by the reader has an internal seek
    /// position, it is not mutated.
    ///
    /// The implementation should do a maximum of one underlying read call.
    ///
    /// If `error.Unseekable` is returned, the resource cannot be used via a
    /// positional reading interface.
    read: *const fn (ctx: ?*anyopaque, bw: *std.io.BufferedWriter, limit: Limit, offset: u64) anyerror!Status,

    /// Writes bytes starting from `offset` to `data`.
    ///
    /// Returns the number of bytes written, which will be at minimum `0` and
    /// at most `limit`. The number of bytes written, including zero, does not
    /// indicate end of stream.
    ///
    /// If the resource represented by the reader has an internal seek
    /// position, it is not mutated.
    ///
    /// The implementation should do a maximum of one underlying read call.
    ///
    /// If `error.Unseekable` is returned, the resource cannot be used via a
    /// positional reading interface.
    readv: *const fn (ctx: ?*anyopaque, data: []const []u8, offset: u64) anyerror!Status,
};

pub const Len = std.io.Reader.Len;
pub const Status = std.io.Reader.Status;
pub const Limit = std.io.Reader.Limit;

pub fn read(pr: PositionalReader, bw: *std.io.BufferedWriter, limit: Limit, offset: u64) anyerror!Status {
    return pr.vtable.read(pr.context, bw, limit, offset);
}

pub fn readv(pr: PositionalReader, data: []const []u8, offset: u64) anyerror!Status {
    return pr.vtable.read(pr.context, data, offset);
}

/// Returns total number of bytes written to `w`.
///
/// May return `error.Unseekable`, indicating this function cannot be used to
/// read from the reader.
pub fn readAll(pr: PositionalReader, w: *std.io.BufferedWriter, start_offset: u64) anyerror!usize {
    const readFn = pr.vtable.read;
    var offset: u64 = start_offset;
    while (true) {
        const status = try readFn(pr.context, w, .none, offset);
        offset += status.len;
        if (status.end) return @intCast(offset - start_offset);
    }
}
