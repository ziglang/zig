const std = @import("std");
const mem = std.mem;
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const ir = @import("ir.zig");
const Module = @import("Module.zig");
const fs = std.fs;
const elf = std.elf;
const codegen = @import("codegen.zig");
const c_codegen = @import("codegen/c.zig");

const default_entry_addr = 0x8000000;

pub const Options = struct {
    target: std.Target,
    output_mode: std.builtin.OutputMode,
    link_mode: std.builtin.LinkMode,
    object_format: std.builtin.ObjectFormat,
    optimize_mode: std.builtin.Mode,
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
) !*File {
    const cbe = options.object_format == .c;
    const file = try dir.createFile(sub_path, .{ .truncate = cbe, .read = true, .mode = determineMode(options) });
    errdefer file.close();

    if (cbe) {
        var bin_file = try allocator.create(File.C);
        errdefer allocator.destroy(bin_file);
        bin_file.* = try openCFile(allocator, file, options);
        return &bin_file.base;
    } else {
        var bin_file = try allocator.create(File.Elf);
        errdefer allocator.destroy(bin_file);
        bin_file.* = try openBinFile(allocator, file, options);
        bin_file.owns_file_handle = true;
        return &bin_file.base;
    }
}

/// Atomically overwrites the old file, if present.
pub fn writeFilePath(
    allocator: *Allocator,
    dir: fs.Dir,
    sub_path: []const u8,
    module: Module,
    errors: *std.ArrayList(Module.ErrorMsg),
) !void {
    const options: Options = .{
        .target = module.target,
        .output_mode = module.output_mode,
        .link_mode = module.link_mode,
        .object_format = module.object_format,
        .symbol_count_hint = module.decls.items.len,
        .optimize_mode = module.optimize_mode,
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

fn openCFile(allocator: *Allocator, file: fs.File, options: Options) !File.C {
    return File.C{
        .base = .{
            .tag = .c,
            .options = options,
        },
        .allocator = allocator,
        .file = file,
        .main = std.ArrayList(u8).init(allocator),
        .header = std.ArrayList(u8).init(allocator),
        .constants = std.ArrayList(u8).init(allocator),
        .called = std.StringHashMap(void).init(allocator),
    };
}

/// Attempts incremental linking, if the file already exists.
/// If incremental linking fails, falls back to truncating the file and rewriting it.
/// Returns an error if `file` is not already open with +read +write +seek abilities.
/// A malicious file is detected as incremental link failure and does not cause Illegal Behavior.
/// This operation is not atomic.
pub fn openBinFile(allocator: *Allocator, file: fs.File, options: Options) !File.Elf {
    return openBinFileInner(allocator, file, options) catch |err| switch (err) {
        error.IncrFailed => {
            return createElfFile(allocator, file, options);
        },
        else => |e| return e,
    };
}

pub const File = struct {
    tag: Tag,
    options: Options,

    pub fn cast(base: *File, comptime T: type) ?*T {
        if (base.tag != T.base_tag)
            return null;

        return @fieldParentPtr(T, "base", base);
    }

    pub fn makeWritable(base: *File, dir: fs.Dir, sub_path: []const u8) !void {
        switch (base.tag) {
            .elf => return @fieldParentPtr(Elf, "base", base).makeWritable(dir, sub_path),
            .c => {},
        }
    }

    pub fn makeExecutable(base: *File) !void {
        switch (base.tag) {
            .elf => return @fieldParentPtr(Elf, "base", base).makeExecutable(),
            .c => unreachable,
        }
    }

    pub fn updateDecl(base: *File, module: *Module, decl: *Module.Decl) !void {
        switch (base.tag) {
            .elf => return @fieldParentPtr(Elf, "base", base).updateDecl(module, decl),
            .c => return @fieldParentPtr(C, "base", base).updateDecl(module, decl),
        }
    }

    pub fn allocateDeclIndexes(base: *File, decl: *Module.Decl) !void {
        switch (base.tag) {
            .elf => return @fieldParentPtr(Elf, "base", base).allocateDeclIndexes(decl),
            .c => {},
        }
    }

    pub fn deinit(base: *File) void {
        switch (base.tag) {
            .elf => @fieldParentPtr(Elf, "base", base).deinit(),
            .c => @fieldParentPtr(C, "base", base).deinit(),
        }
    }

    pub fn destroy(base: *File) void {
        switch (base.tag) {
            .elf => {
                const parent = @fieldParentPtr(Elf, "base", base);
                parent.deinit();
                parent.allocator.destroy(parent);
            },
            .c => {
                const parent = @fieldParentPtr(C, "base", base);
                parent.deinit();
                parent.allocator.destroy(parent);
            },
        }
    }

    pub fn flush(base: *File) !void {
        try switch (base.tag) {
            .elf => @fieldParentPtr(Elf, "base", base).flush(),
            .c => @fieldParentPtr(C, "base", base).flush(),
        };
    }

    pub fn freeDecl(base: *File, decl: *Module.Decl) void {
        switch (base.tag) {
            .elf => @fieldParentPtr(Elf, "base", base).freeDecl(decl),
            .c => unreachable,
        }
    }

    pub fn errorFlags(base: *File) ErrorFlags {
        return switch (base.tag) {
            .elf => @fieldParentPtr(Elf, "base", base).error_flags,
            .c => return .{ .no_entry_point_found = false },
        };
    }

    /// Must be called only after a successful call to `updateDecl`.
    pub fn updateDeclExports(
        base: *File,
        module: *Module,
        decl: *const Module.Decl,
        exports: []const *Module.Export,
    ) !void {
        switch (base.tag) {
            .elf => return @fieldParentPtr(Elf, "base", base).updateDeclExports(module, decl, exports),
            .c => return {},
        }
    }

    pub const Tag = enum {
        elf,
        c,
    };

    pub const ErrorFlags = struct {
        no_entry_point_found: bool = false,
    };

    pub const C = struct {
        pub const base_tag: Tag = .c;

        base: File,

        allocator: *Allocator,
        header: std.ArrayList(u8),
        constants: std.ArrayList(u8),
        main: std.ArrayList(u8),
        file: ?fs.File,
        called: std.StringHashMap(void),
        need_stddef: bool = false,
        need_stdint: bool = false,
        need_noreturn: bool = false,
        error_msg: *Module.ErrorMsg = undefined,

        pub fn fail(self: *C, src: usize, comptime format: []const u8, args: anytype) !void {
            self.error_msg = try Module.ErrorMsg.create(self.allocator, src, format, args);
            return error.CGenFailure;
        }

        pub fn deinit(self: *File.C) void {
            self.main.deinit();
            self.header.deinit();
            self.constants.deinit();
            self.called.deinit();
            if (self.file) |f|
                f.close();
        }

        pub fn updateDecl(self: *File.C, module: *Module, decl: *Module.Decl) !void {
            c_codegen.generate(self, decl) catch |err| {
                if (err == error.CGenFailure) {
                    try module.failed_decls.put(module.gpa, decl, self.error_msg);
                }
                return err;
            };
        }

        pub fn flush(self: *File.C) !void {
            const writer = self.file.?.writer();
            try writer.writeAll(@embedFile("cbe.h"));
            var includes = false;
            if (self.need_stddef) {
                try writer.writeAll("#include <stddef.h>\n");
                includes = true;
            }
            if (self.need_stdint) {
                try writer.writeAll("#include <stdint.h>\n");
                includes = true;
            }
            if (includes) {
                try writer.writeByte('\n');
            }
            if (self.header.items.len > 0) {
                try writer.print("{}\n", .{self.header.items});
            }
            if (self.constants.items.len > 0) {
                try writer.print("{}\n", .{self.constants.items});
            }
            if (self.main.items.len > 1) {
                const last_two = self.main.items[self.main.items.len - 2 ..];
                if (std.mem.eql(u8, last_two, "\n\n")) {
                    self.main.items.len -= 1;
                }
            }
            try writer.writeAll(self.main.items);
            self.file.?.close();
            self.file = null;
        }
    };

    pub const Elf = struct {
        pub const base_tag: Tag = .elf;

        base: File,

        allocator: *Allocator,
        file: ?fs.File,
        owns_file_handle: bool,
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

        /// The same order as in the file. ELF requires global symbols to all be after the
        /// local symbols, they cannot be mixed. So we must buffer all the global symbols and
        /// write them at the end. These are only the local symbols. The length of this array
        /// is the value used for sh_info in the .symtab section.
        local_symbols: std.ArrayListUnmanaged(elf.Elf64_Sym) = std.ArrayListUnmanaged(elf.Elf64_Sym){},
        global_symbols: std.ArrayListUnmanaged(elf.Elf64_Sym) = std.ArrayListUnmanaged(elf.Elf64_Sym){},

        local_symbol_free_list: std.ArrayListUnmanaged(u32) = std.ArrayListUnmanaged(u32){},
        global_symbol_free_list: std.ArrayListUnmanaged(u32) = std.ArrayListUnmanaged(u32){},
        offset_table_free_list: std.ArrayListUnmanaged(u32) = std.ArrayListUnmanaged(u32){},

        /// Same order as in the file. The value is the absolute vaddr value.
        /// If the vaddr of the executable program header changes, the entire
        /// offset table needs to be rewritten.
        offset_table: std.ArrayListUnmanaged(u64) = std.ArrayListUnmanaged(u64){},

        phdr_table_dirty: bool = false,
        shdr_table_dirty: bool = false,
        shstrtab_dirty: bool = false,
        offset_table_count_dirty: bool = false,

        error_flags: ErrorFlags = ErrorFlags{},

        /// A list of text blocks that have surplus capacity. This list can have false
        /// positives, as functions grow and shrink over time, only sometimes being added
        /// or removed from the freelist.
        ///
        /// A text block has surplus capacity when its overcapacity value is greater than
        /// minimum_text_block_size * alloc_num / alloc_den. That is, when it has so
        /// much extra capacity, that we could fit a small new symbol in it, itself with
        /// ideal_capacity or more.
        ///
        /// Ideal capacity is defined by size * alloc_num / alloc_den.
        ///
        /// Overcapacity is measured by actual_capacity - ideal_capacity. Note that
        /// overcapacity can be negative. A simple way to have negative overcapacity is to
        /// allocate a fresh text block, which will have ideal capacity, and then grow it
        /// by 1 byte. It will then have -1 overcapacity.
        text_block_free_list: std.ArrayListUnmanaged(*TextBlock) = std.ArrayListUnmanaged(*TextBlock){},
        last_text_block: ?*TextBlock = null,

        /// `alloc_num / alloc_den` is the factor of padding when allocating.
        const alloc_num = 4;
        const alloc_den = 3;

        /// In order for a slice of bytes to be considered eligible to keep metadata pointing at
        /// it as a possible place to put new symbols, it must have enough room for this many bytes
        /// (plus extra for reserved capacity).
        const minimum_text_block_size = 64;
        const min_text_capacity = minimum_text_block_size * alloc_num / alloc_den;

        pub const TextBlock = struct {
            /// Each decl always gets a local symbol with the fully qualified name.
            /// The vaddr and size are found here directly.
            /// The file offset is found by computing the vaddr offset from the section vaddr
            /// the symbol references, and adding that to the file offset of the section.
            /// If this field is 0, it means the codegen size = 0 and there is no symbol or
            /// offset table entry.
            local_sym_index: u32,
            /// This field is undefined for symbols with size = 0.
            offset_table_index: u32,
            /// Points to the previous and next neighbors, based on the `text_offset`.
            /// This can be used to find, for example, the capacity of this `TextBlock`.
            prev: ?*TextBlock,
            next: ?*TextBlock,

            pub const empty = TextBlock{
                .local_sym_index = 0,
                .offset_table_index = undefined,
                .prev = null,
                .next = null,
            };

            /// Returns how much room there is to grow in virtual address space.
            /// File offset relocation happens transparently, so it is not included in
            /// this calculation.
            fn capacity(self: TextBlock, elf_file: Elf) u64 {
                const self_sym = elf_file.local_symbols.items[self.local_sym_index];
                if (self.next) |next| {
                    const next_sym = elf_file.local_symbols.items[next.local_sym_index];
                    return next_sym.st_value - self_sym.st_value;
                } else {
                    // We are the last block. The capacity is limited only by virtual address space.
                    return std.math.maxInt(u32) - self_sym.st_value;
                }
            }

            fn freeListEligible(self: TextBlock, elf_file: Elf) bool {
                // No need to keep a free list node for the last block.
                const next = self.next orelse return false;
                const self_sym = elf_file.local_symbols.items[self.local_sym_index];
                const next_sym = elf_file.local_symbols.items[next.local_sym_index];
                const cap = next_sym.st_value - self_sym.st_value;
                const ideal_cap = self_sym.st_size * alloc_num / alloc_den;
                if (cap <= ideal_cap) return false;
                const surplus = cap - ideal_cap;
                return surplus >= min_text_capacity;
            }
        };

        pub const Export = struct {
            sym_index: ?u32 = null,
        };

        pub fn deinit(self: *Elf) void {
            self.sections.deinit(self.allocator);
            self.program_headers.deinit(self.allocator);
            self.shstrtab.deinit(self.allocator);
            self.local_symbols.deinit(self.allocator);
            self.global_symbols.deinit(self.allocator);
            self.global_symbol_free_list.deinit(self.allocator);
            self.local_symbol_free_list.deinit(self.allocator);
            self.offset_table_free_list.deinit(self.allocator);
            self.text_block_free_list.deinit(self.allocator);
            self.offset_table.deinit(self.allocator);
            if (self.owns_file_handle) {
                if (self.file) |f| f.close();
            }
        }

        pub fn makeExecutable(self: *Elf) !void {
            assert(self.owns_file_handle);
            if (self.file) |f| {
                f.close();
                self.file = null;
            }
        }

        pub fn makeWritable(self: *Elf, dir: fs.Dir, sub_path: []const u8) !void {
            assert(self.owns_file_handle);
            if (self.file != null) return;
            self.file = try dir.createFile(sub_path, .{
                .truncate = false,
                .read = true,
                .mode = determineMode(self.base.options),
            });
        }

        /// Returns end pos of collision, if any.
        fn detectAllocCollision(self: *Elf, start: u64, size: u64) ?u64 {
            const small_ptr = self.base.options.target.cpu.arch.ptrBitWidth() == 32;
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

        fn allocatedSize(self: *Elf, start: u64) u64 {
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

        fn findFreeSpace(self: *Elf, object_size: u64, min_alignment: u16) u64 {
            var start: u64 = 0;
            while (self.detectAllocCollision(start, object_size)) |item_end| {
                start = mem.alignForwardGeneric(u64, item_end, min_alignment);
            }
            return start;
        }

        fn makeString(self: *Elf, bytes: []const u8) !u32 {
            try self.shstrtab.ensureCapacity(self.allocator, self.shstrtab.items.len + bytes.len + 1);
            const result = self.shstrtab.items.len;
            self.shstrtab.appendSliceAssumeCapacity(bytes);
            self.shstrtab.appendAssumeCapacity(0);
            return @intCast(u32, result);
        }

        fn getString(self: *Elf, str_off: u32) []const u8 {
            assert(str_off < self.shstrtab.items.len);
            return mem.spanZ(@ptrCast([*:0]const u8, self.shstrtab.items.ptr + str_off));
        }

        fn updateString(self: *Elf, old_str_off: u32, new_name: []const u8) !u32 {
            const existing_name = self.getString(old_str_off);
            if (mem.eql(u8, existing_name, new_name)) {
                return old_str_off;
            }
            return self.makeString(new_name);
        }

        pub fn populateMissingMetadata(self: *Elf) !void {
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
                const file_size = self.base.options.program_code_size_hint;
                const p_align = 0x1000;
                const off = self.findFreeSpace(file_size, p_align);
                std.log.debug(.link, "found PT_LOAD free space 0x{x} to 0x{x}\n", .{ off, off + file_size });
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
                const file_size = @as(u64, ptr_size) * self.base.options.symbol_count_hint;
                // We really only need ptr alignment but since we are using PROGBITS, linux requires
                // page align.
                const p_align = 0x1000;
                const off = self.findFreeSpace(file_size, p_align);
                std.log.debug(.link, "found PT_LOAD free space 0x{x} to 0x{x}\n", .{ off, off + file_size });
                // TODO instead of hard coding the vaddr, make a function to find a vaddr to put things at.
                // we'll need to re-use that function anyway, in case the GOT grows and overlaps something
                // else in virtual memory.
                const default_got_addr = 0x4000000;
                try self.program_headers.append(self.allocator, .{
                    .p_type = elf.PT_LOAD,
                    .p_offset = off,
                    .p_filesz = file_size,
                    .p_vaddr = default_got_addr,
                    .p_paddr = default_got_addr,
                    .p_memsz = file_size,
                    .p_align = p_align,
                    .p_flags = elf.PF_R,
                });
                self.phdr_table_dirty = true;
            }
            if (self.shstrtab_index == null) {
                self.shstrtab_index = @intCast(u16, self.sections.items.len);
                assert(self.shstrtab.items.len == 0);
                try self.shstrtab.append(self.allocator, 0); // need a 0 at position 0
                const off = self.findFreeSpace(self.shstrtab.items.len, 1);
                std.log.debug(.link, "found shstrtab free space 0x{x} to 0x{x}\n", .{ off, off + self.shstrtab.items.len });
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
                    .sh_entsize = 0,
                });
                self.shdr_table_dirty = true;
            }
            if (self.symtab_section_index == null) {
                self.symtab_section_index = @intCast(u16, self.sections.items.len);
                const min_align: u16 = if (small_ptr) @alignOf(elf.Elf32_Sym) else @alignOf(elf.Elf64_Sym);
                const each_size: u64 = if (small_ptr) @sizeOf(elf.Elf32_Sym) else @sizeOf(elf.Elf64_Sym);
                const file_size = self.base.options.symbol_count_hint * each_size;
                const off = self.findFreeSpace(file_size, min_align);
                std.log.debug(.link, "found symtab free space 0x{x} to 0x{x}\n", .{ off, off + file_size });

                try self.sections.append(self.allocator, .{
                    .sh_name = try self.makeString(".symtab"),
                    .sh_type = elf.SHT_SYMTAB,
                    .sh_flags = 0,
                    .sh_addr = 0,
                    .sh_offset = off,
                    .sh_size = file_size,
                    // The section header index of the associated string table.
                    .sh_link = self.shstrtab_index.?,
                    .sh_info = @intCast(u32, self.local_symbols.items.len),
                    .sh_addralign = min_align,
                    .sh_entsize = each_size,
                });
                self.shdr_table_dirty = true;
                try self.writeSymbol(0);
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
            {
                // Iterate over symbols, populating free_list and last_text_block.
                if (self.local_symbols.items.len != 1) {
                    @panic("TODO implement setting up free_list and last_text_block from existing ELF file");
                }
                // We are starting with an empty file. The default values are correct, null and empty list.
            }
        }

        /// Commit pending changes and write headers.
        pub fn flush(self: *Elf) !void {
            const foreign_endian = self.base.options.target.cpu.arch.endian() != std.Target.current.cpu.arch.endian();

            // Unfortunately these have to be buffered and done at the end because ELF does not allow
            // mixing local and global symbols within a symbol table.
            try self.writeAllGlobalSymbols();

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
                        try self.file.?.pwriteAll(mem.sliceAsBytes(buf), self.phdr_table_offset.?);
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
                        try self.file.?.pwriteAll(mem.sliceAsBytes(buf), self.phdr_table_offset.?);
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
                    std.log.debug(.link, "shstrtab start=0x{x} end=0x{x}\n", .{ shstrtab_sect.sh_offset, shstrtab_sect.sh_offset + needed_size });

                    try self.file.?.pwriteAll(self.shstrtab.items, shstrtab_sect.sh_offset);
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
                        try self.file.?.pwriteAll(mem.sliceAsBytes(buf), self.shdr_table_offset.?);
                    },
                    .p64 => {
                        const buf = try self.allocator.alloc(elf.Elf64_Shdr, self.sections.items.len);
                        defer self.allocator.free(buf);

                        for (buf) |*shdr, i| {
                            shdr.* = self.sections.items[i];
                            std.log.debug(.link, "writing section {}\n", .{shdr.*});
                            if (foreign_endian) {
                                bswapAllFields(elf.Elf64_Shdr, shdr);
                            }
                        }
                        try self.file.?.pwriteAll(mem.sliceAsBytes(buf), self.shdr_table_offset.?);
                    },
                }
                self.shdr_table_dirty = false;
            }
            if (self.entry_addr == null and self.base.options.output_mode == .Exe) {
                std.log.debug(.link, "no_entry_point_found = true\n", .{});
                self.error_flags.no_entry_point_found = true;
            } else {
                self.error_flags.no_entry_point_found = false;
                try self.writeElfHeader();
            }

            // The point of flush() is to commit changes, so nothing should be dirty after this.
            assert(!self.phdr_table_dirty);
            assert(!self.shdr_table_dirty);
            assert(!self.shstrtab_dirty);
            assert(!self.offset_table_count_dirty);
            const syms_sect = &self.sections.items[self.symtab_section_index.?];
            assert(syms_sect.sh_info == self.local_symbols.items.len);
        }

        fn writeElfHeader(self: *Elf) !void {
            var hdr_buf: [@sizeOf(elf.Elf64_Ehdr)]u8 = undefined;

            var index: usize = 0;
            hdr_buf[0..4].* = "\x7fELF".*;
            index += 4;

            hdr_buf[index] = switch (self.ptr_width) {
                .p32 => elf.ELFCLASS32,
                .p64 => elf.ELFCLASS64,
            };
            index += 1;

            const endian = self.base.options.target.cpu.arch.endian();
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

            const elf_type = switch (self.base.options.output_mode) {
                .Exe => elf.ET.EXEC,
                .Obj => elf.ET.REL,
                .Lib => switch (self.base.options.link_mode) {
                    .Static => elf.ET.REL,
                    .Dynamic => elf.ET.DYN,
                },
            };
            mem.writeInt(u16, hdr_buf[index..][0..2], @enumToInt(elf_type), endian);
            index += 2;

            const machine = self.base.options.target.cpu.arch.toElfMachine();
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

            try self.file.?.pwriteAll(hdr_buf[0..index], 0);
        }

        fn freeTextBlock(self: *Elf, text_block: *TextBlock) void {
            var already_have_free_list_node = false;
            {
                var i: usize = 0;
                while (i < self.text_block_free_list.items.len) {
                    if (self.text_block_free_list.items[i] == text_block) {
                        _ = self.text_block_free_list.swapRemove(i);
                        continue;
                    }
                    if (self.text_block_free_list.items[i] == text_block.prev) {
                        already_have_free_list_node = true;
                    }
                    i += 1;
                }
            }

            if (self.last_text_block == text_block) {
                // TODO shrink the .text section size here
                self.last_text_block = text_block.prev;
            }

            if (text_block.prev) |prev| {
                prev.next = text_block.next;

                if (!already_have_free_list_node and prev.freeListEligible(self.*)) {
                    // The free list is heuristics, it doesn't have to be perfect, so we can
                    // ignore the OOM here.
                    self.text_block_free_list.append(self.allocator, prev) catch {};
                }
            } else {
                text_block.prev = null;
            }

            if (text_block.next) |next| {
                next.prev = text_block.prev;
            } else {
                text_block.next = null;
            }
        }

        fn shrinkTextBlock(self: *Elf, text_block: *TextBlock, new_block_size: u64) void {
            // TODO check the new capacity, and if it crosses the size threshold into a big enough
            // capacity, insert a free list node for it.
        }

        fn growTextBlock(self: *Elf, text_block: *TextBlock, new_block_size: u64, alignment: u64) !u64 {
            const sym = self.local_symbols.items[text_block.local_sym_index];
            const align_ok = mem.alignBackwardGeneric(u64, sym.st_value, alignment) == sym.st_value;
            const need_realloc = !align_ok or new_block_size > text_block.capacity(self.*);
            if (!need_realloc) return sym.st_value;
            return self.allocateTextBlock(text_block, new_block_size, alignment);
        }

        fn allocateTextBlock(self: *Elf, text_block: *TextBlock, new_block_size: u64, alignment: u64) !u64 {
            const phdr = &self.program_headers.items[self.phdr_load_re_index.?];
            const shdr = &self.sections.items[self.text_section_index.?];
            const new_block_ideal_capacity = new_block_size * alloc_num / alloc_den;

            // We use these to indicate our intention to update metadata, placing the new block,
            // and possibly removing a free list node.
            // It would be simpler to do it inside the for loop below, but that would cause a
            // problem if an error was returned later in the function. So this action
            // is actually carried out at the end of the function, when errors are no longer possible.
            var block_placement: ?*TextBlock = null;
            var free_list_removal: ?usize = null;

            // First we look for an appropriately sized free list node.
            // The list is unordered. We'll just take the first thing that works.
            const vaddr = blk: {
                var i: usize = 0;
                while (i < self.text_block_free_list.items.len) {
                    const big_block = self.text_block_free_list.items[i];
                    // We now have a pointer to a live text block that has too much capacity.
                    // Is it enough that we could fit this new text block?
                    const sym = self.local_symbols.items[big_block.local_sym_index];
                    const capacity = big_block.capacity(self.*);
                    const ideal_capacity = capacity * alloc_num / alloc_den;
                    const ideal_capacity_end_vaddr = sym.st_value + ideal_capacity;
                    const capacity_end_vaddr = sym.st_value + capacity;
                    const new_start_vaddr_unaligned = capacity_end_vaddr - new_block_ideal_capacity;
                    const new_start_vaddr = mem.alignBackwardGeneric(u64, new_start_vaddr_unaligned, alignment);
                    if (new_start_vaddr < ideal_capacity_end_vaddr) {
                        // Additional bookkeeping here to notice if this free list node
                        // should be deleted because the block that it points to has grown to take up
                        // more of the extra capacity.
                        if (!big_block.freeListEligible(self.*)) {
                            _ = self.text_block_free_list.swapRemove(i);
                        } else {
                            i += 1;
                        }
                        continue;
                    }
                    // At this point we know that we will place the new block here. But the
                    // remaining question is whether there is still yet enough capacity left
                    // over for there to still be a free list node.
                    const remaining_capacity = new_start_vaddr - ideal_capacity_end_vaddr;
                    const keep_free_list_node = remaining_capacity >= min_text_capacity;

                    // Set up the metadata to be updated, after errors are no longer possible.
                    block_placement = big_block;
                    if (!keep_free_list_node) {
                        free_list_removal = i;
                    }
                    break :blk new_start_vaddr;
                } else if (self.last_text_block) |last| {
                    const sym = self.local_symbols.items[last.local_sym_index];
                    const ideal_capacity = sym.st_size * alloc_num / alloc_den;
                    const ideal_capacity_end_vaddr = sym.st_value + ideal_capacity;
                    const new_start_vaddr = mem.alignForwardGeneric(u64, ideal_capacity_end_vaddr, alignment);
                    // Set up the metadata to be updated, after errors are no longer possible.
                    block_placement = last;
                    break :blk new_start_vaddr;
                } else {
                    break :blk phdr.p_vaddr;
                }
            };

            const expand_text_section = block_placement == null or block_placement.?.next == null;
            if (expand_text_section) {
                const text_capacity = self.allocatedSize(shdr.sh_offset);
                const needed_size = (vaddr + new_block_size) - phdr.p_vaddr;
                if (needed_size > text_capacity) {
                    // Must move the entire text section.
                    const new_offset = self.findFreeSpace(needed_size, 0x1000);
                    const text_size = if (self.last_text_block) |last| blk: {
                        const sym = self.local_symbols.items[last.local_sym_index];
                        break :blk (sym.st_value + sym.st_size) - phdr.p_vaddr;
                    } else 0;
                    const amt = try self.file.?.copyRangeAll(shdr.sh_offset, self.file.?, new_offset, text_size);
                    if (amt != text_size) return error.InputOutput;
                    shdr.sh_offset = new_offset;
                    phdr.p_offset = new_offset;
                }
                self.last_text_block = text_block;

                shdr.sh_size = needed_size;
                phdr.p_memsz = needed_size;
                phdr.p_filesz = needed_size;

                self.phdr_table_dirty = true; // TODO look into making only the one program header dirty
                self.shdr_table_dirty = true; // TODO look into making only the one section dirty
            }

            // This function can also reallocate a text block.
            // In this case we need to "unplug" it from its previous location before
            // plugging it in to its new location.
            if (text_block.prev) |prev| {
                prev.next = text_block.next;
            }
            if (text_block.next) |next| {
                next.prev = text_block.prev;
            }

            if (block_placement) |big_block| {
                text_block.prev = big_block;
                text_block.next = big_block.next;
                big_block.next = text_block;
            } else {
                text_block.prev = null;
                text_block.next = null;
            }
            if (free_list_removal) |i| {
                _ = self.text_block_free_list.swapRemove(i);
            }
            return vaddr;
        }

        pub fn allocateDeclIndexes(self: *Elf, decl: *Module.Decl) !void {
            if (decl.link.local_sym_index != 0) return;

            // Here we also ensure capacity for the free lists so that they can be appended to without fail.
            try self.local_symbols.ensureCapacity(self.allocator, self.local_symbols.items.len + 1);
            try self.local_symbol_free_list.ensureCapacity(self.allocator, self.local_symbols.items.len);
            try self.offset_table.ensureCapacity(self.allocator, self.offset_table.items.len + 1);
            try self.offset_table_free_list.ensureCapacity(self.allocator, self.local_symbols.items.len);

            if (self.local_symbol_free_list.popOrNull()) |i| {
                std.log.debug(.link, "reusing symbol index {} for {}\n", .{ i, decl.name });
                decl.link.local_sym_index = i;
            } else {
                std.log.debug(.link, "allocating symbol index {} for {}\n", .{ self.local_symbols.items.len, decl.name });
                decl.link.local_sym_index = @intCast(u32, self.local_symbols.items.len);
                _ = self.local_symbols.addOneAssumeCapacity();
            }

            if (self.offset_table_free_list.popOrNull()) |i| {
                decl.link.offset_table_index = i;
            } else {
                decl.link.offset_table_index = @intCast(u32, self.offset_table.items.len);
                _ = self.offset_table.addOneAssumeCapacity();
                self.offset_table_count_dirty = true;
            }

            const phdr = &self.program_headers.items[self.phdr_load_re_index.?];

            self.local_symbols.items[decl.link.local_sym_index] = .{
                .st_name = 0,
                .st_info = 0,
                .st_other = 0,
                .st_shndx = 0,
                .st_value = phdr.p_vaddr,
                .st_size = 0,
            };
            self.offset_table.items[decl.link.offset_table_index] = 0;
        }

        pub fn freeDecl(self: *Elf, decl: *Module.Decl) void {
            self.freeTextBlock(&decl.link);
            if (decl.link.local_sym_index != 0) {
                self.local_symbol_free_list.appendAssumeCapacity(decl.link.local_sym_index);
                self.offset_table_free_list.appendAssumeCapacity(decl.link.offset_table_index);

                self.local_symbols.items[decl.link.local_sym_index].st_info = 0;

                decl.link.local_sym_index = 0;
            }
        }

        pub fn updateDecl(self: *Elf, module: *Module, decl: *Module.Decl) !void {
            var code_buffer = std.ArrayList(u8).init(self.allocator);
            defer code_buffer.deinit();

            const typed_value = decl.typed_value.most_recent.typed_value;
            const code = switch (try codegen.generateSymbol(self, decl.src(), typed_value, &code_buffer)) {
                .externally_managed => |x| x,
                .appended => code_buffer.items,
                .fail => |em| {
                    decl.analysis = .codegen_failure;
                    try module.failed_decls.put(module.gpa, decl, em);
                    return;
                },
            };

            const required_alignment = typed_value.ty.abiAlignment(self.base.options.target);

            const stt_bits: u8 = switch (typed_value.ty.zigTypeTag()) {
                .Fn => elf.STT_FUNC,
                else => elf.STT_OBJECT,
            };

            assert(decl.link.local_sym_index != 0); // Caller forgot to allocateDeclIndexes()
            const local_sym = &self.local_symbols.items[decl.link.local_sym_index];
            if (local_sym.st_size != 0) {
                const capacity = decl.link.capacity(self.*);
                const need_realloc = code.len > capacity or
                    !mem.isAlignedGeneric(u64, local_sym.st_value, required_alignment);
                if (need_realloc) {
                    const vaddr = try self.growTextBlock(&decl.link, code.len, required_alignment);
                    std.log.debug(.link, "growing {} from 0x{x} to 0x{x}\n", .{ decl.name, local_sym.st_value, vaddr });
                    if (vaddr != local_sym.st_value) {
                        local_sym.st_value = vaddr;

                        std.log.debug(.link, "  (writing new offset table entry)\n", .{});
                        self.offset_table.items[decl.link.offset_table_index] = vaddr;
                        try self.writeOffsetTableEntry(decl.link.offset_table_index);
                    }
                } else if (code.len < local_sym.st_size) {
                    self.shrinkTextBlock(&decl.link, code.len);
                }
                local_sym.st_size = code.len;
                local_sym.st_name = try self.updateString(local_sym.st_name, mem.spanZ(decl.name));
                local_sym.st_info = (elf.STB_LOCAL << 4) | stt_bits;
                local_sym.st_other = 0;
                local_sym.st_shndx = self.text_section_index.?;
                // TODO this write could be avoided if no fields of the symbol were changed.
                try self.writeSymbol(decl.link.local_sym_index);
            } else {
                const decl_name = mem.spanZ(decl.name);
                const name_str_index = try self.makeString(decl_name);
                const vaddr = try self.allocateTextBlock(&decl.link, code.len, required_alignment);
                std.log.debug(.link, "allocated text block for {} at 0x{x}\n", .{ decl_name, vaddr });
                errdefer self.freeTextBlock(&decl.link);

                local_sym.* = .{
                    .st_name = name_str_index,
                    .st_info = (elf.STB_LOCAL << 4) | stt_bits,
                    .st_other = 0,
                    .st_shndx = self.text_section_index.?,
                    .st_value = vaddr,
                    .st_size = code.len,
                };
                self.offset_table.items[decl.link.offset_table_index] = vaddr;

                try self.writeSymbol(decl.link.local_sym_index);
                try self.writeOffsetTableEntry(decl.link.offset_table_index);
            }

            const section_offset = local_sym.st_value - self.program_headers.items[self.phdr_load_re_index.?].p_vaddr;
            const file_offset = self.sections.items[self.text_section_index.?].sh_offset + section_offset;
            try self.file.?.pwriteAll(code, file_offset);

            // Since we updated the vaddr and the size, each corresponding export symbol also needs to be updated.
            const decl_exports = module.decl_exports.get(decl) orelse &[0]*Module.Export{};
            return self.updateDeclExports(module, decl, decl_exports);
        }

        /// Must be called only after a successful call to `updateDecl`.
        pub fn updateDeclExports(
            self: *Elf,
            module: *Module,
            decl: *const Module.Decl,
            exports: []const *Module.Export,
        ) !void {
            // In addition to ensuring capacity for global_symbols, we also ensure capacity for freeing all of
            // them, so that deleting exports is guaranteed to succeed.
            try self.global_symbols.ensureCapacity(self.allocator, self.global_symbols.items.len + exports.len);
            try self.global_symbol_free_list.ensureCapacity(self.allocator, self.global_symbols.items.len);
            const typed_value = decl.typed_value.most_recent.typed_value;
            if (decl.link.local_sym_index == 0) return;
            const decl_sym = self.local_symbols.items[decl.link.local_sym_index];

            for (exports) |exp| {
                if (exp.options.section) |section_name| {
                    if (!mem.eql(u8, section_name, ".text")) {
                        try module.failed_exports.ensureCapacity(module.gpa, module.failed_exports.items().len + 1);
                        module.failed_exports.putAssumeCapacityNoClobber(
                            exp,
                            try Module.ErrorMsg.create(self.allocator, 0, "Unimplemented: ExportOptions.section", .{}),
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
                        try module.failed_exports.ensureCapacity(module.gpa, module.failed_exports.items().len + 1);
                        module.failed_exports.putAssumeCapacityNoClobber(
                            exp,
                            try Module.ErrorMsg.create(self.allocator, 0, "Unimplemented: GlobalLinkage.LinkOnce", .{}),
                        );
                        continue;
                    },
                };
                const stt_bits: u8 = @truncate(u4, decl_sym.st_info);
                if (exp.link.sym_index) |i| {
                    const sym = &self.global_symbols.items[i];
                    sym.* = .{
                        .st_name = try self.updateString(sym.st_name, exp.options.name),
                        .st_info = (stb_bits << 4) | stt_bits,
                        .st_other = 0,
                        .st_shndx = self.text_section_index.?,
                        .st_value = decl_sym.st_value,
                        .st_size = decl_sym.st_size,
                    };
                } else {
                    const name = try self.makeString(exp.options.name);
                    const i = if (self.global_symbol_free_list.popOrNull()) |i| i else blk: {
                        _ = self.global_symbols.addOneAssumeCapacity();
                        break :blk self.global_symbols.items.len - 1;
                    };
                    self.global_symbols.items[i] = .{
                        .st_name = name,
                        .st_info = (stb_bits << 4) | stt_bits,
                        .st_other = 0,
                        .st_shndx = self.text_section_index.?,
                        .st_value = decl_sym.st_value,
                        .st_size = decl_sym.st_size,
                    };

                    exp.link.sym_index = @intCast(u32, i);
                }
            }
        }

        pub fn deleteExport(self: *Elf, exp: Export) void {
            const sym_index = exp.sym_index orelse return;
            self.global_symbol_free_list.appendAssumeCapacity(sym_index);
            self.global_symbols.items[sym_index].st_info = 0;
        }

        fn writeProgHeader(self: *Elf, index: usize) !void {
            const foreign_endian = self.base.options.target.cpu.arch.endian() != std.Target.current.cpu.arch.endian();
            const offset = self.program_headers.items[index].p_offset;
            switch (self.base.options.target.cpu.arch.ptrBitWidth()) {
                32 => {
                    var phdr = [1]elf.Elf32_Phdr{progHeaderTo32(self.program_headers.items[index])};
                    if (foreign_endian) {
                        bswapAllFields(elf.Elf32_Phdr, &phdr[0]);
                    }
                    return self.file.?.pwriteAll(mem.sliceAsBytes(&phdr), offset);
                },
                64 => {
                    var phdr = [1]elf.Elf64_Phdr{self.program_headers.items[index]};
                    if (foreign_endian) {
                        bswapAllFields(elf.Elf64_Phdr, &phdr[0]);
                    }
                    return self.file.?.pwriteAll(mem.sliceAsBytes(&phdr), offset);
                },
                else => return error.UnsupportedArchitecture,
            }
        }

        fn writeSectHeader(self: *Elf, index: usize) !void {
            const foreign_endian = self.base.options.target.cpu.arch.endian() != std.Target.current.cpu.arch.endian();
            const offset = self.sections.items[index].sh_offset;
            switch (self.base.options.target.cpu.arch.ptrBitWidth()) {
                32 => {
                    var shdr: [1]elf.Elf32_Shdr = undefined;
                    shdr[0] = sectHeaderTo32(self.sections.items[index]);
                    if (foreign_endian) {
                        bswapAllFields(elf.Elf32_Shdr, &shdr[0]);
                    }
                    return self.file.?.pwriteAll(mem.sliceAsBytes(&shdr), offset);
                },
                64 => {
                    var shdr = [1]elf.Elf64_Shdr{self.sections.items[index]};
                    if (foreign_endian) {
                        bswapAllFields(elf.Elf64_Shdr, &shdr[0]);
                    }
                    return self.file.?.pwriteAll(mem.sliceAsBytes(&shdr), offset);
                },
                else => return error.UnsupportedArchitecture,
            }
        }

        fn writeOffsetTableEntry(self: *Elf, index: usize) !void {
            const shdr = &self.sections.items[self.got_section_index.?];
            const phdr = &self.program_headers.items[self.phdr_got_index.?];
            const entry_size: u16 = switch (self.ptr_width) {
                .p32 => 4,
                .p64 => 8,
            };
            if (self.offset_table_count_dirty) {
                // TODO Also detect virtual address collisions.
                const allocated_size = self.allocatedSize(shdr.sh_offset);
                const needed_size = self.local_symbols.items.len * entry_size;
                if (needed_size > allocated_size) {
                    // Must move the entire got section.
                    const new_offset = self.findFreeSpace(needed_size, entry_size);
                    const amt = try self.file.?.copyRangeAll(shdr.sh_offset, self.file.?, new_offset, shdr.sh_size);
                    if (amt != shdr.sh_size) return error.InputOutput;
                    shdr.sh_offset = new_offset;
                    phdr.p_offset = new_offset;
                }
                shdr.sh_size = needed_size;
                phdr.p_memsz = needed_size;
                phdr.p_filesz = needed_size;

                self.shdr_table_dirty = true; // TODO look into making only the one section dirty
                self.phdr_table_dirty = true; // TODO look into making only the one program header dirty

                self.offset_table_count_dirty = false;
            }
            const endian = self.base.options.target.cpu.arch.endian();
            const off = shdr.sh_offset + @as(u64, entry_size) * index;
            switch (self.ptr_width) {
                .p32 => {
                    var buf: [4]u8 = undefined;
                    mem.writeInt(u32, &buf, @intCast(u32, self.offset_table.items[index]), endian);
                    try self.file.?.pwriteAll(&buf, off);
                },
                .p64 => {
                    var buf: [8]u8 = undefined;
                    mem.writeInt(u64, &buf, self.offset_table.items[index], endian);
                    try self.file.?.pwriteAll(&buf, off);
                },
            }
        }

        fn writeSymbol(self: *Elf, index: usize) !void {
            const syms_sect = &self.sections.items[self.symtab_section_index.?];
            // Make sure we are not pointlessly writing symbol data that will have to get relocated
            // due to running out of space.
            if (self.local_symbols.items.len != syms_sect.sh_info) {
                const sym_size: u64 = switch (self.ptr_width) {
                    .p32 => @sizeOf(elf.Elf32_Sym),
                    .p64 => @sizeOf(elf.Elf64_Sym),
                };
                const sym_align: u16 = switch (self.ptr_width) {
                    .p32 => @alignOf(elf.Elf32_Sym),
                    .p64 => @alignOf(elf.Elf64_Sym),
                };
                const needed_size = (self.local_symbols.items.len + self.global_symbols.items.len) * sym_size;
                if (needed_size > self.allocatedSize(syms_sect.sh_offset)) {
                    // Move all the symbols to a new file location.
                    const new_offset = self.findFreeSpace(needed_size, sym_align);
                    const existing_size = @as(u64, syms_sect.sh_info) * sym_size;
                    const amt = try self.file.?.copyRangeAll(syms_sect.sh_offset, self.file.?, new_offset, existing_size);
                    if (amt != existing_size) return error.InputOutput;
                    syms_sect.sh_offset = new_offset;
                }
                syms_sect.sh_info = @intCast(u32, self.local_symbols.items.len);
                syms_sect.sh_size = needed_size; // anticipating adding the global symbols later
                self.shdr_table_dirty = true; // TODO look into only writing one section
            }
            const foreign_endian = self.base.options.target.cpu.arch.endian() != std.Target.current.cpu.arch.endian();
            switch (self.ptr_width) {
                .p32 => {
                    var sym = [1]elf.Elf32_Sym{
                        .{
                            .st_name = self.local_symbols.items[index].st_name,
                            .st_value = @intCast(u32, self.local_symbols.items[index].st_value),
                            .st_size = @intCast(u32, self.local_symbols.items[index].st_size),
                            .st_info = self.local_symbols.items[index].st_info,
                            .st_other = self.local_symbols.items[index].st_other,
                            .st_shndx = self.local_symbols.items[index].st_shndx,
                        },
                    };
                    if (foreign_endian) {
                        bswapAllFields(elf.Elf32_Sym, &sym[0]);
                    }
                    const off = syms_sect.sh_offset + @sizeOf(elf.Elf32_Sym) * index;
                    try self.file.?.pwriteAll(mem.sliceAsBytes(sym[0..1]), off);
                },
                .p64 => {
                    var sym = [1]elf.Elf64_Sym{self.local_symbols.items[index]};
                    if (foreign_endian) {
                        bswapAllFields(elf.Elf64_Sym, &sym[0]);
                    }
                    const off = syms_sect.sh_offset + @sizeOf(elf.Elf64_Sym) * index;
                    try self.file.?.pwriteAll(mem.sliceAsBytes(sym[0..1]), off);
                },
            }
        }

        fn writeAllGlobalSymbols(self: *Elf) !void {
            const syms_sect = &self.sections.items[self.symtab_section_index.?];
            const sym_size: u64 = switch (self.ptr_width) {
                .p32 => @sizeOf(elf.Elf32_Sym),
                .p64 => @sizeOf(elf.Elf64_Sym),
            };
            const foreign_endian = self.base.options.target.cpu.arch.endian() != std.Target.current.cpu.arch.endian();
            const global_syms_off = syms_sect.sh_offset + self.local_symbols.items.len * sym_size;
            switch (self.ptr_width) {
                .p32 => {
                    const buf = try self.allocator.alloc(elf.Elf32_Sym, self.global_symbols.items.len);
                    defer self.allocator.free(buf);

                    for (buf) |*sym, i| {
                        sym.* = .{
                            .st_name = self.global_symbols.items[i].st_name,
                            .st_value = @intCast(u32, self.global_symbols.items[i].st_value),
                            .st_size = @intCast(u32, self.global_symbols.items[i].st_size),
                            .st_info = self.global_symbols.items[i].st_info,
                            .st_other = self.global_symbols.items[i].st_other,
                            .st_shndx = self.global_symbols.items[i].st_shndx,
                        };
                        if (foreign_endian) {
                            bswapAllFields(elf.Elf32_Sym, sym);
                        }
                    }
                    try self.file.?.pwriteAll(mem.sliceAsBytes(buf), global_syms_off);
                },
                .p64 => {
                    const buf = try self.allocator.alloc(elf.Elf64_Sym, self.global_symbols.items.len);
                    defer self.allocator.free(buf);

                    for (buf) |*sym, i| {
                        sym.* = .{
                            .st_name = self.global_symbols.items[i].st_name,
                            .st_value = self.global_symbols.items[i].st_value,
                            .st_size = self.global_symbols.items[i].st_size,
                            .st_info = self.global_symbols.items[i].st_info,
                            .st_other = self.global_symbols.items[i].st_other,
                            .st_shndx = self.global_symbols.items[i].st_shndx,
                        };
                        if (foreign_endian) {
                            bswapAllFields(elf.Elf64_Sym, sym);
                        }
                    }
                    try self.file.?.pwriteAll(mem.sliceAsBytes(buf), global_syms_off);
                },
            }
        }
    };
};

/// Truncates the existing file contents and overwrites the contents.
/// Returns an error if `file` is not already open with +read +write +seek abilities.
pub fn createElfFile(allocator: *Allocator, file: fs.File, options: Options) !File.Elf {
    switch (options.output_mode) {
        .Exe => {},
        .Obj => {},
        .Lib => return error.TODOImplementWritingLibFiles,
    }
    switch (options.object_format) {
        .c => unreachable,
        .unknown => unreachable, // TODO remove this tag from the enum
        .coff => return error.TODOImplementWritingCOFF,
        .elf => {},
        .macho => return error.TODOImplementWritingMachO,
        .wasm => return error.TODOImplementWritingWasmObjects,
        .hex => return error.TODOImplementWritingHex,
        .raw => return error.TODOImplementWritingRaw,
    }

    var self: File.Elf = .{
        .base = .{
            .tag = .elf,
            .options = options,
        },
        .allocator = allocator,
        .file = file,
        .ptr_width = switch (options.target.cpu.arch.ptrBitWidth()) {
            32 => .p32,
            64 => .p64,
            else => return error.UnsupportedELFArchitecture,
        },
        .shdr_table_dirty = true,
        .owns_file_handle = false,
    };
    errdefer self.deinit();

    // Index 0 is always a null symbol.
    try self.local_symbols.append(allocator, .{
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
fn openBinFileInner(allocator: *Allocator, file: fs.File, options: Options) !File.Elf {
    switch (options.output_mode) {
        .Exe => {},
        .Obj => {},
        .Lib => return error.IncrFailed,
    }
    switch (options.object_format) {
        .unknown => unreachable, // TODO remove this tag from the enum
        .c => unreachable,
        .coff => return error.IncrFailed,
        .elf => {},
        .macho => return error.IncrFailed,
        .wasm => return error.IncrFailed,
        .hex => return error.IncrFailed,
        .raw => return error.IncrFailed,
    }
    var self: File.Elf = .{
        .base = .{
            .tag = .elf,
            .options = options,
        },
        .allocator = allocator,
        .file = file,
        .owns_file_handle = false,
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
fn satMul(a: anytype, b: anytype) @TypeOf(a, b) {
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
