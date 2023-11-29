/// Default implicit entrypoint symbol name.
pub const default_entry_point: []const u8 = "_main";

/// Default path to dyld.
pub const default_dyld_path: [*:0]const u8 = "/usr/lib/dyld";

fn calcInstallNameLen(cmd_size: u64, name: []const u8, assume_max_path_len: bool) u64 {
    const darwin_path_max = 1024;
    const name_len = if (assume_max_path_len) darwin_path_max else name.len + 1;
    return mem.alignForward(u64, cmd_size + name_len, @alignOf(u64));
}

const CalcLCsSizeCtx = struct {
    segments: []const macho.segment_command_64,
    dylibs: []const Dylib,
    referenced_dylibs: []u16,
    wants_function_starts: bool = true,
};

fn calcLCsSize(gpa: Allocator, options: *const link.Options, ctx: CalcLCsSizeCtx, assume_max_path_len: bool) !u32 {
    var has_text_segment: bool = false;
    var sizeofcmds: u64 = 0;
    for (ctx.segments) |seg| {
        sizeofcmds += seg.nsects * @sizeOf(macho.section_64) + @sizeOf(macho.segment_command_64);
        if (mem.eql(u8, seg.segName(), "__TEXT")) {
            has_text_segment = true;
        }
    }

    // LC_DYLD_INFO_ONLY
    sizeofcmds += @sizeOf(macho.dyld_info_command);
    // LC_FUNCTION_STARTS
    if (has_text_segment and ctx.wants_function_starts) {
        sizeofcmds += @sizeOf(macho.linkedit_data_command);
    }
    // LC_DATA_IN_CODE
    sizeofcmds += @sizeOf(macho.linkedit_data_command);
    // LC_SYMTAB
    sizeofcmds += @sizeOf(macho.symtab_command);
    // LC_DYSYMTAB
    sizeofcmds += @sizeOf(macho.dysymtab_command);
    // LC_LOAD_DYLINKER
    sizeofcmds += calcInstallNameLen(
        @sizeOf(macho.dylinker_command),
        mem.sliceTo(default_dyld_path, 0),
        false,
    );
    // LC_MAIN
    if (options.output_mode == .Exe) {
        sizeofcmds += @sizeOf(macho.entry_point_command);
    }
    // LC_ID_DYLIB
    if (options.output_mode == .Lib and options.link_mode == .Dynamic) {
        sizeofcmds += blk: {
            const emit = options.emit.?;
            const install_name = options.install_name orelse try emit.directory.join(gpa, &.{emit.sub_path});
            defer if (options.install_name == null) gpa.free(install_name);
            break :blk calcInstallNameLen(
                @sizeOf(macho.dylib_command),
                install_name,
                assume_max_path_len,
            );
        };
    }
    // LC_RPATH
    {
        var it = RpathIterator.init(gpa, options.rpath_list);
        defer it.deinit();
        while (try it.next()) |rpath| {
            sizeofcmds += calcInstallNameLen(
                @sizeOf(macho.rpath_command),
                rpath,
                assume_max_path_len,
            );
        }
    }
    // LC_SOURCE_VERSION
    sizeofcmds += @sizeOf(macho.source_version_command);
    // LC_BUILD_VERSION or LC_VERSION_MIN_ or nothing
    {
        const platform = Platform.fromTarget(options.target);
        if (platform.isBuildVersionCompatible()) {
            // LC_BUILD_VERSION
            sizeofcmds += @sizeOf(macho.build_version_command) + @sizeOf(macho.build_tool_version);
        } else if (platform.isVersionMinCompatible()) {
            // LC_VERSION_MIN_
            sizeofcmds += @sizeOf(macho.version_min_command);
        }
    }
    // LC_UUID
    sizeofcmds += @sizeOf(macho.uuid_command);
    // LC_LOAD_DYLIB
    for (ctx.referenced_dylibs) |id| {
        const dylib = ctx.dylibs[id];
        const dylib_id = dylib.id orelse unreachable;
        sizeofcmds += calcInstallNameLen(
            @sizeOf(macho.dylib_command),
            dylib_id.name,
            assume_max_path_len,
        );
    }
    // LC_CODE_SIGNATURE
    if (MachO.requiresCodeSignature(options)) {
        sizeofcmds += @sizeOf(macho.linkedit_data_command);
    }

    return @as(u32, @intCast(sizeofcmds));
}

pub fn calcMinHeaderPad(gpa: Allocator, options: *const link.Options, ctx: CalcLCsSizeCtx) !u64 {
    var padding: u32 = (try calcLCsSize(gpa, options, ctx, false)) + (options.headerpad_size orelse 0);
    log.debug("minimum requested headerpad size 0x{x}", .{padding + @sizeOf(macho.mach_header_64)});

    if (options.headerpad_max_install_names) {
        const min_headerpad_size: u32 = try calcLCsSize(gpa, options, ctx, true);
        log.debug("headerpad_max_install_names minimum headerpad size 0x{x}", .{
            min_headerpad_size + @sizeOf(macho.mach_header_64),
        });
        padding = @max(padding, min_headerpad_size);
    }

    const offset = @sizeOf(macho.mach_header_64) + padding;
    log.debug("actual headerpad size 0x{x}", .{offset});

    return offset;
}

pub fn calcNumOfLCs(lc_buffer: []const u8) u32 {
    var ncmds: u32 = 0;
    var pos: usize = 0;
    while (true) {
        if (pos >= lc_buffer.len) break;
        const cmd = @as(*align(1) const macho.load_command, @ptrCast(lc_buffer.ptr + pos)).*;
        ncmds += 1;
        pos += cmd.cmdsize;
    }
    return ncmds;
}

pub fn writeDylinkerLC(lc_writer: anytype) !void {
    const name_len = mem.sliceTo(default_dyld_path, 0).len;
    const cmdsize = @as(u32, @intCast(mem.alignForward(
        u64,
        @sizeOf(macho.dylinker_command) + name_len,
        @sizeOf(u64),
    )));
    try lc_writer.writeStruct(macho.dylinker_command{
        .cmd = .LOAD_DYLINKER,
        .cmdsize = cmdsize,
        .name = @sizeOf(macho.dylinker_command),
    });
    try lc_writer.writeAll(mem.sliceTo(default_dyld_path, 0));
    const padding = cmdsize - @sizeOf(macho.dylinker_command) - name_len;
    if (padding > 0) {
        try lc_writer.writeByteNTimes(0, padding);
    }
}

const WriteDylibLCCtx = struct {
    cmd: macho.LC,
    name: []const u8,
    timestamp: u32 = 2,
    current_version: u32 = 0x10000,
    compatibility_version: u32 = 0x10000,
};

fn writeDylibLC(ctx: WriteDylibLCCtx, lc_writer: anytype) !void {
    const name_len = ctx.name.len + 1;
    const cmdsize = @as(u32, @intCast(mem.alignForward(
        u64,
        @sizeOf(macho.dylib_command) + name_len,
        @sizeOf(u64),
    )));
    try lc_writer.writeStruct(macho.dylib_command{
        .cmd = ctx.cmd,
        .cmdsize = cmdsize,
        .dylib = .{
            .name = @sizeOf(macho.dylib_command),
            .timestamp = ctx.timestamp,
            .current_version = ctx.current_version,
            .compatibility_version = ctx.compatibility_version,
        },
    });
    try lc_writer.writeAll(ctx.name);
    try lc_writer.writeByte(0);
    const padding = cmdsize - @sizeOf(macho.dylib_command) - name_len;
    if (padding > 0) {
        try lc_writer.writeByteNTimes(0, padding);
    }
}

pub fn writeDylibIdLC(gpa: Allocator, options: *const link.Options, lc_writer: anytype) !void {
    assert(options.output_mode == .Lib and options.link_mode == .Dynamic);
    const emit = options.emit.?;
    const install_name = options.install_name orelse try emit.directory.join(gpa, &.{emit.sub_path});
    defer if (options.install_name == null) gpa.free(install_name);
    const curr = options.version orelse std.SemanticVersion{
        .major = 1,
        .minor = 0,
        .patch = 0,
    };
    const compat = options.compatibility_version orelse std.SemanticVersion{
        .major = 1,
        .minor = 0,
        .patch = 0,
    };
    try writeDylibLC(.{
        .cmd = .ID_DYLIB,
        .name = install_name,
        .current_version = @as(u32, @intCast(curr.major << 16 | curr.minor << 8 | curr.patch)),
        .compatibility_version = @as(u32, @intCast(compat.major << 16 | compat.minor << 8 | compat.patch)),
    }, lc_writer);
}

const RpathIterator = struct {
    buffer: []const []const u8,
    table: std.StringHashMap(void),
    count: usize = 0,

    fn init(gpa: Allocator, rpaths: []const []const u8) RpathIterator {
        return .{ .buffer = rpaths, .table = std.StringHashMap(void).init(gpa) };
    }

    fn deinit(it: *RpathIterator) void {
        it.table.deinit();
    }

    fn next(it: *RpathIterator) !?[]const u8 {
        while (true) {
            if (it.count >= it.buffer.len) return null;
            const rpath = it.buffer[it.count];
            it.count += 1;
            const gop = try it.table.getOrPut(rpath);
            if (gop.found_existing) continue;
            return rpath;
        }
    }
};

pub fn writeRpathLCs(gpa: Allocator, options: *const link.Options, lc_writer: anytype) !void {
    var it = RpathIterator.init(gpa, options.rpath_list);
    defer it.deinit();

    while (try it.next()) |rpath| {
        const rpath_len = rpath.len + 1;
        const cmdsize = @as(u32, @intCast(mem.alignForward(
            u64,
            @sizeOf(macho.rpath_command) + rpath_len,
            @sizeOf(u64),
        )));
        try lc_writer.writeStruct(macho.rpath_command{
            .cmdsize = cmdsize,
            .path = @sizeOf(macho.rpath_command),
        });
        try lc_writer.writeAll(rpath);
        try lc_writer.writeByte(0);
        const padding = cmdsize - @sizeOf(macho.rpath_command) - rpath_len;
        if (padding > 0) {
            try lc_writer.writeByteNTimes(0, padding);
        }
    }
}

pub fn writeVersionMinLC(platform: Platform, sdk_version: ?std.SemanticVersion, lc_writer: anytype) !void {
    const cmd: macho.LC = switch (platform.os_tag) {
        .macos => .VERSION_MIN_MACOSX,
        .ios => .VERSION_MIN_IPHONEOS,
        .tvos => .VERSION_MIN_TVOS,
        .watchos => .VERSION_MIN_WATCHOS,
        else => unreachable,
    };
    try lc_writer.writeAll(mem.asBytes(&macho.version_min_command{
        .cmd = cmd,
        .version = platform.toAppleVersion(),
        .sdk = if (sdk_version) |ver| semanticVersionToAppleVersion(ver) else platform.toAppleVersion(),
    }));
}

pub fn writeBuildVersionLC(platform: Platform, sdk_version: ?std.SemanticVersion, lc_writer: anytype) !void {
    const cmdsize = @sizeOf(macho.build_version_command) + @sizeOf(macho.build_tool_version);
    try lc_writer.writeStruct(macho.build_version_command{
        .cmdsize = cmdsize,
        .platform = platform.toApplePlatform(),
        .minos = platform.toAppleVersion(),
        .sdk = if (sdk_version) |ver| semanticVersionToAppleVersion(ver) else platform.toAppleVersion(),
        .ntools = 1,
    });
    try lc_writer.writeAll(mem.asBytes(&macho.build_tool_version{
        .tool = .ZIG,
        .version = 0x0,
    }));
}

pub fn writeLoadDylibLCs(dylibs: []const Dylib, referenced: []u16, lc_writer: anytype) !void {
    for (referenced) |index| {
        const dylib = dylibs[index];
        const dylib_id = dylib.id orelse unreachable;
        try writeDylibLC(.{
            .cmd = if (dylib.weak) .LOAD_WEAK_DYLIB else .LOAD_DYLIB,
            .name = dylib_id.name,
            .timestamp = dylib_id.timestamp,
            .current_version = dylib_id.current_version,
            .compatibility_version = dylib_id.compatibility_version,
        }, lc_writer);
    }
}

pub const Platform = struct {
    os_tag: std.Target.Os.Tag,
    abi: std.Target.Abi,
    version: std.SemanticVersion,

    /// Using Apple's ld64 as our blueprint, `min_version` as well as `sdk_version` are set to
    /// the extracted minimum platform version.
    pub fn fromLoadCommand(lc: macho.LoadCommandIterator.LoadCommand) Platform {
        switch (lc.cmd()) {
            .BUILD_VERSION => {
                const cmd = lc.cast(macho.build_version_command).?;
                return .{
                    .os_tag = switch (cmd.platform) {
                        .MACOS => .macos,
                        .IOS, .IOSSIMULATOR => .ios,
                        .TVOS, .TVOSSIMULATOR => .tvos,
                        .WATCHOS, .WATCHOSSIMULATOR => .watchos,
                        else => @panic("TODO"),
                    },
                    .abi = switch (cmd.platform) {
                        .IOSSIMULATOR,
                        .TVOSSIMULATOR,
                        .WATCHOSSIMULATOR,
                        => .simulator,
                        else => .none,
                    },
                    .version = appleVersionToSemanticVersion(cmd.minos),
                };
            },
            .VERSION_MIN_MACOSX,
            .VERSION_MIN_IPHONEOS,
            .VERSION_MIN_TVOS,
            .VERSION_MIN_WATCHOS,
            => {
                const cmd = lc.cast(macho.version_min_command).?;
                return .{
                    .os_tag = switch (lc.cmd()) {
                        .VERSION_MIN_MACOSX => .macos,
                        .VERSION_MIN_IPHONEOS => .ios,
                        .VERSION_MIN_TVOS => .tvos,
                        .VERSION_MIN_WATCHOS => .watchos,
                        else => unreachable,
                    },
                    .abi = .none,
                    .version = appleVersionToSemanticVersion(cmd.version),
                };
            },
            else => unreachable,
        }
    }

    pub fn fromTarget(target: std.Target) Platform {
        return .{
            .os_tag = target.os.tag,
            .abi = target.abi,
            .version = target.os.version_range.semver.min,
        };
    }

    pub fn toAppleVersion(plat: Platform) u32 {
        return semanticVersionToAppleVersion(plat.version);
    }

    pub fn toApplePlatform(plat: Platform) macho.PLATFORM {
        return switch (plat.os_tag) {
            .macos => .MACOS,
            .ios => if (plat.abi == .simulator) .IOSSIMULATOR else .IOS,
            .tvos => if (plat.abi == .simulator) .TVOSSIMULATOR else .TVOS,
            .watchos => if (plat.abi == .simulator) .WATCHOSSIMULATOR else .WATCHOS,
            else => unreachable,
        };
    }

    pub fn isBuildVersionCompatible(plat: Platform) bool {
        inline for (supported_platforms) |sup_plat| {
            if (sup_plat[0] == plat.os_tag and sup_plat[1] == plat.abi) {
                return sup_plat[2] <= plat.toAppleVersion();
            }
        }
        return false;
    }

    pub fn isVersionMinCompatible(plat: Platform) bool {
        inline for (supported_platforms) |sup_plat| {
            if (sup_plat[0] == plat.os_tag and sup_plat[1] == plat.abi) {
                return sup_plat[3] <= plat.toAppleVersion();
            }
        }
        return false;
    }

    pub fn fmtTarget(plat: Platform, cpu_arch: std.Target.Cpu.Arch) std.fmt.Formatter(formatTarget) {
        return .{ .data = .{ .platform = plat, .cpu_arch = cpu_arch } };
    }

    const FmtCtx = struct {
        platform: Platform,
        cpu_arch: std.Target.Cpu.Arch,
    };

    pub fn formatTarget(
        ctx: FmtCtx,
        comptime unused_fmt_string: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = unused_fmt_string;
        _ = options;
        try writer.print("{s}-{s}", .{ @tagName(ctx.cpu_arch), @tagName(ctx.platform.os_tag) });
        if (ctx.platform.abi != .none) {
            try writer.print("-{s}", .{@tagName(ctx.platform.abi)});
        }
    }

    /// Caller owns the memory.
    pub fn allocPrintTarget(plat: Platform, gpa: Allocator, cpu_arch: std.Target.Cpu.Arch) error{OutOfMemory}![]u8 {
        var buffer = std.ArrayList(u8).init(gpa);
        defer buffer.deinit();
        try buffer.writer().print("{}", .{plat.fmtTarget(cpu_arch)});
        return buffer.toOwnedSlice();
    }

    pub fn eqlTarget(plat: Platform, other: Platform) bool {
        return plat.os_tag == other.os_tag and plat.abi == other.abi;
    }
};

const SupportedPlatforms = struct {
    std.Target.Os.Tag,
    std.Target.Abi,
    u32, // Min platform version for which to emit LC_BUILD_VERSION
    u32, // Min supported platform version
};

// Source: https://github.com/apple-oss-distributions/ld64/blob/59a99ab60399c5e6c49e6945a9e1049c42b71135/src/ld/PlatformSupport.cpp#L52
// zig fmt: off
const supported_platforms = [_]SupportedPlatforms{
    .{ .macos,   .none,      0xA0E00, 0xA0800 },
    .{ .ios,     .none,      0xC0000, 0x70000 },
    .{ .tvos,    .none,      0xC0000, 0x70000 },
    .{ .watchos, .none,      0x50000, 0x20000 },
    .{ .ios,     .simulator, 0xD0000, 0x80000 },
    .{ .tvos,    .simulator, 0xD0000, 0x80000 },
    .{ .watchos, .simulator, 0x60000, 0x20000 },
};
// zig fmt: on

inline fn semanticVersionToAppleVersion(version: std.SemanticVersion) u32 {
    const major = version.major;
    const minor = version.minor;
    const patch = version.patch;
    return (@as(u32, @intCast(major)) << 16) | (@as(u32, @intCast(minor)) << 8) | @as(u32, @intCast(patch));
}

pub inline fn appleVersionToSemanticVersion(version: u32) std.SemanticVersion {
    return .{
        .major = @as(u16, @truncate(version >> 16)),
        .minor = @as(u8, @truncate(version >> 8)),
        .patch = @as(u8, @truncate(version)),
    };
}

pub fn inferSdkVersion(gpa: Allocator, comp: *const Compilation) ?std.SemanticVersion {
    var arena_allocator = std.heap.ArenaAllocator.init(gpa);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    const options = comp.bin_file.options;

    const sdk_layout = options.darwin_sdk_layout orelse return null;
    const sdk_dir = switch (sdk_layout) {
        .sdk => options.sysroot.?,
        .vendored => std.fs.path.join(arena, &.{ comp.zig_lib_directory.path.?, "libc", "darwin" }) catch return null,
    };
    if (readSdkVersionFromSettings(arena, sdk_dir)) |ver| {
        return parseSdkVersion(ver);
    } else |_| {
        // Read from settings should always succeed when vendored.
        if (sdk_layout == .vendored) @panic("zig installation bug: unable to parse SDK version");
    }

    // infer from pathname
    const stem = std.fs.path.stem(sdk_dir);
    const start = for (stem, 0..) |c, i| {
        if (std.ascii.isDigit(c)) break i;
    } else stem.len;
    const end = for (stem[start..], start..) |c, i| {
        if (std.ascii.isDigit(c) or c == '.') continue;
        break i;
    } else stem.len;
    return parseSdkVersion(stem[start..end]);
}

// Official Apple SDKs ship with a `SDKSettings.json` located at the top of SDK fs layout.
// Use property `MinimalDisplayName` to determine version.
// The file/property is also available with vendored libc.
fn readSdkVersionFromSettings(arena: Allocator, dir: []const u8) ![]const u8 {
    const sdk_path = try std.fs.path.join(arena, &.{ dir, "SDKSettings.json" });
    const contents = try std.fs.cwd().readFileAlloc(arena, sdk_path, std.math.maxInt(u16));
    const parsed = try std.json.parseFromSlice(std.json.Value, arena, contents, .{});
    if (parsed.value.object.get("MinimalDisplayName")) |ver| return ver.string;
    return error.SdkVersionFailure;
}

// Versions reported by Apple aren't exactly semantically valid as they usually omit
// the patch component, so we parse SDK value by hand.
fn parseSdkVersion(raw: []const u8) ?std.SemanticVersion {
    var parsed: std.SemanticVersion = .{
        .major = 0,
        .minor = 0,
        .patch = 0,
    };

    const parseNext = struct {
        fn parseNext(it: anytype) ?u16 {
            const nn = it.next() orelse return null;
            return std.fmt.parseInt(u16, nn, 10) catch null;
        }
    }.parseNext;

    var it = std.mem.splitAny(u8, raw, ".");
    parsed.major = parseNext(&it) orelse return null;
    parsed.minor = parseNext(&it) orelse return null;
    parsed.patch = parseNext(&it) orelse 0;
    return parsed;
}

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

fn testParseSdkVersionSuccess(exp: std.SemanticVersion, raw: []const u8) !void {
    const maybe_ver = parseSdkVersion(raw);
    try expect(maybe_ver != null);
    const ver = maybe_ver.?;
    try expectEqual(exp.major, ver.major);
    try expectEqual(exp.minor, ver.minor);
    try expectEqual(exp.patch, ver.patch);
}

test "parseSdkVersion" {
    try testParseSdkVersionSuccess(.{ .major = 13, .minor = 4, .patch = 0 }, "13.4");
    try testParseSdkVersionSuccess(.{ .major = 13, .minor = 4, .patch = 1 }, "13.4.1");
    try testParseSdkVersionSuccess(.{ .major = 11, .minor = 15, .patch = 0 }, "11.15");

    try expect(parseSdkVersion("11") == null);
}

const std = @import("std");
const assert = std.debug.assert;
const link = @import("../../link.zig");
const log = std.log.scoped(.link);
const macho = std.macho;
const mem = std.mem;

const Allocator = mem.Allocator;
const Dylib = @import("Dylib.zig");
const MachO = @import("../MachO.zig");
const Compilation = @import("../../Compilation.zig");
