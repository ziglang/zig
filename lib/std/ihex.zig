const std = @import("std");

pub const ParseMode = struct {
    /// When pedantic is true, the parser will not allow data between
    /// records.
    pedantic: bool = true,
};

/// An intel hex data record.
/// Resembles a single line in the hex file.
pub const Record = union(enum) {
    data: Data,
    end_of_file: void,
    extended_segment_address: ExtendedSegmentAddress,
    start_segment_address: StartSegmentAddress,
    extended_linear_address: ExtendedLinearAddress,
    start_linear_address: LinearStartAddress,

    /// A record that contains data.
    pub const Data = struct {
        /// Offset from the start of the current segment.
        offset: u16,
        /// Bytes in the segment
        data: []const u8,
    };

    /// Contains the 8086 segment for the following data.
    pub const ExtendedSegmentAddress = struct {
        segment: u16,
    };

    /// Contains the 8086 entry point for this file.
    pub const StartSegmentAddress = struct {
        /// The `CS` selector for the entry point.
        segment: u16,

        /// The `IP` register content for the entry point.
        offset: u16,
    };

    /// Contains the linear offset for all following data.
    pub const ExtendedLinearAddress = struct {
        /// The upper 16 bit for the address.
        upperWord: u16,
    };

    /// Contains the linear 32 bit entry point.
    pub const LinearStartAddress = struct {
        /// Linear entry point without segmentation.
        offset: u32,
    };
};

/// Parses intel hex records from the stream, using `mode` as parser configuration.
/// For each record, `loader` is called with `context` as the first parameter.
pub fn parseRaw(stream: anytype, mode: ParseMode, context: anytype, Errors: type, loader: fn (@TypeOf(context), record: Record) Errors!void) !void {
    while (true) {
        var b = stream.readByte() catch |err| {
            if (err == error.EndOfStream and !mode.pedantic)
                return;
            return err;
        };
        if (b != ':') {
            if (b != '\n' and b != '\r' and mode.pedantic) {
                return error.InvalidCharacter;
            } else {
                continue;
            }
        }

        var line_buffer: [520]u8 = undefined;

        try stream.readNoEof(line_buffer[0..2]);

        const byte_count = std.fmt.parseInt(u8, line_buffer[0..2], 16) catch return error.InvalidRecord;

        const end_index = 10 + 2 * byte_count;

        try stream.readNoEof(line_buffer[2..end_index]);
        const line = line_buffer[0..end_index];

        const address = std.fmt.parseInt(u16, line[2..6], 16) catch return error.InvalidRecord;

        const record_type = std.fmt.parseInt(u8, line[6..8], 16) catch return error.InvalidRecord;

        {
            var i: usize = 0;
            var checksum: u8 = 0;
            while (i < line.len) : (i += 2) {
                checksum +%= std.fmt.parseInt(u8, line[i .. i + 2], 16) catch return error.InvalidRecord;
            }
            if (checksum != 0)
                return error.InvalidChecksum;
        }

        switch (record_type) {
            0x00 => {
                var temp_data: [255]u8 = undefined;
                for (temp_data[0..byte_count]) |*c, i| {
                    c.* = std.fmt.parseInt(u8, line[8 + 2 * i .. 10 + 2 * i], 16) catch return error.InvalidRecord;
                }
                const data = Record.Data{
                    .offset = address,
                    .data = temp_data[0..byte_count],
                };

                try loader(context, Record{ .data = data });
            },
            0x01 => {
                try loader(context, Record{ .end_of_file = {} });
                return;
            },
            0x02 => {
                if (byte_count != 2)
                    return error.InvalidRecord;
                const addr = Record.ExtendedSegmentAddress{
                    .segment = std.fmt.parseInt(u16, line[8..12], 16) catch return error.InvalidRecord,
                };
                try loader(context, Record{ .extended_segment_address = addr });
            },
            0x03 => {
                if (byte_count != 4)
                    return error.InvalidRecord;
                const addr = Record.StartSegmentAddress{
                    .segment = std.fmt.parseInt(u16, line[8..12], 16) catch return error.InvalidRecord,
                    .offset = std.fmt.parseInt(u16, line[12..16], 16) catch return error.InvalidRecord,
                };
                try loader(context, Record{ .start_segment_address = addr });
            },
            0x04 => {
                if (byte_count != 2)
                    return error.InvalidRecord;
                const addr = Record.ExtendedLinearAddress{
                    .upperWord = std.fmt.parseInt(u16, line[8..12], 16) catch return error.InvalidRecord,
                };
                try loader(context, Record{ .extended_linear_address = addr });
            },
            0x05 => {
                if (byte_count != 4)
                    return error.InvalidRecord;
                const addr = Record.LinearStartAddress{
                    .offset = std.fmt.parseInt(u32, line[8..16], 16) catch return error.InvalidRecord,
                };
                try loader(context, Record{ .start_linear_address = addr });
            },
            else => return error.InvalidRecord,
        }
    }
}

/// Parses intel hex data segments from the stream, using `mode` as parser configuration.
/// For each data record, `loader` is called with `context` as the first parameter.
pub fn parseData(stream: anytype, mode: ParseMode, context: anytype, Errors: type, loader: fn (@TypeOf(context), offset: u32, record: []const u8) Errors!void) !?u32 {
    const Parser = struct {
        entry_point: ?u32,
        current_offset: u32,

        _context: @TypeOf(context),
        _loader: fn (@TypeOf(context), offset: u32, record: []const u8) Errors!void,

        fn load(parser: *@This(), record: Record) Errors!void {
            switch (record) {
                // Basic records
                .end_of_file => {},
                .data => |data| try parser._loader(parser._context, parser.current_offset + data.offset, data.data),

                // Oldschool offsets
                .extended_segment_address => |addr| parser.current_offset = 16 * @as(u32, addr.segment),
                .start_segment_address => |addr| parser.entry_point = 16 * @as(u32, addr.segment) + @as(u32, addr.offset),

                // Newschool offsets
                .extended_linear_address => |addr| parser.current_offset = @as(u32, addr.upperWord) << 16,
                .start_linear_address => |addr| parser.entry_point = addr.offset,
            }
        }
    };

    var parser = Parser{
        .entry_point = null,
        .current_offset = 0,
        ._context = context,
        ._loader = loader,
    };

    try parseRaw(stream, mode, &parser, Errors, Parser.load);

    return parser.entry_point;
}

const pedanticTestData =
    \\:0B0010006164647265737320676170A7
    \\:020000021200EA
    \\:0400000300003800C1
    \\:02000004FFFFFC
    \\:04000005000000CD2A
    \\:00000001FF
    \\
;

const laxTestData =
    \\ this is a comment!
    \\:0B0010006164647265737320676170A7
    \\:020000021200EAi also allow stupid stuff here
    \\:0400000300003800C1
    \\:02000004FFFFFC
    \\this is not a comment
    \\:04000005000000CD2A
    \\34098302948092803284093284093284098320948s
;

const TestVerifier = struct {
    index: usize = 0,

    fn process(verifier: *TestVerifier, record: Record) !void {
        switch (verifier.index) {
            0 => {
                std.testing.expectEqual(@as(u16, 16), record.data.offset);
                std.testing.expectEqualSlices(u8, "address gap", record.data.data);
            },
            1 => std.testing.expectEqual(@as(u16, 4608), record.extended_segment_address.segment),
            2 => {
                std.testing.expectEqual(@as(u16, 0), record.start_segment_address.segment);
                std.testing.expectEqual(@as(u16, 14336), record.start_segment_address.offset);
            },
            3 => std.testing.expectEqual(@as(u16, 65535), record.extended_linear_address.upperWord),
            4 => std.testing.expectEqual(@as(u32, 205), record.start_linear_address.offset),
            5 => std.testing.expect(record == .end_of_file),
            else => @panic("too many records!"),
        }
        verifier.index += 1;
    }
};

test "ihex pedantic" {
    var stream = std.io.fixedBufferStream(pedanticTestData).inStream();

    var verifier = TestVerifier{};
    try parseRaw(stream, ParseMode{ .pedantic = true }, &verifier, error{}, TestVerifier.process);
}

test "ihex lax" {
    var stream = std.io.fixedBufferStream(laxTestData).inStream();

    var verifier = TestVerifier{};
    try parseRaw(stream, ParseMode{ .pedantic = false }, &verifier, error{}, TestVerifier.process);
}

fn ignoreRecords(x: void, offset: u32, data: []const u8) !void {}

test "parseData" {
    var stream = std.io.fixedBufferStream(pedanticTestData).inStream();
    const ep = try parseData(stream, ParseMode{ .pedantic = true }, {}, error{}, ignoreRecords);

    std.testing.expectEqual(@as(u32, 205), ep.?);
}
