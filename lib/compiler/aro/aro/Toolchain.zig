const std = @import("std");
const Driver = @import("Driver.zig");
const Compilation = @import("Compilation.zig");
const mem = std.mem;
const system_defaults = @import("system_defaults");
const target_util = @import("target.zig");
const Linux = @import("toolchains/Linux.zig");
const Multilib = @import("Driver/Multilib.zig");
const Filesystem = @import("Driver/Filesystem.zig").Filesystem;

pub const PathList = std.ArrayListUnmanaged([]const u8);

pub const RuntimeLibKind = enum {
    compiler_rt,
    libgcc,
};

pub const FileKind = enum {
    object,
    static,
    shared,
};

pub const LibGCCKind = enum {
    unspecified,
    static,
    shared,
};

pub const UnwindLibKind = enum {
    none,
    compiler_rt,
    libgcc,
};

const Inner = union(enum) {
    uninitialized,
    linux: Linux,
    unknown: void,

    fn deinit(self: *Inner, allocator: mem.Allocator) void {
        switch (self.*) {
            .linux => |*linux| linux.deinit(allocator),
            .uninitialized, .unknown => {},
        }
    }
};

const Toolchain = @This();

filesystem: Filesystem = .{ .real = {} },
driver: *Driver,
arena: mem.Allocator,

/// The list of toolchain specific path prefixes to search for libraries.
library_paths: PathList = .{},

/// The list of toolchain specific path prefixes to search for files.
file_paths: PathList = .{},

/// The list of toolchain specific path prefixes to search for programs.
program_paths: PathList = .{},

selected_multilib: Multilib = .{},

inner: Inner = .{ .uninitialized = {} },

pub fn getTarget(tc: *const Toolchain) std.Target {
    return tc.driver.comp.target;
}

fn getDefaultLinker(tc: *const Toolchain) []const u8 {
    return switch (tc.inner) {
        .uninitialized => unreachable,
        .linux => |linux| linux.getDefaultLinker(tc.getTarget()),
        .unknown => "ld",
    };
}

/// Call this after driver has finished parsing command line arguments to find the toolchain
pub fn discover(tc: *Toolchain) !void {
    if (tc.inner != .uninitialized) return;

    const target = tc.getTarget();
    tc.inner = switch (target.os.tag) {
        .elfiamcu,
        .linux,
        => if (target.cpu.arch == .hexagon)
            .{ .unknown = {} } // TODO
        else if (target.cpu.arch.isMIPS())
            .{ .unknown = {} } // TODO
        else if (target.cpu.arch.isPowerPC())
            .{ .unknown = {} } // TODO
        else if (target.cpu.arch == .ve)
            .{ .unknown = {} } // TODO
        else
            .{ .linux = .{} },
        else => .{ .unknown = {} }, // TODO
    };
    return switch (tc.inner) {
        .uninitialized => unreachable,
        .linux => |*linux| linux.discover(tc),
        .unknown => {},
    };
}

pub fn deinit(tc: *Toolchain) void {
    const gpa = tc.driver.comp.gpa;
    tc.inner.deinit(gpa);

    tc.library_paths.deinit(gpa);
    tc.file_paths.deinit(gpa);
    tc.program_paths.deinit(gpa);
}

/// Write linker path to `buf` and return a slice of it
pub fn getLinkerPath(tc: *const Toolchain, buf: []u8) ![]const u8 {
    // --ld-path= takes precedence over -fuse-ld= and specifies the executable
    // name. -B, COMPILER_PATH and PATH are consulted if the value does not
    // contain a path component separator.
    // -fuse-ld=lld can be used with --ld-path= to indicate that the binary
    // that --ld-path= points to is lld.
    const use_linker = tc.driver.use_linker orelse system_defaults.linker;

    if (tc.driver.linker_path) |ld_path| {
        var path = ld_path;
        if (path.len > 0) {
            if (std.fs.path.dirname(path) == null) {
                path = tc.getProgramPath(path, buf);
            }
            if (tc.filesystem.canExecute(path)) {
                return path;
            }
        }
        return tc.driver.fatal(
            "invalid linker name in argument '--ld-path={s}'",
            .{path},
        );
    }

    // If we're passed -fuse-ld= with no argument, or with the argument ld,
    // then use whatever the default system linker is.
    if (use_linker.len == 0 or mem.eql(u8, use_linker, "ld")) {
        const default = tc.getDefaultLinker();
        if (std.fs.path.isAbsolute(default)) return default;
        return tc.getProgramPath(default, buf);
    }

    // Extending -fuse-ld= to an absolute or relative path is unexpected. Checking
    // for the linker flavor is brittle. In addition, prepending "ld." or "ld64."
    // to a relative path is surprising. This is more complex due to priorities
    // among -B, COMPILER_PATH and PATH. --ld-path= should be used instead.
    if (mem.indexOfScalar(u8, use_linker, '/') != null) {
        try tc.driver.comp.addDiagnostic(.{ .tag = .fuse_ld_path }, &.{});
    }

    if (std.fs.path.isAbsolute(use_linker)) {
        if (tc.filesystem.canExecute(use_linker)) {
            return use_linker;
        }
    } else {
        var linker_name = try std.ArrayList(u8).initCapacity(tc.driver.comp.gpa, 5 + use_linker.len); // "ld64." ++ use_linker
        defer linker_name.deinit();
        if (tc.getTarget().isDarwin()) {
            linker_name.appendSliceAssumeCapacity("ld64.");
        } else {
            linker_name.appendSliceAssumeCapacity("ld.");
        }
        linker_name.appendSliceAssumeCapacity(use_linker);
        const linker_path = tc.getProgramPath(linker_name.items, buf);
        if (tc.filesystem.canExecute(linker_path)) {
            return linker_path;
        }
    }

    if (tc.driver.use_linker) |linker| {
        return tc.driver.fatal(
            "invalid linker name in argument '-fuse-ld={s}'",
            .{linker},
        );
    }
    const default_linker = tc.getDefaultLinker();
    return tc.getProgramPath(default_linker, buf);
}

/// If an explicit target is provided, also check the prefixed tool-specific name
/// TODO: this isn't exactly right since our target names don't necessarily match up
/// with GCC's.
/// For example the Zig target `arm-freestanding-eabi` would need the `arm-none-eabi` tools
fn possibleProgramNames(raw_triple: ?[]const u8, name: []const u8, buf: *[64]u8) std.BoundedArray([]const u8, 2) {
    var possible_names: std.BoundedArray([]const u8, 2) = .{};
    if (raw_triple) |triple| {
        if (std.fmt.bufPrint(buf, "{s}-{s}", .{ triple, name })) |res| {
            possible_names.appendAssumeCapacity(res);
        } else |_| {}
    }
    possible_names.appendAssumeCapacity(name);

    return possible_names;
}

/// Add toolchain `file_paths` to argv as `-L` arguments
pub fn addFilePathLibArgs(tc: *const Toolchain, argv: *std.ArrayList([]const u8)) !void {
    try argv.ensureUnusedCapacity(tc.file_paths.items.len);

    var bytes_needed: usize = 0;
    for (tc.file_paths.items) |path| {
        bytes_needed += path.len + 2; // +2 for `-L`
    }
    var bytes = try tc.arena.alloc(u8, bytes_needed);
    var index: usize = 0;
    for (tc.file_paths.items) |path| {
        @memcpy(bytes[index..][0..2], "-L");
        @memcpy(bytes[index + 2 ..][0..path.len], path);
        argv.appendAssumeCapacity(bytes[index..][0 .. path.len + 2]);
        index += path.len + 2;
    }
}

/// Search for an executable called `name` or `{triple}-{name} in program_paths and the $PATH environment variable
/// If not found there, just use `name`
/// Writes the result to `buf` and returns a slice of it
fn getProgramPath(tc: *const Toolchain, name: []const u8, buf: []u8) []const u8 {
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    var fib = std.heap.FixedBufferAllocator.init(&path_buf);

    var tool_specific_buf: [64]u8 = undefined;
    const possible_names = possibleProgramNames(tc.driver.raw_target_triple, name, &tool_specific_buf);

    for (possible_names.constSlice()) |tool_name| {
        for (tc.program_paths.items) |program_path| {
            defer fib.reset();

            const candidate = std.fs.path.join(fib.allocator(), &.{ program_path, tool_name }) catch continue;

            if (tc.filesystem.canExecute(candidate) and candidate.len <= buf.len) {
                @memcpy(buf[0..candidate.len], candidate);
                return buf[0..candidate.len];
            }
        }
        return tc.filesystem.findProgramByName(tc.driver.comp.gpa, name, tc.driver.comp.environment.path, buf) orelse continue;
    }
    @memcpy(buf[0..name.len], name);
    return buf[0..name.len];
}

pub fn getSysroot(tc: *const Toolchain) []const u8 {
    return tc.driver.sysroot orelse system_defaults.sysroot;
}

/// Search for `name` in a variety of places
/// TODO: cache results based on `name` so we're not repeatedly allocating the same strings?
pub fn getFilePath(tc: *const Toolchain, name: []const u8) ![]const u8 {
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    var fib = std.heap.FixedBufferAllocator.init(&path_buf);
    const allocator = fib.allocator();

    const sysroot = tc.getSysroot();

    // todo check resource dir
    // todo check compiler RT path
    const aro_dir = std.fs.path.dirname(tc.driver.aro_name) orelse "";
    const candidate = try std.fs.path.join(allocator, &.{ aro_dir, "..", name });
    if (tc.filesystem.exists(candidate)) {
        return tc.arena.dupe(u8, candidate);
    }

    if (tc.searchPaths(&fib, sysroot, tc.library_paths.items, name)) |path| {
        return tc.arena.dupe(u8, path);
    }

    if (tc.searchPaths(&fib, sysroot, tc.file_paths.items, name)) |path| {
        return try tc.arena.dupe(u8, path);
    }

    return name;
}

/// Search a list of `path_prefixes` for the existence `name`
/// Assumes that `fba` is a fixed-buffer allocator, so does not free joined path candidates
fn searchPaths(tc: *const Toolchain, fib: *std.heap.FixedBufferAllocator, sysroot: []const u8, path_prefixes: []const []const u8, name: []const u8) ?[]const u8 {
    for (path_prefixes) |path| {
        fib.reset();
        if (path.len == 0) continue;

        const candidate = if (path[0] == '=')
            std.fs.path.join(fib.allocator(), &.{ sysroot, path[1..], name }) catch continue
        else
            std.fs.path.join(fib.allocator(), &.{ path, name }) catch continue;

        if (tc.filesystem.exists(candidate)) {
            return candidate;
        }
    }
    return null;
}

const PathKind = enum {
    library,
    file,
    program,
};

/// Join `components` into a path. If the path exists, dupe it into the toolchain arena and
/// add it to the specified path list.
pub fn addPathIfExists(tc: *Toolchain, components: []const []const u8, dest_kind: PathKind) !void {
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    var fib = std.heap.FixedBufferAllocator.init(&path_buf);

    const candidate = try std.fs.path.join(fib.allocator(), components);

    if (tc.filesystem.exists(candidate)) {
        const duped = try tc.arena.dupe(u8, candidate);
        const dest = switch (dest_kind) {
            .library => &tc.library_paths,
            .file => &tc.file_paths,
            .program => &tc.program_paths,
        };
        try dest.append(tc.driver.comp.gpa, duped);
    }
}

/// Join `components` using the toolchain arena and add the resulting path to `dest_kind`. Does not check
/// whether the path actually exists
pub fn addPathFromComponents(tc: *Toolchain, components: []const []const u8, dest_kind: PathKind) !void {
    const full_path = try std.fs.path.join(tc.arena, components);
    const dest = switch (dest_kind) {
        .library => &tc.library_paths,
        .file => &tc.file_paths,
        .program => &tc.program_paths,
    };
    try dest.append(tc.driver.comp.gpa, full_path);
}

/// Add linker args to `argv`. Does not add path to linker executable as first item; that must be handled separately
/// Items added to `argv` will be string literals or owned by `tc.arena` so they must not be individually freed
pub fn buildLinkerArgs(tc: *Toolchain, argv: *std.ArrayList([]const u8)) !void {
    return switch (tc.inner) {
        .uninitialized => unreachable,
        .linux => |*linux| linux.buildLinkerArgs(tc, argv),
        .unknown => @panic("This toolchain does not support linking yet"),
    };
}

fn getDefaultRuntimeLibKind(tc: *const Toolchain) RuntimeLibKind {
    if (tc.getTarget().isAndroid()) {
        return .compiler_rt;
    }
    return .libgcc;
}

pub fn getRuntimeLibKind(tc: *const Toolchain) RuntimeLibKind {
    const libname = tc.driver.rtlib orelse system_defaults.rtlib;
    if (mem.eql(u8, libname, "compiler-rt"))
        return .compiler_rt
    else if (mem.eql(u8, libname, "libgcc"))
        return .libgcc
    else
        return tc.getDefaultRuntimeLibKind();
}

/// TODO
pub fn getCompilerRt(tc: *const Toolchain, component: []const u8, file_kind: FileKind) ![]const u8 {
    _ = file_kind;
    _ = component;
    _ = tc;
    return "";
}

fn getLibGCCKind(tc: *const Toolchain) LibGCCKind {
    const target = tc.getTarget();
    if (tc.driver.static_libgcc or tc.driver.static or tc.driver.static_pie or target.isAndroid()) {
        return .static;
    }
    if (tc.driver.shared_libgcc) {
        return .shared;
    }
    return .unspecified;
}

fn getUnwindLibKind(tc: *const Toolchain) !UnwindLibKind {
    const libname = tc.driver.unwindlib orelse system_defaults.unwindlib;
    if (libname.len == 0 or mem.eql(u8, libname, "platform")) {
        switch (tc.getRuntimeLibKind()) {
            .compiler_rt => {
                const target = tc.getTarget();
                if (target.isAndroid() or target.os.tag == .aix) {
                    return .compiler_rt;
                } else {
                    return .none;
                }
            },
            .libgcc => return .libgcc,
        }
    } else if (mem.eql(u8, libname, "none")) {
        return .none;
    } else if (mem.eql(u8, libname, "libgcc")) {
        return .libgcc;
    } else if (mem.eql(u8, libname, "libunwind")) {
        if (tc.getRuntimeLibKind() == .libgcc) {
            try tc.driver.comp.addDiagnostic(.{ .tag = .incompatible_unwindlib }, &.{});
        }
        return .compiler_rt;
    } else {
        unreachable;
    }
}

fn getAsNeededOption(is_solaris: bool, needed: bool) []const u8 {
    if (is_solaris) {
        return if (needed) "-zignore" else "-zrecord";
    } else {
        return if (needed) "--as-needed" else "--no-as-needed";
    }
}

fn addUnwindLibrary(tc: *const Toolchain, argv: *std.ArrayList([]const u8)) !void {
    const unw = try tc.getUnwindLibKind();
    const target = tc.getTarget();
    if ((target.isAndroid() and unw == .libgcc) or
        target.os.tag == .elfiamcu or
        target.ofmt == .wasm or
        target_util.isWindowsMSVCEnvironment(target) or
        unw == .none) return;

    const lgk = tc.getLibGCCKind();
    const as_needed = lgk == .unspecified and !target.isAndroid() and !target_util.isCygwinMinGW(target) and target.os.tag != .aix;
    if (as_needed) {
        try argv.append(getAsNeededOption(target.os.tag == .solaris, true));
    }
    switch (unw) {
        .none => return,
        .libgcc => if (lgk == .static) try argv.append("-lgcc_eh") else try argv.append("-lgcc_s"),
        .compiler_rt => if (target.os.tag == .aix) {
            if (lgk != .static) {
                try argv.append("-lunwind");
            }
        } else if (lgk == .static) {
            try argv.append("-l:libunwind.a");
        } else if (lgk == .shared) {
            if (target_util.isCygwinMinGW(target)) {
                try argv.append("-l:libunwind.dll.a");
            } else {
                try argv.append("-l:libunwind.so");
            }
        } else {
            try argv.append("-lunwind");
        },
    }

    if (as_needed) {
        try argv.append(getAsNeededOption(target.os.tag == .solaris, false));
    }
}

fn addLibGCC(tc: *const Toolchain, argv: *std.ArrayList([]const u8)) !void {
    const libgcc_kind = tc.getLibGCCKind();
    if (libgcc_kind == .static or libgcc_kind == .unspecified) {
        try argv.append("-lgcc");
    }
    try tc.addUnwindLibrary(argv);
    if (libgcc_kind == .shared) {
        try argv.append("-lgcc");
    }
}

pub fn addRuntimeLibs(tc: *const Toolchain, argv: *std.ArrayList([]const u8)) !void {
    const target = tc.getTarget();
    const rlt = tc.getRuntimeLibKind();
    switch (rlt) {
        .compiler_rt => {
            // TODO
        },
        .libgcc => {
            if (target_util.isKnownWindowsMSVCEnvironment(target)) {
                const rtlib_str = tc.driver.rtlib orelse system_defaults.rtlib;
                if (!mem.eql(u8, rtlib_str, "platform")) {
                    try tc.driver.comp.addDiagnostic(.{ .tag = .unsupported_rtlib_gcc, .extra = .{ .str = "MSVC" } }, &.{});
                }
            } else {
                try tc.addLibGCC(argv);
            }
        },
    }

    if (target.isAndroid() and !tc.driver.static and !tc.driver.static_pie) {
        try argv.append("-ldl");
    }
}

pub fn defineSystemIncludes(tc: *Toolchain) !void {
    return switch (tc.inner) {
        .uninitialized => unreachable,
        .linux => |*linux| linux.defineSystemIncludes(tc),
        .unknown => {
            if (tc.driver.nostdinc) return;

            const comp = tc.driver.comp;
            if (!tc.driver.nobuiltininc) {
                try comp.addBuiltinIncludeDir(tc.driver.aro_name);
            }

            if (!tc.driver.nostdlibinc) {
                try comp.addSystemIncludeDir("/usr/include");
            }
        },
    };
}
