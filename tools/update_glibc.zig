const std = @import("std");
const fs = std.fs;
const fmt = std.fmt;
const assert = std.debug.assert;

// Example abilist path:
// ./sysdeps/unix/sysv/linux/aarch64/libc.abilist
const AbiList = struct {
    targets: []const ZigTarget,
    path: []const u8,
};
const ZigTarget = struct {
    arch: std.Target.Cpu.Arch,
    abi: std.Target.Abi,
};

const lib_names = [_][]const u8{
    "c",
    "dl",
    "m",
    "pthread",
    "rt",
    "ld",
    "util",
};

// fpu/nofpu are hardcoded elsewhere, based on .gnueabi/.gnueabihf with an exception for .arm
// n64/n32 are hardcoded elsewhere, based on .gnuabi64/.gnuabin32
const abi_lists = [_]AbiList{
    AbiList{
        .targets = &[_]ZigTarget{
            ZigTarget{ .arch = .aarch64, .abi = .gnu },
            ZigTarget{ .arch = .aarch64_be, .abi = .gnu },
        },
        .path = "aarch64",
    },
    AbiList{
        .targets = &[_]ZigTarget{ZigTarget{ .arch = .s390x, .abi = .gnu }},
        .path = "s390/s390-64",
    },
    AbiList{
        .targets = &[_]ZigTarget{
            ZigTarget{ .arch = .arm, .abi = .gnueabi },
            ZigTarget{ .arch = .armeb, .abi = .gnueabi },
            ZigTarget{ .arch = .arm, .abi = .gnueabihf },
            ZigTarget{ .arch = .armeb, .abi = .gnueabihf },
        },
        .path = "arm",
    },
    AbiList{
        .targets = &[_]ZigTarget{
            ZigTarget{ .arch = .sparc, .abi = .gnu },
            ZigTarget{ .arch = .sparcel, .abi = .gnu },
        },
        .path = "sparc/sparc32",
    },
    AbiList{
        .targets = &[_]ZigTarget{ZigTarget{ .arch = .sparcv9, .abi = .gnu }},
        .path = "sparc/sparc64",
    },
    AbiList{
        .targets = &[_]ZigTarget{
            ZigTarget{ .arch = .mips64el, .abi = .gnuabi64 },
            ZigTarget{ .arch = .mips64, .abi = .gnuabi64 },
        },
        .path = "mips/mips64",
    },
    AbiList{
        .targets = &[_]ZigTarget{
            ZigTarget{ .arch = .mips64el, .abi = .gnuabin32 },
            ZigTarget{ .arch = .mips64, .abi = .gnuabin32 },
        },
        .path = "mips/mips64",
    },
    AbiList{
        .targets = &[_]ZigTarget{
            ZigTarget{ .arch = .mipsel, .abi = .gnueabihf },
            ZigTarget{ .arch = .mips, .abi = .gnueabihf },
        },
        .path = "mips/mips32",
    },
    AbiList{
        .targets = &[_]ZigTarget{
            ZigTarget{ .arch = .mipsel, .abi = .gnueabi },
            ZigTarget{ .arch = .mips, .abi = .gnueabi },
        },
        .path = "mips/mips32",
    },
    AbiList{
        .targets = &[_]ZigTarget{ZigTarget{ .arch = .x86_64, .abi = .gnu }},
        .path = "x86_64/64",
    },
    AbiList{
        .targets = &[_]ZigTarget{ZigTarget{ .arch = .x86_64, .abi = .gnux32 }},
        .path = "x86_64/x32",
    },
    AbiList{
        .targets = &[_]ZigTarget{ZigTarget{ .arch = .i386, .abi = .gnu }},
        .path = "i386",
    },
    AbiList{
        .targets = &[_]ZigTarget{ZigTarget{ .arch = .powerpc64le, .abi = .gnu }},
        .path = "powerpc/powerpc64",
    },
    AbiList{
        .targets = &[_]ZigTarget{ZigTarget{ .arch = .powerpc64, .abi = .gnu }},
        .path = "powerpc/powerpc64",
    },
    AbiList{
        .targets = &[_]ZigTarget{
            ZigTarget{ .arch = .powerpc, .abi = .gnueabi },
            ZigTarget{ .arch = .powerpc, .abi = .gnueabihf },
        },
        .path = "powerpc/powerpc32",
    },
};

const FunctionSet = struct {
    list: std.ArrayList(VersionedFn),
    fn_vers_list: FnVersionList,
};
const FnVersionList = std.StringHashMap(std.ArrayList(usize));

const VersionedFn = struct {
    ver: []const u8, // example: "GLIBC_2.15"
    name: []const u8, // example: "puts"
};
const Function = struct {
    name: []const u8, // example: "puts"
    lib: []const u8, // example: "c"
    index: usize,
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = &arena.allocator;
    const args = try std.process.argsAlloc(allocator);
    const in_glibc_dir = args[1]; // path to the unzipped tarball of glibc, e.g. ~/downloads/glibc-2.25
    const zig_src_dir = args[2]; // path to the source checkout of zig, lib dir, e.g. ~/zig-src/lib
    const glibc_version = args[3]; // glibc version that will be updated, e.g. 2.32; 2.19; 2.2.5 etc.
    const glibc_version_target = try std.builtin.Version.parse(glibc_version);

    const prefix = try fs.path.join(allocator, &[_][]const u8{ in_glibc_dir, "sysdeps", "unix", "sysv", "linux" });
    var glibc_out_dir = try fs.path.join(allocator, &[_][]const u8{ zig_src_dir, "libc", "glibc", "symbols" });

    // Check if version directory is already created, and create if it is not.
    var symbols_dir = try fs.cwd().openDir(glibc_out_dir, .{});
    var out_dir: std.fs.Dir = undefined;
    {
        defer symbols_dir.close();
        out_dir = symbols_dir.openDir(glibc_version, .{}) catch |err| switch (err) {
            error.FileNotFound => blk: {
                try symbols_dir.makeDir(glibc_version);
                break :blk try symbols_dir.openDir(glibc_version, .{});
            },
            else => {
                return err;
            },
        };
    }
    defer out_dir.close();

    var global_fn_set = std.StringHashMap(Function).init(allocator);
    var global_ver_set = std.StringHashMap(usize).init(allocator);
    var target_functions = std.AutoHashMap(usize, FunctionSet).init(allocator);

    for (abi_lists) |*abi_list| {
        const target_funcs_gop = try target_functions.getOrPut(@ptrToInt(abi_list));
        if (!target_funcs_gop.found_existing) {
            target_funcs_gop.value_ptr.* = FunctionSet{
                .list = std.ArrayList(VersionedFn).init(allocator),
                .fn_vers_list = FnVersionList.init(allocator),
            };
        }
        const fn_set = &target_funcs_gop.value_ptr.list;

        // glibc 2.31 added sysdeps/unix/sysv/linux/arm/le and sysdeps/unix/sysv/linux/arm/be
        // Before these directories did not exist.
        const ver30 = std.builtin.Version{
            .major = 2,
            .minor = 30,
        };
        // Similarly, powerpc64 le and be were introduced in glibc 2.29
        const ver28 = std.builtin.Version{
            .major = 2,
            .minor = 28,
        };

        for (lib_names) |lib_name| {
            const lib_prefix = if (std.mem.eql(u8, lib_name, "ld")) "" else "lib";
            const basename = try fmt.allocPrint(allocator, "{s}{s}.abilist", .{ lib_prefix, lib_name });
            const abi_list_filename = blk: {
                const is_c = std.mem.eql(u8, lib_name, "c");
                const is_m = std.mem.eql(u8, lib_name, "m");
                const is_ld = std.mem.eql(u8, lib_name, "ld");
                if (abi_list.targets[0].abi == .gnuabi64 and (is_c or is_ld)) {
                    break :blk try fs.path.join(allocator, &[_][]const u8{ prefix, abi_list.path, "n64", basename });
                } else if (abi_list.targets[0].abi == .gnuabin32 and (is_c or is_ld)) {
                    break :blk try fs.path.join(allocator, &[_][]const u8{ prefix, abi_list.path, "n32", basename });
                } else if (abi_list.targets[0].arch != .arm and
                    abi_list.targets[0].abi == .gnueabihf and
                    (is_c or (is_m and abi_list.targets[0].arch == .powerpc)))
                {
                    break :blk try fs.path.join(allocator, &[_][]const u8{ prefix, abi_list.path, "fpu", basename });
                } else if (abi_list.targets[0].arch != .arm and
                    abi_list.targets[0].abi == .gnueabi and
                    (is_c or (is_m and abi_list.targets[0].arch == .powerpc)))
                {
                    break :blk try fs.path.join(allocator, &[_][]const u8{ prefix, abi_list.path, "nofpu", basename });
                } else if ((abi_list.targets[0].arch == .armeb or abi_list.targets[0].arch == .arm) and glibc_version_target.order(ver30) == .gt) {
                    var le_be = "le";
                    if (abi_list.targets[0].arch == .armeb) {
                        le_be = "be";
                    }
                    break :blk try fs.path.join(allocator, &[_][]const u8{ prefix, abi_list.path, le_be, basename });
                } else if ((abi_list.targets[0].arch == .powerpc64le or abi_list.targets[0].arch == .powerpc64) and glibc_version_target.order(ver28) == .gt) {
                    var le_be = "le";
                    if (abi_list.targets[0].arch == .powerpc64) {
                        le_be = "be";
                    }
                    break :blk try fs.path.join(allocator, &[_][]const u8{ prefix, abi_list.path, le_be, basename });
                }

                break :blk try fs.path.join(allocator, &[_][]const u8{ prefix, abi_list.path, basename });
            };
            const max_bytes = 10 * 1024 * 1024;
            const contents = std.fs.cwd().readFileAlloc(allocator, abi_list_filename, max_bytes) catch |err| {
                std.debug.warn("unable to open {s}: {}\n", .{ abi_list_filename, err });
                std.process.exit(1);
            };
            var lines_it = std.mem.tokenize(u8, contents, "\n");
            while (lines_it.next()) |line| {
                var tok_it = std.mem.tokenize(u8, line, " ");
                const ver = tok_it.next().?;
                const name = tok_it.next().?;
                const category = tok_it.next().?;
                if (!std.mem.eql(u8, category, "F") and
                    !std.mem.eql(u8, category, "D"))
                {
                    continue;
                }
                if (std.mem.startsWith(u8, ver, "GCC_")) continue;
                try global_ver_set.put(ver, undefined);
                const gop = try global_fn_set.getOrPut(name);
                if (gop.found_existing) {
                    if (!std.mem.eql(u8, gop.value_ptr.lib, "c")) {
                        gop.value_ptr.lib = lib_name;
                    }
                } else {
                    gop.value_ptr.* = Function{
                        .name = name,
                        .lib = lib_name,
                        .index = undefined,
                    };
                }
                try fn_set.append(VersionedFn{
                    .ver = ver,
                    .name = name,
                });
            }
        }
    }

    const global_fn_list = blk: {
        var list = std.ArrayList([]const u8).init(allocator);
        var it = global_fn_set.keyIterator();
        while (it.next()) |key| try list.append(key.*);
        std.sort.sort([]const u8, list.items, {}, strCmpLessThan);
        break :blk list.items;
    };
    const global_ver_list = blk: {
        var list = std.ArrayList([]const u8).init(allocator);
        var it = global_ver_set.keyIterator();
        while (it.next()) |key| try list.append(key.*);
        std.sort.sort([]const u8, list.items, {}, versionLessThan);
        break :blk list.items;
    };
    {
        const vers_txt_file = try out_dir.createFile("vers.txt", .{});
        defer vers_txt_file.close();
        var buffered = std.io.bufferedWriter(vers_txt_file.writer());
        const vers_txt = buffered.writer();
        for (global_ver_list) |name, i| {
            global_ver_set.put(name, i) catch unreachable;
            try vers_txt.print("{s}\n", .{name});
        }
        try buffered.flush();
    }
    {
        const fns_txt_file = try out_dir.createFile("fns.txt", .{});
        defer fns_txt_file.close();
        var buffered = std.io.bufferedWriter(fns_txt_file.writer());
        const fns_txt = buffered.writer();
        for (global_fn_list) |name, i| {
            const value = global_fn_set.getPtr(name).?;
            value.index = i;
            try fns_txt.print("{s} {s}\n", .{ name, value.lib });
        }
        try buffered.flush();
    }

    // Now the mapping of version and function to integer index is complete.
    // Here we create a mapping of function name to list of versions.
    for (abi_lists) |*abi_list| {
        const value = target_functions.getPtr(@ptrToInt(abi_list)).?;
        const fn_vers_list = &value.fn_vers_list;
        for (value.list.items) |*ver_fn| {
            const gop = try fn_vers_list.getOrPut(ver_fn.name);
            if (!gop.found_existing) {
                gop.value_ptr.* = std.ArrayList(usize).init(allocator);
            }
            const ver_index = global_ver_set.get(ver_fn.ver).?;
            if (std.mem.indexOfScalar(usize, gop.value_ptr.items, ver_index) == null) {
                try gop.value_ptr.append(ver_index);
            }
        }
    }

    {
        const abilist_txt_file = try out_dir.createFile("abi.txt", .{});
        defer abilist_txt_file.close();
        var buffered = std.io.bufferedWriter(abilist_txt_file.writer());
        const abilist_txt = buffered.writer();

        // first iterate over the abi lists
        for (abi_lists) |*abi_list| {
            const fn_vers_list = &target_functions.getPtr(@ptrToInt(abi_list)).?.fn_vers_list;
            for (abi_list.targets) |target, it_i| {
                if (it_i != 0) try abilist_txt.writeByte(' ');
                try abilist_txt.print("{s}-linux-{s}", .{ @tagName(target.arch), @tagName(target.abi) });
            }
            try abilist_txt.writeByte('\n');
            // next, each line implicitly corresponds to a function
            for (global_fn_list) |name| {
                const value = fn_vers_list.getPtr(name) orelse {
                    try abilist_txt.writeByte('\n');
                    continue;
                };
                for (value.items) |ver_index, it_i| {
                    if (it_i != 0) try abilist_txt.writeByte(' ');
                    try abilist_txt.print("{d}", .{ver_index});
                }
                try abilist_txt.writeByte('\n');
            }
        }

        try buffered.flush();
    }
}

pub fn strCmpLessThan(context: void, a: []const u8, b: []const u8) bool {
    _ = context;
    return std.mem.order(u8, a, b) == .lt;
}

pub fn versionLessThan(context: void, a: []const u8, b: []const u8) bool {
    _ = context;
    const sep_chars = "GLIBC_.";
    var a_tokens = std.mem.tokenize(u8, a, sep_chars);
    var b_tokens = std.mem.tokenize(u8, b, sep_chars);

    while (true) {
        const a_next = a_tokens.next();
        const b_next = b_tokens.next();
        if (a_next == null and b_next == null) {
            return false; // equal means not less than
        } else if (a_next == null) {
            return true;
        } else if (b_next == null) {
            return false;
        }
        const a_int = fmt.parseInt(u64, a_next.?, 10) catch unreachable;
        const b_int = fmt.parseInt(u64, b_next.?, 10) catch unreachable;
        if (a_int < b_int) {
            return true;
        } else if (a_int > b_int) {
            return false;
        }
    }
}
