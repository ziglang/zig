const std = @import("../std.zig");
const elf = std.elf;
const mem = std.mem;
const fs = std.fs;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const assert = std.debug.assert;
const process = std.process;
const Target = std.Target;

const is_windows = Target.current.os.tag == .windows;

pub const NativePaths = struct {
    include_dirs: ArrayList([:0]u8),
    lib_dirs: ArrayList([:0]u8),
    rpaths: ArrayList([:0]u8),
    warnings: ArrayList([:0]u8),

    pub fn detect(allocator: *Allocator) !NativePaths {
        var self: NativePaths = .{
            .include_dirs = ArrayList([:0]u8).init(allocator),
            .lib_dirs = ArrayList([:0]u8).init(allocator),
            .rpaths = ArrayList([:0]u8).init(allocator),
            .warnings = ArrayList([:0]u8).init(allocator),
        };
        errdefer self.deinit();

        var is_nix = false;
        if (process.getEnvVarOwned(allocator, "NIX_CFLAGS_COMPILE")) |nix_cflags_compile| {
            defer allocator.free(nix_cflags_compile);

            is_nix = true;
            var it = mem.tokenize(nix_cflags_compile, " ");
            while (true) {
                const word = it.next() orelse break;
                if (mem.eql(u8, word, "-isystem")) {
                    const include_path = it.next() orelse {
                        try self.addWarning("Expected argument after -isystem in NIX_CFLAGS_COMPILE");
                        break;
                    };
                    try self.addIncludeDir(include_path);
                } else {
                    try self.addWarningFmt("Unrecognized C flag from NIX_CFLAGS_COMPILE: {}", .{word});
                    break;
                }
            }
        } else |err| switch (err) {
            error.InvalidUtf8 => {},
            error.EnvironmentVariableNotFound => {},
            error.OutOfMemory => |e| return e,
        }
        if (process.getEnvVarOwned(allocator, "NIX_LDFLAGS")) |nix_ldflags| {
            defer allocator.free(nix_ldflags);

            is_nix = true;
            var it = mem.tokenize(nix_ldflags, " ");
            while (true) {
                const word = it.next() orelse break;
                if (mem.eql(u8, word, "-rpath")) {
                    const rpath = it.next() orelse {
                        try self.addWarning("Expected argument after -rpath in NIX_LDFLAGS");
                        break;
                    };
                    try self.addRPath(rpath);
                } else if (word.len > 2 and word[0] == '-' and word[1] == 'L') {
                    const lib_path = word[2..];
                    try self.addLibDir(lib_path);
                } else {
                    try self.addWarningFmt("Unrecognized C flag from NIX_LDFLAGS: {}", .{word});
                    break;
                }
            }
        } else |err| switch (err) {
            error.InvalidUtf8 => {},
            error.EnvironmentVariableNotFound => {},
            error.OutOfMemory => |e| return e,
        }
        if (is_nix) {
            return self;
        }

        if (!is_windows) {
            const triple = try Target.current.linuxTriple(allocator);

            // TODO: $ ld --verbose | grep SEARCH_DIR
            // the output contains some paths that end with lib64, maybe include them too?
            // TODO: what is the best possible order of things?
            // TODO: some of these are suspect and should only be added on some systems. audit needed.

            try self.addIncludeDir("/usr/local/include");
            try self.addLibDir("/usr/local/lib");
            try self.addLibDir("/usr/local/lib64");

            try self.addIncludeDirFmt("/usr/include/{}", .{triple});
            try self.addLibDirFmt("/usr/lib/{}", .{triple});

            try self.addIncludeDir("/usr/include");
            try self.addLibDir("/lib");
            try self.addLibDir("/lib64");
            try self.addLibDir("/usr/lib");
            try self.addLibDir("/usr/lib64");

            // example: on a 64-bit debian-based linux distro, with zlib installed from apt:
            // zlib.h is in /usr/include (added above)
            // libz.so.1 is in /lib/x86_64-linux-gnu (added here)
            try self.addLibDirFmt("/lib/{}", .{triple});
        }

        return self;
    }

    pub fn deinit(self: *NativePaths) void {
        deinitArray(&self.include_dirs);
        deinitArray(&self.lib_dirs);
        deinitArray(&self.rpaths);
        deinitArray(&self.warnings);
        self.* = undefined;
    }

    fn deinitArray(array: *ArrayList([:0]u8)) void {
        for (array.toSlice()) |item| {
            array.allocator.free(item);
        }
        array.deinit();
    }

    pub fn addIncludeDir(self: *NativePaths, s: []const u8) !void {
        return self.appendArray(&self.include_dirs, s);
    }

    pub fn addIncludeDirFmt(self: *NativePaths, comptime fmt: []const u8, args: var) !void {
        const item = try std.fmt.allocPrint0(self.include_dirs.allocator, fmt, args);
        errdefer self.include_dirs.allocator.free(item);
        try self.include_dirs.append(item);
    }

    pub fn addLibDir(self: *NativePaths, s: []const u8) !void {
        return self.appendArray(&self.lib_dirs, s);
    }

    pub fn addLibDirFmt(self: *NativePaths, comptime fmt: []const u8, args: var) !void {
        const item = try std.fmt.allocPrint0(self.lib_dirs.allocator, fmt, args);
        errdefer self.lib_dirs.allocator.free(item);
        try self.lib_dirs.append(item);
    }

    pub fn addWarning(self: *NativePaths, s: []const u8) !void {
        return self.appendArray(&self.warnings, s);
    }

    pub fn addWarningFmt(self: *NativePaths, comptime fmt: []const u8, args: var) !void {
        const item = try std.fmt.allocPrint0(self.warnings.allocator, fmt, args);
        errdefer self.warnings.allocator.free(item);
        try self.warnings.append(item);
    }

    pub fn addRPath(self: *NativePaths, s: []const u8) !void {
        return self.appendArray(&self.rpaths, s);
    }

    fn appendArray(self: *NativePaths, array: *ArrayList([:0]u8), s: []const u8) !void {
        const item = try std.mem.dupeZ(array.allocator, u8, s);
        errdefer array.allocator.free(item);
        try array.append(item);
    }
};

pub const NativeTargetInfo = struct {
    target: Target,

    /// Contains the memory used to store the dynamic linker path. This field should
    /// not be used directly. See `dynamicLinker` and `setDynamicLinker`. This field
    /// exists so that this API requires no allocator.
    dynamic_linker_buffer: [255]u8 = undefined,

    /// Used to construct the dynamic linker path. This field should not be used
    /// directly. See `dynamicLinker` and `setDynamicLinker`.
    dynamic_linker_max: ?u8 = null,

    pub const DetectError = error{
        OutOfMemory,
        FileSystem,
        SystemResources,
        SymLinkLoop,
        ProcessFdQuotaExceeded,
        SystemFdQuotaExceeded,
        DeviceBusy,
    };

    /// Detects the native CPU model & features, operating system & version, and C ABI & dynamic linker.
    /// On Linux, this is additionally responsible for detecting the native glibc version when applicable.
    /// TODO Remove the allocator requirement from this.
    pub fn detect(allocator: *Allocator) DetectError!NativeTargetInfo {
        const arch = Target.current.cpu.arch;
        const os_tag = Target.current.os.tag;

        // TODO Detect native CPU model & features. Until that is implemented we hard code baseline.
        const cpu = Target.Cpu.baseline(arch);

        // TODO Detect native operating system version. Until that is implemented we use the default range.
        const os = Target.Os.defaultVersionRange(os_tag);

        return detectAbiAndDynamicLinker(allocator, cpu, os);
    }

    /// Must be the same `Allocator` passed to `detect`.
    pub fn deinit(self: *NativeTargetInfo, allocator: *Allocator) void {
        if (self.dynamic_linker) |dl| allocator.free(dl);
        self.* = undefined;
    }

    /// The returned memory has the same lifetime as the `NativeTargetInfo`.
    pub fn dynamicLinker(self: *const NativeTargetInfo) ?[]const u8 {
        const m = self.dynamic_linker_max orelse return null;
        return self.dynamic_linker_buffer[0 .. m + 1];
    }

    pub fn setDynamicLinker(self: *NativeTargetInfo, dl_or_null: ?[]const u8) void {
        if (dl_or_null) |dl| {
            mem.copy(u8, &self.dynamic_linker_buffer, dl);
            self.dynamic_linker_max = @intCast(u8, dl.len - 1);
        } else {
            self.dynamic_linker_max = null;
        }
    }

    /// First we attempt to use the executable's own binary. If it is dynamically
    /// linked, then it should answer both the C ABI question and the dynamic linker question.
    /// If it is statically linked, then we try /usr/bin/env. If that does not provide the answer, then
    /// we fall back to the defaults.
    fn detectAbiAndDynamicLinker(
        allocator: *Allocator,
        cpu: Target.Cpu,
        os: Target.Os,
    ) DetectError!NativeTargetInfo {
        if (!comptime Target.current.hasDynamicLinker()) {
            return defaultAbiAndDynamicLinker(allocator, cpu, os);
        }
        // The current target's ABI cannot be relied on for this. For example, we may build the zig
        // compiler for target riscv64-linux-musl and provide a tarball for users to download.
        // A user could then run that zig compiler on riscv64-linux-gnu. This use case is well-defined
        // and supported by Zig. But that means that we must detect the system ABI here rather than
        // relying on `Target.current`.
        const LdInfo = struct {
            ld_path: []u8,
            abi: Target.Abi,
        };
        var ld_info_list = std.ArrayList(LdInfo).init(allocator);
        defer {
            for (ld_info_list.toSlice()) |ld_info| allocator.free(ld_info.ld_path);
            ld_info_list.deinit();
        }

        const all_abis = comptime blk: {
            assert(@enumToInt(Target.Abi.none) == 0);
            const fields = std.meta.fields(Target.Abi)[1..];
            var array: [fields.len]Target.Abi = undefined;
            inline for (fields) |field, i| {
                array[i] = @field(Target.Abi, field.name);
            }
            break :blk array;
        };
        for (all_abis) |abi| {
            // This may be a nonsensical parameter. We detect this with error.UnknownDynamicLinkerPath and
            // skip adding it to `ld_info_list`.
            const target: Target = .{
                .cpu = cpu,
                .os = os,
                .abi = abi,
            };
            var buf: [255]u8 = undefined;
            const standard_ld_path = if (target.standardDynamicLinkerPath(&buf)) |s|
                try mem.dupe(allocator, u8, s)
            else
                continue;
            errdefer allocator.free(standard_ld_path);
            try ld_info_list.append(.{
                .ld_path = standard_ld_path,
                .abi = abi,
            });
        }

        // Best case scenario: the executable is dynamically linked, and we can iterate
        // over our own shared objects and find a dynamic linker.
        self_exe: {
            const lib_paths = try std.process.getSelfExeSharedLibPaths(allocator);
            defer allocator.free(lib_paths);

            var found_ld_info: LdInfo = undefined;
            var found_ld_path: [:0]const u8 = undefined;

            // Look for dynamic linker.
            // This is O(N^M) but typical case here is N=2 and M=10.
            find_ld: for (lib_paths) |lib_path| {
                for (ld_info_list.toSlice()) |ld_info| {
                    const standard_ld_basename = fs.path.basename(ld_info.ld_path);
                    if (std.mem.endsWith(u8, lib_path, standard_ld_basename)) {
                        found_ld_info = ld_info;
                        found_ld_path = lib_path;
                        break :find_ld;
                    }
                }
            } else break :self_exe;

            // Look for glibc version.
            var os_adjusted = os;
            if (Target.current.os.tag == .linux and found_ld_info.abi.isGnu()) {
                for (lib_paths) |lib_path| {
                    if (std.mem.endsWith(u8, lib_path, glibc_so_basename)) {
                        os_adjusted.version_range.linux.glibc = glibcVerFromSO(lib_path) catch |err| switch (err) {
                            error.UnrecognizedGnuLibCFileName => continue,
                            error.InvalidGnuLibCVersion => continue,
                            error.GnuLibCVersionUnavailable => continue,
                            else => |e| return e,
                        };
                        break;
                    }
                }
            }

            var result: NativeTargetInfo = .{
                .target = .{
                    .cpu = cpu,
                    .os = os_adjusted,
                    .abi = found_ld_info.abi,
                },
            };
            result.setDynamicLinker(found_ld_path);
            return result;
        }

        // If Zig is statically linked, such as via distributed binary static builds, the above
        // trick won't work. The next thing we fall back to is the same thing, but for /usr/bin/env.
        // Since that path is hard-coded into the shebang line of many portable scripts, it's a
        // reasonably reliable path to check for.
        return abiAndDynamicLinkerFromUsrBinEnv(cpu, os) catch |err| switch (err) {
            error.FileSystem,
            error.SystemResources,
            error.SymLinkLoop,
            error.ProcessFdQuotaExceeded,
            error.SystemFdQuotaExceeded,
            error.DeviceBusy,
            => |e| return e,

            error.UnableToReadElfFile,
            error.ElfNotADynamicExecutable,
            error.InvalidElfProgramHeaders,
            error.InvalidElfClass,
            error.InvalidElfVersion,
            error.InvalidElfEndian,
            error.InvalidElfFile,
            error.InvalidElfMagic,
            error.UsrBinEnvNotAvailable,
            error.Unexpected,
            error.UnexpectedEndOfFile,
            error.NameTooLong,
            // Finally, we fall back on the standard path.
            => defaultAbiAndDynamicLinker(allocator, cpu, os),
        };
    }

    const glibc_so_basename = "libc.so.6";

    fn glibcVerFromSO(so_path: [:0]const u8) !std.builtin.Version {
        var link_buf: [std.os.PATH_MAX]u8 = undefined;
        const link_name = std.os.readlinkC(so_path.ptr, &link_buf) catch |err| switch (err) {
            error.AccessDenied => return error.GnuLibCVersionUnavailable,
            error.FileSystem => return error.FileSystem,
            error.SymLinkLoop => return error.SymLinkLoop,
            error.NameTooLong => unreachable,
            error.FileNotFound => return error.GnuLibCVersionUnavailable,
            error.SystemResources => return error.SystemResources,
            error.NotDir => return error.GnuLibCVersionUnavailable,
            error.Unexpected => return error.GnuLibCVersionUnavailable,
        };
        // example: "libc-2.3.4.so"
        // example: "libc-2.27.so"
        const prefix = "libc-";
        const suffix = ".so";
        if (!mem.startsWith(u8, link_name, prefix) or !mem.endsWith(u8, link_name, suffix)) {
            return error.UnrecognizedGnuLibCFileName;
        }
        // chop off "libc-" and ".so"
        const link_name_chopped = link_name[prefix.len .. link_name.len - suffix.len];
        return std.builtin.Version.parse(link_name_chopped) catch |err| switch (err) {
            error.Overflow => return error.InvalidGnuLibCVersion,
            error.InvalidCharacter => return error.InvalidGnuLibCVersion,
            error.InvalidVersion => return error.InvalidGnuLibCVersion,
        };
    }

    fn abiAndDynamicLinkerFromUsrBinEnv(cpu: Target.Cpu, os: Target.Os) !NativeTargetInfo {
        const env_file = std.fs.openFileAbsoluteC("/usr/bin/env", .{}) catch |err| switch (err) {
            error.NoSpaceLeft => unreachable,
            error.NameTooLong => unreachable,
            error.PathAlreadyExists => unreachable,
            error.SharingViolation => unreachable,
            error.InvalidUtf8 => unreachable,
            error.BadPathName => unreachable,
            error.PipeBusy => unreachable,

            error.IsDir => return error.UsrBinEnvNotAvailable,
            error.NotDir => return error.UsrBinEnvNotAvailable,
            error.AccessDenied => return error.UsrBinEnvNotAvailable,
            error.NoDevice => return error.UsrBinEnvNotAvailable,
            error.FileNotFound => return error.UsrBinEnvNotAvailable,
            error.FileTooBig => return error.UsrBinEnvNotAvailable,

            else => |e| return e,
        };
        var hdr_buf: [@sizeOf(elf.Elf64_Ehdr)]u8 align(@alignOf(elf.Elf64_Ehdr)) = undefined;
        const hdr_bytes_len = try wrapRead(env_file.pread(&hdr_buf, 0));
        if (hdr_bytes_len < @sizeOf(elf.Elf32_Ehdr)) return error.InvalidElfFile;
        const hdr32 = @ptrCast(*elf.Elf32_Ehdr, &hdr_buf);
        const hdr64 = @ptrCast(*elf.Elf64_Ehdr, &hdr_buf);
        if (!mem.eql(u8, hdr32.e_ident[0..4], "\x7fELF")) return error.InvalidElfMagic;
        const elf_endian: std.builtin.Endian = switch (hdr32.e_ident[elf.EI_DATA]) {
            elf.ELFDATA2LSB => .Little,
            elf.ELFDATA2MSB => .Big,
            else => return error.InvalidElfEndian,
        };
        const need_bswap = elf_endian != std.builtin.endian;
        if (hdr32.e_ident[elf.EI_VERSION] != 1) return error.InvalidElfVersion;

        const is_64 = switch (hdr32.e_ident[elf.EI_CLASS]) {
            elf.ELFCLASS32 => false,
            elf.ELFCLASS64 => true,
            else => return error.InvalidElfClass,
        };
        var phoff = elfInt(is_64, need_bswap, hdr32.e_phoff, hdr64.e_phoff);
        const phentsize = elfInt(is_64, need_bswap, hdr32.e_phentsize, hdr64.e_phentsize);
        const phnum = elfInt(is_64, need_bswap, hdr32.e_phnum, hdr64.e_phnum);
        const shstrndx = elfInt(is_64, need_bswap, hdr32.e_shstrndx, hdr64.e_shstrndx);

        var result: NativeTargetInfo = .{
            .target = .{
                .cpu = cpu,
                .os = os,
                .abi = Target.Abi.default(cpu.arch, os),
            },
        };

        const ph_total_size = std.math.mul(u32, phentsize, phnum) catch |err| switch (err) {
            error.Overflow => return error.InvalidElfProgramHeaders,
        };
        var ph_buf: [16 * @sizeOf(elf.Elf64_Phdr)]u8 align(@alignOf(elf.Elf64_Phdr)) = undefined;
        var ph_i: u16 = 0;
        while (ph_i < phnum) {
            // Reserve some bytes so that we can deref the 64-bit struct fields even when the ELF file is 32-bits.
            const reserve = @sizeOf(elf.Elf64_Phdr) - @sizeOf(elf.Elf32_Phdr);
            const read_byte_len = try wrapRead(env_file.pread(ph_buf[0 .. ph_buf.len - reserve], phoff));
            if (read_byte_len < phentsize) return error.ElfNotADynamicExecutable;
            var buf_i: usize = 0;
            while (buf_i < read_byte_len and ph_i < phnum) : ({
                ph_i += 1;
                phoff += phentsize;
                buf_i += phentsize;
            }) {
                const ph32 = @ptrCast(*elf.Elf32_Phdr, @alignCast(@alignOf(elf.Elf32_Phdr), &ph_buf[buf_i]));
                const ph64 = @ptrCast(*elf.Elf64_Phdr, @alignCast(@alignOf(elf.Elf64_Phdr), &ph_buf[buf_i]));
                const p_type = elfInt(is_64, need_bswap, ph32.p_type, ph64.p_type);
                switch (p_type) {
                    elf.PT_INTERP => {
                        const p_offset = elfInt(is_64, need_bswap, ph32.p_offset, ph64.p_offset);
                        const p_filesz = elfInt(is_64, need_bswap, ph32.p_filesz, ph64.p_filesz);
                        var interp_buf: [255]u8 = undefined;
                        if (p_filesz > interp_buf.len) return error.NameTooLong;
                        var read_offset: usize = 0;
                        while (true) {
                            const len = try wrapRead(env_file.pread(
                                interp_buf[read_offset .. p_filesz - read_offset],
                                p_offset + read_offset,
                            ));
                            if (len == 0) return error.UnexpectedEndOfFile;
                            read_offset += len;
                            if (read_offset == p_filesz) break;
                        }
                        // PT_INTERP includes a null byte in p_filesz.
                        result.setDynamicLinker(interp_buf[0 .. p_filesz - 1]);
                    },
                    elf.PT_DYNAMIC => {
                        std.debug.warn("found PT_DYNAMIC\n", .{});
                    },
                    else => continue,
                }
            }
        }

        return result;
    }

    fn wrapRead(res: std.os.ReadError!usize) !usize {
        return res catch |err| switch (err) {
            error.OperationAborted => unreachable, // Windows-only
            error.WouldBlock => unreachable, // Did not request blocking mode
            error.SystemResources => return error.SystemResources,
            error.IsDir => return error.UnableToReadElfFile,
            error.BrokenPipe => return error.UnableToReadElfFile,
            error.ConnectionResetByPeer => return error.UnableToReadElfFile,
            error.Unexpected => return error.Unexpected,
            error.InputOutput => return error.FileSystem,
        };
    }

    fn defaultAbiAndDynamicLinker(allocator: *Allocator, cpu: Target.Cpu, os: Target.Os) !NativeTargetInfo {
        var result: NativeTargetInfo = .{
            .target = .{
                .cpu = cpu,
                .os = os,
                .abi = Target.Abi.default(cpu.arch, os),
            },
        };
        if (result.target.standardDynamicLinkerPath(&result.dynamic_linker_buffer)) |s| {
            result.dynamic_linker_max = @intCast(u8, s.len - 1);
        }
        return result;
    }
};

fn elfInt(is_64: bool, need_bswap: bool, int_32: var, int_64: var) @TypeOf(int_64) {
    if (is_64) {
        if (need_bswap) {
            return @byteSwap(@TypeOf(int_64), int_64);
        } else {
            return int_64;
        }
    } else {
        if (need_bswap) {
            return @byteSwap(@TypeOf(int_32), int_32);
        } else {
            return int_32;
        }
    }
}
