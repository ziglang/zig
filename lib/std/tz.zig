//! The Time Zone Information Format (TZif)
//! https://datatracker.ietf.org/doc/html/rfc8536

const builtin = @import("builtin");

const std = @import("std.zig");
const Reader = std.Io.Reader;
const Allocator = std.mem.Allocator;

pub const Transition = struct {
    ts: i64,
    timetype: *Timetype,
};

pub const Timetype = struct {
    offset: i32,
    flags: u8,
    name_data: [6:0]u8,

    pub fn name(self: *const Timetype) [:0]const u8 {
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
    allocator: Allocator,
    transitions: []const Transition,
    timetypes: []const Timetype,
    leapseconds: []const Leapsecond,
    footer: ?[]const u8,

    const Header = extern struct {
        magic: [4]u8,
        version: u8,
        reserved: [15]u8,
        counts: extern struct {
            isutcnt: u32,
            isstdcnt: u32,
            leapcnt: u32,
            timecnt: u32,
            typecnt: u32,
            charcnt: u32,
        },
    };

    pub fn parse(allocator: Allocator, reader: *Reader) !Tz {
        const legacy_header = try reader.takeStruct(Header, .big);
        if (!std.mem.eql(u8, &legacy_header.magic, "TZif")) return error.BadHeader;
        if (legacy_header.version != 0 and legacy_header.version != '2' and legacy_header.version != '3')
            return error.BadVersion;

        if (legacy_header.version == 0)
            return parseBlock(allocator, reader, legacy_header, true);

        // If the format is modern, just skip over the legacy data
        const skip_n = legacy_header.counts.timecnt * 5 +
            legacy_header.counts.typecnt * 6 +
            legacy_header.counts.charcnt + legacy_header.counts.leapcnt * 8 +
            legacy_header.counts.isstdcnt + legacy_header.counts.isutcnt;
        try reader.discardAll(skip_n);

        var header = try reader.takeStruct(Header, .big);
        if (!std.mem.eql(u8, &header.magic, "TZif")) return error.BadHeader;
        if (header.version != '2' and header.version != '3') return error.BadVersion;

        return parseBlock(allocator, reader, header, false);
    }

    fn parseBlock(allocator: Allocator, reader: *Reader, header: Header, legacy: bool) !Tz {
        if (header.counts.isstdcnt != 0 and header.counts.isstdcnt != header.counts.typecnt) return error.Malformed; // rfc8536: isstdcnt [...] MUST either be zero or equal to "typecnt"
        if (header.counts.isutcnt != 0 and header.counts.isutcnt != header.counts.typecnt) return error.Malformed; // rfc8536: isutcnt [...] MUST either be zero or equal to "typecnt"
        if (header.counts.typecnt == 0) return error.Malformed; // rfc8536: typecnt [...] MUST NOT be zero
        if (header.counts.charcnt == 0) return error.Malformed; // rfc8536: charcnt [...] MUST NOT be zero
        if (header.counts.charcnt > 256 + 6) return error.Malformed; // Not explicitly banned by rfc8536 but nonsensical

        var leapseconds = try allocator.alloc(Leapsecond, header.counts.leapcnt);
        errdefer allocator.free(leapseconds);
        var transitions = try allocator.alloc(Transition, header.counts.timecnt);
        errdefer allocator.free(transitions);
        var timetypes = try allocator.alloc(Timetype, header.counts.typecnt);
        errdefer allocator.free(timetypes);

        // Parse transition types
        var i: usize = 0;
        while (i < header.counts.timecnt) : (i += 1) {
            transitions[i].ts = if (legacy) try reader.takeInt(i32, .big) else try reader.takeInt(i64, .big);
        }

        i = 0;
        while (i < header.counts.timecnt) : (i += 1) {
            const tt = try reader.takeByte();
            if (tt >= timetypes.len) return error.Malformed; // rfc8536: Each type index MUST be in the range [0, "typecnt" - 1]
            transitions[i].timetype = &timetypes[tt];
        }

        // Parse time types
        i = 0;
        while (i < header.counts.typecnt) : (i += 1) {
            const offset = try reader.takeInt(i32, .big);
            if (offset < -2147483648) return error.Malformed; // rfc8536: utoff [...] MUST NOT be -2**31
            const dst = try reader.takeByte();
            if (dst != 0 and dst != 1) return error.Malformed; // rfc8536: (is)dst [...] The value MUST be 0 or 1.
            const idx = try reader.takeByte();
            if (idx > header.counts.charcnt - 1) return error.Malformed; // rfc8536: (desig)idx [...] Each index MUST be in the range [0, "charcnt" - 1]
            timetypes[i] = .{
                .offset = offset,
                .flags = dst,
                .name_data = undefined,
            };

            // Temporarily cache idx in name_data to be processed after we've read the designator names below
            timetypes[i].name_data[0] = idx;
        }

        var designators_data: [256 + 6]u8 = undefined;
        try reader.readSliceAll(designators_data[0..header.counts.charcnt]);
        const designators = designators_data[0..header.counts.charcnt];
        if (designators[designators.len - 1] != 0) return error.Malformed; // rfc8536: charcnt [...] includes the trailing NUL (0x00) octet

        // Iterate through the timetypes again, setting the designator names
        for (timetypes) |*tt| {
            const name = std.mem.sliceTo(designators[tt.name_data[0]..], 0);
            // We are mandating the "SHOULD" 6-character limit so we can pack the struct better, and to conform to POSIX.
            if (name.len > 6) return error.Malformed; // rfc8536: Time zone designations SHOULD consist of at least three (3) and no more than six (6) ASCII characters.
            @memcpy(tt.name_data[0..name.len], name);
            tt.name_data[name.len] = 0;
        }

        // Parse leap seconds
        i = 0;
        while (i < header.counts.leapcnt) : (i += 1) {
            const occur: i64 = if (legacy) try reader.takeInt(i32, .big) else try reader.takeInt(i64, .big);
            if (occur < 0) return error.Malformed; // rfc8536: occur [...] MUST be nonnegative
            if (i > 0 and leapseconds[i - 1].occurrence + 2419199 > occur) return error.Malformed; // rfc8536: occur [...] each later value MUST be at least 2419199 greater than the previous value
            if (occur > std.math.maxInt(i48)) return error.Malformed; // Unreasonably far into the future

            const corr = try reader.takeInt(i32, .big);
            if (i == 0 and corr != -1 and corr != 1) return error.Malformed; // rfc8536: The correction value in the first leap-second record, if present, MUST be either one (1) or minus one (-1)
            if (i > 0 and leapseconds[i - 1].correction != corr + 1 and leapseconds[i - 1].correction != corr - 1) return error.Malformed; // rfc8536: The correction values in adjacent leap-second records MUST differ by exactly one (1)
            if (corr > std.math.maxInt(i16)) return error.Malformed; // Unreasonably large correction

            leapseconds[i] = .{
                .occurrence = @as(i48, @intCast(occur)),
                .correction = @as(i16, @intCast(corr)),
            };
        }

        // Parse standard/wall indicators
        i = 0;
        while (i < header.counts.isstdcnt) : (i += 1) {
            const stdtime = try reader.takeByte();
            if (stdtime == 1) {
                timetypes[i].flags |= 0x02;
            }
        }

        // Parse UT/local indicators
        i = 0;
        while (i < header.counts.isutcnt) : (i += 1) {
            const ut = try reader.takeByte();
            if (ut == 1) {
                timetypes[i].flags |= 0x04;
                if (!timetypes[i].standardTimeIndicator()) return error.Malformed; // rfc8536: standard/wall value MUST be one (1) if the UT/local value is one (1)
            }
        }

        // Footer
        var footer: ?[]u8 = null;
        if (!legacy) {
            if ((try reader.takeByte()) != '\n') return error.Malformed; // An rfc8536 footer must start with a newline
            const footer_mem = reader.takeSentinel('\n') catch |err| switch (err) {
                error.StreamTooLong => return error.OverlargeFooter, // Read more than 128 bytes, much larger than any reasonable POSIX TZ string
                else => return err,
            };
            if (footer_mem.len != 0) {
                footer = try allocator.dupe(u8, footer_mem);
            }
        }
        errdefer if (footer) |ft| allocator.free(ft);

        return .{
            .allocator = allocator,
            .transitions = transitions,
            .timetypes = timetypes,
            .leapseconds = leapseconds,
            .footer = footer,
        };
    }

    pub fn deinit(self: *Tz) void {
        if (self.footer) |footer| {
            self.allocator.free(footer);
        }
        self.allocator.free(self.leapseconds);
        self.allocator.free(self.transitions);
        self.allocator.free(self.timetypes);
    }
};

test "slim" {
    const data = @embedFile("tz/asia_tokyo.tzif");
    var in_stream: Reader = .fixed(data);

    var tz = try std.Tz.parse(std.testing.allocator, &in_stream);
    defer tz.deinit();

    try std.testing.expectEqual(tz.transitions.len, 9);
    try std.testing.expect(std.mem.eql(u8, tz.transitions[3].timetype.name(), "JDT"));
    try std.testing.expectEqual(tz.transitions[5].ts, -620298000); // 1950-05-06 15:00:00 UTC
    try std.testing.expectEqual(tz.leapseconds[13].occurrence, 567993613); // 1988-01-01 00:00:00 UTC (+23s in TAI, and +13 in the data since it doesn't store the initial 10 second offset)
}

test "fat" {
    const data = @embedFile("tz/antarctica_davis.tzif");
    var in_stream: Reader = .fixed(data);

    var tz = try std.Tz.parse(std.testing.allocator, &in_stream);
    defer tz.deinit();

    try std.testing.expectEqual(tz.transitions.len, 8);
    try std.testing.expect(std.mem.eql(u8, tz.transitions[3].timetype.name(), "+05"));
    try std.testing.expectEqual(tz.transitions[4].ts, 1268251224); // 2010-03-10 20:00:00 UTC
}

test "legacy" {
    // Taken from Slackware 8.0, from 2001
    const data = @embedFile("tz/europe_vatican.tzif");
    var in_stream: Reader = .fixed(data);

    var tz = try std.Tz.parse(std.testing.allocator, &in_stream);
    defer tz.deinit();

    try std.testing.expectEqual(tz.transitions.len, 170);
    try std.testing.expect(std.mem.eql(u8, tz.transitions[69].timetype.name(), "CET"));
    try std.testing.expectEqual(tz.transitions[123].ts, 1414285200); // 2014-10-26 01:00:00 UTC
}
