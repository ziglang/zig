const Coff = @This();

const std = @import("std");
const log = std.log.scoped(.link);
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const fs = std.fs;

const Module = @import("../Module.zig");
const codegen = @import("../codegen/wasm.zig");
const link = @import("../link.zig");

pub const base_tag: link.File.Tag = .coff;

const msdos_stub = @embedFile("msdos-stub.bin");

base: link.File,
ptr_width: enum { p32, p64 },
error_flags: link.File.ErrorFlags = .{},

coff_file_header_dirty: bool = false,
optional_header_dirty: bool = false,

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
        .Obj => return error.IncrFailed, // @TODO DO OBJ FILES
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
    switch (options.output_mode) {
        .Exe, .Obj => {},
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
        .coff_file_header_dirty = true,
        .optional_header_dirty = true,
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
    var hdr_data: [112 + data_directory_count * 8 + 2 * 40]u8 = undefined;
    var index: usize = 0;

    // @TODO Add an enum(u16) in std.coff, add .toCoffMachine to Arch
    const machine_type: u16 = switch (self.base.options.target.cpu.arch) {
        .x86_64 => 0x8664,
        .i386 => 0x014c,
        .riscv32 => 0x5032,
        .riscv64 => 0x5064,
        else => return error.UnsupportedCOFFArchitecture,
    };
    std.mem.writeIntLittle(u16, hdr_data[0..2], machine_type);
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
    std.mem.writeIntLittle(u16, hdr_data[index..][0..2], optional_header_size);
    index += 2;

    // Characteristics - IMAGE_FILE_DEBUG_STRIPPED
    var characteristics: u16 = 0x200; // TODO Remove debug info stripped flag when necessary
    if (options.output_mode == .Exe) {
        // IMAGE_FILE_EXECUTABLE_IMAGE
        characteristics |= 0x2;
    }
    switch (self.ptr_width) {
        // IMAGE_FILE_32BIT_MACHINE
        .p32 => characteristics |= 0x100,
        // IMAGE_FILE_LARGE_ADDRESS_AWARE
        .p64 => characteristics |= 0x20,
    }
    std.mem.writeIntLittle(u16, hdr_data[index..][0..2], characteristics);
    index += 2;

    assert(index == 20);
    try self.base.file.?.pwriteAll(hdr_data[0..index], coff_file_header_offset);

    if (options.output_mode == .Exe) {
        // Optional header
        index = 0;
        std.mem.writeIntLittle(u16, hdr_data[0..2], switch (self.ptr_width) {
            .p32 => @as(u16, 0x10b),
            .p64 => 0x20b,
        });
        index += 2;

        // Linker version (u8 + u8), SizeOfCode (u32), SizeOfInitializedData (u32), SizeOfUninitializedData (u32), AddressOfEntryPoint (u32)
        std.mem.set(u8, hdr_data[index..][0..18], 0);
        index += 18;

        // Base of code relative to the image base
        // @TODO Check where to put this
        std.mem.writeIntLittle(u32, hdr_data[index..][0..4], 0x1000);
        index += 4;

        if (self.ptr_width == .p32) {
            // Base of data relative to the image base
            std.mem.set(u8, hdr_data[index..][0..4], 0);
            index += 4;

            // Image base address
            std.mem.writeIntLittle(u32, hdr_data[index..][0..4], 0x400_000);
            index += 4;
        } else {
            // Image base address
            std.mem.writeIntLittle(u64, hdr_data[index..][0..8], 0x140_000_000);
            index += 8;
        }

        // Section alignment
        std.mem.writeIntLittle(u32, hdr_data[index..][0..4], 4096);
        index += 4;
        // File alignment
        std.mem.writeIntLittle(u32, hdr_data[index..][0..4], 512);
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
        // Reserved zeroes (u32), SizeOfImage (u32), SizeOfHeaders (u32), CheckSum (u32)
        std.mem.set(u8, hdr_data[index..][0..16], 0);
        index += 16;
        // Subsystem, TODO: Let users specify the subsystem, always CUI for now
        std.mem.writeIntLittle(u16, hdr_data[index..][0..2], 3);
        index += 2;
        // DLL characteristics, TODO: For now we are just using IMAGE_DLLCHARACTERISTICS_DYNAMIC_BASE
        std.mem.writeIntLittle(u16, hdr_data[index..][0..2], 0x40);
        index += 2;

        switch (self.ptr_width) {
            .p32 => {
                // @TODO See llvm output for 32 bit executables
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
        // @TODO Write meaningful stuff here
        // Initialize data directories to zero
        std.mem.set(u8, hdr_data[index..][0..data_directory_count * 8], 0);
        index += data_directory_count * 8;

        assert(index == optional_header_size);
    }

    // @TODO Merge this write with the one above
    const section_table_offset = coff_file_header_offset + 20 + optional_header_size;

    // Write section table.
    // First, the .got section
    hdr_data[index..][0..8].* = ".got\x00\x00\x00\x00".*;
    index += 8;
    // Virtual size (u32) (@TODO Set to initial value in image files, zero otherwise), Virtual address (u32) (@TODO Set to value in image files, zero otherwise), Size of raw data (u32)
    std.mem.set(u8, hdr_data[index..][0..12], 0);
    index += 12;
    // File pointer to the start of the section
    std.mem.writeIntLittle(u32, hdr_data[index..][0..4], section_table_offset + 2 * 40);
    index += 4;
    // Pointer to relocations (u32) (@TODO Initialize this for object files), PointerToLinenumbers (u32), NumberOfRelocations (u16), (@TODO Initialize this for object files), NumberOfLinenumbers (u16)
    std.mem.set(u8, hdr_data[index..][0..12], 0);
    index += 12;
    // Characteristics `IMAGE_SCN_CNT_INITIALIZED_DATA | IMAGE_SCN_MEM_READ = 0x40000040`
    std.mem.writeIntLittle(u32, hdr_data[index..][0..4], 0x40000040);
    index += 4;
    // Then, the .text section
    hdr_data[index..][0..8].* = ".text\x00\x00\x00".*;
    index += 8;
    // Virtual size (u32) (@TODO Set to initial value in image files, zero otherwise), Virtual address (u32) (@TODO Set to value in image files, zero otherwise), Size of raw data (u32)
    std.mem.set(u8, hdr_data[index..][0..12], 0);
    index += 12;
    // File pointer to the start of the section (@TODO Add the initial size of .got)
    std.mem.writeIntLittle(u32, hdr_data[index..][0..4], section_table_offset + 2 * 40);
    index += 4;
    // Pointer to relocations (u32) (@TODO Initialize this for object files), PointerToLinenumbers (u32), NumberOfRelocations (u16), (@TODO Initialize this for object files), NumberOfLinenumbers (u16)
    std.mem.set(u8, hdr_data[index..][0..12], 0);
    index += 12;
    // Characteristics `IMAGE_SCN_CNT_CODE | IMAGE_SCN_MEM_EXECUTE | IMAGE_SCN_MEM_READ | IMAGE_SCN_MEM_WRITE = 0xE0000020`
    std.mem.writeIntLittle(u32, hdr_data[index..][0..4], 0xE0000020);
    index += 4;

    assert(index == optional_header_size + 2 * 40);
    try self.base.file.?.pwriteAll(hdr_data[0..index], coff_file_header_offset + 20);

    return self;
}

pub fn flush(self: *Coff, module: *Module) !void {
    // @TODO Implement this
}

pub fn freeDecl(self: *Coff, decl: *Module.Decl) void {
    // @TODO Implement this
}

pub fn updateDecl(self: *Coff, module: *Module, decl: *Module.Decl) !void {
    // @TODO Implement this
}

pub fn updateDeclLineNumber(self: *Coff, module: *Module, decl: *Module.Decl) !void {
    // @TODO Implement this
}

pub fn allocateDeclIndexes(self: *Coff, decl: *Module.Decl) !void {
    // @TODO Implement this
}

pub fn updateDeclExports(self: *Coff, module: *Module, decl: *const Module.Decl, exports: []const *Module.Export) !void {
    // @TODO Implement this
}

pub fn getDeclVAddr(self: *Coff, decl: *const Module.Decl) u64 {
    // @TODO Implement this
    return 0;
}

pub fn deinit(self: *Coff) void {
    // @TODO
}
