const std = @import("std");
const mem = std.mem;
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const ir = @import("ir.zig");
const fs = std.fs;
const elf = std.elf;
const codegen = @import("codegen.zig");

const default_entry_addr = 0x8000000;

pub const ErrorMsg = struct {
    byte_offset: usize,
    msg: []const u8,
};

pub const Result = struct {
    errors: []ErrorMsg,

    pub fn deinit(self: *Result, allocator: *mem.Allocator) void {
        for (self.errors) |err| {
            allocator.free(err.msg);
        }
        allocator.free(self.errors);
        self.* = undefined;
    }
};

/// Attempts incremental linking, if the file already exists.
/// If incremental linking fails, falls back to truncating the file and rewriting it.
/// A malicious file is detected as incremental link failure and does not cause Illegal Behavior.
/// This operation is not atomic.
pub fn updateFilePath(
    allocator: *Allocator,
    module: ir.Module,
    dir: fs.Dir,
    sub_path: []const u8,
) !Result {
    const file = try dir.createFile(sub_path, .{ .truncate = false, .read = true, .mode = determineMode(module) });
    defer file.close();

    return updateFile(allocator, module, file);
}

/// Atomically overwrites the old file, if present.
pub fn writeFilePath(
    allocator: *Allocator,
    module: ir.Module,
    dir: fs.Dir,
    sub_path: []const u8,
) !Result {
    const af = try dir.atomicFile(sub_path, .{ .mode = determineMode(module) });
    defer af.deinit();

    const result = try writeFile(allocator, module, af.file);
    try af.finish();
    return result;
}

/// Attempts incremental linking, if the file already exists.
/// If incremental linking fails, falls back to truncating the file and rewriting it.
/// Returns an error if `file` is not already open with +read +write +seek abilities.
/// A malicious file is detected as incremental link failure and does not cause Illegal Behavior.
/// This operation is not atomic.
pub fn updateFile(allocator: *Allocator, module: ir.Module, file: fs.File) !Result {
    return updateFileInner(allocator, module, file) catch |err| switch (err) {
        error.IncrFailed => {
            return writeFile(allocator, module, file);
        },
        else => |e| return e,
    };
}

const Update = struct {
    file: fs.File,
    module: *const ir.Module,

    /// Stored in native-endian format, depending on target endianness needs to be bswapped on read/write.
    /// Same order as in the file.
    sections: std.ArrayList(elf.Elf64_Shdr),
    shdr_table_offset: ?u64,

    /// Stored in native-endian format, depending on target endianness needs to be bswapped on read/write.
    /// Same order as in the file.
    program_headers: std.ArrayList(elf.Elf64_Phdr),
    phdr_table_offset: ?u64,
    /// The index into the program headers of a PT_LOAD program header with Read and Execute flags
    phdr_load_re_index: ?u16,
    entry_addr: ?u64,

    shstrtab: std.ArrayList(u8),
    shstrtab_index: ?u16,

    text_section_index: ?u16,
    symtab_section_index: ?u16,

    /// The same order as in the file
    symbols: std.ArrayList(elf.Elf64_Sym),

    errors: std.ArrayList(ErrorMsg),

    fn deinit(self: *Update) void {
        self.sections.deinit();
        self.program_headers.deinit();
        self.shstrtab.deinit();
        self.symbols.deinit();
        self.errors.deinit();
    }

    // `expand_num / expand_den` is the factor of padding when allocation
    const alloc_num = 4;
    const alloc_den = 3;

    /// Returns end pos of collision, if any.
    fn detectAllocCollision(self: *Update, start: u64, size: u64) ?u64 {
        const small_ptr = self.module.target.cpu.arch.ptrBitWidth() == 32;
        const ehdr_size: u64 = if (small_ptr) @sizeOf(elf.Elf32_Ehdr) else @sizeOf(elf.Elf64_Ehdr);
        if (start < ehdr_size)
            return ehdr_size;

        const end = start + satMul(size, alloc_num) / alloc_den;

        if (self.shdr_table_offset) |off| {
            const shdr_size: u64 = if (small_ptr) @sizeOf(elf.Elf32_Shdr) else @sizeOf(elf.Elf64_Shdr);
            const tight_size = self.sections.items.len * shdr_size;
            const increased_size = satMul(tight_size, alloc_num) / alloc_den;
            const test_end = off + increased_size;
            if (end > off and start < test_end) {
                return test_end;
            }
        }

        if (self.phdr_table_offset) |off| {
            const phdr_size: u64 = if (small_ptr) @sizeOf(elf.Elf32_Phdr) else @sizeOf(elf.Elf64_Phdr);
            const tight_size = self.sections.items.len * phdr_size;
            const increased_size = satMul(tight_size, alloc_num) / alloc_den;
            const test_end = off + increased_size;
            if (end > off and start < test_end) {
                return test_end;
            }
        }

        for (self.sections.items) |section| {
            const increased_size = satMul(section.sh_size, alloc_num) / alloc_den;
            const test_end = section.sh_offset + increased_size;
            if (end > section.sh_offset and start < test_end) {
                return test_end;
            }
        }
        for (self.program_headers.items) |program_header| {
            const increased_size = satMul(program_header.p_filesz, alloc_num) / alloc_den;
            const test_end = program_header.p_offset + increased_size;
            if (end > program_header.p_offset and start < test_end) {
                return test_end;
            }
        }
        return null;
    }

    fn allocatedSize(self: *Update, start: u64) u64 {
        var min_pos: u64 = std.math.maxInt(u64);
        if (self.shdr_table_offset) |off| {
            if (off > start and off < min_pos) min_pos = off;
        }
        if (self.phdr_table_offset) |off| {
            if (off > start and off < min_pos) min_pos = off;
        }
        for (self.sections.items) |section| {
            if (section.sh_offset <= start) continue;
            if (section.sh_offset < min_pos) min_pos = section.sh_offset;
        }
        for (self.program_headers.items) |program_header| {
            if (program_header.p_offset <= start) continue;
            if (program_header.p_offset < min_pos) min_pos = program_header.p_offset;
        }
        return min_pos - start;
    }

    fn findFreeSpace(self: *Update, object_size: u64, min_alignment: u16) u64 {
        var start: u64 = 0;
        while (self.detectAllocCollision(start, object_size)) |item_end| {
            start = mem.alignForwardGeneric(u64, item_end, min_alignment);
        }
        return start;
    }

    fn makeString(self: *Update, bytes: []const u8) !u32 {
        const result = self.shstrtab.items.len;
        try self.shstrtab.appendSlice(bytes);
        try self.shstrtab.append(0);
        return @intCast(u32, result);
    }

    fn perform(self: *Update) !void {
        const ptr_width: enum { p32, p64 } = switch (self.module.target.cpu.arch.ptrBitWidth()) {
            32 => .p32,
            64 => .p64,
            else => return error.UnsupportedArchitecture,
        };
        const small_ptr = switch (ptr_width) {
            .p32 => true,
            .p64 => false,
        };
        // This means the entire read-only executable program code needs to be rewritten.
        var phdr_load_re_dirty = false;
        var phdr_table_dirty = false;
        var shdr_table_dirty = false;
        var shstrtab_dirty = false;
        var symtab_dirty = false;

        if (self.phdr_load_re_index == null) {
            self.phdr_load_re_index = @intCast(u16, self.program_headers.items.len);
            const file_size = 256 * 1024;
            const p_align = 0x1000;
            const off = self.findFreeSpace(file_size, p_align);
            //std.debug.warn("found PT_LOAD free space 0x{x} to 0x{x}\n", .{ off, off + file_size });
            try self.program_headers.append(.{
                .p_type = elf.PT_LOAD,
                .p_offset = off,
                .p_filesz = file_size,
                .p_vaddr = default_entry_addr,
                .p_paddr = default_entry_addr,
                .p_memsz = 0,
                .p_align = p_align,
                .p_flags = elf.PF_X | elf.PF_R,
            });
            self.entry_addr = null;
            phdr_load_re_dirty = true;
            phdr_table_dirty = true;
        }
        if (self.sections.items.len == 0) {
            // There must always be a null section in index 0
            try self.sections.append(.{
                .sh_name = 0,
                .sh_type = elf.SHT_NULL,
                .sh_flags = 0,
                .sh_addr = 0,
                .sh_offset = 0,
                .sh_size = 0,
                .sh_link = 0,
                .sh_info = 0,
                .sh_addralign = 0,
                .sh_entsize = 0,
            });
            shdr_table_dirty = true;
        }
        if (self.shstrtab_index == null) {
            self.shstrtab_index = @intCast(u16, self.sections.items.len);
            assert(self.shstrtab.items.len == 0);
            try self.shstrtab.append(0); // need a 0 at position 0
            const off = self.findFreeSpace(self.shstrtab.items.len, 1);
            //std.debug.warn("found shstrtab free space 0x{x} to 0x{x}\n", .{ off, off + self.shstrtab.items.len });
            try self.sections.append(.{
                .sh_name = try self.makeString(".shstrtab"),
                .sh_type = elf.SHT_STRTAB,
                .sh_flags = 0,
                .sh_addr = 0,
                .sh_offset = off,
                .sh_size = self.shstrtab.items.len,
                .sh_link = 0,
                .sh_info = 0,
                .sh_addralign = 1,
                .sh_entsize = 0,
            });
            shstrtab_dirty = true;
            shdr_table_dirty = true;
        }
        if (self.text_section_index == null) {
            self.text_section_index = @intCast(u16, self.sections.items.len);
            const phdr = &self.program_headers.items[self.phdr_load_re_index.?];

            try self.sections.append(.{
                .sh_name = try self.makeString(".text"),
                .sh_type = elf.SHT_PROGBITS,
                .sh_flags = elf.SHF_ALLOC | elf.SHF_EXECINSTR,
                .sh_addr = phdr.p_vaddr,
                .sh_offset = phdr.p_offset,
                .sh_size = phdr.p_filesz,
                .sh_link = 0,
                .sh_info = 0,
                .sh_addralign = phdr.p_align,
                .sh_entsize = 0,
            });
            shdr_table_dirty = true;
        }
        if (self.symtab_section_index == null) {
            self.symtab_section_index = @intCast(u16, self.sections.items.len);
            const min_align: u16 = if (small_ptr) @alignOf(elf.Elf32_Sym) else @alignOf(elf.Elf64_Sym);
            const each_size: u64 = if (small_ptr) @sizeOf(elf.Elf32_Sym) else @sizeOf(elf.Elf64_Sym);
            const file_size = self.module.exports.len * each_size;
            const off = self.findFreeSpace(file_size, min_align);
            //std.debug.warn("found symtab free space 0x{x} to 0x{x}\n", .{ off, off + file_size });

            try self.sections.append(.{
                .sh_name = try self.makeString(".symtab"),
                .sh_type = elf.SHT_SYMTAB,
                .sh_flags = 0,
                .sh_addr = 0,
                .sh_offset = off,
                .sh_size = file_size,
                // The section header index of the associated string table.
                .sh_link = self.shstrtab_index.?,
                .sh_info = @intCast(u32, self.module.exports.len),
                .sh_addralign = min_align,
                .sh_entsize = each_size,
            });
            symtab_dirty = true;
            shdr_table_dirty = true;
        }
        const shsize: u64 = switch (ptr_width) {
            .p32 => @sizeOf(elf.Elf32_Shdr),
            .p64 => @sizeOf(elf.Elf64_Shdr),
        };
        const shalign: u16 = switch (ptr_width) {
            .p32 => @alignOf(elf.Elf32_Shdr),
            .p64 => @alignOf(elf.Elf64_Shdr),
        };
        if (self.shdr_table_offset == null) {
            self.shdr_table_offset = self.findFreeSpace(self.sections.items.len * shsize, shalign);
            shdr_table_dirty = true;
        }
        const phsize: u64 = switch (ptr_width) {
            .p32 => @sizeOf(elf.Elf32_Phdr),
            .p64 => @sizeOf(elf.Elf64_Phdr),
        };
        const phalign: u16 = switch (ptr_width) {
            .p32 => @alignOf(elf.Elf32_Phdr),
            .p64 => @alignOf(elf.Elf64_Phdr),
        };
        if (self.phdr_table_offset == null) {
            self.phdr_table_offset = self.findFreeSpace(self.program_headers.items.len * phsize, phalign);
            phdr_table_dirty = true;
        }
        const foreign_endian = self.module.target.cpu.arch.endian() != std.Target.current.cpu.arch.endian();

        try self.writeCodeAndSymbols(phdr_table_dirty, shdr_table_dirty);

        if (phdr_table_dirty) {
            const allocated_size = self.allocatedSize(self.phdr_table_offset.?);
            const needed_size = self.program_headers.items.len * phsize;

            if (needed_size > allocated_size) {
                self.phdr_table_offset = null; // free the space
                self.phdr_table_offset = self.findFreeSpace(needed_size, phalign);
            }

            const allocator = self.program_headers.allocator;
            switch (ptr_width) {
                .p32 => {
                    const buf = try allocator.alloc(elf.Elf32_Phdr, self.program_headers.items.len);
                    defer allocator.free(buf);

                    for (buf) |*phdr, i| {
                        phdr.* = progHeaderTo32(self.program_headers.items[i]);
                        if (foreign_endian) {
                            bswapAllFields(elf.Elf32_Phdr, phdr);
                        }
                    }
                    try self.file.pwriteAll(mem.sliceAsBytes(buf), self.phdr_table_offset.?);
                },
                .p64 => {
                    const buf = try allocator.alloc(elf.Elf64_Phdr, self.program_headers.items.len);
                    defer allocator.free(buf);

                    for (buf) |*phdr, i| {
                        phdr.* = self.program_headers.items[i];
                        if (foreign_endian) {
                            bswapAllFields(elf.Elf64_Phdr, phdr);
                        }
                    }
                    try self.file.pwriteAll(mem.sliceAsBytes(buf), self.phdr_table_offset.?);
                },
            }
        }

        {
            const shstrtab_sect = &self.sections.items[self.shstrtab_index.?];
            if (shstrtab_dirty or self.shstrtab.items.len != shstrtab_sect.sh_size) {
                const allocated_size = self.allocatedSize(shstrtab_sect.sh_offset);
                const needed_size = self.shstrtab.items.len;

                if (needed_size > allocated_size) {
                    shstrtab_sect.sh_size = 0; // free the space
                    shstrtab_sect.sh_offset = self.findFreeSpace(needed_size, 1);
                }
                shstrtab_sect.sh_size = needed_size;
                //std.debug.warn("shstrtab start=0x{x} end=0x{x}\n", .{ shstrtab_sect.sh_offset, shstrtab_sect.sh_offset + needed_size });

                try self.file.pwriteAll(self.shstrtab.items, shstrtab_sect.sh_offset);
                if (!shdr_table_dirty) {
                    // Then it won't get written with the others and we need to do it.
                    try self.writeSectHeader(self.shstrtab_index.?);
                }
            }
        }
        if (shdr_table_dirty) {
            const allocated_size = self.allocatedSize(self.shdr_table_offset.?);
            const needed_size = self.sections.items.len * phsize;

            if (needed_size > allocated_size) {
                self.shdr_table_offset = null; // free the space
                self.shdr_table_offset = self.findFreeSpace(needed_size, phalign);
            }

            const allocator = self.sections.allocator;
            switch (ptr_width) {
                .p32 => {
                    const buf = try allocator.alloc(elf.Elf32_Shdr, self.sections.items.len);
                    defer allocator.free(buf);

                    for (buf) |*shdr, i| {
                        shdr.* = sectHeaderTo32(self.sections.items[i]);
                        if (foreign_endian) {
                            bswapAllFields(elf.Elf32_Shdr, shdr);
                        }
                    }
                    try self.file.pwriteAll(mem.sliceAsBytes(buf), self.shdr_table_offset.?);
                },
                .p64 => {
                    const buf = try allocator.alloc(elf.Elf64_Shdr, self.sections.items.len);
                    defer allocator.free(buf);

                    for (buf) |*shdr, i| {
                        shdr.* = self.sections.items[i];
                        //std.debug.warn("writing section {}\n", .{shdr.*});
                        if (foreign_endian) {
                            bswapAllFields(elf.Elf64_Shdr, shdr);
                        }
                    }
                    try self.file.pwriteAll(mem.sliceAsBytes(buf), self.shdr_table_offset.?);
                },
            }
        }
        if (self.entry_addr == null and self.module.output_mode == .Exe) {
            const msg = try std.fmt.allocPrint(self.errors.allocator, "no entry point found", .{});
            errdefer self.errors.allocator.free(msg);
            try self.errors.append(.{
                .byte_offset = 0,
                .msg = msg,
            });
        } else {
            try self.writeElfHeader();
        }
        // TODO find end pos and truncate
    }

    fn writeElfHeader(self: *Update) !void {
        var hdr_buf: [@sizeOf(elf.Elf64_Ehdr)]u8 = undefined;

        var index: usize = 0;
        hdr_buf[0..4].* = "\x7fELF".*;
        index += 4;

        const ptr_width: enum { p32, p64 } = switch (self.module.target.cpu.arch.ptrBitWidth()) {
            32 => .p32,
            64 => .p64,
            else => return error.UnsupportedArchitecture,
        };
        hdr_buf[index] = switch (ptr_width) {
            .p32 => elf.ELFCLASS32,
            .p64 => elf.ELFCLASS64,
        };
        index += 1;

        const endian = self.module.target.cpu.arch.endian();
        hdr_buf[index] = switch (endian) {
            .Little => elf.ELFDATA2LSB,
            .Big => elf.ELFDATA2MSB,
        };
        index += 1;

        hdr_buf[index] = 1; // ELF version
        index += 1;

        // OS ABI, often set to 0 regardless of target platform
        // ABI Version, possibly used by glibc but not by static executables
        // padding
        mem.set(u8, hdr_buf[index..][0..9], 0);
        index += 9;

        assert(index == 16);

        const elf_type = switch (self.module.output_mode) {
            .Exe => elf.ET.EXEC,
            .Obj => elf.ET.REL,
            .Lib => switch (self.module.link_mode) {
                .Static => elf.ET.REL,
                .Dynamic => elf.ET.DYN,
            },
        };
        mem.writeInt(u16, hdr_buf[index..][0..2], @enumToInt(elf_type), endian);
        index += 2;

        const machine = self.module.target.cpu.arch.toElfMachine();
        mem.writeInt(u16, hdr_buf[index..][0..2], @enumToInt(machine), endian);
        index += 2;

        // ELF Version, again
        mem.writeInt(u32, hdr_buf[index..][0..4], 1, endian);
        index += 4;

        const e_entry = if (elf_type == .REL) 0 else self.entry_addr.?;

        switch (ptr_width) {
            .p32 => {
                mem.writeInt(u32, hdr_buf[index..][0..4], @intCast(u32, e_entry), endian);
                index += 4;

                // e_phoff
                mem.writeInt(u32, hdr_buf[index..][0..4], @intCast(u32, self.phdr_table_offset.?), endian);
                index += 4;

                // e_shoff
                mem.writeInt(u32, hdr_buf[index..][0..4], @intCast(u32, self.shdr_table_offset.?), endian);
                index += 4;
            },
            .p64 => {
                // e_entry
                mem.writeInt(u64, hdr_buf[index..][0..8], e_entry, endian);
                index += 8;

                // e_phoff
                mem.writeInt(u64, hdr_buf[index..][0..8], self.phdr_table_offset.?, endian);
                index += 8;

                // e_shoff
                mem.writeInt(u64, hdr_buf[index..][0..8], self.shdr_table_offset.?, endian);
                index += 8;
            },
        }

        const e_flags = 0;
        mem.writeInt(u32, hdr_buf[index..][0..4], e_flags, endian);
        index += 4;

        const e_ehsize: u16 = switch (ptr_width) {
            .p32 => @sizeOf(elf.Elf32_Ehdr),
            .p64 => @sizeOf(elf.Elf64_Ehdr),
        };
        mem.writeInt(u16, hdr_buf[index..][0..2], e_ehsize, endian);
        index += 2;

        const e_phentsize: u16 = switch (ptr_width) {
            .p32 => @sizeOf(elf.Elf32_Phdr),
            .p64 => @sizeOf(elf.Elf64_Phdr),
        };
        mem.writeInt(u16, hdr_buf[index..][0..2], e_phentsize, endian);
        index += 2;

        const e_phnum = @intCast(u16, self.program_headers.items.len);
        mem.writeInt(u16, hdr_buf[index..][0..2], e_phnum, endian);
        index += 2;

        const e_shentsize: u16 = switch (ptr_width) {
            .p32 => @sizeOf(elf.Elf32_Shdr),
            .p64 => @sizeOf(elf.Elf64_Shdr),
        };
        mem.writeInt(u16, hdr_buf[index..][0..2], e_shentsize, endian);
        index += 2;

        const e_shnum = @intCast(u16, self.sections.items.len);
        mem.writeInt(u16, hdr_buf[index..][0..2], e_shnum, endian);
        index += 2;

        mem.writeInt(u16, hdr_buf[index..][0..2], self.shstrtab_index.?, endian);
        index += 2;

        assert(index == e_ehsize);

        try self.file.pwriteAll(hdr_buf[0..index], 0);
    }

    fn writeCodeAndSymbols(self: *Update, phdr_table_dirty: bool, shdr_table_dirty: bool) !void {
        // index 0 is always a null symbol
        try self.symbols.resize(1);
        self.symbols.items[0] = .{
            .st_name = 0,
            .st_info = 0,
            .st_other = 0,
            .st_shndx = 0,
            .st_value = 0,
            .st_size = 0,
        };

        const phdr = &self.program_headers.items[self.phdr_load_re_index.?];
        var vaddr: u64 = phdr.p_vaddr;
        var file_off: u64 = phdr.p_offset;

        var code = std.ArrayList(u8).init(self.sections.allocator);
        defer code.deinit();

        for (self.module.exports) |exp| {
            code.shrink(0);
            var symbol = try codegen.generateSymbol(exp.typed_value, self.module.*, &code);
            defer symbol.deinit(code.allocator);
            if (symbol.errors.len != 0) {
                for (symbol.errors) |err| {
                    const msg = try mem.dupe(self.errors.allocator, u8, err.msg);
                    errdefer self.errors.allocator.free(msg);
                    try self.errors.append(.{
                        .byte_offset = err.byte_offset,
                        .msg = msg,
                    });
                }
                continue;
            }
            try self.file.pwriteAll(code.items, file_off);

            if (mem.eql(u8, exp.name, "_start")) {
                self.entry_addr = vaddr;
            }
            (try self.symbols.addOne()).* = .{
                .st_name = try self.makeString(exp.name),
                .st_info = (elf.STB_LOCAL << 4) | elf.STT_FUNC,
                .st_other = 0,
                .st_shndx = self.text_section_index.?,
                .st_value = vaddr,
                .st_size = code.items.len,
            };
            vaddr += code.items.len;
        }

        {
            // Now that we know the code size, we need to update the program header for executable code
            phdr.p_memsz = vaddr - phdr.p_vaddr;
            phdr.p_filesz = phdr.p_memsz;

            const shdr = &self.sections.items[self.text_section_index.?];
            shdr.sh_size = phdr.p_filesz;

            if (!phdr_table_dirty) {
                // Then it won't get written with the others and we need to do it.
                try self.writeProgHeader(self.phdr_load_re_index.?);
            }
            if (!shdr_table_dirty) {
                // Then it won't get written with the others and we need to do it.
                try self.writeSectHeader(self.text_section_index.?);
            }
        }

        return self.writeSymbols();
    }

    fn writeProgHeader(self: *Update, index: usize) !void {
        const foreign_endian = self.module.target.cpu.arch.endian() != std.Target.current.cpu.arch.endian();
        const offset = self.program_headers.items[index].p_offset;
        switch (self.module.target.cpu.arch.ptrBitWidth()) {
            32 => {
                var phdr = [1]elf.Elf32_Phdr{progHeaderTo32(self.program_headers.items[index])};
                if (foreign_endian) {
                    bswapAllFields(elf.Elf32_Phdr, &phdr[0]);
                }
                return self.file.pwriteAll(mem.sliceAsBytes(&phdr), offset);
            },
            64 => {
                var phdr = [1]elf.Elf64_Phdr{self.program_headers.items[index]};
                if (foreign_endian) {
                    bswapAllFields(elf.Elf64_Phdr, &phdr[0]);
                }
                return self.file.pwriteAll(mem.sliceAsBytes(&phdr), offset);
            },
            else => return error.UnsupportedArchitecture,
        }
    }

    fn writeSectHeader(self: *Update, index: usize) !void {
        const foreign_endian = self.module.target.cpu.arch.endian() != std.Target.current.cpu.arch.endian();
        const offset = self.sections.items[index].sh_offset;
        switch (self.module.target.cpu.arch.ptrBitWidth()) {
            32 => {
                var shdr: [1]elf.Elf32_Shdr = undefined;
                shdr[0] = sectHeaderTo32(self.sections.items[index]);
                if (foreign_endian) {
                    bswapAllFields(elf.Elf32_Shdr, &shdr[0]);
                }
                return self.file.pwriteAll(mem.sliceAsBytes(&shdr), offset);
            },
            64 => {
                var shdr = [1]elf.Elf64_Shdr{self.sections.items[index]};
                if (foreign_endian) {
                    bswapAllFields(elf.Elf64_Shdr, &shdr[0]);
                }
                return self.file.pwriteAll(mem.sliceAsBytes(&shdr), offset);
            },
            else => return error.UnsupportedArchitecture,
        }
    }

    fn writeSymbols(self: *Update) !void {
        const ptr_width: enum { p32, p64 } = switch (self.module.target.cpu.arch.ptrBitWidth()) {
            32 => .p32,
            64 => .p64,
            else => return error.UnsupportedArchitecture,
        };
        const small_ptr = ptr_width == .p32;
        const syms_sect = &self.sections.items[self.symtab_section_index.?];
        const sym_align: u16 = if (small_ptr) @alignOf(elf.Elf32_Sym) else @alignOf(elf.Elf64_Sym);
        const sym_size: u64 = if (small_ptr) @sizeOf(elf.Elf32_Sym) else @sizeOf(elf.Elf64_Sym);

        const allocated_size = self.allocatedSize(syms_sect.sh_offset);
        const needed_size = self.symbols.items.len * sym_size;
        if (needed_size > allocated_size) {
            syms_sect.sh_size = 0; // free the space
            syms_sect.sh_offset = self.findFreeSpace(needed_size, sym_align);
            //std.debug.warn("moved symtab to 0x{x} to 0x{x}\n", .{ syms_sect.sh_offset, syms_sect.sh_offset + needed_size });
        }
        //std.debug.warn("symtab start=0x{x} end=0x{x}\n", .{ syms_sect.sh_offset, syms_sect.sh_offset + needed_size });
        syms_sect.sh_size = needed_size;
        syms_sect.sh_info = @intCast(u32, self.symbols.items.len);
        const allocator = self.symbols.allocator;
        const foreign_endian = self.module.target.cpu.arch.endian() != std.Target.current.cpu.arch.endian();
        switch (ptr_width) {
            .p32 => {
                const buf = try allocator.alloc(elf.Elf32_Sym, self.symbols.items.len);
                defer allocator.free(buf);

                for (buf) |*sym, i| {
                    sym.* = .{
                        .st_name = self.symbols.items[i].st_name,
                        .st_value = @intCast(u32, self.symbols.items[i].st_value),
                        .st_size = @intCast(u32, self.symbols.items[i].st_size),
                        .st_info = self.symbols.items[i].st_info,
                        .st_other = self.symbols.items[i].st_other,
                        .st_shndx = self.symbols.items[i].st_shndx,
                    };
                    if (foreign_endian) {
                        bswapAllFields(elf.Elf32_Sym, sym);
                    }
                }
                try self.file.pwriteAll(mem.sliceAsBytes(buf), syms_sect.sh_offset);
            },
            .p64 => {
                const buf = try allocator.alloc(elf.Elf64_Sym, self.symbols.items.len);
                defer allocator.free(buf);

                for (buf) |*sym, i| {
                    sym.* = .{
                        .st_name = self.symbols.items[i].st_name,
                        .st_value = self.symbols.items[i].st_value,
                        .st_size = self.symbols.items[i].st_size,
                        .st_info = self.symbols.items[i].st_info,
                        .st_other = self.symbols.items[i].st_other,
                        .st_shndx = self.symbols.items[i].st_shndx,
                    };
                    if (foreign_endian) {
                        bswapAllFields(elf.Elf64_Sym, sym);
                    }
                }
                try self.file.pwriteAll(mem.sliceAsBytes(buf), syms_sect.sh_offset);
            },
        }
    }
};

/// Truncates the existing file contents and overwrites the contents.
/// Returns an error if `file` is not already open with +read +write +seek abilities.
pub fn writeFile(allocator: *Allocator, module: ir.Module, file: fs.File) !Result {
    switch (module.output_mode) {
        .Exe => {},
        .Obj => {},
        .Lib => return error.TODOImplementWritingLibFiles,
    }
    switch (module.object_format) {
        .unknown => unreachable, // TODO remove this tag from the enum
        .coff => return error.TODOImplementWritingCOFF,
        .elf => {},
        .macho => return error.TODOImplementWritingMachO,
        .wasm => return error.TODOImplementWritingWasmObjects,
    }

    var update = Update{
        .file = file,
        .module = &module,
        .sections = std.ArrayList(elf.Elf64_Shdr).init(allocator),
        .shdr_table_offset = null,
        .program_headers = std.ArrayList(elf.Elf64_Phdr).init(allocator),
        .phdr_table_offset = null,
        .phdr_load_re_index = null,
        .entry_addr = null,
        .shstrtab = std.ArrayList(u8).init(allocator),
        .shstrtab_index = null,
        .text_section_index = null,
        .symtab_section_index = null,

        .symbols = std.ArrayList(elf.Elf64_Sym).init(allocator),

        .errors = std.ArrayList(ErrorMsg).init(allocator),
    };
    defer update.deinit();

    try update.perform();
    return Result{
        .errors = update.errors.toOwnedSlice(),
    };
}

/// Returns error.IncrFailed if incremental update could not be performed.
fn updateFileInner(allocator: *Allocator, module: ir.Module, file: fs.File) !Result {
    //var ehdr_buf: [@sizeOf(elf.Elf64_Ehdr)]u8 = undefined;

    // TODO implement incremental linking
    return error.IncrFailed;
}

/// Saturating multiplication
fn satMul(a: var, b: var) @TypeOf(a, b) {
    const T = @TypeOf(a, b);
    return std.math.mul(T, a, b) catch std.math.maxInt(T);
}

fn bswapAllFields(comptime S: type, ptr: *S) void {
    @panic("TODO implement bswapAllFields");
}

fn progHeaderTo32(phdr: elf.Elf64_Phdr) elf.Elf32_Phdr {
    return .{
        .p_type = phdr.p_type,
        .p_flags = phdr.p_flags,
        .p_offset = @intCast(u32, phdr.p_offset),
        .p_vaddr = @intCast(u32, phdr.p_vaddr),
        .p_paddr = @intCast(u32, phdr.p_paddr),
        .p_filesz = @intCast(u32, phdr.p_filesz),
        .p_memsz = @intCast(u32, phdr.p_memsz),
        .p_align = @intCast(u32, phdr.p_align),
    };
}

fn sectHeaderTo32(shdr: elf.Elf64_Shdr) elf.Elf32_Shdr {
    return .{
        .sh_name = shdr.sh_name,
        .sh_type = shdr.sh_type,
        .sh_flags = @intCast(u32, shdr.sh_flags),
        .sh_addr = @intCast(u32, shdr.sh_addr),
        .sh_offset = @intCast(u32, shdr.sh_offset),
        .sh_size = @intCast(u32, shdr.sh_size),
        .sh_link = shdr.sh_link,
        .sh_info = shdr.sh_info,
        .sh_addralign = @intCast(u32, shdr.sh_addralign),
        .sh_entsize = @intCast(u32, shdr.sh_entsize),
    };
}

fn determineMode(module: ir.Module) fs.File.Mode {
    // On common systems with a 0o022 umask, 0o777 will still result in a file created
    // with 0o755 permissions, but it works appropriately if the system is configured
    // more leniently. As another data point, C's fopen seems to open files with the
    // 666 mode.
    const executable_mode = if (std.Target.current.os.tag == .windows) 0 else 0o777;
    switch (module.output_mode) {
        .Lib => return switch (module.link_mode) {
            .Dynamic => executable_mode,
            .Static => fs.File.default_mode,
        },
        .Exe => return executable_mode,
        .Obj => return fs.File.default_mode,
    }
}
