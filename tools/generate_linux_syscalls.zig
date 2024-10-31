//! To get started, run this tool with no args and read the help message.
//!
//! This tool extracts syscall numbers from the Linux source tree
//! and emits an enumerated list per arch.

const std = @import("std");
const mem = std.mem;
const fmt = std.fmt;
const zig = std.zig;
const fs = std.fs;

const stdlib_renames = std.StaticStringMap([]const u8).initComptime(.{
    // Remove underscore prefix.
    .{ "_llseek", "llseek" },
    .{ "_newselect", "newselect" },
    .{ "_sysctl", "sysctl" },
    // Most 64-bit archs.
    .{ "newfstat", "fstat64" },
    .{ "newfstatat", "fstatat64" },
    // POWER.
    .{ "sync_file_range2", "sync_file_range" },
    // ARM EABI/Thumb.
    .{ "arm_sync_file_range", "sync_file_range" },
    .{ "arm_fadvise64_64", "fadvise64_64" },
    // ARC and Hexagon.
    .{ "mmap_pgoff", "mmap2" },
});

/// Filter syscalls that aren't actually syscalls.
fn isReserved(name: []const u8) bool {
    return std.mem.startsWith(u8, name, "available") or
        std.mem.startsWith(u8, name, "reserved") or
        std.mem.startsWith(u8, name, "unused");
}

fn abiGen(comptime fields: []const []const u8) fn ([]const u8) bool {
    const common = [_][]const u8{"common"} ++ fields;
    return struct {
        fn gen(abi: []const u8) bool {
            for (common) |f|
                if (mem.eql(u8, abi, f)) return true;
            return false;
        }
    }.gen;
}

/// Used when the abi column is the same value.
fn everythingAbi(_: []const u8) bool {
    return true;
}
/// "common" or "32"
const abi32 = abiGen(&.{"32"});
/// "common" or "64"
const abi64 = abiGen(&.{"64"});
/// "common" or "eabi"
const abiArm = abiGen(&.{"eabi"});
/// "common", "32" or "nospu"
const abiPpc32 = abiGen(&.{ "32", "nospu" });
/// "common", "64" or "nospu"
const abiPpc64 = abiGen(&.{ "64", "nospu" });

/// These architectures have custom syscall numbers defined in arch-specific tables.
const specific = [_]struct {
    var_name: []const u8,
    table: []const u8,
    abi: *const fn (abi: []const u8) bool,
    header: ?[]const u8 = null,
    footer: ?[]const u8 = null,
}{
    .{ .var_name = "X86", .table = "arch/x86/entry/syscalls/syscall_32.tbl", .abi = everythingAbi },
    .{ .var_name = "X64", .table = "arch/x86/entry/syscalls/syscall_64.tbl", .abi = abi64 },
    .{
        .var_name = "Arm",
        .table = "arch/arm/tools/syscall.tbl",
        .abi = abiArm,
        // TODO: These values haven't been brought over from `arch/arm/include/uapi/asm/unistd.h`.
        .header = "    const arm_base = 0x0f0000;\n\n",
        .footer =
        \\
        \\    breakpoint = arm_base + 1,
        \\    cacheflush = arm_base + 2,
        \\    usr26 = arm_base + 3,
        \\    usr32 = arm_base + 4,
        \\    set_tls = arm_base + 5,
        \\    get_tls = arm_base + 6,
        \\
        ,
    },
    .{ .var_name = "Sparc", .table = "arch/sparc/kernel/syscalls/syscall.tbl", .abi = abi32 },
    .{ .var_name = "Sparc64", .table = "arch/sparc/kernel/syscalls/syscall.tbl", .abi = abi64 },
    .{ .var_name = "M68k", .table = "arch/m68k/kernel/syscalls/syscall.tbl", .abi = everythingAbi },
    .{ .var_name = "PowerPC", .table = "arch/powerpc/kernel/syscalls/syscall.tbl", .abi = abiPpc32 },
    .{ .var_name = "PowerPC64", .table = "arch/powerpc/kernel/syscalls/syscall.tbl", .abi = abiPpc64 },
    .{ .var_name = "S390x", .table = "arch/s390/kernel/syscalls/syscall.tbl", .abi = abi64 },
    .{ .var_name = "Xtensa", .table = "arch/xtensa/kernel/syscalls/syscall.tbl", .abi = everythingAbi },
    // TODO: Enable these when a backend is available
    // .{ .var_name = "SuperH", .table = "arch/sh/kernel/syscalls/syscall.tbl", .abi = everythingAbi },
    // .{ .var_name = "Alpha", .table = "arch/alpha/kernel/syscalls/syscall.tbl", .abi = everythingAbi },
    // .{ .var_name = "PARisc", .table = "arch/parisc/kernel/syscalls/syscall.tbl", .abi = abi32 },
    // .{ .var_name = "PARisc64", .table = "arch/parisc/kernel/syscalls/syscall.tbl", .abi = abi64 },
};

/// The MIPS-based architectures are similar to the specific ones, except that the abi
/// is always the same and syscall numbers are offset by a number specific to the arch.
const mips = [_]struct {
    var_name: []const u8,
    table: []const u8,
    base: usize,
}{
    .{ .var_name = "MipsO32", .table = "arch/mips/kernel/syscalls/syscall_o32.tbl", .base = 4000 },
    .{ .var_name = "MipsN64", .table = "arch/mips/kernel/syscalls/syscall_n64.tbl", .base = 5000 },
    .{ .var_name = "MipsN32", .table = "arch/mips/kernel/syscalls/syscall_n32.tbl", .base = 6000 },
};

/// These architectures have their syscall numbers defined using the generic syscall
/// list introduced in c. 2012 for AArch64.
/// The 6.11 release converted this list into a single table, where parts of the
/// syscall ABI are enabled based on the presence of certain abi fields:
/// - 32: Syscalls using 64-bit types on 32-bit targets.
/// - 64: 64-bit native syscalls.
/// - time32: 32-bit time syscalls.
/// - renameat: Supports the older renameat syscall along with renameat2.
/// - rlimit: Supports the {get,set}rlimit syscalls.
/// - memfd_secret: Has an implementation of `memfd_secret`.
///
/// Arch-specfic syscalls between [244...259] are also enabled by adding the arch name as an abi.
///
/// The abi fields are sourced from the respectiev `arch/{arch}/kernel/Makefile.syscalls` files
/// in the kernel tree.
const generic = [_]struct {
    var_name: []const u8,
    abi: *const fn (abi: []const u8) bool,
}{
    .{ .var_name = "Arm64", .abi = abiGen(&.{ "64", "renameat", "rlimit", "memfd_secret" }) },
    .{ .var_name = "RiscV32", .abi = abiGen(&.{ "32", "riscv", "memfd_secret" }) },
    .{ .var_name = "RiscV64", .abi = abiGen(&.{ "64", "riscv", "rlimit", "memfd_secret" }) },
    .{ .var_name = "LoongArch64", .abi = abi64 },
    .{ .var_name = "Arc", .abi = abiGen(&.{ "32", "arc", "time32", "renameat", "stat64", "rlimit" }) },
    .{ .var_name = "CSky", .abi = abiGen(&.{ "32", "csky", "time32", "stat64", "rlimit" }) },
    .{ .var_name = "Hexagon", .abi = abiGen(&.{ "32", "hexagon", "time32", "stat64", "rlimit", "renameat" }) },
    // .{ .var_name = "OpenRisc", .abi = abiGen(&.{ "32", "or1k", "time32", "stat64", "rlimit", "renameat" }) },
    // .{ .var_name = "Nios2", .abi = abiGen(&.{ "32", "nios2", "time32", "stat64", "renameat", "rlimit" }) },
};
const generic_table = "scripts/syscall.tbl";

fn splitLine(line: []const u8) [3][]const u8 {
    var fields = mem.tokenizeAny(u8, line, " \t");
    const number = fields.next() orelse @panic("Bad field");
    const abi = fields.next() orelse @panic("Bad field");
    const name = fields.next() orelse @panic("Bad field");

    return .{ number, abi, name };
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = try std.process.argsAlloc(allocator);
    if (args.len < 2 or mem.eql(u8, args[1], "--help"))
        usageAndExit(std.io.getStdErr(), args[0], 1);
    const linux_path = args[1];

    var buf_out = std.io.bufferedWriter(std.io.getStdOut().writer());
    const writer = buf_out.writer();

    var linux_dir = try std.fs.cwd().openDir(linux_path, .{});
    defer linux_dir.close();

    // As of 6.11, the largest table is 24195 bytes.
    // 32k should be enough for now.
    const buf = try allocator.alloc(u8, 1 << 15);
    defer allocator.free(buf);

    // Fetch the kernel version from the Makefile variables.
    const version = blk: {
        const head = try linux_dir.readFile("Makefile", buf[0..128]);
        var lines = mem.tokenizeScalar(u8, head, '\n');
        _ = lines.next(); // Skip SPDX identifier

        var ver = mem.zeroes(std.SemanticVersion);
        inline for (.{ "major", "minor", "patch" }, .{ "VERSION", "PATCHLEVEL", "SUBLEVEL" }) |f, v| {
            const line = lines.next() orelse @panic("Bad line");
            const offset = (v ++ " = ").len;
            @field(ver, f) = try fmt.parseInt(usize, line[offset..], 10);
        }

        break :blk ver;
    };

    try writer.print(
        \\// This file is automatically generated, DO NOT edit it manually.
        \\// See tools/generate_linux_syscalls.zig for more info.
        \\// This list current as of kernel: {}
        \\
        \\
    , .{version});

    const trailing = "};\n\n";
    for (specific) |arch| {
        try writer.print("pub const {s} = enum(usize) {{\n", .{arch.var_name});
        if (arch.header) |h|
            try writer.writeAll(h);
        const table = try linux_dir.readFile(arch.table, buf);

        var lines = mem.tokenizeScalar(u8, table, '\n');
        while (lines.next()) |line| {
            if (line[0] == '#') continue;
            const number, const abi, const name = splitLine(line);

            if (!arch.abi(abi)) continue;
            if (isReserved(name)) continue;

            const final_name = stdlib_renames.get(name) orelse name;
            try writer.print("    {p} = {s},\n", .{ zig.fmtId(final_name), number });
        }
        if (arch.footer) |f|
            try writer.writeAll(f);
        try writer.writeAll(trailing);
    }

    for (mips) |arch| {
        try writer.print(
            \\pub const {s} = enum(usize) {{
            \\    const linux_base = {d};
            \\
            \\
        , .{ arch.var_name, arch.base });
        const table = try linux_dir.readFile(arch.table, buf);

        var lines = mem.tokenizeScalar(u8, table, '\n');
        while (lines.next()) |line| {
            if (line[0] == '#') continue;
            const number, _, const name = splitLine(line);

            if (isReserved(name)) continue;

            const final_name = stdlib_renames.get(name) orelse name;
            try writer.print("    {p} = linux_base + {s},\n", .{ zig.fmtId(final_name), number });
        }

        try writer.writeAll(trailing);
    }

    const table = try linux_dir.readFile(generic_table, buf);
    for (generic, 0..) |arch, i| {
        try writer.print("pub const {s} = enum(usize) {{\n", .{arch.var_name});

        var lines = mem.tokenizeScalar(u8, table, '\n');
        while (lines.next()) |line| {
            if (line[0] == '#') continue;
            const number, const abi, const name = splitLine(line);

            if (!arch.abi(abi)) continue;
            if (isReserved(name)) continue;

            const final_name = stdlib_renames.get(name) orelse name;
            try writer.print("    {p} = {s},\n", .{ zig.fmtId(final_name), number });
        }

        try writer.writeAll(trailing[0 .. 3 + @as(usize, @intFromBool(i < generic.len - 1))]);
    }

    try buf_out.flush();
}

fn usageAndExit(file: fs.File, arg0: []const u8, code: u8) noreturn {
    file.writer().print(
        \\Usage: {s} /path/to/zig /path/to/linux
        \\Alternative Usage: zig run /path/to/git/zig/tools/generate_linux_syscalls.zig -- /path/to/zig /path/to/linux
        \\
        \\Generates the list of Linux syscalls for each supported cpu arch, using the Linux development tree.
        \\Prints to stdout Zig code which you can use to replace the file lib/std/os/linux/syscalls.zig.
        \\
    , .{arg0}) catch std.process.exit(1);
    std.process.exit(code);
}
