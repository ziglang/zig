//! To get started, run this tool with no args and read the help message.
//!
//! This tool extracts the Linux syscall numbers from the Linux source tree
//! directly, and emits an enumerated list per supported Zig arch.

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

// Only for newer architectures where we use the C preprocessor.
const stdlib_renames_new = std.StaticStringMap([]const u8).initComptime(.{
    .{ "newuname", "uname" },
    .{ "umount", "umount2" },
});

// We use this to deal with the fact that multiple syscalls can be mapped to sys_ni_syscall.
// Thankfully it's only 2 well-known syscalls in newer kernel ports at the moment.
fn getOverridenNameNew(value: []const u8) ?[]const u8 {
    if (mem.eql(u8, value, "18")) {
        return "sys_lookup_dcookie";
    } else if (mem.eql(u8, value, "42")) {
        return "sys_nfsservctl";
    } else {
        return null;
    }
}

fn isReservedNameOld(name: []const u8) bool {
    return std.mem.startsWith(u8, name, "available") or
        std.mem.startsWith(u8, name, "reserved") or
        std.mem.startsWith(u8, name, "unused");
}

const default_args: []const []const u8 = &.{
    "-E",
    // -dM is cleaner, but -dD preserves iteration order.
    "-dD",
    // No need for line-markers.
    "-P",
    "-nostdinc",
    // Using -I=[dir] includes the zig linux headers, which we don't want.
    "-Itools/include",
    "-Itools/include/uapi",
    // Output the syscall in a format we can easily recognize.
    "-D __SYSCALL(nr, nm)=zigsyscall nm nr",
};

const ProcessPreprocessedFileFn = *const fn (bytes: []const u8, writer: anytype) anyerror!void;
const ProcessTableBasedArchFileFn = *const fn (
    bytes: []const u8,
    filters: Filters,
    writer: anytype,
    optional_writer: anytype,
) anyerror!void;

const FlowControl = enum {
    @"break",
    @"continue",
    none,
};

const AbiCheckParams = struct { abi: []const u8, flow: FlowControl };

const Filters = struct {
    abiCheckParams: ?AbiCheckParams,
    fixedName: ?*const fn (name: []const u8) []const u8,
    isReservedNameOld: ?*const fn (name: []const u8) bool,
};

fn abiCheck(abi: []const u8, params: *const AbiCheckParams) FlowControl {
    if (mem.eql(u8, abi, params.abi)) return params.flow;
    return .none;
}

fn fixedName(name: []const u8) []const u8 {
    return if (stdlib_renames.get(name)) |fixed| fixed else name;
}

const ArchInfo = union(enum) {
    table: struct {
        name: []const u8,
        enum_name: []const u8,
        file_path: []const u8,
        header: ?[]const u8,
        extra_values: ?[]const u8,
        process_file: ProcessTableBasedArchFileFn,
        filters: Filters,
        additional_enum: ?[]const u8,
    },
    preprocessor: struct {
        name: []const u8,
        enum_name: []const u8,
        file_path: []const u8,
        child_options: struct {
            comptime additional_args: ?[]const []const u8 = null,
            target: []const u8,

            pub inline fn getArgs(self: *const @This(), zig_exe: []const u8, file_path: []const u8) []const []const u8 {
                const additional_args: []const []const u8 = self.additional_args orelse &.{};
                return .{ zig_exe, "cc" } ++ additional_args ++ .{ "-target", self.target } ++ default_args ++ .{file_path};
            }
        },
        header: ?[]const u8,
        extra_values: ?[]const u8,
        process_file: ProcessPreprocessedFileFn,
        additional_enum: ?[]const u8,
    },
};

const arch_infos = [_]ArchInfo{
    .{
        // These architectures have their syscall definitions generated from a TSV
        // file, processed via scripts/syscallhdr.sh.
        .table = .{
            .name = "x86",
            .enum_name = "X86",
            .file_path = "arch/x86/entry/syscalls/syscall_32.tbl",
            .process_file = &processTableBasedArch,
            .filters = .{
                .abiCheckParams = null,
                .fixedName = &fixedName,
                .isReservedNameOld = null,
            },
            .header = null,
            .extra_values = null,
            .additional_enum = null,
        },
    },
    .{
        .table = .{
            .name = "x64",
            .enum_name = "X64",
            .file_path = "arch/x86/entry/syscalls/syscall_64.tbl",
            .process_file = &processTableBasedArch,
            .filters = .{
                // The x32 abi syscalls are always at the end.
                .abiCheckParams = .{ .abi = "x32", .flow = .@"break" },
                .fixedName = &fixedName,
                .isReservedNameOld = null,
            },
            .header = null,
            .extra_values = null,
            .additional_enum = null,
        },
    },
    .{
        .table = .{
            .name = "arm",
            .enum_name = "Arm",
            .file_path = "arch/arm/tools/syscall.tbl",
            .process_file = &processTableBasedArch,
            .filters = .{
                .abiCheckParams = .{ .abi = "oabi", .flow = .@"continue" },
                .fixedName = &fixedName,
                .isReservedNameOld = null,
            },
            .header = "    const arm_base = 0x0f0000;\n\n",
            // TODO: maybe extract these from arch/arm/include/uapi/asm/unistd.h
            .extra_values =
            \\
            \\    breakpoint = arm_base + 1,
            \\    cacheflush = arm_base + 2,
            \\    usr26 = arm_base + 3,
            \\    usr32 = arm_base + 4,
            \\    set_tls = arm_base + 5,
            \\    get_tls = arm_base + 6,
            \\
            ,
            .additional_enum = null,
        },
    },
    .{
        .table = .{
            .name = "sparc",
            .enum_name = "Sparc",
            .file_path = "arch/sparc/kernel/syscalls/syscall.tbl",
            .process_file = &processTableBasedArch,
            .filters = .{
                .abiCheckParams = .{ .abi = "64", .flow = .@"continue" },
                .fixedName = &fixedName,
                .isReservedNameOld = null,
            },
            .header = null,
            .extra_values = null,
            .additional_enum = null,
        },
    },
    .{
        .table = .{
            .name = "sparc64",
            .enum_name = "Sparc64",
            .file_path = "arch/sparc/kernel/syscalls/syscall.tbl",
            .process_file = &processTableBasedArch,
            .filters = .{
                .abiCheckParams = .{ .abi = "32", .flow = .@"continue" },
                .fixedName = &fixedName,
                .isReservedNameOld = null,
            },
            .header = null,
            .extra_values = null,
            .additional_enum = null,
        },
    },
    .{
        .table = .{
            .name = "m68k",
            .enum_name = "M68k",
            .file_path = "arch/m68k/kernel/syscalls/syscall.tbl",
            .process_file = &processTableBasedArch,
            .filters = .{
                // abi is always common
                .abiCheckParams = null,
                .fixedName = &fixedName,
                .isReservedNameOld = null,
            },
            .header = null,
            .extra_values = null,
            .additional_enum = null,
        },
    },
    .{
        .table = .{
            .name = "mips_o32",
            .enum_name = "MipsO32",
            .file_path = "arch/mips/kernel/syscalls/syscall_o32.tbl",
            .process_file = &processMipsBasedArch,
            .filters = .{
                // abi is always o32
                .abiCheckParams = null,
                .fixedName = &fixedName,
                .isReservedNameOld = &isReservedNameOld,
            },
            .header = "    const linux_base = 4000;\n\n",
            .extra_values = null,
            .additional_enum = null,
        },
    },
    .{
        .table = .{
            .name = "mips_n64",
            .enum_name = "MipsN64",
            .file_path = "arch/mips/kernel/syscalls/syscall_n64.tbl",
            .process_file = &processMipsBasedArch,
            .filters = .{
                // abi is always n64
                .abiCheckParams = null,
                .fixedName = &fixedName,
                .isReservedNameOld = &isReservedNameOld,
            },
            .header = "    const linux_base = 5000;\n\n",
            .extra_values = null,
            .additional_enum = null,
        },
    },
    .{
        .table = .{
            .name = "mips_n32",
            .enum_name = "MipsN32",
            .file_path = "arch/mips/kernel/syscalls/syscall_n32.tbl",
            .process_file = &processMipsBasedArch,
            .filters = .{
                // abi is always n32
                .abiCheckParams = null,
                .fixedName = &fixedName,
                .isReservedNameOld = &isReservedNameOld,
            },
            .header = "    const linux_base = 6000;\n\n",
            .extra_values = null,
            .additional_enum = null,
        },
    },
    .{
        .table = .{
            .name = "powerpc",
            .enum_name = "PowerPC",
            .file_path = "arch/powerpc/kernel/syscalls/syscall.tbl",
            .process_file = &processPowerPcBasedArch,
            .filters = .{
                .abiCheckParams = null,
                .fixedName = null,
                .isReservedNameOld = null,
            },
            .header = null,
            .extra_values = null,
            .additional_enum = "PowerPC64",
        },
    },
    .{
        .table = .{
            .name = "s390x",
            .enum_name = "S390x",
            .file_path = "arch/s390/kernel/syscalls/syscall.tbl",
            .process_file = &processTableBasedArch,
            .filters = .{
                // 32-bit s390 support in linux is deprecated
                .abiCheckParams = .{ .abi = "32", .flow = .@"continue" },
                .fixedName = &fixedName,
                .isReservedNameOld = null,
            },
            .header = null,
            .extra_values = null,
            .additional_enum = null,
        },
    },
    .{
        .table = .{
            .name = "xtensa",
            .enum_name = "Xtensa",
            .file_path = "arch/xtensa/kernel/syscalls/syscall.tbl",
            .process_file = &processTableBasedArch,
            .filters = .{
                // abi is always common
                .abiCheckParams = null,
                .fixedName = fixedName,
                .isReservedNameOld = &isReservedNameOld,
            },
            .header = null,
            .extra_values = null,
            .additional_enum = null,
        },
    },
    .{
        .preprocessor = .{
            .name = "arm64",
            .enum_name = "Arm64",
            .file_path = "arch/arm64/include/uapi/asm/unistd.h",
            .child_options = .{
                .additional_args = null,
                .target = "aarch64-freestanding-none",
            },
            .process_file = &processPreprocessedFile,
            .header = null,
            .extra_values = null,
            .additional_enum = null,
        },
    },
    .{
        .preprocessor = .{
            .name = "riscv32",
            .enum_name = "RiscV32",
            .file_path = "arch/riscv/include/uapi/asm/unistd.h",
            .child_options = .{
                .additional_args = null,
                .target = "riscv32-freestanding-none",
            },
            .process_file = &processPreprocessedFile,
            .header = null,
            .extra_values = null,
            .additional_enum = null,
        },
    },
    .{
        .preprocessor = .{
            .name = "riscv64",
            .enum_name = "RiscV64",
            .file_path = "arch/riscv/include/uapi/asm/unistd.h",
            .child_options = .{
                .additional_args = null,
                .target = "riscv64-freestanding-none",
            },
            .process_file = &processPreprocessedFile,
            .header = null,
            .extra_values = null,
            .additional_enum = null,
        },
    },
    .{
        .preprocessor = .{
            .name = "loongarch",
            .enum_name = "LoongArch64",
            .file_path = "arch/loongarch/include/uapi/asm/unistd.h",
            .child_options = .{
                .additional_args = null,
                .target = "loongarch64-freestanding-none",
            },
            .process_file = &processPreprocessedFile,
            .header = null,
            .extra_values = null,
            .additional_enum = null,
        },
    },
    .{
        .preprocessor = .{
            .name = "arc",
            .enum_name = "Arc",
            .file_path = "arch/arc/include/uapi/asm/unistd.h",
            .child_options = .{
                .additional_args = null,
                .target = "arc-freestanding-none",
            },
            .process_file = &processPreprocessedFile,
            .header = null,
            .extra_values = null,
            .additional_enum = null,
        },
    },
    .{
        .preprocessor = .{
            .name = "csky",
            .enum_name = "CSky",
            .file_path = "arch/csky/include/uapi/asm/unistd.h",
            .child_options = .{
                .additional_args = null,
                .target = "csky-freestanding-none",
            },
            .process_file = &processPreprocessedFile,
            .header = null,
            .extra_values = null,
            .additional_enum = null,
        },
    },
    .{
        .preprocessor = .{
            .name = "hexagon",
            .enum_name = "Hexagon",
            .file_path = "arch/hexagon/include/uapi/asm/unistd.h",
            .child_options = .{
                .additional_args = null,
                .target = "hexagon-freestanding-none",
            },
            .process_file = &processPreprocessedFile,
            .header = null,
            .extra_values = null,
            .additional_enum = null,
        },
    },
};

fn processPreprocessedFile(
    bytes: []const u8,
    writer: anytype,
) !void {
    var lines = mem.tokenizeScalar(u8, bytes, '\n');
    while (lines.next()) |line| {
        var fields = mem.tokenizeAny(u8, line, " ");
        const prefix = fields.next() orelse return error.Incomplete;

        if (!mem.eql(u8, prefix, "zigsyscall")) continue;

        const sys_name = fields.next() orelse return error.Incomplete;
        const value = fields.rest();
        const name = (getOverridenNameNew(value) orelse sys_name)["sys_".len..];
        const fixed_name = if (stdlib_renames_new.get(name)) |f| f else if (stdlib_renames.get(name)) |f| f else name;

        try writer.print("    {p} = {s},\n", .{ zig.fmtId(fixed_name), value });
    }
}

fn processTableBasedArch(
    bytes: []const u8,
    filters: Filters,
    writer: anytype,
    optional_writer: anytype,
) !void {
    _ = optional_writer;

    var lines = mem.tokenizeScalar(u8, bytes, '\n');
    while (lines.next()) |line| {
        if (line[0] == '#') continue;

        var fields = mem.tokenizeAny(u8, line, " \t");
        const number = fields.next() orelse return error.Incomplete;

        const abi = fields.next() orelse return error.Incomplete;
        if (filters.abiCheckParams) |*params| {
            switch (abiCheck(abi, params)) {
                .none => {},
                .@"break" => break,
                .@"continue" => continue,
            }
        }
        const name = fields.next() orelse return error.Incomplete;
        if (filters.isReservedNameOld) |isReservedNameOldFn| {
            if (isReservedNameOldFn(name)) continue;
        }
        const fixed_name = if (filters.fixedName) |fixedNameFn| fixedNameFn(name) else name;

        try writer.print("    {p} = {s},\n", .{ zig.fmtId(fixed_name), number });
    }
}

fn processMipsBasedArch(
    bytes: []const u8,
    filters: Filters,
    writer: anytype,
    optional_writer: anytype,
) !void {
    _ = optional_writer;

    var lines = mem.tokenizeScalar(u8, bytes, '\n');
    while (lines.next()) |line| {
        if (line[0] == '#') continue;

        var fields = mem.tokenizeAny(u8, line, " \t");
        const number = fields.next() orelse return error.Incomplete;

        const abi = fields.next() orelse return error.Incomplete;
        if (filters.abiCheckParams) |*params| {
            switch (abiCheck(abi, params)) {
                .none => {},
                .@"break" => break,
                .@"continue" => continue,
            }
        }
        const name = fields.next() orelse return error.Incomplete;
        if (filters.isReservedNameOld) |isReservedNameOldFn| {
            if (isReservedNameOldFn(name)) continue;
        }
        const fixed_name = if (filters.fixedName) |fixedNameFn| fixedNameFn(name) else name;

        try writer.print("    {p} = linux_base + {s},\n", .{ zig.fmtId(fixed_name), number });
    }
}

fn processPowerPcBasedArch(
    bytes: []const u8,
    filters: Filters,
    writer: anytype,
    optional_writer: anytype,
) !void {
    _ = filters;
    var lines = mem.tokenizeScalar(u8, bytes, '\n');

    while (lines.next()) |line| {
        if (line[0] == '#') continue;

        var fields = mem.tokenizeAny(u8, line, " \t");
        const number = fields.next() orelse return error.Incomplete;
        const abi = fields.next() orelse return error.Incomplete;
        const name = fields.next() orelse return error.Incomplete;
        const fixed_name = if (stdlib_renames.get(name)) |fixed| fixed else name;

        if (mem.eql(u8, abi, "spu")) {
            continue;
        } else if (mem.eql(u8, abi, "32")) {
            try writer.print("    {p} = {s},\n", .{ zig.fmtId(fixed_name), number });
        } else if (mem.eql(u8, abi, "64")) {
            try optional_writer.?.print("    {p} = {s},\n", .{ zig.fmtId(fixed_name), number });
        } else { // common/nospu
            try writer.print("    {p} = {s},\n", .{ zig.fmtId(fixed_name), number });
            try optional_writer.?.print("    {p} = {s},\n", .{ zig.fmtId(fixed_name), number });
        }
    }
}

fn generateSyscallsFromTable(
    allocator: std.mem.Allocator,
    buf: []u8,
    linux_dir: std.fs.Dir,
    writer: anytype,
    _arch_info: *const ArchInfo,
) !void {
    std.debug.assert(_arch_info.* == .table);

    const arch_info = _arch_info.table;

    const table = try linux_dir.readFile(arch_info.file_path, buf);

    var optional_array_list: ?std.ArrayList(u8) = if (arch_info.additional_enum) |_| std.ArrayList(u8).init(allocator) else null;
    const optional_writer = if (optional_array_list) |_| optional_array_list.?.writer() else null;

    try writer.print("pub const {s} = enum(usize) {{\n", .{arch_info.enum_name});

    if (arch_info.header) |header| {
        try writer.writeAll(header);
    }

    try arch_info.process_file(table, arch_info.filters, writer, optional_writer);

    if (arch_info.extra_values) |extra_values| {
        try writer.writeAll(extra_values);
    }
    try writer.writeAll("};");

    if (arch_info.additional_enum) |additional_enum| {
        try writer.writeAll("\n\n");
        try writer.print("pub const {s} = enum(usize) {{\n", .{additional_enum});
        try writer.writeAll(optional_array_list.?.items);
        try writer.writeAll("};");
    }
}

fn generateSyscallsFromPreprocessor(
    allocator: std.mem.Allocator,
    linux_dir: std.fs.Dir,
    linux_path: []const u8,
    zig_exe: []const u8,
    writer: anytype,
    _arch_info: *const ArchInfo,
) !void {
    std.debug.assert(_arch_info.* == .preprocessor);

    const arch_info = _arch_info.preprocessor;

    const child_result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = arch_info.child_options.getArgs(zig_exe, arch_info.file_path),
        .cwd = linux_path,
        .cwd_dir = linux_dir,
    });
    if (child_result.stderr.len > 0) std.debug.print("{s}\n", .{child_result.stderr});

    const defines = switch (child_result.term) {
        .Exited => |code| if (code == 0) child_result.stdout else {
            std.debug.print("zig cc exited with code {d}\n", .{code});
            std.process.exit(1);
        },
        else => {
            std.debug.print("zig cc crashed\n", .{});
            std.process.exit(1);
        },
    };

    try writer.print("pub const {s} = enum(usize) {{\n", .{arch_info.enum_name});
    if (arch_info.header) |header| {
        try writer.writeAll(header);
    }

    try arch_info.process_file(defines, writer);

    if (arch_info.extra_values) |extra_values| {
        try writer.writeAll(extra_values);
    }

    try writer.writeAll("};");
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = try std.process.argsAlloc(allocator);
    if (args.len < 3 or mem.eql(u8, args[1], "--help"))
        usageAndExit(std.io.getStdErr(), args[0], 1);
    const zig_exe = args[1];
    const linux_path = args[2];

    var buf_out = std.io.bufferedWriter(std.io.getStdOut().writer());
    const writer = buf_out.writer();

    var linux_dir = try std.fs.cwd().openDir(linux_path, .{});
    defer linux_dir.close();

    try writer.writeAll(
        \\// This file is automatically generated.
        \\// See tools/generate_linux_syscalls.zig for more info.
        \\
        \\
    );

    // As of 5.17.1, the largest table is 23467 bytes.
    // 32k should be enough for now.
    const buf = try allocator.alloc(u8, 1 << 15);
    defer allocator.free(buf);

    inline for (arch_infos, 0..) |arch_info, i| {
        switch (arch_info) {
            .table => try generateSyscallsFromTable(
                allocator,
                buf,
                linux_dir,
                writer,
                &arch_info,
            ),
            .preprocessor => try generateSyscallsFromPreprocessor(
                allocator,
                linux_dir,
                linux_path,
                zig_exe,
                writer,
                &arch_info,
            ),
        }
        if (i < arch_infos.len - 1) {
            try writer.writeAll("\n\n");
        } else {
            try writer.writeAll("\n");
        }
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
