const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;
const mem = std.mem;
const testing = std.testing;
const os = std.os;

const Target = std.Target;

/// Detect macOS version.
/// `target_os` is not modified in case of error.
pub fn detect(target_os: *Target.Os) !void {
    // Drop use of osproductversion sysctl because:
    //   1. only available 10.13.4 High Sierra and later
    //   2. when used from a binary built against < SDK 11.0 it returns 10.16 and masks Big Sur 11.x version
    //
    // NEW APPROACH, STEP 1, parse file:
    //
    //   /System/Library/CoreServices/SystemVersion.plist
    //
    // NOTE: Historically `SystemVersion.plist` first appeared circa '2003
    // with the release of Mac OS X 10.3.0 Panther.
    //
    // and if it contains a `10.16` value where the `16` is `>= 16` then it is non-canonical,
    // discarded, and we move on to next step. Otherwise we accept the version.
    //
    // BACKGROUND: `10.(16+)` is not a proper version and does not have enough fidelity to
    // indicate minor/point version of Big Sur and later. It is a context-sensitive result
    // issued by the kernel for backwards compatibility purposes. Likely the kernel checks
    // if the executable was linked against an SDK older than Big Sur.
    //
    // STEP 2, parse next file:
    //
    //   /System/Library/CoreServices/.SystemVersionPlatform.plist
    //
    // NOTE: Historically `SystemVersionPlatform.plist` first appeared circa '2020
    // with the release of macOS 11.0 Big Sur.
    //
    // Accessing the content via this path circumvents a context-sensitive result and
    // yields a canonical Big Sur version.
    //
    // At this time there is no other known way for a < SDK 11.0 executable to obtain a
    // canonical Big Sur version.
    //
    // This implementation uses a reasonably simplified approach to parse .plist file
    // that while it is an xml document, we have good history on the file and its format
    // such that I am comfortable with implementing a minimalistic parser.
    // Things like string and general escapes are not supported.
    const prefixSlash = "/System/Library/CoreServices/";
    const paths = [_][]const u8{
        prefixSlash ++ "SystemVersion.plist",
        prefixSlash ++ ".SystemVersionPlatform.plist",
    };
    for (paths) |path| {
        // approx. 4 times historical file size
        var buf: [2048]u8 = undefined;

        if (std.fs.cwd().readFile(path, &buf)) |bytes| {
            if (parseSystemVersion(bytes)) |ver| {
                // never return non-canonical `10.(16+)`
                if (!(ver.major == 10 and ver.minor >= 16)) {
                    target_os.version_range.semver.min = ver;
                    target_os.version_range.semver.max = ver;
                    return;
                }
                continue;
            } else |_| {
                return error.OSVersionDetectionFail;
            }
        } else |_| {
            return error.OSVersionDetectionFail;
        }
    }
    return error.OSVersionDetectionFail;
}

fn parseSystemVersion(buf: []const u8) !std.SemanticVersion {
    var svt = SystemVersionTokenizer{ .bytes = buf };
    try svt.skipUntilTag(.start, "dict");
    while (true) {
        try svt.skipUntilTag(.start, "key");
        const content = try svt.expectContent();
        try svt.skipUntilTag(.end, "key");
        if (mem.eql(u8, content, "ProductVersion")) break;
    }
    try svt.skipUntilTag(.start, "string");
    const ver = try svt.expectContent();
    try svt.skipUntilTag(.end, "string");

    const parseVersionComponent = struct {
        fn parseVersionComponent(component: []const u8) !usize {
            return std.fmt.parseUnsigned(usize, component, 10) catch |err| {
                switch (err) {
                    error.InvalidCharacter => return error.InvalidVersion,
                    error.Overflow => return error.Overflow,
                }
            };
        }
    }.parseVersionComponent;
    var version_components = mem.split(u8, ver, ".");
    const major = version_components.first();
    const minor = version_components.next() orelse return error.InvalidVersion;
    const patch = version_components.next() orelse "0";
    if (version_components.next() != null) return error.InvalidVersion;
    return .{
        .major = try parseVersionComponent(major),
        .minor = try parseVersionComponent(minor),
        .patch = try parseVersionComponent(patch),
    };
}

const SystemVersionTokenizer = struct {
    bytes: []const u8,
    index: usize = 0,
    state: State = .begin,

    fn next(self: *@This()) !?Token {
        var mark: usize = self.index;
        var tag = Tag{};
        var content: []const u8 = "";

        while (self.index < self.bytes.len) {
            const char = self.bytes[self.index];
            switch (self.state) {
                .begin => switch (char) {
                    '<' => {
                        self.state = .tag0;
                        self.index += 1;
                        tag = Tag{};
                        mark = self.index;
                    },
                    '>' => {
                        return error.BadToken;
                    },
                    else => {
                        self.state = .content;
                        content = "";
                        mark = self.index;
                    },
                },
                .tag0 => switch (char) {
                    '<' => {
                        return error.BadToken;
                    },
                    '>' => {
                        self.state = .begin;
                        self.index += 1;
                        tag.name = self.bytes[mark..self.index];
                        return Token{ .tag = tag };
                    },
                    '"' => {
                        self.state = .tag_string;
                        self.index += 1;
                    },
                    '/' => {
                        self.state = .tag0_end_or_empty;
                        self.index += 1;
                    },
                    'A'...'Z', 'a'...'z' => {
                        self.state = .tagN;
                        tag.kind = .start;
                        self.index += 1;
                    },
                    else => {
                        self.state = .tagN;
                        self.index += 1;
                    },
                },
                .tag0_end_or_empty => switch (char) {
                    '<' => {
                        return error.BadToken;
                    },
                    '>' => {
                        self.state = .begin;
                        tag.kind = .empty;
                        tag.name = self.bytes[self.index..self.index];
                        self.index += 1;
                        return Token{ .tag = tag };
                    },
                    else => {
                        self.state = .tagN;
                        tag.kind = .end;
                        mark = self.index;
                        self.index += 1;
                    },
                },
                .tagN => switch (char) {
                    '<' => {
                        return error.BadToken;
                    },
                    '>' => {
                        self.state = .begin;
                        tag.name = self.bytes[mark..self.index];
                        self.index += 1;
                        return Token{ .tag = tag };
                    },
                    '"' => {
                        self.state = .tag_string;
                        self.index += 1;
                    },
                    '/' => {
                        self.state = .tagN_end;
                        tag.kind = .end;
                        self.index += 1;
                    },
                    else => {
                        self.index += 1;
                    },
                },
                .tagN_end => switch (char) {
                    '>' => {
                        self.state = .begin;
                        tag.name = self.bytes[mark..self.index];
                        self.index += 1;
                        return Token{ .tag = tag };
                    },
                    else => {
                        return error.BadToken;
                    },
                },
                .tag_string => switch (char) {
                    '"' => {
                        self.state = .tagN;
                        self.index += 1;
                    },
                    else => {
                        self.index += 1;
                    },
                },
                .content => switch (char) {
                    '<' => {
                        self.state = .tag0;
                        content = self.bytes[mark..self.index];
                        self.index += 1;
                        tag = Tag{};
                        mark = self.index;
                        return Token{ .content = content };
                    },
                    '>' => {
                        return error.BadToken;
                    },
                    else => {
                        self.index += 1;
                    },
                },
            }
        }

        return null;
    }

    fn expectContent(self: *@This()) ![]const u8 {
        if (try self.next()) |tok| {
            switch (tok) {
                .content => |content| {
                    return content;
                },
                else => {},
            }
        }
        return error.UnexpectedToken;
    }

    fn skipUntilTag(self: *@This(), kind: Tag.Kind, name: []const u8) !void {
        while (try self.next()) |tok| {
            switch (tok) {
                .tag => |tag| {
                    if (tag.kind == kind and mem.eql(u8, tag.name, name)) return;
                },
                else => {},
            }
        }
        return error.TagNotFound;
    }

    const State = enum {
        begin,
        tag0,
        tag0_end_or_empty,
        tagN,
        tagN_end,
        tag_string,
        content,
    };

    const Token = union(enum) {
        tag: Tag,
        content: []const u8,
    };

    const Tag = struct {
        kind: Kind = .unknown,
        name: []const u8 = "",

        const Kind = enum { unknown, start, end, empty };
    };
};

test "detect" {
    const cases = .{
        .{
            \\<?xml version="1.0" encoding="UTF-8"?>
            \\<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            \\<plist version="1.0">
            \\<dict>
            \\    <key>ProductBuildVersion</key>
            \\    <string>7B85</string>
            \\    <key>ProductCopyright</key>
            \\    <string>Apple Computer, Inc. 1983-2003</string>
            \\    <key>ProductName</key>
            \\    <string>Mac OS X</string>
            \\    <key>ProductUserVisibleVersion</key>
            \\    <string>10.3</string>
            \\    <key>ProductVersion</key>
            \\    <string>10.3</string>
            \\</dict>
            \\</plist>
            ,
            .{ .major = 10, .minor = 3, .patch = 0 },
        },
        .{
            \\<?xml version="1.0" encoding="UTF-8"?>
            \\<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            \\<plist version="1.0">
            \\<dict>
            \\	<key>ProductBuildVersion</key>
            \\	<string>7W98</string>
            \\	<key>ProductCopyright</key>
            \\	<string>Apple Computer, Inc. 1983-2004</string>
            \\	<key>ProductName</key>
            \\	<string>Mac OS X</string>
            \\	<key>ProductUserVisibleVersion</key>
            \\	<string>10.3.9</string>
            \\	<key>ProductVersion</key>
            \\	<string>10.3.9</string>
            \\</dict>
            \\</plist>
            ,
            .{ .major = 10, .minor = 3, .patch = 9 },
        },
        .{
            \\<?xml version="1.0" encoding="UTF-8"?>
            \\<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            \\<plist version="1.0">
            \\<dict>
            \\	<key>ProductBuildVersion</key>
            \\	<string>19G68</string>
            \\	<key>ProductCopyright</key>
            \\	<string>1983-2020 Apple Inc.</string>
            \\	<key>ProductName</key>
            \\	<string>Mac OS X</string>
            \\	<key>ProductUserVisibleVersion</key>
            \\	<string>10.15.6</string>
            \\	<key>ProductVersion</key>
            \\	<string>10.15.6</string>
            \\	<key>iOSSupportVersion</key>
            \\	<string>13.6</string>
            \\</dict>
            \\</plist>
            ,
            .{ .major = 10, .minor = 15, .patch = 6 },
        },
        .{
            \\<?xml version="1.0" encoding="UTF-8"?>
            \\<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            \\<plist version="1.0">
            \\<dict>
            \\	<key>ProductBuildVersion</key>
            \\	<string>20A2408</string>
            \\	<key>ProductCopyright</key>
            \\	<string>1983-2020 Apple Inc.</string>
            \\	<key>ProductName</key>
            \\	<string>macOS</string>
            \\	<key>ProductUserVisibleVersion</key>
            \\	<string>11.0</string>
            \\	<key>ProductVersion</key>
            \\	<string>11.0</string>
            \\	<key>iOSSupportVersion</key>
            \\	<string>14.2</string>
            \\</dict>
            \\</plist>
            ,
            .{ .major = 11, .minor = 0, .patch = 0 },
        },
        .{
            \\<?xml version="1.0" encoding="UTF-8"?>
            \\<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            \\<plist version="1.0">
            \\<dict>
            \\	<key>ProductBuildVersion</key>
            \\	<string>20C63</string>
            \\	<key>ProductCopyright</key>
            \\	<string>1983-2020 Apple Inc.</string>
            \\	<key>ProductName</key>
            \\	<string>macOS</string>
            \\	<key>ProductUserVisibleVersion</key>
            \\	<string>11.1</string>
            \\	<key>ProductVersion</key>
            \\	<string>11.1</string>
            \\	<key>iOSSupportVersion</key>
            \\	<string>14.3</string>
            \\</dict>
            \\</plist>
            ,
            .{ .major = 11, .minor = 1, .patch = 0 },
        },
    };

    inline for (cases) |case| {
        const ver0 = try parseSystemVersion(case[0]);
        const ver1: std.SemanticVersion = case[1];
        try testing.expectEqual(@as(std.math.Order, .eq), ver0.order(ver1));
    }
}

pub fn detectNativeCpuAndFeatures() ?Target.Cpu {
    var cpu_family: std.c.CPUFAMILY = undefined;
    var len: usize = @sizeOf(std.c.CPUFAMILY);
    os.sysctlbynameZ("hw.cpufamily", &cpu_family, &len, null, 0) catch |err| switch (err) {
        error.NameTooLong => unreachable, // constant, known good value
        error.PermissionDenied => unreachable, // only when setting values,
        error.SystemResources => unreachable, // memory already on the stack
        error.UnknownName => unreachable, // constant, known good value
        error.Unexpected => unreachable, // EFAULT: stack should be safe, EISDIR/ENOTDIR: constant, known good value
    };

    const current_arch = builtin.cpu.arch;
    switch (current_arch) {
        .aarch64, .aarch64_be, .aarch64_32 => {
            const model = switch (cpu_family) {
                .ARM_FIRESTORM_ICESTORM => &Target.aarch64.cpu.apple_a14,
                .ARM_LIGHTNING_THUNDER => &Target.aarch64.cpu.apple_a13,
                .ARM_VORTEX_TEMPEST => &Target.aarch64.cpu.apple_a12,
                .ARM_MONSOON_MISTRAL => &Target.aarch64.cpu.apple_a11,
                .ARM_HURRICANE => &Target.aarch64.cpu.apple_a10,
                .ARM_TWISTER => &Target.aarch64.cpu.apple_a9,
                .ARM_TYPHOON => &Target.aarch64.cpu.apple_a8,
                .ARM_CYCLONE => &Target.aarch64.cpu.cyclone,
                else => return null,
            };

            return Target.Cpu{
                .arch = current_arch,
                .model = model,
                .features = model.features,
            };
        },
        else => {},
    }

    return null;
}
