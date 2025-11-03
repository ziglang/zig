//! To get started, run this tool with no args and read the help message.
//!
//! This tool extracts the Linux syscall numbers from the Linux source tree
//! directly, and emits an enumerated list per supported Zig arch.
//!
//! As of kernel version 6.11, all supported architectures have their syscalls
//! defined in files with the following tabular format:
//!
//!   # Comment
//!   <number> <abi> <name> ...
//!
//! Everything after `name` is ignored for the purposes of this tool.

const std = @import("std");
const Io = std.Io;
const mem = std.mem;

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
});

/// Filter syscalls that aren't actually syscalls.
fn isReserved(name: []const u8) bool {
    return mem.startsWith(u8, name, "available") or
        mem.startsWith(u8, name, "reserved") or
        mem.startsWith(u8, name, "unused");
}

/// Values of the `abi` field in use by the syscall tables.
///
/// Since c. 2012, all new Linux architectures use the same numbers for their syscalls.
/// Before kernel 6.11, the source of truth for this list was the arch-specific `uapi` headers.
/// The 6.11 release converted this into a unified table with the same format as the older archs.
/// For these targets, syscalls are enabled/disabled based on the `abi` field.
/// These fields are sourced from the respective `arch/{arch}/kernel/Makefile.syscalls`
/// files in the kernel source tree.
/// Architecture-specific syscalls between [244...259] are also enabled by adding the arch name as an abi.
const Abi = enum {
    /// Syscalls common to two or more sub-targets.
    /// Often used for single targets in lieu of a nil value.
    common,
    /// Syscalls using 64-bit types on 32-bit targets.
    @"32",
    /// 64-bit native syscalls.
    @"64",
    /// 32-bit time syscalls.
    time32,
    /// Supports the older renameat syscall along with renameat2.
    renameat,
    /// Supports the fstatat64 syscall.
    stat64,
    /// Supports the {get,set}rlimit syscalls.
    rlimit,
    /// Implements `memfd_secret` and friends.
    memfd_secret,
    // Architecture-specific syscalls.
    x32,
    eabi,
    nospu,
    arc,
    csky,
    nios2,
    or1k,
    riscv,
};

const __X32_SYSCALL_BIT: u32 = 0x40000000;
const __NR_Linux_O32: u32 = 4000;
const __NR_Linux_N64: u32 = 5000;
const __NR_Linux_N32: u32 = 6000;

const Arch = struct {
    /// Name for the generated enum variable.
    @"var": []const u8,
    /// Location of the table if this arch doesn't use the generic one.
    table: union(enum) { generic: void, specific: []const u8 },
    /// List of abi features to filter on.
    /// An empty list implies the abi field is a constant value, thus skipping validation.
    abi: []const Abi = &.{},
    /// Some architectures need special handling:
    /// - x32 system calls must have their number OR'ed with
    /// `__X32_SYSCALL_BIT` to distinguish them against the regular x86_64 calls.
    /// - Mips systems calls are offset by a set number based on the ABI.
    ///
    /// Because the `__X32_SYSCALL_BIT` mask is so large, we can turn the OR into a
    /// normal addition and apply a base offset for all targets, defaulting to 0.
    offset: u32 = 0,
    header: ?[]const u8 = null,
    footer: ?[]const u8 = null,

    fn get(self: Arch, line: []const u8) ?struct { []const u8, u32 } {
        var iter = mem.tokenizeAny(u8, line, " \t");
        const num_str = iter.next() orelse @panic("Bad field");
        const abi = iter.next() orelse @panic("Bad field");
        const name = iter.next() orelse @panic("Bad field");

        // Filter out syscalls that aren't actually syscalls.
        if (isReserved(name)) return null;
        // Check abi field matches
        const abi_match: bool = if (self.abi.len == 0) true else blk: {
            for (self.abi) |a|
                if (mem.eql(u8, @tagName(a), abi)) break :blk true;
            break :blk false;
        };
        if (!abi_match) return null;

        var num = std.fmt.parseInt(u32, num_str, 10) catch @panic("Bad syscall number");
        num += self.offset;

        return .{ name, num };
    }
};

const architectures: []const Arch = &.{
    .{ .@"var" = "X86", .table = .{ .specific = "arch/x86/entry/syscalls/syscall_32.tbl" } },
    .{ .@"var" = "X64", .table = .{ .specific = "arch/x86/entry/syscalls/syscall_64.tbl" }, .abi = &.{ .common, .@"64" } },
    .{ .@"var" = "X32", .table = .{ .specific = "arch/x86/entry/syscalls/syscall_64.tbl" }, .abi = &.{ .common, .x32 }, .offset = __X32_SYSCALL_BIT },
    .{
        .@"var" = "Arm",
        .table = .{ .specific = "arch/arm/tools/syscall.tbl" },
        .abi = &.{ .common, .eabi },
        // These values haven't been brought over from `arch/arm/include/uapi/asm/unistd.h`,
        // so we are forced to add them ourselves.
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
    .{ .@"var" = "Sparc", .table = .{ .specific = "arch/sparc/kernel/syscalls/syscall.tbl" }, .abi = &.{ .common, .@"32" } },
    .{ .@"var" = "Sparc64", .table = .{ .specific = "arch/sparc/kernel/syscalls/syscall.tbl" }, .abi = &.{ .common, .@"64" } },
    .{ .@"var" = "M68k", .table = .{ .specific = "arch/m68k/kernel/syscalls/syscall.tbl" } },
    // For Mips, the abi for these tables is always o32/n64/n32.
    .{ .@"var" = "MipsO32", .table = .{ .specific = "arch/mips/kernel/syscalls/syscall_o32.tbl" }, .offset = __NR_Linux_O32 },
    .{ .@"var" = "MipsN64", .table = .{ .specific = "arch/mips/kernel/syscalls/syscall_n64.tbl" }, .offset = __NR_Linux_N64 },
    .{ .@"var" = "MipsN32", .table = .{ .specific = "arch/mips/kernel/syscalls/syscall_n32.tbl" }, .offset = __NR_Linux_N32 },
    .{ .@"var" = "PowerPC", .table = .{ .specific = "arch/powerpc/kernel/syscalls/syscall.tbl" }, .abi = &.{ .common, .@"32", .nospu } },
    .{ .@"var" = "PowerPC64", .table = .{ .specific = "arch/powerpc/kernel/syscalls/syscall.tbl" }, .abi = &.{ .common, .@"64", .nospu } },
    .{ .@"var" = "S390x", .table = .{ .specific = "arch/s390/kernel/syscalls/syscall.tbl" }, .abi = &.{ .common, .@"64" } },
    .{ .@"var" = "Xtensa", .table = .{ .specific = "arch/xtensa/kernel/syscalls/syscall.tbl" } },
    .{ .@"var" = "Arm64", .table = .generic, .abi = &.{ .common, .@"64", .renameat, .rlimit, .memfd_secret } },
    .{ .@"var" = "RiscV32", .table = .generic, .abi = &.{ .common, .@"32", .riscv, .memfd_secret } },
    .{ .@"var" = "RiscV64", .table = .generic, .abi = &.{ .common, .@"64", .riscv, .rlimit, .memfd_secret } },
    .{ .@"var" = "LoongArch64", .table = .generic, .abi = &.{ .common, .@"64" } },
    .{ .@"var" = "Arc", .table = .generic, .abi = &.{ .common, .@"32", .arc, .time32, .renameat, .stat64, .rlimit } },
    .{ .@"var" = "CSky", .table = .generic, .abi = &.{ .common, .@"32", .csky, .time32, .stat64, .rlimit } },
    .{ .@"var" = "Hexagon", .table = .generic, .abi = &.{ .common, .@"32", .time32, .stat64, .rlimit, .renameat } },
    .{ .@"var" = "OpenRisc", .table = .generic, .abi = &.{ .common, .@"32", .or1k, .time32, .stat64, .rlimit, .renameat } },
    // .{ .@"var" = "Nios2", .table = .generic, .abi = &.{ .common, .@"32", .nios2, .time32, .stat64, .rlimit, .renameat } },
    // .{ .@"var" = "Parisc", .table = .{ .specific = "arch/parisc/kernel/syscalls/syscall.tbl" }, .abi = &.{ .common, .@"32" } },
    // .{ .@"var" = "Parisc64", .table = .{ .specific = "arch/parisc/kernel/syscalls/syscall.tbl" }, .abi = &.{ .common, .@"64" } },
    // .{ .@"var" = "Sh", .table = .{ .specific = "arch/sh/kernel/syscalls/syscall.tbl" } },
    // .{ .@"var" = "Microblaze", .table = .{ .specific = "arch/microblaze/kernel/syscalls/syscall.tbl" } },
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const gpa = arena.allocator();

    const args = try std.process.argsAlloc(gpa);
    if (args.len < 2 or mem.eql(u8, args[1], "--help")) {
        const w, _ = std.debug.lockStderrWriter(&.{});
        defer std.debug.unlockStderrWriter();
        usage(w, args[0]) catch std.process.exit(2);
        std.process.exit(1);
    }
    const linux_path = args[1];

    var stdout_buffer: [2048]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writerStreaming(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    var linux_dir = try std.fs.cwd().openDir(linux_path, .{});
    defer linux_dir.close();

    // As of 6.11, the largest table is 24195 bytes.
    // 32k should be enough for now.
    const buf = try gpa.alloc(u8, 1 << 15);
    defer gpa.free(buf);

    // Fetch the kernel version from the Makefile variables.
    const version = blk: {
        const head = try linux_dir.readFile("Makefile", buf[0..128]);
        var lines = mem.tokenizeScalar(u8, head, '\n');
        _ = lines.next(); // Skip SPDX identifier

        var ver = mem.zeroes(std.SemanticVersion);
        inline for (.{ "major", "minor", "patch" }, .{ "VERSION", "PATCHLEVEL", "SUBLEVEL" }) |field, make_var| {
            const line = lines.next() orelse @panic("Bad line");
            const offset = (make_var ++ " = ").len;
            @field(ver, field) = try std.fmt.parseInt(usize, line[offset..], 10);
        }

        break :blk ver;
    };

    try Io.Writer.print(stdout,
        \\// This file is automatically generated, DO NOT edit it manually.
        \\// See tools/generate_linux_syscalls.zig for more info.
        \\// This list current as of kernel: {f}
        \\
        \\
    , .{version});

    for (architectures, 0..) |arch, i| {
        const table = try linux_dir.readFile(switch (arch.table) {
            .generic => "scripts/syscall.tbl",
            .specific => |f| f,
        }, buf);

        try Io.Writer.print(stdout, "pub const {s} = enum(usize) {{\n", .{arch.@"var"});
        if (arch.header) |h|
            try Io.Writer.writeAll(stdout, h);

        var lines = mem.tokenizeScalar(u8, table, '\n');
        while (lines.next()) |line| {
            if (line[0] == '#') continue;
            if (arch.get(line)) |res| {
                const name, const num = res;
                const final_name = stdlib_renames.get(name) orelse name;
                try Io.Writer.print(stdout, "    {f} = {d},\n", .{ std.zig.fmtId(final_name), num });
            }
        }

        if (arch.footer) |f|
            try Io.Writer.writeAll(stdout, f);
        try Io.Writer.writeAll(stdout, "};\n");
        if (i != architectures.len - 1)
            try Io.Writer.writeByte(stdout, '\n');
    }

    try Io.Writer.flush(stdout);
}

fn usage(w: *std.Io.Writer, arg0: []const u8) std.Io.Writer.Error!void {
    try w.print(
        \\Usage: {s} /path/to/zig /path/to/linux
        \\Alternative Usage: zig run /path/to/git/zig/tools/generate_linux_syscalls.zig -- /path/to/zig /path/to/linux
        \\
        \\Generates the list of Linux syscalls for each supported cpu arch, using the Linux development tree.
        \\Prints to stdout Zig code which you can use to replace the file lib/std/os/linux/syscalls.zig.
        \\
    , .{arg0});
}
