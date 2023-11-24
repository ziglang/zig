const std = @import("std.zig");
const builtin = @import("builtin");
const root = @import("root");
const os = std.os;
const mem = std.mem;
const base64 = std.base64;
const crypto = std.crypto;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const is_darwin = builtin.os.tag.isDarwin();

pub const AtomicFile = @import("fs/AtomicFile.zig");
pub const Dir = @import("fs/Dir.zig");
pub const File = @import("fs/File.zig");
pub const path = @import("fs/path.zig");

pub const has_executable_bit = switch (builtin.os.tag) {
    .windows, .wasi => false,
    else => true,
};

pub const wasi = @import("fs/wasi.zig");

// TODO audit these APIs with respect to Dir and absolute paths

pub const realpath = os.realpath;
pub const realpathZ = os.realpathZ;
pub const realpathW = os.realpathW;

pub const getAppDataDir = @import("fs/get_app_data_dir.zig").getAppDataDir;
pub const GetAppDataDirError = @import("fs/get_app_data_dir.zig").GetAppDataDirError;

pub const Watch = @import("fs/watch.zig").Watch;

/// This represents the maximum size of a UTF-8 encoded file path that the
/// operating system will accept. Paths, including those returned from file
/// system operations, may be longer than this length, but such paths cannot
/// be successfully passed back in other file system operations. However,
/// all path components returned by file system operations are assumed to
/// fit into a UTF-8 encoded array of this length.
/// The byte count includes room for a null sentinel byte.
pub const MAX_PATH_BYTES = switch (builtin.os.tag) {
    .linux, .macos, .ios, .freebsd, .openbsd, .netbsd, .dragonfly, .haiku, .solaris, .illumos, .plan9 => os.PATH_MAX,
    // Each UTF-16LE character may be expanded to 3 UTF-8 bytes.
    // If it would require 4 UTF-8 bytes, then there would be a surrogate
    // pair in the UTF-16LE, and we (over)account 3 bytes for it that way.
    // +1 for the null byte at the end, which can be encoded in 1 byte.
    .windows => os.windows.PATH_MAX_WIDE * 3 + 1,
    // TODO work out what a reasonable value we should use here
    .wasi => 4096,
    else => if (@hasDecl(root, "os") and @hasDecl(root.os, "PATH_MAX"))
        root.os.PATH_MAX
    else
        @compileError("PATH_MAX not implemented for " ++ @tagName(builtin.os.tag)),
};

/// This represents the maximum size of a UTF-8 encoded file name component that
/// the platform's common file systems support. File name components returned by file system
/// operations are likely to fit into a UTF-8 encoded array of this length, but
/// (depending on the platform) this assumption may not hold for every configuration.
/// The byte count does not include a null sentinel byte.
pub const MAX_NAME_BYTES = switch (builtin.os.tag) {
    .linux, .macos, .ios, .freebsd, .openbsd, .netbsd, .dragonfly, .solaris, .illumos => os.NAME_MAX,
    // Haiku's NAME_MAX includes the null terminator, so subtract one.
    .haiku => os.NAME_MAX - 1,
    // Each UTF-16LE character may be expanded to 3 UTF-8 bytes.
    // If it would require 4 UTF-8 bytes, then there would be a surrogate
    // pair in the UTF-16LE, and we (over)account 3 bytes for it that way.
    .windows => os.windows.NAME_MAX * 3,
    // For WASI, the MAX_NAME will depend on the host OS, so it needs to be
    // as large as the largest MAX_NAME_BYTES (Windows) in order to work on any host OS.
    // TODO determine if this is a reasonable approach
    .wasi => os.windows.NAME_MAX * 3,
    else => if (@hasDecl(root, "os") and @hasDecl(root.os, "NAME_MAX"))
        root.os.NAME_MAX
    else
        @compileError("NAME_MAX not implemented for " ++ @tagName(builtin.os.tag)),
};

pub const base64_alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_".*;

/// Base64 encoder, replacing the standard `+/` with `-_` so that it can be used in a file name on any filesystem.
pub const base64_encoder = base64.Base64Encoder.init(base64_alphabet, null);

/// Base64 decoder, replacing the standard `+/` with `-_` so that it can be used in a file name on any filesystem.
pub const base64_decoder = base64.Base64Decoder.init(base64_alphabet, null);

/// Whether or not async file system syscalls need a dedicated thread because the operating
/// system does not support non-blocking I/O on the file system.
pub const need_async_thread = std.io.is_async and switch (builtin.os.tag) {
    .windows, .other => false,
    else => true,
};

/// TODO remove the allocator requirement from this API
/// TODO move to Dir
pub fn atomicSymLink(allocator: Allocator, existing_path: []const u8, new_path: []const u8) !void {
    if (cwd().symLink(existing_path, new_path, .{})) {
        return;
    } else |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err, // TODO zig should know this set does not include PathAlreadyExists
    }

    const dirname = path.dirname(new_path) orelse ".";

    var rand_buf: [AtomicFile.random_bytes_len]u8 = undefined;
    const tmp_path = try allocator.alloc(u8, dirname.len + 1 + base64_encoder.calcSize(rand_buf.len));
    defer allocator.free(tmp_path);
    @memcpy(tmp_path[0..dirname.len], dirname);
    tmp_path[dirname.len] = path.sep;
    while (true) {
        crypto.random.bytes(rand_buf[0..]);
        _ = base64_encoder.encode(tmp_path[dirname.len + 1 ..], &rand_buf);

        if (cwd().symLink(existing_path, tmp_path, .{})) {
            return cwd().rename(tmp_path, new_path);
        } else |err| switch (err) {
            error.PathAlreadyExists => continue,
            else => return err, // TODO zig should know this set does not include PathAlreadyExists
        }
    }
}

/// Same as `Dir.updateFile`, except asserts that both `source_path` and `dest_path`
/// are absolute. See `Dir.updateFile` for a function that operates on both
/// absolute and relative paths.
pub fn updateFileAbsolute(
    source_path: []const u8,
    dest_path: []const u8,
    args: Dir.CopyFileOptions,
) !Dir.PrevStatus {
    assert(path.isAbsolute(source_path));
    assert(path.isAbsolute(dest_path));
    const my_cwd = cwd();
    return Dir.updateFile(my_cwd, source_path, my_cwd, dest_path, args);
}

/// Same as `Dir.copyFile`, except asserts that both `source_path` and `dest_path`
/// are absolute. See `Dir.copyFile` for a function that operates on both
/// absolute and relative paths.
pub fn copyFileAbsolute(
    source_path: []const u8,
    dest_path: []const u8,
    args: Dir.CopyFileOptions,
) !void {
    assert(path.isAbsolute(source_path));
    assert(path.isAbsolute(dest_path));
    const my_cwd = cwd();
    return Dir.copyFile(my_cwd, source_path, my_cwd, dest_path, args);
}

/// Create a new directory, based on an absolute path.
/// Asserts that the path is absolute. See `Dir.makeDir` for a function that operates
/// on both absolute and relative paths.
pub fn makeDirAbsolute(absolute_path: []const u8) !void {
    assert(path.isAbsolute(absolute_path));
    return os.mkdir(absolute_path, Dir.default_mode);
}

/// Same as `makeDirAbsolute` except the parameter is a null-terminated UTF-8-encoded string.
pub fn makeDirAbsoluteZ(absolute_path_z: [*:0]const u8) !void {
    assert(path.isAbsoluteZ(absolute_path_z));
    return os.mkdirZ(absolute_path_z, Dir.default_mode);
}

/// Same as `makeDirAbsolute` except the parameter is a null-terminated WTF-16-encoded string.
pub fn makeDirAbsoluteW(absolute_path_w: [*:0]const u16) !void {
    assert(path.isAbsoluteWindowsW(absolute_path_w));
    return os.mkdirW(absolute_path_w, Dir.default_mode);
}

/// Same as `Dir.deleteDir` except the path is absolute.
pub fn deleteDirAbsolute(dir_path: []const u8) !void {
    assert(path.isAbsolute(dir_path));
    return os.rmdir(dir_path);
}

/// Same as `deleteDirAbsolute` except the path parameter is null-terminated.
pub fn deleteDirAbsoluteZ(dir_path: [*:0]const u8) !void {
    assert(path.isAbsoluteZ(dir_path));
    return os.rmdirZ(dir_path);
}

/// Same as `deleteDirAbsolute` except the path parameter is WTF-16 and target OS is assumed Windows.
pub fn deleteDirAbsoluteW(dir_path: [*:0]const u16) !void {
    assert(path.isAbsoluteWindowsW(dir_path));
    return os.rmdirW(dir_path);
}

/// Same as `Dir.rename` except the paths are absolute.
pub fn renameAbsolute(old_path: []const u8, new_path: []const u8) !void {
    assert(path.isAbsolute(old_path));
    assert(path.isAbsolute(new_path));
    return os.rename(old_path, new_path);
}

/// Same as `renameAbsolute` except the path parameters are null-terminated.
pub fn renameAbsoluteZ(old_path: [*:0]const u8, new_path: [*:0]const u8) !void {
    assert(path.isAbsoluteZ(old_path));
    assert(path.isAbsoluteZ(new_path));
    return os.renameZ(old_path, new_path);
}

/// Same as `renameAbsolute` except the path parameters are WTF-16 and target OS is assumed Windows.
pub fn renameAbsoluteW(old_path: [*:0]const u16, new_path: [*:0]const u16) !void {
    assert(path.isAbsoluteWindowsW(old_path));
    assert(path.isAbsoluteWindowsW(new_path));
    return os.renameW(old_path, new_path);
}

/// Same as `Dir.rename`, except `new_sub_path` is relative to `new_dir`
pub fn rename(old_dir: Dir, old_sub_path: []const u8, new_dir: Dir, new_sub_path: []const u8) !void {
    return os.renameat(old_dir.fd, old_sub_path, new_dir.fd, new_sub_path);
}

/// Same as `rename` except the parameters are null-terminated.
pub fn renameZ(old_dir: Dir, old_sub_path_z: [*:0]const u8, new_dir: Dir, new_sub_path_z: [*:0]const u8) !void {
    return os.renameatZ(old_dir.fd, old_sub_path_z, new_dir.fd, new_sub_path_z);
}

/// Same as `rename` except the parameters are UTF16LE, NT prefixed.
/// This function is Windows-only.
pub fn renameW(old_dir: Dir, old_sub_path_w: []const u16, new_dir: Dir, new_sub_path_w: []const u16) !void {
    return os.renameatW(old_dir.fd, old_sub_path_w, new_dir.fd, new_sub_path_w);
}

/// Returns a handle to the current working directory. It is not opened with iteration capability.
/// Closing the returned `Dir` is checked illegal behavior. Iterating over the result is illegal behavior.
/// On POSIX targets, this function is comptime-callable.
pub fn cwd() Dir {
    if (builtin.os.tag == .windows) {
        return Dir{ .fd = os.windows.peb().ProcessParameters.CurrentDirectory.Handle };
    } else if (builtin.os.tag == .wasi) {
        return std.options.wasiCwd();
    } else {
        return Dir{ .fd = os.AT.FDCWD };
    }
}

pub fn defaultWasiCwd() Dir {
    // Expect the first preopen to be current working directory.
    return .{ .fd = 3 };
}

/// Opens a directory at the given path. The directory is a system resource that remains
/// open until `close` is called on the result.
/// See `openDirAbsoluteZ` for a function that accepts a null-terminated path.
///
/// Asserts that the path parameter has no null bytes.
pub fn openDirAbsolute(absolute_path: []const u8, flags: Dir.OpenDirOptions) File.OpenError!Dir {
    assert(path.isAbsolute(absolute_path));
    return cwd().openDir(absolute_path, flags);
}

/// Same as `openDirAbsolute` but the path parameter is null-terminated.
pub fn openDirAbsoluteZ(absolute_path_c: [*:0]const u8, flags: Dir.OpenDirOptions) File.OpenError!Dir {
    assert(path.isAbsoluteZ(absolute_path_c));
    return cwd().openDirZ(absolute_path_c, flags);
}
/// Same as `openDirAbsolute` but the path parameter is null-terminated.
pub fn openDirAbsoluteW(absolute_path_c: [*:0]const u16, flags: Dir.OpenDirOptions) File.OpenError!Dir {
    assert(path.isAbsoluteWindowsW(absolute_path_c));
    return cwd().openDirW(absolute_path_c, flags);
}

/// Opens a file for reading or writing, without attempting to create a new file, based on an absolute path.
/// Call `File.close` to release the resource.
/// Asserts that the path is absolute. See `Dir.openFile` for a function that
/// operates on both absolute and relative paths.
/// Asserts that the path parameter has no null bytes. See `openFileAbsoluteZ` for a function
/// that accepts a null-terminated path.
pub fn openFileAbsolute(absolute_path: []const u8, flags: File.OpenFlags) File.OpenError!File {
    assert(path.isAbsolute(absolute_path));
    return cwd().openFile(absolute_path, flags);
}

/// Same as `openFileAbsolute` but the path parameter is null-terminated.
pub fn openFileAbsoluteZ(absolute_path_c: [*:0]const u8, flags: File.OpenFlags) File.OpenError!File {
    assert(path.isAbsoluteZ(absolute_path_c));
    return cwd().openFileZ(absolute_path_c, flags);
}

/// Same as `openFileAbsolute` but the path parameter is WTF-16-encoded.
pub fn openFileAbsoluteW(absolute_path_w: []const u16, flags: File.OpenFlags) File.OpenError!File {
    assert(path.isAbsoluteWindowsWTF16(absolute_path_w));
    return cwd().openFileW(absolute_path_w, flags);
}

/// Test accessing `path`.
/// `path` is UTF-8-encoded.
/// Be careful of Time-Of-Check-Time-Of-Use race conditions when using this function.
/// For example, instead of testing if a file exists and then opening it, just
/// open it and handle the error for file not found.
/// See `accessAbsoluteZ` for a function that accepts a null-terminated path.
pub fn accessAbsolute(absolute_path: []const u8, flags: File.OpenFlags) Dir.AccessError!void {
    assert(path.isAbsolute(absolute_path));
    try cwd().access(absolute_path, flags);
}
/// Same as `accessAbsolute` but the path parameter is null-terminated.
pub fn accessAbsoluteZ(absolute_path: [*:0]const u8, flags: File.OpenFlags) Dir.AccessError!void {
    assert(path.isAbsoluteZ(absolute_path));
    try cwd().accessZ(absolute_path, flags);
}
/// Same as `accessAbsolute` but the path parameter is WTF-16 encoded.
pub fn accessAbsoluteW(absolute_path: [*:0]const u16, flags: File.OpenFlags) Dir.AccessError!void {
    assert(path.isAbsoluteWindowsW(absolute_path));
    try cwd().accessW(absolute_path, flags);
}

/// Creates, opens, or overwrites a file with write access, based on an absolute path.
/// Call `File.close` to release the resource.
/// Asserts that the path is absolute. See `Dir.createFile` for a function that
/// operates on both absolute and relative paths.
/// Asserts that the path parameter has no null bytes. See `createFileAbsoluteC` for a function
/// that accepts a null-terminated path.
pub fn createFileAbsolute(absolute_path: []const u8, flags: File.CreateFlags) File.OpenError!File {
    assert(path.isAbsolute(absolute_path));
    return cwd().createFile(absolute_path, flags);
}

/// Same as `createFileAbsolute` but the path parameter is null-terminated.
pub fn createFileAbsoluteZ(absolute_path_c: [*:0]const u8, flags: File.CreateFlags) File.OpenError!File {
    assert(path.isAbsoluteZ(absolute_path_c));
    return cwd().createFileZ(absolute_path_c, flags);
}

/// Same as `createFileAbsolute` but the path parameter is WTF-16 encoded.
pub fn createFileAbsoluteW(absolute_path_w: [*:0]const u16, flags: File.CreateFlags) File.OpenError!File {
    assert(path.isAbsoluteWindowsW(absolute_path_w));
    return cwd().createFileW(absolute_path_w, flags);
}

/// Delete a file name and possibly the file it refers to, based on an absolute path.
/// Asserts that the path is absolute. See `Dir.deleteFile` for a function that
/// operates on both absolute and relative paths.
/// Asserts that the path parameter has no null bytes.
pub fn deleteFileAbsolute(absolute_path: []const u8) Dir.DeleteFileError!void {
    assert(path.isAbsolute(absolute_path));
    return cwd().deleteFile(absolute_path);
}

/// Same as `deleteFileAbsolute` except the parameter is null-terminated.
pub fn deleteFileAbsoluteZ(absolute_path_c: [*:0]const u8) Dir.DeleteFileError!void {
    assert(path.isAbsoluteZ(absolute_path_c));
    return cwd().deleteFileZ(absolute_path_c);
}

/// Same as `deleteFileAbsolute` except the parameter is WTF-16 encoded.
pub fn deleteFileAbsoluteW(absolute_path_w: [*:0]const u16) Dir.DeleteFileError!void {
    assert(path.isAbsoluteWindowsW(absolute_path_w));
    return cwd().deleteFileW(absolute_path_w);
}

/// Removes a symlink, file, or directory.
/// This is equivalent to `Dir.deleteTree` with the base directory.
/// Asserts that the path is absolute. See `Dir.deleteTree` for a function that
/// operates on both absolute and relative paths.
/// Asserts that the path parameter has no null bytes.
pub fn deleteTreeAbsolute(absolute_path: []const u8) !void {
    assert(path.isAbsolute(absolute_path));
    const dirname = path.dirname(absolute_path) orelse return error{
        /// Attempt to remove the root file system path.
        /// This error is unreachable if `absolute_path` is relative.
        CannotDeleteRootDirectory,
    }.CannotDeleteRootDirectory;

    var dir = try cwd().openDir(dirname, .{});
    defer dir.close();

    return dir.deleteTree(path.basename(absolute_path));
}

/// Same as `Dir.readLink`, except it asserts the path is absolute.
pub fn readLinkAbsolute(pathname: []const u8, buffer: *[MAX_PATH_BYTES]u8) ![]u8 {
    assert(path.isAbsolute(pathname));
    return os.readlink(pathname, buffer);
}

/// Windows-only. Same as `readlinkW`, except the path parameter is null-terminated, WTF16
/// encoded.
pub fn readlinkAbsoluteW(pathname_w: [*:0]const u16, buffer: *[MAX_PATH_BYTES]u8) ![]u8 {
    assert(path.isAbsoluteWindowsW(pathname_w));
    return os.readlinkW(pathname_w, buffer);
}

/// Same as `readLink`, except the path parameter is null-terminated.
pub fn readLinkAbsoluteZ(pathname_c: [*:0]const u8, buffer: *[MAX_PATH_BYTES]u8) ![]u8 {
    assert(path.isAbsoluteZ(pathname_c));
    return os.readlinkZ(pathname_c, buffer);
}

/// Creates a symbolic link named `sym_link_path` which contains the string `target_path`.
/// A symbolic link (also known as a soft link) may point to an existing file or to a nonexistent
/// one; the latter case is known as a dangling link.
/// If `sym_link_path` exists, it will not be overwritten.
/// See also `symLinkAbsoluteZ` and `symLinkAbsoluteW`.
pub fn symLinkAbsolute(
    target_path: []const u8,
    sym_link_path: []const u8,
    flags: Dir.SymLinkFlags,
) !void {
    assert(path.isAbsolute(target_path));
    assert(path.isAbsolute(sym_link_path));
    if (builtin.os.tag == .windows) {
        const target_path_w = try os.windows.sliceToPrefixedFileW(null, target_path);
        const sym_link_path_w = try os.windows.sliceToPrefixedFileW(null, sym_link_path);
        return os.windows.CreateSymbolicLink(null, sym_link_path_w.span(), target_path_w.span(), flags.is_directory);
    }
    return os.symlink(target_path, sym_link_path);
}

/// Windows-only. Same as `symLinkAbsolute` except the parameters are null-terminated, WTF16 encoded.
/// Note that this function will by default try creating a symbolic link to a file. If you would
/// like to create a symbolic link to a directory, specify this with `SymLinkFlags{ .is_directory = true }`.
/// See also `symLinkAbsolute`, `symLinkAbsoluteZ`.
pub fn symLinkAbsoluteW(
    target_path_w: []const u16,
    sym_link_path_w: []const u16,
    flags: Dir.SymLinkFlags,
) !void {
    assert(path.isAbsoluteWindowsWTF16(target_path_w));
    assert(path.isAbsoluteWindowsWTF16(sym_link_path_w));
    return os.windows.CreateSymbolicLink(null, sym_link_path_w, target_path_w, flags.is_directory);
}

/// Same as `symLinkAbsolute` except the parameters are null-terminated pointers.
/// See also `symLinkAbsolute`.
pub fn symLinkAbsoluteZ(
    target_path_c: [*:0]const u8,
    sym_link_path_c: [*:0]const u8,
    flags: Dir.SymLinkFlags,
) !void {
    assert(path.isAbsoluteZ(target_path_c));
    assert(path.isAbsoluteZ(sym_link_path_c));
    if (builtin.os.tag == .windows) {
        const target_path_w = try os.windows.cStrToWin32PrefixedFileW(target_path_c);
        const sym_link_path_w = try os.windows.cStrToWin32PrefixedFileW(sym_link_path_c);
        return os.windows.CreateSymbolicLink(sym_link_path_w.span(), target_path_w.span(), flags.is_directory);
    }
    return os.symlinkZ(target_path_c, sym_link_path_c);
}

pub const OpenSelfExeError = error{
    SharingViolation,
    PathAlreadyExists,
    FileNotFound,
    AccessDenied,
    PipeBusy,
    NameTooLong,
    /// On Windows, file paths must be valid Unicode.
    InvalidUtf8,
    /// On Windows, file paths cannot contain these characters:
    /// '/', '*', '?', '"', '<', '>', '|'
    BadPathName,
    Unexpected,
} || os.OpenError || SelfExePathError || os.FlockError;

pub fn openSelfExe(flags: File.OpenFlags) OpenSelfExeError!File {
    if (builtin.os.tag == .linux) {
        return openFileAbsoluteZ("/proc/self/exe", flags);
    }
    if (builtin.os.tag == .windows) {
        // If ImagePathName is a symlink, then it will contain the path of the symlink,
        // not the path that the symlink points to. However, because we are opening
        // the file, we can let the openFileW call follow the symlink for us.
        const image_path_unicode_string = &os.windows.peb().ProcessParameters.ImagePathName;
        const image_path_name = image_path_unicode_string.Buffer[0 .. image_path_unicode_string.Length / 2 :0];
        const prefixed_path_w = try os.windows.wToPrefixedFileW(null, image_path_name);
        return cwd().openFileW(prefixed_path_w.span(), flags);
    }
    // Use of MAX_PATH_BYTES here is valid as the resulting path is immediately
    // opened with no modification.
    var buf: [MAX_PATH_BYTES]u8 = undefined;
    const self_exe_path = try selfExePath(&buf);
    buf[self_exe_path.len] = 0;
    return openFileAbsoluteZ(buf[0..self_exe_path.len :0].ptr, flags);
}

pub const SelfExePathError = os.ReadLinkError || os.SysCtlError || os.RealPathError;

/// `selfExePath` except allocates the result on the heap.
/// Caller owns returned memory.
pub fn selfExePathAlloc(allocator: Allocator) ![]u8 {
    // Use of MAX_PATH_BYTES here is justified as, at least on one tested Linux
    // system, readlink will completely fail to return a result larger than
    // PATH_MAX even if given a sufficiently large buffer. This makes it
    // fundamentally impossible to get the selfExePath of a program running in
    // a very deeply nested directory chain in this way.
    // TODO(#4812): Investigate other systems and whether it is possible to get
    // this path by trying larger and larger buffers until one succeeds.
    var buf: [MAX_PATH_BYTES]u8 = undefined;
    return allocator.dupe(u8, try selfExePath(&buf));
}

/// Get the path to the current executable. Follows symlinks.
/// If you only need the directory, use selfExeDirPath.
/// If you only want an open file handle, use openSelfExe.
/// This function may return an error if the current executable
/// was deleted after spawning.
/// Returned value is a slice of out_buffer.
///
/// On Linux, depends on procfs being mounted. If the currently executing binary has
/// been deleted, the file path looks something like `/a/b/c/exe (deleted)`.
/// TODO make the return type of this a null terminated pointer
pub fn selfExePath(out_buffer: []u8) SelfExePathError![]u8 {
    if (is_darwin) {
        // Note that _NSGetExecutablePath() will return "a path" to
        // the executable not a "real path" to the executable.
        var symlink_path_buf: [MAX_PATH_BYTES:0]u8 = undefined;
        var u32_len: u32 = MAX_PATH_BYTES + 1; // include the sentinel
        const rc = std.c._NSGetExecutablePath(&symlink_path_buf, &u32_len);
        if (rc != 0) return error.NameTooLong;

        var real_path_buf: [MAX_PATH_BYTES]u8 = undefined;
        const real_path = try std.os.realpathZ(&symlink_path_buf, &real_path_buf);
        if (real_path.len > out_buffer.len) return error.NameTooLong;
        const result = out_buffer[0..real_path.len];
        @memcpy(result, real_path);
        return result;
    }
    switch (builtin.os.tag) {
        .linux => return os.readlinkZ("/proc/self/exe", out_buffer),
        .solaris, .illumos => return os.readlinkZ("/proc/self/path/a.out", out_buffer),
        .freebsd, .dragonfly => {
            var mib = [4]c_int{ os.CTL.KERN, os.KERN.PROC, os.KERN.PROC_PATHNAME, -1 };
            var out_len: usize = out_buffer.len;
            try os.sysctl(&mib, out_buffer.ptr, &out_len, null, 0);
            // TODO could this slice from 0 to out_len instead?
            return mem.sliceTo(out_buffer, 0);
        },
        .netbsd => {
            var mib = [4]c_int{ os.CTL.KERN, os.KERN.PROC_ARGS, -1, os.KERN.PROC_PATHNAME };
            var out_len: usize = out_buffer.len;
            try os.sysctl(&mib, out_buffer.ptr, &out_len, null, 0);
            // TODO could this slice from 0 to out_len instead?
            return mem.sliceTo(out_buffer, 0);
        },
        .openbsd, .haiku => {
            // OpenBSD doesn't support getting the path of a running process, so try to guess it
            if (os.argv.len == 0)
                return error.FileNotFound;

            const argv0 = mem.span(os.argv[0]);
            if (mem.indexOf(u8, argv0, "/") != null) {
                // argv[0] is a path (relative or absolute): use realpath(3) directly
                var real_path_buf: [MAX_PATH_BYTES]u8 = undefined;
                const real_path = try os.realpathZ(os.argv[0], &real_path_buf);
                if (real_path.len > out_buffer.len)
                    return error.NameTooLong;
                const result = out_buffer[0..real_path.len];
                @memcpy(result, real_path);
                return result;
            } else if (argv0.len != 0) {
                // argv[0] is not empty (and not a path): search it inside PATH
                const PATH = std.os.getenvZ("PATH") orelse return error.FileNotFound;
                var path_it = mem.tokenizeScalar(u8, PATH, path.delimiter);
                while (path_it.next()) |a_path| {
                    var resolved_path_buf: [MAX_PATH_BYTES - 1:0]u8 = undefined;
                    const resolved_path = std.fmt.bufPrintZ(&resolved_path_buf, "{s}/{s}", .{
                        a_path,
                        os.argv[0],
                    }) catch continue;

                    var real_path_buf: [MAX_PATH_BYTES]u8 = undefined;
                    if (os.realpathZ(resolved_path, &real_path_buf)) |real_path| {
                        // found a file, and hope it is the right file
                        if (real_path.len > out_buffer.len)
                            return error.NameTooLong;
                        const result = out_buffer[0..real_path.len];
                        @memcpy(result, real_path);
                        return result;
                    } else |_| continue;
                }
            }
            return error.FileNotFound;
        },
        .windows => {
            const image_path_unicode_string = &os.windows.peb().ProcessParameters.ImagePathName;
            const image_path_name = image_path_unicode_string.Buffer[0 .. image_path_unicode_string.Length / 2 :0];

            // If ImagePathName is a symlink, then it will contain the path of the
            // symlink, not the path that the symlink points to. We want the path
            // that the symlink points to, though, so we need to get the realpath.
            const pathname_w = try os.windows.wToPrefixedFileW(null, image_path_name);
            return std.fs.cwd().realpathW(pathname_w.span(), out_buffer);
        },
        else => @compileError("std.fs.selfExePath not supported for this target"),
    }
}

pub const selfExePathW = @compileError("deprecated; use selfExePath instead");

/// `selfExeDirPath` except allocates the result on the heap.
/// Caller owns returned memory.
pub fn selfExeDirPathAlloc(allocator: Allocator) ![]u8 {
    // Use of MAX_PATH_BYTES here is justified as, at least on one tested Linux
    // system, readlink will completely fail to return a result larger than
    // PATH_MAX even if given a sufficiently large buffer. This makes it
    // fundamentally impossible to get the selfExeDirPath of a program running
    // in a very deeply nested directory chain in this way.
    // TODO(#4812): Investigate other systems and whether it is possible to get
    // this path by trying larger and larger buffers until one succeeds.
    var buf: [MAX_PATH_BYTES]u8 = undefined;
    return allocator.dupe(u8, try selfExeDirPath(&buf));
}

/// Get the directory path that contains the current executable.
/// Returned value is a slice of out_buffer.
pub fn selfExeDirPath(out_buffer: []u8) SelfExePathError![]const u8 {
    const self_exe_path = try selfExePath(out_buffer);
    // Assume that the OS APIs return absolute paths, and therefore dirname
    // will not return null.
    return path.dirname(self_exe_path).?;
}

/// `realpath`, except caller must free the returned memory.
/// See also `Dir.realpath`.
pub fn realpathAlloc(allocator: Allocator, pathname: []const u8) ![]u8 {
    // Use of MAX_PATH_BYTES here is valid as the realpath function does not
    // have a variant that takes an arbitrary-size buffer.
    // TODO(#4812): Consider reimplementing realpath or using the POSIX.1-2008
    // NULL out parameter (GNU's canonicalize_file_name) to handle overelong
    // paths. musl supports passing NULL but restricts the output to PATH_MAX
    // anyway.
    var buf: [MAX_PATH_BYTES]u8 = undefined;
    return allocator.dupe(u8, try os.realpath(pathname, &buf));
}

test {
    if (builtin.os.tag != .wasi) {
        _ = &makeDirAbsolute;
        _ = &makeDirAbsoluteZ;
        _ = &copyFileAbsolute;
        _ = &updateFileAbsolute;
    }
    _ = &AtomicFile;
    _ = &Dir;
    _ = &File;
    _ = &path;
    _ = @import("fs/test.zig");
    _ = @import("fs/get_app_data_dir.zig");
    _ = @import("fs/watch.zig");
}
