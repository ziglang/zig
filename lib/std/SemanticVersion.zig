//! A software version formatted according to the Semantic Versioning 2.0.0 specification.
//!
//! See: https://semver.org

const std = @import("std");
const Version = @This();

major: usize,
minor: usize,
patch: usize,
pre: ?[]const u8 = null,
build: ?[]const u8 = null,

pub const Range = struct {
    min: Version,
    max: Version,

    pub fn includesVersion(self: Range, ver: Version) bool {
        if (self.min.order(ver) == .gt) return false;
        if (self.max.order(ver) == .lt) return false;
        return true;
    }

    /// Checks if system is guaranteed to be at least `version` or older than `version`.
    /// Returns `null` if a runtime check is required.
    pub fn isAtLeast(self: Range, ver: Version) ?bool {
        if (self.min.order(ver) != .lt) return true;
        if (self.max.order(ver) == .lt) return false;
        return null;
    }
};

pub fn order(lhs: Version, rhs: Version) std.math.Order {
    if (lhs.major < rhs.major) return .lt;
    if (lhs.major > rhs.major) return .gt;
    if (lhs.minor < rhs.minor) return .lt;
    if (lhs.minor > rhs.minor) return .gt;
    if (lhs.patch < rhs.patch) return .lt;
    if (lhs.patch > rhs.patch) return .gt;
    if (lhs.pre != null and rhs.pre == null) return .lt;
    if (lhs.pre == null and rhs.pre == null) return .eq;
    if (lhs.pre == null and rhs.pre != null) return .gt;

    // Iterate over pre-release identifiers until a difference is found.
    var lhs_pre_it = std.mem.splitScalar(u8, lhs.pre.?, '.');
    var rhs_pre_it = std.mem.splitScalar(u8, rhs.pre.?, '.');
    while (true) {
        const next_lid = lhs_pre_it.next();
        const next_rid = rhs_pre_it.next();

        // A larger set of pre-release fields has a higher precedence than a smaller set.
        if (next_lid == null and next_rid != null) return .lt;
        if (next_lid == null and next_rid == null) return .eq;
        if (next_lid != null and next_rid == null) return .gt;

        const lid = next_lid.?; // Left identifier
        const rid = next_rid.?; // Right identifier

        // Attempt to parse identifiers as numbers. Overflows are checked by parse.
        const lnum: ?usize = std.fmt.parseUnsigned(usize, lid, 10) catch |err| switch (err) {
            error.InvalidCharacter => null,
            error.Overflow => unreachable,
        };
        const rnum: ?usize = std.fmt.parseUnsigned(usize, rid, 10) catch |err| switch (err) {
            error.InvalidCharacter => null,
            error.Overflow => unreachable,
        };

        // Numeric identifiers always have lower precedence than non-numeric identifiers.
        if (lnum != null and rnum == null) return .lt;
        if (lnum == null and rnum != null) return .gt;

        // Identifiers consisting of only digits are compared numerically.
        // Identifiers with letters or hyphens are compared lexically in ASCII sort order.
        if (lnum != null and rnum != null) {
            if (lnum.? < rnum.?) return .lt;
            if (lnum.? > rnum.?) return .gt;
        } else {
            const ord = std.mem.order(u8, lid, rid);
            if (ord != .eq) return ord;
        }
    }
}

pub fn parse(text: []const u8) !Version {
    // Parse the required major, minor, and patch numbers.
    const extra_index = std.mem.indexOfAny(u8, text, "-+");
    const required = text[0..(extra_index orelse text.len)];
    var it = std.mem.splitScalar(u8, required, '.');
    var ver = Version{
        .major = try parseNum(it.first()),
        .minor = try parseNum(it.next() orelse return error.InvalidVersion),
        .patch = try parseNum(it.next() orelse return error.InvalidVersion),
    };
    if (it.next() != null) return error.InvalidVersion;
    if (extra_index == null) return ver;

    // Slice optional pre-release or build metadata components.
    const extra: []const u8 = text[extra_index.?..text.len];
    if (extra[0] == '-') {
        const build_index = std.mem.indexOfScalar(u8, extra, '+');
        ver.pre = extra[1..(build_index orelse extra.len)];
        if (build_index) |idx| ver.build = extra[(idx + 1)..];
    } else {
        ver.build = extra[1..];
    }

    // Check validity of optional pre-release identifiers.
    // See: https://semver.org/#spec-item-9
    if (ver.pre) |pre| {
        it = std.mem.splitScalar(u8, pre, '.');
        while (it.next()) |id| {
            // Identifiers MUST NOT be empty.
            if (id.len == 0) return error.InvalidVersion;

            // Identifiers MUST comprise only ASCII alphanumerics and hyphens [0-9A-Za-z-].
            for (id) |c| if (!std.ascii.isAlphanumeric(c) and c != '-') return error.InvalidVersion;

            // Numeric identifiers MUST NOT include leading zeroes.
            const is_num = for (id) |c| {
                if (!std.ascii.isDigit(c)) break false;
            } else true;
            if (is_num) _ = try parseNum(id);
        }
    }

    // Check validity of optional build metadata identifiers.
    // See: https://semver.org/#spec-item-10
    if (ver.build) |build| {
        it = std.mem.splitScalar(u8, build, '.');
        while (it.next()) |id| {
            // Identifiers MUST NOT be empty.
            if (id.len == 0) return error.InvalidVersion;

            // Identifiers MUST comprise only ASCII alphanumerics and hyphens [0-9A-Za-z-].
            for (id) |c| if (!std.ascii.isAlphanumeric(c) and c != '-') return error.InvalidVersion;
        }
    }

    return ver;
}

fn parseNum(text: []const u8) error{ InvalidVersion, Overflow }!usize {
    // Leading zeroes are not allowed.
    if (text.len > 1 and text[0] == '0') return error.InvalidVersion;

    return std.fmt.parseUnsigned(usize, text, 10) catch |err| switch (err) {
        error.InvalidCharacter => return error.InvalidVersion,
        error.Overflow => return error.Overflow,
    };
}

pub fn format(
    self: Version,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    out_stream: anytype,
) !void {
    _ = options;
    if (fmt.len != 0) std.fmt.invalidFmtError(fmt, self);
    try std.fmt.format(out_stream, "{d}.{d}.{d}", .{ self.major, self.minor, self.patch });
    if (self.pre) |pre| try std.fmt.format(out_stream, "-{s}", .{pre});
    if (self.build) |build| try std.fmt.format(out_stream, "+{s}", .{build});
}

const expect = std.testing.expect;
const expectError = std.testing.expectError;

test format {
    // Many of these test strings are from https://github.com/semver/semver.org/issues/59#issuecomment-390854010.

    // Valid version strings should be accepted.
    for ([_][]const u8{
        "0.0.4",
        "1.2.3",
        "10.20.30",
        "1.1.2-prerelease+meta",
        "1.1.2+meta",
        "1.1.2+meta-valid",
        "1.0.0-alpha",
        "1.0.0-beta",
        "1.0.0-alpha.beta",
        "1.0.0-alpha.beta.1",
        "1.0.0-alpha.1",
        "1.0.0-alpha0.valid",
        "1.0.0-alpha.0valid",
        "1.0.0-alpha-a.b-c-somethinglong+build.1-aef.1-its-okay",
        "1.0.0-rc.1+build.1",
        "2.0.0-rc.1+build.123",
        "1.2.3-beta",
        "10.2.3-DEV-SNAPSHOT",
        "1.2.3-SNAPSHOT-123",
        "1.0.0",
        "2.0.0",
        "1.1.7",
        "2.0.0+build.1848",
        "2.0.1-alpha.1227",
        "1.0.0-alpha+beta",
        "1.2.3----RC-SNAPSHOT.12.9.1--.12+788",
        "1.2.3----R-S.12.9.1--.12+meta",
        "1.2.3----RC-SNAPSHOT.12.9.1--.12",
        "1.0.0+0.build.1-rc.10000aaa-kk-0.1",
        "5.4.0-1018-raspi",
        "5.7.123",
    }) |valid| try std.testing.expectFmt(valid, "{}", .{try parse(valid)});

    // Invalid version strings should be rejected.
    for ([_][]const u8{
        "",
        "1",
        "1.2",
        "1.2.3-0123",
        "1.2.3-0123.0123",
        "1.1.2+.123",
        "+invalid",
        "-invalid",
        "-invalid+invalid",
        "-invalid.01",
        "alpha",
        "alpha.beta",
        "alpha.beta.1",
        "alpha.1",
        "alpha+beta",
        "alpha_beta",
        "alpha.",
        "alpha..",
        "beta\\",
        "1.0.0-alpha_beta",
        "-alpha.",
        "1.0.0-alpha..",
        "1.0.0-alpha..1",
        "1.0.0-alpha...1",
        "1.0.0-alpha....1",
        "1.0.0-alpha.....1",
        "1.0.0-alpha......1",
        "1.0.0-alpha.......1",
        "01.1.1",
        "1.01.1",
        "1.1.01",
        "1.2",
        "1.2.3.DEV",
        "1.2-SNAPSHOT",
        "1.2.31.2.3----RC-SNAPSHOT.12.09.1--..12+788",
        "1.2-RC-SNAPSHOT",
        "-1.0.3-gamma+b7718",
        "+justmeta",
        "9.8.7+meta+meta",
        "9.8.7-whatever+meta+meta",
        "2.6.32.11-svn21605",
        "2.11.2(0.329/5/3)",
        "2.13-DEVELOPMENT",
        "2.3-35",
        "1a.4",
        "3.b1.0",
        "1.4beta",
        "2.7.pre",
        "0..3",
        "8.008.",
        "01...",
        "55",
        "foobar",
        "",
        "-1",
        "+4",
        ".",
        "....3",
    }) |invalid| try expectError(error.InvalidVersion, parse(invalid));

    // Valid version string that may overflow.
    const big_valid = "99999999999999999999999.999999999999999999.99999999999999999";
    if (parse(big_valid)) |ver| {
        try std.testing.expectFmt(big_valid, "{}", .{ver});
    } else |err| try expect(err == error.Overflow);

    // Invalid version string that may overflow.
    const big_invalid = "99999999999999999999999.999999999999999999.99999999999999999----RC-SNAPSHOT.12.09.1--------------------------------..12";
    if (parse(big_invalid)) |ver| std.debug.panic("expected error, found {}", .{ver}) else |_| {}
}

test "precedence" {
    // SemVer 2 spec 11.2 example: 1.0.0 < 2.0.0 < 2.1.0 < 2.1.1.
    try expect(order(try parse("1.0.0"), try parse("2.0.0")) == .lt);
    try expect(order(try parse("2.0.0"), try parse("2.1.0")) == .lt);
    try expect(order(try parse("2.1.0"), try parse("2.1.1")) == .lt);

    // SemVer 2 spec 11.3 example: 1.0.0-alpha < 1.0.0.
    try expect(order(try parse("1.0.0-alpha"), try parse("1.0.0")) == .lt);

    // SemVer 2 spec 11.4 example: 1.0.0-alpha < 1.0.0-alpha.1 < 1.0.0-alpha.beta < 1.0.0-beta <
    // 1.0.0-beta.2 < 1.0.0-beta.11 < 1.0.0-rc.1 < 1.0.0.
    try expect(order(try parse("1.0.0-alpha"), try parse("1.0.0-alpha.1")) == .lt);
    try expect(order(try parse("1.0.0-alpha.1"), try parse("1.0.0-alpha.beta")) == .lt);
    try expect(order(try parse("1.0.0-alpha.beta"), try parse("1.0.0-beta")) == .lt);
    try expect(order(try parse("1.0.0-beta"), try parse("1.0.0-beta.2")) == .lt);
    try expect(order(try parse("1.0.0-beta.2"), try parse("1.0.0-beta.11")) == .lt);
    try expect(order(try parse("1.0.0-beta.11"), try parse("1.0.0-rc.1")) == .lt);
    try expect(order(try parse("1.0.0-rc.1"), try parse("1.0.0")) == .lt);
}

test "zig_version" {
    // An approximate Zig build that predates this test.
    const older_version = .{ .major = 0, .minor = 8, .patch = 0, .pre = "dev.874" };

    // Simulated compatibility check using Zig version.
    const compatible = comptime @import("builtin").zig_version.order(older_version) == .gt;
    if (!compatible) @compileError("zig_version test failed");
}
