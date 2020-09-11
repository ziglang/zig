const std = @import("std");
const Allocator = std.mem.Allocator;
const target_util = @import("target.zig");
const mem = std.mem;

pub const Lib = struct {
    name: []const u8,
    sover: u8,
};

pub const Fn = struct {
    name: []const u8,
    lib: *const Lib,
};

pub const VerList = struct {
    /// 7 is just the max number, we know statically it's big enough.
    versions: [7]u8,
    len: u8,
};

pub const ABI = struct {
    all_versions: []const std.builtin.Version,
    all_functions: []const Fn,
    /// The value is a pointer to all_functions.len items and each item is an index into all_functions.
    version_table: std.AutoHashMapUnmanaged(target_util.ArchOsAbi, [*]VerList),
    arena_state: std.heap.ArenaAllocator.State,

    pub fn destroy(abi: *ABI, gpa: *Allocator) void {
        abi.version_table.deinit(gpa);
        abi.arena_state.promote(gpa).deinit(); // Frees the ABI memory too.
    }
};

pub const libs = [_]Lib{
    .{ .name = "c", .sover = 6 },
    .{ .name = "m", .sover = 6 },
    .{ .name = "pthread", .sover = 0 },
    .{ .name = "dl", .sover = 2 },
    .{ .name = "rt", .sover = 1 },
    .{ .name = "ld", .sover = 2 },
    .{ .name = "util", .sover = 1 },
};

pub const LoadMetaDataError = error{
    /// The files that ship with the Zig compiler were unable to be read, or otherwise had malformed data.
    ZigInstallationCorrupt,
    OutOfMemory,
};

/// This function will emit a log error when there is a problem with the zig installation and then return
/// `error.ZigInstallationCorrupt`.
pub fn loadMetaData(gpa: *Allocator, zig_lib_dir: std.fs.Dir) LoadMetaDataError!*ABI {
    var arena_allocator = std.heap.ArenaAllocator.init(gpa);
    errdefer arena_allocator.deinit();
    const arena = &arena_allocator.allocator;

    var all_versions = std.ArrayListUnmanaged(std.builtin.Version){};
    var all_functions = std.ArrayListUnmanaged(Fn){};
    var version_table = std.AutoHashMapUnmanaged(target_util.ArchOsAbi, [*]VerList){};
    errdefer version_table.deinit(gpa);

    var glibc_dir = zig_lib_dir.openDir("libc" ++ std.fs.path.sep_str ++ "glibc", .{}) catch |err| {
        std.log.err("unable to open glibc dir: {}", .{@errorName(err)});
        return error.ZigInstallationCorrupt;
    };
    defer glibc_dir.close();

    const max_txt_size = 500 * 1024; // Bigger than this and something is definitely borked.
    const vers_txt_contents = glibc_dir.readFileAlloc(gpa, "vers.txt", max_txt_size) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => {
            std.log.err("unable to read vers.txt: {}", .{@errorName(err)});
            return error.ZigInstallationCorrupt;
        },
    };
    defer gpa.free(vers_txt_contents);

    const fns_txt_contents = glibc_dir.readFileAlloc(gpa, "fns.txt", max_txt_size) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => {
            std.log.err("unable to read fns.txt: {}", .{@errorName(err)});
            return error.ZigInstallationCorrupt;
        },
    };
    defer gpa.free(fns_txt_contents);

    const abi_txt_contents = glibc_dir.readFileAlloc(gpa, "abi.txt", max_txt_size) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => {
            std.log.err("unable to read abi.txt: {}", .{@errorName(err)});
            return error.ZigInstallationCorrupt;
        },
    };
    defer gpa.free(abi_txt_contents);

    {
        var it = mem.tokenize(vers_txt_contents, "\r\n");
        var line_i: usize = 1;
        while (it.next()) |line| : (line_i += 1) {
            const prefix = "GLIBC_";
            if (!mem.startsWith(u8, line, prefix)) {
                std.log.err("vers.txt:{}: expected 'GLIBC_' prefix", .{line_i});
                return error.ZigInstallationCorrupt;
            }
            const adjusted_line = line[prefix.len..];
            const ver = std.builtin.Version.parse(adjusted_line) catch |err| {
                std.log.err("vers.txt:{}: unable to parse glibc version '{}': {}", .{ line_i, line, @errorName(err) });
                return error.ZigInstallationCorrupt;
            };
            try all_versions.append(arena, ver);
        }
    }
    {
        var file_it = mem.tokenize(fns_txt_contents, "\r\n");
        var line_i: usize = 1;
        while (file_it.next()) |line| : (line_i += 1) {
            var line_it = mem.tokenize(line, " ");
            const fn_name = line_it.next() orelse {
                std.log.err("fns.txt:{}: expected function name", .{line_i});
                return error.ZigInstallationCorrupt;
            };
            const lib_name = line_it.next() orelse {
                std.log.err("fns.txt:{}: expected library name", .{line_i});
                return error.ZigInstallationCorrupt;
            };
            const lib = findLib(lib_name) orelse {
                std.log.err("fns.txt:{}: unknown library name: {}", .{ line_i, lib_name });
                return error.ZigInstallationCorrupt;
            };
            try all_functions.append(arena, .{
                .name = fn_name,
                .lib = lib,
            });
        }
    }
    {
        var file_it = mem.split(abi_txt_contents, "\n");
        var line_i: usize = 0;
        while (true) {
            const ver_list_base: []VerList = blk: {
                const line = file_it.next() orelse break;
                if (line.len == 0) break;
                line_i += 1;
                const ver_list_base = try arena.alloc(VerList, all_functions.items.len);
                var line_it = mem.tokenize(line, " ");
                while (line_it.next()) |target_string| {
                    var component_it = mem.tokenize(target_string, "-");
                    const arch_name = component_it.next() orelse {
                        std.log.err("abi.txt:{}: expected arch name", .{line_i});
                        return error.ZigInstallationCorrupt;
                    };
                    const os_name = component_it.next() orelse {
                        std.log.err("abi.txt:{}: expected OS name", .{line_i});
                        return error.ZigInstallationCorrupt;
                    };
                    const abi_name = component_it.next() orelse {
                        std.log.err("abi.txt:{}: expected ABI name", .{line_i});
                        return error.ZigInstallationCorrupt;
                    };
                    const arch_tag = std.meta.stringToEnum(std.Target.Cpu.Arch, arch_name) orelse {
                        std.log.err("abi.txt:{}: unrecognized arch: '{}'", .{ line_i, arch_name });
                        return error.ZigInstallationCorrupt;
                    };
                    if (!mem.eql(u8, os_name, "linux")) {
                        std.log.err("abi.txt:{}: expected OS 'linux', found '{}'", .{ line_i, os_name });
                        return error.ZigInstallationCorrupt;
                    }
                    const abi_tag = std.meta.stringToEnum(std.Target.Abi, abi_name) orelse {
                        std.log.err("abi.txt:{}: unrecognized ABI: '{}'", .{ line_i, abi_name });
                        return error.ZigInstallationCorrupt;
                    };

                    const triple = target_util.ArchOsAbi{
                        .arch = arch_tag,
                        .os = .linux,
                        .abi = abi_tag,
                    };
                    try version_table.put(arena, triple, ver_list_base.ptr);
                }
                break :blk ver_list_base;
            };
            for (ver_list_base) |*ver_list| {
                const line = file_it.next() orelse {
                    std.log.err("abi.txt:{}: missing version number line", .{line_i});
                    return error.ZigInstallationCorrupt;
                };
                line_i += 1;

                ver_list.* = .{
                    .versions = undefined,
                    .len = 0,
                };
                var line_it = mem.tokenize(line, " ");
                while (line_it.next()) |version_index_string| {
                    if (ver_list.len >= ver_list.versions.len) {
                        // If this happens with legit data, increase the array len in the type.
                        std.log.err("abi.txt:{}: too many versions", .{line_i});
                        return error.ZigInstallationCorrupt;
                    }
                    const version_index = std.fmt.parseInt(u8, version_index_string, 10) catch |err| {
                        // If this happens with legit data, increase the size of the integer type in the struct.
                        std.log.err("abi.txt:{}: unable to parse version: {}", .{ line_i, @errorName(err) });
                        return error.ZigInstallationCorrupt;
                    };

                    ver_list.versions[ver_list.len] = version_index;
                    ver_list.len += 1;
                }
            }
        }
    }

    const abi = try arena.create(ABI);
    abi.* = .{
        .all_versions = all_versions.items,
        .all_functions = all_functions.items,
        .version_table = version_table,
        .arena_state = arena_allocator.state,
    };
    return abi;
}

fn findLib(name: []const u8) ?*const Lib {
    for (libs) |*lib| {
        if (mem.eql(u8, lib.name, name)) {
            return lib;
        }
    }
    return null;
}
