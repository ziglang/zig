//! Example usage:
//! ./gen_stubs /path/to/musl/build-all >libc.S
//!
//! The directory 'build-all' is expected to contain these subdirectories:
//! arm  x86  mips  mips64  powerpc  powerpc64  riscv64  x86_64
//!
//! ...each with 'lib/libc.so' inside of them.
//!
//! When building the resulting libc.S file, these defines are required:
//! * `-DPTR64`: when the architecture is 64-bit
//! * One of the following, corresponding to the CPU architecture:
//!   - `-DARCH_riscv64`
//!   - `-DARCH_mips`
//!   - `-DARCH_i386`
//!   - `-DARCH_x86_64`
//!   - `-DARCH_powerpc`
//!   - `-DARCH_powerpc64`
//!   - `-DARCH_aarch64`

// TODO: pick the best index to put them into instead of at the end
//       - e.g. find a common previous symbol and put it after that one
//       - they definitely need to go into the correct section

const std = @import("std");
const builtin = std.builtin;
const mem = std.mem;
const log = std.log;
const elf = std.elf;
const native_endian = @import("builtin").target.cpu.arch.endian();

const arches: [7]std.Target.Cpu.Arch = blk: {
    var result: [7]std.Target.Cpu.Arch = undefined;
    for (.{ .riscv64, .mips, .x86, .x86_64, .powerpc, .powerpc64, .aarch64 }) |arch| {
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

    fn allPresent(ms: MultiSym) bool {
        for (arches) |_, i| {
            if (!ms.present[i]) {
                return false;
            }
        }
        return true;
    }

    fn is32Only(ms: MultiSym) bool {
        return ms.present[archIndex(.riscv64)] == false and
            ms.present[archIndex(.mips)] == true and
            ms.present[archIndex(.x86)] == true and
            ms.present[archIndex(.x86_64)] == false and
            ms.present[archIndex(.powerpc)] == true and
            ms.present[archIndex(.powerpc64)] == false and
            ms.present[archIndex(.aarch64)] == false;
    }

    fn commonSize(ms: MultiSym) ?u64 {
        var size: ?u64 = null;
        for (arches) |_, i| {
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
        for (arches) |_, i| {
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

    fn isPtrSize(ms: MultiSym) bool {
        const map = .{
            .{ .riscv64, 8 },
            .{ .mips, 4 },
            .{ .x86, 4 },
            .{ .x86_64, 8 },
            .{ .powerpc, 4 },
            .{ .powerpc64, 8 },
            .{ .aarch64, 8 },
        };
        inline for (map) |item| {
            const arch = item[0];
            const size = item[1];
            const arch_index = archIndex(arch);
            if (ms.present[arch_index] and ms.size[arch_index] != size) {
                return false;
            }
        }
        return true;
    }

    fn isPtr2Size(ms: MultiSym) bool {
        const map = .{
            .{ .riscv64, 16 },
            .{ .mips, 8 },
            .{ .x86, 8 },
            .{ .x86_64, 16 },
            .{ .powerpc, 8 },
            .{ .powerpc64, 16 },
            .{ .aarch64, 16 },
        };
        inline for (map) |item| {
            const arch = item[0];
            const size = item[1];
            const arch_index = archIndex(arch);
            if (ms.present[arch_index] and ms.size[arch_index] != size) {
                return false;
            }
        }
        return true;
    }

    fn isWeak64(ms: MultiSym) bool {
        const map = .{
            .{ .riscv64, 2 },
            .{ .mips, 1 },
            .{ .x86, 1 },
            .{ .x86_64, 2 },
            .{ .powerpc, 1 },
            .{ .powerpc64, 2 },
            .{ .aarch64, 2 },
        };
        inline for (map) |item| {
            const arch = item[0];
            const binding = item[1];
            const arch_index = archIndex(arch);
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
    blacklist: std.StringArrayHashMap(void),
    elf_bytes: []align(@alignOf(elf.Elf64_Ehdr)) u8,
    header: elf.Header,
    arch: std.Target.Cpu.Arch,
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
    var blacklist = std.StringArrayHashMap(void).init(arena);

    try blacklist.ensureUnusedCapacity(blacklisted_symbols.len);
    for (blacklisted_symbols) |name| {
        blacklist.putAssumeCapacityNoClobber(name, {});
    }

    for (arches) |arch| {
        const libc_so_path = try std.fmt.allocPrint(arena, "{s}/lib/libc.so", .{@tagName(arch)});

        // Read the ELF header.
        const elf_bytes = try build_all_dir.readFileAllocOptions(
            arena,
            libc_so_path,
            100 * 1024 * 1024,
            1 * 1024 * 1024,
            @alignOf(elf.Elf64_Ehdr),
            null,
        );
        const header = try elf.Header.parse(elf_bytes[0..@sizeOf(elf.Elf64_Ehdr)]);

        const parse: Parse = .{
            .arena = arena,
            .sym_table = &sym_table,
            .sections = &sections,
            .blacklist = blacklist,
            .elf_bytes = elf_bytes,
            .header = header,
            .arch = arch,
        };

        switch (header.is_64) {
            true => switch (header.endian) {
                .Big => try parseElf(parse, true, .Big),
                .Little => try parseElf(parse, true, .Little),
            },
            false => switch (header.endian) {
                .Big => try parseElf(parse, false, .Big),
                .Little => try parseElf(parse, false, .Little),
            },
        }
    }

    const stdout = std.io.getStdOut().writer();
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
    var prev_pp_state: enum { none, ptr32, special } = .none;
    for (sym_table.values()) |multi_sym, sym_index| {
        const name = sym_table.keys()[sym_index];

        if (multi_sym.section != prev_section) {
            prev_section = multi_sym.section;
            const sh_name = sections.keys()[multi_sym.section];
            try stdout.print("{s}\n", .{sh_name});
        }

        if (multi_sym.allPresent()) {
            switch (prev_pp_state) {
                .none => {},
                .ptr32, .special => {
                    try stdout.writeAll("#endif\n");
                    prev_pp_state = .none;
                },
            }
        } else if (multi_sym.is32Only()) {
            switch (prev_pp_state) {
                .none => {
                    try stdout.writeAll("#ifdef PTR32\n");
                    prev_pp_state = .ptr32;
                },
                .special => {
                    try stdout.writeAll("#endif\n#ifdef PTR32\n");
                    prev_pp_state = .ptr32;
                },
                .ptr32 => {},
            }
        } else {
            switch (prev_pp_state) {
                .none => {},
                .special, .ptr32 => {
                    try stdout.writeAll("#endif\n");
                },
            }
            prev_pp_state = .special;

            var first = true;
            try stdout.writeAll("#if ");

            for (arches) |arch, i| {
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
        } else {
            for (arches) |arch, i| {
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
                } else if (multi_sym.isPtrSize()) {
                    try stdout.print(".size {s}, PTR_SIZE_BYTES\n", .{name});
                } else if (multi_sym.isPtr2Size()) {
                    try stdout.print(".size {s}, PTR2_SIZE_BYTES\n", .{name});
                } else {
                    for (arches) |arch, i| {
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
        .none => {},
        .ptr32, .special => try stdout.writeAll("#endif\n"),
    }
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
    for (shdrs) |shdr, i| {
        const sh_name = try arena.dupe(u8, mem.sliceTo(shstrtab[s(shdr.sh_name)..], 0));
        log.debug("found section: {s}", .{sh_name});
        if (mem.eql(u8, sh_name, ".dynsym")) {
            dynsym_index = @intCast(u16, i);
        }
        const gop = try parse.sections.getOrPut(sh_name);
        section_index_map[i] = @intCast(u16, gop.index);
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
    std.sort.sort(Sym, @alignCast(8, dyn_syms), {}, S.symbolAddrLessThan);

    for (dyn_syms) |sym| {
        const this_section = s(sym.st_shndx);
        const name = try arena.dupe(u8, mem.sliceTo(dynstr[s(sym.st_name)..], 0));
        const ty = @truncate(u4, sym.st_info);
        const binding = @truncate(u4, sym.st_info >> 4);
        const visib = @intToEnum(elf.STV, @truncate(u2, sym.st_other));
        const size = s(sym.st_size);

        if (parse.blacklist.contains(name)) continue;

        if (size == 0) {
            log.warn("{s}: symbol '{s}' has size 0", .{ @tagName(parse.arch), name });
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

fn archIndex(arch: std.Target.Cpu.Arch) u8 {
    return switch (arch) {
        // zig fmt: off
        .riscv64   => 0,
        .mips      => 1,
        .x86      => 2,
        .x86_64    => 3,
        .powerpc   => 4,
        .powerpc64 => 5,
        .aarch64   => 6,
        else       => unreachable,
        // zig fmt: on
    };
}

fn archSetName(arch_set: [arches.len]bool) []const u8 {
    for (arches) |arch, i| {
        if (arch_set[i]) {
            return @tagName(arch);
        }
    }
    return "(none)";
}

fn fatal(comptime format: []const u8, args: anytype) noreturn {
    log.err(format, args);
    std.process.exit(1);
}

const blacklisted_symbols = [_][]const u8{
    "__absvdi2",
    "__absvsi2",
    "__absvti2",
    "__adddf3",
    "__addkf3",
    "__addodi4",
    "__addosi4",
    "__addoti4",
    "__addsf3",
    "__addtf3",
    "__addxf3",
    "__ashldi3",
    "__ashlsi3",
    "__ashlti3",
    "__ashrdi3",
    "__ashrsi3",
    "__ashrti3",
    "__atomic_compare_exchange",
    "__atomic_compare_exchange_1",
    "__atomic_compare_exchange_2",
    "__atomic_compare_exchange_4",
    "__atomic_compare_exchange_8",
    "__atomic_exchange",
    "__atomic_exchange_1",
    "__atomic_exchange_2",
    "__atomic_exchange_4",
    "__atomic_exchange_8",
    "__atomic_fetch_add_1",
    "__atomic_fetch_add_2",
    "__atomic_fetch_add_4",
    "__atomic_fetch_add_8",
    "__atomic_fetch_and_1",
    "__atomic_fetch_and_2",
    "__atomic_fetch_and_4",
    "__atomic_fetch_and_8",
    "__atomic_fetch_nand_1",
    "__atomic_fetch_nand_2",
    "__atomic_fetch_nand_4",
    "__atomic_fetch_nand_8",
    "__atomic_fetch_or_1",
    "__atomic_fetch_or_2",
    "__atomic_fetch_or_4",
    "__atomic_fetch_or_8",
    "__atomic_fetch_sub_1",
    "__atomic_fetch_sub_2",
    "__atomic_fetch_sub_4",
    "__atomic_fetch_sub_8",
    "__atomic_fetch_xor_1",
    "__atomic_fetch_xor_2",
    "__atomic_fetch_xor_4",
    "__atomic_fetch_xor_8",
    "__atomic_load",
    "__atomic_load_1",
    "__atomic_load_2",
    "__atomic_load_4",
    "__atomic_load_8",
    "__atomic_store",
    "__atomic_store_1",
    "__atomic_store_2",
    "__atomic_store_4",
    "__atomic_store_8",
    "__bswapdi2",
    "__bswapsi2",
    "__bswapti2",
    "__ceilh",
    "__ceilx",
    "__clear_cache",
    "__clzdi2",
    "__clzsi2",
    "__clzti2",
    "__cmpdf2",
    "__cmpdi2",
    "__cmpsf2",
    "__cmpsi2",
    "__cmptf2",
    "__cmpti2",
    "__cosh",
    "__cosx",
    "__ctzdi2",
    "__ctzsi2",
    "__ctzti2",
    "__divdf3",
    "__divdi3",
    "__divkf3",
    "__divmoddi4",
    "__divmodsi4",
    "__divmodti4",
    "__divsf3",
    "__divsi3",
    "__divtf3",
    "__divti3",
    "__divxf3",
    "__dlstart",
    "__eqdf2",
    "__eqkf2",
    "__eqsf2",
    "__eqtf2",
    "__eqxf2",
    "__exp2h",
    "__exp2x",
    "__exph",
    "__expx",
    "__extenddfkf2",
    "__extenddftf2",
    "__extenddfxf2",
    "__extendhfsf2",
    "__extendhftf2",
    "__extendhfxf2",
    "__extendsfdf2",
    "__extendsfkf2",
    "__extendsftf2",
    "__extendsfxf2",
    "__extendxftf2",
    "__fabsh",
    "__fabsx",
    "__ffsdi2",
    "__ffssi2",
    "__ffsti2",
    "__fixdfdi",
    "__fixdfsi",
    "__fixdfti",
    "__fixkfdi",
    "__fixkfsi",
    "__fixsfdi",
    "__fixsfsi",
    "__fixsfti",
    "__fixtfdi",
    "__fixtfsi",
    "__fixtfti",
    "__fixunsdfdi",
    "__fixunsdfsi",
    "__fixunsdfti",
    "__fixunskfdi",
    "__fixunskfsi",
    "__fixunssfdi",
    "__fixunssfsi",
    "__fixunssfti",
    "__fixunstfdi",
    "__fixunstfsi",
    "__fixunstfti",
    "__fixunsxfdi",
    "__fixunsxfsi",
    "__fixunsxfti",
    "__fixxfdi",
    "__fixxfsi",
    "__fixxfti",
    "__floatdidf",
    "__floatdikf",
    "__floatdisf",
    "__floatditf",
    "__floatdixf",
    "__floatsidf",
    "__floatsikf",
    "__floatsisf",
    "__floatsitf",
    "__floatsixf",
    "__floattidf",
    "__floattisf",
    "__floattitf",
    "__floattixf",
    "__floatundidf",
    "__floatundikf",
    "__floatundisf",
    "__floatunditf",
    "__floatundixf",
    "__floatunsidf",
    "__floatunsikf",
    "__floatunsisf",
    "__floatunsitf",
    "__floatunsixf",
    "__floatuntidf",
    "__floatuntikf",
    "__floatuntisf",
    "__floatuntitf",
    "__floatuntixf",
    "__floorh",
    "__floorx",
    "__fmah",
    "__fmax",
    "__fmaxh",
    "__fmaxx",
    "__fminh",
    "__fminx",
    "__fmodh",
    "__fmodx",
    "__gedf2",
    "__gekf2",
    "__gesf2",
    "__getf2",
    "__gexf2",
    "__gnu_f2h_ieee",
    "__gnu_h2f_ieee",
    "__gtdf2",
    "__gtkf2",
    "__gtsf2",
    "__gttf2",
    "__gtxf2",
    "__ledf2",
    "__lekf2",
    "__lesf2",
    "__letf2",
    "__lexf2",
    "__log10h",
    "__log10x",
    "__log2h",
    "__log2x",
    "__logh",
    "__logx",
    "__lshrdi3",
    "__lshrsi3",
    "__lshrti3",
    "__ltdf2",
    "__ltkf2",
    "__ltsf2",
    "__lttf2",
    "__ltxf2",
    "__moddi3",
    "__modsi3",
    "__modti3",
    "__muldc3",
    "__muldf3",
    "__muldi3",
    "__mulkf3",
    "__mulodi4",
    "__mulosi4",
    "__muloti4",
    "__mulsc3",
    "__mulsf3",
    "__mulsi3",
    "__multc3",
    "__multf3",
    "__multi3",
    "__mulxc3",
    "__mulxf3",
    "__nedf2",
    "__negdf2",
    "__negdi2",
    "__negsf2",
    "__negsi2",
    "__negti2",
    "__negvdi2",
    "__negvsi2",
    "__negvti2",
    "__nekf2",
    "__nesf2",
    "__netf2",
    "__nexf2",
    "__paritydi2",
    "__paritysi2",
    "__parityti2",
    "__popcountdi2",
    "__popcountsi2",
    "__popcountti2",
    "__powidf2",
    "__powihf2",
    "__powisf2",
    "__powitf2",
    "__powixf2",
    "__roundh",
    "__roundx",
    "__sincosh",
    "__sincosx",
    "__sinh",
    "__sinx",
    "__sqrth",
    "__sqrtx",
    "__subdf3",
    "__subkf3",
    "__subodi4",
    "__subosi4",
    "__suboti4",
    "__subsf3",
    "__subtf3",
    "__subxf3",
    "__tanh",
    "__tanx",
    "__truncdfhf2",
    "__truncdfsf2",
    "__trunch",
    "__trunckfdf2",
    "__trunckfsf2",
    "__truncsfhf2",
    "__trunctfdf2",
    "__trunctfhf2",
    "__trunctfsf2",
    "__trunctfxf2",
    "__truncx",
    "__truncxfdf2",
    "__truncxfhf2",
    "__truncxfsf2",
    "__ucmpdi2",
    "__ucmpsi2",
    "__ucmpti2",
    "__udivdi3",
    "__udivei4",
    "__udivmoddi4",
    "__udivmodsi4",
    "__udivmodti4",
    "__udivsi3",
    "__udivti3",
    "__umoddi3",
    "__umodei4",
    "__umodsi3",
    "__umodti3",
    "__unorddf2",
    "__unordkf2",
    "__unordsf2",
    "__unordtf2",
    "__zig_probe_stack",
    "ceilf128",
    "cosf128",
    "exp2f128",
    "expf128",
    "fabsf128",
    "floorf128",
    "fmaf128",
    "fmaq",
    "fmaxf128",
    "fminf128",
    "fmodf128",
    "log10f128",
    "log2f128",
    "logf128",
    "roundf128",
    "sincosf128",
    "sinf128",
    "sqrtf128",
    "truncf128",
};
