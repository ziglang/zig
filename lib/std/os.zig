//! This file contains thin wrappers around OS-specific APIs, with these
//! specific goals in mind:
//! * Convert "errno"-style error codes into Zig errors.
//! * When null-terminated byte buffers are required, provide APIs which accept
//!   slices as well as APIs which accept null-terminated byte buffers. Same goes
//!   for WTF-16LE encoding.
//! * Where operating systems share APIs, e.g. POSIX, these thin wrappers provide
//!   cross platform abstracting.
//! * When there exists a corresponding libc function and linking libc, the libc
//!   implementation is used. Exceptions are made for known buggy areas of libc.
//!   On Linux libc can be side-stepped by using `std.os.linux` directly.
//! * For Windows, this file represents the API that libc would provide for
//!   Windows. For thin wrappers around Windows-specific APIs, see `std.os.windows`.

const root = @import("root");
const std = @import("std.zig");
const builtin = @import("builtin");
const assert = std.debug.assert;
const math = std.math;
const mem = std.mem;
const elf = std.elf;
const fs = std.fs;
const dl = @import("dynamic_library.zig");
const max_path_bytes = std.fs.max_path_bytes;
const posix = std.posix;
const native_os = builtin.os.tag;

pub const linux = @import("os/linux.zig");
pub const plan9 = @import("os/plan9.zig");
pub const uefi = @import("os/uefi.zig");
pub const wasi = @import("os/wasi.zig");
pub const emscripten = @import("os/emscripten.zig");
pub const windows = @import("os/windows.zig");

test {
    _ = linux;
    if (native_os == .uefi) {
        _ = uefi;
    }
    _ = wasi;
    _ = windows;
}

/// See also `getenv`. Populated by startup code before main().
/// TODO this is a footgun because the value will be undefined when using `zig build-lib`.
/// https://github.com/ziglang/zig/issues/4524
pub var environ: [][*:0]u8 = undefined;

/// Populated by startup code before main().
/// Not available on WASI or Windows without libc. See `std.process.argsAlloc`
/// or `std.process.argsWithAllocator` for a cross-platform alternative.
pub var argv: [][*:0]u8 = if (builtin.link_libc) undefined else switch (native_os) {
    .windows => @compileError("argv isn't supported on Windows: use std.process.argsAlloc instead"),
    .wasi => @compileError("argv isn't supported on WASI: use std.process.argsAlloc instead"),
    else => undefined,
};

/// Call from Windows-specific code if you already have a WTF-16LE encoded, null terminated string.
/// Otherwise use `access` or `accessZ`.
pub fn accessW(path: [*:0]const u16) windows.GetFileAttributesError!void {
    const ret = try windows.GetFileAttributesW(path);
    if (ret != windows.INVALID_FILE_ATTRIBUTES) {
        return;
    }
    switch (windows.GetLastError()) {
        .FILE_NOT_FOUND => return error.FileNotFound,
        .PATH_NOT_FOUND => return error.FileNotFound,
        .ACCESS_DENIED => return error.PermissionDenied,
        else => |err| return windows.unexpectedError(err),
    }
}

pub fn isGetFdPathSupportedOnTarget(os: std.Target.Os) bool {
    return switch (os.tag) {
        .windows,
        .macos,
        .ios,
        .watchos,
        .tvos,
        .visionos,
        .linux,
        .solaris,
        .illumos,
        .freebsd,
        => true,

        .dragonfly => os.version_range.semver.max.order(.{ .major = 6, .minor = 0, .patch = 0 }) != .lt,
        .netbsd => os.version_range.semver.max.order(.{ .major = 10, .minor = 0, .patch = 0 }) != .lt,
        else => false,
    };
}

/// Return canonical path of handle `fd`.
///
/// This function is very host-specific and is not universally supported by all hosts.
/// For example, while it generally works on Linux, macOS, FreeBSD or Windows, it is
/// unsupported on WASI.
///
/// * On Windows, the result is encoded as [WTF-8](https://simonsapin.github.io/wtf-8/).
/// * On other platforms, the result is an opaque sequence of bytes with no particular encoding.
///
/// Calling this function is usually a bug.
pub fn getFdPath(fd: std.posix.fd_t, out_buffer: *[max_path_bytes]u8) std.posix.RealPathError![]u8 {
    if (!comptime isGetFdPathSupportedOnTarget(builtin.os)) {
        @compileError("querying for canonical path of a handle is unsupported on this host");
    }
    switch (native_os) {
        .windows => {
            var wide_buf: [windows.PATH_MAX_WIDE]u16 = undefined;
            const wide_slice = try windows.GetFinalPathNameByHandle(fd, .{}, wide_buf[0..]);

            const end_index = std.unicode.wtf16LeToWtf8(out_buffer, wide_slice);
            return out_buffer[0..end_index];
        },
        .macos, .ios, .watchos, .tvos, .visionos => {
            // On macOS, we can use F.GETPATH fcntl command to query the OS for
            // the path to the file descriptor.
            @memset(out_buffer[0..max_path_bytes], 0);
            switch (posix.errno(posix.system.fcntl(fd, posix.F.GETPATH, out_buffer))) {
                .SUCCESS => {},
                .BADF => return error.FileNotFound,
                .NOSPC => return error.NameTooLong,
                // TODO man pages for fcntl on macOS don't really tell you what
                // errno values to expect when command is F.GETPATH...
                else => |err| return posix.unexpectedErrno(err),
            }
            const len = mem.indexOfScalar(u8, out_buffer[0..], 0) orelse max_path_bytes;
            return out_buffer[0..len];
        },
        .linux => {
            var procfs_buf: ["/proc/self/fd/-2147483648\x00".len]u8 = undefined;
            const proc_path = std.fmt.bufPrintZ(procfs_buf[0..], "/proc/self/fd/{d}", .{fd}) catch unreachable;

            const target = posix.readlinkZ(proc_path, out_buffer) catch |err| {
                switch (err) {
                    error.NotLink => unreachable,
                    error.BadPathName => unreachable,
                    error.InvalidUtf8 => unreachable, // WASI-only
                    error.InvalidWtf8 => unreachable, // Windows-only
                    error.UnsupportedReparsePointType => unreachable, // Windows-only
                    error.NetworkNotFound => unreachable, // Windows-only
                    else => |e| return e,
                }
            };
            return target;
        },
        .solaris, .illumos => {
            var procfs_buf: ["/proc/self/path/-2147483648\x00".len]u8 = undefined;
            const proc_path = std.fmt.bufPrintZ(procfs_buf[0..], "/proc/self/path/{d}", .{fd}) catch unreachable;

            const target = posix.readlinkZ(proc_path, out_buffer) catch |err| switch (err) {
                error.UnsupportedReparsePointType => unreachable,
                error.NotLink => unreachable,
                error.InvalidUtf8 => unreachable, // WASI-only
                else => |e| return e,
            };
            return target;
        },
        .freebsd => {
            if (comptime builtin.os.isAtLeast(.freebsd, .{ .major = 13, .minor = 0, .patch = 0 }) orelse false) {
                var kfile: std.c.kinfo_file = undefined;
                kfile.structsize = std.c.KINFO_FILE_SIZE;
                switch (posix.errno(std.c.fcntl(fd, std.c.F.KINFO, @intFromPtr(&kfile)))) {
                    .SUCCESS => {},
                    .BADF => return error.FileNotFound,
                    else => |err| return posix.unexpectedErrno(err),
                }
                const len = mem.indexOfScalar(u8, &kfile.path, 0) orelse max_path_bytes;
                if (len == 0) return error.NameTooLong;
                const result = out_buffer[0..len];
                @memcpy(result, kfile.path[0..len]);
                return result;
            } else {
                // This fallback implementation reimplements libutil's `kinfo_getfile()`.
                // The motivation is to avoid linking -lutil when building zig or general
                // user executables.
                var mib = [4]c_int{ posix.CTL.KERN, posix.KERN.PROC, posix.KERN.PROC_FILEDESC, std.c.getpid() };
                var len: usize = undefined;
                posix.sysctl(&mib, null, &len, null, 0) catch |err| switch (err) {
                    error.PermissionDenied => unreachable,
                    error.SystemResources => return error.SystemResources,
                    error.NameTooLong => unreachable,
                    error.UnknownName => unreachable,
                    else => return error.Unexpected,
                };
                len = len * 4 / 3;
                const buf = std.heap.c_allocator.alloc(u8, len) catch return error.SystemResources;
                defer std.heap.c_allocator.free(buf);
                len = buf.len;
                posix.sysctl(&mib, &buf[0], &len, null, 0) catch |err| switch (err) {
                    error.PermissionDenied => unreachable,
                    error.SystemResources => return error.SystemResources,
                    error.NameTooLong => unreachable,
                    error.UnknownName => unreachable,
                    else => return error.Unexpected,
                };
                var i: usize = 0;
                while (i < len) {
                    const kf: *align(1) std.c.kinfo_file = @ptrCast(&buf[i]);
                    if (kf.fd == fd) {
                        len = mem.indexOfScalar(u8, &kf.path, 0) orelse max_path_bytes;
                        if (len == 0) return error.NameTooLong;
                        const result = out_buffer[0..len];
                        @memcpy(result, kf.path[0..len]);
                        return result;
                    }
                    i += @intCast(kf.structsize);
                }
                return error.FileNotFound;
            }
        },
        .dragonfly => {
            @memset(out_buffer[0..max_path_bytes], 0);
            switch (posix.errno(std.c.fcntl(fd, posix.F.GETPATH, out_buffer))) {
                .SUCCESS => {},
                .BADF => return error.FileNotFound,
                .RANGE => return error.NameTooLong,
                else => |err| return posix.unexpectedErrno(err),
            }
            const len = mem.indexOfScalar(u8, out_buffer[0..], 0) orelse max_path_bytes;
            return out_buffer[0..len];
        },
        .netbsd => {
            @memset(out_buffer[0..max_path_bytes], 0);
            switch (posix.errno(std.c.fcntl(fd, posix.F.GETPATH, out_buffer))) {
                .SUCCESS => {},
                .ACCES => return error.AccessDenied,
                .BADF => return error.FileNotFound,
                .NOENT => return error.FileNotFound,
                .NOMEM => return error.SystemResources,
                .RANGE => return error.NameTooLong,
                else => |err| return posix.unexpectedErrno(err),
            }
            const len = mem.indexOfScalar(u8, out_buffer[0..], 0) orelse max_path_bytes;
            return out_buffer[0..len];
        },
        else => unreachable, // made unreachable by isGetFdPathSupportedOnTarget above
    }
}

/// WASI-only. Same as `fstatat` but targeting WASI.
/// `pathname` should be encoded as valid UTF-8.
/// See also `fstatat`.
pub fn fstatat_wasi(dirfd: posix.fd_t, pathname: []const u8, flags: wasi.lookupflags_t) posix.FStatAtError!wasi.filestat_t {
    var stat: wasi.filestat_t = undefined;
    switch (wasi.path_filestat_get(dirfd, flags, pathname.ptr, pathname.len, &stat)) {
        .SUCCESS => return stat,
        .INVAL => unreachable,
        .BADF => unreachable, // Always a race condition.
        .NOMEM => return error.SystemResources,
        .ACCES => return error.AccessDenied,
        .FAULT => unreachable,
        .NAMETOOLONG => return error.NameTooLong,
        .NOENT => return error.FileNotFound,
        .NOTDIR => return error.FileNotFound,
        .NOTCAPABLE => return error.AccessDenied,
        .ILSEQ => return error.InvalidUtf8,
        else => |err| return posix.unexpectedErrno(err),
    }
}

pub fn fstat_wasi(fd: posix.fd_t) posix.FStatError!wasi.filestat_t {
    var stat: wasi.filestat_t = undefined;
    switch (wasi.fd_filestat_get(fd, &stat)) {
        .SUCCESS => return stat,
        .INVAL => unreachable,
        .BADF => unreachable, // Always a race condition.
        .NOMEM => return error.SystemResources,
        .ACCES => return error.AccessDenied,
        .NOTCAPABLE => return error.AccessDenied,
        else => |err| return posix.unexpectedErrno(err),
    }
}
