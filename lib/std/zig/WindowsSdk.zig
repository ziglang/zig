windows10sdk: ?Windows10Sdk,
windows81sdk: ?Windows81Sdk,
msvc_lib_dir: ?[]const u8,

const WindowsSdk = @This();
const std = @import("std");
const builtin = @import("builtin");

const windows = std.os.windows;
const RRF = windows.advapi32.RRF;

const WINDOWS_KIT_REG_KEY = "SOFTWARE\\Microsoft\\Windows Kits\\Installed Roots";

// https://learn.microsoft.com/en-us/windows/win32/msi/productversion
const version_major_minor_max_length = "255.255".len;
// note(bratishkaerik): i think ProductVersion in registry (created by Visual Studio installer) also follows this rule
const product_version_max_length = version_major_minor_max_length + ".65535".len;

/// Find path and version of Windows 10 SDK and Windows 8.1 SDK, and find path to MSVC's `lib/` directory.
/// Caller owns the result's fields.
/// After finishing work, call `free(allocator)`.
pub fn find(allocator: std.mem.Allocator) error{ OutOfMemory, NotFound, PathTooLong }!WindowsSdk {
    if (builtin.os.tag != .windows) return error.NotFound;

    //note(dimenus): If this key doesn't exist, neither the Win 8 SDK nor the Win 10 SDK is installed
    const roots_key = RegistryWtf8.openKey(windows.HKEY_LOCAL_MACHINE, WINDOWS_KIT_REG_KEY) catch |err| switch (err) {
        error.KeyNotFound => return error.NotFound,
    };
    defer roots_key.closeKey();

    const windows10sdk: ?Windows10Sdk = blk: {
        const windows10sdk = Windows10Sdk.find(allocator) catch |err| switch (err) {
            error.Windows10SdkNotFound,
            error.PathTooLong,
            error.VersionTooLong,
            => break :blk null,
            error.OutOfMemory => return error.OutOfMemory,
        };
        const is_valid_version = windows10sdk.isValidVersion();
        if (!is_valid_version) break :blk null;
        break :blk windows10sdk;
    };
    errdefer if (windows10sdk) |*w| w.free(allocator);

    const windows81sdk: ?Windows81Sdk = blk: {
        const windows81sdk = Windows81Sdk.find(allocator, &roots_key) catch |err| switch (err) {
            error.Windows81SdkNotFound => break :blk null,
            error.PathTooLong => break :blk null,
            error.VersionTooLong => break :blk null,
            error.OutOfMemory => return error.OutOfMemory,
        };
        // no check
        break :blk windows81sdk;
    };
    errdefer if (windows81sdk) |*w| w.free(allocator);

    const msvc_lib_dir: ?[]const u8 = MsvcLibDir.find(allocator) catch |err| switch (err) {
        error.MsvcLibDirNotFound => null,
        error.OutOfMemory => return error.OutOfMemory,
    };
    errdefer allocator.free(msvc_lib_dir);

    return WindowsSdk{
        .windows10sdk = windows10sdk,
        .windows81sdk = windows81sdk,
        .msvc_lib_dir = msvc_lib_dir,
    };
}

pub fn free(self: *const WindowsSdk, allocator: std.mem.Allocator) void {
    if (self.windows10sdk) |*w10sdk| {
        w10sdk.free(allocator);
    }
    if (self.windows81sdk) |*w81sdk| {
        w81sdk.free(allocator);
    }
    if (self.msvc_lib_dir) |msvc_lib_dir| {
        allocator.free(msvc_lib_dir);
    }
}

/// Iterates via `iterator` and collects all folders with names starting with `optional_prefix`
/// and similar to SemVer. Returns slice of folder names sorted in descending order.
/// Caller owns result.
fn iterateAndFilterBySemVer(
    iterator: *std.fs.Dir.Iterator,
    allocator: std.mem.Allocator,
    comptime optional_prefix: ?[]const u8,
) error{ OutOfMemory, VersionNotFound }![][]const u8 {
    var dirs_filtered_list = std.ArrayList([]const u8).init(allocator);
    errdefer {
        for (dirs_filtered_list.items) |filtered_dir| allocator.free(filtered_dir);
        dirs_filtered_list.deinit();
    }

    var normalized_name_buf: [std.fs.MAX_NAME_BYTES + ".0+build.0".len]u8 = undefined;
    var normalized_name_fbs = std.io.fixedBufferStream(&normalized_name_buf);
    const normalized_name_w = normalized_name_fbs.writer();
    iterate_folder: while (true) : (normalized_name_fbs.reset()) {
        const maybe_entry = iterator.next() catch continue :iterate_folder;
        const entry = maybe_entry orelse break :iterate_folder;

        if (entry.kind != .directory)
            continue :iterate_folder;

        // invalidated on next iteration
        const subfolder_name = blk: {
            if (comptime optional_prefix) |prefix| {
                if (!std.mem.startsWith(u8, entry.name, prefix)) continue :iterate_folder;
                break :blk entry.name[prefix.len..];
            } else break :blk entry.name;
        };

        { // check if subfolder name looks similar to SemVer
            switch (std.mem.count(u8, subfolder_name, ".")) {
                0 => normalized_name_w.print("{s}.0.0+build.0", .{subfolder_name}) catch unreachable, // 17 => 17.0.0+build.0
                1 => if (std.mem.indexOfScalar(u8, subfolder_name, '_')) |underscore_pos| blk: { // 17.0_9e9cbb98 => 17.0.1+build.9e9cbb98
                    var subfolder_name_tmp_copy_buf: [std.fs.MAX_NAME_BYTES]u8 = undefined;
                    const subfolder_name_tmp_copy = subfolder_name_tmp_copy_buf[0..subfolder_name.len];
                    @memcpy(subfolder_name_tmp_copy, subfolder_name);

                    subfolder_name_tmp_copy[underscore_pos] = '.'; // 17.0_9e9cbb98 => 17.0.9e9cbb98
                    var subfolder_name_parts = std.mem.splitScalar(u8, subfolder_name_tmp_copy, '.'); // [ 17, 0, 9e9cbb98 ]

                    const first = subfolder_name_parts.first(); // 17
                    const second = subfolder_name_parts.next().?; // 0
                    const third = subfolder_name_parts.rest(); // 9e9cbb98

                    break :blk normalized_name_w.print("{s}.{s}.1+build.{s}", .{ first, second, third }) catch unreachable; // [ 17, 0, 9e9cbb98 ] => 17.0.1+build.9e9cbb98
                } else normalized_name_w.print("{s}.0+build.0", .{subfolder_name}) catch unreachable, // 17.0 => 17.0.0+build.0
                else => normalized_name_w.print("{s}+build.0", .{subfolder_name}) catch unreachable, // 17.0.0 => 17.0.0+build.0
            }
            const subfolder_name_normalized: []const u8 = normalized_name_fbs.getWritten();
            const sem_ver = std.SemanticVersion.parse(subfolder_name_normalized);
            _ = sem_ver catch continue :iterate_folder;
        }
        // entry.name passed check

        const subfolder_name_allocated = try allocator.dupe(u8, subfolder_name);
        errdefer allocator.free(subfolder_name_allocated);
        try dirs_filtered_list.append(subfolder_name_allocated);
    }

    const dirs_filtered_slice = try dirs_filtered_list.toOwnedSlice();
    // Keep in mind that order of these names is not guaranteed by Windows,
    // so we cannot just reverse or "while (popOrNull())" this ArrayList.
    std.mem.sortUnstable([]const u8, dirs_filtered_slice, {}, struct {
        fn desc(_: void, lhs: []const u8, rhs: []const u8) bool {
            return std.mem.order(u8, lhs, rhs) == .gt;
        }
    }.desc);
    return dirs_filtered_slice;
}

const RegistryWtf8 = struct {
    key: windows.HKEY,

    /// Assert that `key` is valid WTF-8 string
    pub fn openKey(hkey: windows.HKEY, key: []const u8) error{KeyNotFound}!RegistryWtf8 {
        const key_wtf16le: [:0]const u16 = key_wtf16le: {
            var key_wtf16le_buf: [RegistryWtf16Le.key_name_max_len]u16 = undefined;
            const key_wtf16le_len: usize = std.unicode.wtf8ToWtf16Le(key_wtf16le_buf[0..], key) catch |err| switch (err) {
                error.InvalidWtf8 => unreachable,
            };
            key_wtf16le_buf[key_wtf16le_len] = 0;
            break :key_wtf16le key_wtf16le_buf[0..key_wtf16le_len :0];
        };

        const registry_wtf16le = try RegistryWtf16Le.openKey(hkey, key_wtf16le);
        return RegistryWtf8{ .key = registry_wtf16le.key };
    }

    /// Closes key, after that usage is invalid
    pub fn closeKey(self: *const RegistryWtf8) void {
        const return_code_int: windows.HRESULT = windows.advapi32.RegCloseKey(self.key);
        const return_code: windows.Win32Error = @enumFromInt(return_code_int);
        switch (return_code) {
            .SUCCESS => {},
            else => {},
        }
    }

    /// Get string from registry.
    /// Caller owns result.
    pub fn getString(self: *const RegistryWtf8, allocator: std.mem.Allocator, subkey: []const u8, value_name: []const u8) error{ OutOfMemory, ValueNameNotFound, NotAString, StringNotFound }![]u8 {
        const subkey_wtf16le: [:0]const u16 = subkey_wtf16le: {
            var subkey_wtf16le_buf: [RegistryWtf16Le.key_name_max_len]u16 = undefined;
            const subkey_wtf16le_len: usize = std.unicode.wtf8ToWtf16Le(subkey_wtf16le_buf[0..], subkey) catch unreachable;
            subkey_wtf16le_buf[subkey_wtf16le_len] = 0;
            break :subkey_wtf16le subkey_wtf16le_buf[0..subkey_wtf16le_len :0];
        };

        const value_name_wtf16le: [:0]const u16 = value_name_wtf16le: {
            var value_name_wtf16le_buf: [RegistryWtf16Le.value_name_max_len]u16 = undefined;
            const value_name_wtf16le_len: usize = std.unicode.wtf8ToWtf16Le(value_name_wtf16le_buf[0..], value_name) catch unreachable;
            value_name_wtf16le_buf[value_name_wtf16le_len] = 0;
            break :value_name_wtf16le value_name_wtf16le_buf[0..value_name_wtf16le_len :0];
        };

        const registry_wtf16le = RegistryWtf16Le{ .key = self.key };
        const value_wtf16le = try registry_wtf16le.getString(allocator, subkey_wtf16le, value_name_wtf16le);
        defer allocator.free(value_wtf16le);

        const value_wtf8: []u8 = try std.unicode.wtf16LeToWtf8Alloc(allocator, value_wtf16le);
        errdefer allocator.free(value_wtf8);

        return value_wtf8;
    }

    /// Get DWORD (u32) from registry.
    pub fn getDword(self: *const RegistryWtf8, subkey: []const u8, value_name: []const u8) error{ ValueNameNotFound, NotADword, DwordTooLong, DwordNotFound }!u32 {
        const subkey_wtf16le: [:0]const u16 = subkey_wtf16le: {
            var subkey_wtf16le_buf: [RegistryWtf16Le.key_name_max_len]u16 = undefined;
            const subkey_wtf16le_len: usize = std.unicode.wtf8ToWtf16Le(subkey_wtf16le_buf[0..], subkey) catch unreachable;
            subkey_wtf16le_buf[subkey_wtf16le_len] = 0;
            break :subkey_wtf16le subkey_wtf16le_buf[0..subkey_wtf16le_len :0];
        };

        const value_name_wtf16le: [:0]const u16 = value_name_wtf16le: {
            var value_name_wtf16le_buf: [RegistryWtf16Le.value_name_max_len]u16 = undefined;
            const value_name_wtf16le_len: usize = std.unicode.wtf8ToWtf16Le(value_name_wtf16le_buf[0..], value_name) catch unreachable;
            value_name_wtf16le_buf[value_name_wtf16le_len] = 0;
            break :value_name_wtf16le value_name_wtf16le_buf[0..value_name_wtf16le_len :0];
        };

        const registry_wtf16le = RegistryWtf16Le{ .key = self.key };
        return try registry_wtf16le.getDword(subkey_wtf16le, value_name_wtf16le);
    }

    /// Under private space with flags:
    /// KEY_QUERY_VALUE and KEY_ENUMERATE_SUB_KEYS.
    /// After finishing work, call `closeKey`.
    pub fn loadFromPath(absolute_path: []const u8) error{KeyNotFound}!RegistryWtf8 {
        const absolute_path_wtf16le: [:0]const u16 = absolute_path_wtf16le: {
            var absolute_path_wtf16le_buf: [RegistryWtf16Le.value_name_max_len]u16 = undefined;
            const absolute_path_wtf16le_len: usize = std.unicode.wtf8ToWtf16Le(absolute_path_wtf16le_buf[0..], absolute_path) catch unreachable;
            absolute_path_wtf16le_buf[absolute_path_wtf16le_len] = 0;
            break :absolute_path_wtf16le absolute_path_wtf16le_buf[0..absolute_path_wtf16le_len :0];
        };

        const registry_wtf16le = try RegistryWtf16Le.loadFromPath(absolute_path_wtf16le);
        return RegistryWtf8{ .key = registry_wtf16le.key };
    }
};

const RegistryWtf16Le = struct {
    key: windows.HKEY,

    /// Includes root key (f.e. HKEY_LOCAL_MACHINE).
    /// https://learn.microsoft.com/en-us/windows/win32/sysinfo/registry-element-size-limits
    pub const key_name_max_len = 255;
    /// In Unicode characters.
    /// https://learn.microsoft.com/en-us/windows/win32/sysinfo/registry-element-size-limits
    pub const value_name_max_len = 16_383;

    /// Under HKEY_LOCAL_MACHINE with flags:
    /// KEY_QUERY_VALUE, KEY_WOW64_32KEY, and KEY_ENUMERATE_SUB_KEYS.
    /// After finishing work, call `closeKey`.
    fn openKey(hkey: windows.HKEY, key_wtf16le: [:0]const u16) error{KeyNotFound}!RegistryWtf16Le {
        var key: windows.HKEY = undefined;
        const return_code_int: windows.HRESULT = windows.advapi32.RegOpenKeyExW(
            hkey,
            key_wtf16le,
            0,
            windows.KEY_QUERY_VALUE | windows.KEY_WOW64_32KEY | windows.KEY_ENUMERATE_SUB_KEYS,
            &key,
        );
        const return_code: windows.Win32Error = @enumFromInt(return_code_int);
        switch (return_code) {
            .SUCCESS => {},
            .FILE_NOT_FOUND => return error.KeyNotFound,

            else => return error.KeyNotFound,
        }
        return RegistryWtf16Le{ .key = key };
    }

    /// Closes key, after that usage is invalid
    fn closeKey(self: *const RegistryWtf16Le) void {
        const return_code_int: windows.HRESULT = windows.advapi32.RegCloseKey(self.key);
        const return_code: windows.Win32Error = @enumFromInt(return_code_int);
        switch (return_code) {
            .SUCCESS => {},
            else => {},
        }
    }

    /// Get string ([:0]const u16) from registry.
    fn getString(self: *const RegistryWtf16Le, allocator: std.mem.Allocator, subkey_wtf16le: [:0]const u16, value_name_wtf16le: [:0]const u16) error{ OutOfMemory, ValueNameNotFound, NotAString, StringNotFound }![]const u16 {
        var actual_type: windows.ULONG = undefined;

        // Calculating length to allocate
        var value_wtf16le_buf_size: u32 = 0; // in bytes, including any terminating NUL character or characters.
        var return_code_int: windows.HRESULT = windows.advapi32.RegGetValueW(
            self.key,
            subkey_wtf16le,
            value_name_wtf16le,
            RRF.RT_REG_SZ,
            &actual_type,
            null,
            &value_wtf16le_buf_size,
        );

        // Check returned code and type
        var return_code: windows.Win32Error = @enumFromInt(return_code_int);
        switch (return_code) {
            .SUCCESS => std.debug.assert(value_wtf16le_buf_size != 0),
            .MORE_DATA => unreachable, // We are only reading length
            .FILE_NOT_FOUND => return error.ValueNameNotFound,
            .INVALID_PARAMETER => unreachable, // We didn't combine RRF.SUBKEY_WOW6464KEY and RRF.SUBKEY_WOW6432KEY
            else => return error.StringNotFound,
        }
        switch (actual_type) {
            windows.REG.SZ => {},
            else => return error.NotAString,
        }

        const value_wtf16le_buf: []u16 = try allocator.alloc(u16, std.math.divCeil(u32, value_wtf16le_buf_size, 2) catch unreachable);
        errdefer allocator.free(value_wtf16le_buf);

        return_code_int = windows.advapi32.RegGetValueW(
            self.key,
            subkey_wtf16le,
            value_name_wtf16le,
            RRF.RT_REG_SZ,
            &actual_type,
            value_wtf16le_buf.ptr,
            &value_wtf16le_buf_size,
        );

        // Check returned code and (just in case) type again.
        return_code = @enumFromInt(return_code_int);
        switch (return_code) {
            .SUCCESS => {},
            .MORE_DATA => unreachable, // Calculated first time length should be enough, even overestimated
            .FILE_NOT_FOUND => return error.ValueNameNotFound,
            .INVALID_PARAMETER => unreachable, // We didn't combine RRF.SUBKEY_WOW6464KEY and RRF.SUBKEY_WOW6432KEY
            else => return error.StringNotFound,
        }
        switch (actual_type) {
            windows.REG.SZ => {},
            else => return error.NotAString,
        }

        const value_wtf16le: []const u16 = value_wtf16le: {
            // note(bratishkaerik): somehow returned value in `buf_len` is overestimated by Windows and contains extra space
            // we will just search for zero termination and forget length
            // Windows sure is strange
            const value_wtf16le_overestimated: [*:0]const u16 = @ptrCast(value_wtf16le_buf.ptr);
            break :value_wtf16le std.mem.span(value_wtf16le_overestimated);
        };

        _ = allocator.resize(value_wtf16le_buf, value_wtf16le.len);
        return value_wtf16le;
    }

    /// Get DWORD (u32) from registry.
    fn getDword(self: *const RegistryWtf16Le, subkey_wtf16le: [:0]const u16, value_name_wtf16le: [:0]const u16) error{ ValueNameNotFound, NotADword, DwordTooLong, DwordNotFound }!u32 {
        var actual_type: windows.ULONG = undefined;
        var reg_size: u32 = @sizeOf(u32);
        var reg_value: u32 = 0;

        const return_code_int: windows.HRESULT = windows.advapi32.RegGetValueW(
            self.key,
            subkey_wtf16le,
            value_name_wtf16le,
            RRF.RT_REG_DWORD,
            &actual_type,
            &reg_value,
            &reg_size,
        );
        const return_code: windows.Win32Error = @enumFromInt(return_code_int);
        switch (return_code) {
            .SUCCESS => {},
            .MORE_DATA => return error.DwordTooLong,
            .FILE_NOT_FOUND => return error.ValueNameNotFound,
            .INVALID_PARAMETER => unreachable, // We didn't combine RRF.SUBKEY_WOW6464KEY and RRF.SUBKEY_WOW6432KEY
            else => return error.DwordNotFound,
        }

        switch (actual_type) {
            windows.REG.DWORD => {},
            else => return error.NotADword,
        }

        return reg_value;
    }

    /// Under private space with flags:
    /// KEY_QUERY_VALUE and KEY_ENUMERATE_SUB_KEYS.
    /// After finishing work, call `closeKey`.
    fn loadFromPath(absolute_path_as_wtf16le: [:0]const u16) error{KeyNotFound}!RegistryWtf16Le {
        var key: windows.HKEY = undefined;

        const return_code_int: windows.HRESULT = std.os.windows.advapi32.RegLoadAppKeyW(
            absolute_path_as_wtf16le,
            &key,
            windows.KEY_QUERY_VALUE | windows.KEY_ENUMERATE_SUB_KEYS,
            0,
            0,
        );
        const return_code: windows.Win32Error = @enumFromInt(return_code_int);
        switch (return_code) {
            .SUCCESS => {},
            else => return error.KeyNotFound,
        }

        return RegistryWtf16Le{ .key = key };
    }
};

pub const Windows10Sdk = struct {
    path: []const u8,
    version: []const u8,

    /// Find path and version of Windows 10 SDK.
    /// Caller owns the result's fields.
    /// After finishing work, call `free(allocator)`.
    fn find(allocator: std.mem.Allocator) error{ OutOfMemory, Windows10SdkNotFound, PathTooLong, VersionTooLong }!Windows10Sdk {
        const v10_key = RegistryWtf8.openKey(windows.HKEY_LOCAL_MACHINE, "SOFTWARE\\Microsoft\\Microsoft SDKs\\Windows\\v10.0") catch |err| switch (err) {
            error.KeyNotFound => return error.Windows10SdkNotFound,
        };
        defer v10_key.closeKey();

        const path: []const u8 = path10: {
            const path_maybe_with_trailing_slash = v10_key.getString(allocator, "", "InstallationFolder") catch |err| switch (err) {
                error.NotAString => return error.Windows10SdkNotFound,
                error.ValueNameNotFound => return error.Windows10SdkNotFound,
                error.StringNotFound => return error.Windows10SdkNotFound,

                error.OutOfMemory => return error.OutOfMemory,
            };

            if (path_maybe_with_trailing_slash.len > std.fs.MAX_PATH_BYTES or !std.fs.path.isAbsolute(path_maybe_with_trailing_slash)) {
                allocator.free(path_maybe_with_trailing_slash);
                return error.PathTooLong;
            }

            var path = std.ArrayList(u8).fromOwnedSlice(allocator, path_maybe_with_trailing_slash);
            errdefer path.deinit();

            // String might contain trailing slash, so trim it here
            if (path.items.len > "C:\\".len and path.getLast() == '\\') _ = path.pop();

            const path_without_trailing_slash = try path.toOwnedSlice();
            break :path10 path_without_trailing_slash;
        };
        errdefer allocator.free(path);

        const version: []const u8 = version10: {

            // note(dimenus): Microsoft doesn't include the .0 in the ProductVersion key....
            const version_without_0 = v10_key.getString(allocator, "", "ProductVersion") catch |err| switch (err) {
                error.NotAString => return error.Windows10SdkNotFound,
                error.ValueNameNotFound => return error.Windows10SdkNotFound,
                error.StringNotFound => return error.Windows10SdkNotFound,

                error.OutOfMemory => return error.OutOfMemory,
            };
            if (version_without_0.len + ".0".len > product_version_max_length) {
                allocator.free(version_without_0);
                return error.VersionTooLong;
            }

            var version = std.ArrayList(u8).fromOwnedSlice(allocator, version_without_0);
            errdefer version.deinit();

            try version.appendSlice(".0");

            const version_with_0 = try version.toOwnedSlice();
            break :version10 version_with_0;
        };
        errdefer allocator.free(version);

        return Windows10Sdk{ .path = path, .version = version };
    }

    /// Check whether this version is enumerated in registry.
    fn isValidVersion(windows10sdk: *const Windows10Sdk) bool {
        var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        const reg_query_as_wtf8 = std.fmt.bufPrint(buf[0..], "{s}\\{s}\\Installed Options", .{ WINDOWS_KIT_REG_KEY, windows10sdk.version }) catch |err| switch (err) {
            error.NoSpaceLeft => return false,
        };

        const options_key = RegistryWtf8.openKey(windows.HKEY_LOCAL_MACHINE, reg_query_as_wtf8) catch |err| switch (err) {
            error.KeyNotFound => return false,
        };
        defer options_key.closeKey();

        const option_name = comptime switch (builtin.target.cpu.arch) {
            .arm, .armeb => "OptionId.DesktopCPParm",
            .aarch64 => "OptionId.DesktopCPParm64",
            .x86_64 => "OptionId.DesktopCPPx64",
            .x86 => "OptionId.DesktopCPPx86",
            else => |tag| @compileError("Windows 10 SDK cannot be detected on architecture " ++ tag),
        };

        const reg_value = options_key.getDword("", option_name) catch return false;
        return (reg_value == 1);
    }

    fn free(self: *const Windows10Sdk, allocator: std.mem.Allocator) void {
        allocator.free(self.path);
        allocator.free(self.version);
    }
};

pub const Windows81Sdk = struct {
    path: []const u8,
    version: []const u8,

    /// Find path and version of Windows 8.1 SDK.
    /// Caller owns the result's fields.
    /// After finishing work, call `free(allocator)`.
    fn find(allocator: std.mem.Allocator, roots_key: *const RegistryWtf8) error{ OutOfMemory, Windows81SdkNotFound, PathTooLong, VersionTooLong }!Windows81Sdk {
        const path: []const u8 = path81: {
            const path_maybe_with_trailing_slash = roots_key.getString(allocator, "", "KitsRoot81") catch |err| switch (err) {
                error.NotAString => return error.Windows81SdkNotFound,
                error.ValueNameNotFound => return error.Windows81SdkNotFound,
                error.StringNotFound => return error.Windows81SdkNotFound,

                error.OutOfMemory => return error.OutOfMemory,
            };
            if (path_maybe_with_trailing_slash.len > std.fs.MAX_PATH_BYTES or !std.fs.path.isAbsolute(path_maybe_with_trailing_slash)) {
                allocator.free(path_maybe_with_trailing_slash);
                return error.PathTooLong;
            }

            var path = std.ArrayList(u8).fromOwnedSlice(allocator, path_maybe_with_trailing_slash);
            errdefer path.deinit();

            // String might contain trailing slash, so trim it here
            if (path.items.len > "C:\\".len and path.getLast() == '\\') _ = path.pop();

            const path_without_trailing_slash = try path.toOwnedSlice();
            break :path81 path_without_trailing_slash;
        };
        errdefer allocator.free(path);

        const version: []const u8 = version81: {
            var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
            const sdk_lib_dir_path = std.fmt.bufPrint(buf[0..], "{s}\\Lib\\", .{path}) catch |err| switch (err) {
                error.NoSpaceLeft => return error.PathTooLong,
            };
            if (!std.fs.path.isAbsolute(sdk_lib_dir_path)) return error.Windows81SdkNotFound;

            // enumerate files in sdk path looking for latest version
            var sdk_lib_dir = std.fs.openDirAbsolute(sdk_lib_dir_path, .{
                .iterate = true,
            }) catch |err| switch (err) {
                error.NameTooLong => return error.PathTooLong,
                else => return error.Windows81SdkNotFound,
            };
            defer sdk_lib_dir.close();

            var iterator = sdk_lib_dir.iterate();
            const versions = iterateAndFilterBySemVer(&iterator, allocator, "winv") catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                error.VersionNotFound => return error.Windows81SdkNotFound,
            };
            defer {
                for (versions) |version| allocator.free(version);
                allocator.free(versions);
            }
            const latest_version = try allocator.dupe(u8, versions[0]);
            break :version81 latest_version;
        };
        errdefer allocator.free(version);

        return Windows81Sdk{ .path = path, .version = version };
    }

    fn free(self: *const Windows81Sdk, allocator: std.mem.Allocator) void {
        allocator.free(self.path);
        allocator.free(self.version);
    }
};

const MsvcLibDir = struct {
    fn findInstancesDirViaCLSID(allocator: std.mem.Allocator) error{ OutOfMemory, PathNotFound }!std.fs.Dir {
        const setup_configuration_clsid = "{177f0c4a-1cd3-4de7-a32c-71dbbb9fa36d}";
        const setup_config_key = RegistryWtf8.openKey(windows.HKEY_CLASSES_ROOT, "CLSID\\" ++ setup_configuration_clsid) catch |err| switch (err) {
            error.KeyNotFound => return error.PathNotFound,
        };
        defer setup_config_key.closeKey();

        const dll_path = setup_config_key.getString(allocator, "InprocServer32", "") catch |err| switch (err) {
            error.NotAString,
            error.ValueNameNotFound,
            error.StringNotFound,
            => return error.PathNotFound,

            error.OutOfMemory => return error.OutOfMemory,
        };
        defer allocator.free(dll_path);

        var path_it = std.fs.path.componentIterator(dll_path) catch return error.PathNotFound;
        // the .dll filename
        _ = path_it.last();
        const root_path = while (path_it.previous()) |dir_component| {
            if (std.ascii.eqlIgnoreCase(dir_component.name, "VisualStudio")) {
                break dir_component.path;
            }
        } else {
            return error.PathNotFound;
        };

        const instances_path = try std.fs.path.join(allocator, &.{ root_path, "Packages", "_Instances" });
        defer allocator.free(instances_path);

        return std.fs.openDirAbsolute(instances_path, .{ .iterate = true }) catch return error.PathNotFound;
    }

    fn findInstancesDir(allocator: std.mem.Allocator) error{ OutOfMemory, PathNotFound }!std.fs.Dir {
        // First try to get the path from the .dll that would have been
        // loaded via COM for SetupConfiguration.
        return findInstancesDirViaCLSID(allocator) catch |orig_err| {
            // If that can't be found, fall back to manually appending
            // `Microsoft\VisualStudio\Packages\_Instances` to %PROGRAMDATA%
            const program_data = std.process.getEnvVarOwned(allocator, "PROGRAMDATA") catch |err| switch (err) {
                error.OutOfMemory => |e| return e,
                else => return orig_err,
            };
            defer allocator.free(program_data);

            const instances_path = try std.fs.path.join(allocator, &.{ program_data, "Microsoft", "VisualStudio", "Packages", "_Instances" });
            defer allocator.free(instances_path);

            return std.fs.openDirAbsolute(instances_path, .{ .iterate = true }) catch return orig_err;
        };
    }

    /// Intended to be equivalent to `ISetupHelper.ParseVersion`
    /// Example: 17.4.33205.214 -> 0x0011000481b500d6
    fn parseVersionQuad(version: []const u8) error{InvalidVersion}!u64 {
        var it = std.mem.splitScalar(u8, version, '.');
        const a = it.next() orelse return error.InvalidVersion;
        const b = it.next() orelse return error.InvalidVersion;
        const c = it.next() orelse return error.InvalidVersion;
        const d = it.next() orelse return error.InvalidVersion;
        if (it.next()) |_| return error.InvalidVersion;
        var result: u64 = undefined;
        var result_bytes = std.mem.asBytes(&result);

        std.mem.writeInt(
            u16,
            result_bytes[0..2],
            std.fmt.parseUnsigned(u16, d, 10) catch return error.InvalidVersion,
            .little,
        );
        std.mem.writeInt(
            u16,
            result_bytes[2..4],
            std.fmt.parseUnsigned(u16, c, 10) catch return error.InvalidVersion,
            .little,
        );
        std.mem.writeInt(
            u16,
            result_bytes[4..6],
            std.fmt.parseUnsigned(u16, b, 10) catch return error.InvalidVersion,
            .little,
        );
        std.mem.writeInt(
            u16,
            result_bytes[6..8],
            std.fmt.parseUnsigned(u16, a, 10) catch return error.InvalidVersion,
            .little,
        );

        return result;
    }

    /// Intended to be equivalent to ISetupConfiguration.EnumInstances:
    /// https://learn.microsoft.com/en-us/dotnet/api/microsoft.visualstudio.setup.configuration
    /// but without the use of COM in order to avoid a dependency on ole32.dll
    ///
    /// The logic in this function is intended to match what ISetupConfiguration does
    /// under-the-hood, as verified using Procmon.
    fn findViaCOM(allocator: std.mem.Allocator) error{ OutOfMemory, PathNotFound }![]const u8 {
        // Typically `%PROGRAMDATA%\Microsoft\VisualStudio\Packages\_Instances`
        // This will contain directories with names of instance IDs like 80a758ca,
        // which will contain `state.json` files that have the version and
        // installation directory.
        var instances_dir = try findInstancesDir(allocator);
        defer instances_dir.close();

        var state_subpath_buf: [std.fs.MAX_NAME_BYTES + 32]u8 = undefined;
        var latest_version_lib_dir = std.ArrayListUnmanaged(u8){};
        errdefer latest_version_lib_dir.deinit(allocator);

        var latest_version: u64 = 0;
        var instances_dir_it = instances_dir.iterateAssumeFirstIteration();
        while (instances_dir_it.next() catch return error.PathNotFound) |entry| {
            if (entry.kind != .directory) continue;

            var fbs = std.io.fixedBufferStream(&state_subpath_buf);
            const writer = fbs.writer();

            writer.writeAll(entry.name) catch unreachable;
            writer.writeByte(std.fs.path.sep) catch unreachable;
            writer.writeAll("state.json") catch unreachable;

            const json_contents = instances_dir.readFileAlloc(allocator, fbs.getWritten(), std.math.maxInt(usize)) catch continue;
            defer allocator.free(json_contents);

            var parsed = std.json.parseFromSlice(std.json.Value, allocator, json_contents, .{}) catch continue;
            defer parsed.deinit();

            if (parsed.value != .object) continue;
            const catalog_info = parsed.value.object.get("catalogInfo") orelse continue;
            if (catalog_info != .object) continue;
            const product_version_value = catalog_info.object.get("buildVersion") orelse continue;
            if (product_version_value != .string) continue;
            const product_version_text = product_version_value.string;
            const parsed_version = parseVersionQuad(product_version_text) catch continue;

            // We want to end up with the most recent version installed
            if (parsed_version <= latest_version) continue;

            const installation_path = parsed.value.object.get("installationPath") orelse continue;
            if (installation_path != .string) continue;

            const lib_dir_path = libDirFromInstallationPath(allocator, installation_path.string) catch |err| switch (err) {
                error.OutOfMemory => |e| return e,
                error.PathNotFound => continue,
            };
            defer allocator.free(lib_dir_path);

            latest_version_lib_dir.clearRetainingCapacity();
            try latest_version_lib_dir.appendSlice(allocator, lib_dir_path);
            latest_version = parsed_version;
        }

        if (latest_version_lib_dir.items.len == 0) return error.PathNotFound;
        return latest_version_lib_dir.toOwnedSlice(allocator);
    }

    fn libDirFromInstallationPath(allocator: std.mem.Allocator, installation_path: []const u8) error{ OutOfMemory, PathNotFound }![]const u8 {
        var lib_dir_buf = try std.ArrayList(u8).initCapacity(allocator, installation_path.len + 64);
        errdefer lib_dir_buf.deinit();

        lib_dir_buf.appendSliceAssumeCapacity(installation_path);

        if (!std.fs.path.isSep(lib_dir_buf.getLast())) {
            try lib_dir_buf.append('\\');
        }
        const installation_path_with_trailing_sep_len = lib_dir_buf.items.len;

        try lib_dir_buf.appendSlice("VC\\Auxiliary\\Build\\Microsoft.VCToolsVersion.default.txt");
        var default_tools_version_buf: [512]u8 = undefined;
        const default_tools_version_contents = std.fs.cwd().readFile(lib_dir_buf.items, &default_tools_version_buf) catch {
            return error.PathNotFound;
        };
        var tokenizer = std.mem.tokenizeAny(u8, default_tools_version_contents, " \r\n");
        const default_tools_version = tokenizer.next() orelse return error.PathNotFound;

        lib_dir_buf.shrinkRetainingCapacity(installation_path_with_trailing_sep_len);
        try lib_dir_buf.appendSlice("VC\\Tools\\MSVC\\");
        try lib_dir_buf.appendSlice(default_tools_version);
        const folder_with_arch = "\\Lib\\" ++ comptime switch (builtin.target.cpu.arch) {
            .x86 => "x86",
            .x86_64 => "x64",
            .arm, .armeb => "arm",
            .aarch64 => "arm64",
            else => |tag| @compileError("MSVC lib dir cannot be detected on architecture " ++ tag),
        };
        try lib_dir_buf.appendSlice(folder_with_arch);

        if (!verifyLibDir(lib_dir_buf.items)) {
            return error.PathNotFound;
        }

        return lib_dir_buf.toOwnedSlice();
    }

    // https://learn.microsoft.com/en-us/visualstudio/install/tools-for-managing-visual-studio-instances?view=vs-2022#editing-the-registry-for-a-visual-studio-instance
    fn findViaRegistry(allocator: std.mem.Allocator) error{ OutOfMemory, PathNotFound }![]const u8 {

        // %localappdata%\Microsoft\VisualStudio\
        // %appdata%\Local\Microsoft\VisualStudio\
        const visualstudio_folder_path = std.fs.getAppDataDir(allocator, "Microsoft\\VisualStudio\\") catch return error.PathNotFound;
        defer allocator.free(visualstudio_folder_path);

        const vs_versions: []const []const u8 = vs_versions: {
            if (!std.fs.path.isAbsolute(visualstudio_folder_path)) return error.PathNotFound;
            // enumerate folders that contain `privateregistry.bin`, looking for all versions
            // f.i. %localappdata%\Microsoft\VisualStudio\17.0_9e9cbb98\
            var visualstudio_folder = std.fs.openDirAbsolute(visualstudio_folder_path, .{
                .iterate = true,
            }) catch return error.PathNotFound;
            defer visualstudio_folder.close();

            var iterator = visualstudio_folder.iterate();
            const versions = iterateAndFilterBySemVer(&iterator, allocator, null) catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                error.VersionNotFound => return error.PathNotFound,
            };
            break :vs_versions versions;
        };
        defer {
            for (vs_versions) |vs_version| allocator.free(vs_version);
            allocator.free(vs_versions);
        }
        var config_subkey_buf: [RegistryWtf16Le.key_name_max_len * 2]u8 = undefined;
        const source_directories: []const u8 = source_directories: for (vs_versions) |vs_version| {
            const privateregistry_absolute_path = std.fs.path.join(allocator, &.{ visualstudio_folder_path, vs_version, "privateregistry.bin" }) catch continue;
            defer allocator.free(privateregistry_absolute_path);
            if (!std.fs.path.isAbsolute(privateregistry_absolute_path)) continue;

            const visualstudio_registry = RegistryWtf8.loadFromPath(privateregistry_absolute_path) catch continue;
            defer visualstudio_registry.closeKey();

            const config_subkey = std.fmt.bufPrint(config_subkey_buf[0..], "Software\\Microsoft\\VisualStudio\\{s}_Config", .{vs_version}) catch unreachable;

            const source_directories_value = visualstudio_registry.getString(allocator, config_subkey, "Source Directories") catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                else => continue,
            };
            if (source_directories_value.len > (std.fs.MAX_PATH_BYTES * 30)) { // note(bratishkaerik): guessing from the fact that on my computer it has 15 pathes and at least some of them are not of max length
                allocator.free(source_directories_value);
                continue;
            }

            break :source_directories source_directories_value;
        } else return error.PathNotFound;
        defer allocator.free(source_directories);

        var source_directories_splitted = std.mem.splitScalar(u8, source_directories, ';');

        const msvc_dir: []const u8 = msvc_dir: {
            const msvc_include_dir_maybe_with_trailing_slash = try allocator.dupe(u8, source_directories_splitted.first());

            if (msvc_include_dir_maybe_with_trailing_slash.len > std.fs.MAX_PATH_BYTES or !std.fs.path.isAbsolute(msvc_include_dir_maybe_with_trailing_slash)) {
                allocator.free(msvc_include_dir_maybe_with_trailing_slash);
                return error.PathNotFound;
            }

            var msvc_dir = std.ArrayList(u8).fromOwnedSlice(allocator, msvc_include_dir_maybe_with_trailing_slash);
            errdefer msvc_dir.deinit();

            // String might contain trailing slash, so trim it here
            if (msvc_dir.items.len > "C:\\".len and msvc_dir.getLast() == '\\') _ = msvc_dir.pop();

            // Remove `\include` at the end of path
            if (std.mem.endsWith(u8, msvc_dir.items, "\\include")) {
                msvc_dir.shrinkRetainingCapacity(msvc_dir.items.len - "\\include".len);
            }

            const folder_with_arch = "\\Lib\\" ++ comptime switch (builtin.target.cpu.arch) {
                .x86 => "x86",
                .x86_64 => "x64",
                .arm, .armeb => "arm",
                .aarch64 => "arm64",
                else => |tag| @compileError("MSVC lib dir cannot be detected on architecture " ++ tag),
            };

            try msvc_dir.appendSlice(folder_with_arch);
            const msvc_dir_with_arch = try msvc_dir.toOwnedSlice();
            break :msvc_dir msvc_dir_with_arch;
        };
        errdefer allocator.free(msvc_dir);

        if (!verifyLibDir(msvc_dir)) {
            return error.PathNotFound;
        }

        return msvc_dir;
    }

    fn findViaVs7Key(allocator: std.mem.Allocator) error{ OutOfMemory, PathNotFound }![]const u8 {
        var base_path: std.ArrayList(u8) = base_path: {
            try_env: {
                var env_map = std.process.getEnvMap(allocator) catch |err| switch (err) {
                    error.OutOfMemory => return error.OutOfMemory,
                    else => break :try_env,
                };
                defer env_map.deinit();

                if (env_map.get("VS140COMNTOOLS")) |VS140COMNTOOLS| {
                    if (VS140COMNTOOLS.len < "C:\\Common7\\Tools".len) break :try_env;
                    if (!std.fs.path.isAbsolute(VS140COMNTOOLS)) break :try_env;
                    var list = std.ArrayList(u8).init(allocator);
                    errdefer list.deinit();

                    try list.appendSlice(VS140COMNTOOLS); // C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\Tools
                    // String might contain trailing slash, so trim it here
                    if (list.items.len > "C:\\".len and list.getLast() == '\\') _ = list.pop();
                    list.shrinkRetainingCapacity(list.items.len - "\\Common7\\Tools".len); // C:\Program Files (x86)\Microsoft Visual Studio 14.0
                    break :base_path list;
                }
            }

            const vs7_key = RegistryWtf8.openKey(windows.HKEY_LOCAL_MACHINE, "SOFTWARE\\Microsoft\\VisualStudio\\SxS\\VS7") catch return error.PathNotFound;
            defer vs7_key.closeKey();
            try_vs7_key: {
                const path_maybe_with_trailing_slash = vs7_key.getString(allocator, "", "14.0") catch |err| switch (err) {
                    error.OutOfMemory => return error.OutOfMemory,
                    else => break :try_vs7_key,
                };

                if (path_maybe_with_trailing_slash.len > std.fs.MAX_PATH_BYTES or !std.fs.path.isAbsolute(path_maybe_with_trailing_slash)) {
                    allocator.free(path_maybe_with_trailing_slash);
                    break :try_vs7_key;
                }

                var path = std.ArrayList(u8).fromOwnedSlice(allocator, path_maybe_with_trailing_slash);
                errdefer path.deinit();

                // String might contain trailing slash, so trim it here
                if (path.items.len > "C:\\".len and path.getLast() == '\\') _ = path.pop();
                break :base_path path;
            }
            return error.PathNotFound;
        };
        errdefer base_path.deinit();

        const folder_with_arch = "\\VC\\lib\\" ++ comptime switch (builtin.target.cpu.arch) {
            .x86 => "", //x86 is in the root of the Lib folder
            .x86_64 => "amd64",
            .arm, .armeb => "arm",
            .aarch64 => "arm64",
            else => |tag| @compileError("MSVC lib dir cannot be detected on architecture " ++ tag),
        };
        try base_path.appendSlice(folder_with_arch);

        if (!verifyLibDir(base_path.items)) {
            return error.PathNotFound;
        }

        const full_path = try base_path.toOwnedSlice();
        return full_path;
    }

    fn verifyLibDir(lib_dir_path: []const u8) bool {
        std.debug.assert(std.fs.path.isAbsolute(lib_dir_path)); // should be already handled in `findVia*`

        var dir = std.fs.openDirAbsolute(lib_dir_path, .{}) catch return false;
        defer dir.close();

        const stat = dir.statFile("vcruntime.lib") catch return false;
        if (stat.kind != .file)
            return false;

        return true;
    }

    /// Find path to MSVC's `lib/` directory.
    /// Caller owns the result.
    pub fn find(allocator: std.mem.Allocator) error{ OutOfMemory, MsvcLibDirNotFound }![]const u8 {
        const full_path = MsvcLibDir.findViaCOM(allocator) catch |err1| switch (err1) {
            error.OutOfMemory => return error.OutOfMemory,
            error.PathNotFound => MsvcLibDir.findViaRegistry(allocator) catch |err2| switch (err2) {
                error.OutOfMemory => return error.OutOfMemory,
                error.PathNotFound => MsvcLibDir.findViaVs7Key(allocator) catch |err3| switch (err3) {
                    error.OutOfMemory => return error.OutOfMemory,
                    error.PathNotFound => return error.MsvcLibDirNotFound,
                },
            },
        };
        errdefer allocator.free(full_path);

        return full_path;
    }
};
