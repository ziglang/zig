//! Example usage:
//! ./gen_stubs /path/to/musl/build-all >libc.S
//!
//! The directory 'build-all' is expected to contain these subdirectories:
//!
//! * aarch64
//! * arm
//! * i386
//! * hexagon
//! * loongarch64
//! * mips
//! * mips64
//! * mipsn32
//! * powerpc
//! * powerpc64
//! * riscv32
//! * riscv64
//! * s390x
//! * x32 (currently broken)
//! * x86_64
//!
//! ...each with 'lib/libc.so' inside of them.
//!
//! When building the resulting libc.S file, these defines are required:
//! * `-DTIME32`: When the target's primary time ABI is 32-bit
//! * `-DPTR64`: When the target has 64-bit pointers
//! * One of the following, corresponding to the CPU architecture:
//!   - `-DARCH_aarch64`
//!   - `-DARCH_arm`
//!   - `-DARCH_i386`
//!   - `-DARCH_hexagon`
//!   - `-DARCH_loongarch64`
//!   - `-DARCH_mips`
//!   - `-DARCH_mips64`
//!   - `-DARCH_mipsn32`
//!   - `-DARCH_powerpc`
//!   - `-DARCH_powerpc64`
//!   - `-DARCH_riscv32`
//!   - `-DARCH_riscv64`
//!   - `-DARCH_s390x`
//!   - `-DARCH_x32`
//!   - `-DARCH_x86_64`
//! * One of the following, corresponding to the CPU architecture family:
//!   - `-DFAMILY_aarch64`
//!   - `-DFAMILY_arm`
//!   - `-DFAMILY_hexagon`
//!   - `-DFAMILY_loongarch`
//!   - `-DFAMILY_mips`
//!   - `-DFAMILY_powerpc`
//!   - `-DFAMILY_riscv`
//!   - `-DFAMILY_s390x`
//!   - `-DFAMILY_x86`

// TODO: pick the best index to put them into instead of at the end
//       - e.g. find a common previous symbol and put it after that one
//       - they definitely need to go into the correct section

const std = @import("std");
const builtin = std.builtin;
const mem = std.mem;
const log = std.log;
const elf = std.elf;
const native_endian = @import("builtin").cpu.arch.endian();

const Arch = enum {
    aarch64,
    arm,
    i386,
    hexagon,
    loongarch64,
    mips,
    mips64,
    mipsn32,
    powerpc,
    powerpc64,
    riscv32,
    riscv64,
    s390x,
    x86_64,

    pub fn ptrSize(arch: Arch) u16 {
        return switch (arch) {
            .arm,
            .hexagon,
            .i386,
            .mips,
            .mipsn32,
            .powerpc,
            .riscv32,
            => 4,
            .aarch64,
            .loongarch64,
            .mips64,
            .powerpc64,
            .riscv64,
            .s390x,
            .x86_64,
            => 8,
        };
    }

    pub fn isTime32(arch: Arch) bool {
        return switch (arch) {
            // This list will never grow; newer 32-bit ports will be time64 (e.g. riscv32).
            .arm,
            .i386,
            .mips,
            .mipsn32,
            .powerpc,
            => true,
            else => false,
        };
    }

    pub fn family(arch: Arch) Family {
        return switch (arch) {
            .aarch64 => .aarch64,
            .arm => .arm,
            .i386, .x86_64 => .x86,
            .hexagon => .hexagon,
            .loongarch64 => .loongarch,
            .mips, .mips64, .mipsn32 => .mips,
            .powerpc, .powerpc64 => .powerpc,
            .riscv32, .riscv64 => .riscv,
            .s390x => .s390x,
        };
    }
};

const Family = enum {
    aarch64,
    arm,
    hexagon,
    loongarch,
    mips,
    powerpc,
    riscv,
    s390x,
    x86,
};

const arches: [@typeInfo(Arch).@"enum".fields.len]Arch = blk: {
    var result: [@typeInfo(Arch).@"enum".fields.len]Arch = undefined;
    for (@typeInfo(Arch).@"enum".fields) |field| {
        const arch: Arch = @enumFromInt(field.value);
        result[archIndex(arch)] = arch;
    }
    break :blk result;
};

const MultiSym = struct {
    size: [arches.len]u64,
    present: [arches.len]bool,
    binding: [arches.len]u4,
    section: u16,
    ty: u4,
    visib: elf.STV,

    fn isSingleArch(ms: MultiSym) ?Arch {
        var result: ?Arch = null;
        inline for (@typeInfo(Arch).@"enum".fields) |field| {
            const arch: Arch = @enumFromInt(field.value);
            if (ms.present[archIndex(arch)]) {
                if (result != null) return null;
                result = arch;
            }
        }
        return result;
    }

    fn isFamily(ms: MultiSym) ?Family {
        var result: ?Family = null;
        inline for (@typeInfo(Arch).@"enum".fields) |field| {
            const arch: Arch = @enumFromInt(field.value);
            if (ms.present[archIndex(arch)]) {
                const family = arch.family();
                if (result) |r| if (family != r) return null;
                result = family;
            }
        }
        return result;
    }

    fn allPresent(ms: MultiSym) bool {
        for (arches, 0..) |_, i| {
            if (!ms.present[i]) {
                return false;
            }
        }
        return true;
    }

    fn isTime32Only(ms: MultiSym) bool {
        inline for (@typeInfo(Arch).@"enum".fields) |field| {
            const arch: Arch = @enumFromInt(field.value);
            if (ms.present[archIndex(arch)] != arch.isTime32()) {
                return false;
            }
        }
        return true;
    }

    fn commonSize(ms: MultiSym) ?u64 {
        var size: ?u64 = null;
        for (arches, 0..) |_, i| {
            if (!ms.present[i]) continue;
            if (size) |s| {
                if (ms.size[i] != s) {
                    return null;
                }
            } else {
                size = ms.size[i];
            }
        }
        return size.?;
    }

    fn commonBinding(ms: MultiSym) ?u4 {
        var binding: ?u4 = null;
        for (arches, 0..) |_, i| {
            if (!ms.present[i]) continue;
            if (binding) |b| {
                if (ms.binding[i] != b) {
                    return null;
                }
            } else {
                binding = ms.binding[i];
            }
        }
        return binding.?;
    }

    fn isPtrSize(ms: MultiSym, mult: u16) bool {
        inline for (@typeInfo(Arch).@"enum".fields) |field| {
            const arch: Arch = @enumFromInt(field.value);
            const arch_index = archIndex(arch);
            if (ms.present[arch_index] and ms.size[arch_index] != arch.ptrSize() * mult) {
                return false;
            }
        }
        return true;
    }

    fn isWeak64(ms: MultiSym) bool {
        inline for (@typeInfo(Arch).@"enum".fields) |field| {
            const arch: Arch = @enumFromInt(field.value);
            const arch_index = archIndex(arch);
            const binding: u4 = switch (arch.ptrSize()) {
                4 => std.elf.STB_GLOBAL,
                8 => std.elf.STB_WEAK,
                else => unreachable,
            };
            if (ms.present[arch_index] and ms.binding[arch_index] != binding) {
                return false;
            }
        }
        return true;
    }

    fn isWeakTime64(ms: MultiSym) bool {
        inline for (@typeInfo(Arch).@"enum".fields) |field| {
            const arch: Arch = @enumFromInt(field.value);
            const arch_index = archIndex(arch);
            const binding: u4 = if (arch.isTime32()) std.elf.STB_GLOBAL else std.elf.STB_WEAK;
            if (ms.present[arch_index] and ms.binding[arch_index] != binding) {
                return false;
            }
        }
        return true;
    }
};

const Parse = struct {
    arena: mem.Allocator,
    sym_table: *std.StringArrayHashMap(MultiSym),
    sections: *std.StringArrayHashMap(void),
    elf_bytes: []align(@alignOf(elf.Elf64_Ehdr)) u8,
    header: elf.Header,
    arch: Arch,
};

pub fn main() !void {
    var arena_instance = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();

    const args = try std.process.argsAlloc(arena);
    const build_all_path = args[1];

    var build_all_dir = try std.fs.cwd().openDir(build_all_path, .{});

    var sym_table = std.StringArrayHashMap(MultiSym).init(arena);
    var sections = std.StringArrayHashMap(void).init(arena);

    for (arches) |arch| {
        const libc_so_path = try std.fmt.allocPrint(arena, "{s}/lib/libc.so", .{
            @tagName(arch),
        });

        // Read the ELF header.
        const elf_bytes = build_all_dir.readFileAllocOptions(
            arena,
            libc_so_path,
            100 * 1024 * 1024,
            1 * 1024 * 1024,
            @alignOf(elf.Elf64_Ehdr),
            null,
        ) catch |err| {
            std.debug.panic("unable to read '{s}/{s}': {s}", .{
                build_all_path, libc_so_path, @errorName(err),
            });
        };
        const header = try elf.Header.parse(elf_bytes[0..@sizeOf(elf.Elf64_Ehdr)]);

        const parse: Parse = .{
            .arena = arena,
            .sym_table = &sym_table,
            .sections = &sections,
            .elf_bytes = elf_bytes,
            .header = header,
            .arch = arch,
        };

        switch (header.is_64) {
            true => switch (header.endian) {
                .big => try parseElf(parse, true, .big),
                .little => try parseElf(parse, true, .little),
            },
            false => switch (header.endian) {
                .big => try parseElf(parse, false, .big),
                .little => try parseElf(parse, false, .little),
            },
        }
    }

    var stdout_buffer: [2000]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writerStreaming(&stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.writeAll(
        \\#ifdef PTR64
        \\#define WEAK64 .weak
        \\#define PTR_SIZE_BYTES 8
        \\#define PTR2_SIZE_BYTES 16
        \\#else
        \\#define WEAK64 .globl
        \\#define PTR_SIZE_BYTES 4
        \\#define PTR2_SIZE_BYTES 8
        \\#endif
        \\
        \\#ifdef TIME32
        \\#define WEAKTIME64 .globl
        \\#else
        \\#define WEAKTIME64 .weak
        \\#endif
        \\
        \\
    );

    // Sort the symbols for deterministic output and cleaner vcs diffs.
    const SymTableSort = struct {
        sections: *const std.StringArrayHashMap(void),
        sym_table: *const std.StringArrayHashMap(MultiSym),

        /// Sort first by section name, then by symbol name
        pub fn lessThan(ctx: @This(), index_a: usize, index_b: usize) bool {
            const multi_sym_a = ctx.sym_table.values()[index_a];
            const multi_sym_b = ctx.sym_table.values()[index_b];

            const section_a = ctx.sections.keys()[multi_sym_a.section];
            const section_b = ctx.sections.keys()[multi_sym_b.section];

            switch (mem.order(u8, section_a, section_b)) {
                .lt => return true,
                .gt => return false,
                .eq => {},
            }

            const symbol_a = ctx.sym_table.keys()[index_a];
            const symbol_b = ctx.sym_table.keys()[index_b];

            switch (mem.order(u8, symbol_a, symbol_b)) {
                .lt => return true,
                .gt, .eq => return false,
            }
        }
    };
    sym_table.sort(SymTableSort{ .sym_table = &sym_table, .sections = &sections });

    var prev_section: u16 = std.math.maxInt(u16);
    var prev_pp_state: union(enum) { all, single: Arch, multi, family: Family, time32 } = .all;
    for (sym_table.values(), 0..) |multi_sym, sym_index| {
        const name = sym_table.keys()[sym_index];

        if (multi_sym.section != prev_section) {
            prev_section = multi_sym.section;
            const sh_name = sections.keys()[multi_sym.section];
            try stdout.print("{s}\n", .{sh_name});
        }

        if (multi_sym.allPresent()) {
            switch (prev_pp_state) {
                .all => {},
                .single, .multi, .family, .time32 => {
                    try stdout.writeAll("#endif\n");
                    prev_pp_state = .all;
                },
            }
        } else if (multi_sym.isSingleArch()) |arch| {
            switch (prev_pp_state) {
                .all => {
                    try stdout.print("#ifdef ARCH_{s}\n", .{@tagName(arch)});
                    prev_pp_state = .{ .single = arch };
                },
                .multi, .family, .time32 => {
                    try stdout.print("#endif\n#ifdef ARCH_{s}\n", .{@tagName(arch)});
                    prev_pp_state = .{ .single = arch };
                },
                .single => |prev_arch| {
                    if (arch != prev_arch) {
                        try stdout.print("#endif\n#ifdef ARCH_{s}\n", .{@tagName(arch)});
                        prev_pp_state = .{ .single = arch };
                    }
                },
            }
        } else if (multi_sym.isFamily()) |family| {
            switch (prev_pp_state) {
                .all => {
                    try stdout.print("#ifdef FAMILY_{s}\n", .{@tagName(family)});
                    prev_pp_state = .{ .family = family };
                },
                .single, .multi, .time32 => {
                    try stdout.print("#endif\n#ifdef FAMILY_{s}\n", .{@tagName(family)});
                    prev_pp_state = .{ .family = family };
                },
                .family => |prev_family| {
                    if (family != prev_family) {
                        try stdout.print("#endif\n#ifdef FAMILY_{s}\n", .{@tagName(family)});
                        prev_pp_state = .{ .family = family };
                    }
                },
            }
        } else if (multi_sym.isTime32Only()) {
            switch (prev_pp_state) {
                .all => {
                    try stdout.writeAll("#ifdef TIME32\n");
                    prev_pp_state = .time32;
                },
                .single, .multi, .family => {
                    try stdout.writeAll("#endif\n#ifdef TIME32\n");
                    prev_pp_state = .time32;
                },
                .time32 => {},
            }
        } else {
            switch (prev_pp_state) {
                .all => {},
                .single, .multi, .family, .time32 => {
                    try stdout.writeAll("#endif\n");
                },
            }
            prev_pp_state = .multi;

            var first = true;
            try stdout.writeAll("#if ");

            for (arches, 0..) |arch, i| {
                if (multi_sym.present[i]) continue;

                if (!first) try stdout.writeAll(" && ");
                first = false;
                try stdout.print("!defined(ARCH_{s})", .{@tagName(arch)});
            }

            try stdout.writeAll("\n");
        }

        if (multi_sym.commonBinding()) |binding| {
            switch (binding) {
                elf.STB_GLOBAL => {
                    try stdout.print(".globl {s}\n", .{name});
                },
                elf.STB_WEAK => {
                    try stdout.print(".weak {s}\n", .{name});
                },
                else => unreachable,
            }
        } else if (multi_sym.isWeak64()) {
            try stdout.print("WEAK64 {s}\n", .{name});
        } else if (multi_sym.isWeakTime64()) {
            try stdout.print("WEAKTIME64 {s}\n", .{name});
        } else {
            for (arches, 0..) |arch, i| {
                log.info("symbol '{s}' binding on {s}: {d}", .{
                    name, @tagName(arch), multi_sym.binding[i],
                });
            }
        }

        switch (multi_sym.ty) {
            elf.STT_NOTYPE => {},
            elf.STT_FUNC => {
                try stdout.print(".type {s}, %function;\n", .{name});
                // omitting the size is OK for functions
            },
            elf.STT_OBJECT => {
                try stdout.print(".type {s}, %object;\n", .{name});
                if (multi_sym.commonSize()) |size| {
                    try stdout.print(".size {s}, {d}\n", .{ name, size });
                } else if (multi_sym.isPtrSize(1)) {
                    try stdout.print(".size {s}, PTR_SIZE_BYTES\n", .{name});
                } else if (multi_sym.isPtrSize(2)) {
                    try stdout.print(".size {s}, PTR2_SIZE_BYTES\n", .{name});
                } else {
                    for (arches, 0..) |arch, i| {
                        log.info("symbol '{s}' size on {s}: {d}", .{
                            name, @tagName(arch), multi_sym.size[i],
                        });
                    }
                    //try stdout.print(".size {s}, {d}\n", .{ name, size });
                }
            },
            else => unreachable,
        }

        switch (multi_sym.visib) {
            .DEFAULT => {},
            .PROTECTED => try stdout.print(".protected {s}\n", .{name}),
            .INTERNAL, .HIDDEN => unreachable,
        }

        try stdout.print("{s}:\n", .{name});
    }

    switch (prev_pp_state) {
        .all => {},
        .single, .multi, .family, .time32 => try stdout.writeAll("#endif\n"),
    }

    try stdout.flush();
}

fn parseElf(parse: Parse, comptime is_64: bool, comptime endian: builtin.Endian) !void {
    const arena = parse.arena;
    const elf_bytes = parse.elf_bytes;
    const header = parse.header;
    const Sym = if (is_64) elf.Elf64_Sym else elf.Elf32_Sym;
    const S = struct {
        fn endianSwap(x: anytype) @TypeOf(x) {
            if (endian != native_endian) {
                return @byteSwap(x);
            } else {
                return x;
            }
        }
        fn symbolAddrLessThan(_: void, lhs: Sym, rhs: Sym) bool {
            return endianSwap(lhs.st_value) < endianSwap(rhs.st_value);
        }
    };
    // A little helper to do endian swapping.
    const s = S.endianSwap;

    // Obtain list of sections.
    const Shdr = if (is_64) elf.Elf64_Shdr else elf.Elf32_Shdr;
    const shdrs = mem.bytesAsSlice(Shdr, elf_bytes[header.shoff..])[0..header.shnum];

    // Obtain the section header string table.
    const shstrtab_offset = s(shdrs[header.shstrndx].sh_offset);
    log.debug("shstrtab is at offset {d}", .{shstrtab_offset});
    const shstrtab = elf_bytes[shstrtab_offset..];

    // Maps this ELF file's section header index to the multi arch section ArrayHashMap index.
    const section_index_map = try arena.alloc(u16, shdrs.len);

    // Find the offset of the dynamic symbol table.
    var dynsym_index: u16 = 0;
    for (shdrs, 0..) |shdr, i| {
        const sh_name = try arena.dupe(u8, mem.sliceTo(shstrtab[s(shdr.sh_name)..], 0));
        log.debug("found section: {s}", .{sh_name});
        if (mem.eql(u8, sh_name, ".dynsym")) {
            dynsym_index = @as(u16, @intCast(i));
        }
        const gop = try parse.sections.getOrPut(sh_name);
        section_index_map[i] = @as(u16, @intCast(gop.index));
    }
    if (dynsym_index == 0) @panic("did not find the .dynsym section");

    log.debug("found .dynsym section at index {d}", .{dynsym_index});

    // Read the dynamic symbols into a list.
    const dyn_syms_off = s(shdrs[dynsym_index].sh_offset);
    const dyn_syms_size = s(shdrs[dynsym_index].sh_size);
    const dyn_syms = mem.bytesAsSlice(Sym, elf_bytes[dyn_syms_off..][0..dyn_syms_size]);

    const dynstr_offset = s(shdrs[s(shdrs[dynsym_index].sh_link)].sh_offset);
    const dynstr = elf_bytes[dynstr_offset..];

    // Sort the list by address, ascending.
    // We need a copy to fix alignment.
    const copied_dyn_syms = copy: {
        const ptr = try arena.alloc(Sym, dyn_syms.len);
        @memcpy(ptr, dyn_syms);
        break :copy ptr;
    };
    mem.sort(Sym, copied_dyn_syms, {}, S.symbolAddrLessThan);

    for (copied_dyn_syms) |sym| {
        const this_section = s(sym.st_shndx);
        const name = try arena.dupe(u8, mem.sliceTo(dynstr[s(sym.st_name)..], 0));
        const ty = @as(u4, @truncate(sym.st_info));
        const binding = @as(u4, @truncate(sym.st_info >> 4));
        const visib = @as(elf.STV, @enumFromInt(@as(u2, @truncate(sym.st_other))));
        const size = s(sym.st_size);

        if (size == 0) {
            log.warn("{s}: symbol '{s}' has size 0", .{ @tagName(parse.arch), name });
        }

        if (sym.st_shndx == elf.SHN_UNDEF) {
            log.debug("{s}: skipping '{s}' due to it being undefined", .{
                @tagName(parse.arch), name,
            });
            continue;
        }

        switch (binding) {
            elf.STB_GLOBAL, elf.STB_WEAK => {},
            else => {
                log.debug("{s}: skipping '{s}' due to it having binding '{d}'", .{
                    @tagName(parse.arch), name, binding,
                });
                continue;
            },
        }

        switch (ty) {
            elf.STT_NOTYPE, elf.STT_FUNC, elf.STT_OBJECT => {},
            else => {
                log.debug("{s}: skipping '{s}' due to it having type '{d}'", .{
                    @tagName(parse.arch), name, ty,
                });
                continue;
            },
        }

        switch (visib) {
            .DEFAULT, .PROTECTED => {},
            .INTERNAL, .HIDDEN => {
                log.debug("{s}: skipping '{s}' due to it having visibility '{s}'", .{
                    @tagName(parse.arch), name, @tagName(visib),
                });
                continue;
            },
        }

        const gop = try parse.sym_table.getOrPut(name);
        if (gop.found_existing) {
            if (gop.value_ptr.section != section_index_map[this_section]) {
                const sh_name = mem.sliceTo(shstrtab[s(shdrs[this_section].sh_name)..], 0);
                fatal("symbol '{s}' in arch {s} is in section {s} but in arch {s} is in section {s}", .{
                    name,
                    @tagName(parse.arch),
                    sh_name,
                    archSetName(gop.value_ptr.present),
                    parse.sections.keys()[gop.value_ptr.section],
                });
            }
            if (gop.value_ptr.ty != ty) blk: {
                if (ty == elf.STT_NOTYPE) {
                    log.warn("symbol '{s}' in arch {s} has type {d} but in arch {s} has type {d}. going with the one that is not STT_NOTYPE", .{
                        name,
                        @tagName(parse.arch),
                        ty,
                        archSetName(gop.value_ptr.present),
                        gop.value_ptr.ty,
                    });
                    break :blk;
                }
                if (gop.value_ptr.ty == elf.STT_NOTYPE) {
                    log.warn("symbol '{s}' in arch {s} has type {d} but in arch {s} has type {d}. going with the one that is not STT_NOTYPE", .{
                        name,
                        @tagName(parse.arch),
                        ty,
                        archSetName(gop.value_ptr.present),
                        gop.value_ptr.ty,
                    });
                    gop.value_ptr.ty = ty;
                    break :blk;
                }
                fatal("symbol '{s}' in arch {s} has type {d} but in arch {s} has type {d}", .{
                    name,
                    @tagName(parse.arch),
                    ty,
                    archSetName(gop.value_ptr.present),
                    gop.value_ptr.ty,
                });
            }
            if (gop.value_ptr.visib != visib) {
                fatal("symbol '{s}' in arch {s} has visib {s} but in arch {s} has visib {s}", .{
                    name,
                    @tagName(parse.arch),
                    @tagName(visib),
                    archSetName(gop.value_ptr.present),
                    @tagName(gop.value_ptr.visib),
                });
            }
        } else {
            gop.value_ptr.* = .{
                .present = [1]bool{false} ** arches.len,
                .section = section_index_map[this_section],
                .ty = ty,
                .binding = [1]u4{0} ** arches.len,
                .visib = visib,
                .size = [1]u64{0} ** arches.len,
            };
        }
        gop.value_ptr.present[archIndex(parse.arch)] = true;
        gop.value_ptr.size[archIndex(parse.arch)] = size;
        gop.value_ptr.binding[archIndex(parse.arch)] = binding;
    }
}

fn archIndex(arch: Arch) u8 {
    return @intFromEnum(arch);
}

fn archSetName(arch_set: [arches.len]bool) []const u8 {
    for (arches, arch_set) |arch, set_item| {
        if (set_item) {
            return @tagName(arch);
        }
    }
    return "(none)";
}

fn fatal(comptime format: []const u8, args: anytype) noreturn {
    log.err(format, args);
    std.process.exit(1);
}
