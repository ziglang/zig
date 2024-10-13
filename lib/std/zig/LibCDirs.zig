libc_include_dir_list: []const []const u8,
libc_installation: ?*const LibCInstallation,
libc_framework_dir_list: []const []const u8,
sysroot: ?[]const u8,
darwin_sdk_layout: ?DarwinSdkLayout,

/// The filesystem layout of darwin SDK elements.
pub const DarwinSdkLayout = enum {
    /// macOS SDK layout: TOP { /usr/include, /usr/lib, /System/Library/Frameworks }.
    sdk,
    /// Shipped libc layout: TOP { /lib/libc/include,  /lib/libc/darwin, <NONE> }.
    vendored,
};

pub fn detect(
    arena: Allocator,
    zig_lib_dir: []const u8,
    target: std.Target,
    is_native_abi: bool,
    link_libc: bool,
    libc_installation: ?*const LibCInstallation,
) !LibCDirs {
    if (!link_libc) {
        return .{
            .libc_include_dir_list = &[0][]u8{},
            .libc_installation = null,
            .libc_framework_dir_list = &.{},
            .sysroot = null,
            .darwin_sdk_layout = null,
        };
    }

    if (libc_installation) |lci| {
        return detectFromInstallation(arena, target, lci);
    }

    // If linking system libraries and targeting the native abi, default to
    // using the system libc installation.
    if (is_native_abi and !target.isMinGW()) {
        const libc = try arena.create(LibCInstallation);
        libc.* = LibCInstallation.findNative(.{ .allocator = arena, .target = target }) catch |err| switch (err) {
            error.CCompilerExitCode,
            error.CCompilerCrashed,
            error.CCompilerCannotFindHeaders,
            error.UnableToSpawnCCompiler,
            error.DarwinSdkNotFound,
            => |e| {
                // We tried to integrate with the native system C compiler,
                // however, it is not installed. So we must rely on our bundled
                // libc files.
                if (std.zig.target.canBuildLibC(target)) {
                    return detectFromBuilding(arena, zig_lib_dir, target);
                }
                return e;
            },
            else => |e| return e,
        };
        return detectFromInstallation(arena, target, libc);
    }

    // If not linking system libraries, build and provide our own libc by
    // default if possible.
    if (std.zig.target.canBuildLibC(target)) {
        return detectFromBuilding(arena, zig_lib_dir, target);
    }

    // If zig can't build the libc for the target and we are targeting the
    // native abi, fall back to using the system libc installation.
    // On windows, instead of the native (mingw) abi, we want to check
    // for the MSVC abi as a fallback.
    const use_system_abi = if (builtin.os.tag == .windows)
        target.abi == .msvc or target.abi == .itanium
    else
        is_native_abi;

    if (use_system_abi) {
        const libc = try arena.create(LibCInstallation);
        libc.* = try LibCInstallation.findNative(.{ .allocator = arena, .verbose = true, .target = target });
        return detectFromInstallation(arena, target, libc);
    }

    return .{
        .libc_include_dir_list = &[0][]u8{},
        .libc_installation = null,
        .libc_framework_dir_list = &.{},
        .sysroot = null,
        .darwin_sdk_layout = null,
    };
}

fn detectFromInstallation(arena: Allocator, target: std.Target, lci: *const LibCInstallation) !LibCDirs {
    var list = try std.ArrayList([]const u8).initCapacity(arena, 5);
    var framework_list = std.ArrayList([]const u8).init(arena);

    list.appendAssumeCapacity(lci.include_dir.?);

    const is_redundant = std.mem.eql(u8, lci.sys_include_dir.?, lci.include_dir.?);
    if (!is_redundant) list.appendAssumeCapacity(lci.sys_include_dir.?);

    if (target.os.tag == .windows) {
        if (std.fs.path.dirname(lci.sys_include_dir.?)) |sys_include_dir_parent| {
            // This include path will only exist when the optional "Desktop development with C++"
            // is installed. It contains headers, .rc files, and resources. It is especially
            // necessary when working with Windows resources.
            const atlmfc_dir = try std.fs.path.join(arena, &[_][]const u8{ sys_include_dir_parent, "atlmfc", "include" });
            list.appendAssumeCapacity(atlmfc_dir);
        }
        if (std.fs.path.dirname(lci.include_dir.?)) |include_dir_parent| {
            const um_dir = try std.fs.path.join(arena, &[_][]const u8{ include_dir_parent, "um" });
            list.appendAssumeCapacity(um_dir);

            const shared_dir = try std.fs.path.join(arena, &[_][]const u8{ include_dir_parent, "shared" });
            list.appendAssumeCapacity(shared_dir);
        }
    }
    if (target.os.tag == .haiku) {
        const include_dir_path = lci.include_dir orelse return error.LibCInstallationNotAvailable;
        const os_dir = try std.fs.path.join(arena, &[_][]const u8{ include_dir_path, "os" });
        list.appendAssumeCapacity(os_dir);
        // Errors.h
        const os_support_dir = try std.fs.path.join(arena, &[_][]const u8{ include_dir_path, "os/support" });
        list.appendAssumeCapacity(os_support_dir);

        const config_dir = try std.fs.path.join(arena, &[_][]const u8{ include_dir_path, "config" });
        list.appendAssumeCapacity(config_dir);
    }

    var sysroot: ?[]const u8 = null;

    if (target.isDarwin()) d: {
        const down1 = std.fs.path.dirname(lci.sys_include_dir.?) orelse break :d;
        const down2 = std.fs.path.dirname(down1) orelse break :d;
        try framework_list.append(try std.fs.path.join(arena, &.{ down2, "System", "Library", "Frameworks" }));
        sysroot = down2;
    }

    return .{
        .libc_include_dir_list = list.items,
        .libc_installation = lci,
        .libc_framework_dir_list = framework_list.items,
        .sysroot = sysroot,
        .darwin_sdk_layout = if (sysroot == null) null else .sdk,
    };
}

pub fn detectFromBuilding(
    arena: Allocator,
    zig_lib_dir: []const u8,
    target: std.Target,
) !LibCDirs {
    const s = std.fs.path.sep_str;

    if (target.isDarwin()) {
        const list = try arena.alloc([]const u8, 1);
        list[0] = try std.fmt.allocPrint(
            arena,
            "{s}" ++ s ++ "libc" ++ s ++ "include" ++ s ++ "any-macos-any",
            .{zig_lib_dir},
        );
        return .{
            .libc_include_dir_list = list,
            .libc_installation = null,
            .libc_framework_dir_list = &.{},
            .sysroot = null,
            .darwin_sdk_layout = .vendored,
        };
    }

    const generic_name = libCGenericName(target);
    // Some architectures are handled by the same set of headers.
    const arch_name = if (target.abi.isMusl())
        std.zig.target.muslArchNameHeaders(target.cpu.arch)
    else if (target.cpu.arch.isThumb())
        // ARM headers are valid for Thumb too.
        switch (target.cpu.arch) {
            .thumb => "arm",
            .thumbeb => "armeb",
            else => unreachable,
        }
    else
        @tagName(target.cpu.arch);
    const os_name = @tagName(target.os.tag);
    // Musl's headers are ABI-agnostic and so they all have the "musl" ABI name.
    const abi_name = if (target.abi.isMusl()) "musl" else @tagName(target.abi);
    const arch_include_dir = try std.fmt.allocPrint(
        arena,
        "{s}" ++ s ++ "libc" ++ s ++ "include" ++ s ++ "{s}-{s}-{s}",
        .{ zig_lib_dir, arch_name, os_name, abi_name },
    );
    const generic_include_dir = try std.fmt.allocPrint(
        arena,
        "{s}" ++ s ++ "libc" ++ s ++ "include" ++ s ++ "generic-{s}",
        .{ zig_lib_dir, generic_name },
    );
    const generic_arch_name = target.osArchName();
    const arch_os_include_dir = try std.fmt.allocPrint(
        arena,
        "{s}" ++ s ++ "libc" ++ s ++ "include" ++ s ++ "{s}-{s}-any",
        .{ zig_lib_dir, generic_arch_name, os_name },
    );
    const generic_os_include_dir = try std.fmt.allocPrint(
        arena,
        "{s}" ++ s ++ "libc" ++ s ++ "include" ++ s ++ "any-{s}-any",
        .{ zig_lib_dir, os_name },
    );

    const list = try arena.alloc([]const u8, 4);
    list[0] = arch_include_dir;
    list[1] = generic_include_dir;
    list[2] = arch_os_include_dir;
    list[3] = generic_os_include_dir;

    return .{
        .libc_include_dir_list = list,
        .libc_installation = null,
        .libc_framework_dir_list = &.{},
        .sysroot = null,
        .darwin_sdk_layout = .vendored,
    };
}

fn libCGenericName(target: std.Target) [:0]const u8 {
    switch (target.os.tag) {
        .windows => return "mingw",
        .macos, .ios, .tvos, .watchos, .visionos => return "darwin",
        else => {},
    }
    switch (target.abi) {
        .gnu,
        .gnuabin32,
        .gnuabi64,
        .gnueabi,
        .gnueabihf,
        .gnuf32,
        .gnusf,
        .gnux32,
        .gnuilp32,
        => return "glibc",
        .musl,
        .musleabi,
        .musleabihf,
        .muslx32,
        .none,
        .ohos,
        .ohoseabi,
        => return "musl",
        .code16,
        .eabi,
        .eabihf,
        .ilp32,
        .android,
        .androideabi,
        .msvc,
        .itanium,
        .cygnus,
        .simulator,
        .macabi,
        => unreachable,
    }
}

const LibCDirs = @This();
const builtin = @import("builtin");
const std = @import("../std.zig");
const LibCInstallation = std.zig.LibCInstallation;
const Allocator = std.mem.Allocator;
