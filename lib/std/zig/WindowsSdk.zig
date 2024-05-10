windows10sdk: ?Installation,
windows81sdk: ?Installation,
msvc_lib_dir: ?[]const u8,

const WindowsSdk = @This();
const std = @import("std");
const builtin = @import("builtin");

const windows = std.os.windows;
const RRF = windows.advapi32.RRF;

const windows_kits_reg_key = "SOFTWARE\\Microsoft\\Windows Kits\\Installed Roots";

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
    const roots_key = RegistryWtf8.openKey(windows.HKEY_LOCAL_MACHINE, windows_kits_reg_key, .{ .wow64_32 = true }) catch |err| switch (err) {
        error.KeyNotFound => return error.NotFound,
    };
    defer roots_key.closeKey();

    const windows10sdk = Installation.find(allocator, roots_key, "KitsRoot10", "", "v10.0") catch |err| switch (err) {
        error.InstallationNotFound => null,
        error.PathTooLong => null,
        error.VersionTooLong => null,
        error.OutOfMemory => return error.OutOfMemory,
    };
    errdefer if (windows10sdk) |*w| w.free(allocator);

    const windows81sdk = Installation.find(allocator, roots_key, "KitsRoot81", "winver", "v8.1") catch |err| switch (err) {
        error.InstallationNotFound => null,
        error.PathTooLong => null,
        error.VersionTooLong => null,
        error.OutOfMemory => return error.OutOfMemory,
    };
    errdefer if (windows81sdk) |*w| w.free(allocator);

    const msvc_lib_dir: ?[]const u8 = MsvcLibDir.find(allocator) catch |err| switch (err) {
        error.MsvcLibDirNotFound => null,
        error.OutOfMemory => return error.OutOfMemory,
    };
    errdefer allocator.free(msvc_lib_dir);

    return .{
        .windows10sdk = windows10sdk,
        .windows81sdk = windows81sdk,
        .msvc_lib_dir = msvc_lib_dir,
    };
}

pub fn free(sdk: WindowsSdk, allocator: std.mem.Allocator) void {
    if (sdk.windows10sdk) |*w10sdk| {
        w10sdk.free(allocator);
    }
    if (sdk.windows81sdk) |*w81sdk| {
        w81sdk.free(allocator);
    }
    if (sdk.msvc_lib_dir) |msvc_lib_dir| {
        allocator.free(msvc_lib_dir);
    }
}

/// Iterates via `iterator` and collects all folders with names starting with `strip_prefix`
/// and a version. Returns slice of version strings sorted in descending order.
/// Caller owns result.
fn iterateAndFilterByVersion(
    iterator: *std.fs.Dir.Iterator,
    allocator: std.mem.Allocator,
    prefix: []const u8,
) error{OutOfMemory}![][]const u8 {
    const Version = struct {
        nums: [4]u32,
        build: []const u8,

        fn parseNum(num: []const u8) ?u32 {
            if (num[0] == '0' and num.len > 1) return null;
            return std.fmt.parseInt(u32, num, 10) catch null;
        }

        fn order(lhs: @This(), rhs: @This()) std.math.Order {
            return std.mem.order(u32, &lhs.nums, &rhs.nums).differ() orelse
                std.mem.order(u8, lhs.build, rhs.build);
        }
    };
    var versions = std.ArrayList(Version).init(allocator);
    var dirs = std.ArrayList([]const u8).init(allocator);
    defer {
        versions.deinit();
        for (dirs.items) |filtered_dir| allocator.free(filtered_dir);
        dirs.deinit();
    }

    iterate: while (iterator.next() catch null) |entry| {
        if (entry.kind != .directory) continue;
        if (!std.mem.startsWith(u8, entry.name, prefix)) continue;

        var version: Version = .{
            .nums = .{0} ** 4,
            .build = "",
        };
        const suffix = entry.name[prefix.len..];
        const underscore = std.mem.indexOfScalar(u8, entry.name, '_');
        var num_it = std.mem.splitScalar(u8, suffix[0 .. underscore orelse suffix.len], '.');
        version.nums[0] = Version.parseNum(num_it.first()) orelse continue;
        for (version.nums[1..]) |*num|
            num.* = Version.parseNum(num_it.next() orelse break) orelse continue :iterate
        else if (num_it.next()) |_| continue;

        const name = try allocator.dupe(u8, suffix);
        errdefer allocator.free(name);
        if (underscore) |pos| version.build = name[pos + 1 ..];

        try versions.append(version);
        try dirs.append(name);
    }

    std.mem.sortUnstableContext(0, dirs.items.len, struct {
        versions: []Version,
        dirs: [][]const u8,
        pub fn lessThan(context: @This(), lhs: usize, rhs: usize) bool {
            return context.versions[lhs].order(context.versions[rhs]).compare(.gt);
        }
        pub fn swap(context: @This(), lhs: usize, rhs: usize) void {
            std.mem.swap(Version, &context.versions[lhs], &context.versions[rhs]);
            std.mem.swap([]const u8, &context.dirs[lhs], &context.dirs[rhs]);
        }
    }{ .versions = versions.items, .dirs = dirs.items });
    return dirs.toOwnedSlice();
}

const OpenOptions = struct {
    /// Sets the KEY_WOW64_32KEY access flag.
    /// https://learn.microsoft.com/en-us/windows/win32/winprog64/accessing-an-alternate-registry-view
    wow64_32: bool = false,
};

const RegistryWtf8 = struct {
    key: windows.HKEY,

    /// Assert that `key` is valid WTF-8 string
    pub fn openKey(hkey: windows.HKEY, key: []const u8, options: OpenOptions) error{KeyNotFound}!RegistryWtf8 {
        const key_wtf16le: [:0]const u16 = key_wtf16le: {
            var key_wtf16le_buf: [RegistryWtf16Le.key_name_max_len]u16 = undefined;
            const key_wtf16le_len: usize = std.unicode.wtf8ToWtf16Le(key_wtf16le_buf[0..], key) catch |err| switch (err) {
                error.InvalidWtf8 => unreachable,
            };
            key_wtf16le_buf[key_wtf16le_len] = 0;
            break :key_wtf16le key_wtf16le_buf[0..key_wtf16le_len :0];
        };

        const registry_wtf16le = try RegistryWtf16Le.openKey(hkey, key_wtf16le, options);
        return .{ .key = registry_wtf16le.key };
    }

    /// Closes key, after that usage is invalid
    pub fn closeKey(reg: RegistryWtf8) void {
        const return_code_int: windows.HRESULT = windows.advapi32.RegCloseKey(reg.key);
        const return_code: windows.Win32Error = @enumFromInt(return_code_int);
        switch (return_code) {
            .SUCCESS => {},
            else => {},
        }
    }

    /// Get string from registry.
    /// Caller owns result.
    pub fn getString(reg: RegistryWtf8, allocator: std.mem.Allocator, subkey: []const u8, value_name: []const u8) error{ OutOfMemory, ValueNameNotFound, NotAString, StringNotFound }![]u8 {
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

        const registry_wtf16le: RegistryWtf16Le = .{ .key = reg.key };
        const value_wtf16le = try registry_wtf16le.getString(allocator, subkey_wtf16le, value_name_wtf16le);
        defer allocator.free(value_wtf16le);

        const value_wtf8: []u8 = try std.unicode.wtf16LeToWtf8Alloc(allocator, value_wtf16le);
        errdefer allocator.free(value_wtf8);

        return value_wtf8;
    }

    /// Get DWORD (u32) from registry.
    pub fn getDword(reg: RegistryWtf8, subkey: []const u8, value_name: []const u8) error{ ValueNameNotFound, NotADword, DwordTooLong, DwordNotFound }!u32 {
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

        const registry_wtf16le: RegistryWtf16Le = .{ .key = reg.key };
        return registry_wtf16le.getDword(subkey_wtf16le, value_name_wtf16le);
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
        return .{ .key = registry_wtf16le.key };
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
    /// KEY_QUERY_VALUE, KEY_ENUMERATE_SUB_KEYS, optionally KEY_WOW64_32KEY.
    /// After finishing work, call `closeKey`.
    fn openKey(hkey: windows.HKEY, key_wtf16le: [:0]const u16, options: OpenOptions) error{KeyNotFound}!RegistryWtf16Le {
        var key: windows.HKEY = undefined;
        var access: windows.REGSAM = windows.KEY_QUERY_VALUE | windows.KEY_ENUMERATE_SUB_KEYS;
        if (options.wow64_32) access |= windows.KEY_WOW64_32KEY;
        const return_code_int: windows.HRESULT = windows.advapi32.RegOpenKeyExW(
            hkey,
            key_wtf16le,
            0,
            access,
            &key,
        );
        const return_code: windows.Win32Error = @enumFromInt(return_code_int);
        switch (return_code) {
            .SUCCESS => {},
            .FILE_NOT_FOUND => return error.KeyNotFound,

            else => return error.KeyNotFound,
        }
        return .{ .key = key };
    }

    /// Closes key, after that usage is invalid
    fn closeKey(reg: RegistryWtf16Le) void {
        const return_code_int: windows.HRESULT = windows.advapi32.RegCloseKey(reg.key);
        const return_code: windows.Win32Error = @enumFromInt(return_code_int);
        switch (return_code) {
            .SUCCESS => {},
            else => {},
        }
    }

    /// Get string ([:0]const u16) from registry.
    fn getString(reg: RegistryWtf16Le, allocator: std.mem.Allocator, subkey_wtf16le: [:0]const u16, value_name_wtf16le: [:0]const u16) error{ OutOfMemory, ValueNameNotFound, NotAString, StringNotFound }![]const u16 {
        var actual_type: windows.ULONG = undefined;

        // Calculating length to allocate
        var value_wtf16le_buf_size: u32 = 0; // in bytes, including any terminating NUL character or characters.
        var return_code_int: windows.HRESULT = windows.advapi32.RegGetValueW(
            reg.key,
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
            reg.key,
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
    fn getDword(reg: RegistryWtf16Le, subkey_wtf16le: [:0]const u16, value_name_wtf16le: [:0]const u16) error{ ValueNameNotFound, NotADword, DwordTooLong, DwordNotFound }!u32 {
        var actual_type: windows.ULONG = undefined;
        var reg_size: u32 = @sizeOf(u32);
        var reg_value: u32 = 0;

        const return_code_int: windows.HRESULT = windows.advapi32.RegGetValueW(
            reg.key,
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

        return .{ .key = key };
    }
};

pub const Installation = struct {
    path: []const u8,
    version: []const u8,

    /// Find path and version of Windows SDK.
    /// Caller owns the result's fields.
    /// After finishing work, call `free(allocator)`.
    fn find(
        allocator: std.mem.Allocator,
        roots_key: RegistryWtf8,
        roots_subkey: []const u8,
        prefix: []const u8,
        version_key_name: []const u8,
    ) error{ OutOfMemory, InstallationNotFound, PathTooLong, VersionTooLong }!Installation {
        roots: {
            const installation = findFromRoot(allocator, roots_key, roots_subkey, prefix) catch
                break :roots;
            if (installation.isValidVersion()) return installation;
            installation.free(allocator);
        }
        {
            const installation = try findFromInstallationFolder(allocator, version_key_name);
            if (installation.isValidVersion()) return installation;
            installation.free(allocator);
        }
        return error.InstallationNotFound;
    }

    fn findFromRoot(
        allocator: std.mem.Allocator,
        roots_key: RegistryWtf8,
        roots_subkey: []const u8,
        prefix: []const u8,
    ) error{ OutOfMemory, InstallationNotFound, PathTooLong, VersionTooLong }!Installation {
        const path = path: {
            const path_maybe_with_trailing_slash = roots_key.getString(allocator, "", roots_subkey) catch |err| switch (err) {
                error.NotAString => return error.InstallationNotFound,
                error.ValueNameNotFound => return error.InstallationNotFound,
                error.StringNotFound => return error.InstallationNotFound,

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
            break :path try path.toOwnedSlice();
        };
        errdefer allocator.free(path);

        const version = version: {
            var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
            const sdk_lib_dir_path = std.fmt.bufPrint(buf[0..], "{s}\\Lib\\", .{path}) catch |err| switch (err) {
                error.NoSpaceLeft => return error.PathTooLong,
            };
            if (!std.fs.path.isAbsolute(sdk_lib_dir_path)) return error.InstallationNotFound;

            // enumerate files in sdk path looking for latest version
            var sdk_lib_dir = std.fs.openDirAbsolute(sdk_lib_dir_path, .{
                .iterate = true,
            }) catch |err| switch (err) {
                error.NameTooLong => return error.PathTooLong,
                else => return error.InstallationNotFound,
            };
            defer sdk_lib_dir.close();

            var iterator = sdk_lib_dir.iterate();
            const versions = try iterateAndFilterByVersion(&iterator, allocator, prefix);
            defer {
                for (versions[1..]) |version| allocator.free(version);
                allocator.free(versions);
            }
            break :version versions[0];
        };
        errdefer allocator.free(version);

        return .{ .path = path, .version = version };
    }

    fn findFromInstallationFolder(
        allocator: std.mem.Allocator,
        version_key_name: []const u8,
    ) error{ OutOfMemory, InstallationNotFound, PathTooLong, VersionTooLong }!Installation {
        var key_name_buf: [RegistryWtf16Le.key_name_max_len]u8 = undefined;
        const key_name = std.fmt.bufPrint(
            &key_name_buf,
            "SOFTWARE\\Microsoft\\Microsoft SDKs\\Windows\\{s}",
            .{version_key_name},
        ) catch unreachable;
        const key = key: for ([_]bool{ true, false }) |wow6432node| {
            for ([_]windows.HKEY{ windows.HKEY_LOCAL_MACHINE, windows.HKEY_CURRENT_USER }) |hkey| {
                break :key RegistryWtf8.openKey(hkey, key_name, .{ .wow64_32 = wow6432node }) catch |err| switch (err) {
                    error.KeyNotFound => return error.InstallationNotFound,
                };
            }
        } else return error.InstallationNotFound;
        defer key.closeKey();

        const path: []const u8 = path: {
            const path_maybe_with_trailing_slash = key.getString(allocator, "", "InstallationFolder") catch |err| switch (err) {
                error.NotAString => return error.InstallationNotFound,
                error.ValueNameNotFound => return error.InstallationNotFound,
                error.StringNotFound => return error.InstallationNotFound,

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
            break :path path_without_trailing_slash;
        };
        errdefer allocator.free(path);

        const version: []const u8 = version: {

            // note(dimenus): Microsoft doesn't include the .0 in the ProductVersion key....
            const version_without_0 = key.getString(allocator, "", "ProductVersion") catch |err| switch (err) {
                error.NotAString => return error.InstallationNotFound,
                error.ValueNameNotFound => return error.InstallationNotFound,
                error.StringNotFound => return error.InstallationNotFound,

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
            break :version version_with_0;
        };
        errdefer allocator.free(version);

        return .{ .path = path, .version = version };
    }

    /// Check whether this version is enumerated in registry.
    fn isValidVersion(installation: Installation) bool {
        var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        const reg_query_as_wtf8 = std.fmt.bufPrint(buf[0..], "{s}\\{s}\\Installed Options", .{
            windows_kits_reg_key,
            installation.version,
        }) catch |err| switch (err) {
            error.NoSpaceLeft => return false,
        };

        const options_key = RegistryWtf8.openKey(
            windows.HKEY_LOCAL_MACHINE,
            reg_query_as_wtf8,
            .{ .wow64_32 = true },
        ) catch |err| switch (err) {
            error.KeyNotFound => return false,
        };
        defer options_key.closeKey();

        const option_name = comptime switch (builtin.target.cpu.arch) {
            .arm, .armeb => "OptionId.DesktopCPParm",
            .aarch64 => "OptionId.DesktopCPParm64",
            .x86_64 => "OptionId.DesktopCPPx64",
            .x86 => "OptionId.DesktopCPPx86",
            else => |tag| @compileError("Windows SDK cannot be detected on architecture " ++ tag),
        };

        const reg_value = options_key.getDword("", option_name) catch return false;
        return (reg_value == 1);
    }

    fn free(install: Installation, allocator: std.mem.Allocator) void {
        allocator.free(install.path);
        allocator.free(install.version);
    }
};

const MsvcLibDir = struct {
    fn findInstancesDirViaSetup(allocator: std.mem.Allocator) error{ OutOfMemory, PathNotFound }!std.fs.Dir {
        const vs_setup_key_path = "SOFTWARE\\Microsoft\\VisualStudio\\Setup";
        const vs_setup_key = RegistryWtf8.openKey(windows.HKEY_LOCAL_MACHINE, vs_setup_key_path, .{}) catch |err| switch (err) {
            error.KeyNotFound => return error.PathNotFound,
        };
        defer vs_setup_key.closeKey();

        const packages_path = vs_setup_key.getString(allocator, "", "CachePath") catch |err| switch (err) {
            error.NotAString,
            error.ValueNameNotFound,
            error.StringNotFound,
            => return error.PathNotFound,

            error.OutOfMemory => return error.OutOfMemory,
        };
        defer allocator.free(packages_path);

        if (!std.fs.path.isAbsolute(packages_path)) return error.PathNotFound;

        const instances_path = try std.fs.path.join(allocator, &.{ packages_path, "_Instances" });
        defer allocator.free(instances_path);

        return std.fs.openDirAbsolute(instances_path, .{ .iterate = true }) catch return error.PathNotFound;
    }

    fn findInstancesDirViaCLSID(allocator: std.mem.Allocator) error{ OutOfMemory, PathNotFound }!std.fs.Dir {
        const setup_configuration_clsid = "{177f0c4a-1cd3-4de7-a32c-71dbbb9fa36d}";
        const setup_config_key = RegistryWtf8.openKey(windows.HKEY_CLASSES_ROOT, "CLSID\\" ++ setup_configuration_clsid, .{}) catch |err| switch (err) {
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

        if (!std.fs.path.isAbsolute(dll_path)) return error.PathNotFound;

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
        // First, try getting the packages cache path from the registry.
        // This only seems to exist when the path is different from the default.
        method1: {
            return findInstancesDirViaSetup(allocator) catch |err| switch (err) {
                error.OutOfMemory => |e| return e,
                error.PathNotFound => break :method1,
            };
        }
        // Otherwise, try to get the path from the .dll that would have been
        // loaded via COM for SetupConfiguration.
        method2: {
            return findInstancesDirViaCLSID(allocator) catch |err| switch (err) {
                error.OutOfMemory => |e| return e,
                error.PathNotFound => break :method2,
            };
        }
        // If that can't be found, fall back to manually appending
        // `Microsoft\VisualStudio\Packages\_Instances` to %PROGRAMDATA%
        method3: {
            const program_data = std.process.getEnvVarOwned(allocator, "PROGRAMDATA") catch |err| switch (err) {
                error.OutOfMemory => |e| return e,
                error.InvalidWtf8 => unreachable,
                error.EnvironmentVariableNotFound => break :method3,
            };
            defer allocator.free(program_data);

            if (!std.fs.path.isAbsolute(program_data)) break :method3;

            const instances_path = try std.fs.path.join(allocator, &.{ program_data, "Microsoft", "VisualStudio", "Packages", "_Instances" });
            defer allocator.free(instances_path);

            return std.fs.openDirAbsolute(instances_path, .{ .iterate = true }) catch break :method3;
        }
        return error.PathNotFound;
    }

    /// Intended to be equivalent to `ISetupHelper.ParseVersion`
    /// Example: 17.4.33205.214 -> 0x0011000481b500d6
    fn parseVersionQuad(version: []const u8) error{InvalidVersion}!u64 {
        var it = std.mem.splitScalar(u8, version, '.');
        const a = it.first();
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
            break :vs_versions try iterateAndFilterByVersion(&iterator, allocator, "");
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

            const vs7_key = RegistryWtf8.openKey(windows.HKEY_LOCAL_MACHINE, "SOFTWARE\\Microsoft\\VisualStudio\\SxS\\VS7", .{ .wow64_32 = true }) catch return error.PathNotFound;
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
