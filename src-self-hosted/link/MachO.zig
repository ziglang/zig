const MachO = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const fs = std.fs;
const log = std.log.scoped(.link);
const macho = std.macho;
const math = std.math;
const mem = std.mem;
const trace = @import("../tracy.zig").trace;
const CodeGen = @import("../codegen.zig").CodeGen;
const Type = @import("../type.zig").Type;

const Module = @import("../Module.zig");
const link = @import("../link.zig");
const File = link.File;

pub const base_tag: Tag = File.Tag.macho;

base: File,

/// Stored in native-endian format, depending on target endianness needs to be bswapped on read/write.
/// Same order as in the file.
segment_cmds: std.ArrayListUnmanaged(macho.segment_command_64) = std.ArrayListUnmanaged(macho.segment_command_64){},

/// Stored in native-endian format, depending on target endianness needs to be bswapped on read/write.
/// Same order as in the file.
sections: std.ArrayListUnmanaged(macho.section_64) = std.ArrayListUnmanaged(macho.section_64){},

entry_addr: ?u64 = null,

error_flags: File.ErrorFlags = File.ErrorFlags{},

pub const DbgInfoTypeRelocsTable = std.HashMapUnmanaged(Type, DbgInfoTypeReloc, Type.hash, Type.eql, true);

const DbgInfoTypeReloc = struct {
    /// Offset from `TextBlock.dbg_info_off` (the buffer that is local to a Decl).
    /// This is where the .debug_info tag for the type is.
    off: u32,
    /// Offset from `TextBlock.dbg_info_off` (the buffer that is local to a Decl).
    /// List of DW.AT_type / DW.FORM_ref4 that points to the type.
    relocs: std.ArrayListUnmanaged(u32),
};

pub const TextBlock = struct {
    pub const empty = TextBlock{};
};

pub const SrcFn = struct {
    pub const empty = SrcFn{};
};

pub fn openPath(allocator: *Allocator, dir: fs.Dir, sub_path: []const u8, options: link.Options) !*File {
    assert(options.object_format == .macho);

    const file = try dir.createFile(sub_path, .{ .truncate = false, .read = true, .mode = link.determineMode(options) });
    errdefer file.close();

    var macho_file = try allocator.create(MachO);
    errdefer allocator.destroy(macho_file);

    macho_file.* = openFile(allocator, file, options) catch |err| switch (err) {
        error.IncrFailed => try createFile(allocator, file, options),
        else => |e| return e,
    };

    return &macho_file.base;
}

/// Returns error.IncrFailed if incremental update could not be performed.
fn openFile(allocator: *Allocator, file: fs.File, options: link.Options) !MachO {
    switch (options.output_mode) {
        .Exe => {},
        .Obj => {},
        .Lib => return error.IncrFailed,
    }
    var self: MachO = .{
        .base = .{
            .file = file,
            .tag = .macho,
            .options = options,
            .allocator = allocator,
        },
    };
    errdefer self.deinit();

    // TODO implement reading the macho file
    return error.IncrFailed;
    //try self.populateMissingMetadata();
    //return self;
}

/// Truncates the existing file contents and overwrites the contents.
/// Returns an error if `file` is not already open with +read +write +seek abilities.
fn createFile(allocator: *Allocator, file: fs.File, options: link.Options) !MachO {
    switch (options.output_mode) {
        .Exe => {},
        .Obj => {},
        .Lib => return error.TODOImplementWritingLibFiles,
    }

    var self: MachO = .{
        .base = .{
            .file = file,
            .tag = .macho,
            .options = options,
            .allocator = allocator,
        },
    };
    errdefer self.deinit();

    if (options.output_mode == .Exe) {
        // The first segment command for executables is always a __PAGEZERO segment.
        try self.segment_cmds.append(allocator, .{
            .cmd = macho.LC_SEGMENT_64,
            .cmdsize = @sizeOf(macho.segment_command_64),
            .segname = self.makeString("__PAGEZERO"),
            .vmaddr = 0,
            .vmsize = 0,
            .fileoff = 0,
            .filesize = 0,
            .maxprot = 0,
            .initprot = 0,
            .nsects = 0,
            .flags = 0,
        });
    }

    return self;
}

fn makeString(self: *MachO, comptime bytes: []const u8) [16]u8 {
    var buf: [16]u8 = undefined;
    if (bytes.len > buf.len) @compileError("MachO segment/section name too long");
    mem.copy(u8, buf[0..], bytes);
    return buf;
}

fn writeMachOHeader(self: *MachO) !void {
    var hdr: macho.mach_header_64 = undefined;
    hdr.magic = macho.MH_MAGIC_64;

    const CpuInfo = struct {
        cpu_type: macho.cpu_type_t,
        cpu_subtype: macho.cpu_subtype_t,
    };

    const cpu_info: CpuInfo = switch (self.base.options.target.cpu.arch) {
        .aarch64 => .{
            .cpu_type = macho.CPU_TYPE_ARM64,
            .cpu_subtype = macho.CPU_SUBTYPE_ARM_ALL,
        },
        .x86_64 => .{
            .cpu_type = macho.CPU_TYPE_X86_64,
            .cpu_subtype = macho.CPU_SUBTYPE_X86_64_ALL,
        },
        else => return error.UnsupportedMachOArchitecture,
    };
    hdr.cputype = cpu_info.cpu_type;
    hdr.cpusubtype = cpu_info.cpu_subtype;

    const filetype: u32 = switch (self.base.options.output_mode) {
        .Exe => macho.MH_EXECUTE,
        .Obj => macho.MH_OBJECT,
        .Lib => switch (self.base.options.link_mode) {
            .Static => return error.TODOStaticLibMachOType,
            .Dynamic => macho.MH_DYLIB,
        },
    };
    hdr.filetype = filetype;

    // TODO consider other commands
    const ncmds = try math.cast(u32, self.segment_cmds.items.len);
    hdr.ncmds = ncmds;
    hdr.sizeofcmds = ncmds * @sizeOf(macho.segment_command_64);

    // TODO should these be set to something else?
    hdr.flags = 0;
    hdr.reserved = 0;

    try self.base.file.?.pwriteAll(@ptrCast([*]const u8, &hdr)[0..@sizeOf(macho.mach_header_64)], 0);
}

pub fn flush(self: *MachO, module: *Module) !void {
    // TODO implement flush
    {
        const buf = try self.base.allocator.alloc(macho.segment_command_64, self.segment_cmds.items.len);
        defer self.base.allocator.free(buf);

        for (buf) |*seg, i| {
            seg.* = self.segment_cmds.items[i];
        }

        try self.base.file.?.pwriteAll(mem.sliceAsBytes(buf), @sizeOf(macho.mach_header_64));
    }

    if (self.entry_addr == null and self.base.options.output_mode == .Exe) {
        log.debug("flushing. no_entry_point_found = true\n", .{});
        self.error_flags.no_entry_point_found = true;
    } else {
        log.debug("flushing. no_entry_point_found = false\n", .{});
        self.error_flags.no_entry_point_found = false;
        try self.writeMachOHeader();
    }
}

pub fn deinit(self: *MachO) void {
    self.segment_cmds.deinit(self.base.allocator);
    self.sections.deinit(self.base.allocator);
}

pub fn allocateDeclIndexes(self: *MachO, decl: *Module.Decl) !void {}

pub fn updateDecl(self: *MachO, module: *Module, decl: *Module.Decl) !void {
    const tracy = trace(@src());
    defer tracy.end();

    var code_buffer = std.ArrayList(u8).init(self.base.allocator);
    defer code_buffer.deinit();

    var dbg_line_buffer = std.ArrayList(u8).init(self.base.allocator);
    defer dbg_line_buffer.deinit();

    var dbg_info_buffer = std.ArrayList(u8).init(self.base.allocator);
    defer dbg_info_buffer.deinit();

    var dbg_info_type_relocs: DbgInfoTypeRelocsTable = .{};
    defer {
        for (dbg_info_type_relocs.items()) |*entry| {
            entry.value.relocs.deinit(self.base.allocator);
        }
        dbg_info_type_relocs.deinit(self.base.allocator);
    }

    const typed_value = decl.typed_value.most_recent.typed_value;

    const res = try CodeGen(.macho).generateSymbol(
        &self.base,
        decl.src(),
        typed_value,
        &code_buffer,
        &dbg_line_buffer,
        &dbg_info_buffer,
        &dbg_info_type_relocs,
    );
}

pub fn updateDeclLineNumber(self: *MachO, module: *Module, decl: *const Module.Decl) !void {}

pub fn updateDeclExports(
    self: *MachO,
    module: *Module,
    decl: *const Module.Decl,
    exports: []const *Module.Export,
) !void {}

pub fn freeDecl(self: *MachO, decl: *Module.Decl) void {}
