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
//! 2. Run with those arguments
//!    For example:
//!    zig run process_headers_ohos.zig \
//!    --search-path /path/to/sdk/packages/ohos-sdk/darwin/native/sysroot/usr/include \
//!    --generic-musl-path /path/to/zig/zig/lib/libc/musl --out /path/to/zig/zig/lib/libc/include
//!
//! Note: For system bulit-in header file, we should ignore it. For example: arkui/native_dialog.h etc.
//!       So if there are some new built-in header files, please add them to system_built_in_ability in this file.
//!
//! Diff logic:
//!     1. generate the full musl headers map and key is relative path:
//!         i. Put musl/include
//!        ii. Put musl/arch/generic
//!       iii. Put musl/arch/$arch
//!     2. iterate the full musl headers map and check if the file exists in the search path:
//!        i. If the file exists, read the file and remove the comments and spaces and lines
//!       ii. Calculate the hash of the file content and check if the hash is the same
//!      iii. If the hash is the same, we can reduce the size
//!       iv. If the hash is different, we should save the content
//!    3. Save the content to the out dir
//!       i. If the hit count is greater than 1, save the content to the generic-ohos dir
//!      ii. If the hit count is equal to 1, save the content to the target dir

const std = @import("std");
const Arch = std.Target.Cpu.Arch;
const Abi = std.Target.Abi;
const OsTag = std.Target.Os.Tag;
const assert = std.debug.assert;
const Blake3 = std.crypto.hash.Blake3;

const LibCTarget = struct {
    name: []const u8,
    arch: Arch,
    abi: Abi,
    abi_name: []const u8,
};

fn is_in_array(value: []const u8, array: []const []const u8) bool {
    for (array) |item| {
        if (std.mem.eql(u8, value, item)) {
            return true;
        }
    }
    return false;
}

const musl_targets = [_]LibCTarget{
    LibCTarget{ .name = "aarch64", .arch = Arch.aarch64, .abi = Abi.ohos, .abi_name = "ohos" },
    // Note: for older version of zig, ohoseabi is not exist.
    LibCTarget{ .name = "arm", .arch = Arch.arm, .abi = Abi.ohoseabi, .abi_name = "ohoseabi" },
    LibCTarget{ .name = "x86_64", .arch = Arch.x86_64, .abi = Abi.ohos, .abi_name = "ohos" },
};

const Contents = struct {
    bytes: []const u8,
    hit_count: usize,
    hash: []const u8,
    is_generic: bool,
    path: []const u8,
    target: []const u8,

    fn hitCountLessThan(context: void, lhs: *const Contents, rhs: *const Contents) bool {
        _ = context;
        return lhs.hit_count < rhs.hit_count;
    }
};

const HashToContents = std.StringHashMap(Contents);

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

                    std.debug.print("generic: {s}\n", .{rel_path});

                    // use path as key and we just need to check the hash
                    const gop = try musl_hash_content.getOrPut(rel_path);

                    // for generic_musl always be new hash
                    gop.value_ptr.* = Contents{ .bytes = trimmed, .hit_count = 1, .target = "", .hash = hash, .is_generic = false, .path = rel_path };
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

fn fileExists(path: []const u8) bool {
    _ = std.fs.cwd().statFile(path) catch {
        return false;
    };
    return true;
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

    var ohos_common_content = HashToContents.init(allocator);

    for (musl_targets) |libc_target| {
        const target = try std.fmt.allocPrint(allocator, "{s}-{s}-{s}", .{
            libc_target.name,
            "linux",
            libc_target.abi_name,
        });

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
            var target_dir: []const u8 = "";

            if (std.mem.startsWith(u8, entry.key_ptr.*, "bits") or std.mem.startsWith(u8, entry.key_ptr.*, "asm")) {
                target_dir = target;
            }
            const target_file_path = try std.fs.path.join(allocator, &[_][]const u8{ search_paths.items[0], target_dir, entry.key_ptr.* });

            if (!fileExists(target_file_path)) {
                continue;
            }

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

            // if hash is the same, we can reduce the size
            if (std.mem.eql(u8, hash, entry.value_ptr.hash)) {
                max_bytes_saved += raw_bytes.len;
                std.debug.print("ohos duplicate: {s} {s} ({:2})\n", .{
                    libc_target.name,
                    entry.key_ptr.*,
                    std.fmt.fmtIntSizeDec(raw_bytes.len),
                });
            } else {
                const common = try ohos_common_content.getOrPut(hash);

                if (common.found_existing) {
                    common.value_ptr.hit_count += 1;
                } else {
                    common.value_ptr.* = Contents{ .bytes = tmp_content, .target = target, .hit_count = 1, .hash = hash, .is_generic = false, .path = entry.value_ptr.path };
                }
            }
        } else {
            std.debug.print("warning: libc target not found: {s}\n", .{libc_target.name});
        }
    }

    try std.fs.cwd().makePath(out_dir);

    var it = ohos_common_content.iterator();
    while (it.next()) |entry| {
        var full_path: []const u8 = "";
        if (entry.value_ptr.hit_count > 1) {
            full_path = try std.fs.path.join(allocator, &[_][]const u8{ out_dir, "generic-ohos", entry.value_ptr.path });
        } else {
            full_path = try std.fs.path.join(allocator, &[_][]const u8{ out_dir, entry.value_ptr.target, entry.value_ptr.path });
        }

        try std.fs.cwd().makePath(std.fs.path.dirname(full_path).?);
        const with_newline = try std.mem.concat(allocator, u8, &[_][]const u8{ entry.value_ptr.bytes, "\n" });
        defer allocator.free(with_newline);
        try std.fs.cwd().writeFile(.{ .sub_path = full_path, .data = with_newline });
    }
}

fn usageAndExit(arg0: []const u8) noreturn {
    std.debug.print("Usage: {s} --search-path <dir> --generic-musl-path <dir> --out <name>\n", .{arg0});
    std.debug.print("--search-path should be openharmony ndk include dir.\n", .{});
    std.debug.print("--generic-musl-path is current generic-musl dir.\n", .{});
    std.debug.print("--out is a dir that will be created, and populated with the results\n", .{});
    std.process.exit(1);
}
