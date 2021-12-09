//! Example usage:
//! ./gen_stubs /path/to/musl/build-all
//!
//! The directory 'build-all' is expected to contain these subdirectories:
//! arm  i386  mips  mips64  powerpc  powerpc64  riscv64  x86_64
//!
//! ...each with 'lib/libc.so' inside of them.

const std = @import("std");
const builtin = std.builtin;
const mem = std.mem;
const elf = std.elf;
const native_endian = @import("builtin").target.cpu.arch.endian();

pub fn main() !void {
    var arena_instance = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();

    const args = try std.process.argsAlloc(arena);
    const libc_so_path = args[1];

    // Read the ELF header.
    const elf_bytes = try std.fs.cwd().readFileAllocOptions(
        arena,
        libc_so_path,
        100 * 1024 * 1024,
        1 * 1024 * 1024,
        @alignOf(elf.Elf64_Ehdr),
        null,
    );
    const header = try elf.Header.parse(elf_bytes[0..@sizeOf(elf.Elf64_Ehdr)]);

    switch (header.is_64) {
        true => switch (header.endian) {
            .Big => return finishMain(arena, elf_bytes, header, true, .Big),
            .Little => return finishMain(arena, elf_bytes, header, true, .Little),
        },
        false => switch (header.endian) {
            .Big => return finishMain(arena, elf_bytes, header, false, .Big),
            .Little => return finishMain(arena, elf_bytes, header, false, .Little),
        },
    }
}

fn finishMain(
    arena: mem.Allocator,
    elf_bytes: []align(@alignOf(elf.Elf64_Ehdr)) u8,
    header: elf.Header,
    comptime is_64: bool,
    comptime endian: builtin.Endian,
) !void {
    _ = arena;
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
    std.log.debug("shstrtab is at offset {d}", .{shstrtab_offset});
    const shstrtab = elf_bytes[shstrtab_offset..];

    // Find the offset of the dynamic symbol table.
    const dynsym_index = for (shdrs) |shdr, i| {
        const sh_name = mem.sliceTo(shstrtab[s(shdr.sh_name)..], 0);
        std.log.debug("found section: {s}", .{sh_name});
        if (mem.eql(u8, sh_name, ".dynsym")) break @intCast(u16, i);
    } else @panic("did not find the .dynsym section");

    std.log.debug("found .dynsym section at index {d}", .{dynsym_index});

    // Read the dynamic symbols into a list.
    const dyn_syms_off = s(shdrs[dynsym_index].sh_offset);
    const dyn_syms_size = s(shdrs[dynsym_index].sh_size);
    const dyn_syms = mem.bytesAsSlice(Sym, elf_bytes[dyn_syms_off..][0..dyn_syms_size]);

    const dynstr_offset = s(shdrs[s(shdrs[dynsym_index].sh_link)].sh_offset);
    const dynstr = elf_bytes[dynstr_offset..];

    // Sort the list by address, ascending.
    std.sort.sort(Sym, dyn_syms, {}, S.symbolAddrLessThan);

    const stdout = std.io.getStdOut().writer();

    var prev_section: u16 = 0;
    for (dyn_syms) |sym| {
        const name = mem.sliceTo(dynstr[s(sym.st_name)..], 0);
        const ty = @truncate(u4, sym.st_info);
        const binding = @truncate(u4, sym.st_info >> 4);
        const visib = @intToEnum(elf.STV, @truncate(u2, sym.st_other));
        const size = s(sym.st_size);

        if (size == 0) {
            std.log.warn("symbol '{s}' has size 0", .{name});
            continue;
        }

        switch (binding) {
            elf.STB_GLOBAL, elf.STB_WEAK => {},
            else => {
                std.log.debug("skipping '{s}' due to it having binding '{d}'", .{ name, binding });
                continue;
            },
        }

        switch (ty) {
            elf.STT_NOTYPE, elf.STT_FUNC, elf.STT_OBJECT => {},
            else => {
                std.log.debug("skipping '{s}' due to it having type '{d}'", .{ name, ty });
                continue;
            },
        }

        switch (visib) {
            .DEFAULT, .PROTECTED => {},
            .INTERNAL, .HIDDEN => {
                std.log.debug("skipping '{s}' due to it having visibility '{s}'", .{
                    name, @tagName(visib),
                });
                continue;
            },
        }

        const this_section = s(sym.st_shndx);
        if (this_section != prev_section) {
            prev_section = this_section;
            const sh_name = mem.sliceTo(shstrtab[s(shdrs[this_section].sh_name)..], 0);
            try stdout.print("{s}\n", .{sh_name});
        }

        switch (binding) {
            elf.STB_GLOBAL => {
                try stdout.print(".globl {s}\n", .{name});
            },
            elf.STB_WEAK => {
                try stdout.print(".weak {s}\n", .{name});
            },
            else => unreachable,
        }

        switch (ty) {
            elf.STT_NOTYPE => {},
            elf.STT_FUNC => {
                try stdout.print(".type {s}, %function;\n", .{name});
                // omitting the size is OK for functions
            },
            elf.STT_OBJECT => {
                try stdout.print(".type {s}, %object;\n", .{name});
                if (size != 0) {
                    try stdout.print(".size {s}, {d}\n", .{ name, size });
                }
            },
            else => unreachable,
        }

        switch (visib) {
            .DEFAULT => {},
            .PROTECTED => try stdout.print(".protected {s}\n", .{name}),
            .INTERNAL, .HIDDEN => unreachable,
        }

        try stdout.print("{s}:\n", .{name});
    }
}
