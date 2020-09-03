const Coff = @This();

const std = @import("std");
const log = std.log.scoped(.link);
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const fs = std.fs;

const trace = @import("../tracy.zig").trace;
const Module = @import("../Module.zig");
const codegen = @import("../codegen.zig");
const link = @import("../link.zig");

const allocation_padding = 4 / 3;
const minimum_text_block_size = 64 * allocation_padding;

const section_alignment = 4096;
const file_alignment = 512;
const image_base = 0x400_000;
const section_table_size = 2 * 40;
comptime {
    std.debug.assert(std.mem.isAligned(image_base, section_alignment));
}

pub const base_tag: link.File.Tag = .coff;

const msdos_stub = @embedFile("msdos-stub.bin");

base: link.File,
ptr_width: enum { p32, p64 },
error_flags: link.File.ErrorFlags = .{},

text_block_free_list: std.ArrayListUnmanaged(*TextBlock) = .{},
last_text_block: ?*TextBlock = null,

/// Section table file pointer.
section_table_offset: u32 = 0,
/// Section data file pointer.
section_data_offset: u32 = 0,
/// Optiona header file pointer.
optional_header_offset: u32 = 0,

/// Absolute virtual address of the offset table when the executable is loaded in memory.
offset_table_virtual_address: u32 = 0,
/// Current size of the offset table on disk, must be a multiple of `file_alignment`
offset_table_size: u32 = 0,
/// Contains absolute virtual addresses
offset_table: std.ArrayListUnmanaged(u64) = .{},
/// Free list of offset table indices
offset_table_free_list: std.ArrayListUnmanaged(u32) = .{},

/// Virtual address of the entry point procedure relative to `image_base`
entry_addr: ?u32 = null,

/// Absolute virtual address of the text section when the executable is loaded in memory.
text_section_virtual_address: u32 = 0,
/// Current size of the `.text` section on disk, must be a multiple of `file_alignment`
text_section_size: u32 = 0,

offset_table_size_dirty: bool = false,
text_section_size_dirty: bool = false,
/// This flag is set when the virtual size of the whole image file when loaded in memory has changed
/// and needs to be updated in the optional header.
size_of_image_dirty: bool = false,

pub const TextBlock = struct {
    /// Offset of the code relative to the start of the text section
    text_offset: u32,
    /// Used size of the text block
    size: u32,
    /// This field is undefined for symbols with size = 0.
    offset_table_index: u32,
    /// Points to the previous and next neighbors, based on the `text_offset`.
    /// This can be used to find, for example, the capacity of this `TextBlock`.
    prev: ?*TextBlock,
    next: ?*TextBlock,

    pub const empty = TextBlock{
        .text_offset = 0,
        .size = 0,
        .offset_table_index = undefined,
        .prev = null,
        .next = null,
    };

    /// Returns how much room there is to grow in virtual address space.
    fn capacity(self: TextBlock) u64 {
        if (self.next) |next| {
            return next.text_offset - self.text_offset;
        }
        // This is the last block, the capacity is only limited by the address space.
        return std.math.maxInt(u32) - self.text_offset;
    }

    fn freeListEligible(self: TextBlock) bool {
        // No need to keep a free list node for the last block.
        const next = self.next orelse return false;
        const cap = next.text_offset - self.text_offset;
        const ideal_cap = self.size * allocation_padding;
        if (cap <= ideal_cap) return false;
        const surplus = cap - ideal_cap;
        return surplus >= minimum_text_block_size;
    }

    /// Absolute virtual address of the text block when the file is loaded in memory.
    fn getVAddr(self: TextBlock, coff: Coff) u32 {
        return coff.text_section_virtual_address + self.text_offset;
    }
};

pub const SrcFn = void;

pub fn openPath(allocator: *Allocator, dir: fs.Dir, sub_path: []const u8, options: link.Options) !*link.File {
    assert(options.object_format == .coff);

    const file = try dir.createFile(sub_path, .{ .truncate = false, .read = true, .mode = link.determineMode(options) });
    errdefer file.close();

    var coff_file = try allocator.create(Coff);
    errdefer allocator.destroy(coff_file);

    coff_file.* = openFile(allocator, file, options) catch |err| switch (err) {
        error.IncrFailed => try createFile(allocator, file, options),
        else => |e| return e,
    };

    return &coff_file.base;
}

/// Returns error.IncrFailed if incremental update could not be performed.
fn openFile(allocator: *Allocator, file: fs.File, options: link.Options) !Coff {
    switch (options.output_mode) {
        .Exe => {},
        .Obj => return error.IncrFailed,
        .Lib => return error.IncrFailed,
    }
    var self: Coff = .{
        .base = .{
            .file = file,
            .tag = .coff,
            .options = options,
            .allocator = allocator,
        },
        .ptr_width = switch (options.target.cpu.arch.ptrBitWidth()) {
            32 => .p32,
            64 => .p64,
            else => return error.UnsupportedELFArchitecture,
        },
    };
    errdefer self.deinit();

    // TODO implement reading the PE/COFF file
    return error.IncrFailed;
}

/// Truncates the existing file contents and overwrites the contents.
/// Returns an error if `file` is not already open with +read +write +seek abilities.
fn createFile(allocator: *Allocator, file: fs.File, options: link.Options) !Coff {
    // TODO Write object specific relocations, COFF symbol table, then enable object file output.
    switch (options.output_mode) {
        .Exe => {},
        .Obj => return error.TODOImplementWritingObjFiles,
        .Lib => return error.TODOImplementWritingLibFiles,
    }
    var self: Coff = .{
        .base = .{
            .tag = .coff,
            .options = options,
            .allocator = allocator,
            .file = file,
        },
        .ptr_width = switch (options.target.cpu.arch.ptrBitWidth()) {
            32 => .p32,
            64 => .p64,
            else => return error.UnsupportedCOFFArchitecture,
        },
    };
    errdefer self.deinit();

    var coff_file_header_offset: u32 = 0;
    if (options.output_mode == .Exe) {
        // Write the MS-DOS stub and the PE signature
        try self.base.file.?.pwriteAll(msdos_stub ++ "PE\x00\x00", 0);
        coff_file_header_offset = msdos_stub.len + 4;
    }

    // COFF file header
    const data_directory_count = 0;
    var hdr_data: [112 + data_directory_count * 8 + section_table_size]u8 = undefined;
    var index: usize = 0;

    const machine = self.base.options.target.cpu.arch.toCoffMachine();
    if (machine == .Unknown) {
        return error.UnsupportedCOFFArchitecture;
    }
    std.mem.writeIntLittle(u16, hdr_data[0..2], @enumToInt(machine));
    index += 2;

    // Number of sections (we only use .got, .text)
    std.mem.writeIntLittle(u16, hdr_data[index..][0..2], 2);
    index += 2;
    // TimeDateStamp (u32), PointerToSymbolTable (u32), NumberOfSymbols (u32)
    std.mem.set(u8, hdr_data[index..][0..12], 0);
    index += 12;

    const optional_header_size = switch (options.output_mode) {
        .Exe => data_directory_count * 8 + switch (self.ptr_width) {
            .p32 => @as(u16, 96),
            .p64 => 112,
        },
        else => 0,
    };

    const section_table_offset = coff_file_header_offset + 20 + optional_header_size;
    const default_offset_table_size = file_alignment;
    const default_size_of_code = 0;

    self.section_data_offset = std.mem.alignForwardGeneric(u32, self.section_table_offset + section_table_size, file_alignment);
    const section_data_relative_virtual_address = std.mem.alignForwardGeneric(u32, self.section_table_offset + section_table_size, section_alignment);
    self.offset_table_virtual_address = image_base + section_data_relative_virtual_address;
    self.offset_table_size = default_offset_table_size;
    self.section_table_offset = section_table_offset;
    self.text_section_virtual_address = image_base + section_data_relative_virtual_address + section_alignment;
    self.text_section_size = default_size_of_code;

    // Size of file when loaded in memory
    const size_of_image = std.mem.alignForwardGeneric(u32, self.text_section_virtual_address - image_base + default_size_of_code, section_alignment);

    std.mem.writeIntLittle(u16, hdr_data[index..][0..2], optional_header_size);
    index += 2;

    // Characteristics
    var characteristics: u16 = std.coff.IMAGE_FILE_DEBUG_STRIPPED | std.coff.IMAGE_FILE_RELOCS_STRIPPED; // TODO Remove debug info stripped flag when necessary
    if (options.output_mode == .Exe) {
        characteristics |= std.coff.IMAGE_FILE_EXECUTABLE_IMAGE;
    }
    switch (self.ptr_width) {
        .p32 => characteristics |= std.coff.IMAGE_FILE_32BIT_MACHINE,
        .p64 => characteristics |= std.coff.IMAGE_FILE_LARGE_ADDRESS_AWARE,
    }
    std.mem.writeIntLittle(u16, hdr_data[index..][0..2], characteristics);
    index += 2;

    assert(index == 20);
    try self.base.file.?.pwriteAll(hdr_data[0..index], coff_file_header_offset);

    if (options.output_mode == .Exe) {
        self.optional_header_offset = coff_file_header_offset + 20;
        // Optional header
        index = 0;
        std.mem.writeIntLittle(u16, hdr_data[0..2], switch (self.ptr_width) {
            .p32 => @as(u16, 0x10b),
            .p64 => 0x20b,
        });
        index += 2;

        // Linker version (u8 + u8)
        std.mem.set(u8, hdr_data[index..][0..2], 0);
        index += 2;

        // SizeOfCode (UNUSED, u32), SizeOfInitializedData (u32), SizeOfUninitializedData (u32), AddressOfEntryPoint (u32), BaseOfCode (UNUSED, u32)
        std.mem.set(u8, hdr_data[index..][0..20], 0);
        index += 20;

        if (self.ptr_width == .p32) {
            // Base of data relative to the image base (UNUSED)
            std.mem.set(u8, hdr_data[index..][0..4], 0);
            index += 4;

            // Image base address
            std.mem.writeIntLittle(u32, hdr_data[index..][0..4], image_base);
            index += 4;
        } else {
            // Image base address
            std.mem.writeIntLittle(u64, hdr_data[index..][0..8], image_base);
            index += 8;
        }

        // Section alignment
        std.mem.writeIntLittle(u32, hdr_data[index..][0..4], section_alignment);
        index += 4;
        // File alignment
        std.mem.writeIntLittle(u32, hdr_data[index..][0..4], file_alignment);
        index += 4;
        // Required OS version, 6.0 is vista
        std.mem.writeIntLittle(u16, hdr_data[index..][0..2], 6);
        index += 2;
        std.mem.writeIntLittle(u16, hdr_data[index..][0..2], 0);
        index += 2;
        // Image version
        std.mem.set(u8, hdr_data[index..][0..4], 0);
        index += 4;
        // Required subsystem version, same as OS version
        std.mem.writeIntLittle(u16, hdr_data[index..][0..2], 6);
        index += 2;
        std.mem.writeIntLittle(u16, hdr_data[index..][0..2], 0);
        index += 2;
        // Reserved zeroes (u32)
        std.mem.set(u8, hdr_data[index..][0..4], 0);
        index += 4;
        std.mem.writeIntLittle(u32, hdr_data[index..][0..4], size_of_image);
        index += 4;
        std.mem.writeIntLittle(u32, hdr_data[index..][0..4], self.section_data_offset);
        index += 4;
        // CheckSum (u32)
        std.mem.set(u8, hdr_data[index..][0..4], 0);
        index += 4;
        // Subsystem, TODO: Let users specify the subsystem, always CUI for now
        std.mem.writeIntLittle(u16, hdr_data[index..][0..2], 3);
        index += 2;
        // DLL characteristics
        std.mem.writeIntLittle(u16, hdr_data[index..][0..2], 0x0);
        index += 2;

        switch (self.ptr_width) {
            .p32 => {
                // Size of stack reserve + commit
                std.mem.writeIntLittle(u32, hdr_data[index..][0..4], 0x1_000_000);
                index += 4;
                std.mem.writeIntLittle(u32, hdr_data[index..][0..4], 0x1_000);
                index += 4;
                // Size of heap reserve + commit
                std.mem.writeIntLittle(u32, hdr_data[index..][0..4], 0x100_000);
                index += 4;
                std.mem.writeIntLittle(u32, hdr_data[index..][0..4], 0x1_000);
                index += 4;
            },
            .p64 => {
                // Size of stack reserve + commit
                std.mem.writeIntLittle(u64, hdr_data[index..][0..8], 0x1_000_000);
                index += 8;
                std.mem.writeIntLittle(u64, hdr_data[index..][0..8], 0x1_000);
                index += 8;
                // Size of heap reserve + commit
                std.mem.writeIntLittle(u64, hdr_data[index..][0..8], 0x100_000);
                index += 8;
                std.mem.writeIntLittle(u64, hdr_data[index..][0..8], 0x1_000);
                index += 8;
            },
        }

        // Reserved zeroes
        std.mem.set(u8, hdr_data[index..][0..4], 0);
        index += 4;

        // Number of data directories
        std.mem.writeIntLittle(u32, hdr_data[index..][0..4], data_directory_count);
        index += 4;
        // Initialize data directories to zero
        std.mem.set(u8, hdr_data[index..][0 .. data_directory_count * 8], 0);
        index += data_directory_count * 8;

        assert(index == optional_header_size);
    }

    // Write section table.
    // First, the .got section
    hdr_data[index..][0..8].* = ".got\x00\x00\x00\x00".*;
    index += 8;
    if (options.output_mode == .Exe) {
        // Virtual size (u32)
        std.mem.writeIntLittle(u32, hdr_data[index..][0..4], default_offset_table_size);
        index += 4;
        // Virtual address (u32)
        std.mem.writeIntLittle(u32, hdr_data[index..][0..4], self.offset_table_virtual_address - image_base);
        index += 4;
    } else {
        std.mem.set(u8, hdr_data[index..][0..8], 0);
        index += 8;
    }
    // Size of raw data (u32)
    std.mem.writeIntLittle(u32, hdr_data[index..][0..4], default_offset_table_size);
    index += 4;
    // File pointer to the start of the section
    std.mem.writeIntLittle(u32, hdr_data[index..][0..4], self.section_data_offset);
    index += 4;
    // Pointer to relocations (u32), PointerToLinenumbers (u32), NumberOfRelocations (u16), NumberOfLinenumbers (u16)
    std.mem.set(u8, hdr_data[index..][0..12], 0);
    index += 12;
    // Section flags
    std.mem.writeIntLittle(u32, hdr_data[index..][0..4], std.coff.IMAGE_SCN_CNT_INITIALIZED_DATA | std.coff.IMAGE_SCN_MEM_READ);
    index += 4;
    // Then, the .text section
    hdr_data[index..][0..8].* = ".text\x00\x00\x00".*;
    index += 8;
    if (options.output_mode == .Exe) {
        // Virtual size (u32)
        std.mem.writeIntLittle(u32, hdr_data[index..][0..4], default_size_of_code);
        index += 4;
        // Virtual address (u32)
        std.mem.writeIntLittle(u32, hdr_data[index..][0..4], self.text_section_virtual_address - image_base);
        index += 4;
    } else {
        std.mem.set(u8, hdr_data[index..][0..8], 0);
        index += 8;
    }
    // Size of raw data (u32)
    std.mem.writeIntLittle(u32, hdr_data[index..][0..4], default_size_of_code);
    index += 4;
    // File pointer to the start of the section
    std.mem.writeIntLittle(u32, hdr_data[index..][0..4], self.section_data_offset + default_offset_table_size);
    index += 4;
    // Pointer to relocations (u32), PointerToLinenumbers (u32), NumberOfRelocations (u16), NumberOfLinenumbers (u16)
    std.mem.set(u8, hdr_data[index..][0..12], 0);
    index += 12;
    // Section flags
    std.mem.writeIntLittle(
        u32,
        hdr_data[index..][0..4],
        std.coff.IMAGE_SCN_CNT_CODE | std.coff.IMAGE_SCN_MEM_EXECUTE | std.coff.IMAGE_SCN_MEM_READ | std.coff.IMAGE_SCN_MEM_WRITE,
    );
    index += 4;

    assert(index == optional_header_size + section_table_size);
    try self.base.file.?.pwriteAll(hdr_data[0..index], self.optional_header_offset);
    try self.base.file.?.setEndPos(self.section_data_offset + default_offset_table_size + default_size_of_code);

    return self;
}

pub fn allocateDeclIndexes(self: *Coff, decl: *Module.Decl) !void {
    try self.offset_table.ensureCapacity(self.base.allocator, self.offset_table.items.len + 1);

    if (self.offset_table_free_list.popOrNull()) |i| {
        decl.link.coff.offset_table_index = i;
    } else {
        decl.link.coff.offset_table_index = @intCast(u32, self.offset_table.items.len);
        _ = self.offset_table.addOneAssumeCapacity();

        const entry_size = self.base.options.target.cpu.arch.ptrBitWidth() / 8;
        if (self.offset_table.items.len > self.offset_table_size / entry_size) {
            self.offset_table_size_dirty = true;
        }
    }

    self.offset_table.items[decl.link.coff.offset_table_index] = 0;
}

fn allocateTextBlock(self: *Coff, text_block: *TextBlock, new_block_size: u64, alignment: u64) !u64 {
    const new_block_min_capacity = new_block_size * allocation_padding;

    // We use these to indicate our intention to update metadata, placing the new block,
    // and possibly removing a free list node.
    // It would be simpler to do it inside the for loop below, but that would cause a
    // problem if an error was returned later in the function. So this action
    // is actually carried out at the end of the function, when errors are no longer possible.
    var block_placement: ?*TextBlock = null;
    var free_list_removal: ?usize = null;

    const vaddr = blk: {
        var i: usize = 0;
        while (i < self.text_block_free_list.items.len) {
            const free_block = self.text_block_free_list.items[i];

            const next_block_text_offset = free_block.text_offset + free_block.capacity();
            const new_block_text_offset = std.mem.alignForwardGeneric(u64, free_block.getVAddr(self.*) + free_block.size, alignment) - self.text_section_virtual_address;
            if (new_block_text_offset < next_block_text_offset and next_block_text_offset - new_block_text_offset >= new_block_min_capacity) {
                block_placement = free_block;

                const remaining_capacity = next_block_text_offset - new_block_text_offset - new_block_min_capacity;
                if (remaining_capacity < minimum_text_block_size) {
                    free_list_removal = i;
                }

                break :blk new_block_text_offset + self.text_section_virtual_address;
            } else {
                if (!free_block.freeListEligible()) {
                    _ = self.text_block_free_list.swapRemove(i);
                } else {
                    i += 1;
                }
                continue;
            }
        } else if (self.last_text_block) |last| {
            const new_block_vaddr = std.mem.alignForwardGeneric(u64, last.getVAddr(self.*) + last.size, alignment);
            block_placement = last;
            break :blk new_block_vaddr;
        } else {
            break :blk self.text_section_virtual_address;
        }
    };

    const expand_text_section = block_placement == null or block_placement.?.next == null;
    if (expand_text_section) {
        const needed_size = @intCast(u32, std.mem.alignForwardGeneric(u64, vaddr + new_block_size - self.text_section_virtual_address, file_alignment));
        if (needed_size > self.text_section_size) {
            const current_text_section_virtual_size = std.mem.alignForwardGeneric(u32, self.text_section_size, section_alignment);
            const new_text_section_virtual_size = std.mem.alignForwardGeneric(u32, needed_size, section_alignment);
            if (current_text_section_virtual_size != new_text_section_virtual_size) {
                self.size_of_image_dirty = true;
                // Write new virtual size
                var buf: [4]u8 = undefined;
                std.mem.writeIntLittle(u32, &buf, new_text_section_virtual_size);
                try self.base.file.?.pwriteAll(&buf, self.section_table_offset + 40 + 8);
            }

            self.text_section_size = needed_size;
            self.text_section_size_dirty = true;
        }
        self.last_text_block = text_block;
    }
    text_block.text_offset = @intCast(u32, vaddr - self.text_section_virtual_address);
    text_block.size = @intCast(u32, new_block_size);

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

fn growTextBlock(self: *Coff, text_block: *TextBlock, new_block_size: u64, alignment: u64) !u64 {
    const block_vaddr = text_block.getVAddr(self.*);
    const align_ok = std.mem.alignBackwardGeneric(u64, block_vaddr, alignment) == block_vaddr;
    const need_realloc = !align_ok or new_block_size > text_block.capacity();
    if (!need_realloc) return @as(u64, block_vaddr);
    return self.allocateTextBlock(text_block, new_block_size, alignment);
}

fn shrinkTextBlock(self: *Coff, text_block: *TextBlock, new_block_size: u64) void {
    text_block.size = @intCast(u32, new_block_size);
    if (text_block.capacity() - text_block.size >= minimum_text_block_size) {
        self.text_block_free_list.append(self.base.allocator, text_block) catch {};
    }
}

fn freeTextBlock(self: *Coff, text_block: *TextBlock) void {
    var already_have_free_list_node = false;
    {
        var i: usize = 0;
        // TODO turn text_block_free_list into a hash map
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
        self.last_text_block = text_block.prev;
    }
    if (text_block.prev) |prev| {
        prev.next = text_block.next;

        if (!already_have_free_list_node and prev.freeListEligible()) {
            // The free list is heuristics, it doesn't have to be perfect, so we can
            // ignore the OOM here.
            self.text_block_free_list.append(self.base.allocator, prev) catch {};
        }
    }

    if (text_block.next) |next| {
        next.prev = text_block.prev;
    }
}

fn writeOffsetTableEntry(self: *Coff, index: usize) !void {
    const entry_size = self.base.options.target.cpu.arch.ptrBitWidth() / 8;
    const endian = self.base.options.target.cpu.arch.endian();

    const offset_table_start = self.section_data_offset;
    if (self.offset_table_size_dirty) {
        const current_raw_size = self.offset_table_size;
        const new_raw_size = self.offset_table_size * 2;
        log.debug("growing offset table from raw size {} to {}\n", .{ current_raw_size, new_raw_size });

        // Move the text section to a new place in the executable
        const current_text_section_start = self.section_data_offset + current_raw_size;
        const new_text_section_start = self.section_data_offset + new_raw_size;

        const amt = try self.base.file.?.copyRangeAll(current_text_section_start, self.base.file.?, new_text_section_start, self.text_section_size);
        if (amt != self.text_section_size) return error.InputOutput;

        // Write the new raw size in the .got header
        var buf: [8]u8 = undefined;
        std.mem.writeIntLittle(u32, buf[0..4], new_raw_size);
        try self.base.file.?.pwriteAll(buf[0..4], self.section_table_offset + 16);
        // Write the new .text section file offset in the .text section header
        std.mem.writeIntLittle(u32, buf[0..4], new_text_section_start);
        try self.base.file.?.pwriteAll(buf[0..4], self.section_table_offset + 40 + 20);

        const current_virtual_size = std.mem.alignForwardGeneric(u32, self.offset_table_size, section_alignment);
        const new_virtual_size = std.mem.alignForwardGeneric(u32, new_raw_size, section_alignment);
        // If we had to move in the virtual address space, we need to fix the VAs in the offset table, as well as the virtual address of the `.text` section
        // and the virutal size of the `.got` section

        if (new_virtual_size != current_virtual_size) {
            log.debug("growing offset table from virtual size {} to {}\n", .{ current_virtual_size, new_virtual_size });
            self.size_of_image_dirty = true;
            const va_offset = new_virtual_size - current_virtual_size;

            // Write .got virtual size
            std.mem.writeIntLittle(u32, buf[0..4], new_virtual_size);
            try self.base.file.?.pwriteAll(buf[0..4], self.section_table_offset + 8);

            // Write .text new virtual address
            self.text_section_virtual_address = self.text_section_virtual_address + va_offset;
            std.mem.writeIntLittle(u32, buf[0..4], self.text_section_virtual_address - image_base);
            try self.base.file.?.pwriteAll(buf[0..4], self.section_table_offset + 40 + 12);

            // Fix the VAs in the offset table
            for (self.offset_table.items) |*va, idx| {
                if (va.* != 0) {
                    va.* += va_offset;

                    switch (entry_size) {
                        4 => {
                            std.mem.writeInt(u32, buf[0..4], @intCast(u32, va.*), endian);
                            try self.base.file.?.pwriteAll(buf[0..4], offset_table_start + idx * entry_size);
                        },
                        8 => {
                            std.mem.writeInt(u64, &buf, va.*, endian);
                            try self.base.file.?.pwriteAll(&buf, offset_table_start + idx * entry_size);
                        },
                        else => unreachable,
                    }
                }
            }
        }
        self.offset_table_size = new_raw_size;
        self.offset_table_size_dirty = false;
    }
    // Write the new entry
    switch (entry_size) {
        4 => {
            var buf: [4]u8 = undefined;
            std.mem.writeInt(u32, &buf, @intCast(u32, self.offset_table.items[index]), endian);
            try self.base.file.?.pwriteAll(&buf, offset_table_start + index * entry_size);
        },
        8 => {
            var buf: [8]u8 = undefined;
            std.mem.writeInt(u64, &buf, self.offset_table.items[index], endian);
            try self.base.file.?.pwriteAll(&buf, offset_table_start + index * entry_size);
        },
        else => unreachable,
    }
}

pub fn updateDecl(self: *Coff, module: *Module, decl: *Module.Decl) !void {
    // TODO COFF/PE debug information
    // TODO Implement exports
    const tracy = trace(@src());
    defer tracy.end();

    var code_buffer = std.ArrayList(u8).init(self.base.allocator);
    defer code_buffer.deinit();

    const typed_value = decl.typed_value.most_recent.typed_value;
    const res = try codegen.generateSymbol(&self.base, decl.src(), typed_value, &code_buffer, .none);
    const code = switch (res) {
        .externally_managed => |x| x,
        .appended => code_buffer.items,
        .fail => |em| {
            decl.analysis = .codegen_failure;
            try module.failed_decls.put(module.gpa, decl, em);
            return;
        },
    };

    const required_alignment = typed_value.ty.abiAlignment(self.base.options.target);
    const curr_size = decl.link.coff.size;
    if (curr_size != 0) {
        const capacity = decl.link.coff.capacity();
        const need_realloc = code.len > capacity or
            !std.mem.isAlignedGeneric(u32, decl.link.coff.text_offset, required_alignment);
        if (need_realloc) {
            const curr_vaddr = self.getDeclVAddr(decl);
            const vaddr = try self.growTextBlock(&decl.link.coff, code.len, required_alignment);
            log.debug("growing {} from 0x{x} to 0x{x}\n", .{ decl.name, curr_vaddr, vaddr });
            if (vaddr != curr_vaddr) {
                log.debug("  (writing new offset table entry)\n", .{});
                self.offset_table.items[decl.link.coff.offset_table_index] = vaddr;
                try self.writeOffsetTableEntry(decl.link.coff.offset_table_index);
            }
        } else if (code.len < curr_size) {
            self.shrinkTextBlock(&decl.link.coff, code.len);
        }
    } else {
        const vaddr = try self.allocateTextBlock(&decl.link.coff, code.len, required_alignment);
        log.debug("allocated text block for {} at 0x{x} (size: {Bi})\n", .{ std.mem.spanZ(decl.name), vaddr, code.len });
        errdefer self.freeTextBlock(&decl.link.coff);
        self.offset_table.items[decl.link.coff.offset_table_index] = vaddr;
        try self.writeOffsetTableEntry(decl.link.coff.offset_table_index);
    }

    // Write the code into the file
    try self.base.file.?.pwriteAll(code, self.section_data_offset + self.offset_table_size + decl.link.coff.text_offset);

    // Since we updated the vaddr and the size, each corresponding export symbol also needs to be updated.
    const decl_exports = module.decl_exports.get(decl) orelse &[0]*Module.Export{};
    return self.updateDeclExports(module, decl, decl_exports);
}

pub fn freeDecl(self: *Coff, decl: *Module.Decl) void {
    // Appending to free lists is allowed to fail because the free lists are heuristics based anyway.
    self.freeTextBlock(&decl.link.coff);
    self.offset_table_free_list.append(self.base.allocator, decl.link.coff.offset_table_index) catch {};
}

pub fn updateDeclExports(self: *Coff, module: *Module, decl: *const Module.Decl, exports: []const *Module.Export) !void {
    for (exports) |exp| {
        if (exp.options.section) |section_name| {
            if (!std.mem.eql(u8, section_name, ".text")) {
                try module.failed_exports.ensureCapacity(module.gpa, module.failed_exports.items().len + 1);
                module.failed_exports.putAssumeCapacityNoClobber(
                    exp,
                    try Module.ErrorMsg.create(self.base.allocator, 0, "Unimplemented: ExportOptions.section", .{}),
                );
                continue;
            }
        }
        if (std.mem.eql(u8, exp.options.name, "_start")) {
            self.entry_addr = decl.link.coff.getVAddr(self.*) - image_base;
        } else {
            try module.failed_exports.ensureCapacity(module.gpa, module.failed_exports.items().len + 1);
            module.failed_exports.putAssumeCapacityNoClobber(
                exp,
                try Module.ErrorMsg.create(self.base.allocator, 0, "Unimplemented: Exports other than '_start'", .{}),
            );
            continue;
        }
    }
}

pub fn flush(self: *Coff, module: *Module) !void {
    if (self.text_section_size_dirty) {
        // Write the new raw size in the .text header
        var buf: [4]u8 = undefined;
        std.mem.writeIntLittle(u32, &buf, self.text_section_size);
        try self.base.file.?.pwriteAll(&buf, self.section_table_offset + 40 + 16);
        try self.base.file.?.setEndPos(self.section_data_offset + self.offset_table_size + self.text_section_size);
        self.text_section_size_dirty = false;
    }

    if (self.base.options.output_mode == .Exe and self.size_of_image_dirty) {
        const new_size_of_image = std.mem.alignForwardGeneric(u32, self.text_section_virtual_address - image_base + self.text_section_size, section_alignment);
        var buf: [4]u8 = undefined;
        std.mem.writeIntLittle(u32, &buf, new_size_of_image);
        try self.base.file.?.pwriteAll(&buf, self.optional_header_offset + 56);
        self.size_of_image_dirty = false;
    }

    if (self.entry_addr == null and self.base.options.output_mode == .Exe) {
        log.debug("flushing. no_entry_point_found = true\n", .{});
        self.error_flags.no_entry_point_found = true;
    } else {
        log.debug("flushing. no_entry_point_found = false\n", .{});
        self.error_flags.no_entry_point_found = false;

        if (self.base.options.output_mode == .Exe) {
            // Write AddressOfEntryPoint
            var buf: [4]u8 = undefined;
            std.mem.writeIntLittle(u32, &buf, self.entry_addr.?);
            try self.base.file.?.pwriteAll(&buf, self.optional_header_offset + 16);
        }
    }
}

pub fn getDeclVAddr(self: *Coff, decl: *const Module.Decl) u64 {
    return self.text_section_virtual_address + decl.link.coff.text_offset;
}

pub fn updateDeclLineNumber(self: *Coff, module: *Module, decl: *Module.Decl) !void {
    // TODO Implement this
}

pub fn deinit(self: *Coff) void {
    self.text_block_free_list.deinit(self.base.allocator);
    self.offset_table.deinit(self.base.allocator);
    self.offset_table_free_list.deinit(self.base.allocator);
}
