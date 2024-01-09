const std = @import("std");
const assert = std.debug.assert;
const log = std.log.scoped(.link);
const macho = std.macho;
const mem = std.mem;

const Allocator = mem.Allocator;
const Dylib = @import("Dylib.zig");
const MachO = @import("../MachO.zig");
const Options = @import("../MachO.zig").Options;

pub const default_dyld_path: [*:0]const u8 = "/usr/lib/dyld";

fn calcInstallNameLen(cmd_size: u64, name: []const u8, assume_max_path_len: bool) u64 {
    const darwin_path_max = 1024;
    const name_len = if (assume_max_path_len) darwin_path_max else name.len + 1;
    return mem.alignForward(u64, cmd_size + name_len, @alignOf(u64));
}

pub fn calcLoadCommandsSize(macho_file: *MachO, assume_max_path_len: bool) u32 {
    const options = &macho_file.options;
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
    if (!options.dylib) {
        sizeofcmds += @sizeOf(macho.entry_point_command);
    }
    // LC_ID_DYLIB
    if (options.dylib) {
        sizeofcmds += blk: {
            const emit = options.emit;
            const install_name = options.install_name orelse emit.sub_path;
            break :blk calcInstallNameLen(
                @sizeOf(macho.dylib_command),
                install_name,
                assume_max_path_len,
            );
        };
    }
    // LC_RPATH
    {
        for (options.rpath_list) |rpath| {
            sizeofcmds += calcInstallNameLen(
                @sizeOf(macho.rpath_command),
                rpath,
                assume_max_path_len,
            );
        }
    }
    // LC_SOURCE_VERSION
    sizeofcmds += @sizeOf(macho.source_version_command);
    if (options.platform) |platform| {
        if (platform.isBuildVersionCompatible()) {
            // LC_BUILD_VERSION
            sizeofcmds += @sizeOf(macho.build_version_command) + @sizeOf(macho.build_tool_version);
        } else {
            // LC_VERSION_MIN_*
            sizeofcmds += @sizeOf(macho.version_min_command);
        }
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

pub fn calcLoadCommandsSizeObject(macho_file: *MachO) u32 {
    const options = &macho_file.options;
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

    if (options.platform) |platform| {
        if (platform.isBuildVersionCompatible()) {
            // LC_BUILD_VERSION
            sizeofcmds += @sizeOf(macho.build_version_command) + @sizeOf(macho.build_tool_version);
        } else {
            // LC_VERSION_MIN_*
            sizeofcmds += @sizeOf(macho.version_min_command);
        }
    }

    return @as(u32, @intCast(sizeofcmds));
}

pub fn calcMinHeaderPadSize(macho_file: *MachO) u32 {
    const options = &macho_file.options;
    var padding: u32 = calcLoadCommandsSize(macho_file, false) + (options.headerpad orelse 0);
    log.debug("minimum requested headerpad size 0x{x}", .{padding + @sizeOf(macho.mach_header_64)});

    if (options.headerpad_max_install_names) {
        const min_headerpad_size: u32 = calcLoadCommandsSize(macho_file, true);
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

pub fn writeDylibIdLC(options: *const Options, writer: anytype) !void {
    assert(options.dylib);
    const emit = options.emit;
    const install_name = options.install_name orelse emit.sub_path;
    const curr = options.current_version orelse Options.Version.new(1, 0, 0);
    const compat = options.compatibility_version orelse Options.Version.new(1, 0, 0);
    try writeDylibLC(.{
        .cmd = .ID_DYLIB,
        .name = install_name,
        .current_version = curr.value,
        .compatibility_version = compat.value,
    }, writer);
}

pub fn writeRpathLCs(rpaths: []const []const u8, writer: anytype) !void {
    for (rpaths) |rpath| {
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
}

pub fn writeVersionMinLC(platform: Options.Platform, sdk_version: ?Options.Version, writer: anytype) !void {
    const cmd: macho.LC = switch (platform.platform) {
        .MACOS => .VERSION_MIN_MACOSX,
        .IOS, .IOSSIMULATOR => .VERSION_MIN_IPHONEOS,
        .TVOS, .TVOSSIMULATOR => .VERSION_MIN_TVOS,
        .WATCHOS, .WATCHOSSIMULATOR => .VERSION_MIN_WATCHOS,
        else => unreachable,
    };
    try writer.writeAll(mem.asBytes(&macho.version_min_command{
        .cmd = cmd,
        .version = platform.version.value,
        .sdk = if (sdk_version) |ver| ver.value else platform.version.value,
    }));
}

pub fn writeBuildVersionLC(platform: Options.Platform, sdk_version: ?Options.Version, writer: anytype) !void {
    const cmdsize = @sizeOf(macho.build_version_command) + @sizeOf(macho.build_tool_version);
    try writer.writeStruct(macho.build_version_command{
        .cmdsize = cmdsize,
        .platform = platform.platform,
        .minos = platform.version.value,
        .sdk = if (sdk_version) |ver| ver.value else platform.version.value,
        .ntools = 1,
    });
    try writer.writeAll(mem.asBytes(&macho.build_tool_version{
        .tool = @as(macho.TOOL, @enumFromInt(0x6)),
        .version = 0x0,
    }));
}
