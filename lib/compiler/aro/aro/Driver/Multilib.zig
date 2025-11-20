const std = @import("std");
const Toolchain = @import("../Toolchain.zig");

/// Large enough for GCCDetector for Linux; may need to be increased to support other toolchains.
const max_multilibs = 4;

pub const Detected = struct {
    multilib_buf: [max_multilibs]Multilib = undefined,
    multilib_count: u8 = 0,
    selected: Multilib = .{},
    biarch_sibling: ?Multilib = null,

    pub fn filter(d: *Detected, multilib_filter: Filter, tc: *const Toolchain) void {
        var found_count: u8 = 0;
        for (d.multilibs()) |multilib| {
            if (multilib_filter.exists(multilib, tc)) {
                d.multilib_buf[found_count] = multilib;
                found_count += 1;
            }
        }
        d.multilib_count = found_count;
    }

    pub fn select(d: *Detected, check_flags: []const []const u8) !bool {
        var selected: ?Multilib = null;

        for (d.multilibs()) |multilib| {
            for (multilib.flags()) |multilib_flag| {
                const matched = for (check_flags) |arg_flag| {
                    if (std.mem.eql(u8, arg_flag[1..], multilib_flag[1..])) break arg_flag;
                } else multilib_flag;
                if (matched[0] != multilib_flag[0]) break;
            } else if (selected != null) {
                return error.TooManyMultilibs;
            } else {
                selected = multilib;
            }
        }
        if (selected) |multilib| {
            d.selected = multilib;
            return true;
        }
        return false;
    }

    pub fn multilibs(d: *const Detected) []const Multilib {
        return d.multilib_buf[0..d.multilib_count];
    }
};

pub const Filter = struct {
    base: [2][]const u8,
    file: []const u8,
    pub fn exists(self: Filter, m: Multilib, tc: *const Toolchain) bool {
        return tc.joinedExists(&.{ self.base[0], self.base[1], m.gcc_suffix, self.file });
    }
};

const Multilib = @This();

gcc_suffix: []const u8 = "",
os_suffix: []const u8 = "",
include_suffix: []const u8 = "",
flag_buf: [6][]const u8 = undefined,
flag_count: u8 = 0,
priority: u32 = 0,

pub fn init(gcc_suffix: []const u8, os_suffix: []const u8, init_flags: []const []const u8) Multilib {
    var self: Multilib = .{
        .gcc_suffix = gcc_suffix,
        .os_suffix = os_suffix,
        .flag_count = @intCast(init_flags.len),
    };
    @memcpy(self.flag_buf[0..init_flags.len], init_flags);
    return self;
}

pub fn flags(m: *const Multilib) []const []const u8 {
    return m.flag_buf[0..m.flag_count];
}
