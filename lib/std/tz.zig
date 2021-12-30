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

    pub fn parse(allocator: std.mem.Allocator, data: []const u8) !Tz {
        const header_size = 4 + 1 + 15 + 6 * 4;
        if (data.len < header_size) return error.BadSize;

        const magic_l = data[0..4];
        const version_l = data[4];
        if (!std.mem.eql(u8, magic_l, "TZif")) return error.BadHeader;
        if (version_l != '2' and version_l != '3') return error.BadVersion;

        // Parse the legacy header and skip the entire thing
        const isutcnt_l = std.mem.readIntBig(u32, data[20..24]);
        const isstdcnt_l = std.mem.readIntBig(u32, data[24..28]);
        const leapcnt_l = std.mem.readIntBig(u32, data[28..32]);
        const timecnt_l = std.mem.readIntBig(u32, data[32..36]);
        const typecnt_l = std.mem.readIntBig(u32, data[36..40]);
        const charcnt_l = std.mem.readIntBig(u32, data[40..44]);
        const data_block_size_legacy = timecnt_l * 5 + typecnt_l * 6 + charcnt_l + leapcnt_l * 8 + isstdcnt_l + isutcnt_l;
        if (data.len < header_size + data_block_size_legacy) return error.BadSize;

        const data2 = data[header_size + data_block_size_legacy ..];
        if (data2.len < header_size) return error.BadSize;

        const magic = data2[0..4];
        const version = data2[4];
        if (!std.mem.eql(u8, magic, "TZif")) return error.BadHeader;
        if (version != '2' and version != '3') return error.BadVersion;

        const isutcnt = std.mem.readIntBig(u32, data2[20..24]);
        const isstdcnt = std.mem.readIntBig(u32, data2[24..28]);
        const leapcnt = std.mem.readIntBig(u32, data2[28..32]);
        const timecnt = std.mem.readIntBig(u32, data2[32..36]);
        const typecnt = std.mem.readIntBig(u32, data2[36..40]);
        const charcnt = std.mem.readIntBig(u32, data2[40..44]);

        if (isstdcnt != 0 and isstdcnt != typecnt) return error.Malformed; // rfc8536: isstdcnt [...] MUST either be zero or equal to "typecnt"
        if (isutcnt != 0 and isutcnt != typecnt) return error.Malformed; // rfc8536: isutcnt [...] MUST either be zero or equal to "typecnt"
        if (typecnt == 0) return error.Malformed; // rfc8536: typecnt [...] MUST NOT be zero
        if (charcnt == 0) return error.Malformed; // rfc8536: charcnt [...] MUST NOT be zero

        const data_block_size = timecnt * 9 + typecnt * 6 + charcnt + leapcnt * 12 + isstdcnt + isutcnt;
        if (data2.len < header_size + data_block_size) return error.BadSize;

        var leapseconds = try allocator.alloc(Leapsecond, leapcnt);
        errdefer allocator.free(leapseconds);
        var transitions = try allocator.alloc(Transition, timecnt);
        errdefer allocator.free(transitions);
        var timetypes = try allocator.alloc(Timetype, typecnt);
        errdefer allocator.free(timetypes);

        var p: usize = header_size;

        // First, parse timezone designators ahead of time so that we can reject malformed files early
        const designators = data2[header_size + timecnt * 9 + typecnt * 6 .. header_size + timecnt * 9 + typecnt * 6 + charcnt];
        if (designators[designators.len - 1] != 0) return error.Malformed; // rfc8536: charcnt [...] includes the trailing NUL (0x00) octet

        // Parse transition types
        var i: usize = 0;
        while (i < timecnt) : (i += 1) {
            transitions[i].ts = std.mem.readIntSliceBig(i64, data2[p .. p + 8]);
            p += 8;
        }

        i = 0;
        while (i < timecnt) : (i += 1) {
            const tt = data2[p];
            if (tt >= timetypes.len) return error.Malformed; // rfc8536: Each type index MUST be in the range [0, "typecnt" - 1]
            transitions[i].timetype = &timetypes[tt];
            p += 1;
        }

        // Parse time types
        i = 0;
        while (i < typecnt) : (i += 1) {
            const offset = std.mem.readIntSliceBig(i32, data2[p .. p + 4]);
            if (offset < -2147483648) return error.Malformed; // rfc8536: utoff [...] MUST NOT be -2**31
            const dst = data2[p + 4];
            if (dst != 0 and dst != 1) return error.Malformed; // rfc8536: (is)dst [...] The value MUST be 0 or 1.
            const idx = data2[p + 5];
            if (idx > designators.len - 1) return error.Malformed; // rfc8536: (desig)idx [...] Each index MUST be in the range [0, "charcnt" - 1]

            const name = std.mem.sliceTo(designators[idx..], 0);

            // We are mandating the "SHOULD" 6-character limit so we can pack the struct better, and to conform to POSIX.
            if (name.len > 6) return error.Malformed; // rfc8536: Time zone designations SHOULD consist of at least three (3) and no more than six (6) ASCII characters.

            timetypes[i] = .{
                .offset = offset,
                .flags = dst,
                .name_data = undefined,
            };

            std.mem.copy(u8, timetypes[i].name_data[0..], name);
            timetypes[i].name_data[name.len] = 0;

            p += 6;
        }

        // Skip the designators we got earlier
        p += charcnt;

        // Parse leap seconds
        i = 0;
        while (i < leapcnt) : (i += 1) {
            const occur = std.mem.readIntSliceBig(i64, data2[p .. p + 8]);
            if (occur < 0) return error.Malformed; // rfc8536: occur [...] MUST be nonnegative
            if (i > 0 and leapseconds[i - 1].occurrence + 2419199 > occur) return error.Malformed; // rfc8536: occur [...] each later value MUST be at least 2419199 greater than the previous value
            if (occur > std.math.maxInt(i48)) return error.Malformed; // Unreasonably far into the future

            const corr = std.mem.readIntSliceBig(i32, data2[p + 8 .. p + 12]);
            if (i == 0 and corr != -1 and corr != 1) return error.Malformed; // rfc8536: The correction value in the first leap-second record, if present, MUST be either one (1) or minus one (-1)
            if (i > 0 and leapseconds[i - 1].correction != corr + 1 and leapseconds[i - 1].correction != corr - 1) return error.Malformed; // rfc8536: The correction values in adjacent leap- second records MUST differ by exactly one (1)
            if (corr > std.math.maxInt(i16)) return error.Malformed; // Unreasonably large correction

            leapseconds[i] = .{
                .occurrence = @intCast(i48, occur),
                .correction = @intCast(i16, corr),
            };
            p += 12;
        }

        // Parse standard/wall indicators
        i = 0;
        while (i < isstdcnt) : (i += 1) {
            const stdtime = data2[p];
            if (stdtime == 1) {
                timetypes[i].flags |= 0x02;
            }
            p += 1;
        }

        // Parse UT/local indicators
        i = 0;
        while (i < isutcnt) : (i += 1) {
            const ut = data2[p];
            if (ut == 1) {
                timetypes[i].flags |= 0x04;
                if (!timetypes[i].standardTimeIndicator()) return error.Malformed; // rfc8536: standard/wall value MUST be one (1) if the UT/local value is one (1)
            }
            p += 1;
        }

        // Footer
        if (data2[p..].len < 2) return error.Malformed; // rfc8536 requires at least 2 newlines
        if (data2[p] != '\n') return error.Malformed; // Not a rfc8536 footer
        const footer_end = std.mem.indexOfScalar(u8, data2[p + 1 ..], '\n') orelse return error.Malformed; // No 2nd rfc8536 newline
        const footer = try allocator.dupe(u8, data2[p + 1 .. p + 1 + footer_end]);
        errdefer allocator.free(footer);

        return Tz{
            .allocator = allocator,
            .transitions = transitions,
            .timetypes = timetypes,
            .leapseconds = leapseconds,
            .footer = footer,
        };
    }

    pub fn deinit(self: *Tz) void {
        self.allocator.free(self.footer);
        self.allocator.free(self.leapseconds);
        self.allocator.free(self.transitions);
        self.allocator.free(self.timetypes);
    }
};

test "parse" {
    // Asia/Tokyo is good for embedding, as Japan only had DST for a short while during the US occupation
    const data = @embedFile("tz/asia_tokyo.tzif");
    var tz = try Tz.parse(std.testing.allocator, data);
    defer tz.deinit();

    try std.testing.expectEqual(tz.transitions.len, 9);
    try std.testing.expect(std.mem.eql(u8, tz.transitions[3].timetype.name(), "JDT"));
    try std.testing.expectEqual(tz.transitions[5].ts, -620298000); // 1950-05-06 15:00:00 (UTC)
    try std.testing.expectEqual(tz.leapseconds[13].occurrence, 567993613); // 1988-01-01 00:00:13 (IAT)
}
