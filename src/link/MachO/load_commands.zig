const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.link);
const macho = std.macho;
const mem = std.mem;

const Allocator = mem.Allocator;
const DebugSymbols = @import("DebugSymbols.zig");
const Dylib = @import("Dylib.zig");
const MachO = @import("../MachO.zig");

pub const default_dyld_path: [*:0]const u8 = "/usr/lib/dyld";

fn calcInstallNameLen(cmd_size: u64, name: []const u8, assume_max_path_len: bool) u64 {
    const darwin_path_max = 1024;
    const name_len = if (assume_max_path_len) darwin_path_max else name.len + 1;
    return mem.alignForward(u64, cmd_size + name_len, @alignOf(u64));
}

pub fn calcLoadCommandsSize(macho_file: *MachO, assume_max_path_len: bool) !u32 {
    const comp = macho_file.base.comp;
    const gpa = comp.gpa;

    var sizeofcmds: u64 = 0;

    // LC_SEGMENT_64
    sizeofcmds += @sizeOf(macho.segment_command_64) * macho_file.segments.items.len;
    for (macho_file.segments.items) |seg| {
        sizeofcmds += seg.nsects * @sizeOf(macho.section_64);
    }

    // LC_DYLD_INFO_ONLY
    sizeofcmds += @sizeOf(macho.dyld_info_command);
    // LC_FUNCTION_STARTS
    sizeofcmds += @sizeOf(macho.linkedit_data_command);
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
    if (!macho_file.base.isDynLib()) {
        sizeofcmds += @sizeOf(macho.entry_point_command);
    }
    // LC_ID_DYLIB
    if (macho_file.base.isDynLib()) {
        const emit = macho_file.base.emit;
        const install_name = macho_file.install_name orelse
            try emit.root_dir.join(gpa, &.{emit.sub_path});
        defer if (macho_file.install_name == null) gpa.free(install_name);
        sizeofcmds += calcInstallNameLen(
            @sizeOf(macho.dylib_command),
            install_name,
            assume_max_path_len,
        );
    }
    // LC_RPATH
    {
        for (macho_file.rpath_list) |rpath| {
            sizeofcmds += calcInstallNameLen(
                @sizeOf(macho.rpath_command),
                rpath,
                assume_max_path_len,
            );
        }

        if (comp.config.any_sanitize_thread) {
            const path = try comp.tsan_lib.?.full_object_path.toString(gpa);
            defer gpa.free(path);
            const rpath = std.fs.path.dirname(path) orelse ".";
            sizeofcmds += calcInstallNameLen(
                @sizeOf(macho.rpath_command),
                rpath,
                assume_max_path_len,
            );
        }
    }
    // LC_SOURCE_VERSION
    sizeofcmds += @sizeOf(macho.source_version_command);
    if (macho_file.platform.isBuildVersionCompatible()) {
        // LC_BUILD_VERSION
        sizeofcmds += @sizeOf(macho.build_version_command) + @sizeOf(macho.build_tool_version);
    } else {
        // LC_VERSION_MIN_*
        sizeofcmds += @sizeOf(macho.version_min_command);
    }
    // LC_UUID
    sizeofcmds += @sizeOf(macho.uuid_command);
    // LC_LOAD_DYLIB
    for (macho_file.dylibs.items) |index| {
        const dylib = macho_file.getFile(index).?.dylib;
        assert(dylib.isAlive(macho_file));
        const dylib_id = dylib.id.?;
        sizeofcmds += calcInstallNameLen(
            @sizeOf(macho.dylib_command),
            dylib_id.name,
            assume_max_path_len,
        );
    }
    // LC_CODE_SIGNATURE
    if (macho_file.requiresCodeSig()) {
        sizeofcmds += @sizeOf(macho.linkedit_data_command);
    }

    return @as(u32, @intCast(sizeofcmds));
}

pub fn calcLoadCommandsSizeDsym(macho_file: *MachO, dsym: *const DebugSymbols) u32 {
    var sizeofcmds: u64 = 0;

    // LC_SEGMENT_64
    sizeofcmds += @sizeOf(macho.segment_command_64) * (macho_file.segments.items.len - 1);
    for (macho_file.segments.items) |seg| {
        sizeofcmds += seg.nsects * @sizeOf(macho.section_64);
    }
    sizeofcmds += @sizeOf(macho.segment_command_64) * dsym.segments.items.len;
    for (dsym.segments.items) |seg| {
        sizeofcmds += seg.nsects * @sizeOf(macho.section_64);
    }

    // LC_SYMTAB
    sizeofcmds += @sizeOf(macho.symtab_command);
    // LC_UUID
    sizeofcmds += @sizeOf(macho.uuid_command);

    return @as(u32, @intCast(sizeofcmds));
}

pub fn calcLoadCommandsSizeObject(macho_file: *MachO) u32 {
    var sizeofcmds: u64 = 0;

    // LC_SEGMENT_64
    {
        assert(macho_file.segments.items.len == 1);
        sizeofcmds += @sizeOf(macho.segment_command_64);
        const seg = macho_file.segments.items[0];
        sizeofcmds += seg.nsects * @sizeOf(macho.section_64);
    }

    // LC_DATA_IN_CODE
    sizeofcmds += @sizeOf(macho.linkedit_data_command);
    // LC_SYMTAB
    sizeofcmds += @sizeOf(macho.symtab_command);
    // LC_DYSYMTAB
    sizeofcmds += @sizeOf(macho.dysymtab_command);

    if (macho_file.platform.isBuildVersionCompatible()) {
        // LC_BUILD_VERSION
        sizeofcmds += @sizeOf(macho.build_version_command) + @sizeOf(macho.build_tool_version);
    } else {
        // LC_VERSION_MIN_*
        sizeofcmds += @sizeOf(macho.version_min_command);
    }

    return @as(u32, @intCast(sizeofcmds));
}

pub fn calcMinHeaderPadSize(macho_file: *MachO) !u32 {
    var padding: u32 = (try calcLoadCommandsSize(macho_file, false)) + (macho_file.headerpad_size orelse 0);
    log.debug("minimum requested headerpad size 0x{x}", .{padding + @sizeOf(macho.mach_header_64)});

    if (macho_file.headerpad_max_install_names) {
        const min_headerpad_size: u32 = try calcLoadCommandsSize(macho_file, true);
        log.debug("headerpad_max_install_names minimum headerpad size 0x{x}", .{
            min_headerpad_size + @sizeOf(macho.mach_header_64),
        });
        padding = @max(padding, min_headerpad_size);
    }

    const offset = @sizeOf(macho.mach_header_64) + padding;
    log.debug("actual headerpad size 0x{x}", .{offset});

    return offset;
}

pub fn writeDylinkerLC(writer: anytype) !void {
    const name_len = mem.sliceTo(default_dyld_path, 0).len;
    const cmdsize = @as(u32, @intCast(mem.alignForward(
        u64,
        @sizeOf(macho.dylinker_command) + name_len,
        @sizeOf(u64),
    )));
    try writer.writeStruct(macho.dylinker_command{
        .cmd = .LOAD_DYLINKER,
        .cmdsize = cmdsize,
        .name = @sizeOf(macho.dylinker_command),
    });
    try writer.writeAll(mem.sliceTo(default_dyld_path, 0));
    const padding = cmdsize - @sizeOf(macho.dylinker_command) - name_len;
    if (padding > 0) {
        try writer.writeByteNTimes(0, padding);
    }
}

const WriteDylibLCCtx = struct {
    cmd: macho.LC,
    name: []const u8,
    timestamp: u32 = 2,
    current_version: u32 = 0x10000,
    compatibility_version: u32 = 0x10000,
};

pub fn writeDylibLC(ctx: WriteDylibLCCtx, writer: anytype) !void {
    const name_len = ctx.name.len + 1;
    const cmdsize = @as(u32, @intCast(mem.alignForward(
        u64,
        @sizeOf(macho.dylib_command) + name_len,
        @sizeOf(u64),
    )));
    try writer.writeStruct(macho.dylib_command{
        .cmd = ctx.cmd,
        .cmdsize = cmdsize,
        .dylib = .{
            .name = @sizeOf(macho.dylib_command),
            .timestamp = ctx.timestamp,
            .current_version = ctx.current_version,
            .compatibility_version = ctx.compatibility_version,
        },
    });
    try writer.writeAll(ctx.name);
    try writer.writeByte(0);
    const padding = cmdsize - @sizeOf(macho.dylib_command) - name_len;
    if (padding > 0) {
        try writer.writeByteNTimes(0, padding);
    }
}

pub fn writeDylibIdLC(macho_file: *MachO, writer: anytype) !void {
    const comp = macho_file.base.comp;
    const gpa = comp.gpa;
    assert(comp.config.output_mode == .Lib and comp.config.link_mode == .dynamic);
    const emit = macho_file.base.emit;
    const install_name = macho_file.install_name orelse
        try emit.root_dir.join(gpa, &.{emit.sub_path});
    defer if (macho_file.install_name == null) gpa.free(install_name);
    const curr = comp.version orelse std.SemanticVersion{
        .major = 1,
        .minor = 0,
        .patch = 0,
    };
    const compat = macho_file.compatibility_version orelse std.SemanticVersion{
        .major = 1,
        .minor = 0,
        .patch = 0,
    };
    try writeDylibLC(.{
        .cmd = .ID_DYLIB,
        .name = install_name,
        .current_version = @as(u32, @intCast(curr.major << 16 | curr.minor << 8 | curr.patch)),
        .compatibility_version = @as(u32, @intCast(compat.major << 16 | compat.minor << 8 | compat.patch)),
    }, writer);
}

pub fn writeRpathLC(rpath: []const u8, writer: anytype) !void {
    const rpath_len = rpath.len + 1;
    const cmdsize = @as(u32, @intCast(mem.alignForward(
        u64,
        @sizeOf(macho.rpath_command) + rpath_len,
        @sizeOf(u64),
    )));
    try writer.writeStruct(macho.rpath_command{
        .cmdsize = cmdsize,
        .path = @sizeOf(macho.rpath_command),
    });
    try writer.writeAll(rpath);
    try writer.writeByte(0);
    const padding = cmdsize - @sizeOf(macho.rpath_command) - rpath_len;
    if (padding > 0) {
        try writer.writeByteNTimes(0, padding);
    }
}

pub fn writeVersionMinLC(platform: MachO.Platform, sdk_version: ?std.SemanticVersion, writer: anytype) !void {
    const cmd: macho.LC = switch (platform.os_tag) {
        .macos => .VERSION_MIN_MACOSX,
        .ios => .VERSION_MIN_IPHONEOS,
        .tvos => .VERSION_MIN_TVOS,
        .watchos => .VERSION_MIN_WATCHOS,
        else => unreachable,
    };
    try writer.writeAll(mem.asBytes(&macho.version_min_command{
        .cmd = cmd,
        .version = platform.toAppleVersion(),
        .sdk = if (sdk_version) |ver|
            MachO.semanticVersionToAppleVersion(ver)
        else
            platform.toAppleVersion(),
    }));
}

pub fn writeBuildVersionLC(platform: MachO.Platform, sdk_version: ?std.SemanticVersion, writer: anytype) !void {
    const cmdsize = @sizeOf(macho.build_version_command) + @sizeOf(macho.build_tool_version);
    try writer.writeStruct(macho.build_version_command{
        .cmdsize = cmdsize,
        .platform = platform.toApplePlatform(),
        .minos = platform.toAppleVersion(),
        .sdk = if (sdk_version) |ver|
            MachO.semanticVersionToAppleVersion(ver)
        else
            platform.toAppleVersion(),
        .ntools = 1,
    });
    try writer.writeAll(mem.asBytes(&macho.build_tool_version{
        .tool = .ZIG,
        .version = 0x0,
    }));
}
