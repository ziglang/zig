const Coff = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const fs = std.fs;

const Module = @import("../Module.zig");
const codegen = @import("../codegen/wasm.zig");
const link = @import("../link.zig");


pub const base_tag: link.File.Tag = .coff;

const msdos_stub = @embedFile("msdos-stub.bin");
const coff_file_header_offset = msdos_stub.len + 4;
const optional_header_offset = coff_file_header_offset + 20;

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
        .Exe => {},
        .Obj => return error.TODOImplementWritingObjFiles, // @TODO DO OBJ FILES
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

    var output = self.base.file.?.writer();

    // MS-DOS stub + PE magic
    try output.writeAll(msdos_stub ++ "PE\x00\x00");
    const machine_type: u16 = switch (self.base.options.target.cpu.arch) {
        .x86_64  => 0x8664,
        .i386    => 0x014c,
        .riscv32 => 0x5032,
        .riscv64 => 0x5064,
        else => return error.UnsupportedCOFFArchitecture,
    };

    // Start of COFF file header
    try output.writeIntLittle(u16, machine_type);
    try output.writeIntLittle(u16, switch (self.ptr_width) {
        .p32 => @as(u16, 98),
        .p64 => 114,
    });
    try output.writeAll("\x00" ** 14);
    // Characteristics - IMAGE_FILE_RELOCS_STRIPPED | IMAGE_FILE_EXECUTABLE_IMAGE | IMAGE_FILE_DEBUG_STRIPPED
    var characteristics: u16 = 0x0001 | 0x000 | 0x02002; // @TODO Remove debug info stripped flag when necessary
    switch (self.ptr_width) {
        // IMAGE_FILE_32BIT_MACHINE
        .p32 => characteristics |= 0x0100,
        // IMAGE_FILE_LARGE_ADDRESS_AWARE
        .p64 => characteristics |= 0x0020,
    }
    try output.writeIntLittle(u16, characteristics);
    try output.writeIntLittle(u16, switch (self.ptr_width) {
        .p32 => @as(u16, 0x10b),
        .p64 => 0x20b,
    });

    // Start of optional header
    // TODO Linker version, use 0.0 for now.
    try output.writeAll("\x00" ** 2);
    // Zero out every field until "BaseOfCode"
    // @TODO Actually write entry point address, base of code address
    try output.writeAll("\x00" ** 20);
    switch (self.ptr_width) {
        .p32 => {
            // Zero out base of data
            try output.writeAll("\x00" ** 4);
            // Write image base
            try output.writeIntLittle(u32, 0x40000000);
        },
        .p64 => {
            // Write image base
            try output.writeIntLittle(u64, 0x40000000);
        },
    }

    // Section alignment - default to 256
    try output.writeIntLittle(u32, 256);
    // File alignment - default to 512
    try output.writeIntLittle(u32, 512);
    // TODO - Minimum required windows version - use 6.0 (aka vista for now)
    try output.writeIntLittle(u16, 0x6);
    try output.writeIntLittle(u16, 0x0);
    // TODO - Image version - use 0.0 for now
    try output.writeIntLittle(u32, 0x0);
    // Subsystem version
    try output.writeIntLittle(u16, 0x6);
    try output.writeIntLittle(u16, 0x0);
    // Reserved zeroes
    try output.writeIntLittle(u32, 0x0);
    // Size of image - initialize to zero
    try output.writeIntLittle(u32, 0x0);
    // @TODO Size of headers - calculate this.
    try output.writeIntLittle(u32, 0x0);
    // Checksum
    try output.writeIntLittle(u32, 0x0);
    // Subsystem
    try output.writeIntLittle(u16, 0x3);
    // @TODO Dll characteristics, just using a value from a LLVM produced executable for now.
    try output.writeIntLittle(u16, 0x8160);
    switch (self.ptr_width) {
        .p32 => {
            // Stack reserve
            try output.writeIntLittle(u32, 0x1000000);
            // Stack commit
            try output.writeIntLittle(u32, 0x1000);
            // Heap reserve
            try output.writeIntLittle(u32, 0x100000);
            // Heap commit
            try output.writeIntLittle(u32, 0x100);
        },
        .p64 => {
            // Stack reserve
            try output.writeIntLittle(u64, 0x1000000);
            // Stack commit
            try output.writeIntLittle(u64, 0x1000);
            // Heap reserve
            try output.writeIntLittle(u64, 0x100000);
            // Heap commit
            try output.writeIntLittle(u64, 0x100);
        },
    }
    // Reserved loader flags
    try output.writeIntLittle(u32, 0x0);
    // Number of RVA + sizes
    try output.writeIntLittle(u32, 0x0);

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
