const std = @import("std.zig");
const builtin = @import("builtin");

pub const Transition = struct {
    ts: i64,
    timetype: *Timetype,
};

pub const Timetype = struct {
    offset: i32,
    flags: u8,
    name_data: [6:0]u8,

    pub fn name(self: Timetype) [:0]const u8 {
        return std.mem.sliceTo(self.name_data[0..], 0);
    }

    pub fn isDst(self: Timetype) bool {
        return (self.flags & 0x01) > 0;
    }

    pub fn standardTimeIndicator(self: Timetype) bool {
        return (self.flags & 0x02) > 0;
    }

    pub fn utIndicator(self: Timetype) bool {
        return (self.flags & 0x04) > 0;
    }
};

pub const Leapsecond = struct {
    occurrence: i48,
    correction: i16,
};

pub const Tz = struct {
    allocator: std.mem.Allocator,
    transitions: []const Transition,
    timetypes: []const Timetype,
    leapseconds: []const Leapsecond,
    footer: []const u8,

    pub fn parse(allocator: std.mem.Allocator, reader: anytype) !Tz {
        const Header = extern struct {
            magic: [4]u8,
            version: u8,
            reserved: [15]u8,
        };

        const Counts = extern struct {
            isutcnt: u32,
            isstdcnt: u32,
            leapcnt: u32,
            timecnt: u32,
            typecnt: u32,
            charcnt: u32,
        };

        // Parse and skip the legacy header and data
        {
            const header = try reader.readStruct(Header);
            if (!std.mem.eql(u8, &header.magic, "TZif")) return error.BadHeader;
            if (header.version == 0) return error.UnsupportedLegacyFormat;
            if (header.version != '2' and header.version != '3') return error.BadVersion;

            var counts = try reader.readStruct(Counts);
            if (builtin.target.cpu.arch.endian() != std.builtin.Endian.Big) {
                std.mem.bswapAllFields(Counts, &counts);
            }

            const skipv = counts.timecnt * 5 + counts.typecnt * 6 + counts.charcnt + counts.leapcnt * 8 + counts.isstdcnt + counts.isutcnt;
            try reader.skipBytes(skipv, .{});
        }

        const header = try reader.readStruct(Header);
        if (!std.mem.eql(u8, &header.magic, "TZif")) return error.BadHeader;
        if (header.version != '2' and header.version != '3') return error.BadVersion;

        var counts = try reader.readStruct(Counts);
        if (builtin.target.cpu.arch.endian() != std.builtin.Endian.Big) {
            std.mem.bswapAllFields(Counts, &counts);
        }

        if (counts.isstdcnt != 0 and counts.isstdcnt != counts.typecnt) return error.Malformed; // rfc8536: isstdcnt [...] MUST either be zero or equal to "typecnt"
        if (counts.isutcnt != 0 and counts.isutcnt != counts.typecnt) return error.Malformed; // rfc8536: isutcnt [...] MUST either be zero or equal to "typecnt"
        if (counts.typecnt == 0) return error.Malformed; // rfc8536: typecnt [...] MUST NOT be zero
        if (counts.charcnt == 0) return error.Malformed; // rfc8536: charcnt [...] MUST NOT be zero
        if (counts.charcnt > 256 + 6) return error.Malformed; // Not explicitly banned by rfc8536 but nonsensical

        var leapseconds = try allocator.alloc(Leapsecond, counts.leapcnt);
        errdefer allocator.free(leapseconds);
        var transitions = try allocator.alloc(Transition, counts.timecnt);
        errdefer allocator.free(transitions);
        var timetypes = try allocator.alloc(Timetype, counts.typecnt);
        errdefer allocator.free(timetypes);

        // Parse transition types
        var i: usize = 0;
        while (i < counts.timecnt) : (i += 1) {
            transitions[i].ts = try reader.readIntBig(i64);
        }

        i = 0;
        while (i < counts.timecnt) : (i += 1) {
            const tt = try reader.readByte();
            if (tt >= timetypes.len) return error.Malformed; // rfc8536: Each type index MUST be in the range [0, "typecnt" - 1]
            transitions[i].timetype = &timetypes[tt];
        }

        // Parse time types
        i = 0;
        while (i < counts.typecnt) : (i += 1) {
            const offset = try reader.readIntBig(i32);
            if (offset < -2147483648) return error.Malformed; // rfc8536: utoff [...] MUST NOT be -2**31
            const dst = try reader.readByte();
            if (dst != 0 and dst != 1) return error.Malformed; // rfc8536: (is)dst [...] The value MUST be 0 or 1.
            const idx = try reader.readByte();
            if (idx > counts.charcnt - 1) return error.Malformed; // rfc8536: (desig)idx [...] Each index MUST be in the range [0, "charcnt" - 1]
            timetypes[i] = .{
                .offset = offset,
                .flags = dst,
                .name_data = undefined,
            };

            // Temporarily cache idx in name_data to be processed after we've read the designator names below
            timetypes[i].name_data[0] = idx;
        }

        var designators_data: [256 + 6]u8 = undefined;
        try reader.readNoEof(designators_data[0..counts.charcnt]);
        const designators = designators_data[0..counts.charcnt];
        if (designators[designators.len - 1] != 0) return error.Malformed; // rfc8536: charcnt [...] includes the trailing NUL (0x00) octet

        // Iterate through the timetypes again, setting the designator names
        for (timetypes) |*tt| {
            const name = std.mem.sliceTo(designators[tt.name_data[0]..], 0);
            // We are mandating the "SHOULD" 6-character limit so we can pack the struct better, and to conform to POSIX.
            if (name.len > 6) return error.Malformed; // rfc8536: Time zone designations SHOULD consist of at least three (3) and no more than six (6) ASCII characters.
            std.mem.copy(u8, tt.name_data[0..], name);
            tt.name_data[name.len] = 0;
        }

        // Parse leap seconds
        i = 0;
        while (i < counts.leapcnt) : (i += 1) {
            const occur = try reader.readIntBig(i64);
            if (occur < 0) return error.Malformed; // rfc8536: occur [...] MUST be nonnegative
            if (i > 0 and leapseconds[i - 1].occurrence + 2419199 > occur) return error.Malformed; // rfc8536: occur [...] each later value MUST be at least 2419199 greater than the previous value
            if (occur > std.math.maxInt(i48)) return error.Malformed; // Unreasonably far into the future

            const corr = try reader.readIntBig(i32);
            if (i == 0 and corr != -1 and corr != 1) return error.Malformed; // rfc8536: The correction value in the first leap-second record, if present, MUST be either one (1) or minus one (-1)
            if (i > 0 and leapseconds[i - 1].correction != corr + 1 and leapseconds[i - 1].correction != corr - 1) return error.Malformed; // rfc8536: The correction values in adjacent leap-second records MUST differ by exactly one (1)
            if (corr > std.math.maxInt(i16)) return error.Malformed; // Unreasonably large correction

            leapseconds[i] = .{
                .occurrence = @intCast(i48, occur),
                .correction = @intCast(i16, corr),
            };
        }

        // Parse standard/wall indicators
        i = 0;
        while (i < counts.isstdcnt) : (i += 1) {
            const stdtime = try reader.readByte();
            if (stdtime == 1) {
                timetypes[i].flags |= 0x02;
            }
        }

        // Parse UT/local indicators
        i = 0;
        while (i < counts.isutcnt) : (i += 1) {
            const ut = try reader.readByte();
            if (ut == 1) {
                timetypes[i].flags |= 0x04;
                if (!timetypes[i].standardTimeIndicator()) return error.Malformed; // rfc8536: standard/wall value MUST be one (1) if the UT/local value is one (1)
            }
        }

        if ((try reader.readByte()) != '\n') return error.Malformed; // An rfc8536 footer must start with a newline

        // Footer
        var footerdata_buf: [128]u8 = undefined;
        const footer = reader.readUntilDelimiter(&footerdata_buf, '\n') catch |err| switch (err) {
            error.StreamTooLong => return error.OverlargeFooter, // Read more than 128 bytes, much larger than any reasonable POSIX TZ string
            else => return err,
        };

        const footer_dup = try allocator.dupe(u8, footer);
        errdefer allocator.free(footer_dup);

        return Tz{
            .allocator = allocator,
            .transitions = transitions,
            .timetypes = timetypes,
            .leapseconds = leapseconds,
            .footer = footer_dup,
        };
    }

    pub fn deinit(self: *Tz) void {
        self.allocator.free(self.footer);
        self.allocator.free(self.leapseconds);
        self.allocator.free(self.transitions);
        self.allocator.free(self.timetypes);
    }
};

test "slim" {
    const data = @embedFile("tz/asia_tokyo.tzif");
    var in_stream = std.io.fixedBufferStream(data);

    var tz = try std.Tz.parse(std.testing.allocator, in_stream.reader());
    defer tz.deinit();

    try std.testing.expectEqual(tz.transitions.len, 9);
    try std.testing.expect(std.mem.eql(u8, tz.transitions[3].timetype.name(), "JDT"));
    try std.testing.expectEqual(tz.transitions[5].ts, -620298000); // 1950-05-06 15:00:00 UTC
    try std.testing.expectEqual(tz.leapseconds[13].occurrence, 567993613); // 1988-01-01 00:00:00 UTC (+23s in TAI, and +13 in the data since it doesn't store the initial 10 second offset)
}

test "fat" {
    const data = @embedFile("tz/antarctica_davis.tzif");
    var in_stream = std.io.fixedBufferStream(data);

    var tz = try std.Tz.parse(std.testing.allocator, in_stream.reader());
    defer tz.deinit();

    try std.testing.expectEqual(tz.transitions.len, 8);
    try std.testing.expect(std.mem.eql(u8, tz.transitions[3].timetype.name(), "+05"));
    try std.testing.expectEqual(tz.transitions[4].ts, 1268251224); // 2010-03-10 20:00:00 UTC
}
