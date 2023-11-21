const std = @import("std");
const Filesystem = @import("Filesystem.zig").Filesystem;

pub const Flags = std.BoundedArray([]const u8, 6);

/// Large enough for GCCDetector for Linux; may need to be increased to support other toolchains.
const max_multilibs = 4;

const MultilibArray = std.BoundedArray(Multilib, max_multilibs);

pub const Detected = struct {
    multilibs: MultilibArray = .{},
    selected: Multilib = .{},
    biarch_sibling: ?Multilib = null,

    pub fn filter(self: *Detected, multilib_filter: Filter, fs: Filesystem) void {
        var found_count: usize = 0;
        for (self.multilibs.constSlice()) |multilib| {
            if (multilib_filter.exists(multilib, fs)) {
                self.multilibs.set(found_count, multilib);
                found_count += 1;
            }
        }
        self.multilibs.resize(found_count) catch unreachable;
    }

    pub fn select(self: *Detected, flags: Flags) !bool {
        var filtered: MultilibArray = .{};
        for (self.multilibs.constSlice()) |multilib| {
            for (multilib.flags.constSlice()) |multilib_flag| {
                const matched = for (flags.constSlice()) |arg_flag| {
                    if (std.mem.eql(u8, arg_flag[1..], multilib_flag[1..])) break arg_flag;
                } else multilib_flag;
                if (matched[0] != multilib_flag[0]) break;
            } else {
                filtered.appendAssumeCapacity(multilib);
            }
        }
        if (filtered.len == 0) return false;
        if (filtered.len == 1) {
            self.selected = filtered.get(0);
            return true;
        }
        return error.TooManyMultilibs;
    }
};

pub const Filter = struct {
    base: [2][]const u8,
    file: []const u8,
    pub fn exists(self: Filter, m: Multilib, fs: Filesystem) bool {
        return fs.joinedExists(&.{ self.base[0], self.base[1], m.gcc_suffix, self.file });
    }
};

const Multilib = @This();

gcc_suffix: []const u8 = "",
os_suffix: []const u8 = "",
include_suffix: []const u8 = "",
flags: Flags = .{},
priority: u32 = 0,

pub fn init(gcc_suffix: []const u8, os_suffix: []const u8, flags: []const []const u8) Multilib {
    var self: Multilib = .{
        .gcc_suffix = gcc_suffix,
        .os_suffix = os_suffix,
    };
    self.flags.appendSliceAssumeCapacity(flags);
    return self;
}
