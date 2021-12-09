//! Example usage:
//! ./gen_stubs /path/to/musl/build-all
//!
//! The directory 'build-all' is expected to contain these subdirectories:
//! arm  i386  mips  mips64  powerpc  powerpc64  riscv64  x86_64
//!
//! ...each with 'lib/libc.so' inside of them.

// TODO: pick the best index to put them into instead of at the end
//       - e.g. find a common previous symbol and put it after that one
//       - they definitely need to go into the correct section
// TODO: emit MultiSyms to use the preprocessor

const std = @import("std");
const builtin = std.builtin;
const mem = std.mem;
const log = std.log;
const elf = std.elf;
const native_endian = @import("builtin").target.cpu.arch.endian();

const arches: [6]std.Target.Cpu.Arch = blk: {
    var result: [6]std.Target.Cpu.Arch = undefined;
    for (.{ .riscv64, .mips, .i386, .x86_64, .powerpc, .powerpc64 }) |arch| {
        result[archIndex(arch)] = arch;
    }
    break :blk result;
};

const MultiSym = struct {
    size: [arches.len]u64,
    present: [arches.len]bool,
    section: u16,
    ty: u4,
    binding: u4,
    visib: elf.STV,
};

const Parse = struct {
    arena: mem.Allocator,
    sym_table: *std.StringArrayHashMap(MultiSym),
    sections: *std.StringArrayHashMap(void),
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

        var sym_table = std.StringArrayHashMap(MultiSym).init(arena);
        var sections = std.StringArrayHashMap(void).init(arena);

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
    _ = stdout;

    //var prev_section: u16 = 0;
    //for (all_syms) |sym| {
    //    const this_section = s(sym.st_shndx);
    //    if (this_section != prev_section) {
    //        prev_section = this_section;
    //        const sh_name = mem.sliceTo(shstrtab[s(shdrs[this_section].sh_name)..], 0);
    //        try stdout.print("{s}\n", .{sh_name});
    //    }

    //    switch (binding) {
    //        elf.STB_GLOBAL => {
    //            try stdout.print(".globl {s}\n", .{name});
    //        },
    //        elf.STB_WEAK => {
    //            try stdout.print(".weak {s}\n", .{name});
    //        },
    //        else => unreachable,
    //    }

    //    switch (ty) {
    //        elf.STT_NOTYPE => {},
    //        elf.STT_FUNC => {
    //            try stdout.print(".type {s}, %function;\n", .{name});
    //            // omitting the size is OK for functions
    //        },
    //        elf.STT_OBJECT => {
    //            try stdout.print(".type {s}, %object;\n", .{name});
    //            if (size != 0) {
    //                try stdout.print(".size {s}, {d}\n", .{ name, size });
    //            }
    //        },
    //        else => unreachable,
    //    }

    //    switch (visib) {
    //        .DEFAULT => {},
    //        .PROTECTED => try stdout.print(".protected {s}\n", .{name}),
    //        .INTERNAL, .HIDDEN => unreachable,
    //    }

    //    try stdout.print("{s}:\n", .{name});
    //}
}

fn parseElf(parse: Parse, comptime is_64: bool, comptime endian: builtin.Endian) !void {
    const arena = parse.arena;
    const elf_bytes = parse.elf_bytes;
    const header = parse.header;
    const Sym = if (is_64) elf.Elf64_Sym else elf.Elf32_Sym;
    const S = struct {
        fn endianSwap(x: anytype) @TypeOf(x) {
            if (endian != native_endian) {
                return @byteSwap(@TypeOf(x), x);
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
    std.sort.sort(Sym, dyn_syms, {}, S.symbolAddrLessThan);

    for (dyn_syms) |sym| {
        const this_section = s(sym.st_shndx);
        const name = try arena.dupe(u8, mem.sliceTo(dynstr[s(sym.st_name)..], 0));
        const ty = @truncate(u4, sym.st_info);
        const binding = @truncate(u4, sym.st_info >> 4);
        const visib = @intToEnum(elf.STV, @truncate(u2, sym.st_other));
        const size = s(sym.st_size);

        if (size == 0) {
            log.warn("{s}: symbol '{s}' has size 0", .{ @tagName(parse.arch), name });
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
                    name,                               @tagName(parse.arch),                         sh_name,
                    archSetName(gop.value_ptr.present), parse.sections.keys()[gop.value_ptr.section],
                });
            }
            if (gop.value_ptr.ty != ty) {
                fatal("symbol '{s}' in arch {s} has type {d} but in arch {s} has type {d}", .{
                    name,                               @tagName(parse.arch), ty,
                    archSetName(gop.value_ptr.present), gop.value_ptr.ty,
                });
            }
            if (gop.value_ptr.binding != binding) {
                fatal("symbol '{s}' in arch {s} has binding {d} but in arch {s} has binding {d}", .{
                    name,                               @tagName(parse.arch),  binding,
                    archSetName(gop.value_ptr.present), gop.value_ptr.binding,
                });
            }
            if (gop.value_ptr.visib != visib) {
                fatal("symbol '{s}' in arch {s} has visib {s} but in arch {s} has visib {s}", .{
                    name,                               @tagName(parse.arch),          @tagName(visib),
                    archSetName(gop.value_ptr.present), @tagName(gop.value_ptr.visib),
                });
            }
        } else {
            gop.value_ptr.* = .{
                .present = [1]bool{false} ** arches.len,
                .section = section_index_map[this_section],
                .ty = ty,
                .binding = binding,
                .visib = visib,
                .size = [1]u64{0} ** arches.len,
            };
        }
        gop.value_ptr.present[archIndex(parse.arch)] = true;
        gop.value_ptr.size[archIndex(parse.arch)] = size;
    }
}

fn archIndex(arch: std.Target.Cpu.Arch) u8 {
    return switch (arch) {
        // zig fmt: off
        .riscv64   => 0,
        .mips      => 1,
        .i386      => 2,
        .x86_64    => 3,
        .powerpc   => 4,
        .powerpc64 => 5,
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
