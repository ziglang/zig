const std = @import("std");
const mem = std.mem;
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const ir = @import("ir.zig");
const fs = std.fs;
const elf = std.elf;
const codegen = @import("codegen.zig");

const default_entry_addr = 0x8000000;

pub const Options = struct {
    target: std.Target,
    output_mode: std.builtin.OutputMode,
    link_mode: std.builtin.LinkMode,
    object_format: std.builtin.ObjectFormat,
    /// Used for calculating how much space to reserve for symbols in case the binary file
    /// does not already have a symbol table.
    symbol_count_hint: u64 = 32,
    /// Used for calculating how much space to reserve for executable program code in case
    /// the binary file deos not already have such a section.
    program_code_size_hint: u64 = 256 * 1024,
};

/// Attempts incremental linking, if the file already exists.
/// If incremental linking fails, falls back to truncating the file and rewriting it.
/// A malicious file is detected as incremental link failure and does not cause Illegal Behavior.
/// This operation is not atomic.
pub fn openBinFilePath(
    allocator: *Allocator,
    dir: fs.Dir,
    sub_path: []const u8,
    options: Options,
) !ElfFile {
    const file = try dir.createFile(sub_path, .{ .truncate = false, .read = true, .mode = determineMode(options) });
    defer file.close();

    return openBinFile(allocator, file, options);
}

/// Atomically overwrites the old file, if present.
pub fn writeFilePath(
    allocator: *Allocator,
    dir: fs.Dir,
    sub_path: []const u8,
    module: ir.Module,
    errors: *std.ArrayList(ir.ErrorMsg),
) !void {
    const options: Options = .{
        .target = module.target,
        .output_mode = module.output_mode,
        .link_mode = module.link_mode,
        .object_format = module.object_format,
        .symbol_count_hint = module.decls.items.len,
    };
    const af = try dir.atomicFile(sub_path, .{ .mode = determineMode(options) });
    defer af.deinit();

    const elf_file = try createElfFile(allocator, af.file, options);
    for (module.decls.items) |decl| {
        try elf_file.updateDecl(module, decl, errors);
    }
    try elf_file.flush();
    if (elf_file.error_flags.no_entry_point_found) {
        try errors.ensureCapacity(errors.items.len + 1);
        errors.appendAssumeCapacity(.{
            .byte_offset = 0,
            .msg = try std.fmt.allocPrint(errors.allocator, "no entry point found", .{}),
        });
    }
    try af.finish();
    return result;
}

/// Attempts incremental linking, if the file already exists.
/// If incremental linking fails, falls back to truncating the file and rewriting it.
/// Returns an error if `file` is not already open with +read +write +seek abilities.
/// A malicious file is detected as incremental link failure and does not cause Illegal Behavior.
/// This operation is not atomic.
pub fn openBinFile(allocator: *Allocator, file: fs.File, options: Options) !ElfFile {
    return openBinFileInner(allocator, file, options) catch |err| switch (err) {
        error.IncrFailed => {
            return createElfFile(allocator, file, options);
        },
        else => |e| return e,
    };
}

pub const ElfFile = struct {
    allocator: *Allocator,
    file: fs.File,
    options: Options,
    ptr_width: enum { p32, p64 },

    /// Stored in native-endian format, depending on target endianness needs to be bswapped on read/write.
    /// Same order as in the file.
    sections: std.ArrayListUnmanaged(elf.Elf64_Shdr) = std.ArrayListUnmanaged(elf.Elf64_Shdr){},
    shdr_table_offset: ?u64 = null,

    /// Stored in native-endian format, depending on target endianness needs to be bswapped on read/write.
    /// Same order as in the file.
    program_headers: std.ArrayListUnmanaged(elf.Elf64_Phdr) = std.ArrayListUnmanaged(elf.Elf64_Phdr){},
    phdr_table_offset: ?u64 = null,
    /// The index into the program headers of a PT_LOAD program header with Read and Execute flags
    phdr_load_re_index: ?u16 = null,
    /// The index into the program headers of the global offset table.
    /// It needs PT_LOAD and Read flags.
    phdr_got_index: ?u16 = null,
    entry_addr: ?u64 = null,

    shstrtab: std.ArrayListUnmanaged(u8) = std.ArrayListUnmanaged(u8){},
    shstrtab_index: ?u16 = null,

    text_section_index: ?u16 = null,
    symtab_section_index: ?u16 = null,
    got_section_index: ?u16 = null,

    /// The same order as in the file
    symbols: std.ArrayListUnmanaged(elf.Elf64_Sym) = std.ArrayListUnmanaged(elf.Elf64_Sym){},

    /// Same order as in the file. The value is the absolute vaddr value.
    /// If the vaddr of the executable program header changes, the entire
    /// offset table needs to be rewritten.
    offset_table: std.ArrayListUnmanaged(u64) = std.ArrayListUnmanaged(u64){},

    phdr_table_dirty: bool = false,
    shdr_table_dirty: bool = false,
    shstrtab_dirty: bool = false,
    offset_table_count_dirty: bool = false,
    symbol_count_dirty: bool = false,

    error_flags: ErrorFlags = ErrorFlags{},

    pub const ErrorFlags = struct {
        no_entry_point_found: bool = false,
    };

    pub const Decl = struct {
        /// Each decl always gets a local symbol with the fully qualified name.
        /// The vaddr and size are found here directly.
        /// The file offset is found by computing the vaddr offset from the section vaddr
        /// the symbol references, and adding that to the file offset of the section.
        /// If this field is 0, it means the codegen size = 0 and there is no symbol or
        /// offset table entry.
        local_sym_index: u32,
        /// This field is undefined for symbols with size = 0.
        offset_table_index: u32,

        pub const empty = Decl{
            .local_sym_index = 0,
            .offset_table_index = undefined,
        };
    };

    pub const Export = struct {
        sym_index: ?usize = null,
    };

    pub fn deinit(self: *ElfFile) void {
        self.sections.deinit(self.allocator);
        self.program_headers.deinit(self.allocator);
        self.shstrtab.deinit(self.allocator);
        self.symbols.deinit(self.allocator);
        self.offset_table.deinit(self.allocator);
    }

    // `alloc_num / alloc_den` is the factor of padding when allocation
    const alloc_num = 4;
    const alloc_den = 3;

    /// Returns end pos of collision, if any.
    fn detectAllocCollision(self: *ElfFile, start: u64, size: u64) ?u64 {
        const small_ptr = self.options.target.cpu.arch.ptrBitWidth() == 32;
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

    fn allocatedSize(self: *ElfFile, start: u64) u64 {
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

    fn findFreeSpace(self: *ElfFile, object_size: u64, min_alignment: u16) u64 {
        var start: u64 = 0;
        while (self.detectAllocCollision(start, object_size)) |item_end| {
            start = mem.alignForwardGeneric(u64, item_end, min_alignment);
        }
        return start;
    }

    fn makeString(self: *ElfFile, bytes: []const u8) !u32 {
        try self.shstrtab.ensureCapacity(self.allocator, self.shstrtab.items.len + bytes.len + 1);
        const result = self.shstrtab.items.len;
        self.shstrtab.appendSliceAssumeCapacity(bytes);
        self.shstrtab.appendAssumeCapacity(0);
        return @intCast(u32, result);
    }

    fn getString(self: *ElfFile, str_off: u32) []const u8 {
        assert(str_off < self.shstrtab.items.len);
        return mem.spanZ(@ptrCast([*:0]const u8, self.shstrtab.items.ptr + str_off));
    }

    fn updateString(self: *ElfFile, old_str_off: u32, new_name: []const u8) !u32 {
        const existing_name = self.getString(old_str_off);
        if (mem.eql(u8, existing_name, new_name)) {
            return old_str_off;
        }
        return self.makeString(new_name);
    }

    pub fn populateMissingMetadata(self: *ElfFile) !void {
        const small_ptr = switch (self.ptr_width) {
            .p32 => true,
            .p64 => false,
        };
        const ptr_size: u8 = switch (self.ptr_width) {
            .p32 => 4,
            .p64 => 8,
        };
        if (self.phdr_load_re_index == null) {
            self.phdr_load_re_index = @intCast(u16, self.program_headers.items.len);
            const file_size = self.options.program_code_size_hint;
            const p_align = 0x1000;
            const off = self.findFreeSpace(file_size, p_align);
            //std.debug.warn("found PT_LOAD free space 0x{x} to 0x{x}\n", .{ off, off + file_size });
            try self.program_headers.append(self.allocator, .{
                .p_type = elf.PT_LOAD,
                .p_offset = off,
                .p_filesz = file_size,
                .p_vaddr = default_entry_addr,
                .p_paddr = default_entry_addr,
                .p_memsz = file_size,
                .p_align = p_align,
                .p_flags = elf.PF_X | elf.PF_R,
            });
            self.entry_addr = null;
            self.phdr_table_dirty = true;
        }
        if (self.phdr_got_index == null) {
            self.phdr_got_index = @intCast(u16, self.program_headers.items.len);
            const file_size = @as(u64, ptr_size) * self.options.symbol_count_hint;
            const off = self.findFreeSpace(file_size, ptr_size);
            //std.debug.warn("found PT_LOAD free space 0x{x} to 0x{x}\n", .{ off, off + file_size });
            // TODO instead of hard coding the vaddr, make a function to find a vaddr to put things at.
            // we'll need to re-use that function anyway, in case the GOT grows and overlaps something
            // else in virtual memory.
            const default_got_addr = 0x80000000;
            try self.program_headers.append(self.allocator, .{
                .p_type = elf.PT_LOAD,
                .p_offset = off,
                .p_filesz = file_size,
                .p_vaddr = default_got_addr,
                .p_paddr = default_got_addr,
                .p_memsz = file_size,
                .p_align = ptr_size,
                .p_flags = elf.PF_R,
            });
            self.phdr_table_dirty = true;
        }
        if (self.shstrtab_index == null) {
            self.shstrtab_index = @intCast(u16, self.sections.items.len);
            assert(self.shstrtab.items.len == 0);
            try self.shstrtab.append(self.allocator, 0); // need a 0 at position 0
            const off = self.findFreeSpace(self.shstrtab.items.len, 1);
            //std.debug.warn("found shstrtab free space 0x{x} to 0x{x}\n", .{ off, off + self.shstrtab.items.len });
            try self.sections.append(self.allocator, .{
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
            self.shstrtab_dirty = true;
            self.shdr_table_dirty = true;
        }
        if (self.text_section_index == null) {
            self.text_section_index = @intCast(u16, self.sections.items.len);
            const phdr = &self.program_headers.items[self.phdr_load_re_index.?];

            try self.sections.append(self.allocator, .{
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
            self.shdr_table_dirty = true;
        }
        if (self.got_section_index == null) {
            self.got_section_index = @intCast(u16, self.sections.items.len);
            const phdr = &self.program_headers.items[self.phdr_got_index.?];

            try self.sections.append(self.allocator, .{
                .sh_name = try self.makeString(".got"),
                .sh_type = elf.SHT_PROGBITS,
                .sh_flags = elf.SHF_ALLOC,
                .sh_addr = phdr.p_vaddr,
                .sh_offset = phdr.p_offset,
                .sh_size = phdr.p_filesz,
                .sh_link = 0,
                .sh_info = 0,
                .sh_addralign = phdr.p_align,
                .sh_entsize = ptr_size,
            });
            self.shdr_table_dirty = true;
        }
        if (self.symtab_section_index == null) {
            self.symtab_section_index = @intCast(u16, self.sections.items.len);
            const min_align: u16 = if (small_ptr) @alignOf(elf.Elf32_Sym) else @alignOf(elf.Elf64_Sym);
            const each_size: u64 = if (small_ptr) @sizeOf(elf.Elf32_Sym) else @sizeOf(elf.Elf64_Sym);
            const file_size = self.options.symbol_count_hint * each_size;
            const off = self.findFreeSpace(file_size, min_align);
            //std.debug.warn("found symtab free space 0x{x} to 0x{x}\n", .{ off, off + file_size });

            try self.sections.append(self.allocator, .{
                .sh_name = try self.makeString(".symtab"),
                .sh_type = elf.SHT_SYMTAB,
                .sh_flags = 0,
                .sh_addr = 0,
                .sh_offset = off,
                .sh_size = file_size,
                // The section header index of the associated string table.
                .sh_link = self.shstrtab_index.?,
                .sh_info = @intCast(u32, self.symbols.items.len),
                .sh_addralign = min_align,
                .sh_entsize = each_size,
            });
            self.shdr_table_dirty = true;
            try self.writeAllSymbols();
        }
        const shsize: u64 = switch (self.ptr_width) {
            .p32 => @sizeOf(elf.Elf32_Shdr),
            .p64 => @sizeOf(elf.Elf64_Shdr),
        };
        const shalign: u16 = switch (self.ptr_width) {
            .p32 => @alignOf(elf.Elf32_Shdr),
            .p64 => @alignOf(elf.Elf64_Shdr),
        };
        if (self.shdr_table_offset == null) {
            self.shdr_table_offset = self.findFreeSpace(self.sections.items.len * shsize, shalign);
            self.shdr_table_dirty = true;
        }
        const phsize: u64 = switch (self.ptr_width) {
            .p32 => @sizeOf(elf.Elf32_Phdr),
            .p64 => @sizeOf(elf.Elf64_Phdr),
        };
        const phalign: u16 = switch (self.ptr_width) {
            .p32 => @alignOf(elf.Elf32_Phdr),
            .p64 => @alignOf(elf.Elf64_Phdr),
        };
        if (self.phdr_table_offset == null) {
            self.phdr_table_offset = self.findFreeSpace(self.program_headers.items.len * phsize, phalign);
            self.phdr_table_dirty = true;
        }
    }

    /// Commit pending changes and write headers.
    pub fn flush(self: *ElfFile) !void {
        const foreign_endian = self.options.target.cpu.arch.endian() != std.Target.current.cpu.arch.endian();

        if (self.phdr_table_dirty) {
            const phsize: u64 = switch (self.ptr_width) {
                .p32 => @sizeOf(elf.Elf32_Phdr),
                .p64 => @sizeOf(elf.Elf64_Phdr),
            };
            const phalign: u16 = switch (self.ptr_width) {
                .p32 => @alignOf(elf.Elf32_Phdr),
                .p64 => @alignOf(elf.Elf64_Phdr),
            };
            const allocated_size = self.allocatedSize(self.phdr_table_offset.?);
            const needed_size = self.program_headers.items.len * phsize;

            if (needed_size > allocated_size) {
                self.phdr_table_offset = null; // free the space
                self.phdr_table_offset = self.findFreeSpace(needed_size, phalign);
            }

            switch (self.ptr_width) {
                .p32 => {
                    const buf = try self.allocator.alloc(elf.Elf32_Phdr, self.program_headers.items.len);
                    defer self.allocator.free(buf);

                    for (buf) |*phdr, i| {
                        phdr.* = progHeaderTo32(self.program_headers.items[i]);
                        if (foreign_endian) {
                            bswapAllFields(elf.Elf32_Phdr, phdr);
                        }
                    }
                    try self.file.pwriteAll(mem.sliceAsBytes(buf), self.phdr_table_offset.?);
                },
                .p64 => {
                    const buf = try self.allocator.alloc(elf.Elf64_Phdr, self.program_headers.items.len);
                    defer self.allocator.free(buf);

                    for (buf) |*phdr, i| {
                        phdr.* = self.program_headers.items[i];
                        if (foreign_endian) {
                            bswapAllFields(elf.Elf64_Phdr, phdr);
                        }
                    }
                    try self.file.pwriteAll(mem.sliceAsBytes(buf), self.phdr_table_offset.?);
                },
            }
            self.phdr_table_dirty = false;
        }

        {
            const shstrtab_sect = &self.sections.items[self.shstrtab_index.?];
            if (self.shstrtab_dirty or self.shstrtab.items.len != shstrtab_sect.sh_size) {
                const allocated_size = self.allocatedSize(shstrtab_sect.sh_offset);
                const needed_size = self.shstrtab.items.len;

                if (needed_size > allocated_size) {
                    shstrtab_sect.sh_size = 0; // free the space
                    shstrtab_sect.sh_offset = self.findFreeSpace(needed_size, 1);
                }
                shstrtab_sect.sh_size = needed_size;
                //std.debug.warn("shstrtab start=0x{x} end=0x{x}\n", .{ shstrtab_sect.sh_offset, shstrtab_sect.sh_offset + needed_size });

                try self.file.pwriteAll(self.shstrtab.items, shstrtab_sect.sh_offset);
                if (!self.shdr_table_dirty) {
                    // Then it won't get written with the others and we need to do it.
                    try self.writeSectHeader(self.shstrtab_index.?);
                }
                self.shstrtab_dirty = false;
            }
        }
        if (self.shdr_table_dirty) {
            const shsize: u64 = switch (self.ptr_width) {
                .p32 => @sizeOf(elf.Elf32_Shdr),
                .p64 => @sizeOf(elf.Elf64_Shdr),
            };
            const shalign: u16 = switch (self.ptr_width) {
                .p32 => @alignOf(elf.Elf32_Shdr),
                .p64 => @alignOf(elf.Elf64_Shdr),
            };
            const allocated_size = self.allocatedSize(self.shdr_table_offset.?);
            const needed_size = self.sections.items.len * shsize;

            if (needed_size > allocated_size) {
                self.shdr_table_offset = null; // free the space
                self.shdr_table_offset = self.findFreeSpace(needed_size, shalign);
            }

            switch (self.ptr_width) {
                .p32 => {
                    const buf = try self.allocator.alloc(elf.Elf32_Shdr, self.sections.items.len);
                    defer self.allocator.free(buf);

                    for (buf) |*shdr, i| {
                        shdr.* = sectHeaderTo32(self.sections.items[i]);
                        if (foreign_endian) {
                            bswapAllFields(elf.Elf32_Shdr, shdr);
                        }
                    }
                    try self.file.pwriteAll(mem.sliceAsBytes(buf), self.shdr_table_offset.?);
                },
                .p64 => {
                    const buf = try self.allocator.alloc(elf.Elf64_Shdr, self.sections.items.len);
                    defer self.allocator.free(buf);

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
            self.shdr_table_dirty = false;
        }
        if (self.entry_addr == null and self.options.output_mode == .Exe) {
            self.error_flags.no_entry_point_found = true;
        } else {
            self.error_flags.no_entry_point_found = false;
            try self.writeElfHeader();
        }
        // TODO find end pos and truncate

        // The point of flush() is to commit changes, so nothing should be dirty after this.
        assert(!self.phdr_table_dirty);
        assert(!self.shdr_table_dirty);
        assert(!self.shstrtab_dirty);
        assert(!self.symbol_count_dirty);
        assert(!self.offset_table_count_dirty);
    }

    fn writeElfHeader(self: *ElfFile) !void {
        var hdr_buf: [@sizeOf(elf.Elf64_Ehdr)]u8 = undefined;

        var index: usize = 0;
        hdr_buf[0..4].* = "\x7fELF".*;
        index += 4;

        hdr_buf[index] = switch (self.ptr_width) {
            .p32 => elf.ELFCLASS32,
            .p64 => elf.ELFCLASS64,
        };
        index += 1;

        const endian = self.options.target.cpu.arch.endian();
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

        const elf_type = switch (self.options.output_mode) {
            .Exe => elf.ET.EXEC,
            .Obj => elf.ET.REL,
            .Lib => switch (self.options.link_mode) {
                .Static => elf.ET.REL,
                .Dynamic => elf.ET.DYN,
            },
        };
        mem.writeInt(u16, hdr_buf[index..][0..2], @enumToInt(elf_type), endian);
        index += 2;

        const machine = self.options.target.cpu.arch.toElfMachine();
        mem.writeInt(u16, hdr_buf[index..][0..2], @enumToInt(machine), endian);
        index += 2;

        // ELF Version, again
        mem.writeInt(u32, hdr_buf[index..][0..4], 1, endian);
        index += 4;

        const e_entry = if (elf_type == .REL) 0 else self.entry_addr.?;

        switch (self.ptr_width) {
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

        const e_ehsize: u16 = switch (self.ptr_width) {
            .p32 => @sizeOf(elf.Elf32_Ehdr),
            .p64 => @sizeOf(elf.Elf64_Ehdr),
        };
        mem.writeInt(u16, hdr_buf[index..][0..2], e_ehsize, endian);
        index += 2;

        const e_phentsize: u16 = switch (self.ptr_width) {
            .p32 => @sizeOf(elf.Elf32_Phdr),
            .p64 => @sizeOf(elf.Elf64_Phdr),
        };
        mem.writeInt(u16, hdr_buf[index..][0..2], e_phentsize, endian);
        index += 2;

        const e_phnum = @intCast(u16, self.program_headers.items.len);
        mem.writeInt(u16, hdr_buf[index..][0..2], e_phnum, endian);
        index += 2;

        const e_shentsize: u16 = switch (self.ptr_width) {
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

    const AllocatedBlock = struct {
        vaddr: u64,
        file_offset: u64,
        size_capacity: u64,
    };

    fn allocateTextBlock(self: *ElfFile, new_block_size: u64) !AllocatedBlock {
        const phdr = &self.program_headers.items[self.phdr_load_re_index.?];
        const shdr = &self.sections.items[self.text_section_index.?];

        // TODO Also detect virtual address collisions.
        const text_capacity = self.allocatedSize(shdr.sh_offset);
        // TODO instead of looping here, maintain a free list and a pointer to the end.
        const end_vaddr = blk: {
            var start: u64 = 0;
            var size: u64 = 0;
            for (self.symbols.items) |sym| {
                if (sym.st_value > start) {
                    start = sm.st_value;
                    size = sym.st_size;
                }
            }
            break :blk start + (size * alloc_num / alloc_den);
        };

        const text_size = end_vaddr - phdr.p_vaddr;
        const needed_size = text_size + new_block_size;
        if (needed_size > text_capacity) {
            // Must move the entire text section.
            const new_offset = self.findFreeSpace(needed_size, 0x1000);
            const amt = try self.file.copyRangeAll(shdr.sh_offset, self.file, new_offset, text_size);
            if (amt != text_size) return error.InputOutput;
            shdr.sh_offset = new_offset;
        }
        // Now that we know the code size, we need to update the program header for executable code
        shdr.sh_size = needed_size;
        phdr.p_memsz = needed_size;
        phdr.p_filesz = needed_size;

        self.phdr_table_dirty = true; // TODO look into making only the one program header dirty
        self.shdr_table_dirty = true; // TODO look into making only the one section dirty
    }

    fn findAllocatedTextBlock(self: *ElfFile, sym: elf.Elf64_Sym) AllocatedBlock {
        const phdr = &self.program_headers.items[self.phdr_load_re_index.?];
        const shdr = &self.sections.items[self.text_section_index.?];

        // Find the next sym after this one.
        // TODO look into using a hash map to speed up perf.
        const text_capacity = self.allocatedSize(shdr.sh_offset);
        var next_vaddr_start = phdr.p_vaddr + text_capacity;
        for (self.symbols.items) |elem| {
            if (elem.st_value < sym.st_value) continue;
            if (elem.st_value < next_vaddr_start) next_vaddr_start = elem.st_value;
        }
        return .{
            .vaddr = sym.st_value,
            .file_offset = shdr.sh_offset + (sym.st_value - phdr.p_vaddr),
            .size_capacity = next_vaddr_start - sym.st_value,
        };
    }

    pub fn updateDecl(self: *ElfFile, module: *ir.Module, decl: *ir.Module.Decl) !void {
        var code = std.ArrayList(u8).init(self.allocator);
        defer code.deinit();

        const typed_value = decl.typed_value.most_recent.typed_value;
        const err_msg = try codegen.generateSymbol(typed_value, module.*, &code);
        if (err_msg != null) |em| {
            decl.analysis = .codegen_failure;
            _ = try module.failed_decls.put(decl, em);
            return;
        }

        const file_offset = blk: {
            const code_size = code.items.len;
            const stt_bits: u8 = switch (typed_value.ty.zigTypeTag()) {
                .Fn => elf.STT_FUNC,
                else => elf.STT_OBJECT,
            };

            if (decl.link.local_sym_index != 0) {
                const local_sym = &self.symbols.items[decl.link.local_sym_index];
                const existing_block = self.findAllocatedTextBlock(local_sym);
                const file_offset = if (code_size > existing_block.size_capacity) fo: {
                    const new_block = try self.allocateTextBlock(code_size);
                    local_sym.st_value = new_block.vaddr;
                    local_sym.st_size = code_size;

                    try self.writeOffsetTableEntry(decl.link.offset_table_index);

                    break :fo new_block.file_offset;
                } else existing_block.file_offset;
                local_sym.st_name = try self.updateString(local_sym.st_name, mem.spanZ(u8, decl.name));
                local_sym.st_info = (elf.STB_LOCAL << 4) | stt_bits;
                // TODO this write could be avoided if no fields of the symbol were changed.
                try self.writeSymbol(decl.link.local_sym_index);
                break :blk file_offset;
            } else {
                try self.symbols.ensureCapacity(self.allocator, self.symbols.items.len + 1);
                try self.offset_table.ensureCapacity(self.allocator, self.offset_table.items.len + 1);
                const decl_name = mem.spanZ(u8, decl.name);
                const name_str_index = try self.makeString(decl_name);
                const new_block = try self.allocateTextBlock(code_size);
                const local_sym_index = self.symbols.items.len;
                const offset_table_index = self.offset_table.items.len;

                self.symbols.appendAssumeCapacity(.{
                    .st_name = name_str_index,
                    .st_info = (elf.STB_LOCAL << 4) | stt_bits,
                    .st_other = 0,
                    .st_shndx = self.text_section_index.?,
                    .st_value = new_block.vaddr,
                    .st_size = code_size,
                });
                errdefer self.symbols.shrink(self.allocator, self.symbols.items.len - 1);
                self.offset_table.appendAssumeCapacity(new_block.vaddr);
                errdefer self.offset_table.shrink(self.allocator, self.offset_table.items.len - 1);
                try self.writeSymbol(local_sym_index);
                try self.writeOffsetTableEntry(offset_table_index);

                self.symbol_count_dirty = true;
                self.offset_table_count_dirty = true;
                decl.link = .{
                    .local_sym_index = local_sym_index,
                    .offset_table_index = offset_table_index,
                };

                break :blk new_block.file_offset;
            }
        };

        try self.file.pwriteAll(code.items, file_offset);

        // Since we updated the vaddr and the size, each corresponding export symbol also needs to be updated.
        const decl_exports = module.decl_exports.get(decl) orelse &[0]*ir.Module.Export{};
        return self.updateDeclExports(module, decl, decl_exports);
    }

    /// Must be called only after a successful call to `updateDecl`.
    pub fn updateDeclExports(
        self: *ElfFile,
        module: *ir.Module,
        decl: *const ir.Module.Decl,
        exports: []const *ir.Module.Export,
    ) !void {
        try self.symbols.ensureCapacity(self.allocator, self.symbols.items.len + exports.len);
        const typed_value = decl.typed_value.most_recent.typed_value;
        assert(decl.link.local_sym_index != 0);
        const decl_sym = self.symbols.items[decl.link.local_sym_index];

        for (exports) |exp| {
            if (exp.options.section) |section_name| {
                if (!mem.eql(u8, section_name, ".text")) {
                    try module.failed_exports.ensureCapacity(module.failed_exports.size + 1);
                    module.failed_exports.putAssumeCapacityNoClobber(
                        exp,
                        try ir.ErrorMsg.create(self.allocator, 0, "Unimplemented: ExportOptions.section", .{}),
                    );
                    continue;
                }
            }
            const stb_bits: u8 = switch (exp.options.linkage) {
                .Internal => elf.STB_LOCAL,
                .Strong => blk: {
                    if (mem.eql(u8, exp.options.name, "_start")) {
                        self.entry_addr = decl_sym.st_value;
                    }
                    break :blk elf.STB_GLOBAL;
                },
                .Weak => elf.STB_WEAK,
                .LinkOnce => {
                    try module.failed_exports.ensureCapacity(module.failed_exports.size + 1);
                    module.failed_exports.putAssumeCapacityNoClobber(
                        exp,
                        try ir.ErrorMsg.create(self.allocator, 0, "Unimplemented: GlobalLinkage.LinkOnce", .{}),
                    );
                    continue;
                },
            };
            const stt_bits: u8 = @truncate(u4, decl_sym.st_info);
            if (exp.link.sym_index) |i| {
                const sym = &self.symbols.items[i];
                sym.* = .{
                    .st_name = try self.updateString(sym.st_name, exp.options.name),
                    .st_info = (stb_bits << 4) | stt_bits,
                    .st_other = 0,
                    .st_shndx = self.text_section_index.?,
                    .st_value = decl_sym.st_value,
                    .st_size = decl_sym.st_size,
                };
                try self.writeSymbol(i);
            } else {
                const name = try self.makeString(exp.options.name);
                const i = self.symbols.items.len;
                self.symbols.appendAssumeCapacity(.{
                    .st_name = name,
                    .st_info = (stb_bits << 4) | stt_bits,
                    .st_other = 0,
                    .st_shndx = self.text_section_index.?,
                    .st_value = decl_sym.st_value,
                    .st_size = decl_sym.st_size,
                });
                errdefer self.symbols.shrink(self.allocator, self.symbols.items.len - 1);
                try self.writeSymbol(i);

                self.symbol_count_dirty = true;
                exp.link.sym_index = i;
            }
        }
    }

    fn writeProgHeader(self: *ElfFile, index: usize) !void {
        const foreign_endian = self.options.target.cpu.arch.endian() != std.Target.current.cpu.arch.endian();
        const offset = self.program_headers.items[index].p_offset;
        switch (self.options.target.cpu.arch.ptrBitWidth()) {
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

    fn writeSectHeader(self: *ElfFile, index: usize) !void {
        const foreign_endian = self.options.target.cpu.arch.endian() != std.Target.current.cpu.arch.endian();
        const offset = self.sections.items[index].sh_offset;
        switch (self.options.target.cpu.arch.ptrBitWidth()) {
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

    fn writeOffsetTableEntry(self: *ElfFile, index: usize) !void {
        const shdr = &self.sections.items[self.got_section_index.?];
        const phdr = &self.program_headers.items[self.phdr_got_index.?];
        if (self.offset_table_count_dirty) {
            // TODO Also detect virtual address collisions.
            const allocated_size = self.allocatedSize(shdr.sh_offset);
            const needed_size = self.symbols.items.len * shdr.sh_entsize;
            if (needed_size > allocated_size) {
                // Must move the entire got section.
                const new_offset = self.findFreeSpace(needed_size, shdr.sh_entsize);
                const amt = try self.file.copyRangeAll(shdr.sh_offset, self.file, new_offset, shdr.sh_size);
                if (amt != text_size) return error.InputOutput;
                shdr.sh_offset = new_offset;
            }
            shdr.sh_size = needed_size;
            phdr.p_memsz = needed_size;
            phdr.p_filesz = needed_size;

            self.shdr_table_dirty = true; // TODO look into making only the one section dirty
            self.phdr_table_dirty = true; // TODO look into making only the one program header dirty

            self.offset_table_count_dirty = false;
        }
        const endian = self.options.target.cpu.arch.endian();
        const off = shdr.sh_offset + shdr.sh_entsize * index;
        switch (self.ptr_width) {
            .p32 => {
                var buf: [4]u8 = undefined;
                mem.writeInt(u32, &buf, @intCast(u32, self.offset_table.items[index]), endian);
                try self.file.pwriteAll(&buf, off);
            },
            .p64 => {
                var buf: [8]u8 = undefined;
                mem.writeInt(u64, &buf, self.offset_table.items[index], endian);
                try self.file.pwriteAll(&buf, off);
            },
        }
    }

    fn writeSymbol(self: *ElfFile, index: usize) !void {
        assert(index != 0);
        const syms_sect = &self.sections.items[self.symtab_section_index.?];
        // Make sure we are not pointlessly writing symbol data that will have to get relocated
        // due to running out of space.
        if (self.symbol_count_dirty) {
            const sym_size: u64 = switch (self.ptr_width) {
                .p32 => @sizeOf(elf.Elf32_Sym),
                .p64 => @sizeOf(elf.Elf64_Sym),
            };
            const allocated_size = self.allocatedSize(syms_sect.sh_offset);
            const needed_size = self.symbols.items.len * sym_size;
            if (needed_size > allocated_size) {
                return self.writeAllSymbols();
            }
            syms_sect.sh_info = @intCast(u32, self.symbols.items.len);
            self.shdr_table_dirty = true; // TODO look into only writing one section
            self.symbol_count_dirty = false;
        }
        const foreign_endian = self.options.target.cpu.arch.endian() != std.Target.current.cpu.arch.endian();
        switch (self.ptr_width) {
            .p32 => {
                var sym = [1]elf.Elf32_Sym{
                    .{
                        .st_name = self.symbols.items[index].st_name,
                        .st_value = @intCast(u32, self.symbols.items[index].st_value),
                        .st_size = @intCast(u32, self.symbols.items[index].st_size),
                        .st_info = self.symbols.items[index].st_info,
                        .st_other = self.symbols.items[index].st_other,
                        .st_shndx = self.symbols.items[index].st_shndx,
                    },
                };
                if (foreign_endian) {
                    bswapAllFields(elf.Elf32_Sym, &sym[0]);
                }
                const off = syms_sect.sh_offset + @sizeOf(elf.Elf32_Sym) * index;
                try self.file.pwriteAll(mem.sliceAsBytes(sym[0..1]), off);
            },
            .p64 => {
                var sym = [1]elf.Elf64_Sym{self.symbols.items[index]};
                if (foreign_endian) {
                    bswapAllFields(elf.Elf64_Sym, &sym[0]);
                }
                const off = syms_sect.sh_offset + @sizeOf(elf.Elf64_Sym) * index;
                try self.file.pwriteAll(mem.sliceAsBytes(sym[0..1]), off);
            },
        }
    }

    fn writeAllSymbols(self: *ElfFile) !void {
        const syms_sect = &self.sections.items[self.symtab_section_index.?];
        const sym_align: u16 = switch (self.ptr_width) {
            .p32 => @alignOf(elf.Elf32_Sym),
            .p64 => @alignOf(elf.Elf64_Sym),
        };
        const sym_size: u64 = switch (self.ptr_width) {
            .p32 => @sizeOf(elf.Elf32_Sym),
            .p64 => @sizeOf(elf.Elf64_Sym),
        };
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
        self.symbol_count_dirty = false;
        self.shdr_table_dirty = true; // TODO look into only writing one section
        const foreign_endian = self.options.target.cpu.arch.endian() != std.Target.current.cpu.arch.endian();
        switch (self.ptr_width) {
            .p32 => {
                const buf = try self.allocator.alloc(elf.Elf32_Sym, self.symbols.items.len);
                defer self.allocator.free(buf);

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
                const buf = try self.allocator.alloc(elf.Elf64_Sym, self.symbols.items.len);
                defer self.allocator.free(buf);

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
pub fn createElfFile(allocator: *Allocator, file: fs.File, options: Options) !ElfFile {
    switch (options.output_mode) {
        .Exe => {},
        .Obj => {},
        .Lib => return error.TODOImplementWritingLibFiles,
    }
    switch (options.object_format) {
        .unknown => unreachable, // TODO remove this tag from the enum
        .coff => return error.TODOImplementWritingCOFF,
        .elf => {},
        .macho => return error.TODOImplementWritingMachO,
        .wasm => return error.TODOImplementWritingWasmObjects,
    }

    var self: ElfFile = .{
        .allocator = allocator,
        .file = file,
        .options = options,
        .ptr_width = switch (options.target.cpu.arch.ptrBitWidth()) {
            32 => .p32,
            64 => .p64,
            else => return error.UnsupportedELFArchitecture,
        },
        .shdr_table_dirty = true,
    };
    errdefer self.deinit();

    // Index 0 is always a null symbol.
    try self.symbols.append(allocator, .{
        .st_name = 0,
        .st_info = 0,
        .st_other = 0,
        .st_shndx = 0,
        .st_value = 0,
        .st_size = 0,
    });

    // There must always be a null section in index 0
    try self.sections.append(allocator, .{
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

    try self.populateMissingMetadata();

    return self;
}

/// Returns error.IncrFailed if incremental update could not be performed.
fn openBinFileInner(allocator: *Allocator, file: fs.File, options: Options) !ElfFile {
    switch (options.output_mode) {
        .Exe => {},
        .Obj => {},
        .Lib => return error.IncrFailed,
    }
    switch (options.object_format) {
        .unknown => unreachable, // TODO remove this tag from the enum
        .coff => return error.IncrFailed,
        .elf => {},
        .macho => return error.IncrFailed,
        .wasm => return error.IncrFailed,
    }
    var self: ElfFile = .{
        .allocator = allocator,
        .file = file,
        .options = options,
        .ptr_width = switch (options.target.cpu.arch.ptrBitWidth()) {
            32 => .p32,
            64 => .p64,
            else => return error.UnsupportedELFArchitecture,
        },
    };
    errdefer self.deinit();

    // TODO implement reading the elf file
    return error.IncrFailed;
    //try self.populateMissingMetadata();
    //return self;
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

fn determineMode(options: Options) fs.File.Mode {
    // On common systems with a 0o022 umask, 0o777 will still result in a file created
    // with 0o755 permissions, but it works appropriately if the system is configured
    // more leniently. As another data point, C's fopen seems to open files with the
    // 666 mode.
    const executable_mode = if (std.Target.current.os.tag == .windows) 0 else 0o777;
    switch (options.output_mode) {
        .Lib => return switch (options.link_mode) {
            .Dynamic => executable_mode,
            .Static => fs.File.default_mode,
        },
        .Exe => return executable_mode,
        .Obj => return fs.File.default_mode,
    }
}
