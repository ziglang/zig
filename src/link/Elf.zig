const Elf = @This();

const std = @import("std");
const builtin = @import("builtin");
const math = std.math;
const mem = std.mem;
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const fs = std.fs;
const elf = std.elf;
const log = std.log.scoped(.link);

const Module = @import("../Module.zig");
const Compilation = @import("../Compilation.zig");
const Dwarf = @import("Dwarf.zig");
const codegen = @import("../codegen.zig");
const lldMain = @import("../main.zig").lldMain;
const trace = @import("../tracy.zig").trace;
const Package = @import("../Package.zig");
const Value = @import("../value.zig").Value;
const Type = @import("../type.zig").Type;
const TypedValue = @import("../TypedValue.zig");
const link = @import("../link.zig");
const File = link.File;
const build_options = @import("build_options");
const target_util = @import("../target.zig");
const glibc = @import("../glibc.zig");
const musl = @import("../musl.zig");
const Cache = @import("../Cache.zig");
const Air = @import("../Air.zig");
const Liveness = @import("../Liveness.zig");
const LlvmObject = @import("../codegen/llvm.zig").Object;

const default_entry_addr = 0x8000000;

pub const base_tag: File.Tag = .elf;

base: File,
dwarf: ?Dwarf = null,

ptr_width: PtrWidth,

/// If this is not null, an object file is created by LLVM and linked with LLD afterwards.
llvm_object: ?*LlvmObject = null,

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
/// The index into the program headers of a PT_LOAD program header with Read flag
phdr_load_ro_index: ?u16 = null,
/// The index into the program headers of a PT_LOAD program header with Write flag
phdr_load_rw_index: ?u16 = null,

phdr_shdr_table: std.AutoHashMapUnmanaged(u16, u16) = .{},

entry_addr: ?u64 = null,
page_size: u32,

shstrtab: std.ArrayListUnmanaged(u8) = std.ArrayListUnmanaged(u8){},
shstrtab_index: ?u16 = null,

symtab_section_index: ?u16 = null,
text_section_index: ?u16 = null,
rodata_section_index: ?u16 = null,
got_section_index: ?u16 = null,
data_section_index: ?u16 = null,
debug_info_section_index: ?u16 = null,
debug_abbrev_section_index: ?u16 = null,
debug_str_section_index: ?u16 = null,
debug_aranges_section_index: ?u16 = null,
debug_line_section_index: ?u16 = null,

/// The same order as in the file. ELF requires global symbols to all be after the
/// local symbols, they cannot be mixed. So we must buffer all the global symbols and
/// write them at the end. These are only the local symbols. The length of this array
/// is the value used for sh_info in the .symtab section.
local_symbols: std.ArrayListUnmanaged(elf.Elf64_Sym) = .{},
global_symbols: std.ArrayListUnmanaged(elf.Elf64_Sym) = .{},

local_symbol_free_list: std.ArrayListUnmanaged(u32) = .{},
global_symbol_free_list: std.ArrayListUnmanaged(u32) = .{},
offset_table_free_list: std.ArrayListUnmanaged(u32) = .{},

/// Same order as in the file. The value is the absolute vaddr value.
/// If the vaddr of the executable program header changes, the entire
/// offset table needs to be rewritten.
offset_table: std.ArrayListUnmanaged(u64) = .{},

phdr_table_dirty: bool = false,
shdr_table_dirty: bool = false,
shstrtab_dirty: bool = false,
offset_table_count_dirty: bool = false,

debug_strtab_dirty: bool = false,
debug_abbrev_section_dirty: bool = false,
debug_aranges_section_dirty: bool = false,
debug_info_header_dirty: bool = false,
debug_line_header_dirty: bool = false,

error_flags: File.ErrorFlags = File.ErrorFlags{},

/// Pointer to the last allocated atom
atoms: std.AutoHashMapUnmanaged(u16, *TextBlock) = .{},

/// A list of text blocks that have surplus capacity. This list can have false
/// positives, as functions grow and shrink over time, only sometimes being added
/// or removed from the freelist.
///
/// A text block has surplus capacity when its overcapacity value is greater than
/// padToIdeal(minimum_text_block_size). That is, when it has so
/// much extra capacity, that we could fit a small new symbol in it, itself with
/// ideal_capacity or more.
///
/// Ideal capacity is defined by size + (size / ideal_factor)
///
/// Overcapacity is measured by actual_capacity - ideal_capacity. Note that
/// overcapacity can be negative. A simple way to have negative overcapacity is to
/// allocate a fresh text block, which will have ideal capacity, and then grow it
/// by 1 byte. It will then have -1 overcapacity.
atom_free_lists: std.AutoHashMapUnmanaged(u16, std.ArrayListUnmanaged(*TextBlock)) = .{},

/// Table of Decls that are currently alive.
/// We store them here so that we can properly dispose of any allocated
/// memory within the atom in the incremental linker.
/// TODO consolidate this.
decls: std.AutoHashMapUnmanaged(Module.Decl.Index, ?u16) = .{},

/// List of atoms that are owned directly by the linker.
/// Currently these are only atoms that are the result of linking
/// object files. Atoms which take part in incremental linking are
/// at present owned by Module.Decl.
/// TODO consolidate this.
managed_atoms: std.ArrayListUnmanaged(*TextBlock) = .{},
atom_by_index_table: std.AutoHashMapUnmanaged(u32, *TextBlock) = .{},

/// Table of unnamed constants associated with a parent `Decl`.
/// We store them here so that we can free the constants whenever the `Decl`
/// needs updating or is freed.
///
/// For example,
///
/// ```zig
/// const Foo = struct{
///     a: u8,
/// };
///
/// pub fn main() void {
///     var foo = Foo{ .a = 1 };
///     _ = foo;
/// }
/// ```
///
/// value assigned to label `foo` is an unnamed constant belonging/associated
/// with `Decl` `main`, and lives as long as that `Decl`.
unnamed_const_atoms: UnnamedConstTable = .{},

/// A table of relocations indexed by the owning them `TextBlock`.
/// Note that once we refactor `TextBlock`'s lifetime and ownership rules,
/// this will be a table indexed by index into the list of Atoms.
relocs: RelocTable = .{},

const Reloc = struct {
    target: u32,
    offset: u64,
    addend: u32,
    prev_vaddr: u64,
};

const RelocTable = std.AutoHashMapUnmanaged(*TextBlock, std.ArrayListUnmanaged(Reloc));
const UnnamedConstTable = std.AutoHashMapUnmanaged(Module.Decl.Index, std.ArrayListUnmanaged(*TextBlock));

/// When allocating, the ideal_capacity is calculated by
/// actual_capacity + (actual_capacity / ideal_factor)
const ideal_factor = 3;

/// In order for a slice of bytes to be considered eligible to keep metadata pointing at
/// it as a possible place to put new symbols, it must have enough room for this many bytes
/// (plus extra for reserved capacity).
const minimum_text_block_size = 64;
const min_text_capacity = padToIdeal(minimum_text_block_size);

pub const PtrWidth = enum { p32, p64 };

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

    dbg_info_atom: Dwarf.Atom,

    pub const empty = TextBlock{
        .local_sym_index = 0,
        .offset_table_index = undefined,
        .prev = null,
        .next = null,
        .dbg_info_atom = undefined,
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
        const ideal_cap = padToIdeal(self_sym.st_size);
        if (cap <= ideal_cap) return false;
        const surplus = cap - ideal_cap;
        return surplus >= min_text_capacity;
    }
};

pub const Export = struct {
    sym_index: ?u32 = null,
};

pub fn openPath(allocator: Allocator, sub_path: []const u8, options: link.Options) !*Elf {
    assert(options.object_format == .elf);

    if (build_options.have_llvm and options.use_llvm) {
        return createEmpty(allocator, options);
    }

    const self = try createEmpty(allocator, options);
    errdefer self.base.destroy();

    const file = try options.emit.?.directory.handle.createFile(sub_path, .{
        .truncate = false,
        .read = true,
        .mode = link.determineMode(options),
    });

    self.base.file = file;
    self.shdr_table_dirty = true;

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

pub fn createEmpty(gpa: Allocator, options: link.Options) !*Elf {
    const ptr_width: PtrWidth = switch (options.target.cpu.arch.ptrBitWidth()) {
        0...32 => .p32,
        33...64 => .p64,
        else => return error.UnsupportedELFArchitecture,
    };
    const self = try gpa.create(Elf);
    errdefer gpa.destroy(self);

    const page_size: u32 = switch (options.target.cpu.arch) {
        .powerpc64le => 0x10000,
        .sparc64 => 0x2000,
        else => 0x1000,
    };

    var dwarf: ?Dwarf = if (!options.strip and options.module != null)
        Dwarf.init(gpa, .elf, options.target)
    else
        null;

    self.* = .{
        .base = .{
            .tag = .elf,
            .options = options,
            .allocator = gpa,
            .file = null,
        },
        .dwarf = dwarf,
        .ptr_width = ptr_width,
        .page_size = page_size,
    };
    const use_llvm = build_options.have_llvm and options.use_llvm;
    const use_stage1 = build_options.is_stage1 and options.use_stage1;
    if (use_llvm and !use_stage1) {
        self.llvm_object = try LlvmObject.create(gpa, options);
    }
    return self;
}

pub fn deinit(self: *Elf) void {
    if (build_options.have_llvm) {
        if (self.llvm_object) |llvm_object| llvm_object.destroy(self.base.allocator);
    }

    self.sections.deinit(self.base.allocator);
    self.program_headers.deinit(self.base.allocator);
    self.shstrtab.deinit(self.base.allocator);
    self.local_symbols.deinit(self.base.allocator);
    self.global_symbols.deinit(self.base.allocator);
    self.global_symbol_free_list.deinit(self.base.allocator);
    self.local_symbol_free_list.deinit(self.base.allocator);
    self.offset_table_free_list.deinit(self.base.allocator);
    self.offset_table.deinit(self.base.allocator);
    self.phdr_shdr_table.deinit(self.base.allocator);
    self.decls.deinit(self.base.allocator);

    self.atoms.deinit(self.base.allocator);
    {
        var it = self.atom_free_lists.valueIterator();
        while (it.next()) |free_list| {
            free_list.deinit(self.base.allocator);
        }
        self.atom_free_lists.deinit(self.base.allocator);
    }

    for (self.managed_atoms.items) |atom| {
        self.base.allocator.destroy(atom);
    }
    self.managed_atoms.deinit(self.base.allocator);

    {
        var it = self.unnamed_const_atoms.valueIterator();
        while (it.next()) |atoms| {
            atoms.deinit(self.base.allocator);
        }
        self.unnamed_const_atoms.deinit(self.base.allocator);
    }

    {
        var it = self.relocs.valueIterator();
        while (it.next()) |relocs| {
            relocs.deinit(self.base.allocator);
        }
        self.relocs.deinit(self.base.allocator);
    }

    self.atom_by_index_table.deinit(self.base.allocator);

    if (self.dwarf) |*dw| {
        dw.deinit();
    }
}

pub fn getDeclVAddr(self: *Elf, decl_index: Module.Decl.Index, reloc_info: File.RelocInfo) !u64 {
    const mod = self.base.options.module.?;
    const decl = mod.declPtr(decl_index);

    assert(self.llvm_object == null);
    assert(decl.link.elf.local_sym_index != 0);

    const target = decl.link.elf.local_sym_index;
    const vaddr = self.local_symbols.items[target].st_value;
    const atom = self.atom_by_index_table.get(reloc_info.parent_atom_index).?;
    const gop = try self.relocs.getOrPut(self.base.allocator, atom);
    if (!gop.found_existing) {
        gop.value_ptr.* = .{};
    }
    try gop.value_ptr.append(self.base.allocator, .{
        .target = target,
        .offset = reloc_info.offset,
        .addend = reloc_info.addend,
        .prev_vaddr = vaddr,
    });

    return vaddr;
}

/// Returns end pos of collision, if any.
fn detectAllocCollision(self: *Elf, start: u64, size: u64) ?u64 {
    const small_ptr = self.ptr_width == .p32;
    const ehdr_size: u64 = if (small_ptr) @sizeOf(elf.Elf32_Ehdr) else @sizeOf(elf.Elf64_Ehdr);
    if (start < ehdr_size)
        return ehdr_size;

    const end = start + padToIdeal(size);

    if (self.shdr_table_offset) |off| {
        const shdr_size: u64 = if (small_ptr) @sizeOf(elf.Elf32_Shdr) else @sizeOf(elf.Elf64_Shdr);
        const tight_size = self.sections.items.len * shdr_size;
        const increased_size = padToIdeal(tight_size);
        const test_end = off + increased_size;
        if (end > off and start < test_end) {
            return test_end;
        }
    }

    if (self.phdr_table_offset) |off| {
        const phdr_size: u64 = if (small_ptr) @sizeOf(elf.Elf32_Phdr) else @sizeOf(elf.Elf64_Phdr);
        const tight_size = self.sections.items.len * phdr_size;
        const increased_size = padToIdeal(tight_size);
        const test_end = off + increased_size;
        if (end > off and start < test_end) {
            return test_end;
        }
    }

    for (self.sections.items) |section| {
        const increased_size = padToIdeal(section.sh_size);
        const test_end = section.sh_offset + increased_size;
        if (end > section.sh_offset and start < test_end) {
            return test_end;
        }
    }
    for (self.program_headers.items) |program_header| {
        const increased_size = padToIdeal(program_header.p_filesz);
        const test_end = program_header.p_offset + increased_size;
        if (end > program_header.p_offset and start < test_end) {
            return test_end;
        }
    }
    return null;
}

pub fn allocatedSize(self: *Elf, start: u64) u64 {
    if (start == 0)
        return 0;
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

pub fn findFreeSpace(self: *Elf, object_size: u64, min_alignment: u32) u64 {
    var start: u64 = 0;
    while (self.detectAllocCollision(start, object_size)) |item_end| {
        start = mem.alignForwardGeneric(u64, item_end, min_alignment);
    }
    return start;
}

/// TODO Improve this to use a table.
fn makeString(self: *Elf, bytes: []const u8) !u32 {
    try self.shstrtab.ensureUnusedCapacity(self.base.allocator, bytes.len + 1);
    const result = self.shstrtab.items.len;
    self.shstrtab.appendSliceAssumeCapacity(bytes);
    self.shstrtab.appendAssumeCapacity(0);
    return @intCast(u32, result);
}

fn getString(self: Elf, str_off: u32) []const u8 {
    assert(str_off < self.shstrtab.items.len);
    return mem.sliceTo(@ptrCast([*:0]const u8, self.shstrtab.items.ptr + str_off), 0);
}

fn updateString(self: *Elf, old_str_off: u32, new_name: []const u8) !u32 {
    const existing_name = self.getString(old_str_off);
    if (mem.eql(u8, existing_name, new_name)) {
        return old_str_off;
    }
    return self.makeString(new_name);
}

pub fn populateMissingMetadata(self: *Elf) !void {
    assert(self.llvm_object == null);

    const small_ptr = switch (self.ptr_width) {
        .p32 => true,
        .p64 => false,
    };
    const ptr_size: u8 = self.ptrWidthBytes();

    if (self.phdr_load_re_index == null) {
        self.phdr_load_re_index = @intCast(u16, self.program_headers.items.len);
        const file_size = self.base.options.program_code_size_hint;
        const p_align = self.page_size;
        const off = self.findFreeSpace(file_size, p_align);
        log.debug("found PT_LOAD RE free space 0x{x} to 0x{x}", .{ off, off + file_size });
        const entry_addr: u64 = self.entry_addr orelse if (self.base.options.target.cpu.arch == .spu_2) @as(u64, 0) else default_entry_addr;
        try self.program_headers.append(self.base.allocator, .{
            .p_type = elf.PT_LOAD,
            .p_offset = off,
            .p_filesz = file_size,
            .p_vaddr = entry_addr,
            .p_paddr = entry_addr,
            .p_memsz = file_size,
            .p_align = p_align,
            .p_flags = elf.PF_X | elf.PF_R,
        });
        try self.atom_free_lists.putNoClobber(self.base.allocator, self.phdr_load_re_index.?, .{});
        self.entry_addr = null;
        self.phdr_table_dirty = true;
    }

    if (self.phdr_got_index == null) {
        self.phdr_got_index = @intCast(u16, self.program_headers.items.len);
        const file_size = @as(u64, ptr_size) * self.base.options.symbol_count_hint;
        // We really only need ptr alignment but since we are using PROGBITS, linux requires
        // page align.
        const p_align = if (self.base.options.target.os.tag == .linux) self.page_size else @as(u16, ptr_size);
        const off = self.findFreeSpace(file_size, p_align);
        log.debug("found PT_LOAD GOT free space 0x{x} to 0x{x}", .{ off, off + file_size });
        // TODO instead of hard coding the vaddr, make a function to find a vaddr to put things at.
        // we'll need to re-use that function anyway, in case the GOT grows and overlaps something
        // else in virtual memory.
        const got_addr: u32 = if (self.base.options.target.cpu.arch.ptrBitWidth() >= 32) 0x4000000 else 0x8000;
        try self.program_headers.append(self.base.allocator, .{
            .p_type = elf.PT_LOAD,
            .p_offset = off,
            .p_filesz = file_size,
            .p_vaddr = got_addr,
            .p_paddr = got_addr,
            .p_memsz = file_size,
            .p_align = p_align,
            .p_flags = elf.PF_R,
        });
        self.phdr_table_dirty = true;
    }

    if (self.phdr_load_ro_index == null) {
        self.phdr_load_ro_index = @intCast(u16, self.program_headers.items.len);
        // TODO Find a hint about how much data need to be in rodata ?
        const file_size = 1024;
        // Same reason as for GOT
        const p_align = if (self.base.options.target.os.tag == .linux) self.page_size else @as(u16, ptr_size);
        const off = self.findFreeSpace(file_size, p_align);
        log.debug("found PT_LOAD RO free space 0x{x} to 0x{x}", .{ off, off + file_size });
        // TODO Same as for GOT
        const rodata_addr: u32 = if (self.base.options.target.cpu.arch.ptrBitWidth() >= 32) 0xc000000 else 0xa000;
        try self.program_headers.append(self.base.allocator, .{
            .p_type = elf.PT_LOAD,
            .p_offset = off,
            .p_filesz = file_size,
            .p_vaddr = rodata_addr,
            .p_paddr = rodata_addr,
            .p_memsz = file_size,
            .p_align = p_align,
            .p_flags = elf.PF_R,
        });
        try self.atom_free_lists.putNoClobber(self.base.allocator, self.phdr_load_ro_index.?, .{});
        self.phdr_table_dirty = true;
    }

    if (self.phdr_load_rw_index == null) {
        self.phdr_load_rw_index = @intCast(u16, self.program_headers.items.len);
        // TODO Find a hint about how much data need to be in data ?
        const file_size = 1024;
        // Same reason as for GOT
        const p_align = if (self.base.options.target.os.tag == .linux) self.page_size else @as(u16, ptr_size);
        const off = self.findFreeSpace(file_size, p_align);
        log.debug("found PT_LOAD RW free space 0x{x} to 0x{x}", .{ off, off + file_size });
        // TODO Same as for GOT
        const rwdata_addr: u32 = if (self.base.options.target.cpu.arch.ptrBitWidth() >= 32) 0x10000000 else 0xc000;
        try self.program_headers.append(self.base.allocator, .{
            .p_type = elf.PT_LOAD,
            .p_offset = off,
            .p_filesz = file_size,
            .p_vaddr = rwdata_addr,
            .p_paddr = rwdata_addr,
            .p_memsz = file_size,
            .p_align = p_align,
            .p_flags = elf.PF_R | elf.PF_W,
        });
        try self.atom_free_lists.putNoClobber(self.base.allocator, self.phdr_load_rw_index.?, .{});
        self.phdr_table_dirty = true;
    }

    if (self.shstrtab_index == null) {
        self.shstrtab_index = @intCast(u16, self.sections.items.len);
        assert(self.shstrtab.items.len == 0);
        try self.shstrtab.append(self.base.allocator, 0); // need a 0 at position 0
        const off = self.findFreeSpace(self.shstrtab.items.len, 1);
        log.debug("found shstrtab free space 0x{x} to 0x{x}", .{ off, off + self.shstrtab.items.len });
        try self.sections.append(self.base.allocator, .{
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

        try self.sections.append(self.base.allocator, .{
            .sh_name = try self.makeString(".text"),
            .sh_type = elf.SHT_PROGBITS,
            .sh_flags = elf.SHF_ALLOC | elf.SHF_EXECINSTR,
            .sh_addr = phdr.p_vaddr,
            .sh_offset = phdr.p_offset,
            .sh_size = phdr.p_filesz,
            .sh_link = 0,
            .sh_info = 0,
            .sh_addralign = 1,
            .sh_entsize = 0,
        });
        try self.phdr_shdr_table.putNoClobber(
            self.base.allocator,
            self.phdr_load_re_index.?,
            self.text_section_index.?,
        );
        self.shdr_table_dirty = true;
    }

    if (self.got_section_index == null) {
        self.got_section_index = @intCast(u16, self.sections.items.len);
        const phdr = &self.program_headers.items[self.phdr_got_index.?];

        try self.sections.append(self.base.allocator, .{
            .sh_name = try self.makeString(".got"),
            .sh_type = elf.SHT_PROGBITS,
            .sh_flags = elf.SHF_ALLOC,
            .sh_addr = phdr.p_vaddr,
            .sh_offset = phdr.p_offset,
            .sh_size = phdr.p_filesz,
            .sh_link = 0,
            .sh_info = 0,
            .sh_addralign = @as(u16, ptr_size),
            .sh_entsize = 0,
        });
        try self.phdr_shdr_table.putNoClobber(
            self.base.allocator,
            self.phdr_got_index.?,
            self.got_section_index.?,
        );
        self.shdr_table_dirty = true;
    }

    if (self.rodata_section_index == null) {
        self.rodata_section_index = @intCast(u16, self.sections.items.len);
        const phdr = &self.program_headers.items[self.phdr_load_ro_index.?];

        try self.sections.append(self.base.allocator, .{
            .sh_name = try self.makeString(".rodata"),
            .sh_type = elf.SHT_PROGBITS,
            .sh_flags = elf.SHF_ALLOC,
            .sh_addr = phdr.p_vaddr,
            .sh_offset = phdr.p_offset,
            .sh_size = phdr.p_filesz,
            .sh_link = 0,
            .sh_info = 0,
            .sh_addralign = 1,
            .sh_entsize = 0,
        });
        try self.phdr_shdr_table.putNoClobber(
            self.base.allocator,
            self.phdr_load_ro_index.?,
            self.rodata_section_index.?,
        );
        self.shdr_table_dirty = true;
    }

    if (self.data_section_index == null) {
        self.data_section_index = @intCast(u16, self.sections.items.len);
        const phdr = &self.program_headers.items[self.phdr_load_rw_index.?];

        try self.sections.append(self.base.allocator, .{
            .sh_name = try self.makeString(".data"),
            .sh_type = elf.SHT_PROGBITS,
            .sh_flags = elf.SHF_WRITE | elf.SHF_ALLOC,
            .sh_addr = phdr.p_vaddr,
            .sh_offset = phdr.p_offset,
            .sh_size = phdr.p_filesz,
            .sh_link = 0,
            .sh_info = 0,
            .sh_addralign = @as(u16, ptr_size),
            .sh_entsize = 0,
        });
        try self.phdr_shdr_table.putNoClobber(
            self.base.allocator,
            self.phdr_load_rw_index.?,
            self.data_section_index.?,
        );
        self.shdr_table_dirty = true;
    }

    if (self.symtab_section_index == null) {
        self.symtab_section_index = @intCast(u16, self.sections.items.len);
        const min_align: u16 = if (small_ptr) @alignOf(elf.Elf32_Sym) else @alignOf(elf.Elf64_Sym);
        const each_size: u64 = if (small_ptr) @sizeOf(elf.Elf32_Sym) else @sizeOf(elf.Elf64_Sym);
        const file_size = self.base.options.symbol_count_hint * each_size;
        const off = self.findFreeSpace(file_size, min_align);
        log.debug("found symtab free space 0x{x} to 0x{x}", .{ off, off + file_size });

        try self.sections.append(self.base.allocator, .{
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

    if (self.dwarf) |dw| {
        if (self.debug_str_section_index == null) {
            self.debug_str_section_index = @intCast(u16, self.sections.items.len);
            assert(dw.strtab.items.len == 0);
            try self.sections.append(self.base.allocator, .{
                .sh_name = try self.makeString(".debug_str"),
                .sh_type = elf.SHT_PROGBITS,
                .sh_flags = elf.SHF_MERGE | elf.SHF_STRINGS,
                .sh_addr = 0,
                .sh_offset = 0,
                .sh_size = 0,
                .sh_link = 0,
                .sh_info = 0,
                .sh_addralign = 1,
                .sh_entsize = 1,
            });
            self.debug_strtab_dirty = true;
            self.shdr_table_dirty = true;
        }

        if (self.debug_info_section_index == null) {
            self.debug_info_section_index = @intCast(u16, self.sections.items.len);

            const file_size_hint = 200;
            const p_align = 1;
            const off = self.findFreeSpace(file_size_hint, p_align);
            log.debug("found .debug_info free space 0x{x} to 0x{x}", .{
                off,
                off + file_size_hint,
            });
            try self.sections.append(self.base.allocator, .{
                .sh_name = try self.makeString(".debug_info"),
                .sh_type = elf.SHT_PROGBITS,
                .sh_flags = 0,
                .sh_addr = 0,
                .sh_offset = off,
                .sh_size = file_size_hint,
                .sh_link = 0,
                .sh_info = 0,
                .sh_addralign = p_align,
                .sh_entsize = 0,
            });
            self.shdr_table_dirty = true;
            self.debug_info_header_dirty = true;
        }

        if (self.debug_abbrev_section_index == null) {
            self.debug_abbrev_section_index = @intCast(u16, self.sections.items.len);

            const file_size_hint = 128;
            const p_align = 1;
            const off = self.findFreeSpace(file_size_hint, p_align);
            log.debug("found .debug_abbrev free space 0x{x} to 0x{x}", .{
                off,
                off + file_size_hint,
            });
            try self.sections.append(self.base.allocator, .{
                .sh_name = try self.makeString(".debug_abbrev"),
                .sh_type = elf.SHT_PROGBITS,
                .sh_flags = 0,
                .sh_addr = 0,
                .sh_offset = off,
                .sh_size = file_size_hint,
                .sh_link = 0,
                .sh_info = 0,
                .sh_addralign = p_align,
                .sh_entsize = 0,
            });
            self.shdr_table_dirty = true;
            self.debug_abbrev_section_dirty = true;
        }

        if (self.debug_aranges_section_index == null) {
            self.debug_aranges_section_index = @intCast(u16, self.sections.items.len);

            const file_size_hint = 160;
            const p_align = 16;
            const off = self.findFreeSpace(file_size_hint, p_align);
            log.debug("found .debug_aranges free space 0x{x} to 0x{x}", .{
                off,
                off + file_size_hint,
            });
            try self.sections.append(self.base.allocator, .{
                .sh_name = try self.makeString(".debug_aranges"),
                .sh_type = elf.SHT_PROGBITS,
                .sh_flags = 0,
                .sh_addr = 0,
                .sh_offset = off,
                .sh_size = file_size_hint,
                .sh_link = 0,
                .sh_info = 0,
                .sh_addralign = p_align,
                .sh_entsize = 0,
            });
            self.shdr_table_dirty = true;
            self.debug_aranges_section_dirty = true;
        }

        if (self.debug_line_section_index == null) {
            self.debug_line_section_index = @intCast(u16, self.sections.items.len);

            const file_size_hint = 250;
            const p_align = 1;
            const off = self.findFreeSpace(file_size_hint, p_align);
            log.debug("found .debug_line free space 0x{x} to 0x{x}", .{
                off,
                off + file_size_hint,
            });
            try self.sections.append(self.base.allocator, .{
                .sh_name = try self.makeString(".debug_line"),
                .sh_type = elf.SHT_PROGBITS,
                .sh_flags = 0,
                .sh_addr = 0,
                .sh_offset = off,
                .sh_size = file_size_hint,
                .sh_link = 0,
                .sh_info = 0,
                .sh_addralign = p_align,
                .sh_entsize = 0,
            });
            self.shdr_table_dirty = true;
            self.debug_line_header_dirty = true;
        }
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

    if (self.shdr_table_dirty) {
        // We need to find out what the max file offset is according to section headers.
        // Otherwise, we may end up with an ELF binary with file size not matching the final section's
        // offset + it's filesize.
        var max_file_offset: u64 = 0;

        for (self.sections.items) |shdr| {
            if (shdr.sh_offset + shdr.sh_size > max_file_offset) {
                max_file_offset = shdr.sh_offset + shdr.sh_size;
            }
        }

        try self.base.file.?.pwriteAll(&[_]u8{0}, max_file_offset);
    }
}

pub fn flush(self: *Elf, comp: *Compilation, prog_node: *std.Progress.Node) !void {
    if (self.base.options.emit == null) {
        if (build_options.have_llvm) {
            if (self.llvm_object) |llvm_object| {
                return try llvm_object.flushModule(comp, prog_node);
            }
        }
        return;
    }
    const use_lld = build_options.have_llvm and self.base.options.use_lld;
    if (use_lld) {
        return self.linkWithLLD(comp, prog_node);
    }
    switch (self.base.options.output_mode) {
        .Exe, .Obj => return self.flushModule(comp, prog_node),
        .Lib => return error.TODOImplementWritingLibFiles,
    }
}

pub fn flushModule(self: *Elf, comp: *Compilation, prog_node: *std.Progress.Node) !void {
    const tracy = trace(@src());
    defer tracy.end();

    if (build_options.have_llvm) {
        if (self.llvm_object) |llvm_object| {
            return try llvm_object.flushModule(comp, prog_node);
        }
    }

    var sub_prog_node = prog_node.start("ELF Flush", 0);
    sub_prog_node.activate();
    defer sub_prog_node.end();

    // TODO This linker code currently assumes there is only 1 compilation unit and it
    // corresponds to the Zig source code.
    const module = self.base.options.module orelse return error.LinkingWithoutZigSourceUnimplemented;

    const target_endian = self.base.options.target.cpu.arch.endian();
    const foreign_endian = target_endian != builtin.cpu.arch.endian();

    if (self.dwarf) |*dw| {
        try dw.flushModule(&self.base, module);
    }

    {
        var it = self.relocs.iterator();
        while (it.next()) |entry| {
            const atom = entry.key_ptr.*;
            const relocs = entry.value_ptr.*;
            const source_sym = self.local_symbols.items[atom.local_sym_index];
            const source_shdr = self.sections.items[source_sym.st_shndx];

            log.debug("relocating '{s}'", .{self.getString(source_sym.st_name)});

            for (relocs.items) |*reloc| {
                const target_sym = self.local_symbols.items[reloc.target];
                const target_vaddr = target_sym.st_value + reloc.addend;

                if (target_vaddr == reloc.prev_vaddr) continue;

                const section_offset = (source_sym.st_value + reloc.offset) - source_shdr.sh_addr;
                const file_offset = source_shdr.sh_offset + section_offset;

                log.debug("  ({x}: [() => 0x{x}] ({s}))", .{
                    reloc.offset,
                    target_vaddr,
                    self.getString(target_sym.st_name),
                });

                switch (self.ptr_width) {
                    .p32 => try self.base.file.?.pwriteAll(mem.asBytes(&@intCast(u32, target_vaddr)), file_offset),
                    .p64 => try self.base.file.?.pwriteAll(mem.asBytes(&target_vaddr), file_offset),
                }

                reloc.prev_vaddr = target_vaddr;
            }
        }
    }

    // Unfortunately these have to be buffered and done at the end because ELF does not allow
    // mixing local and global symbols within a symbol table.
    try self.writeAllGlobalSymbols();

    if (build_options.enable_logging) {
        self.logSymtab();
    }

    if (self.dwarf) |*dw| {
        if (self.debug_abbrev_section_dirty) {
            try dw.writeDbgAbbrev(&self.base);
            if (!self.shdr_table_dirty) {
                // Then it won't get written with the others and we need to do it.
                try self.writeSectHeader(self.debug_abbrev_section_index.?);
            }
            self.debug_abbrev_section_dirty = false;
        }

        if (self.debug_info_header_dirty) {
            // Currently only one compilation unit is supported, so the address range is simply
            // identical to the main program header virtual address and memory size.
            const text_phdr = &self.program_headers.items[self.phdr_load_re_index.?];
            const low_pc = text_phdr.p_vaddr;
            const high_pc = text_phdr.p_vaddr + text_phdr.p_memsz;
            try dw.writeDbgInfoHeader(&self.base, module, low_pc, high_pc);
            self.debug_info_header_dirty = false;
        }

        if (self.debug_aranges_section_dirty) {
            // Currently only one compilation unit is supported, so the address range is simply
            // identical to the main program header virtual address and memory size.
            const text_phdr = &self.program_headers.items[self.phdr_load_re_index.?];
            try dw.writeDbgAranges(&self.base, text_phdr.p_vaddr, text_phdr.p_memsz);
            if (!self.shdr_table_dirty) {
                // Then it won't get written with the others and we need to do it.
                try self.writeSectHeader(self.debug_aranges_section_index.?);
            }
            self.debug_aranges_section_dirty = false;
        }

        if (self.debug_line_header_dirty) {
            try dw.writeDbgLineHeader(&self.base, module);
            self.debug_line_header_dirty = false;
        }
    }

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
                const buf = try self.base.allocator.alloc(elf.Elf32_Phdr, self.program_headers.items.len);
                defer self.base.allocator.free(buf);

                for (buf) |*phdr, i| {
                    phdr.* = progHeaderTo32(self.program_headers.items[i]);
                    if (foreign_endian) {
                        mem.byteSwapAllFields(elf.Elf32_Phdr, phdr);
                    }
                }
                try self.base.file.?.pwriteAll(mem.sliceAsBytes(buf), self.phdr_table_offset.?);
            },
            .p64 => {
                const buf = try self.base.allocator.alloc(elf.Elf64_Phdr, self.program_headers.items.len);
                defer self.base.allocator.free(buf);

                for (buf) |*phdr, i| {
                    phdr.* = self.program_headers.items[i];
                    if (foreign_endian) {
                        mem.byteSwapAllFields(elf.Elf64_Phdr, phdr);
                    }
                }
                try self.base.file.?.pwriteAll(mem.sliceAsBytes(buf), self.phdr_table_offset.?);
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
            log.debug("writing shstrtab start=0x{x} end=0x{x}", .{ shstrtab_sect.sh_offset, shstrtab_sect.sh_offset + needed_size });

            try self.base.file.?.pwriteAll(self.shstrtab.items, shstrtab_sect.sh_offset);
            if (!self.shdr_table_dirty) {
                // Then it won't get written with the others and we need to do it.
                try self.writeSectHeader(self.shstrtab_index.?);
            }
            self.shstrtab_dirty = false;
        }
    }

    if (self.dwarf) |dwarf| {
        const debug_strtab_sect = &self.sections.items[self.debug_str_section_index.?];
        if (self.debug_strtab_dirty or dwarf.strtab.items.len != debug_strtab_sect.sh_size) {
            const allocated_size = self.allocatedSize(debug_strtab_sect.sh_offset);
            const needed_size = dwarf.strtab.items.len;

            if (needed_size > allocated_size) {
                debug_strtab_sect.sh_size = 0; // free the space
                debug_strtab_sect.sh_offset = self.findFreeSpace(needed_size, 1);
            }
            debug_strtab_sect.sh_size = needed_size;
            log.debug("debug_strtab start=0x{x} end=0x{x}", .{ debug_strtab_sect.sh_offset, debug_strtab_sect.sh_offset + needed_size });

            try self.base.file.?.pwriteAll(dwarf.strtab.items, debug_strtab_sect.sh_offset);
            if (!self.shdr_table_dirty) {
                // Then it won't get written with the others and we need to do it.
                try self.writeSectHeader(self.debug_str_section_index.?);
            }
            self.debug_strtab_dirty = false;
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
                const buf = try self.base.allocator.alloc(elf.Elf32_Shdr, self.sections.items.len);
                defer self.base.allocator.free(buf);

                for (buf) |*shdr, i| {
                    shdr.* = sectHeaderTo32(self.sections.items[i]);
                    log.debug("writing section {s}: {}", .{ self.getString(shdr.sh_name), shdr.* });
                    if (foreign_endian) {
                        mem.byteSwapAllFields(elf.Elf32_Shdr, shdr);
                    }
                }
                try self.base.file.?.pwriteAll(mem.sliceAsBytes(buf), self.shdr_table_offset.?);
            },
            .p64 => {
                const buf = try self.base.allocator.alloc(elf.Elf64_Shdr, self.sections.items.len);
                defer self.base.allocator.free(buf);

                for (buf) |*shdr, i| {
                    shdr.* = self.sections.items[i];
                    log.debug("writing section {s}: {}", .{ self.getString(shdr.sh_name), shdr.* });
                    if (foreign_endian) {
                        mem.byteSwapAllFields(elf.Elf64_Shdr, shdr);
                    }
                }
                try self.base.file.?.pwriteAll(mem.sliceAsBytes(buf), self.shdr_table_offset.?);
            },
        }
        self.shdr_table_dirty = false;
    }
    if (self.entry_addr == null and self.base.options.effectiveOutputMode() == .Exe) {
        log.debug("flushing. no_entry_point_found = true", .{});
        self.error_flags.no_entry_point_found = true;
    } else {
        log.debug("flushing. no_entry_point_found = false", .{});
        self.error_flags.no_entry_point_found = false;
        try self.writeElfHeader();
    }

    // The point of flush() is to commit changes, so in theory, nothing should
    // be dirty after this. However, it is possible for some things to remain
    // dirty because they fail to be written in the event of compile errors,
    // such as debug_line_header_dirty and debug_info_header_dirty.
    assert(!self.debug_abbrev_section_dirty);
    assert(!self.debug_aranges_section_dirty);
    assert(!self.phdr_table_dirty);
    assert(!self.shdr_table_dirty);
    assert(!self.shstrtab_dirty);
    assert(!self.debug_strtab_dirty);
}

fn linkWithLLD(self: *Elf, comp: *Compilation, prog_node: *std.Progress.Node) !void {
    const tracy = trace(@src());
    defer tracy.end();

    var arena_allocator = std.heap.ArenaAllocator.init(self.base.allocator);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    const directory = self.base.options.emit.?.directory; // Just an alias to make it shorter to type.
    const full_out_path = try directory.join(arena, &[_][]const u8{self.base.options.emit.?.sub_path});

    // If there is no Zig code to compile, then we should skip flushing the output file because it
    // will not be part of the linker line anyway.
    const module_obj_path: ?[]const u8 = if (self.base.options.module) |module| blk: {
        // stage1 puts the object file in the cache directory.
        if (self.base.options.use_stage1) {
            const obj_basename = try std.zig.binNameAlloc(arena, .{
                .root_name = self.base.options.root_name,
                .target = self.base.options.target,
                .output_mode = .Obj,
            });
            switch (self.base.options.cache_mode) {
                .incremental => break :blk try module.zig_cache_artifact_directory.join(
                    arena,
                    &[_][]const u8{obj_basename},
                ),
                .whole => break :blk try fs.path.join(arena, &.{
                    fs.path.dirname(full_out_path).?, obj_basename,
                }),
            }
        }

        try self.flushModule(comp, prog_node);

        if (fs.path.dirname(full_out_path)) |dirname| {
            break :blk try fs.path.join(arena, &.{ dirname, self.base.intermediary_basename.? });
        } else {
            break :blk self.base.intermediary_basename.?;
        }
    } else null;

    var sub_prog_node = prog_node.start("LLD Link", 0);
    sub_prog_node.activate();
    sub_prog_node.context.refresh();
    defer sub_prog_node.end();

    const is_obj = self.base.options.output_mode == .Obj;
    const is_lib = self.base.options.output_mode == .Lib;
    const is_dyn_lib = self.base.options.link_mode == .Dynamic and is_lib;
    const is_exe_or_dyn_lib = is_dyn_lib or self.base.options.output_mode == .Exe;
    const have_dynamic_linker = self.base.options.link_libc and
        self.base.options.link_mode == .Dynamic and is_exe_or_dyn_lib;
    const target = self.base.options.target;
    const gc_sections = self.base.options.gc_sections orelse !is_obj;
    const stack_size = self.base.options.stack_size_override orelse 16777216;
    const allow_shlib_undefined = self.base.options.allow_shlib_undefined orelse !self.base.options.is_native_os;
    const compiler_rt_path: ?[]const u8 = blk: {
        if (comp.compiler_rt_lib) |x| break :blk x.full_object_path;
        if (comp.compiler_rt_obj) |x| break :blk x.full_object_path;
        break :blk null;
    };

    // Here we want to determine whether we can save time by not invoking LLD when the
    // output is unchanged. None of the linker options or the object files that are being
    // linked are in the hash that namespaces the directory we are outputting to. Therefore,
    // we must hash those now, and the resulting digest will form the "id" of the linking
    // job we are about to perform.
    // After a successful link, we store the id in the metadata of a symlink named "id.txt" in
    // the artifact directory. So, now, we check if this symlink exists, and if it matches
    // our digest. If so, we can skip linking. Otherwise, we proceed with invoking LLD.
    const id_symlink_basename = "lld.id";

    var man: Cache.Manifest = undefined;
    defer if (!self.base.options.disable_lld_caching) man.deinit();

    var digest: [Cache.hex_digest_len]u8 = undefined;

    if (!self.base.options.disable_lld_caching) {
        man = comp.cache_parent.obtain();

        // We are about to obtain this lock, so here we give other processes a chance first.
        self.base.releaseLock();

        comptime assert(Compilation.link_hash_implementation_version == 7);

        try man.addOptionalFile(self.base.options.linker_script);
        try man.addOptionalFile(self.base.options.version_script);
        for (self.base.options.objects) |obj| {
            _ = try man.addFile(obj.path, null);
            man.hash.add(obj.must_link);
        }
        for (comp.c_object_table.keys()) |key| {
            _ = try man.addFile(key.status.success.object_path, null);
        }
        try man.addOptionalFile(module_obj_path);
        try man.addOptionalFile(compiler_rt_path);

        // We can skip hashing libc and libc++ components that we are in charge of building from Zig
        // installation sources because they are always a product of the compiler version + target information.
        man.hash.addOptionalBytes(self.base.options.entry);
        man.hash.addOptional(self.base.options.image_base_override);
        man.hash.add(gc_sections);
        man.hash.add(self.base.options.eh_frame_hdr);
        man.hash.add(self.base.options.emit_relocs);
        man.hash.add(self.base.options.rdynamic);
        man.hash.addListOfBytes(self.base.options.lib_dirs);
        man.hash.addListOfBytes(self.base.options.rpath_list);
        man.hash.add(self.base.options.each_lib_rpath);
        if (self.base.options.output_mode == .Exe) {
            man.hash.add(stack_size);
            man.hash.add(self.base.options.build_id);
        }
        man.hash.add(self.base.options.skip_linker_dependencies);
        man.hash.add(self.base.options.z_nodelete);
        man.hash.add(self.base.options.z_notext);
        man.hash.add(self.base.options.z_defs);
        man.hash.add(self.base.options.z_origin);
        man.hash.add(self.base.options.z_nocopyreloc);
        man.hash.add(self.base.options.z_now);
        man.hash.add(self.base.options.z_relro);
        man.hash.add(self.base.options.hash_style);
        // strip does not need to go into the linker hash because it is part of the hash namespace
        if (self.base.options.link_libc) {
            man.hash.add(self.base.options.libc_installation != null);
            if (self.base.options.libc_installation) |libc_installation| {
                man.hash.addBytes(libc_installation.crt_dir.?);
            }
            if (have_dynamic_linker) {
                man.hash.addOptionalBytes(self.base.options.dynamic_linker);
            }
        }
        man.hash.addOptionalBytes(self.base.options.soname);
        man.hash.addOptional(self.base.options.version);
        link.hashAddSystemLibs(&man.hash, self.base.options.system_libs);
        man.hash.add(allow_shlib_undefined);
        man.hash.add(self.base.options.bind_global_refs_locally);
        man.hash.add(self.base.options.compress_debug_sections);
        man.hash.add(self.base.options.tsan);
        man.hash.addOptionalBytes(self.base.options.sysroot);
        man.hash.add(self.base.options.linker_optimization);

        // We don't actually care whether it's a cache hit or miss; we just need the digest and the lock.
        _ = try man.hit();
        digest = man.final();

        var prev_digest_buf: [digest.len]u8 = undefined;
        const prev_digest: []u8 = Cache.readSmallFile(
            directory.handle,
            id_symlink_basename,
            &prev_digest_buf,
        ) catch |err| blk: {
            log.debug("ELF LLD new_digest={s} error: {s}", .{ std.fmt.fmtSliceHexLower(&digest), @errorName(err) });
            // Handle this as a cache miss.
            break :blk prev_digest_buf[0..0];
        };
        if (mem.eql(u8, prev_digest, &digest)) {
            log.debug("ELF LLD digest={s} match - skipping invocation", .{std.fmt.fmtSliceHexLower(&digest)});
            // Hot diggity dog! The output binary is already there.
            self.base.lock = man.toOwnedLock();
            return;
        }
        log.debug("ELF LLD prev_digest={s} new_digest={s}", .{ std.fmt.fmtSliceHexLower(prev_digest), std.fmt.fmtSliceHexLower(&digest) });

        // We are about to change the output file to be different, so we invalidate the build hash now.
        directory.handle.deleteFile(id_symlink_basename) catch |err| switch (err) {
            error.FileNotFound => {},
            else => |e| return e,
        };
    }

    // Due to a deficiency in LLD, we need to special-case BPF to a simple file
    // copy when generating relocatables. Normally, we would expect `lld -r` to work.
    // However, because LLD wants to resolve BPF relocations which it shouldn't, it fails
    // before even generating the relocatable.
    if (self.base.options.output_mode == .Obj and
        (self.base.options.lto or target.isBpfFreestanding()))
    {
        // In this case we must do a simple file copy
        // here. TODO: think carefully about how we can avoid this redundant operation when doing
        // build-obj. See also the corresponding TODO in linkAsArchive.
        const the_object_path = blk: {
            if (self.base.options.objects.len != 0)
                break :blk self.base.options.objects[0].path;

            if (comp.c_object_table.count() != 0)
                break :blk comp.c_object_table.keys()[0].status.success.object_path;

            if (module_obj_path) |p|
                break :blk p;

            // TODO I think this is unreachable. Audit this situation when solving the above TODO
            // regarding eliding redundant object -> object transformations.
            return error.NoObjectsToLink;
        };
        // This can happen when using --enable-cache and using the stage1 backend. In this case
        // we can skip the file copy.
        if (!mem.eql(u8, the_object_path, full_out_path)) {
            try fs.cwd().copyFile(the_object_path, fs.cwd(), full_out_path, .{});
        }
    } else {
        // Create an LLD command line and invoke it.
        var argv = std.ArrayList([]const u8).init(self.base.allocator);
        defer argv.deinit();
        // We will invoke ourselves as a child process to gain access to LLD.
        // This is necessary because LLD does not behave properly as a library -
        // it calls exit() and does not reset all global data between invocations.
        try argv.appendSlice(&[_][]const u8{ comp.self_exe_path.?, "ld.lld" });
        if (is_obj) {
            try argv.append("-r");
        }

        try argv.append("-error-limit=0");

        if (self.base.options.sysroot) |sysroot| {
            try argv.append(try std.fmt.allocPrint(arena, "--sysroot={s}", .{sysroot}));
        }

        if (self.base.options.lto) {
            switch (self.base.options.optimize_mode) {
                .Debug => {},
                .ReleaseSmall => try argv.append("--lto-O2"),
                .ReleaseFast, .ReleaseSafe => try argv.append("--lto-O3"),
            }
        }
        try argv.append(try std.fmt.allocPrint(arena, "-O{d}", .{
            self.base.options.linker_optimization,
        }));

        if (self.base.options.entry) |entry| {
            try argv.append("--entry");
            try argv.append(entry);
        }

        switch (self.base.options.hash_style) {
            .gnu => try argv.append("--hash-style=gnu"),
            .sysv => try argv.append("--hash-style=sysv"),
            .both => {}, // this is the default
        }

        if (self.base.options.output_mode == .Exe) {
            try argv.append("-z");
            try argv.append(try std.fmt.allocPrint(arena, "stack-size={d}", .{stack_size}));

            if (self.base.options.build_id) {
                try argv.append("--build-id");
            }
        }

        if (self.base.options.image_base_override) |image_base| {
            try argv.append(try std.fmt.allocPrint(arena, "--image-base={d}", .{image_base}));
        }

        if (self.base.options.linker_script) |linker_script| {
            try argv.append("-T");
            try argv.append(linker_script);
        }

        if (gc_sections) {
            try argv.append("--gc-sections");
        }

        if (self.base.options.eh_frame_hdr) {
            try argv.append("--eh-frame-hdr");
        }

        if (self.base.options.emit_relocs) {
            try argv.append("--emit-relocs");
        }

        if (self.base.options.rdynamic) {
            try argv.append("--export-dynamic");
        }

        if (self.base.options.strip) {
            try argv.append("-s");
        }

        if (self.base.options.z_nodelete) {
            try argv.append("-z");
            try argv.append("nodelete");
        }
        if (self.base.options.z_notext) {
            try argv.append("-z");
            try argv.append("notext");
        }
        if (self.base.options.z_defs) {
            try argv.append("-z");
            try argv.append("defs");
        }
        if (self.base.options.z_origin) {
            try argv.append("-z");
            try argv.append("origin");
        }
        if (self.base.options.z_nocopyreloc) {
            try argv.append("-z");
            try argv.append("nocopyreloc");
        }
        if (self.base.options.z_now) {
            // LLD defaults to -zlazy
            try argv.append("-znow");
        }
        if (!self.base.options.z_relro) {
            // LLD defaults to -zrelro
            try argv.append("-znorelro");
        }

        if (getLDMOption(target)) |ldm| {
            // Any target ELF will use the freebsd osabi if suffixed with "_fbsd".
            const arg = if (target.os.tag == .freebsd)
                try std.fmt.allocPrint(arena, "{s}_fbsd", .{ldm})
            else
                ldm;
            try argv.append("-m");
            try argv.append(arg);
        }

        if (self.base.options.link_mode == .Static) {
            if (target.cpu.arch.isARM() or target.cpu.arch.isThumb()) {
                try argv.append("-Bstatic");
            } else {
                try argv.append("-static");
            }
        } else if (is_dyn_lib) {
            try argv.append("-shared");
        }

        if (self.base.options.pie and self.base.options.output_mode == .Exe) {
            try argv.append("-pie");
        }

        if (self.base.options.link_mode == .Dynamic and target.os.tag == .netbsd) {
            // Add options to produce shared objects with only 2 PT_LOAD segments.
            // NetBSD expects 2 PT_LOAD segments in a shared object, otherwise
            // ld.elf_so fails to load, emitting a general "not found" error.
            // See https://github.com/ziglang/zig/issues/9109 .
            try argv.append("--no-rosegment");
            try argv.append("-znorelro");
        }

        try argv.append("-o");
        try argv.append(full_out_path);

        // csu prelude
        var csu = try CsuObjects.init(arena, self.base.options, comp);
        if (csu.crt0) |v| try argv.append(v);
        if (csu.crti) |v| try argv.append(v);
        if (csu.crtbegin) |v| try argv.append(v);

        // rpaths
        var rpath_table = std.StringHashMap(void).init(self.base.allocator);
        defer rpath_table.deinit();
        for (self.base.options.rpath_list) |rpath| {
            if ((try rpath_table.fetchPut(rpath, {})) == null) {
                try argv.append("-rpath");
                try argv.append(rpath);
            }
        }
        if (self.base.options.each_lib_rpath) {
            var test_path = std.ArrayList(u8).init(self.base.allocator);
            defer test_path.deinit();
            for (self.base.options.lib_dirs) |lib_dir_path| {
                for (self.base.options.system_libs.keys()) |link_lib| {
                    test_path.clearRetainingCapacity();
                    const sep = fs.path.sep_str;
                    try test_path.writer().print("{s}" ++ sep ++ "lib{s}.so", .{
                        lib_dir_path, link_lib,
                    });
                    fs.cwd().access(test_path.items, .{}) catch |err| switch (err) {
                        error.FileNotFound => continue,
                        else => |e| return e,
                    };
                    if ((try rpath_table.fetchPut(lib_dir_path, {})) == null) {
                        try argv.append("-rpath");
                        try argv.append(lib_dir_path);
                    }
                }
            }
        }

        for (self.base.options.lib_dirs) |lib_dir| {
            try argv.append("-L");
            try argv.append(lib_dir);
        }

        if (self.base.options.link_libc) {
            if (self.base.options.libc_installation) |libc_installation| {
                try argv.append("-L");
                try argv.append(libc_installation.crt_dir.?);
            }

            if (have_dynamic_linker) {
                if (self.base.options.dynamic_linker) |dynamic_linker| {
                    try argv.append("-dynamic-linker");
                    try argv.append(dynamic_linker);
                }
            }
        }

        if (is_dyn_lib) {
            if (self.base.options.soname) |soname| {
                try argv.append("-soname");
                try argv.append(soname);
            }
            if (self.base.options.version_script) |version_script| {
                try argv.append("-version-script");
                try argv.append(version_script);
            }
        }

        // Positional arguments to the linker such as object files.
        var whole_archive = false;
        for (self.base.options.objects) |obj| {
            if (obj.must_link and !whole_archive) {
                try argv.append("-whole-archive");
                whole_archive = true;
            } else if (!obj.must_link and whole_archive) {
                try argv.append("-no-whole-archive");
                whole_archive = false;
            }
            try argv.append(obj.path);
        }
        if (whole_archive) {
            try argv.append("-no-whole-archive");
            whole_archive = false;
        }

        for (comp.c_object_table.keys()) |key| {
            try argv.append(key.status.success.object_path);
        }

        if (module_obj_path) |p| {
            try argv.append(p);
        }

        // TSAN
        if (self.base.options.tsan) {
            try argv.append(comp.tsan_static_lib.?.full_object_path);
        }

        // libc
        if (is_exe_or_dyn_lib and
            !self.base.options.skip_linker_dependencies and
            !self.base.options.link_libc)
        {
            if (comp.libc_static_lib) |lib| {
                try argv.append(lib.full_object_path);
            }
        }

        // compiler-rt
        if (compiler_rt_path) |p| {
            try argv.append(p);
        }

        // Shared libraries.
        if (is_exe_or_dyn_lib) {
            const system_libs = self.base.options.system_libs.keys();
            const system_libs_values = self.base.options.system_libs.values();

            // Worst-case, we need an --as-needed argument for every lib, as well
            // as one before and one after.
            try argv.ensureUnusedCapacity(system_libs.len * 2 + 2);
            argv.appendAssumeCapacity("--as-needed");
            var as_needed = true;

            for (system_libs) |link_lib, i| {
                const lib_as_needed = !system_libs_values[i].needed;
                switch ((@as(u2, @boolToInt(lib_as_needed)) << 1) | @boolToInt(as_needed)) {
                    0b00, 0b11 => {},
                    0b01 => {
                        argv.appendAssumeCapacity("--no-as-needed");
                        as_needed = false;
                    },
                    0b10 => {
                        argv.appendAssumeCapacity("--as-needed");
                        as_needed = true;
                    },
                }

                // By this time, we depend on these libs being dynamically linked
                // libraries and not static libraries (the check for that needs to be earlier),
                // but they could be full paths to .so files, in which case we
                // want to avoid prepending "-l".
                const ext = Compilation.classifyFileExt(link_lib);
                const arg = if (ext == .shared_library) link_lib else try std.fmt.allocPrint(arena, "-l{s}", .{link_lib});
                argv.appendAssumeCapacity(arg);
            }

            if (!as_needed) {
                argv.appendAssumeCapacity("--as-needed");
                as_needed = true;
            }

            // libc++ dep
            if (self.base.options.link_libcpp) {
                try argv.append(comp.libcxxabi_static_lib.?.full_object_path);
                try argv.append(comp.libcxx_static_lib.?.full_object_path);
            }

            // libunwind dep
            if (self.base.options.link_libunwind) {
                try argv.append(comp.libunwind_static_lib.?.full_object_path);
            }

            // libc dep
            self.error_flags.missing_libc = false;
            if (self.base.options.link_libc) {
                if (self.base.options.libc_installation != null) {
                    const needs_grouping = self.base.options.link_mode == .Static;
                    if (needs_grouping) try argv.append("--start-group");
                    try argv.appendSlice(target_util.libcFullLinkFlags(target));
                    if (needs_grouping) try argv.append("--end-group");
                } else if (target.isGnuLibC()) {
                    for (glibc.libs) |lib| {
                        const lib_path = try std.fmt.allocPrint(arena, "{s}{c}lib{s}.so.{d}", .{
                            comp.glibc_so_files.?.dir_path, fs.path.sep, lib.name, lib.sover,
                        });
                        try argv.append(lib_path);
                    }
                    try argv.append(try comp.get_libc_crt_file(arena, "libc_nonshared.a"));
                } else if (target.isMusl()) {
                    try argv.append(try comp.get_libc_crt_file(arena, switch (self.base.options.link_mode) {
                        .Static => "libc.a",
                        .Dynamic => "libc.so",
                    }));
                } else {
                    self.error_flags.missing_libc = true;
                    return error.FlushFailure;
                }
            }
        }

        // crt postlude
        if (csu.crtend) |v| try argv.append(v);
        if (csu.crtn) |v| try argv.append(v);

        if (allow_shlib_undefined) {
            try argv.append("--allow-shlib-undefined");
        }

        switch (self.base.options.compress_debug_sections) {
            .none => {},
            .zlib => try argv.append("--compress-debug-sections=zlib"),
        }

        if (self.base.options.bind_global_refs_locally) {
            try argv.append("-Bsymbolic");
        }

        if (self.base.options.verbose_link) {
            // Skip over our own name so that the LLD linker name is the first argv item.
            Compilation.dump_argv(argv.items[1..]);
        }

        if (std.process.can_spawn) {
            // If possible, we run LLD as a child process because it does not always
            // behave properly as a library, unfortunately.
            // https://github.com/ziglang/zig/issues/3825
            var child = std.ChildProcess.init(argv.items, arena);
            if (comp.clang_passthrough_mode) {
                child.stdin_behavior = .Inherit;
                child.stdout_behavior = .Inherit;
                child.stderr_behavior = .Inherit;

                const term = child.spawnAndWait() catch |err| {
                    log.err("unable to spawn {s}: {s}", .{ argv.items[0], @errorName(err) });
                    return error.UnableToSpawnSelf;
                };
                switch (term) {
                    .Exited => |code| {
                        if (code != 0) {
                            std.process.exit(code);
                        }
                    },
                    else => std.process.abort(),
                }
            } else {
                child.stdin_behavior = .Ignore;
                child.stdout_behavior = .Ignore;
                child.stderr_behavior = .Pipe;

                try child.spawn();

                const stderr = try child.stderr.?.reader().readAllAlloc(arena, 10 * 1024 * 1024);

                const term = child.wait() catch |err| {
                    log.err("unable to spawn {s}: {s}", .{ argv.items[0], @errorName(err) });
                    return error.UnableToSpawnSelf;
                };

                switch (term) {
                    .Exited => |code| {
                        if (code != 0) {
                            // TODO parse this output and surface with the Compilation API rather than
                            // directly outputting to stderr here.
                            std.debug.print("{s}", .{stderr});
                            return error.LLDReportedFailure;
                        }
                    },
                    else => {
                        log.err("{s} terminated with stderr:\n{s}", .{ argv.items[0], stderr });
                        return error.LLDCrashed;
                    },
                }

                if (stderr.len != 0) {
                    log.warn("unexpected LLD stderr:\n{s}", .{stderr});
                }
            }
        } else {
            const exit_code = try lldMain(arena, argv.items, false);
            if (exit_code != 0) {
                if (comp.clang_passthrough_mode) {
                    std.process.exit(exit_code);
                } else {
                    return error.LLDReportedFailure;
                }
            }
        }
    }

    if (!self.base.options.disable_lld_caching) {
        // Update the file with the digest. If it fails we can continue; it only
        // means that the next invocation will have an unnecessary cache miss.
        Cache.writeSmallFile(directory.handle, id_symlink_basename, &digest) catch |err| {
            log.warn("failed to save linking hash digest file: {s}", .{@errorName(err)});
        };
        // Again failure here only means an unnecessary cache miss.
        man.writeManifest() catch |err| {
            log.warn("failed to write cache manifest when linking: {s}", .{@errorName(err)});
        };
        // We hang on to this lock so that the output file path can be used without
        // other processes clobbering it.
        self.base.lock = man.toOwnedLock();
    }
}

fn writeDwarfAddrAssumeCapacity(self: *Elf, buf: *std.ArrayList(u8), addr: u64) void {
    const target_endian = self.base.options.target.cpu.arch.endian();
    switch (self.ptr_width) {
        .p32 => mem.writeInt(u32, buf.addManyAsArrayAssumeCapacity(4), @intCast(u32, addr), target_endian),
        .p64 => mem.writeInt(u64, buf.addManyAsArrayAssumeCapacity(8), addr, target_endian),
    }
}

fn writeElfHeader(self: *Elf) !void {
    var hdr_buf: [@sizeOf(elf.Elf64_Ehdr)]u8 = undefined;

    var index: usize = 0;
    hdr_buf[0..4].* = elf.MAGIC.*;
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

    const elf_type = switch (self.base.options.effectiveOutputMode()) {
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

    try self.base.file.?.pwriteAll(hdr_buf[0..index], 0);
}

fn freeTextBlock(self: *Elf, text_block: *TextBlock, phdr_index: u16) void {
    const local_sym = self.local_symbols.items[text_block.local_sym_index];
    const name_str_index = local_sym.st_name;
    const name = self.getString(name_str_index);
    log.debug("freeTextBlock {*} ({s})", .{ text_block, name });

    const free_list = self.atom_free_lists.getPtr(phdr_index).?;
    var already_have_free_list_node = false;
    {
        var i: usize = 0;
        // TODO turn free_list into a hash map
        while (i < free_list.items.len) {
            if (free_list.items[i] == text_block) {
                _ = free_list.swapRemove(i);
                continue;
            }
            if (free_list.items[i] == text_block.prev) {
                already_have_free_list_node = true;
            }
            i += 1;
        }
    }

    if (self.atoms.getPtr(phdr_index)) |last_block| {
        if (last_block.* == text_block) {
            if (text_block.prev) |prev| {
                // TODO shrink the section size here
                last_block.* = prev;
            } else {
                _ = self.atoms.fetchRemove(phdr_index);
            }
        }
    }

    if (text_block.prev) |prev| {
        prev.next = text_block.next;

        if (!already_have_free_list_node and prev.freeListEligible(self.*)) {
            // The free list is heuristics, it doesn't have to be perfect, so we can
            // ignore the OOM here.
            free_list.append(self.base.allocator, prev) catch {};
        }
    } else {
        text_block.prev = null;
    }

    if (text_block.next) |next| {
        next.prev = text_block.prev;
    } else {
        text_block.next = null;
    }

    if (self.dwarf) |*dw| {
        dw.freeAtom(&text_block.dbg_info_atom);
    }
}

fn shrinkTextBlock(self: *Elf, text_block: *TextBlock, new_block_size: u64, phdr_index: u16) void {
    _ = self;
    _ = text_block;
    _ = new_block_size;
    _ = phdr_index;
}

fn growTextBlock(self: *Elf, text_block: *TextBlock, new_block_size: u64, alignment: u64, phdr_index: u16) !u64 {
    const sym = self.local_symbols.items[text_block.local_sym_index];
    const align_ok = mem.alignBackwardGeneric(u64, sym.st_value, alignment) == sym.st_value;
    const need_realloc = !align_ok or new_block_size > text_block.capacity(self.*);
    if (!need_realloc) return sym.st_value;
    return self.allocateTextBlock(text_block, new_block_size, alignment, phdr_index);
}

fn allocateTextBlock(self: *Elf, text_block: *TextBlock, new_block_size: u64, alignment: u64, phdr_index: u16) !u64 {
    const shdr_index = self.phdr_shdr_table.get(phdr_index).?;
    const phdr = &self.program_headers.items[phdr_index];
    const shdr = &self.sections.items[shdr_index];
    const new_block_ideal_capacity = padToIdeal(new_block_size);

    // We use these to indicate our intention to update metadata, placing the new block,
    // and possibly removing a free list node.
    // It would be simpler to do it inside the for loop below, but that would cause a
    // problem if an error was returned later in the function. So this action
    // is actually carried out at the end of the function, when errors are no longer possible.
    var block_placement: ?*TextBlock = null;
    var free_list_removal: ?usize = null;
    var free_list = self.atom_free_lists.get(phdr_index).?;

    // First we look for an appropriately sized free list node.
    // The list is unordered. We'll just take the first thing that works.
    const vaddr = blk: {
        var i: usize = 0;
        while (i < free_list.items.len) {
            const big_block = free_list.items[i];
            // We now have a pointer to a live text block that has too much capacity.
            // Is it enough that we could fit this new text block?
            const sym = self.local_symbols.items[big_block.local_sym_index];
            const capacity = big_block.capacity(self.*);
            const ideal_capacity = padToIdeal(capacity);
            const ideal_capacity_end_vaddr = std.math.add(u64, sym.st_value, ideal_capacity) catch ideal_capacity;
            const capacity_end_vaddr = sym.st_value + capacity;
            const new_start_vaddr_unaligned = capacity_end_vaddr - new_block_ideal_capacity;
            const new_start_vaddr = mem.alignBackwardGeneric(u64, new_start_vaddr_unaligned, alignment);
            if (new_start_vaddr < ideal_capacity_end_vaddr) {
                // Additional bookkeeping here to notice if this free list node
                // should be deleted because the block that it points to has grown to take up
                // more of the extra capacity.
                if (!big_block.freeListEligible(self.*)) {
                    _ = free_list.swapRemove(i);
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
        } else if (self.atoms.get(phdr_index)) |last| {
            const sym = self.local_symbols.items[last.local_sym_index];
            const ideal_capacity = padToIdeal(sym.st_size);
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
            // Must move the entire section.
            const new_offset = self.findFreeSpace(needed_size, self.page_size);
            const text_size = if (self.atoms.get(phdr_index)) |last| blk: {
                const sym = self.local_symbols.items[last.local_sym_index];
                break :blk (sym.st_value + sym.st_size) - phdr.p_vaddr;
            } else 0;
            log.debug("new PT_LOAD file offset 0x{x} to 0x{x}", .{ new_offset, new_offset + text_size });
            const amt = try self.base.file.?.copyRangeAll(shdr.sh_offset, self.base.file.?, new_offset, text_size);
            if (amt != text_size) return error.InputOutput;
            shdr.sh_offset = new_offset;
            phdr.p_offset = new_offset;
        }
        _ = try self.atoms.put(self.base.allocator, phdr_index, text_block);

        shdr.sh_size = needed_size;
        phdr.p_memsz = needed_size;
        phdr.p_filesz = needed_size;

        if (self.dwarf) |_| {
            // The .debug_info section has `low_pc` and `high_pc` values which is the virtual address
            // range of the compilation unit. When we expand the text section, this range changes,
            // so the DW_TAG.compile_unit tag of the .debug_info section becomes dirty.
            self.debug_info_header_dirty = true;
            // This becomes dirty for the same reason. We could potentially make this more
            // fine-grained with the addition of support for more compilation units. It is planned to
            // model each package as a different compilation unit.
            self.debug_aranges_section_dirty = true;
        }

        self.phdr_table_dirty = true; // TODO look into making only the one program header dirty
        self.shdr_table_dirty = true; // TODO look into making only the one section dirty
    }
    shdr.sh_addralign = math.max(shdr.sh_addralign, alignment);

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
        _ = free_list.swapRemove(i);
    }
    return vaddr;
}

fn allocateLocalSymbol(self: *Elf) !u32 {
    try self.local_symbols.ensureUnusedCapacity(self.base.allocator, 1);

    const index = blk: {
        if (self.local_symbol_free_list.popOrNull()) |index| {
            log.debug("  (reusing symbol index {d})", .{index});
            break :blk index;
        } else {
            log.debug("  (allocating symbol index {d})", .{self.local_symbols.items.len});
            const index = @intCast(u32, self.local_symbols.items.len);
            _ = self.local_symbols.addOneAssumeCapacity();
            break :blk index;
        }
    };

    self.local_symbols.items[index] = .{
        .st_name = 0,
        .st_info = 0,
        .st_other = 0,
        .st_shndx = 0,
        .st_value = 0,
        .st_size = 0,
    };

    return index;
}

pub fn allocateDeclIndexes(self: *Elf, decl_index: Module.Decl.Index) !void {
    if (self.llvm_object) |_| return;

    const mod = self.base.options.module.?;
    const decl = mod.declPtr(decl_index);
    if (decl.link.elf.local_sym_index != 0) return;

    try self.offset_table.ensureUnusedCapacity(self.base.allocator, 1);
    try self.decls.putNoClobber(self.base.allocator, decl_index, null);

    const decl_name = try decl.getFullyQualifiedName(mod);
    defer self.base.allocator.free(decl_name);

    log.debug("allocating symbol indexes for {s}", .{decl_name});
    decl.link.elf.local_sym_index = try self.allocateLocalSymbol();
    try self.atom_by_index_table.putNoClobber(self.base.allocator, decl.link.elf.local_sym_index, &decl.link.elf);

    if (self.offset_table_free_list.popOrNull()) |i| {
        decl.link.elf.offset_table_index = i;
    } else {
        decl.link.elf.offset_table_index = @intCast(u32, self.offset_table.items.len);
        _ = self.offset_table.addOneAssumeCapacity();
        self.offset_table_count_dirty = true;
    }
    self.offset_table.items[decl.link.elf.offset_table_index] = 0;
}

fn freeUnnamedConsts(self: *Elf, decl_index: Module.Decl.Index) void {
    const unnamed_consts = self.unnamed_const_atoms.getPtr(decl_index) orelse return;
    for (unnamed_consts.items) |atom| {
        self.freeTextBlock(atom, self.phdr_load_ro_index.?);
        self.local_symbol_free_list.append(self.base.allocator, atom.local_sym_index) catch {};
        self.local_symbols.items[atom.local_sym_index].st_info = 0;
        _ = self.atom_by_index_table.remove(atom.local_sym_index);
    }
    unnamed_consts.clearAndFree(self.base.allocator);
}

pub fn freeDecl(self: *Elf, decl_index: Module.Decl.Index) void {
    if (build_options.have_llvm) {
        if (self.llvm_object) |llvm_object| return llvm_object.freeDecl(decl_index);
    }

    const mod = self.base.options.module.?;
    const decl = mod.declPtr(decl_index);

    const kv = self.decls.fetchRemove(decl_index);
    if (kv.?.value) |index| {
        self.freeTextBlock(&decl.link.elf, index);
        self.freeUnnamedConsts(decl_index);
    }

    // Appending to free lists is allowed to fail because the free lists are heuristics based anyway.
    if (decl.link.elf.local_sym_index != 0) {
        self.local_symbol_free_list.append(self.base.allocator, decl.link.elf.local_sym_index) catch {};
        self.local_symbols.items[decl.link.elf.local_sym_index].st_info = 0;
        _ = self.atom_by_index_table.remove(decl.link.elf.local_sym_index);
        decl.link.elf.local_sym_index = 0;

        self.offset_table_free_list.append(self.base.allocator, decl.link.elf.offset_table_index) catch {};
    }

    if (self.dwarf) |*dw| {
        dw.freeDecl(decl);
    }
}

fn getDeclPhdrIndex(self: *Elf, decl: *Module.Decl) !u16 {
    const ty = decl.ty;
    const zig_ty = ty.zigTypeTag();
    const val = decl.val;
    const phdr_index: u16 = blk: {
        if (val.isUndefDeep()) {
            // TODO in release-fast and release-small, we should put undef in .bss
            break :blk self.phdr_load_rw_index.?;
        }

        switch (zig_ty) {
            .Fn => break :blk self.phdr_load_re_index.?,
            else => {
                if (val.castTag(.variable)) |_| {
                    break :blk self.phdr_load_rw_index.?;
                }
                break :blk self.phdr_load_ro_index.?;
            },
        }
    };
    return phdr_index;
}

fn updateDeclCode(self: *Elf, decl_index: Module.Decl.Index, code: []const u8, stt_bits: u8) !*elf.Elf64_Sym {
    const mod = self.base.options.module.?;
    const decl = mod.declPtr(decl_index);

    const decl_name = try decl.getFullyQualifiedName(mod);
    defer self.base.allocator.free(decl_name);

    log.debug("updateDeclCode {s}{*}", .{ decl_name, decl });
    const required_alignment = decl.getAlignment(self.base.options.target);

    const decl_ptr = self.decls.getPtr(decl_index).?;
    if (decl_ptr.* == null) {
        decl_ptr.* = try self.getDeclPhdrIndex(decl);
    }
    const phdr_index = decl_ptr.*.?;
    const shdr_index = self.phdr_shdr_table.get(phdr_index).?;

    assert(decl.link.elf.local_sym_index != 0); // Caller forgot to allocateDeclIndexes()
    const local_sym = &self.local_symbols.items[decl.link.elf.local_sym_index];
    if (local_sym.st_size != 0) {
        const capacity = decl.link.elf.capacity(self.*);
        const need_realloc = code.len > capacity or
            !mem.isAlignedGeneric(u64, local_sym.st_value, required_alignment);
        if (need_realloc) {
            const vaddr = try self.growTextBlock(&decl.link.elf, code.len, required_alignment, phdr_index);
            log.debug("growing {s} from 0x{x} to 0x{x}", .{ decl_name, local_sym.st_value, vaddr });
            if (vaddr != local_sym.st_value) {
                local_sym.st_value = vaddr;

                log.debug("  (writing new offset table entry)", .{});
                self.offset_table.items[decl.link.elf.offset_table_index] = vaddr;
                try self.writeOffsetTableEntry(decl.link.elf.offset_table_index);
            }
        } else if (code.len < local_sym.st_size) {
            self.shrinkTextBlock(&decl.link.elf, code.len, phdr_index);
        }
        local_sym.st_size = code.len;
        local_sym.st_name = try self.updateString(local_sym.st_name, decl_name);
        local_sym.st_info = (elf.STB_LOCAL << 4) | stt_bits;
        local_sym.st_other = 0;
        local_sym.st_shndx = shdr_index;
        // TODO this write could be avoided if no fields of the symbol were changed.
        try self.writeSymbol(decl.link.elf.local_sym_index);
    } else {
        const name_str_index = try self.makeString(decl_name);
        const vaddr = try self.allocateTextBlock(&decl.link.elf, code.len, required_alignment, phdr_index);
        errdefer self.freeTextBlock(&decl.link.elf, phdr_index);
        log.debug("allocated text block for {s} at 0x{x}", .{ decl_name, vaddr });

        local_sym.* = .{
            .st_name = name_str_index,
            .st_info = (elf.STB_LOCAL << 4) | stt_bits,
            .st_other = 0,
            .st_shndx = shdr_index,
            .st_value = vaddr,
            .st_size = code.len,
        };
        self.offset_table.items[decl.link.elf.offset_table_index] = vaddr;

        try self.writeSymbol(decl.link.elf.local_sym_index);
        try self.writeOffsetTableEntry(decl.link.elf.offset_table_index);
    }

    const section_offset = local_sym.st_value - self.program_headers.items[phdr_index].p_vaddr;
    const file_offset = self.sections.items[shdr_index].sh_offset + section_offset;
    try self.base.file.?.pwriteAll(code, file_offset);

    return local_sym;
}

pub fn updateFunc(self: *Elf, module: *Module, func: *Module.Fn, air: Air, liveness: Liveness) !void {
    if (build_options.skip_non_native and builtin.object_format != .elf) {
        @panic("Attempted to compile for object format that was disabled by build configuration");
    }
    if (build_options.have_llvm) {
        if (self.llvm_object) |llvm_object| return llvm_object.updateFunc(module, func, air, liveness);
    }

    const tracy = trace(@src());
    defer tracy.end();

    var code_buffer = std.ArrayList(u8).init(self.base.allocator);
    defer code_buffer.deinit();

    const decl_index = func.owner_decl;
    const decl = module.declPtr(decl_index);
    self.freeUnnamedConsts(decl_index);

    var decl_state: ?Dwarf.DeclState = if (self.dwarf) |*dw| try dw.initDeclState(module, decl) else null;
    defer if (decl_state) |*ds| ds.deinit();

    const res = if (decl_state) |*ds|
        try codegen.generateFunction(&self.base, decl.srcLoc(), func, air, liveness, &code_buffer, .{
            .dwarf = ds,
        })
    else
        try codegen.generateFunction(&self.base, decl.srcLoc(), func, air, liveness, &code_buffer, .none);

    const code = switch (res) {
        .appended => code_buffer.items,
        .fail => |em| {
            decl.analysis = .codegen_failure;
            try module.failed_decls.put(module.gpa, decl_index, em);
            return;
        },
    };
    const local_sym = try self.updateDeclCode(decl_index, code, elf.STT_FUNC);
    if (decl_state) |*ds| {
        try self.dwarf.?.commitDeclState(
            &self.base,
            module,
            decl,
            local_sym.st_value,
            local_sym.st_size,
            ds,
        );
    }

    // Since we updated the vaddr and the size, each corresponding export symbol also needs to be updated.
    const decl_exports = module.decl_exports.get(decl_index) orelse &[0]*Module.Export{};
    return self.updateDeclExports(module, decl_index, decl_exports);
}

pub fn updateDecl(self: *Elf, module: *Module, decl_index: Module.Decl.Index) !void {
    if (build_options.skip_non_native and builtin.object_format != .elf) {
        @panic("Attempted to compile for object format that was disabled by build configuration");
    }
    if (build_options.have_llvm) {
        if (self.llvm_object) |llvm_object| return llvm_object.updateDecl(module, decl_index);
    }

    const tracy = trace(@src());
    defer tracy.end();

    const decl = module.declPtr(decl_index);

    if (decl.val.tag() == .extern_fn) {
        return; // TODO Should we do more when front-end analyzed extern decl?
    }
    if (decl.val.castTag(.variable)) |payload| {
        const variable = payload.data;
        if (variable.is_extern) {
            return; // TODO Should we do more when front-end analyzed extern decl?
        }
    }

    assert(!self.unnamed_const_atoms.contains(decl_index));

    var code_buffer = std.ArrayList(u8).init(self.base.allocator);
    defer code_buffer.deinit();

    var decl_state: ?Dwarf.DeclState = if (self.dwarf) |*dw| try dw.initDeclState(module, decl) else null;
    defer if (decl_state) |*ds| ds.deinit();

    // TODO implement .debug_info for global variables
    const decl_val = if (decl.val.castTag(.variable)) |payload| payload.data.init else decl.val;
    const res = if (decl_state) |*ds|
        try codegen.generateSymbol(&self.base, decl.srcLoc(), .{
            .ty = decl.ty,
            .val = decl_val,
        }, &code_buffer, .{
            .dwarf = ds,
        }, .{
            .parent_atom_index = decl.link.elf.local_sym_index,
        })
    else
        try codegen.generateSymbol(&self.base, decl.srcLoc(), .{
            .ty = decl.ty,
            .val = decl_val,
        }, &code_buffer, .none, .{
            .parent_atom_index = decl.link.elf.local_sym_index,
        });

    const code = switch (res) {
        .externally_managed => |x| x,
        .appended => code_buffer.items,
        .fail => |em| {
            decl.analysis = .codegen_failure;
            try module.failed_decls.put(module.gpa, decl_index, em);
            return;
        },
    };

    const local_sym = try self.updateDeclCode(decl_index, code, elf.STT_OBJECT);
    if (decl_state) |*ds| {
        try self.dwarf.?.commitDeclState(
            &self.base,
            module,
            decl,
            local_sym.st_value,
            local_sym.st_size,
            ds,
        );
    }

    // Since we updated the vaddr and the size, each corresponding export symbol also needs to be updated.
    const decl_exports = module.decl_exports.get(decl_index) orelse &[0]*Module.Export{};
    return self.updateDeclExports(module, decl_index, decl_exports);
}

pub fn lowerUnnamedConst(self: *Elf, typed_value: TypedValue, decl_index: Module.Decl.Index) !u32 {
    var code_buffer = std.ArrayList(u8).init(self.base.allocator);
    defer code_buffer.deinit();

    const mod = self.base.options.module.?;
    const decl = mod.declPtr(decl_index);

    const gop = try self.unnamed_const_atoms.getOrPut(self.base.allocator, decl_index);
    if (!gop.found_existing) {
        gop.value_ptr.* = .{};
    }
    const unnamed_consts = gop.value_ptr;

    const atom = try self.base.allocator.create(TextBlock);
    errdefer self.base.allocator.destroy(atom);
    atom.* = TextBlock.empty;
    try self.managed_atoms.append(self.base.allocator, atom);

    const name_str_index = blk: {
        const decl_name = try decl.getFullyQualifiedName(mod);
        defer self.base.allocator.free(decl_name);

        const index = unnamed_consts.items.len;
        const name = try std.fmt.allocPrint(self.base.allocator, "__unnamed_{s}_{d}", .{ decl_name, index });
        defer self.base.allocator.free(name);

        break :blk try self.makeString(name);
    };
    const name = self.getString(name_str_index);

    log.debug("allocating symbol indexes for {s}", .{name});
    atom.local_sym_index = try self.allocateLocalSymbol();
    try self.atom_by_index_table.putNoClobber(self.base.allocator, atom.local_sym_index, atom);

    const res = try codegen.generateSymbol(&self.base, decl.srcLoc(), typed_value, &code_buffer, .{
        .none = {},
    }, .{
        .parent_atom_index = atom.local_sym_index,
    });
    const code = switch (res) {
        .externally_managed => |x| x,
        .appended => code_buffer.items,
        .fail => |em| {
            decl.analysis = .codegen_failure;
            try mod.failed_decls.put(mod.gpa, decl_index, em);
            log.err("{s}", .{em.msg});
            return error.AnalysisFail;
        },
    };

    const required_alignment = typed_value.ty.abiAlignment(self.base.options.target);
    const phdr_index = self.phdr_load_ro_index.?;
    const shdr_index = self.phdr_shdr_table.get(phdr_index).?;
    const vaddr = try self.allocateTextBlock(atom, code.len, required_alignment, phdr_index);
    errdefer self.freeTextBlock(atom, phdr_index);

    log.debug("allocated text block for {s} at 0x{x}", .{ name, vaddr });

    const local_sym = &self.local_symbols.items[atom.local_sym_index];
    local_sym.* = .{
        .st_name = name_str_index,
        .st_info = (elf.STB_LOCAL << 4) | elf.STT_OBJECT,
        .st_other = 0,
        .st_shndx = shdr_index,
        .st_value = vaddr,
        .st_size = code.len,
    };

    try self.writeSymbol(atom.local_sym_index);
    try unnamed_consts.append(self.base.allocator, atom);

    const section_offset = local_sym.st_value - self.program_headers.items[phdr_index].p_vaddr;
    const file_offset = self.sections.items[shdr_index].sh_offset + section_offset;
    try self.base.file.?.pwriteAll(code, file_offset);

    return atom.local_sym_index;
}

pub fn updateDeclExports(
    self: *Elf,
    module: *Module,
    decl_index: Module.Decl.Index,
    exports: []const *Module.Export,
) !void {
    if (build_options.skip_non_native and builtin.object_format != .elf) {
        @panic("Attempted to compile for object format that was disabled by build configuration");
    }
    if (build_options.have_llvm) {
        if (self.llvm_object) |llvm_object| return llvm_object.updateDeclExports(module, decl_index, exports);
    }

    const tracy = trace(@src());
    defer tracy.end();

    try self.global_symbols.ensureUnusedCapacity(self.base.allocator, exports.len);
    const decl = module.declPtr(decl_index);
    if (decl.link.elf.local_sym_index == 0) return;
    const decl_sym = self.local_symbols.items[decl.link.elf.local_sym_index];

    const decl_ptr = self.decls.getPtr(decl_index).?;
    if (decl_ptr.* == null) {
        decl_ptr.* = try self.getDeclPhdrIndex(decl);
    }
    const phdr_index = decl_ptr.*.?;
    const shdr_index = self.phdr_shdr_table.get(phdr_index).?;

    for (exports) |exp| {
        if (exp.options.section) |section_name| {
            if (!mem.eql(u8, section_name, ".text")) {
                try module.failed_exports.ensureUnusedCapacity(module.gpa, 1);
                module.failed_exports.putAssumeCapacityNoClobber(
                    exp,
                    try Module.ErrorMsg.create(self.base.allocator, decl.srcLoc(), "Unimplemented: ExportOptions.section", .{}),
                );
                continue;
            }
        }
        const stb_bits: u8 = switch (exp.options.linkage) {
            .Internal => elf.STB_LOCAL,
            .Strong => blk: {
                const entry_name = self.base.options.entry orelse "_start";
                if (mem.eql(u8, exp.options.name, entry_name)) {
                    self.entry_addr = decl_sym.st_value;
                }
                break :blk elf.STB_GLOBAL;
            },
            .Weak => elf.STB_WEAK,
            .LinkOnce => {
                try module.failed_exports.ensureUnusedCapacity(module.gpa, 1);
                module.failed_exports.putAssumeCapacityNoClobber(
                    exp,
                    try Module.ErrorMsg.create(self.base.allocator, decl.srcLoc(), "Unimplemented: GlobalLinkage.LinkOnce", .{}),
                );
                continue;
            },
        };
        const stt_bits: u8 = @truncate(u4, decl_sym.st_info);
        if (exp.link.elf.sym_index) |i| {
            const sym = &self.global_symbols.items[i];
            sym.* = .{
                .st_name = try self.updateString(sym.st_name, exp.options.name),
                .st_info = (stb_bits << 4) | stt_bits,
                .st_other = 0,
                .st_shndx = shdr_index,
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
                .st_shndx = shdr_index,
                .st_value = decl_sym.st_value,
                .st_size = decl_sym.st_size,
            };

            exp.link.elf.sym_index = @intCast(u32, i);
        }
    }
}

/// Must be called only after a successful call to `updateDecl`.
pub fn updateDeclLineNumber(self: *Elf, mod: *Module, decl: *const Module.Decl) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const decl_name = try decl.getFullyQualifiedName(mod);
    defer self.base.allocator.free(decl_name);

    log.debug("updateDeclLineNumber {s}{*}", .{ decl_name, decl });

    if (self.llvm_object) |_| return;
    if (self.dwarf) |*dw| {
        try dw.updateDeclLineNumber(&self.base, decl);
    }
}

pub fn deleteExport(self: *Elf, exp: Export) void {
    if (self.llvm_object) |_| return;

    const sym_index = exp.sym_index orelse return;
    self.global_symbol_free_list.append(self.base.allocator, sym_index) catch {};
    self.global_symbols.items[sym_index].st_info = 0;
}

fn writeProgHeader(self: *Elf, index: usize) !void {
    const foreign_endian = self.base.options.target.cpu.arch.endian() != builtin.cpu.arch.endian();
    const offset = self.program_headers.items[index].p_offset;
    switch (self.ptr_width) {
        .p32 => {
            var phdr = [1]elf.Elf32_Phdr{progHeaderTo32(self.program_headers.items[index])};
            if (foreign_endian) {
                mem.byteSwapAllFields(elf.Elf32_Phdr, &phdr[0]);
            }
            return self.base.file.?.pwriteAll(mem.sliceAsBytes(&phdr), offset);
        },
        .p64 => {
            var phdr = [1]elf.Elf64_Phdr{self.program_headers.items[index]};
            if (foreign_endian) {
                mem.byteSwapAllFields(elf.Elf64_Phdr, &phdr[0]);
            }
            return self.base.file.?.pwriteAll(mem.sliceAsBytes(&phdr), offset);
        },
    }
}

fn writeSectHeader(self: *Elf, index: usize) !void {
    const foreign_endian = self.base.options.target.cpu.arch.endian() != builtin.cpu.arch.endian();
    switch (self.ptr_width) {
        .p32 => {
            var shdr: [1]elf.Elf32_Shdr = undefined;
            shdr[0] = sectHeaderTo32(self.sections.items[index]);
            if (foreign_endian) {
                mem.byteSwapAllFields(elf.Elf32_Shdr, &shdr[0]);
            }
            const offset = self.shdr_table_offset.? + index * @sizeOf(elf.Elf32_Shdr);
            return self.base.file.?.pwriteAll(mem.sliceAsBytes(&shdr), offset);
        },
        .p64 => {
            var shdr = [1]elf.Elf64_Shdr{self.sections.items[index]};
            if (foreign_endian) {
                mem.byteSwapAllFields(elf.Elf64_Shdr, &shdr[0]);
            }
            const offset = self.shdr_table_offset.? + index * @sizeOf(elf.Elf64_Shdr);
            return self.base.file.?.pwriteAll(mem.sliceAsBytes(&shdr), offset);
        },
    }
}

fn writeOffsetTableEntry(self: *Elf, index: usize) !void {
    const shdr = &self.sections.items[self.got_section_index.?];
    const phdr = &self.program_headers.items[self.phdr_got_index.?];
    const entry_size: u16 = self.archPtrWidthBytes();
    if (self.offset_table_count_dirty) {
        // TODO Also detect virtual address collisions.
        const allocated_size = self.allocatedSize(shdr.sh_offset);
        const needed_size = self.offset_table.items.len * entry_size;
        if (needed_size > allocated_size) {
            // Must move the entire got section.
            const new_offset = self.findFreeSpace(needed_size, self.page_size);
            const amt = try self.base.file.?.copyRangeAll(shdr.sh_offset, self.base.file.?, new_offset, shdr.sh_size);
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
    switch (entry_size) {
        2 => {
            var buf: [2]u8 = undefined;
            mem.writeInt(u16, &buf, @intCast(u16, self.offset_table.items[index]), endian);
            try self.base.file.?.pwriteAll(&buf, off);
        },
        4 => {
            var buf: [4]u8 = undefined;
            mem.writeInt(u32, &buf, @intCast(u32, self.offset_table.items[index]), endian);
            try self.base.file.?.pwriteAll(&buf, off);
        },
        8 => {
            var buf: [8]u8 = undefined;
            mem.writeInt(u64, &buf, self.offset_table.items[index], endian);
            try self.base.file.?.pwriteAll(&buf, off);
        },
        else => unreachable,
    }
}

fn writeSymbol(self: *Elf, index: usize) !void {
    const tracy = trace(@src());
    defer tracy.end();

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
            log.debug("moving '.symtab' from 0x{x} to 0x{x}", .{ syms_sect.sh_offset, new_offset });
            const existing_size = @as(u64, syms_sect.sh_info) * sym_size;
            const amt = try self.base.file.?.copyRangeAll(
                syms_sect.sh_offset,
                self.base.file.?,
                new_offset,
                existing_size,
            );
            if (amt != existing_size) return error.InputOutput;
            syms_sect.sh_offset = new_offset;
        }
        syms_sect.sh_info = @intCast(u32, self.local_symbols.items.len);
        syms_sect.sh_size = needed_size; // anticipating adding the global symbols later
        self.shdr_table_dirty = true; // TODO look into only writing one section
    }
    const foreign_endian = self.base.options.target.cpu.arch.endian() != builtin.cpu.arch.endian();
    const off = switch (self.ptr_width) {
        .p32 => syms_sect.sh_offset + @sizeOf(elf.Elf32_Sym) * index,
        .p64 => syms_sect.sh_offset + @sizeOf(elf.Elf64_Sym) * index,
    };
    const local = self.local_symbols.items[index];
    log.debug("writing symbol {d}, '{s}' at 0x{x}", .{ index, self.getString(local.st_name), off });
    log.debug("  ({})", .{local});
    switch (self.ptr_width) {
        .p32 => {
            var sym = [1]elf.Elf32_Sym{
                .{
                    .st_name = local.st_name,
                    .st_value = @intCast(u32, local.st_value),
                    .st_size = @intCast(u32, local.st_size),
                    .st_info = local.st_info,
                    .st_other = local.st_other,
                    .st_shndx = local.st_shndx,
                },
            };
            if (foreign_endian) {
                mem.byteSwapAllFields(elf.Elf32_Sym, &sym[0]);
            }
            try self.base.file.?.pwriteAll(mem.sliceAsBytes(sym[0..1]), off);
        },
        .p64 => {
            var sym = [1]elf.Elf64_Sym{local};
            if (foreign_endian) {
                mem.byteSwapAllFields(elf.Elf64_Sym, &sym[0]);
            }
            try self.base.file.?.pwriteAll(mem.sliceAsBytes(sym[0..1]), off);
        },
    }
}

fn writeAllGlobalSymbols(self: *Elf) !void {
    const syms_sect = &self.sections.items[self.symtab_section_index.?];
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
        log.debug("moving '.symtab' from 0x{x} to 0x{x}", .{ syms_sect.sh_offset, new_offset });
        const existing_size = @as(u64, syms_sect.sh_info) * sym_size;
        const amt = try self.base.file.?.copyRangeAll(
            syms_sect.sh_offset,
            self.base.file.?,
            new_offset,
            existing_size,
        );
        if (amt != existing_size) return error.InputOutput;
        syms_sect.sh_offset = new_offset;
    }
    syms_sect.sh_size = needed_size; // anticipating adding the global symbols later
    self.shdr_table_dirty = true; // TODO look into only writing one section

    const foreign_endian = self.base.options.target.cpu.arch.endian() != builtin.cpu.arch.endian();
    const global_syms_off = syms_sect.sh_offset + self.local_symbols.items.len * sym_size;
    log.debug("writing {d} global symbols at 0x{x}", .{ self.global_symbols.items.len, global_syms_off });
    switch (self.ptr_width) {
        .p32 => {
            const buf = try self.base.allocator.alloc(elf.Elf32_Sym, self.global_symbols.items.len);
            defer self.base.allocator.free(buf);

            for (buf) |*sym, i| {
                const global = self.global_symbols.items[i];
                sym.* = .{
                    .st_name = global.st_name,
                    .st_value = @intCast(u32, global.st_value),
                    .st_size = @intCast(u32, global.st_size),
                    .st_info = global.st_info,
                    .st_other = global.st_other,
                    .st_shndx = global.st_shndx,
                };
                if (foreign_endian) {
                    mem.byteSwapAllFields(elf.Elf32_Sym, sym);
                }
            }
            try self.base.file.?.pwriteAll(mem.sliceAsBytes(buf), global_syms_off);
        },
        .p64 => {
            const buf = try self.base.allocator.alloc(elf.Elf64_Sym, self.global_symbols.items.len);
            defer self.base.allocator.free(buf);

            for (buf) |*sym, i| {
                const global = self.global_symbols.items[i];
                sym.* = .{
                    .st_name = global.st_name,
                    .st_value = global.st_value,
                    .st_size = global.st_size,
                    .st_info = global.st_info,
                    .st_other = global.st_other,
                    .st_shndx = global.st_shndx,
                };
                if (foreign_endian) {
                    mem.byteSwapAllFields(elf.Elf64_Sym, sym);
                }
            }
            try self.base.file.?.pwriteAll(mem.sliceAsBytes(buf), global_syms_off);
        },
    }
}

/// Always 4 or 8 depending on whether this is 32-bit ELF or 64-bit ELF.
fn ptrWidthBytes(self: Elf) u8 {
    return switch (self.ptr_width) {
        .p32 => 4,
        .p64 => 8,
    };
}

/// Does not necessarily match `ptrWidthBytes` for example can be 2 bytes
/// in a 32-bit ELF file.
fn archPtrWidthBytes(self: Elf) u8 {
    return @intCast(u8, self.base.options.target.cpu.arch.ptrBitWidth() / 8);
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

fn getLDMOption(target: std.Target) ?[]const u8 {
    switch (target.cpu.arch) {
        .i386 => return "elf_i386",
        .aarch64 => return "aarch64linux",
        .aarch64_be => return "aarch64_be_linux",
        .arm, .thumb => return "armelf_linux_eabi",
        .armeb, .thumbeb => return "armebelf_linux_eabi",
        .powerpc => return "elf32ppclinux",
        .powerpc64 => return "elf64ppc",
        .powerpc64le => return "elf64lppc",
        .sparc, .sparcel => return "elf32_sparc",
        .sparc64 => return "elf64_sparc",
        .mips => return "elf32btsmip",
        .mipsel => return "elf32ltsmip",
        .mips64 => {
            if (target.abi == .gnuabin32) {
                return "elf32btsmipn32";
            } else {
                return "elf64btsmip";
            }
        },
        .mips64el => {
            if (target.abi == .gnuabin32) {
                return "elf32ltsmipn32";
            } else {
                return "elf64ltsmip";
            }
        },
        .s390x => return "elf64_s390",
        .x86_64 => {
            if (target.abi == .gnux32) {
                return "elf32_x86_64";
            } else {
                return "elf_x86_64";
            }
        },
        .riscv32 => return "elf32lriscv",
        .riscv64 => return "elf64lriscv",
        else => return null,
    }
}

fn padToIdeal(actual_size: anytype) @TypeOf(actual_size) {
    // TODO https://github.com/ziglang/zig/issues/1284
    return std.math.add(@TypeOf(actual_size), actual_size, actual_size / ideal_factor) catch
        std.math.maxInt(@TypeOf(actual_size));
}

// Provide a blueprint of csu (c-runtime startup) objects for supported
// link modes.
//
// This is for cross-mode targets only. For host-mode targets the system
// compiler can be probed to produce a robust blueprint.
//
// Targets requiring a libc for which zig does not bundle a libc are
// host-mode targets. Unfortunately, host-mode probes are not yet
// implemented. For now the data is hard-coded here. Such targets are
// { freebsd, netbsd, openbsd, dragonfly }.
const CsuObjects = struct {
    crt0: ?[]const u8 = null,
    crti: ?[]const u8 = null,
    crtbegin: ?[]const u8 = null,
    crtend: ?[]const u8 = null,
    crtn: ?[]const u8 = null,

    fn init(arena: mem.Allocator, link_options: link.Options, comp: *const Compilation) !CsuObjects {
        // crt objects are only required for libc.
        if (!link_options.link_libc) return CsuObjects{};

        var result: CsuObjects = .{};

        // TODO: https://github.com/ziglang/zig/issues/4629
        // - use inline enum type
        // - reduce to enum-literals for values
        const Mode = enum {
            dynamic_lib,
            dynamic_exe,
            dynamic_pie,
            static_exe,
            static_pie,
        };

        // Flatten crt case types.
        const mode: Mode = switch (link_options.output_mode) {
            .Obj => return CsuObjects{},
            .Lib => switch (link_options.link_mode) {
                .Dynamic => Mode.dynamic_lib,
                .Static => return CsuObjects{},
            },
            .Exe => switch (link_options.link_mode) {
                .Dynamic => if (link_options.pie) Mode.dynamic_pie else Mode.dynamic_exe,
                .Static => if (link_options.pie) Mode.static_pie else Mode.static_exe,
            },
        };

        if (link_options.target.isAndroid()) {
            switch (mode) {
                // zig fmt: off
                .dynamic_lib => result.set( null, null, "crtbegin_so.o",      "crtend_so.o",      null ),
                .dynamic_exe,
                .dynamic_pie => result.set( null, null, "crtbegin_dynamic.o", "crtend_android.o", null ),
                .static_exe,
                .static_pie  => result.set( null, null, "crtbegin_static.o",  "crtend_android.o", null ),
                // zig fmt: on
            }
        } else {
            switch (link_options.target.os.tag) {
                .linux => {
                    switch (mode) {
                        // zig fmt: off
                        .dynamic_lib => result.set( null,      "crti.o", "crtbeginS.o", "crtendS.o", "crtn.o" ),
                        .dynamic_exe => result.set( "crt1.o",  "crti.o", "crtbegin.o",  "crtend.o",  "crtn.o" ),
                        .dynamic_pie => result.set( "Scrt1.o", "crti.o", "crtbeginS.o", "crtendS.o", "crtn.o" ),
                        .static_exe  => result.set( "crt1.o",  "crti.o", "crtbeginT.o", "crtend.o",  "crtn.o" ),
                        .static_pie  => result.set( "rcrt1.o", "crti.o", "crtbeginS.o", "crtendS.o", "crtn.o" ),
                        // zig fmt: on
                    }
                    if (link_options.libc_installation) |_| {
                        // hosted-glibc provides crtbegin/end objects in platform/compiler-specific dirs
                        // and they are not known at comptime. For now null-out crtbegin/end objects;
                        // there is no feature loss, zig has never linked those objects in before.
                        // TODO: probe for paths, ie. `cc -print-file-name`
                        result.crtbegin = null;
                        result.crtend = null;
                    } else {
                        // Bundled glibc only has Scrt1.o .
                        if (result.crt0 != null and link_options.target.isGnuLibC()) result.crt0 = "Scrt1.o";
                    }
                },
                .dragonfly => switch (mode) {
                    // zig fmt: off
                    .dynamic_lib => result.set( null,      "crti.o", "crtbeginS.o",  "crtendS.o", "crtn.o" ),
                    .dynamic_exe => result.set( "crt1.o",  "crti.o", "crtbegin.o",   "crtend.o",  "crtn.o" ),
                    .dynamic_pie => result.set( "Scrt1.o", "crti.o", "crtbeginS.o",  "crtendS.o", "crtn.o" ),
                    .static_exe  => result.set( "crt1.o",  "crti.o", "crtbegin.o",   "crtend.o",  "crtn.o" ),
                    .static_pie  => result.set( "Scrt1.o", "crti.o", "crtbeginS.o",  "crtendS.o", "crtn.o" ),
                    // zig fmt: on
                },
                .freebsd => switch (mode) {
                    // zig fmt: off
                    .dynamic_lib => result.set( null,      "crti.o", "crtbeginS.o", "crtendS.o", "crtn.o" ),
                    .dynamic_exe => result.set( "crt1.o",  "crti.o", "crtbegin.o",  "crtend.o",  "crtn.o" ),
                    .dynamic_pie => result.set( "Scrt1.o", "crti.o", "crtbeginS.o", "crtendS.o", "crtn.o" ),
                    .static_exe  => result.set( "crt1.o",  "crti.o", "crtbeginT.o", "crtend.o",  "crtn.o" ),
                    .static_pie  => result.set( "Scrt1.o", "crti.o", "crtbeginS.o", "crtendS.o", "crtn.o" ),
                    // zig fmt: on
                },
                .netbsd => switch (mode) {
                    // zig fmt: off
                    .dynamic_lib => result.set( null,     "crti.o", "crtbeginS.o", "crtendS.o", "crtn.o" ),
                    .dynamic_exe => result.set( "crt0.o", "crti.o", "crtbegin.o",  "crtend.o",  "crtn.o" ),
                    .dynamic_pie => result.set( "crt0.o", "crti.o", "crtbeginS.o", "crtendS.o", "crtn.o" ),
                    .static_exe  => result.set( "crt0.o", "crti.o", "crtbeginT.o", "crtend.o",  "crtn.o" ),
                    .static_pie  => result.set( "crt0.o", "crti.o", "crtbeginT.o", "crtendS.o", "crtn.o" ),
                    // zig fmt: on
                },
                .openbsd => switch (mode) {
                    // zig fmt: off
                    .dynamic_lib => result.set( null,      null, "crtbeginS.o", "crtendS.o", null ),
                    .dynamic_exe,
                    .dynamic_pie => result.set( "crt0.o",  null, "crtbegin.o",  "crtend.o",  null ),
                    .static_exe,
                    .static_pie  => result.set( "rcrt0.o", null, "crtbegin.o",  "crtend.o",  null ),
                    // zig fmt: on
                },
                .haiku => switch (mode) {
                    // zig fmt: off
                    .dynamic_lib => result.set( null,          "crti.o", "crtbeginS.o", "crtendS.o", "crtn.o" ),
                    .dynamic_exe => result.set( "start_dyn.o", "crti.o", "crtbegin.o",  "crtend.o",  "crtn.o" ),
                    .dynamic_pie => result.set( "start_dyn.o", "crti.o", "crtbeginS.o", "crtendS.o", "crtn.o" ),
                    .static_exe  => result.set( "start_dyn.o", "crti.o", "crtbegin.o",  "crtend.o",  "crtn.o" ),
                    .static_pie  => result.set( "start_dyn.o", "crti.o", "crtbeginS.o", "crtendS.o", "crtn.o" ),
                    // zig fmt: on
                },
                .solaris => switch (mode) {
                    // zig fmt: off
                    .dynamic_lib => result.set( null,     "crti.o", null, null, "crtn.o" ),
                    .dynamic_exe,
                    .dynamic_pie => result.set( "crt1.o", "crti.o", null, null, "crtn.o" ),
                    .static_exe,
                    .static_pie  => result.set( null,     null,     null, null, null     ),
                    // zig fmt: on
                },
                else => {},
            }
        }

        // Convert each object to a full pathname.
        if (link_options.libc_installation) |lci| {
            const crt_dir_path = lci.crt_dir orelse return error.LibCInstallationMissingCRTDir;
            switch (link_options.target.os.tag) {
                .dragonfly => {
                    if (result.crt0) |*obj| obj.* = try fs.path.join(arena, &[_][]const u8{ crt_dir_path, obj.* });
                    if (result.crti) |*obj| obj.* = try fs.path.join(arena, &[_][]const u8{ crt_dir_path, obj.* });
                    if (result.crtn) |*obj| obj.* = try fs.path.join(arena, &[_][]const u8{ crt_dir_path, obj.* });

                    var gccv: []const u8 = undefined;
                    if (link_options.target.os.version_range.semver.isAtLeast(.{ .major = 5, .minor = 4 }) orelse true) {
                        gccv = "gcc80";
                    } else {
                        gccv = "gcc54";
                    }

                    if (result.crtbegin) |*obj| obj.* = try fs.path.join(arena, &[_][]const u8{ crt_dir_path, gccv, obj.* });
                    if (result.crtend) |*obj| obj.* = try fs.path.join(arena, &[_][]const u8{ crt_dir_path, gccv, obj.* });
                },
                .haiku => {
                    const gcc_dir_path = lci.gcc_dir orelse return error.LibCInstallationMissingCRTDir;
                    if (result.crt0) |*obj| obj.* = try fs.path.join(arena, &[_][]const u8{ crt_dir_path, obj.* });
                    if (result.crti) |*obj| obj.* = try fs.path.join(arena, &[_][]const u8{ crt_dir_path, obj.* });
                    if (result.crtn) |*obj| obj.* = try fs.path.join(arena, &[_][]const u8{ crt_dir_path, obj.* });

                    if (result.crtbegin) |*obj| obj.* = try fs.path.join(arena, &[_][]const u8{ gcc_dir_path, obj.* });
                    if (result.crtend) |*obj| obj.* = try fs.path.join(arena, &[_][]const u8{ gcc_dir_path, obj.* });
                },
                else => {
                    inline for (std.meta.fields(@TypeOf(result))) |f| {
                        if (@field(result, f.name)) |*obj| {
                            obj.* = try fs.path.join(arena, &[_][]const u8{ crt_dir_path, obj.* });
                        }
                    }
                },
            }
        } else {
            inline for (std.meta.fields(@TypeOf(result))) |f| {
                if (@field(result, f.name)) |*obj| {
                    if (comp.crt_files.get(obj.*)) |crtf| {
                        obj.* = crtf.full_object_path;
                    } else {
                        @field(result, f.name) = null;
                    }
                }
            }
        }

        return result;
    }

    fn set(
        self: *CsuObjects,
        crt0: ?[]const u8,
        crti: ?[]const u8,
        crtbegin: ?[]const u8,
        crtend: ?[]const u8,
        crtn: ?[]const u8,
    ) void {
        self.crt0 = crt0;
        self.crti = crti;
        self.crtbegin = crtbegin;
        self.crtend = crtend;
        self.crtn = crtn;
    }
};

fn logSymtab(self: Elf) void {
    log.debug("locals:", .{});
    for (self.local_symbols.items) |sym, id| {
        log.debug("  {d}: {s}: @{x} in {d}", .{ id, self.getString(sym.st_name), sym.st_value, sym.st_shndx });
    }
    log.debug("globals:", .{});
    for (self.global_symbols.items) |sym, id| {
        log.debug("  {d}: {s}: @{x} in {d}", .{ id, self.getString(sym.st_name), sym.st_value, sym.st_shndx });
    }
}
