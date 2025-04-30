const Limited = @This();

const std = @import("../../std.zig");
const Reader = std.io.Reader;
const BufferedWriter = std.io.BufferedWriter;

unlimited_reader: Reader,
remaining: Reader.Limit,

pub fn reader(l: *Limited) Reader {
    return .{
        .context = l,
        .vtable = &.{
            .read = passthruRead,
            .readVec = passthruReadVec,
            .discard = passthruDiscard,
        },
    };
}

fn passthruRead(context: ?*anyopaque, bw: *BufferedWriter, limit: Reader.Limit) Reader.RwError!usize {
    const l: *Limited = @alignCast(@ptrCast(context));
    const combined_limit = limit.min(l.remaining);
    const n = try l.unlimited_reader.read(bw, combined_limit);
    l.remaining.subtract(n);
    return n;
}

fn passthruDiscard(context: ?*anyopaque, limit: Reader.Limit) Reader.Error!usize {
    const l: *Limited = @alignCast(@ptrCast(context));
    const combined_limit = limit.min(l.remaining);
    const n = try l.unlimited_reader.discard(combined_limit);
    l.remaining.subtract(n);
    return n;
}

fn passthruReadVec(context: ?*anyopaque, data: []const []u8) Reader.Error!usize {
    const l: *Limited = @alignCast(@ptrCast(context));
    if (data.len == 0) return 0;
    if (data[0].len >= @intFromEnum(l.limit)) {
        const n = try l.unlimited_reader.readVec(&.{l.limit.slice(data[0])});
        l.remaining.subtract(n);
        return n;
    }
    var total: usize = 0;
    for (data, 0..) |buf, i| {
        total += buf.len;
        if (total > @intFromEnum(l.limit)) {
            const n = try l.unlimited_reader.readVec(data[0..i]);
            l.remaining.subtract(n);
            return n;
        }
    }
    return 0;
}
