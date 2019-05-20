const std = @import("std.zig");
const builtin = @import("builtin");
const Os = builtin.Os;
const is_windows = builtin.os == Os.windows;
const os = @This();

comptime {
    assert(@import("std") == std); // You have to run the std lib tests with --override-std-dir
}

test "std.os" {
    _ = @import("os/child_process.zig");
    _ = @import("os/darwin.zig");
    _ = @import("os/get_user_id.zig");
    _ = @import("os/linux.zig");
    _ = @import("os/path.zig");
    _ = @import("os/test.zig");
    _ = @import("os/time.zig");
    _ = @import("os/windows.zig");
    _ = @import("os/uefi.zig");
    _ = @import("os/wasi.zig");
    _ = @import("os/get_app_data_dir.zig");
}

pub const windows = @import("os/windows.zig");
pub const darwin = @import("os/darwin.zig");
pub const linux = @import("os/linux.zig");
pub const freebsd = @import("os/freebsd.zig");
pub const netbsd = @import("os/netbsd.zig");
pub const zen = @import("os/zen.zig");
pub const uefi = @import("os/uefi.zig");
pub const wasi = @import("os/wasi.zig");

pub const system = switch (builtin.os) {
    .linux => linux,
    .macosx, .ios, .watchos, .tvos => darwin,
    .freebsd => freebsd,
    .netbsd => netbsd,
    .zen => zen,
    .wasi => wasi,
    else => struct {},
};

pub const net = @import("net.zig");

pub const ChildProcess = @import("os/child_process.zig").ChildProcess;
pub const path = @import("os/path.zig");
pub const File = @import("os/file.zig").File;
pub const time = @import("os/time.zig");

pub const page_size = switch (builtin.arch) {
    .wasm32, .wasm64 => 64 * 1024,
    else => 4 * 1024,
};

/// This represents the maximum size of a UTF-8 encoded file path.
/// All file system operations which return a path are guaranteed to
/// fit into a UTF-8 encoded array of this length.
/// path being too long if it is this 0long
pub const MAX_PATH_BYTES = switch (builtin.os) {
    .linux, .macosx, .ios, .freebsd, .netbsd => posix.PATH_MAX,
    // Each UTF-16LE character may be expanded to 3 UTF-8 bytes.
    // If it would require 4 UTF-8 bytes, then there would be a surrogate
    // pair in the UTF-16LE, and we (over)account 3 bytes for it that way.
    // +1 for the null byte at the end, which can be encoded in 1 byte.
    .windows => posix.PATH_MAX_WIDE * 3 + 1,
    else => @compileError("Unsupported OS"),
};

pub const UserInfo = @import("os/get_user_id.zig").UserInfo;
pub const getUserInfo = @import("os/get_user_id.zig").getUserInfo;

const windows_util = @import("os/windows/util.zig");
pub const windowsWaitSingle = windows_util.windowsWaitSingle;
pub const windowsWrite = windows_util.windowsWrite;
pub const windowsIsCygwinPty = windows_util.windowsIsCygwinPty;
pub const windowsOpen = windows_util.windowsOpen;
pub const windowsOpenW = windows_util.windowsOpenW;
pub const createWindowsEnvBlock = windows_util.createWindowsEnvBlock;

pub const WindowsCreateIoCompletionPortError = windows_util.WindowsCreateIoCompletionPortError;
pub const windowsCreateIoCompletionPort = windows_util.windowsCreateIoCompletionPort;

pub const WindowsPostQueuedCompletionStatusError = windows_util.WindowsPostQueuedCompletionStatusError;
pub const windowsPostQueuedCompletionStatus = windows_util.windowsPostQueuedCompletionStatus;

pub const WindowsWaitResult = windows_util.WindowsWaitResult;
pub const windowsGetQueuedCompletionStatus = windows_util.windowsGetQueuedCompletionStatus;

pub const WindowsWaitError = windows_util.WaitError;
pub const WindowsOpenError = windows_util.OpenError;
pub const WindowsWriteError = windows_util.WriteError;
pub const WindowsReadError = windows_util.ReadError;

pub const getAppDataDir = @import("os/get_app_data_dir.zig").getAppDataDir;
pub const GetAppDataDirError = @import("os/get_app_data_dir.zig").GetAppDataDirError;

pub const getRandomBytes = posix.getrandom;
pub const abort = posix.abort;
pub const exit = posix.exit;
pub const symLink = posix.symlink;
pub const symLinkC = posix.symlinkC;
pub const symLinkW = posix.symlinkW;
pub const deleteFile = posix.unlink;
pub const deleteFileC = posix.unlinkC;
pub const deleteFileW = posix.unlinkW;
pub const rename = posix.rename;
pub const renameC = posix.renameC;
pub const renameW = posix.renameW;
pub const changeCurDir = posix.chdir;
pub const changeCurDirC = posix.chdirC;
pub const changeCurDirW = posix.chdirW;

const debug = std.debug;
const assert = debug.assert;
const testing = std.testing;

const c = std.c;

const mem = std.mem;
const Allocator = mem.Allocator;

const BufMap = std.BufMap;
const cstr = std.cstr;

const io = std.io;
const base64 = std.base64;
const ArrayList = std.ArrayList;
const Buffer = std.Buffer;
const math = std.math;

pub fn getBaseAddress() usize {
    switch (builtin.os) {
        builtin.Os.linux => {
            const base = linuxGetAuxVal(std.elf.AT_BASE);
            if (base != 0) {
                return base;
            }
            const phdr = linuxGetAuxVal(std.elf.AT_PHDR);
            return phdr - @sizeOf(std.elf.Ehdr);
        },
        builtin.Os.macosx, builtin.Os.freebsd, builtin.Os.netbsd => {
            return @ptrToInt(&std.c._mh_execute_header);
        },
        builtin.Os.windows => return @ptrToInt(windows.GetModuleHandleW(null)),
        else => @compileError("Unsupported OS"),
    }
}

/// Caller must free result when done.
/// TODO make this go through libc when we have it
pub fn getEnvMap(allocator: *Allocator) !BufMap {
    var result = BufMap.init(allocator);
    errdefer result.deinit();

    if (is_windows) {
        const ptr = windows.GetEnvironmentStringsW() orelse return error.OutOfMemory;
        defer assert(windows.FreeEnvironmentStringsW(ptr) != 0);

        var i: usize = 0;
        while (true) {
            if (ptr[i] == 0) return result;

            const key_start = i;

            while (ptr[i] != 0 and ptr[i] != '=') : (i += 1) {}
            const key_w = ptr[key_start..i];
            const key = try std.unicode.utf16leToUtf8Alloc(allocator, key_w);
            errdefer allocator.free(key);

            if (ptr[i] == '=') i += 1;

            const value_start = i;
            while (ptr[i] != 0) : (i += 1) {}
            const value_w = ptr[value_start..i];
            const value = try std.unicode.utf16leToUtf8Alloc(allocator, value_w);
            errdefer allocator.free(value);

            i += 1; // skip over null byte

            try result.setMove(key, value);
        }
    } else if (builtin.os == Os.wasi) {
        var environ_count: usize = undefined;
        var environ_buf_size: usize = undefined;

        const environ_sizes_get_ret = std.os.wasi.environ_sizes_get(&environ_count, &environ_buf_size);
        if (environ_sizes_get_ret != os.wasi.ESUCCESS) {
            return unexpectedErrorPosix(environ_sizes_get_ret);
        }

        // TODO: Verify that the documentation is incorrect
        // https://github.com/WebAssembly/WASI/issues/27
        var environ = try allocator.alloc(?[*]u8, environ_count + 1);
        defer allocator.free(environ);
        var environ_buf = try std.heap.wasm_allocator.alloc(u8, environ_buf_size);
        defer allocator.free(environ_buf);

        const environ_get_ret = std.os.wasi.environ_get(environ.ptr, environ_buf.ptr);
        if (environ_get_ret != os.wasi.ESUCCESS) {
            return unexpectedErrorPosix(environ_get_ret);
        }

        for (environ) |env| {
            if (env) |ptr| {
                const pair = mem.toSlice(u8, ptr);
                var parts = mem.separate(pair, "=");
                const key = parts.next().?;
                const value = parts.next().?;
                try result.set(key, value);
            }
        }
        return result;
    } else {
        for (posix.environ) |ptr| {
            var line_i: usize = 0;
            while (ptr[line_i] != 0 and ptr[line_i] != '=') : (line_i += 1) {}
            const key = ptr[0..line_i];

            var end_i: usize = line_i;
            while (ptr[end_i] != 0) : (end_i += 1) {}
            const value = ptr[line_i + 1 .. end_i];

            try result.set(key, value);
        }
        return result;
    }
}

test "os.getEnvMap" {
    var env = try getEnvMap(std.debug.global_allocator);
    defer env.deinit();
}

pub const GetEnvVarOwnedError = error{
    OutOfMemory,
    EnvironmentVariableNotFound,

    /// See https://github.com/ziglang/zig/issues/1774
    InvalidUtf8,
};

/// Caller must free returned memory.
/// TODO make this go through libc when we have it
pub fn getEnvVarOwned(allocator: *mem.Allocator, key: []const u8) GetEnvVarOwnedError![]u8 {
    if (is_windows) {
        const key_with_null = try std.unicode.utf8ToUtf16LeWithNull(allocator, key);
        defer allocator.free(key_with_null);

        var buf = try allocator.alloc(u16, 256);
        defer allocator.free(buf);

        while (true) {
            const windows_buf_len = math.cast(windows.DWORD, buf.len) catch return error.OutOfMemory;
            const result = windows.GetEnvironmentVariableW(key_with_null.ptr, buf.ptr, windows_buf_len);

            if (result == 0) {
                const err = windows.GetLastError();
                return switch (err) {
                    windows.ERROR.ENVVAR_NOT_FOUND => error.EnvironmentVariableNotFound,
                    else => {
                        unexpectedErrorWindows(err) catch {};
                        return error.EnvironmentVariableNotFound;
                    },
                };
            }

            if (result > buf.len) {
                buf = try allocator.realloc(buf, result);
                continue;
            }

            return std.unicode.utf16leToUtf8Alloc(allocator, buf) catch |err| switch (err) {
                error.DanglingSurrogateHalf => return error.InvalidUtf8,
                error.ExpectedSecondSurrogateHalf => return error.InvalidUtf8,
                error.UnexpectedSecondSurrogateHalf => return error.InvalidUtf8,
                error.OutOfMemory => return error.OutOfMemory,
            };
        }
    } else {
        const result = getEnvPosix(key) orelse return error.EnvironmentVariableNotFound;
        return mem.dupe(allocator, u8, result);
    }
}

test "os.getEnvVarOwned" {
    var ga = debug.global_allocator;
    testing.expectError(error.EnvironmentVariableNotFound, getEnvVarOwned(ga, "BADENV"));
}

/// The result is a slice of `out_buffer`, from index `0`.
pub fn getCwd(out_buffer: *[MAX_PATH_BYTES]u8) ![]u8 {
    return posix.getcwd(out_buffer);
}

/// Caller must free the returned memory.
pub fn getCwdAlloc(allocator: *Allocator) ![]u8 {
    var buf: [os.MAX_PATH_BYTES]u8 = undefined;
    return mem.dupe(allocator, u8, try posix.getcwd(&buf));
}

test "getCwdAlloc" {
    // at least call it so it gets compiled
    var buf: [1000]u8 = undefined;
    const allocator = &std.heap.FixedBufferAllocator.init(&buf).allocator;
    _ = getCwdAlloc(allocator) catch {};
}

// here we replace the standard +/ with -_ so that it can be used in a file name
const b64_fs_encoder = base64.Base64Encoder.init("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_", base64.standard_pad_char);

/// TODO remove the allocator requirement from this API
pub fn atomicSymLink(allocator: *Allocator, existing_path: []const u8, new_path: []const u8) !void {
    if (symLink(existing_path, new_path)) {
        return;
    } else |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err, // TODO zig should know this set does not include PathAlreadyExists
    }

    const dirname = os.path.dirname(new_path) orelse ".";

    var rand_buf: [12]u8 = undefined;
    const tmp_path = try allocator.alloc(u8, dirname.len + 1 + base64.Base64Encoder.calcSize(rand_buf.len));
    defer allocator.free(tmp_path);
    mem.copy(u8, tmp_path[0..], dirname);
    tmp_path[dirname.len] = os.path.sep;
    while (true) {
        try getRandomBytes(rand_buf[0..]);
        b64_fs_encoder.encode(tmp_path[dirname.len + 1 ..], rand_buf);

        if (symLink(existing_path, tmp_path)) {
            return rename(tmp_path, new_path);
        } else |err| switch (err) {
            error.PathAlreadyExists => continue,
            else => return err, // TODO zig should know this set does not include PathAlreadyExists
        }
    }
}

/// Guaranteed to be atomic. However until https://patchwork.kernel.org/patch/9636735/ is
/// merged and readily available,
/// there is a possibility of power loss or application termination leaving temporary files present
/// in the same directory as dest_path.
/// Destination file will have the same mode as the source file.
pub fn copyFile(source_path: []const u8, dest_path: []const u8) !void {
    var in_file = try os.File.openRead(source_path);
    defer in_file.close();

    const mode = try in_file.mode();
    const in_stream = &in_file.inStream().stream;

    var atomic_file = try AtomicFile.init(dest_path, mode);
    defer atomic_file.deinit();

    var buf: [page_size]u8 = undefined;
    while (true) {
        const amt = try in_stream.readFull(buf[0..]);
        try atomic_file.file.write(buf[0..amt]);
        if (amt != buf.len) {
            return atomic_file.finish();
        }
    }
}

/// Guaranteed to be atomic. However until https://patchwork.kernel.org/patch/9636735/ is
/// merged and readily available,
/// there is a possibility of power loss or application termination leaving temporary files present
pub fn copyFileMode(source_path: []const u8, dest_path: []const u8, mode: File.Mode) !void {
    var in_file = try os.File.openRead(source_path);
    defer in_file.close();

    var atomic_file = try AtomicFile.init(dest_path, mode);
    defer atomic_file.deinit();

    var buf: [page_size]u8 = undefined;
    while (true) {
        const amt = try in_file.read(buf[0..]);
        try atomic_file.file.write(buf[0..amt]);
        if (amt != buf.len) {
            return atomic_file.finish();
        }
    }
}

pub const AtomicFile = struct {
    file: os.File,
    tmp_path_buf: [MAX_PATH_BYTES]u8,
    dest_path: []const u8,
    finished: bool,

    const InitError = os.File.OpenError;

    /// dest_path must remain valid for the lifetime of AtomicFile
    /// call finish to atomically replace dest_path with contents
    /// TODO once we have null terminated pointers, use the
    /// openWriteNoClobberN function
    pub fn init(dest_path: []const u8, mode: File.Mode) InitError!AtomicFile {
        const dirname = os.path.dirname(dest_path);
        var rand_buf: [12]u8 = undefined;
        const dirname_component_len = if (dirname) |d| d.len + 1 else 0;
        const encoded_rand_len = comptime base64.Base64Encoder.calcSize(rand_buf.len);
        const tmp_path_len = dirname_component_len + encoded_rand_len;
        var tmp_path_buf: [MAX_PATH_BYTES]u8 = undefined;
        if (tmp_path_len >= tmp_path_buf.len) return error.NameTooLong;

        if (dirname) |dir| {
            mem.copy(u8, tmp_path_buf[0..], dir);
            tmp_path_buf[dir.len] = os.path.sep;
        }

        tmp_path_buf[tmp_path_len] = 0;

        while (true) {
            try getRandomBytes(rand_buf[0..]);
            b64_fs_encoder.encode(tmp_path_buf[dirname_component_len..tmp_path_len], rand_buf);

            const file = os.File.openWriteNoClobberC(&tmp_path_buf, mode) catch |err| switch (err) {
                error.PathAlreadyExists => continue,
                // TODO zig should figure out that this error set does not include PathAlreadyExists since
                // it is handled in the above switch
                else => return err,
            };

            return AtomicFile{
                .file = file,
                .tmp_path_buf = tmp_path_buf,
                .dest_path = dest_path,
                .finished = false,
            };
        }
    }

    /// always call deinit, even after successful finish()
    pub fn deinit(self: *AtomicFile) void {
        if (!self.finished) {
            self.file.close();
            deleteFileC(&self.tmp_path_buf) catch {};
            self.finished = true;
        }
    }

    pub fn finish(self: *AtomicFile) !void {
        assert(!self.finished);
        self.file.close();
        self.finished = true;
        if (is_posix) {
            const dest_path_c = try toPosixPath(self.dest_path);
            return renameC(&self.tmp_path_buf, &dest_path_c);
        } else if (is_windows) {
            const dest_path_w = try posix.sliceToPrefixedFileW(self.dest_path);
            const tmp_path_w = try posix.cStrToPrefixedFileW(&self.tmp_path_buf);
            return renameW(&tmp_path_w, &dest_path_w);
        } else {
            @compileError("Unsupported OS");
        }
    }
};

const default_new_dir_mode = 0o755;

/// Create a new directory.
pub fn makeDir(dir_path: []const u8) !void {
    return posix.mkdir(dir_path, default_new_dir_mode);
}

/// Same as `makeDir` except the parameter is a null-terminated UTF8-encoded string.
pub fn makeDirC(dir_path: [*]const u8) !void {
    return posix.mkdirC(dir_path, default_new_dir_mode);
}

/// Same as `makeDir` except the parameter is a null-terminated UTF16LE-encoded string.
pub fn makeDirW(dir_path: [*]const u16) !void {
    return posix.mkdirW(dir_path, default_new_dir_mode);
}

/// Calls makeDir recursively to make an entire path. Returns success if the path
/// already exists and is a directory.
/// This function is not atomic, and if it returns an error, the file system may
/// have been modified regardless.
/// TODO determine if we can remove the allocator requirement from this function
pub fn makePath(allocator: *Allocator, full_path: []const u8) !void {
    const resolved_path = try path.resolve(allocator, [][]const u8{full_path});
    defer allocator.free(resolved_path);

    var end_index: usize = resolved_path.len;
    while (true) {
        makeDir(resolved_path[0..end_index]) catch |err| switch (err) {
            error.PathAlreadyExists => {
                // TODO stat the file and return an error if it's not a directory
                // this is important because otherwise a dangling symlink
                // could cause an infinite loop
                if (end_index == resolved_path.len) return;
            },
            error.FileNotFound => {
                // march end_index backward until next path component
                while (true) {
                    end_index -= 1;
                    if (os.path.isSep(resolved_path[end_index])) break;
                }
                continue;
            },
            else => return err,
        };
        if (end_index == resolved_path.len) return;
        // march end_index forward until next path component
        while (true) {
            end_index += 1;
            if (end_index == resolved_path.len or os.path.isSep(resolved_path[end_index])) break;
        }
    }
}

/// Returns `error.DirNotEmpty` if the directory is not empty.
/// To delete a directory recursively, see `deleteTree`.
pub fn deleteDir(dir_path: []const u8) DeleteDirError!void {
    return posix.rmdir(dir_path);
}

/// Same as `deleteDir` except the parameter is a null-terminated UTF8-encoded string.
pub fn deleteDirC(dir_path: [*]const u8) DeleteDirError!void {
    return posix.rmdirC(dir_path);
}

/// Same as `deleteDir` except the parameter is a null-terminated UTF16LE-encoded string.
pub fn deleteDirW(dir_path: [*]const u16) DeleteDirError!void {
    return posix.rmdirW(dir_path);
}

/// Whether ::full_path describes a symlink, file, or directory, this function
/// removes it. If it cannot be removed because it is a non-empty directory,
/// this function recursively removes its entries and then tries again.
const DeleteTreeError = error{
    OutOfMemory,
    AccessDenied,
    FileTooBig,
    IsDir,
    SymLinkLoop,
    ProcessFdQuotaExceeded,
    NameTooLong,
    SystemFdQuotaExceeded,
    NoDevice,
    SystemResources,
    NoSpaceLeft,
    PathAlreadyExists,
    ReadOnlyFileSystem,
    NotDir,
    FileNotFound,
    FileSystem,
    FileBusy,
    DirNotEmpty,
    DeviceBusy,

    /// On Windows, file paths must be valid Unicode.
    InvalidUtf8,

    /// On Windows, file paths cannot contain these characters:
    /// '/', '*', '?', '"', '<', '>', '|'
    BadPathName,

    Unexpected,
};

/// TODO determine if we can remove the allocator requirement
pub fn deleteTree(allocator: *Allocator, full_path: []const u8) DeleteTreeError!void {
    start_over: while (true) {
        var got_access_denied = false;
        // First, try deleting the item as a file. This way we don't follow sym links.
        if (deleteFile(full_path)) {
            return;
        } else |err| switch (err) {
            error.FileNotFound => return,
            error.IsDir => {},
            error.AccessDenied => got_access_denied = true,

            error.InvalidUtf8,
            error.SymLinkLoop,
            error.NameTooLong,
            error.SystemResources,
            error.ReadOnlyFileSystem,
            error.NotDir,
            error.FileSystem,
            error.FileBusy,
            error.BadPathName,
            error.Unexpected,
            => return err,
        }
        {
            var dir = Dir.open(allocator, full_path) catch |err| switch (err) {
                error.NotDir => {
                    if (got_access_denied) {
                        return error.AccessDenied;
                    }
                    continue :start_over;
                },

                error.OutOfMemory,
                error.AccessDenied,
                error.FileTooBig,
                error.IsDir,
                error.SymLinkLoop,
                error.ProcessFdQuotaExceeded,
                error.NameTooLong,
                error.SystemFdQuotaExceeded,
                error.NoDevice,
                error.FileNotFound,
                error.SystemResources,
                error.NoSpaceLeft,
                error.PathAlreadyExists,
                error.Unexpected,
                error.InvalidUtf8,
                error.BadPathName,
                error.DeviceBusy,
                => return err,
            };
            defer dir.close();

            var full_entry_buf = ArrayList(u8).init(allocator);
            defer full_entry_buf.deinit();

            while (try dir.next()) |entry| {
                try full_entry_buf.resize(full_path.len + entry.name.len + 1);
                const full_entry_path = full_entry_buf.toSlice();
                mem.copy(u8, full_entry_path, full_path);
                full_entry_path[full_path.len] = path.sep;
                mem.copy(u8, full_entry_path[full_path.len + 1 ..], entry.name);

                try deleteTree(allocator, full_entry_path);
            }
        }
        return deleteDir(full_path);
    }
}

pub const Dir = struct {
    handle: Handle,
    allocator: *Allocator,

    pub const Handle = switch (builtin.os) {
        Os.macosx, Os.ios, Os.freebsd, Os.netbsd => struct {
            fd: i32,
            seek: i64,
            buf: []u8,
            index: usize,
            end_index: usize,
        },
        Os.linux => struct {
            fd: i32,
            buf: []u8,
            index: usize,
            end_index: usize,
        },
        Os.windows => struct {
            handle: windows.HANDLE,
            find_file_data: windows.WIN32_FIND_DATAW,
            first: bool,
            name_data: [256]u8,
        },
        else => @compileError("unimplemented"),
    };

    pub const Entry = struct {
        name: []const u8,
        kind: Kind,

        pub const Kind = enum {
            BlockDevice,
            CharacterDevice,
            Directory,
            NamedPipe,
            SymLink,
            File,
            UnixDomainSocket,
            Whiteout,
            Unknown,
        };
    };

    pub const OpenError = error{
        FileNotFound,
        NotDir,
        AccessDenied,
        FileTooBig,
        IsDir,
        SymLinkLoop,
        ProcessFdQuotaExceeded,
        NameTooLong,
        SystemFdQuotaExceeded,
        NoDevice,
        SystemResources,
        NoSpaceLeft,
        PathAlreadyExists,
        OutOfMemory,
        InvalidUtf8,
        BadPathName,
        DeviceBusy,

        Unexpected,
    };

    /// TODO remove the allocator requirement from this API
    pub fn open(allocator: *Allocator, dir_path: []const u8) OpenError!Dir {
        return Dir{
            .allocator = allocator,
            .handle = switch (builtin.os) {
                Os.windows => blk: {
                    var find_file_data: windows.WIN32_FIND_DATAW = undefined;
                    const handle = try windows_util.windowsFindFirstFile(dir_path, &find_file_data);
                    break :blk Handle{
                        .handle = handle,
                        .find_file_data = find_file_data, // TODO guaranteed copy elision
                        .first = true,
                        .name_data = undefined,
                    };
                },
                Os.macosx, Os.ios, Os.freebsd, Os.netbsd => Handle{
                    .fd = try posixOpen(
                        dir_path,
                        posix.O_RDONLY | posix.O_NONBLOCK | posix.O_DIRECTORY | posix.O_CLOEXEC,
                        0,
                    ),
                    .seek = 0,
                    .index = 0,
                    .end_index = 0,
                    .buf = []u8{},
                },
                Os.linux => Handle{
                    .fd = try posixOpen(
                        dir_path,
                        posix.O_RDONLY | posix.O_DIRECTORY | posix.O_CLOEXEC,
                        0,
                    ),
                    .index = 0,
                    .end_index = 0,
                    .buf = []u8{},
                },
                else => @compileError("unimplemented"),
            },
        };
    }

    pub fn close(self: *Dir) void {
        switch (builtin.os) {
            Os.windows => {
                _ = windows.FindClose(self.handle.handle);
            },
            Os.macosx, Os.ios, Os.linux, Os.freebsd, Os.netbsd => {
                self.allocator.free(self.handle.buf);
                os.close(self.handle.fd);
            },
            else => @compileError("unimplemented"),
        }
    }

    /// Memory such as file names referenced in this returned entry becomes invalid
    /// with subsequent calls to next, as well as when this `Dir` is deinitialized.
    pub fn next(self: *Dir) !?Entry {
        switch (builtin.os) {
            Os.linux => return self.nextLinux(),
            Os.macosx, Os.ios => return self.nextDarwin(),
            Os.windows => return self.nextWindows(),
            Os.freebsd => return self.nextFreebsd(),
            Os.netbsd => return self.nextFreebsd(),
            else => @compileError("unimplemented"),
        }
    }

    fn nextDarwin(self: *Dir) !?Entry {
        start_over: while (true) {
            if (self.handle.index >= self.handle.end_index) {
                if (self.handle.buf.len == 0) {
                    self.handle.buf = try self.allocator.alloc(u8, page_size);
                }

                while (true) {
                    const result = system.__getdirentries64(self.handle.fd, self.handle.buf.ptr, self.handle.buf.len, &self.handle.seek);
                    if (result == 0) return null;
                    if (result < 0) {
                        switch (system.getErrno(result)) {
                            posix.EBADF => unreachable,
                            posix.EFAULT => unreachable,
                            posix.ENOTDIR => unreachable,
                            posix.EINVAL => {
                                self.handle.buf = try self.allocator.realloc(self.handle.buf, self.handle.buf.len * 2);
                                continue;
                            },
                            else => return unexpectedErrorPosix(err),
                        }
                    }
                    self.handle.index = 0;
                    self.handle.end_index = @intCast(usize, result);
                    break;
                }
            }
            const darwin_entry = @ptrCast(*align(1) posix.dirent, &self.handle.buf[self.handle.index]);
            const next_index = self.handle.index + darwin_entry.d_reclen;
            self.handle.index = next_index;

            const name = @ptrCast([*]u8, &darwin_entry.d_name)[0..darwin_entry.d_namlen];

            if (mem.eql(u8, name, ".") or mem.eql(u8, name, "..")) {
                continue :start_over;
            }

            const entry_kind = switch (darwin_entry.d_type) {
                posix.DT_BLK => Entry.Kind.BlockDevice,
                posix.DT_CHR => Entry.Kind.CharacterDevice,
                posix.DT_DIR => Entry.Kind.Directory,
                posix.DT_FIFO => Entry.Kind.NamedPipe,
                posix.DT_LNK => Entry.Kind.SymLink,
                posix.DT_REG => Entry.Kind.File,
                posix.DT_SOCK => Entry.Kind.UnixDomainSocket,
                posix.DT_WHT => Entry.Kind.Whiteout,
                else => Entry.Kind.Unknown,
            };
            return Entry{
                .name = name,
                .kind = entry_kind,
            };
        }
    }

    fn nextWindows(self: *Dir) !?Entry {
        while (true) {
            if (self.handle.first) {
                self.handle.first = false;
            } else {
                if (!try windows_util.windowsFindNextFile(self.handle.handle, &self.handle.find_file_data))
                    return null;
            }
            const name_utf16le = mem.toSlice(u16, self.handle.find_file_data.cFileName[0..].ptr);
            if (mem.eql(u16, name_utf16le, []u16{'.'}) or mem.eql(u16, name_utf16le, []u16{ '.', '.' }))
                continue;
            // Trust that Windows gives us valid UTF-16LE
            const name_utf8_len = std.unicode.utf16leToUtf8(self.handle.name_data[0..], name_utf16le) catch unreachable;
            const name_utf8 = self.handle.name_data[0..name_utf8_len];
            const kind = blk: {
                const attrs = self.handle.find_file_data.dwFileAttributes;
                if (attrs & windows.FILE_ATTRIBUTE_DIRECTORY != 0) break :blk Entry.Kind.Directory;
                if (attrs & windows.FILE_ATTRIBUTE_REPARSE_POINT != 0) break :blk Entry.Kind.SymLink;
                if (attrs & windows.FILE_ATTRIBUTE_NORMAL != 0) break :blk Entry.Kind.File;
                break :blk Entry.Kind.Unknown;
            };
            return Entry{
                .name = name_utf8,
                .kind = kind,
            };
        }
    }

    fn nextLinux(self: *Dir) !?Entry {
        start_over: while (true) {
            if (self.handle.index >= self.handle.end_index) {
                if (self.handle.buf.len == 0) {
                    self.handle.buf = try self.allocator.alloc(u8, page_size);
                }

                while (true) {
                    const result = posix.getdents64(self.handle.fd, self.handle.buf.ptr, self.handle.buf.len);
                    const err = posix.getErrno(result);
                    if (err > 0) {
                        switch (err) {
                            posix.EBADF, posix.EFAULT, posix.ENOTDIR => unreachable,
                            posix.EINVAL => {
                                self.handle.buf = try self.allocator.realloc(self.handle.buf, self.handle.buf.len * 2);
                                continue;
                            },
                            else => return unexpectedErrorPosix(err),
                        }
                    }
                    if (result == 0) return null;
                    self.handle.index = 0;
                    self.handle.end_index = result;
                    break;
                }
            }
            const linux_entry = @ptrCast(*align(1) posix.dirent64, &self.handle.buf[self.handle.index]);
            const next_index = self.handle.index + linux_entry.d_reclen;
            self.handle.index = next_index;

            const name = cstr.toSlice(@ptrCast([*]u8, &linux_entry.d_name));

            // skip . and .. entries
            if (mem.eql(u8, name, ".") or mem.eql(u8, name, "..")) {
                continue :start_over;
            }

            const entry_kind = switch (linux_entry.d_type) {
                posix.DT_BLK => Entry.Kind.BlockDevice,
                posix.DT_CHR => Entry.Kind.CharacterDevice,
                posix.DT_DIR => Entry.Kind.Directory,
                posix.DT_FIFO => Entry.Kind.NamedPipe,
                posix.DT_LNK => Entry.Kind.SymLink,
                posix.DT_REG => Entry.Kind.File,
                posix.DT_SOCK => Entry.Kind.UnixDomainSocket,
                else => Entry.Kind.Unknown,
            };
            return Entry{
                .name = name,
                .kind = entry_kind,
            };
        }
    }

    fn nextFreebsd(self: *Dir) !?Entry {
        start_over: while (true) {
            if (self.handle.index >= self.handle.end_index) {
                if (self.handle.buf.len == 0) {
                    self.handle.buf = try self.allocator.alloc(u8, page_size);
                }

                while (true) {
                    const result = posix.getdirentries(self.handle.fd, self.handle.buf.ptr, self.handle.buf.len, &self.handle.seek);
                    const err = posix.getErrno(result);
                    if (err > 0) {
                        switch (err) {
                            posix.EBADF, posix.EFAULT, posix.ENOTDIR => unreachable,
                            posix.EINVAL => {
                                self.handle.buf = try self.allocator.realloc(self.handle.buf, self.handle.buf.len * 2);
                                continue;
                            },
                            else => return unexpectedErrorPosix(err),
                        }
                    }
                    if (result == 0) return null;
                    self.handle.index = 0;
                    self.handle.end_index = result;
                    break;
                }
            }
            const freebsd_entry = @ptrCast(*align(1) posix.dirent, &self.handle.buf[self.handle.index]);
            const next_index = self.handle.index + freebsd_entry.d_reclen;
            self.handle.index = next_index;

            const name = @ptrCast([*]u8, &freebsd_entry.d_name)[0..freebsd_entry.d_namlen];

            if (mem.eql(u8, name, ".") or mem.eql(u8, name, "..")) {
                continue :start_over;
            }

            const entry_kind = switch (freebsd_entry.d_type) {
                posix.DT_BLK => Entry.Kind.BlockDevice,
                posix.DT_CHR => Entry.Kind.CharacterDevice,
                posix.DT_DIR => Entry.Kind.Directory,
                posix.DT_FIFO => Entry.Kind.NamedPipe,
                posix.DT_LNK => Entry.Kind.SymLink,
                posix.DT_REG => Entry.Kind.File,
                posix.DT_SOCK => Entry.Kind.UnixDomainSocket,
                posix.DT_WHT => Entry.Kind.Whiteout,
                else => Entry.Kind.Unknown,
            };
            return Entry{
                .name = name,
                .kind = entry_kind,
            };
        }
    }
};

/// Read value of a symbolic link.
/// The return value is a slice of buffer, from index `0`.
pub fn readLink(buffer: *[posix.PATH_MAX]u8, pathname: []const u8) ![]u8 {
    return posix.readlink(pathname, buffer);
}

/// Same as `readLink`, except the `pathname` parameter is null-terminated.
pub fn readLinkC(buffer: *[posix.PATH_MAX]u8, pathname: [*]const u8) ![]u8 {
    return posix.readlinkC(pathname, buffer);
}

pub const ArgIteratorPosix = struct {
    index: usize,
    count: usize,

    pub fn init() ArgIteratorPosix {
        return ArgIteratorPosix{
            .index = 0,
            .count = raw.len,
        };
    }

    pub fn next(self: *ArgIteratorPosix) ?[]const u8 {
        if (self.index == self.count) return null;

        const s = raw[self.index];
        self.index += 1;
        return cstr.toSlice(s);
    }

    pub fn skip(self: *ArgIteratorPosix) bool {
        if (self.index == self.count) return false;

        self.index += 1;
        return true;
    }

    /// This is marked as public but actually it's only meant to be used
    /// internally by zig's startup code.
    pub var raw: [][*]u8 = undefined;
};

pub const ArgIteratorWindows = struct {
    index: usize,
    cmd_line: [*]const u8,
    in_quote: bool,
    quote_count: usize,
    seen_quote_count: usize,

    pub const NextError = error{OutOfMemory};

    pub fn init() ArgIteratorWindows {
        return initWithCmdLine(windows.GetCommandLineA());
    }

    pub fn initWithCmdLine(cmd_line: [*]const u8) ArgIteratorWindows {
        return ArgIteratorWindows{
            .index = 0,
            .cmd_line = cmd_line,
            .in_quote = false,
            .quote_count = countQuotes(cmd_line),
            .seen_quote_count = 0,
        };
    }

    /// You must free the returned memory when done.
    pub fn next(self: *ArgIteratorWindows, allocator: *Allocator) ?(NextError![]u8) {
        // march forward over whitespace
        while (true) : (self.index += 1) {
            const byte = self.cmd_line[self.index];
            switch (byte) {
                0 => return null,
                ' ', '\t' => continue,
                else => break,
            }
        }

        return self.internalNext(allocator);
    }

    pub fn skip(self: *ArgIteratorWindows) bool {
        // march forward over whitespace
        while (true) : (self.index += 1) {
            const byte = self.cmd_line[self.index];
            switch (byte) {
                0 => return false,
                ' ', '\t' => continue,
                else => break,
            }
        }

        var backslash_count: usize = 0;
        while (true) : (self.index += 1) {
            const byte = self.cmd_line[self.index];
            switch (byte) {
                0 => return true,
                '"' => {
                    const quote_is_real = backslash_count % 2 == 0;
                    if (quote_is_real) {
                        self.seen_quote_count += 1;
                    }
                },
                '\\' => {
                    backslash_count += 1;
                },
                ' ', '\t' => {
                    if (self.seen_quote_count % 2 == 0 or self.seen_quote_count == self.quote_count) {
                        return true;
                    }
                    backslash_count = 0;
                },
                else => {
                    backslash_count = 0;
                    continue;
                },
            }
        }
    }

    fn internalNext(self: *ArgIteratorWindows, allocator: *Allocator) NextError![]u8 {
        var buf = try Buffer.initSize(allocator, 0);
        defer buf.deinit();

        var backslash_count: usize = 0;
        while (true) : (self.index += 1) {
            const byte = self.cmd_line[self.index];
            switch (byte) {
                0 => return buf.toOwnedSlice(),
                '"' => {
                    const quote_is_real = backslash_count % 2 == 0;
                    try self.emitBackslashes(&buf, backslash_count / 2);
                    backslash_count = 0;

                    if (quote_is_real) {
                        self.seen_quote_count += 1;
                        if (self.seen_quote_count == self.quote_count and self.seen_quote_count % 2 == 1) {
                            try buf.appendByte('"');
                        }
                    } else {
                        try buf.appendByte('"');
                    }
                },
                '\\' => {
                    backslash_count += 1;
                },
                ' ', '\t' => {
                    try self.emitBackslashes(&buf, backslash_count);
                    backslash_count = 0;
                    if (self.seen_quote_count % 2 == 1 and self.seen_quote_count != self.quote_count) {
                        try buf.appendByte(byte);
                    } else {
                        return buf.toOwnedSlice();
                    }
                },
                else => {
                    try self.emitBackslashes(&buf, backslash_count);
                    backslash_count = 0;
                    try buf.appendByte(byte);
                },
            }
        }
    }

    fn emitBackslashes(self: *ArgIteratorWindows, buf: *Buffer, emit_count: usize) !void {
        var i: usize = 0;
        while (i < emit_count) : (i += 1) {
            try buf.appendByte('\\');
        }
    }

    fn countQuotes(cmd_line: [*]const u8) usize {
        var result: usize = 0;
        var backslash_count: usize = 0;
        var index: usize = 0;
        while (true) : (index += 1) {
            const byte = cmd_line[index];
            switch (byte) {
                0 => return result,
                '\\' => backslash_count += 1,
                '"' => {
                    result += 1 - (backslash_count % 2);
                    backslash_count = 0;
                },
                else => {
                    backslash_count = 0;
                },
            }
        }
    }
};

pub const ArgIterator = struct {
    const InnerType = if (builtin.os == Os.windows) ArgIteratorWindows else ArgIteratorPosix;

    inner: InnerType,

    pub fn init() ArgIterator {
        if (builtin.os == Os.wasi) {
            // TODO: Figure out a compatible interface accomodating WASI
            @compileError("ArgIterator is not yet supported in WASI. Use argsAlloc and argsFree instead.");
        }

        return ArgIterator{ .inner = InnerType.init() };
    }

    pub const NextError = ArgIteratorWindows.NextError;

    /// You must free the returned memory when done.
    pub fn next(self: *ArgIterator, allocator: *Allocator) ?(NextError![]u8) {
        if (builtin.os == Os.windows) {
            return self.inner.next(allocator);
        } else {
            return mem.dupe(allocator, u8, self.inner.next() orelse return null);
        }
    }

    /// If you only are targeting posix you can call this and not need an allocator.
    pub fn nextPosix(self: *ArgIterator) ?[]const u8 {
        return self.inner.next();
    }

    /// Parse past 1 argument without capturing it.
    /// Returns `true` if skipped an arg, `false` if we are at the end.
    pub fn skip(self: *ArgIterator) bool {
        return self.inner.skip();
    }
};

pub fn args() ArgIterator {
    return ArgIterator.init();
}

/// Caller must call argsFree on result.
pub fn argsAlloc(allocator: *mem.Allocator) ![]const []u8 {
    if (builtin.os == Os.wasi) {
        var count: usize = undefined;
        var buf_size: usize = undefined;

        const args_sizes_get_ret = os.wasi.args_sizes_get(&count, &buf_size);
        if (args_sizes_get_ret != os.wasi.ESUCCESS) {
            return unexpectedErrorPosix(args_sizes_get_ret);
        }

        var argv = try allocator.alloc([*]u8, count);
        defer allocator.free(argv);

        var argv_buf = try allocator.alloc(u8, buf_size);
        const args_get_ret = os.wasi.args_get(argv.ptr, argv_buf.ptr);
        if (args_get_ret != os.wasi.ESUCCESS) {
            return unexpectedErrorPosix(args_get_ret);
        }

        var result_slice = try allocator.alloc([]u8, count);

        var i: usize = 0;
        while (i < count) : (i += 1) {
            result_slice[i] = mem.toSlice(u8, argv[i]);
        }

        return result_slice;
    }

    // TODO refactor to only make 1 allocation.
    var it = args();
    var contents = try Buffer.initSize(allocator, 0);
    defer contents.deinit();

    var slice_list = ArrayList(usize).init(allocator);
    defer slice_list.deinit();

    while (it.next(allocator)) |arg_or_err| {
        const arg = try arg_or_err;
        defer allocator.free(arg);
        try contents.append(arg);
        try slice_list.append(arg.len);
    }

    const contents_slice = contents.toSliceConst();
    const slice_sizes = slice_list.toSliceConst();
    const slice_list_bytes = try math.mul(usize, @sizeOf([]u8), slice_sizes.len);
    const total_bytes = try math.add(usize, slice_list_bytes, contents_slice.len);
    const buf = try allocator.alignedAlloc(u8, @alignOf([]u8), total_bytes);
    errdefer allocator.free(buf);

    const result_slice_list = @bytesToSlice([]u8, buf[0..slice_list_bytes]);
    const result_contents = buf[slice_list_bytes..];
    mem.copy(u8, result_contents, contents_slice);

    var contents_index: usize = 0;
    for (slice_sizes) |len, i| {
        const new_index = contents_index + len;
        result_slice_list[i] = result_contents[contents_index..new_index];
        contents_index = new_index;
    }

    return result_slice_list;
}

pub fn argsFree(allocator: *mem.Allocator, args_alloc: []const []u8) void {
    if (builtin.os == Os.wasi) {
        const last_item = args_alloc[args_alloc.len - 1];
        const last_byte_addr = @ptrToInt(last_item.ptr) + last_item.len + 1; // null terminated
        const first_item_ptr = args_alloc[0].ptr;
        const len = last_byte_addr - @ptrToInt(first_item_ptr);
        allocator.free(first_item_ptr[0..len]);

        return allocator.free(args_alloc);
    }

    var total_bytes: usize = 0;
    for (args_alloc) |arg| {
        total_bytes += @sizeOf([]u8) + arg.len;
    }
    const unaligned_allocated_buf = @ptrCast([*]const u8, args_alloc.ptr)[0..total_bytes];
    const aligned_allocated_buf = @alignCast(@alignOf([]u8), unaligned_allocated_buf);
    return allocator.free(aligned_allocated_buf);
}

test "windows arg parsing" {
    testWindowsCmdLine(c"a   b\tc d", [][]const u8{ "a", "b", "c", "d" });
    testWindowsCmdLine(c"\"abc\" d e", [][]const u8{ "abc", "d", "e" });
    testWindowsCmdLine(c"a\\\\\\b d\"e f\"g h", [][]const u8{ "a\\\\\\b", "de fg", "h" });
    testWindowsCmdLine(c"a\\\\\\\"b c d", [][]const u8{ "a\\\"b", "c", "d" });
    testWindowsCmdLine(c"a\\\\\\\\\"b c\" d e", [][]const u8{ "a\\\\b c", "d", "e" });
    testWindowsCmdLine(c"a   b\tc \"d f", [][]const u8{ "a", "b", "c", "\"d", "f" });

    testWindowsCmdLine(c"\".\\..\\zig-cache\\build\" \"bin\\zig.exe\" \".\\..\" \".\\..\\zig-cache\" \"--help\"", [][]const u8{
        ".\\..\\zig-cache\\build",
        "bin\\zig.exe",
        ".\\..",
        ".\\..\\zig-cache",
        "--help",
    });
}

fn testWindowsCmdLine(input_cmd_line: [*]const u8, expected_args: []const []const u8) void {
    var it = ArgIteratorWindows.initWithCmdLine(input_cmd_line);
    for (expected_args) |expected_arg| {
        const arg = it.next(debug.global_allocator).? catch unreachable;
        testing.expectEqualSlices(u8, expected_arg, arg);
    }
    testing.expect(it.next(debug.global_allocator) == null);
}

pub fn openSelfExe() !os.File {
    switch (builtin.os) {
        Os.linux => return os.File.openReadC(c"/proc/self/exe"),
        Os.macosx, Os.ios, Os.freebsd, Os.netbsd => {
            var buf: [MAX_PATH_BYTES]u8 = undefined;
            const self_exe_path = try selfExePath(&buf);
            buf[self_exe_path.len] = 0;
            return os.File.openReadC(self_exe_path.ptr);
        },
        Os.windows => {
            var buf: [posix.PATH_MAX_WIDE]u16 = undefined;
            const wide_slice = try selfExePathW(&buf);
            return os.File.openReadW(wide_slice.ptr);
        },
        else => @compileError("Unsupported OS"),
    }
}

test "openSelfExe" {
    switch (builtin.os) {
        Os.linux, Os.macosx, Os.ios, Os.windows, Os.freebsd => (try openSelfExe()).close(),
        else => return error.SkipZigTest, // Unsupported OS.
    }
}

pub fn selfExePathW(out_buffer: *[posix.PATH_MAX_WIDE]u16) ![]u16 {
    const casted_len = @intCast(windows.DWORD, out_buffer.len); // TODO shouldn't need this cast
    const rc = windows.GetModuleFileNameW(null, out_buffer, casted_len);
    assert(rc <= out_buffer.len);
    if (rc == 0) {
        const err = windows.GetLastError();
        switch (err) {
            else => return unexpectedErrorWindows(err),
        }
    }
    return out_buffer[0..rc];
}

/// Get the path to the current executable.
/// If you only need the directory, use selfExeDirPath.
/// If you only want an open file handle, use openSelfExe.
/// This function may return an error if the current executable
/// was deleted after spawning.
/// Returned value is a slice of out_buffer.
///
/// On Linux, depends on procfs being mounted. If the currently executing binary has
/// been deleted, the file path looks something like `/a/b/c/exe (deleted)`.
/// TODO make the return type of this a null terminated pointer
pub fn selfExePath(out_buffer: *[MAX_PATH_BYTES]u8) ![]u8 {
    switch (builtin.os) {
        Os.linux => return readLink(out_buffer, "/proc/self/exe"),
        Os.freebsd => {
            var mib = [4]c_int{ posix.CTL_KERN, posix.KERN_PROC, posix.KERN_PROC_PATHNAME, -1 };
            var out_len: usize = out_buffer.len;
            try posix.sysctl(&mib, out_buffer, &out_len, null, 0);
            // TODO could this slice from 0 to out_len instead?
            return mem.toSlice(u8, out_buffer);
        },
        Os.netbsd => {
            var mib = [4]c_int{ posix.CTL_KERN, posix.KERN_PROC_ARGS, -1, posix.KERN_PROC_PATHNAME };
            var out_len: usize = out_buffer.len;
            try posix.sysctl(&mib, out_buffer, &out_len, null, 0);
            // TODO could this slice from 0 to out_len instead?
            return mem.toSlice(u8, out_buffer);
        },
        Os.windows => {
            var utf16le_buf: [posix.PATH_MAX_WIDE]u16 = undefined;
            const utf16le_slice = try selfExePathW(&utf16le_buf);
            // Trust that Windows gives us valid UTF-16LE.
            const end_index = std.unicode.utf16leToUtf8(out_buffer, utf16le_slice) catch unreachable;
            return out_buffer[0..end_index];
        },
        Os.macosx, Os.ios => {
            var u32_len: u32 = @intCast(u32, out_buffer.len); // TODO shouldn't need this cast
            const rc = c._NSGetExecutablePath(out_buffer, &u32_len);
            if (rc != 0) return error.NameTooLong;
            return mem.toSlice(u8, out_buffer);
        },
        else => @compileError("Unsupported OS"),
    }
}

/// `selfExeDirPath` except allocates the result on the heap.
/// Caller owns returned memory.
pub fn selfExeDirPathAlloc(allocator: *Allocator) ![]u8 {
    var buf: [MAX_PATH_BYTES]u8 = undefined;
    return mem.dupe(allocator, u8, try selfExeDirPath(&buf));
}

/// Get the directory path that contains the current executable.
/// Returned value is a slice of out_buffer.
pub fn selfExeDirPath(out_buffer: *[MAX_PATH_BYTES]u8) ![]const u8 {
    switch (builtin.os) {
        Os.linux => {
            // If the currently executing binary has been deleted,
            // the file path looks something like `/a/b/c/exe (deleted)`
            // This path cannot be opened, but it's valid for determining the directory
            // the executable was in when it was run.
            const full_exe_path = try readLinkC(out_buffer, c"/proc/self/exe");
            // Assume that /proc/self/exe has an absolute path, and therefore dirname
            // will not return null.
            return path.dirname(full_exe_path).?;
        },
        Os.windows, Os.macosx, Os.ios, Os.freebsd, Os.netbsd => {
            const self_exe_path = try selfExePath(out_buffer);
            // Assume that the OS APIs return absolute paths, and therefore dirname
            // will not return null.
            return path.dirname(self_exe_path).?;
        },
        else => @compileError("Unsupported OS"),
    }
}

pub const Thread = struct {
    data: Data,

    pub const use_pthreads = is_posix and builtin.link_libc;

    /// Represents a kernel thread handle.
    /// May be an integer or a pointer depending on the platform.
    /// On Linux and POSIX, this is the same as Id.
    pub const Handle = if (use_pthreads)
        c.pthread_t
    else switch (builtin.os) {
        builtin.Os.linux => i32,
        builtin.Os.windows => windows.HANDLE,
        else => @compileError("Unsupported OS"),
    };

    /// Represents a unique ID per thread.
    /// May be an integer or pointer depending on the platform.
    /// On Linux and POSIX, this is the same as Handle.
    pub const Id = switch (builtin.os) {
        builtin.Os.windows => windows.DWORD,
        else => Handle,
    };

    pub const Data = if (use_pthreads)
        struct {
            handle: Thread.Handle,
            mmap_addr: usize,
            mmap_len: usize,
        }
    else switch (builtin.os) {
        builtin.Os.linux => struct {
            handle: Thread.Handle,
            mmap_addr: usize,
            mmap_len: usize,
        },
        builtin.Os.windows => struct {
            handle: Thread.Handle,
            alloc_start: *c_void,
            heap_handle: windows.HANDLE,
        },
        else => @compileError("Unsupported OS"),
    };

    /// Returns the ID of the calling thread.
    /// Makes a syscall every time the function is called.
    /// On Linux and POSIX, this Id is the same as a Handle.
    pub fn getCurrentId() Id {
        if (use_pthreads) {
            return c.pthread_self();
        } else
            return switch (builtin.os) {
            builtin.Os.linux => linux.gettid(),
            builtin.Os.windows => windows.GetCurrentThreadId(),
            else => @compileError("Unsupported OS"),
        };
    }

    /// Returns the handle of this thread.
    /// On Linux and POSIX, this is the same as Id.
    /// On Linux, it is possible that the thread spawned with `spawnThread`
    /// finishes executing entirely before the clone syscall completes. In this
    /// case, this function will return 0 rather than the no-longer-existing thread's
    /// pid.
    pub fn handle(self: Thread) Handle {
        return self.data.handle;
    }

    pub fn wait(self: *const Thread) void {
        if (use_pthreads) {
            const err = c.pthread_join(self.data.handle, null);
            switch (err) {
                0 => {},
                posix.EINVAL => unreachable,
                posix.ESRCH => unreachable,
                posix.EDEADLK => unreachable,
                else => unreachable,
            }
            assert(posix.munmap(self.data.mmap_addr, self.data.mmap_len) == 0);
        } else switch (builtin.os) {
            builtin.Os.linux => {
                while (true) {
                    const pid_value = @atomicLoad(i32, &self.data.handle, .SeqCst);
                    if (pid_value == 0) break;
                    const rc = linux.futex_wait(&self.data.handle, linux.FUTEX_WAIT, pid_value, null);
                    switch (linux.getErrno(rc)) {
                        0 => continue,
                        posix.EINTR => continue,
                        posix.EAGAIN => continue,
                        else => unreachable,
                    }
                }
                assert(posix.munmap(self.data.mmap_addr, self.data.mmap_len) == 0);
            },
            builtin.Os.windows => {
                assert(windows.WaitForSingleObject(self.data.handle, windows.INFINITE) == windows.WAIT_OBJECT_0);
                assert(windows.CloseHandle(self.data.handle) != 0);
                assert(windows.HeapFree(self.data.heap_handle, 0, self.data.alloc_start) != 0);
            },
            else => @compileError("Unsupported OS"),
        }
    }
};

pub const SpawnThreadError = error{
    /// A system-imposed limit on the number of threads was encountered.
    /// There are a number of limits that may trigger this error:
    /// *  the  RLIMIT_NPROC soft resource limit (set via setrlimit(2)),
    ///    which limits the number of processes and threads for  a  real
    ///    user ID, was reached;
    /// *  the kernel's system-wide limit on the number of processes and
    ///    threads,  /proc/sys/kernel/threads-max,  was   reached   (see
    ///    proc(5));
    /// *  the  maximum  number  of  PIDs, /proc/sys/kernel/pid_max, was
    ///    reached (see proc(5)); or
    /// *  the PID limit (pids.max) imposed by the cgroup "process  num‐
    ///    ber" (PIDs) controller was reached.
    ThreadQuotaExceeded,

    /// The kernel cannot allocate sufficient memory to allocate a task structure
    /// for the child, or to copy those parts of the caller's context that need to
    /// be copied.
    SystemResources,

    /// Not enough userland memory to spawn the thread.
    OutOfMemory,

    Unexpected,
};

/// caller must call wait on the returned thread
/// fn startFn(@typeOf(context)) T
/// where T is u8, noreturn, void, or !void
/// caller must call wait on the returned thread
pub fn spawnThread(context: var, comptime startFn: var) SpawnThreadError!*Thread {
    if (builtin.single_threaded) @compileError("cannot spawn thread when building in single-threaded mode");
    // TODO compile-time call graph analysis to determine stack upper bound
    // https://github.com/ziglang/zig/issues/157
    const default_stack_size = 8 * 1024 * 1024;

    const Context = @typeOf(context);
    comptime assert(@ArgType(@typeOf(startFn), 0) == Context);

    if (builtin.os == builtin.Os.windows) {
        const WinThread = struct {
            const OuterContext = struct {
                thread: Thread,
                inner: Context,
            };
            extern fn threadMain(raw_arg: windows.LPVOID) windows.DWORD {
                const arg = if (@sizeOf(Context) == 0) {} else @ptrCast(*Context, @alignCast(@alignOf(Context), raw_arg)).*;
                switch (@typeId(@typeOf(startFn).ReturnType)) {
                    builtin.TypeId.Int => {
                        return startFn(arg);
                    },
                    builtin.TypeId.Void => {
                        startFn(arg);
                        return 0;
                    },
                    else => @compileError("expected return type of startFn to be 'u8', 'noreturn', 'void', or '!void'"),
                }
            }
        };

        const heap_handle = windows.GetProcessHeap() orelse return SpawnThreadError.OutOfMemory;
        const byte_count = @alignOf(WinThread.OuterContext) + @sizeOf(WinThread.OuterContext);
        const bytes_ptr = windows.HeapAlloc(heap_handle, 0, byte_count) orelse return SpawnThreadError.OutOfMemory;
        errdefer assert(windows.HeapFree(heap_handle, 0, bytes_ptr) != 0);
        const bytes = @ptrCast([*]u8, bytes_ptr)[0..byte_count];
        const outer_context = std.heap.FixedBufferAllocator.init(bytes).allocator.create(WinThread.OuterContext) catch unreachable;
        outer_context.* = WinThread.OuterContext{
            .thread = Thread{
                .data = Thread.Data{
                    .heap_handle = heap_handle,
                    .alloc_start = bytes_ptr,
                    .handle = undefined,
                },
            },
            .inner = context,
        };

        const parameter = if (@sizeOf(Context) == 0) null else @ptrCast(*c_void, &outer_context.inner);
        outer_context.thread.data.handle = windows.CreateThread(null, default_stack_size, WinThread.threadMain, parameter, 0, null) orelse {
            const err = windows.GetLastError();
            return switch (err) {
                else => os.unexpectedErrorWindows(err),
            };
        };
        return &outer_context.thread;
    }

    const MainFuncs = struct {
        extern fn linuxThreadMain(ctx_addr: usize) u8 {
            const arg = if (@sizeOf(Context) == 0) {} else @intToPtr(*const Context, ctx_addr).*;

            switch (@typeId(@typeOf(startFn).ReturnType)) {
                builtin.TypeId.Int => {
                    return startFn(arg);
                },
                builtin.TypeId.Void => {
                    startFn(arg);
                    return 0;
                },
                else => @compileError("expected return type of startFn to be 'u8', 'noreturn', 'void', or '!void'"),
            }
        }
        extern fn posixThreadMain(ctx: ?*c_void) ?*c_void {
            if (@sizeOf(Context) == 0) {
                _ = startFn({});
                return null;
            } else {
                _ = startFn(@ptrCast(*const Context, @alignCast(@alignOf(Context), ctx)).*);
                return null;
            }
        }
    };

    const MAP_GROWSDOWN = if (builtin.os == builtin.Os.linux) linux.MAP_GROWSDOWN else 0;

    var stack_end_offset: usize = undefined;
    var thread_start_offset: usize = undefined;
    var context_start_offset: usize = undefined;
    var tls_start_offset: usize = undefined;
    const mmap_len = blk: {
        // First in memory will be the stack, which grows downwards.
        var l: usize = mem.alignForward(default_stack_size, os.page_size);
        stack_end_offset = l;
        // Above the stack, so that it can be in the same mmap call, put the Thread object.
        l = mem.alignForward(l, @alignOf(Thread));
        thread_start_offset = l;
        l += @sizeOf(Thread);
        // Next, the Context object.
        if (@sizeOf(Context) != 0) {
            l = mem.alignForward(l, @alignOf(Context));
            context_start_offset = l;
            l += @sizeOf(Context);
        }
        // Finally, the Thread Local Storage, if any.
        if (!Thread.use_pthreads) {
            if (linux.tls.tls_image) |tls_img| {
                l = mem.alignForward(l, @alignOf(usize));
                tls_start_offset = l;
                l += tls_img.alloc_size;
            }
        }
        break :blk l;
    };
    const mmap_addr = posix.mmap(null, mmap_len, posix.PROT_READ | posix.PROT_WRITE, posix.MAP_PRIVATE | posix.MAP_ANONYMOUS | MAP_GROWSDOWN, -1, 0);
    if (mmap_addr == posix.MAP_FAILED) return error.OutOfMemory;
    errdefer assert(posix.munmap(mmap_addr, mmap_len) == 0);

    const thread_ptr = @alignCast(@alignOf(Thread), @intToPtr(*Thread, mmap_addr + thread_start_offset));
    thread_ptr.data.mmap_addr = mmap_addr;
    thread_ptr.data.mmap_len = mmap_len;

    var arg: usize = undefined;
    if (@sizeOf(Context) != 0) {
        arg = mmap_addr + context_start_offset;
        const context_ptr = @alignCast(@alignOf(Context), @intToPtr(*Context, arg));
        context_ptr.* = context;
    }

    if (Thread.use_pthreads) {
        // use pthreads
        var attr: c.pthread_attr_t = undefined;
        if (c.pthread_attr_init(&attr) != 0) return SpawnThreadError.SystemResources;
        defer assert(c.pthread_attr_destroy(&attr) == 0);

        assert(c.pthread_attr_setstack(&attr, @intToPtr(*c_void, mmap_addr), stack_end_offset) == 0);

        const err = c.pthread_create(&thread_ptr.data.handle, &attr, MainFuncs.posixThreadMain, @intToPtr(*c_void, arg));
        switch (err) {
            0 => return thread_ptr,
            posix.EAGAIN => return SpawnThreadError.SystemResources,
            posix.EPERM => unreachable,
            posix.EINVAL => unreachable,
            else => return unexpectedErrorPosix(@intCast(usize, err)),
        }
    } else if (builtin.os == builtin.Os.linux) {
        var flags: u32 = posix.CLONE_VM | posix.CLONE_FS | posix.CLONE_FILES | posix.CLONE_SIGHAND |
            posix.CLONE_THREAD | posix.CLONE_SYSVSEM | posix.CLONE_PARENT_SETTID | posix.CLONE_CHILD_CLEARTID |
            posix.CLONE_DETACHED;
        var newtls: usize = undefined;
        if (linux.tls.tls_image) |tls_img| {
            newtls = linux.tls.copyTLS(mmap_addr + tls_start_offset);
            flags |= posix.CLONE_SETTLS;
        }
        const rc = posix.clone(MainFuncs.linuxThreadMain, mmap_addr + stack_end_offset, flags, arg, &thread_ptr.data.handle, newtls, &thread_ptr.data.handle);
        const err = posix.getErrno(rc);
        switch (err) {
            0 => return thread_ptr,
            posix.EAGAIN => return SpawnThreadError.ThreadQuotaExceeded,
            posix.EINVAL => unreachable,
            posix.ENOMEM => return SpawnThreadError.SystemResources,
            posix.ENOSPC => unreachable,
            posix.EPERM => unreachable,
            posix.EUSERS => unreachable,
            else => return unexpectedErrorPosix(err),
        }
    } else {
        @compileError("Unsupported OS");
    }
}

pub const CpuCountError = error{
    OutOfMemory,
    PermissionDenied,

    Unexpected,
};

pub fn cpuCount(fallback_allocator: *mem.Allocator) CpuCountError!usize {
    switch (builtin.os) {
        .macosx, .freebsd, .netbsd => {
            var count: c_int = undefined;
            var count_len: usize = @sizeOf(c_int);
            const name = switch (builtin.os) {
                builtin.Os.macosx => c"hw.logicalcpu",
                else => c"hw.ncpu",
            };
            try posix.sysctlbyname(name, @ptrCast(*c_void, &count), &count_len, null, 0);
            return @intCast(usize, count);
        },
        .linux => {
            const usize_count = 16;
            const allocator = std.heap.stackFallback(usize_count * @sizeOf(usize), fallback_allocator).get();

            var set = try allocator.alloc(usize, usize_count);
            defer allocator.free(set);

            while (true) {
                const rc = posix.sched_getaffinity(0, set);
                const err = posix.getErrno(rc);
                switch (err) {
                    0 => {
                        if (rc < set.len * @sizeOf(usize)) {
                            const result = set[0 .. rc / @sizeOf(usize)];
                            var sum: usize = 0;
                            for (result) |x| {
                                sum += @popCount(usize, x);
                            }
                            return sum;
                        } else {
                            set = try allocator.realloc(set, set.len * 2);
                            continue;
                        }
                    },
                    posix.EFAULT => unreachable,
                    posix.EINVAL => unreachable,
                    posix.EPERM => return CpuCountError.PermissionDenied,
                    posix.ESRCH => unreachable,
                    else => return os.unexpectedErrorPosix(err),
                }
            }
        },
        .windows => {
            var system_info: windows.SYSTEM_INFO = undefined;
            windows.GetSystemInfo(&system_info);
            return @intCast(usize, system_info.dwNumberOfProcessors);
        },
        else => @compileError("unsupported OS"),
    }
}
