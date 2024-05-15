//! To get started, run this tool with no args and read the help message.
//!
//! The build systems of musl-libc and glibc require specifying a single target
//! architecture. Meanwhile, Zig supports out-of-the-box cross compilation for
//! every target. So the process to create libc headers that Zig ships is to use
//! this tool.
//! First, use the musl/glibc build systems to create installations of all the
//! targets in the `glibc_targets`/`musl_targets` variables.
//! Next, run this tool to create a new directory which puts .h files into
//! <arch> subdirectories, with `generic` being files that apply to all architectures.
//! You'll then have to manually update Zig source repo with these new files.

const std = @import("std");
const Arch = std.Target.Cpu.Arch;
const Abi = std.Target.Abi;
const OsTag = std.Target.Os.Tag;
const assert = std.debug.assert;
const Blake3 = std.crypto.hash.Blake3;

const LibCTarget = struct {
    name: []const u8,
    arch: MultiArch,
    abi: MultiAbi,
};

const MultiArch = union(enum) {
    aarch64,
    arm,
    mips,
    mips64,
    powerpc64,
    specific: Arch,

    fn eql(a: MultiArch, b: MultiArch) bool {
        if (@intFromEnum(a) != @intFromEnum(b))
            return false;
        if (a != .specific)
            return true;
        return a.specific == b.specific;
    }
};

const MultiAbi = union(enum) {
    musl,
    specific: Abi,

    fn eql(a: MultiAbi, b: MultiAbi) bool {
        if (@intFromEnum(a) != @intFromEnum(b))
            return false;
        if (std.meta.Tag(MultiAbi)(a) != .specific)
            return true;
        return a.specific == b.specific;
    }
};

const glibc_targets = [_]LibCTarget{
    LibCTarget{
        .name = "aarch64_be-linux-gnu",
        .arch = MultiArch{ .specific = Arch.aarch64_be },
        .abi = MultiAbi{ .specific = Abi.gnu },
    },
    LibCTarget{
        .name = "aarch64-linux-gnu",
        .arch = MultiArch{ .specific = Arch.aarch64 },
        .abi = MultiAbi{ .specific = Abi.gnu },
    },
    LibCTarget{
        .name = "armeb-linux-gnueabi",
        .arch = MultiArch{ .specific = Arch.armeb },
        .abi = MultiAbi{ .specific = Abi.gnueabi },
    },
    LibCTarget{
        .name = "armeb-linux-gnueabihf",
        .arch = MultiArch{ .specific = Arch.armeb },
        .abi = MultiAbi{ .specific = Abi.gnueabihf },
    },
    LibCTarget{
        .name = "arm-linux-gnueabi",
        .arch = MultiArch{ .specific = Arch.arm },
        .abi = MultiAbi{ .specific = Abi.gnueabi },
    },
    LibCTarget{
        .name = "arm-linux-gnueabihf",
        .arch = MultiArch{ .specific = Arch.arm },
        .abi = MultiAbi{ .specific = Abi.gnueabihf },
    },
    LibCTarget{
        .name = "csky-linux-gnuabiv2",
        .arch = MultiArch{ .specific = Arch.csky },
        .abi = MultiAbi{ .specific = Abi.gnueabihf },
    },
    LibCTarget{
        .name = "csky-linux-gnuabiv2-soft",
        .arch = MultiArch{ .specific = Arch.csky },
        .abi = MultiAbi{ .specific = Abi.gnueabi },
    },
    LibCTarget{
        .name = "i686-linux-gnu",
        .arch = MultiArch{ .specific = Arch.x86 },
        .abi = MultiAbi{ .specific = Abi.gnu },
    },
    LibCTarget{
        .name = "mips64el-linux-gnu-n32",
        .arch = MultiArch{ .specific = Arch.mips64el },
        .abi = MultiAbi{ .specific = Abi.gnuabin32 },
    },
    LibCTarget{
        .name = "mips64el-linux-gnu-n64",
        .arch = MultiArch{ .specific = Arch.mips64el },
        .abi = MultiAbi{ .specific = Abi.gnuabi64 },
    },
    LibCTarget{
        .name = "mips64-linux-gnu-n32",
        .arch = MultiArch{ .specific = Arch.mips64 },
        .abi = MultiAbi{ .specific = Abi.gnuabin32 },
    },
    LibCTarget{
        .name = "mips64-linux-gnu-n64",
        .arch = MultiArch{ .specific = Arch.mips64 },
        .abi = MultiAbi{ .specific = Abi.gnuabi64 },
    },
    LibCTarget{
        .name = "mipsel-linux-gnu",
        .arch = MultiArch{ .specific = Arch.mipsel },
        .abi = MultiAbi{ .specific = Abi.gnueabihf },
    },
    LibCTarget{
        .name = "mipsel-linux-gnu-soft",
        .arch = MultiArch{ .specific = Arch.mipsel },
        .abi = MultiAbi{ .specific = Abi.gnueabi },
    },
    LibCTarget{
        .name = "mips-linux-gnu",
        .arch = MultiArch{ .specific = Arch.mips },
        .abi = MultiAbi{ .specific = Abi.gnueabihf },
    },
    LibCTarget{
        .name = "mips-linux-gnu-soft",
        .arch = MultiArch{ .specific = Arch.mips },
        .abi = MultiAbi{ .specific = Abi.gnueabi },
    },
    LibCTarget{
        .name = "powerpc64le-linux-gnu",
        .arch = MultiArch{ .specific = Arch.powerpc64le },
        .abi = MultiAbi{ .specific = Abi.gnu },
    },
    LibCTarget{
        .name = "powerpc64-linux-gnu",
        .arch = MultiArch{ .specific = Arch.powerpc64 },
        .abi = MultiAbi{ .specific = Abi.gnu },
    },
    LibCTarget{
        .name = "powerpc-linux-gnu",
        .arch = MultiArch{ .specific = Arch.powerpc },
        .abi = MultiAbi{ .specific = Abi.gnueabihf },
    },
    LibCTarget{
        .name = "powerpc-linux-gnu-soft",
        .arch = MultiArch{ .specific = Arch.powerpc },
        .abi = MultiAbi{ .specific = Abi.gnueabi },
    },
    LibCTarget{
        .name = "riscv64-linux-gnu-rv64imac-lp64",
        .arch = MultiArch{ .specific = Arch.riscv64 },
        .abi = MultiAbi{ .specific = Abi.gnu },
    },
    LibCTarget{
        .name = "s390x-linux-gnu",
        .arch = MultiArch{ .specific = Arch.s390x },
        .abi = MultiAbi{ .specific = Abi.gnu },
    },
    // It's unclear which zig target this glibc sparcv9 target maps to.
    //LibCTarget{
    //    .name = "sparcv9-linux-gnu",
    //    .arch = MultiArch{ .specific = Arch.sparc },
    //    .abi = MultiAbi{ .specific = Abi.gnu },
    //},
    LibCTarget{
        .name = "sparc64-linux-gnu",
        .arch = MultiArch{ .specific = Arch.sparc64 },
        .abi = MultiAbi{ .specific = Abi.gnu },
    },
    LibCTarget{
        .name = "x86_64-linux-gnu",
        .arch = MultiArch{ .specific = Arch.x86_64 },
        .abi = MultiAbi{ .specific = Abi.gnu },
    },
    LibCTarget{
        .name = "x86_64-linux-gnu-x32",
        .arch = MultiArch{ .specific = Arch.x86_64 },
        .abi = MultiAbi{ .specific = Abi.gnux32 },
    },
    LibCTarget{
        .name = "m68k-linux-gnu",
        .arch = MultiArch{ .specific = Arch.m68k },
        .abi = MultiAbi{ .specific = Abi.gnu },
    },
};

const musl_targets = [_]LibCTarget{
    LibCTarget{
        .name = "aarch64",
        .arch = MultiArch.aarch64,
        .abi = MultiAbi.musl,
    },
    LibCTarget{
        .name = "arm",
        .arch = MultiArch.arm,
        .abi = MultiAbi.musl,
    },
    LibCTarget{
        .name = "i386",
        .arch = MultiArch{ .specific = .x86 },
        .abi = MultiAbi.musl,
    },
    LibCTarget{
        .name = "mips",
        .arch = MultiArch.mips,
        .abi = MultiAbi.musl,
    },
    LibCTarget{
        .name = "mips64",
        .arch = MultiArch.mips64,
        .abi = MultiAbi.musl,
    },
    LibCTarget{
        .name = "powerpc",
        .arch = MultiArch{ .specific = .powerpc },
        .abi = MultiAbi.musl,
    },
    LibCTarget{
        .name = "powerpc64",
        .arch = MultiArch.powerpc64,
        .abi = MultiAbi.musl,
    },
    LibCTarget{
        .name = "riscv64",
        .arch = MultiArch{ .specific = .riscv64 },
        .abi = MultiAbi.musl,
    },
    LibCTarget{
        .name = "s390x",
        .arch = MultiArch{ .specific = .s390x },
        .abi = MultiAbi.musl,
    },
    LibCTarget{
        .name = "x86_64",
        .arch = MultiArch{ .specific = .x86_64 },
        .abi = MultiAbi.musl,
    },
    LibCTarget{
        .name = "m68k",
        .arch = MultiArch{ .specific = .m68k },
        .abi = MultiAbi{ .specific = .musl },
    },
};

const DestTarget = struct {
    arch: MultiArch,
    os: OsTag,
    abi: Abi,

    const HashContext = struct {
        pub fn hash(self: @This(), a: DestTarget) u32 {
            _ = self;
            return @intFromEnum(a.arch) +%
                (@intFromEnum(a.os) *% @as(u32, 4202347608)) +%
                (@intFromEnum(a.abi) *% @as(u32, 4082223418));
        }

        pub fn eql(self: @This(), a: DestTarget, b: DestTarget, b_index: usize) bool {
            _ = self;
            _ = b_index;
            return a.arch.eql(b.arch) and
                a.os == b.os and
                a.abi == b.abi;
        }
    };
};

const Contents = struct {
    bytes: []const u8,
    hit_count: usize,
    hash: []const u8,
    is_generic: bool,

    fn hitCountLessThan(context: void, lhs: *const Contents, rhs: *const Contents) bool {
        _ = context;
        return lhs.hit_count < rhs.hit_count;
    }
};

const HashToContents = std.StringHashMap(Contents);
const TargetToHash = std.ArrayHashMap(DestTarget, []const u8, DestTarget.HashContext, true);
const PathTable = std.StringHashMap(*TargetToHash);

const LibCVendor = enum {
    musl,
    glibc,
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    const args = try std.process.argsAlloc(allocator);
    var search_paths = std.ArrayList([]const u8).init(allocator);
    var opt_out_dir: ?[]const u8 = null;
    var opt_abi: ?[]const u8 = null;

    var arg_i: usize = 1;
    while (arg_i < args.len) : (arg_i += 1) {
        if (std.mem.eql(u8, args[arg_i], "--help"))
            usageAndExit(args[0]);
        if (arg_i + 1 >= args.len) {
            std.debug.print("expected argument after '{s}'\n", .{args[arg_i]});
            usageAndExit(args[0]);
        }

        if (std.mem.eql(u8, args[arg_i], "--search-path")) {
            try search_paths.append(args[arg_i + 1]);
        } else if (std.mem.eql(u8, args[arg_i], "--out")) {
            assert(opt_out_dir == null);
            opt_out_dir = args[arg_i + 1];
        } else if (std.mem.eql(u8, args[arg_i], "--abi")) {
            assert(opt_abi == null);
            opt_abi = args[arg_i + 1];
        } else {
            std.debug.print("unrecognized argument: {s}\n", .{args[arg_i]});
            usageAndExit(args[0]);
        }

        arg_i += 1;
    }

    const out_dir = opt_out_dir orelse usageAndExit(args[0]);
    const abi_name = opt_abi orelse usageAndExit(args[0]);
    const vendor = if (std.mem.eql(u8, abi_name, "musl"))
        LibCVendor.musl
    else if (std.mem.eql(u8, abi_name, "glibc"))
        LibCVendor.glibc
    else {
        std.debug.print("unrecognized C ABI: {s}\n", .{abi_name});
        usageAndExit(args[0]);
    };
    const generic_name = try std.fmt.allocPrint(allocator, "generic-{s}", .{abi_name});

    // TODO compiler crashed when I wrote this the canonical way
    var libc_targets: []const LibCTarget = undefined;
    switch (vendor) {
        .musl => libc_targets = &musl_targets,
        .glibc => libc_targets = &glibc_targets,
    }

    var path_table = PathTable.init(allocator);
    var hash_to_contents = HashToContents.init(allocator);
    var max_bytes_saved: usize = 0;
    var total_bytes: usize = 0;

    var hasher = Blake3.init(.{});

    for (libc_targets) |libc_target| {
        const dest_target = DestTarget{
            .arch = libc_target.arch,
            .abi = switch (vendor) {
                .musl => .musl,
                .glibc => libc_target.abi.specific,
            },
            .os = .linux,
        };
        search: for (search_paths.items) |search_path| {
            var sub_path: []const []const u8 = undefined;
            switch (vendor) {
                .musl => {
                    sub_path = &[_][]const u8{ search_path, libc_target.name, "usr", "local", "musl", "include" };
                },
                .glibc => {
                    sub_path = &[_][]const u8{ search_path, libc_target.name, "usr", "include" };
                },
            }
            const target_include_dir = try std.fs.path.join(allocator, sub_path);
            var dir_stack = std.ArrayList([]const u8).init(allocator);
            try dir_stack.append(target_include_dir);

            while (dir_stack.popOrNull()) |full_dir_name| {
                var dir = std.fs.cwd().openDir(full_dir_name, .{ .iterate = true }) catch |err| switch (err) {
                    error.FileNotFound => continue :search,
                    error.AccessDenied => continue :search,
                    else => return err,
                };
                defer dir.close();

                var dir_it = dir.iterate();

                while (try dir_it.next()) |entry| {
                    const full_path = try std.fs.path.join(allocator, &[_][]const u8{ full_dir_name, entry.name });
                    switch (entry.kind) {
                        .directory => try dir_stack.append(full_path),
                        .file => {
                            const rel_path = try std.fs.path.relative(allocator, target_include_dir, full_path);
                            const max_size = 2 * 1024 * 1024 * 1024;
                            const raw_bytes = try std.fs.cwd().readFileAlloc(allocator, full_path, max_size);
                            const trimmed = std.mem.trim(u8, raw_bytes, " \r\n\t");
                            total_bytes += raw_bytes.len;
                            const hash = try allocator.alloc(u8, 32);
                            hasher = Blake3.init(.{});
                            hasher.update(rel_path);
                            hasher.update(trimmed);
                            hasher.final(hash);
                            const gop = try hash_to_contents.getOrPut(hash);
                            if (gop.found_existing) {
                                max_bytes_saved += raw_bytes.len;
                                gop.value_ptr.hit_count += 1;
                                std.debug.print("duplicate: {s} {s} ({:2})\n", .{
                                    libc_target.name,
                                    rel_path,
                                    std.fmt.fmtIntSizeDec(raw_bytes.len),
                                });
                            } else {
                                gop.value_ptr.* = Contents{
                                    .bytes = trimmed,
                                    .hit_count = 1,
                                    .hash = hash,
                                    .is_generic = false,
                                };
                            }
                            const path_gop = try path_table.getOrPut(rel_path);
                            const target_to_hash = if (path_gop.found_existing) path_gop.value_ptr.* else blk: {
                                const ptr = try allocator.create(TargetToHash);
                                ptr.* = TargetToHash.init(allocator);
                                path_gop.value_ptr.* = ptr;
                                break :blk ptr;
                            };
                            try target_to_hash.putNoClobber(dest_target, hash);
                        },
                        else => std.debug.print("warning: weird file: {s}\n", .{full_path}),
                    }
                }
            }
            break;
        } else {
            std.debug.print("warning: libc target not found: {s}\n", .{libc_target.name});
        }
    }
    std.debug.print("summary: {:2} could be reduced to {:2}\n", .{
        std.fmt.fmtIntSizeDec(total_bytes),
        std.fmt.fmtIntSizeDec(total_bytes - max_bytes_saved),
    });
    try std.fs.cwd().makePath(out_dir);

    var missed_opportunity_bytes: usize = 0;
    // iterate path_table. for each path, put all the hashes into a list. sort by hit_count.
    // the hash with the highest hit_count gets to be the "generic" one. everybody else
    // gets their header in a separate arch directory.
    var path_it = path_table.iterator();
    while (path_it.next()) |path_kv| {
        var contents_list = std.ArrayList(*Contents).init(allocator);
        {
            var hash_it = path_kv.value_ptr.*.iterator();
            while (hash_it.next()) |hash_kv| {
                const contents = hash_to_contents.getPtr(hash_kv.value_ptr.*).?;
                try contents_list.append(contents);
            }
        }
        std.mem.sort(*Contents, contents_list.items, {}, Contents.hitCountLessThan);
        const best_contents = contents_list.popOrNull().?;
        if (best_contents.hit_count > 1) {
            // worth it to make it generic
            const full_path = try std.fs.path.join(allocator, &[_][]const u8{ out_dir, generic_name, path_kv.key_ptr.* });
            try std.fs.cwd().makePath(std.fs.path.dirname(full_path).?);
            try std.fs.cwd().writeFile(.{ .sub_path = full_path, .data = best_contents.bytes });
            best_contents.is_generic = true;
            while (contents_list.popOrNull()) |contender| {
                if (contender.hit_count > 1) {
                    const this_missed_bytes = contender.hit_count * contender.bytes.len;
                    missed_opportunity_bytes += this_missed_bytes;
                    std.debug.print("Missed opportunity ({:2}): {s}\n", .{
                        std.fmt.fmtIntSizeDec(this_missed_bytes),
                        path_kv.key_ptr.*,
                    });
                } else break;
            }
        }
        var hash_it = path_kv.value_ptr.*.iterator();
        while (hash_it.next()) |hash_kv| {
            const contents = hash_to_contents.get(hash_kv.value_ptr.*).?;
            if (contents.is_generic) continue;

            const dest_target = hash_kv.key_ptr.*;
            const arch_name = switch (dest_target.arch) {
                .specific => |a| @tagName(a),
                else => @tagName(dest_target.arch),
            };
            const out_subpath = try std.fmt.allocPrint(allocator, "{s}-{s}-{s}", .{
                arch_name,
                @tagName(dest_target.os),
                @tagName(dest_target.abi),
            });
            const full_path = try std.fs.path.join(allocator, &[_][]const u8{ out_dir, out_subpath, path_kv.key_ptr.* });
            try std.fs.cwd().makePath(std.fs.path.dirname(full_path).?);
            try std.fs.cwd().writeFile(.{ .sub_path = full_path, .data = contents.bytes });
        }
    }
}

fn usageAndExit(arg0: []const u8) noreturn {
    std.debug.print("Usage: {s} [--search-path <dir>] --out <dir> --abi <name>\n", .{arg0});
    std.debug.print("--search-path can be used any number of times.\n", .{});
    std.debug.print("    subdirectories of search paths look like, e.g. x86_64-linux-gnu\n", .{});
    std.debug.print("--out is a dir that will be created, and populated with the results\n", .{});
    std.debug.print("--abi is either musl or glibc\n", .{});
    std.process.exit(1);
}
