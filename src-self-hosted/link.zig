const std = @import("std");
const Allocator = std.mem.Allocator;
const Module = @import("Module.zig");
const fs = std.fs;
const trace = @import("tracy.zig").trace;
const Package = @import("Package.zig");
const Type = @import("type.zig").Type;
const build_options = @import("build_options");

pub const producer_string = if (std.builtin.is_test) "zig test" else "zig " ++ build_options.version;

pub const Options = struct {
    target: std.Target,
    output_mode: std.builtin.OutputMode,
    link_mode: std.builtin.LinkMode,
    object_format: std.builtin.ObjectFormat,
    optimize_mode: std.builtin.Mode,
    root_name: []const u8,
    root_pkg: *const Package,
    /// Used for calculating how much space to reserve for symbols in case the binary file
    /// does not already have a symbol table.
    symbol_count_hint: u64 = 32,
    /// Used for calculating how much space to reserve for executable program code in case
    /// the binary file deos not already have such a section.
    program_code_size_hint: u64 = 256 * 1024,
    entry_addr: ?u64 = null,
};

pub const File = struct {
    tag: Tag,
    options: Options,
    file: ?fs.File,
    allocator: *Allocator,

    pub const LinkBlock = union {
        elf: Elf.TextBlock,
        coff: Coff.TextBlock,
        macho: MachO.TextBlock,
        c: void,
        wasm: void,
    };

    pub const LinkFn = union {
        elf: Elf.SrcFn,
        coff: Coff.SrcFn,
        macho: MachO.SrcFn,
        c: void,
        wasm: ?Wasm.FnData,
    };

    /// For DWARF .debug_info.
    pub const DbgInfoTypeRelocsTable = std.HashMapUnmanaged(Type, DbgInfoTypeReloc, Type.hash, Type.eql, std.hash_map.DefaultMaxLoadPercentage);

    /// For DWARF .debug_info.
    pub const DbgInfoTypeReloc = struct {
        /// Offset from `TextBlock.dbg_info_off` (the buffer that is local to a Decl).
        /// This is where the .debug_info tag for the type is.
        off: u32,
        /// Offset from `TextBlock.dbg_info_off` (the buffer that is local to a Decl).
        /// List of DW.AT_type / DW.FORM_ref4 that points to the type.
        relocs: std.ArrayListUnmanaged(u32),
    };

    /// Attempts incremental linking, if the file already exists. If
    /// incremental linking fails, falls back to truncating the file and
    /// rewriting it. A malicious file is detected as incremental link failure
    /// and does not cause Illegal Behavior. This operation is not atomic.
    pub fn openPath(allocator: *Allocator, dir: fs.Dir, sub_path: []const u8, options: Options) !*File {
        switch (options.object_format) {
            .unknown => unreachable,
            .coff, .pe => return Coff.openPath(allocator, dir, sub_path, options),
            .elf => return Elf.openPath(allocator, dir, sub_path, options),
            .macho => return MachO.openPath(allocator, dir, sub_path, options),
            .wasm => return Wasm.openPath(allocator, dir, sub_path, options),
            .c => return C.openPath(allocator, dir, sub_path, options),
            .hex => return error.TODOImplementHex,
            .raw => return error.TODOImplementRaw,
        }
    }

    pub fn cast(base: *File, comptime T: type) ?*T {
        if (base.tag != T.base_tag)
            return null;

        return @fieldParentPtr(T, "base", base);
    }

    pub fn makeWritable(base: *File, dir: fs.Dir, sub_path: []const u8) !void {
        switch (base.tag) {
            .coff, .elf, .macho => {
                if (base.file != null) return;
                base.file = try dir.createFile(sub_path, .{
                    .truncate = false,
                    .read = true,
                    .mode = determineMode(base.options),
                });
            },
            .c, .wasm => {},
        }
    }

    pub fn makeExecutable(base: *File) !void {
        switch (base.tag) {
            .c => unreachable,
            .wasm => {},
            else => if (base.file) |f| {
                f.close();
                base.file = null;
            },
        }
    }

    /// May be called before or after updateDeclExports but must be called
    /// after allocateDeclIndexes for any given Decl.
    pub fn updateDecl(base: *File, module: *Module, decl: *Module.Decl) !void {
        switch (base.tag) {
            .coff => return @fieldParentPtr(Coff, "base", base).updateDecl(module, decl),
            .elf => return @fieldParentPtr(Elf, "base", base).updateDecl(module, decl),
            .macho => return @fieldParentPtr(MachO, "base", base).updateDecl(module, decl),
            .c => return @fieldParentPtr(C, "base", base).updateDecl(module, decl),
            .wasm => return @fieldParentPtr(Wasm, "base", base).updateDecl(module, decl),
        }
    }

    pub fn updateDeclLineNumber(base: *File, module: *Module, decl: *Module.Decl) !void {
        switch (base.tag) {
            .coff => return @fieldParentPtr(Coff, "base", base).updateDeclLineNumber(module, decl),
            .elf => return @fieldParentPtr(Elf, "base", base).updateDeclLineNumber(module, decl),
            .macho => return @fieldParentPtr(MachO, "base", base).updateDeclLineNumber(module, decl),
            .c, .wasm => {},
        }
    }

    /// Must be called before any call to updateDecl or updateDeclExports for
    /// any given Decl.
    pub fn allocateDeclIndexes(base: *File, decl: *Module.Decl) !void {
        switch (base.tag) {
            .coff => return @fieldParentPtr(Coff, "base", base).allocateDeclIndexes(decl),
            .elf => return @fieldParentPtr(Elf, "base", base).allocateDeclIndexes(decl),
            .macho => return @fieldParentPtr(MachO, "base", base).allocateDeclIndexes(decl),
            .c, .wasm => {},
        }
    }

    pub fn deinit(base: *File) void {
        if (base.file) |f| f.close();
        switch (base.tag) {
            .coff => @fieldParentPtr(Coff, "base", base).deinit(),
            .elf => @fieldParentPtr(Elf, "base", base).deinit(),
            .macho => @fieldParentPtr(MachO, "base", base).deinit(),
            .c => @fieldParentPtr(C, "base", base).deinit(),
            .wasm => @fieldParentPtr(Wasm, "base", base).deinit(),
        }
    }

    pub fn destroy(base: *File) void {
        switch (base.tag) {
            .coff => {
                const parent = @fieldParentPtr(Coff, "base", base);
                parent.deinit();
                base.allocator.destroy(parent);
            },
            .elf => {
                const parent = @fieldParentPtr(Elf, "base", base);
                parent.deinit();
                base.allocator.destroy(parent);
            },
            .macho => {
                const parent = @fieldParentPtr(MachO, "base", base);
                parent.deinit();
                base.allocator.destroy(parent);
            },
            .c => {
                const parent = @fieldParentPtr(C, "base", base);
                parent.deinit();
                base.allocator.destroy(parent);
            },
            .wasm => {
                const parent = @fieldParentPtr(Wasm, "base", base);
                parent.deinit();
                base.allocator.destroy(parent);
            },
        }
    }

    pub fn flush(base: *File, module: *Module) !void {
        const tracy = trace(@src());
        defer tracy.end();

        try switch (base.tag) {
            .coff => @fieldParentPtr(Coff, "base", base).flush(module),
            .elf => @fieldParentPtr(Elf, "base", base).flush(module),
            .macho => @fieldParentPtr(MachO, "base", base).flush(module),
            .c => @fieldParentPtr(C, "base", base).flush(module),
            .wasm => @fieldParentPtr(Wasm, "base", base).flush(module),
        };
    }

    pub fn freeDecl(base: *File, decl: *Module.Decl) void {
        switch (base.tag) {
            .coff => @fieldParentPtr(Coff, "base", base).freeDecl(decl),
            .elf => @fieldParentPtr(Elf, "base", base).freeDecl(decl),
            .macho => @fieldParentPtr(MachO, "base", base).freeDecl(decl),
            .c => unreachable,
            .wasm => @fieldParentPtr(Wasm, "base", base).freeDecl(decl),
        }
    }

    pub fn errorFlags(base: *File) ErrorFlags {
        return switch (base.tag) {
            .coff => @fieldParentPtr(Coff, "base", base).error_flags,
            .elf => @fieldParentPtr(Elf, "base", base).error_flags,
            .macho => @fieldParentPtr(MachO, "base", base).error_flags,
            .c => return .{ .no_entry_point_found = false },
            .wasm => return ErrorFlags{},
        };
    }

    /// May be called before or after updateDecl, but must be called after
    /// allocateDeclIndexes for any given Decl.
    pub fn updateDeclExports(
        base: *File,
        module: *Module,
        decl: *const Module.Decl,
        exports: []const *Module.Export,
    ) !void {
        switch (base.tag) {
            .coff => return @fieldParentPtr(Coff, "base", base).updateDeclExports(module, decl, exports),
            .elf => return @fieldParentPtr(Elf, "base", base).updateDeclExports(module, decl, exports),
            .macho => return @fieldParentPtr(MachO, "base", base).updateDeclExports(module, decl, exports),
            .c => return {},
            .wasm => return @fieldParentPtr(Wasm, "base", base).updateDeclExports(module, decl, exports),
        }
    }

    pub fn getDeclVAddr(base: *File, decl: *const Module.Decl) u64 {
        switch (base.tag) {
            .coff => return @fieldParentPtr(Coff, "base", base).getDeclVAddr(decl),
            .elf => return @fieldParentPtr(Elf, "base", base).getDeclVAddr(decl),
            .macho => return @fieldParentPtr(MachO, "base", base).getDeclVAddr(decl),
            .c => unreachable,
            .wasm => unreachable,
        }
    }

    pub const Tag = enum {
        coff,
        elf,
        macho,
        c,
        wasm,
    };

    pub const ErrorFlags = struct {
        no_entry_point_found: bool = false,
    };

    pub const C = @import("link/C.zig");
    pub const Coff = @import("link/Coff.zig");
    pub const Elf = @import("link/Elf.zig");
    pub const MachO = @import("link/MachO.zig");
    pub const Wasm = @import("link/Wasm.zig");
};

pub fn determineMode(options: Options) fs.File.Mode {
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
