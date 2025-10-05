const Limited = @This();

const std = @import("../../std.zig");
const Reader = std.Io.Reader;
const Writer = std.Io.Writer;
const Limit = std.Io.Limit;

unlimited: *Reader,
remaining: Limit,
interface: Reader,

pub fn init(reader: *Reader, limit: Limit, buffer: []u8) Limited {
    return .{
        .unlimited = reader,
        .remaining = limit,
        .interface = .{
            .vtable = &.{
                .stream = stream,
                .discard = discard,
            },
            .buffer = buffer,
            .seek = 0,
            .end = 0,
        },
    };
}

fn stream(r: *Reader, w: *Writer, limit: Limit) Reader.StreamError!usize {
    const l: *Limited = @fieldParentPtr("interface", r);
    const combined_limit = limit.min(l.remaining);
    if (combined_limit.nonzero()) {
        const n = try l.unlimited.stream(w, combined_limit);
        l.remaining = l.remaining.subtract(n).?;
        return n;
    } else return error.EndOfStream;
}

test stream {
    var orig_buf: [10]u8 = undefined;
    @memcpy(&orig_buf, "test bytes");
    var fixed: std.Io.Reader = .fixed(&orig_buf);

    var limit_buf: [1]u8 = undefined;
    var limited: std.Io.Reader.Limited = .init(&fixed, @enumFromInt(4), &limit_buf);

    var result_buf: [10]u8 = undefined;
    var fixed_writer: std.Io.Writer = .fixed(&result_buf);
    const streamed = try limited.interface.stream(&fixed_writer, @enumFromInt(7));

    try std.testing.expect(streamed == 4);
    try std.testing.expectEqualStrings("test", result_buf[0..streamed]);
}

test "readSliceAll from infinite source" {
    const InfSource = struct {
        reader: std.Io.Reader,

        pub fn init(buffer: []u8) @This() {
            return @This(){
                .reader = .{
                    .vtable = &.{
                        .stream = streamA,
                    },
                    .buffer = buffer,
                    .seek = 0,
                    .end = 0,
                },
            };
        }

        fn streamA(io_reader: *std.Io.Reader, w: *std.Io.Writer, limit: std.Io.Limit) std.Io.Reader.StreamError!usize {
            _ = io_reader;

            std.debug.assert(limit.nonzero());

            const n_bytes_remaining = limit.minInt(2);
            for (0..n_bytes_remaining) |_| {
                try w.writeByte('A');
            }
            return n_bytes_remaining;
        }
    };

    // Exact size
    {
        var inf_buf: [10]u8 = undefined;
        var inf_stream = InfSource.init(&inf_buf);

        var limit_buf: [2]u8 = undefined;
        var limited: std.Io.Reader.Limited = .init(&inf_stream.reader, .limited(2), &limit_buf);
        const limited_reader = &limited.interface;

        var out_buffer: [2]u8 = undefined;
        try std.testing.expectEqual({}, limited_reader.readSliceAll(&out_buffer));
        try std.testing.expectEqualStrings("AA", &out_buffer);
    }

    // Too large
    {
        var inf_buf: [10]u8 = undefined;
        var inf_stream = InfSource.init(&inf_buf);

        var limit_buf: [2]u8 = undefined;
        var limited: std.Io.Reader.Limited = .init(&inf_stream.reader, .limited(2), &limit_buf);
        const limited_reader = &limited.interface;

        var out_buffer: [8]u8 = undefined;
        try std.testing.expectError(error.EndOfStream, limited_reader.readSliceAll(&out_buffer));
    }
}

fn discard(r: *Reader, limit: Limit) Reader.Error!usize {
    const l: *Limited = @fieldParentPtr("interface", r);
    const combined_limit = limit.min(l.remaining);
    const n = try l.unlimited.discard(combined_limit);
    l.remaining = l.remaining.subtract(n).?;
    return n;
}
