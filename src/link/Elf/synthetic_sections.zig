pub const GotSection = struct {
    entries: std.ArrayListUnmanaged(Entry) = .{},
    needs_rela: bool = false,
    output_symtab_size: Elf.SymtabSize = .{},

    pub const Index = u32;

    const Tag = enum {
        got,
        tlsld,
        tlsgd,
        gottp,
        tlsdesc,
    };

    const Entry = struct {
        tag: Tag,
        symbol_index: Symbol.Index,
        cell_index: Index,

        /// Returns how many indexes in the GOT this entry uses.
        pub inline fn len(entry: Entry) usize {
            return switch (entry.tag) {
                .got, .gottp => 1,
                .tlsld, .tlsgd, .tlsdesc => 2,
            };
        }

        pub fn address(entry: Entry, elf_file: *Elf) u64 {
            const ptr_bytes = @as(u64, elf_file.archPtrWidthBytes());
            const shdr = &elf_file.shdrs.items[elf_file.got_section_index.?];
            return shdr.sh_addr + @as(u64, entry.cell_index) * ptr_bytes;
        }
    };

    pub fn deinit(got: *GotSection, allocator: Allocator) void {
        got.entries.deinit(allocator);
    }

    fn allocateEntry(got: *GotSection, allocator: Allocator) !Index {
        try got.entries.ensureUnusedCapacity(allocator, 1);
        // TODO add free list
        const index = @as(Index, @intCast(got.entries.items.len));
        const entry = got.entries.addOneAssumeCapacity();
        const cell_index: Index = if (index > 0) blk: {
            const last = got.entries.items[index - 1];
            break :blk last.cell_index + @as(Index, @intCast(last.len()));
        } else 0;
        entry.* = .{ .tag = undefined, .symbol_index = undefined, .cell_index = cell_index };
        return index;
    }

    pub fn addGotSymbol(got: *GotSection, sym_index: Symbol.Index, elf_file: *Elf) !Index {
        const index = try got.allocateEntry(elf_file.base.allocator);
        const entry = &got.entries.items[index];
        entry.tag = .got;
        entry.symbol_index = sym_index;
        const symbol = elf_file.symbol(sym_index);
        if (symbol.flags.import or symbol.isIFunc(elf_file) or (elf_file.base.options.pic and !symbol.isAbs(elf_file)))
            got.needs_rela = true;
        if (symbol.extra(elf_file)) |extra| {
            var new_extra = extra;
            new_extra.got = index;
            symbol.setExtra(new_extra, elf_file);
        } else try symbol.addExtra(.{ .got = index }, elf_file);
        return index;
    }

    // pub fn addTlsGdSymbol(got: *GotSection, sym_index: Symbol.Index, elf_file: *Elf) !void {
    //     const index = got.next_index;
    //     const symbol = elf_file.getSymbol(sym_index);
    //     if (symbol.flags.import or elf_file.options.output_mode == .lib) got.needs_rela = true;
    //     if (symbol.getExtra(elf_file)) |extra| {
    //         var new_extra = extra;
    //         new_extra.tlsgd = index;
    //         symbol.setExtra(new_extra, elf_file);
    //     } else try symbol.addExtra(.{ .tlsgd = index }, elf_file);
    //     try got.symbols.append(elf_file.base.allocator, .{ .tlsgd = sym_index });
    //     got.next_index += 2;
    // }

    // pub fn addGotTpSymbol(got: *GotSection, sym_index: Symbol.Index, elf_file: *Elf) !void {
    //     const index = got.next_index;
    //     const symbol = elf_file.getSymbol(sym_index);
    //     if (symbol.flags.import or elf_file.options.output_mode == .lib) got.needs_rela = true;
    //     if (symbol.getExtra(elf_file)) |extra| {
    //         var new_extra = extra;
    //         new_extra.gottp = index;
    //         symbol.setExtra(new_extra, elf_file);
    //     } else try symbol.addExtra(.{ .gottp = index }, elf_file);
    //     try got.symbols.append(elf_file.base.allocator, .{ .gottp = sym_index });
    //     got.next_index += 1;
    // }

    // pub fn addTlsDescSymbol(got: *GotSection, sym_index: Symbol.Index, elf_file: *Elf) !void {
    //     const index = got.next_index;
    //     const symbol = elf_file.getSymbol(sym_index);
    //     got.needs_rela = true;
    //     if (symbol.getExtra(elf_file)) |extra| {
    //         var new_extra = extra;
    //         new_extra.tlsdesc = index;
    //         symbol.setExtra(new_extra, elf_file);
    //     } else try symbol.addExtra(.{ .tlsdesc = index }, elf_file);
    //     try got.symbols.append(elf_file.base.allocator, .{ .tlsdesc = sym_index });
    //     got.next_index += 2;
    // }

    pub fn size(got: GotSection, elf_file: *Elf) usize {
        var s: usize = 0;
        for (got.entries.items) |entry| {
            s += elf_file.archPtrWidthBytes() * entry.len();
        }
        return s;
    }

    pub fn writeEntry(got: *GotSection, elf_file: *Elf, index: Index) !void {
        const entry_size: u16 = elf_file.archPtrWidthBytes();
        // if (got.dirty) {
        //     const needed_size = got.size(elf_file);
        //     try elf_file.growAllocSection(elf_file.got_section_index.?, needed_size);
        //     got.dirty = false;
        // }
        const endian = elf_file.base.options.target.cpu.arch.endian();
        const entry = got.entries.items[index];
        const shdr = &elf_file.shdrs.items[elf_file.got_section_index.?];
        const off = shdr.sh_offset + @as(u64, entry_size) * entry.cell_index;
        const vaddr = shdr.sh_addr + @as(u64, entry_size) * entry.cell_index;
        const value = elf_file.symbol(entry.symbol_index).value;
        switch (entry_size) {
            2 => {
                var buf: [2]u8 = undefined;
                std.mem.writeInt(u16, &buf, @as(u16, @intCast(value)), endian);
                try elf_file.base.file.?.pwriteAll(&buf, off);
            },
            4 => {
                var buf: [4]u8 = undefined;
                std.mem.writeInt(u32, &buf, @as(u32, @intCast(value)), endian);
                try elf_file.base.file.?.pwriteAll(&buf, off);
            },
            8 => {
                var buf: [8]u8 = undefined;
                std.mem.writeInt(u64, &buf, value, endian);
                try elf_file.base.file.?.pwriteAll(&buf, off);

                if (elf_file.base.child_pid) |pid| {
                    switch (builtin.os.tag) {
                        .linux => {
                            var local_vec: [1]std.os.iovec_const = .{.{
                                .iov_base = &buf,
                                .iov_len = buf.len,
                            }};
                            var remote_vec: [1]std.os.iovec_const = .{.{
                                .iov_base = @as([*]u8, @ptrFromInt(@as(usize, @intCast(vaddr)))),
                                .iov_len = buf.len,
                            }};
                            const rc = std.os.linux.process_vm_writev(pid, &local_vec, &remote_vec, 0);
                            switch (std.os.errno(rc)) {
                                .SUCCESS => assert(rc == buf.len),
                                else => |errno| log.warn("process_vm_writev failure: {s}", .{@tagName(errno)}),
                            }
                        },
                        else => return error.HotSwapUnavailableOnHostOperatingSystem,
                    }
                }
            },
            else => unreachable,
        }
    }

    pub fn write(got: GotSection, elf_file: *Elf, writer: anytype) !void {
        const entry_size: u16 = elf_file.archPtrWidthBytes();
        const endian = elf_file.base.options.target.cpu.arch.endian();
        for (got.entries.items) |entry| {
            const value = elf_file.symbol(entry.symbol_index).value;
            switch (entry_size) {
                2 => try writer.writeInt(u16, @intCast(value), endian),
                4 => try writer.writeInt(u32, @intCast(value), endian),
                8 => try writer.writeInt(u64, @intCast(value), endian),
                else => unreachable,
            }
        }
    }

    // pub fn write(got: GotSection, elf_file: *Elf, writer: anytype) !void {
    //     const is_shared = elf_file.options.output_mode == .lib;
    //     const apply_relocs = elf_file.options.apply_dynamic_relocs;

    //     for (got.symbols.items) |sym| {
    //         const symbol = elf_file.getSymbol(sym.getIndex());
    //         switch (sym) {
    //             .got => {
    //                 const value: u64 = blk: {
    //                     const value = symbol.getAddress(.{ .plt = false }, elf_file);
    //                     if (symbol.flags.import) break :blk 0;
    //                     if (symbol.isIFunc(elf_file))
    //                         break :blk if (apply_relocs) value else 0;
    //                     if (elf_file.options.pic and !symbol.isAbs(elf_file))
    //                         break :blk if (apply_relocs) value else 0;
    //                     break :blk value;
    //                 };
    //                 try writer.writeIntLittle(u64, value);
    //             },

    //             .tlsgd => {
    //                 if (symbol.flags.import) {
    //                     try writer.writeIntLittle(u64, 0);
    //                     try writer.writeIntLittle(u64, 0);
    //                 } else {
    //                     try writer.writeIntLittle(u64, if (is_shared) @as(u64, 0) else 1);
    //                     const offset = symbol.getAddress(.{}, elf_file) - elf_file.getDtpAddress();
    //                     try writer.writeIntLittle(u64, offset);
    //                 }
    //             },

    //             .gottp => {
    //                 if (symbol.flags.import) {
    //                     try writer.writeIntLittle(u64, 0);
    //                 } else if (is_shared) {
    //                     const offset = if (apply_relocs)
    //                         symbol.getAddress(.{}, elf_file) - elf_file.getTlsAddress()
    //                     else
    //                         0;
    //                     try writer.writeIntLittle(u64, offset);
    //                 } else {
    //                     const offset = @as(i64, @intCast(symbol.getAddress(.{}, elf_file))) -
    //                         @as(i64, @intCast(elf_file.getTpAddress()));
    //                     try writer.writeIntLittle(u64, @as(u64, @bitCast(offset)));
    //                 }
    //             },

    //             .tlsdesc => {
    //                 try writer.writeIntLittle(u64, 0);
    //                 try writer.writeIntLittle(u64, 0);
    //             },
    //         }
    //     }

    //     if (got.emit_tlsld) {
    //         try writer.writeIntLittle(u64, if (is_shared) @as(u64, 0) else 1);
    //         try writer.writeIntLittle(u64, 0);
    //     }
    // }

    // pub fn addRela(got: GotSection, elf_file: *Elf) !void {
    //     const is_shared = elf_file.options.output_mode == .lib;
    //     try elf_file.rela_dyn.ensureUnusedCapacity(elf_file.base.allocator, got.numRela(elf_file));

    //     for (got.symbols.items) |sym| {
    //         const symbol = elf_file.getSymbol(sym.getIndex());
    //         const extra = symbol.getExtra(elf_file).?;

    //         switch (sym) {
    //             .got => {
    //                 const offset = symbol.gotAddress(elf_file);

    //                 if (symbol.flags.import) {
    //                     elf_file.addRelaDynAssumeCapacity(.{
    //                         .offset = offset,
    //                         .sym = extra.dynamic,
    //                         .type = elf.R_X86_64_GLOB_DAT,
    //                     });
    //                     continue;
    //                 }

    //                 if (symbol.isIFunc(elf_file)) {
    //                     elf_file.addRelaDynAssumeCapacity(.{
    //                         .offset = offset,
    //                         .type = elf.R_X86_64_IRELATIVE,
    //                         .addend = @intCast(symbol.getAddress(.{ .plt = false }, elf_file)),
    //                     });
    //                     continue;
    //                 }

    //                 if (elf_file.options.pic and !symbol.isAbs(elf_file)) {
    //                     elf_file.addRelaDynAssumeCapacity(.{
    //                         .offset = offset,
    //                         .type = elf.R_X86_64_RELATIVE,
    //                         .addend = @intCast(symbol.getAddress(.{ .plt = false }, elf_file)),
    //                     });
    //                 }
    //             },

    //             .tlsgd => {
    //                 const offset = symbol.getTlsGdAddress(elf_file);
    //                 if (symbol.flags.import) {
    //                     elf_file.addRelaDynAssumeCapacity(.{
    //                         .offset = offset,
    //                         .sym = extra.dynamic,
    //                         .type = elf.R_X86_64_DTPMOD64,
    //                     });
    //                     elf_file.addRelaDynAssumeCapacity(.{
    //                         .offset = offset + 8,
    //                         .sym = extra.dynamic,
    //                         .type = elf.R_X86_64_DTPOFF64,
    //                     });
    //                 } else if (is_shared) {
    //                     elf_file.addRelaDynAssumeCapacity(.{
    //                         .offset = offset,
    //                         .sym = extra.dynamic,
    //                         .type = elf.R_X86_64_DTPMOD64,
    //                     });
    //                 }
    //             },

    //             .gottp => {
    //                 const offset = symbol.getGotTpAddress(elf_file);
    //                 if (symbol.flags.import) {
    //                     elf_file.addRelaDynAssumeCapacity(.{
    //                         .offset = offset,
    //                         .sym = extra.dynamic,
    //                         .type = elf.R_X86_64_TPOFF64,
    //                     });
    //                 } else if (is_shared) {
    //                     elf_file.addRelaDynAssumeCapacity(.{
    //                         .offset = offset,
    //                         .type = elf.R_X86_64_TPOFF64,
    //                         .addend = @intCast(symbol.getAddress(.{}, elf_file) - elf_file.getTlsAddress()),
    //                     });
    //                 }
    //             },

    //             .tlsdesc => {
    //                 const offset = symbol.getTlsDescAddress(elf_file);
    //                 elf_file.addRelaDynAssumeCapacity(.{
    //                     .offset = offset,
    //                     .sym = extra.dynamic,
    //                     .type = elf.R_X86_64_TLSDESC,
    //                 });
    //             },
    //         }
    //     }

    //     if (is_shared and got.emit_tlsld) {
    //         const offset = elf_file.getTlsLdAddress();
    //         elf_file.addRelaDynAssumeCapacity(.{
    //             .offset = offset,
    //             .type = elf.R_X86_64_DTPMOD64,
    //         });
    //     }
    // }

    // pub fn numRela(got: GotSection, elf_file: *Elf) usize {
    //     const is_shared = elf_file.options.output_mode == .lib;
    //     var num: usize = 0;
    //     for (got.symbols.items) |sym| {
    //         const symbol = elf_file.symbol(sym.index());
    //         switch (sym) {
    //             .got => if (symbol.flags.import or
    //                 symbol.isIFunc(elf_file) or (elf_file.options.pic and !symbol.isAbs(elf_file)))
    //             {
    //                 num += 1;
    //             },

    //             .tlsgd => if (symbol.flags.import) {
    //                 num += 2;
    //             } else if (is_shared) {
    //                 num += 1;
    //             },

    //             .gottp => if (symbol.flags.import or is_shared) {
    //                 num += 1;
    //             },

    //             .tlsdesc => num += 1,
    //         }
    //     }
    //     if (is_shared and got.emit_tlsld) num += 1;
    //     return num;
    // }

    pub fn updateSymtabSize(got: *GotSection, elf_file: *Elf) void {
        _ = elf_file;
        got.output_symtab_size.nlocals = @as(u32, @intCast(got.entries.items.len));
    }

    pub fn updateStrtab(got: GotSection, elf_file: *Elf) !void {
        const gpa = elf_file.base.allocator;
        for (got.entries.items) |entry| {
            const symbol = elf_file.symbol(entry.symbol_index);
            const name = try std.fmt.allocPrint(gpa, "{s}${s}", .{ symbol.name(elf_file), @tagName(entry.tag) });
            defer gpa.free(name);
            _ = try elf_file.strtab.insert(gpa, name);
        }
    }

    pub fn writeSymtab(got: GotSection, elf_file: *Elf, ctx: anytype) !void {
        const gpa = elf_file.base.allocator;
        for (got.entries.items, ctx.ilocal..) |entry, ilocal| {
            const symbol = elf_file.symbol(entry.symbol_index);
            const name = try std.fmt.allocPrint(gpa, "{s}${s}", .{ symbol.name(elf_file), @tagName(entry.tag) });
            defer gpa.free(name);
            const st_name = try elf_file.strtab.insert(gpa, name);
            const st_value = switch (entry.tag) {
                .got => symbol.gotAddress(elf_file),
                else => unreachable,
            };
            const st_size: u64 = entry.len() * elf_file.archPtrWidthBytes();
            ctx.symtab[ilocal] = .{
                .st_name = st_name,
                .st_info = elf.STT_OBJECT,
                .st_other = 0,
                .st_shndx = elf_file.got_section_index.?,
                .st_value = st_value,
                .st_size = st_size,
            };
        }
    }

    const FormatCtx = struct {
        got: GotSection,
        elf_file: *Elf,
    };

    pub fn fmt(got: GotSection, elf_file: *Elf) std.fmt.Formatter(format2) {
        return .{ .data = .{ .got = got, .elf_file = elf_file } };
    }

    pub fn format2(
        ctx: FormatCtx,
        comptime unused_fmt_string: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = options;
        _ = unused_fmt_string;
        try writer.writeAll("GOT\n");
        for (ctx.got.entries.items) |entry| {
            const symbol = ctx.elf_file.symbol(entry.symbol_index);
            try writer.print("  {d}@0x{x} => {d}@0x{x} ({s})\n", .{
                entry.cell_index,
                entry.address(ctx.elf_file),
                entry.symbol_index,
                symbol.address(.{}, ctx.elf_file),
                symbol.name(ctx.elf_file),
            });
        }
    }
};

const assert = std.debug.assert;
const builtin = @import("builtin");
const elf = std.elf;
const log = std.log.scoped(.link);
const std = @import("std");

const Allocator = std.mem.Allocator;
const Elf = @import("../Elf.zig");
const Symbol = @import("Symbol.zig");
