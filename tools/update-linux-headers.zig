//! To get started, run this tool with no args and read the help message.
//!
//! The build system of Linux requires specifying a single target
//! architecture. Meanwhile, Zig supports out-of-the-box cross compilation for
//! every target. So the process to create libc headers that Zig ships is to use
//! this tool.
//!
//! First, use the Linux build systems to create installations of all the
//! targets in the `linux_targets` variable.
//!
//! Next, run this tool to create a new directory which puts .h files into
//! <arch> subdirectories, with `any-linux-any` being files that apply to
//! all architectures.
//!
//! You'll then have to manually update Zig source repo with these new files.

const std = @import("std");
const Arch = std.Target.Cpu.Arch;
const Abi = std.Target.Abi;
const assert = std.debug.assert;
const Blake3 = std.crypto.hash.Blake3;

const LibCTarget = struct {
    name: []const u8,
    arch: MultiArch,
};

const MultiArch = union(enum) {
    arm,
    arm64,
    loongarch,
    mips,
    powerpc,
    riscv,
    sparc,
    x86,
    specific: Arch,

    fn eql(a: MultiArch, b: MultiArch) bool {
        if (@intFromEnum(a) != @intFromEnum(b))
            return false;
        if (a != .specific)
            return true;
        return a.specific == b.specific;
    }
};

const linux_targets = [_]LibCTarget{
    LibCTarget{
        .name = "arc",
        .arch = MultiArch{ .specific = Arch.arc },
    },
    LibCTarget{
        .name = "arm",
        .arch = .arm,
    },
    LibCTarget{
        .name = "arm64",
        .arch = .{ .specific = .aarch64 },
    },
    LibCTarget{
        .name = "csky",
        .arch = .{ .specific = .csky },
    },
    LibCTarget{
        .name = "hexagon",
        .arch = .{ .specific = .hexagon },
    },
    LibCTarget{
        .name = "m68k",
        .arch = .{ .specific = .m68k },
    },
    LibCTarget{
        .name = "loongarch",
        .arch = .loongarch,
    },
    LibCTarget{
        .name = "mips",
        .arch = .mips,
    },
    LibCTarget{
        .name = "powerpc",
        .arch = .powerpc,
    },
    LibCTarget{
        .name = "riscv",
        .arch = .riscv,
    },
    LibCTarget{
        .name = "s390",
        .arch = .{ .specific = .s390x },
    },
    LibCTarget{
        .name = "sparc",
        .arch = .{ .specific = .sparc },
    },
    LibCTarget{
        .name = "x86",
        .arch = .x86,
    },
    LibCTarget{
        .name = "xtensa",
        .arch = .{ .specific = .xtensa },
    },
};

const DestTarget = struct {
    arch: MultiArch,

    const HashContext = struct {
        pub fn hash(self: @This(), a: DestTarget) u32 {
            _ = self;
            var hasher = std.hash.Wyhash.init(0);
            std.hash.autoHash(&hasher, a.arch);
            return @as(u32, @truncate(hasher.final()));
        }

        pub fn eql(self: @This(), a: DestTarget, b: DestTarget, b_index: usize) bool {
            _ = self;
            _ = b_index;
            return a.arch.eql(b.arch);
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

pub fn main() !void {
    var arena_state = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const arena = arena_state.allocator();
    const args = try std.process.argsAlloc(arena);
    var search_paths = std.ArrayList([]const u8).init(arena);
    var opt_out_dir: ?[]const u8 = null;

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
        } else {
            std.debug.print("unrecognized argument: {s}\n", .{args[arg_i]});
            usageAndExit(args[0]);
        }

        arg_i += 1;
    }

    const out_dir = opt_out_dir orelse usageAndExit(args[0]);
    const generic_name = "any-linux-any";

    var path_table = PathTable.init(arena);
    var hash_to_contents = HashToContents.init(arena);
    var max_bytes_saved: usize = 0;
    var total_bytes: usize = 0;

    var hasher = Blake3.init(.{});

    for (linux_targets) |linux_target| {
        const dest_target = DestTarget{
            .arch = linux_target.arch,
        };
        search: for (search_paths.items) |search_path| {
            const target_include_dir = try std.fs.path.join(arena, &.{
                search_path, linux_target.name, "include",
            });
            var dir_stack = std.ArrayList([]const u8).init(arena);
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
                    const full_path = try std.fs.path.join(arena, &[_][]const u8{ full_dir_name, entry.name });
                    switch (entry.kind) {
                        .directory => try dir_stack.append(full_path),
                        .file => {
                            const rel_path = try std.fs.path.relative(arena, target_include_dir, full_path);
                            const max_size = 2 * 1024 * 1024 * 1024;
                            const raw_bytes = try std.fs.cwd().readFileAlloc(arena, full_path, max_size);
                            const trimmed = std.mem.trim(u8, raw_bytes, " \r\n\t");
                            total_bytes += raw_bytes.len;
                            const hash = try arena.alloc(u8, 32);
                            hasher = Blake3.init(.{});
                            hasher.update(rel_path);
                            hasher.update(trimmed);
                            hasher.final(hash);
                            const gop = try hash_to_contents.getOrPut(hash);
                            if (gop.found_existing) {
                                max_bytes_saved += raw_bytes.len;
                                gop.value_ptr.hit_count += 1;
                                std.debug.print("duplicate: {s} {s} ({:2})\n", .{
                                    linux_target.name,
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
                                const ptr = try arena.create(TargetToHash);
                                ptr.* = TargetToHash.init(arena);
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
            std.debug.print("warning: libc target not found: {s}\n", .{linux_target.name});
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
        var contents_list = std.ArrayList(*Contents).init(arena);
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
            const full_path = try std.fs.path.join(arena, &[_][]const u8{ out_dir, generic_name, path_kv.key_ptr.* });
            try std.fs.cwd().makePath(std.fs.path.dirname(full_path).?);
            try std.fs.cwd().writeFile(full_path, best_contents.bytes);
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
            const out_subpath = try std.fmt.allocPrint(arena, "{s}-linux-any", .{arch_name});
            const full_path = try std.fs.path.join(arena, &[_][]const u8{ out_dir, out_subpath, path_kv.key_ptr.* });
            try std.fs.cwd().makePath(std.fs.path.dirname(full_path).?);
            try std.fs.cwd().writeFile(full_path, contents.bytes);
        }
    }

    const bad_files = [_][]const u8{
        "any-linux-any/linux/netfilter/xt_CONNMARK.h",
        "any-linux-any/linux/netfilter/xt_DSCP.h",
        "any-linux-any/linux/netfilter/xt_MARK.h",
        "any-linux-any/linux/netfilter/xt_RATEEST.h",
        "any-linux-any/linux/netfilter/xt_TCPMSS.h",
        "any-linux-any/linux/netfilter_ipv4/ipt_ECN.h",
        "any-linux-any/linux/netfilter_ipv4/ipt_TTL.h",
        "any-linux-any/linux/netfilter_ipv6/ip6t_HL.h",
    };
    for (bad_files) |bad_file| {
        const full_path = try std.fs.path.join(arena, &[_][]const u8{ out_dir, bad_file });
        try std.fs.cwd().deleteFile(full_path);
    }
}

fn usageAndExit(arg0: []const u8) noreturn {
    std.debug.print("Usage: {s} [--search-path <dir>] --out <dir> --abi <name>\n", .{arg0});
    std.debug.print("--search-path can be used any number of times.\n", .{});
    std.debug.print("    subdirectories of search paths look like, e.g. x86_64-linux-gnu\n", .{});
    std.debug.print("--out is a dir that will be created, and populated with the results\n", .{});
    std.process.exit(1);
}
