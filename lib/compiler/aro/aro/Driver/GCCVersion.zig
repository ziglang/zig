const std = @import("std");
const mem = std.mem;
const Order = std.math.Order;

const GCCVersion = @This();

/// Raw version number text
raw: []const u8 = "",

/// -1 indicates not present
major: i32 = -1,
/// -1 indicates not present
minor: i32 = -1,
/// -1 indicates not present
patch: i32 = -1,

/// Text of parsed major version number
major_str: []const u8 = "",
/// Text of parsed major + minor version number
minor_str: []const u8 = "",

/// Patch number suffix
suffix: []const u8 = "",

/// This orders versions according to the preferred usage order, not a notion of release-time ordering
/// Higher version numbers are preferred, but nonexistent minor/patch/suffix is preferred to one that does exist
/// e.g. `4.1` is preferred over `4.0` but `4` is preferred over both `4.0` and `4.1`
pub fn isLessThan(self: GCCVersion, rhs_major: i32, rhs_minor: i32, rhs_patch: i32, rhs_suffix: []const u8) bool {
    if (self.major != rhs_major) {
        return self.major < rhs_major;
    }
    if (self.minor != rhs_minor) {
        if (rhs_minor == -1) return true;
        if (self.minor == -1) return false;
        return self.minor < rhs_minor;
    }
    if (self.patch != rhs_patch) {
        if (rhs_patch == -1) return true;
        if (self.patch == -1) return false;
        return self.patch < rhs_patch;
    }
    if (!mem.eql(u8, self.suffix, rhs_suffix)) {
        if (rhs_suffix.len == 0) return true;
        if (self.suffix.len == 0) return false;
        return switch (std.mem.order(u8, self.suffix, rhs_suffix)) {
            .lt => true,
            .eq => unreachable,
            .gt => false,
        };
    }
    return false;
}

/// Strings in the returned GCCVersion struct have the same lifetime as `text`
pub fn parse(text: []const u8) GCCVersion {
    const bad = GCCVersion{ .major = -1 };
    var good = bad;

    var it = mem.splitScalar(u8, text, '.');
    const first = it.next().?;
    const second = it.next() orelse "";
    const rest = it.next() orelse "";

    good.major = std.fmt.parseInt(i32, first, 10) catch return bad;
    if (good.major < 0) return bad;
    good.major_str = first;

    if (second.len == 0) return good;
    var minor_str = second;

    if (rest.len == 0) {
        const end = mem.indexOfNone(u8, minor_str, "0123456789") orelse minor_str.len;
        if (end > 0) {
            good.suffix = minor_str[end..];
            minor_str = minor_str[0..end];
        }
    }
    good.minor = std.fmt.parseInt(i32, minor_str, 10) catch return bad;
    if (good.minor < 0) return bad;
    good.minor_str = minor_str;

    if (rest.len > 0) {
        const end = mem.indexOfNone(u8, rest, "0123456789") orelse rest.len;
        if (end > 0) {
            const patch_num_text = rest[0..end];
            good.patch = std.fmt.parseInt(i32, patch_num_text, 10) catch return bad;
            if (good.patch < 0) return bad;
            good.suffix = rest[end..];
        }
    }

    return good;
}

pub fn order(a: GCCVersion, b: GCCVersion) Order {
    if (a.isLessThan(b.major, b.minor, b.patch, b.suffix)) return .lt;
    if (b.isLessThan(a.major, a.minor, a.patch, a.suffix)) return .gt;
    return .eq;
}

/// Used for determining __GNUC__ macro values
/// This matches clang's logic for overflowing values
pub fn toUnsigned(self: GCCVersion) u32 {
    var result: u32 = 0;
    if (self.major > 0) result = @as(u32, @intCast(self.major)) *% 10_000;
    if (self.minor > 0) result +%= @as(u32, @intCast(self.minor)) *% 100;
    if (self.patch > 0) result +%= @as(u32, @intCast(self.patch));
    return result;
}

test parse {
    const versions = [10]GCCVersion{
        parse("5"),
        parse("4"),
        parse("4.2"),
        parse("4.0"),
        parse("4.0-patched"),
        parse("4.0.2"),
        parse("4.0.1"),
        parse("4.0.1-patched"),
        parse("4.0.0"),
        parse("4.0.0-patched"),
    };

    for (versions[0 .. versions.len - 1], versions[1..versions.len]) |first, second| {
        try std.testing.expectEqual(Order.eq, first.order(first));
        try std.testing.expectEqual(Order.gt, first.order(second));
        try std.testing.expectEqual(Order.lt, second.order(first));
    }
    const last = versions[versions.len - 1];
    try std.testing.expectEqual(Order.eq, last.order(last));
}
