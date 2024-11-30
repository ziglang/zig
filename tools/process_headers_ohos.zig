//! To get started, run this tool with no args and read the help message.
//!
//! The build systems of musl-libc and glibc require specifying a single target
//! architecture. Meanwhile, Zig supports out-of-the-box cross compilation for
//! every target. So the process to create libc headers that Zig ships is to use
//! this tool.
//!
//! Current Version: 5.0-beta.1
//!
//! 1. Download openharmony sdk from https://gitee.com/openharmony/docs/tree/OpenHarmony-5.0-Beta1/zh-cn/release-notes
//!    For example, if we use 5.0-beta.1, we can get download url with: https://gitee.com/openharmony/docs/blob/OpenHarmony-5.0-Beta1/zh-cn/release-notes/OpenHarmony-v5.0-beta1.md#%E6%BA%90%E7%A0%81%E8%8E%B7%E5%8F%96
//! 2. Run this file without argument
//!    zig run process_headers_ohos.zig
//! 3. Run with those arguments
//!    For example:
//!    /path/to/process_headers_ohos \
//!    --search-path /path/to/sdk/packages/ohos-sdk/darwin/native/sysroot/usr/include \
//!    --generic-musl-path /path/to/zig/zig/lib/libc/include/generic-musl --out ./
//!
//! Note: For system bulit-in header file, we should ignore it. For example: arkui/native_dialog.h etc.
//!       So if there are some new built-in header files, please add them to system_built_in_ability in this file.
//!
//! Diff logic:
//!     1. reduce with generic-musl
//!     2. reduce with <arch>-linux-any
//!     3. reduce with <arch>-linux-musl
//!     4. for x86_64 should compare with x86-linux-any x86-linux-musl x86_64-linux-musl

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
    x86_64,
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

const targets_dirs = &[_][]const u8{
    "aarch64-linux-ohos",
    "arm-linux-ohos",
    "x86_64-linux-ohos",
};

fn is_in_array(value: []const u8, array: []const []const u8) bool {
    for (array) |item| {
        if (std.mem.eql(u8, value, item)) {
            return true;
        }
    }
    return false;
}

// openharmony bulit-in header file
// should be ignored
const system_built_in_ability = &[_][]const u8{ "AbilityKit", "BasicServicesKit", "EGL", "GLES2", "GLES3", "IPCKit", "KHR", "SLES", "ace", "ark_runtime", "arkui", "asm-generic", "asm-mips", "asm-riscv", "asset", "bundle", "ffrt", "filemanagement", "fortify", "database", "ddk", "deviceinfo.h", "drm", "hiappevent", "hid", "hidebug", "hilog", "hitrace", "huks", "info", "js_native_api.h", "js_native_api_types.h", "linux", "mtd", "multimedia", "multimodalinput", "napi", "native_buffer", "native_drawing", "native_effect", "native_image", "native_vsync", "native_window", "neural_network_runtime", "ohaudio", "ohcamera", "purgeable_memory", "qos", "rawfile", "rdma", "resourcemanager", "sensors", "sound", "tee", "tee_client", "unicode", "usb", "uv", "uv.h", "version.h", "video", "vulkan", "web", "window_manager", "xen", "zconf.h", "zlib.h", "network" };

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
        .name = "x86_64",
        .arch = MultiArch.x86_64,
        .abi = MultiAbi.musl,
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

fn generateGenericFileMap(allocator: std.mem.Allocator, generic_musl_path: []const []const u8) !HashToContents {
    var musl_hash_content = HashToContents.init(allocator);
    const target_include_dir = try std.fs.path.join(allocator, generic_musl_path);

    var dir_stack = std.ArrayList([]const u8).init(allocator);
    try dir_stack.append(target_include_dir);

    while (dir_stack.popOrNull()) |full_dir_name| {
        var dir = std.fs.cwd().openDir(full_dir_name, .{ .iterate = true }) catch |err| switch (err) {
            error.FileNotFound => continue,
            error.AccessDenied => continue,
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

                    const replaced = try replaceBytes(allocator, raw_bytes, "\r\n", "\n");
                    const removed_comment = try removeComment(allocator, replaced);
                    const trimmed = try removeSpacesAndLines(allocator, removed_comment);

                    const hash = try allocator.alloc(u8, 32);
                    var inner_hasher = Blake3.init(.{});
                    inner_hasher.update(rel_path);
                    inner_hasher.update(trimmed);
                    inner_hasher.final(hash);
                    // use path as key and we just need to check the hash
                    const gop = try musl_hash_content.getOrPut(rel_path);

                    // for generic_musl always be new hash
                    gop.value_ptr.* = Contents{
                        .bytes = trimmed,
                        .hit_count = 1,
                        .hash = hash,
                        .is_generic = false,
                    };
                },
                else => std.debug.print("warning: weird file: {s}\n", .{full_path}),
            }
        }
    }
    return musl_hash_content;
}

fn replaceBytes(allocator: std.mem.Allocator, input: []const u8, from: []const u8, to: []const u8) ![]u8 {
    var builder = std.ArrayList(u8).init(allocator);
    defer builder.deinit();

    var i: usize = 0;
    while (i < input.len) {
        if (std.mem.startsWith(u8, input[i..], from)) {
            try builder.appendSlice(to);
            i += from.len;
        } else {
            try builder.append(input[i]);
            i += 1;
        }
    }

    return builder.toOwnedSlice();
}

fn removeComment(allocator: std.mem.Allocator, content: []const u8) ![]u8 {
    var builder = std.ArrayList(u8).init(allocator);

    var i: usize = 0;
    while (i < content.len) {
        if (content[i] == '/' and i + 1 < content.len and content[i + 1] == '/') {
            // single
            while (i < content.len and content[i] != '\n') {
                i += 1;
            }
        } else if (content[i] == '/' and i + 1 < content.len and content[i + 1] == '*') {
            // multi line
            i += 2;
            while (i + 1 < content.len and !(content[i] == '*' and content[i + 1] == '/')) {
                i += 1;
            }
            i += 2; // skip end of */
        } else {
            // non-comment
            _ = try builder.append(content[i]);
            i += 1;
        }
    }

    return builder.toOwnedSlice();
}

fn removeSpacesAndLines(allocator: std.mem.Allocator, content: []const u8) ![]u8 {
    var result = try allocator.alloc(u8, content.len);
    var resultIndex: usize = 0;
    var i: usize = 0;

    while (i < content.len) : (i += 1) {
        const c = content[i];
        const isFullWidthSpace = (i + 2 < content.len) and (content[i] == 0xE3) and (content[i + 1] == 0x80) and (content[i + 2] == 0x80);
        if (std.ascii.isWhitespace(c) or isFullWidthSpace) {} else {
            result[resultIndex] = c;
            resultIndex += 1;
        }
    }

    return result[0..resultIndex];
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    const args = try std.process.argsAlloc(allocator);
    var search_paths = std.ArrayList([]const u8).init(allocator);
    var opt_out_dir: ?[]const u8 = null;
    var opt_generic_musl_libc_dir: ?[]const u8 = null;

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
        } else if (std.mem.eql(u8, args[arg_i], "--generic-musl-path")) {
            assert(opt_generic_musl_libc_dir == null);
            opt_generic_musl_libc_dir = args[arg_i + 1];
        } else {
            std.debug.print("unrecognized argument: {s}\n", .{args[arg_i]});
            usageAndExit(args[0]);
        }

        arg_i += 1;
    }

    const out_dir = opt_out_dir orelse usageAndExit(args[0]);
    const generic_musl_libc_dir: []const u8 = opt_generic_musl_libc_dir orelse usageAndExit(args[0]);

    // we can't reuse generic-musl directly.
    // comment always different so hash is different.
    const generic_name = "generic-ohos";

    var path_table = PathTable.init(allocator);
    var hash_to_contents = HashToContents.init(allocator);
    var max_bytes_saved: usize = 0;
    var total_bytes: usize = 0;

    const musl_hash_to_contents = generateGenericFileMap(allocator, &[_][]const u8{ generic_musl_libc_dir, "include" }) catch |err| {
        std.debug.print("Error occurred: {}\n", .{err});
        return;
    };
    const musl_generic_hash_content = generateGenericFileMap(allocator, &[_][]const u8{ generic_musl_libc_dir, "arch", "generic" }) catch |err| {
        std.debug.print("Error occurred: {}\n", .{err});
        return;
    };

    for (musl_targets) |libc_target| {
        const dest_target = DestTarget{
            .arch = libc_target.arch,
            .abi = .ohos,
            .os = .linux,
        };

        const arch_generic_hash_content = generateGenericFileMap(allocator, &[_][]const u8{ generic_musl_libc_dir, "arch", libc_target.name }) catch |err| {
            std.debug.print("Error occurred: {}\n", .{err});
            return;
        };

        // merge hashmap by path
        // arch_generic_hash_content is the most specific and should be merged last
        var result = HashToContents.init(allocator);
        var it1 = musl_hash_to_contents.iterator();
        while (it1.next()) |entry| {
            try result.put(entry.key_ptr.*, entry.value_ptr.*);
        }

        var it2 = musl_generic_hash_content.iterator();
        while (it2.next()) |entry| {
            try result.put(entry.key_ptr.*, entry.value_ptr.*);
        }
        var it3 = arch_generic_hash_content.iterator();
        while (it3.next()) |entry| {
            try result.put(entry.key_ptr.*, entry.value_ptr.*);
        }

        var iterator = result.iterator();
        // iterate the map and make sure the hash is unique
        while (iterator.next()) |entry| {
            const target_file_path = try std.fs.path.join(allocator, &[_][]const u8{ search_paths, entry.key_ptr.* });

            const max_size = 2 * 1024 * 1024 * 1024;
            const raw_bytes = try std.fs.cwd().readFileAlloc(allocator, target_file_path, max_size);
            const replaced = try replaceBytes(allocator, raw_bytes, "\r\n", "\n");

            // save content
            const tmp_content = std.mem.trim(u8, replaced, " \r\n\t");

            const removed_content = try removeComment(allocator, replaced);
            const trimmed = try removeSpacesAndLines(allocator, removed_content);

            total_bytes += raw_bytes.len;
            const hash = try allocator.alloc(u8, 32);

            var hasher = Blake3.init(.{});
            hasher.update(entry.key_ptr.*);
            hasher.update(trimmed);
            hasher.final(hash);

            const gop = try hash_to_contents.getOrPut(entry.key_ptr.*);
            // if hash is the same, we can reduce the size
            if (.{std.mem.eql(u8, hash, entry.value_ptr.hash)}) {
                max_bytes_saved += raw_bytes.len;
                gop.value_ptr.hit_count += 1;
                std.debug.print("ohos duplicate: {s} {s} ({:2})\n", .{
                    libc_target.name,
                    entry.key_ptr.*,
                    std.fmt.fmtIntSizeDec(raw_bytes.len),
                });
            } else {
                gop.value_ptr.* = Contents{
                    .bytes = tmp_content,
                    .hit_count = 1,
                    .hash = hash,
                    .is_generic = false,
                };
            }
            const path_gop = try path_table.getOrPut(entry.key_ptr.*);
            const target_to_hash = if (path_gop.found_existing) path_gop.value_ptr.* else blk: {
                const ptr = try allocator.create(TargetToHash);
                ptr.* = TargetToHash.init(allocator);
                path_gop.value_ptr.* = ptr;
                break :blk ptr;
            };
            try target_to_hash.putNoClobber(dest_target, hash);
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
    std.debug.print("Usage: {s} --search-path <dir> --generic-musl-path <dir> --out <name>\n", .{arg0});
    std.debug.print("--search-path should be openharmony ndk include dir.\n", .{});
    std.debug.print("--generic-musl-path is current generic-musl dir.\n", .{});
    std.debug.print("--out is a dir that will be created, and populated with the results\n", .{});
    std.process.exit(1);
}
