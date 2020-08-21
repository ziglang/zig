const MachO = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const fs = std.fs;
const log = std.log.scoped(.link);
const macho = std.macho;
const codegen = @import("../codegen.zig");
const math = std.math;
const mem = std.mem;
const trace = @import("../tracy.zig").trace;
const Type = @import("../type.zig").Type;

const Module = @import("../Module.zig");
const link = @import("../link.zig");
const File = link.File;

pub const base_tag: File.Tag = File.Tag.macho;

base: File,

/// List of all load command headers that are in the file.
/// We use it to track number and size of all commands needed by the header.
commands: std.ArrayListUnmanaged(macho.load_command) = std.ArrayListUnmanaged(macho.load_command){},
command_file_offset: ?u64 = null,

/// Stored in native-endian format, depending on target endianness needs to be bswapped on read/write.
/// Same order as in the file.
segments: std.ArrayListUnmanaged(macho.segment_command_64) = std.ArrayListUnmanaged(macho.segment_command_64){},
sections: std.ArrayListUnmanaged(macho.section_64) = std.ArrayListUnmanaged(macho.section_64){},
segment_table_offset: ?u64 = null,

/// Entry point load command
entry_point_cmd: ?macho.entry_point_command = null,
entry_addr: ?u64 = null,

/// Default VM start address set at 4GB
vm_start_address: u64 = 0x100000000,

seg_table_dirty: bool = false,

error_flags: File.ErrorFlags = File.ErrorFlags{},

/// `alloc_num / alloc_den` is the factor of padding when allocating.
const alloc_num = 4;
const alloc_den = 3;

/// Default path to dyld
const DEFAULT_DYLD_PATH: [*:0]const u8 = "/usr/lib/dyld";

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
    var self: MachO = .{
        .base = .{
            .file = file,
            .tag = .macho,
            .options = options,
            .allocator = allocator,
        },
    };
    errdefer self.deinit();

    switch (options.output_mode) {
        .Exe => {
            // The first segment command for executables is always a __PAGEZERO segment.
            const pagezero = .{
                .cmd = macho.LC_SEGMENT_64,
                .cmdsize = commandSize(@sizeOf(macho.segment_command_64)),
                .segname = makeString("__PAGEZERO"),
                .vmaddr = 0,
                .vmsize = self.vm_start_address,
                .fileoff = 0,
                .filesize = 0,
                .maxprot = 0,
                .initprot = 0,
                .nsects = 0,
                .flags = 0,
            };
            try self.commands.append(allocator, .{
                .cmd = pagezero.cmd,
                .cmdsize = pagezero.cmdsize,
            });
            try self.segments.append(allocator, pagezero);
        },
        .Obj => return error.TODOImplementWritingObjFiles,
        .Lib => return error.TODOImplementWritingLibFiles,
    }

    try self.populateMissingMetadata();

    return self;
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

    const ncmds = try math.cast(u32, self.commands.items.len);
    hdr.ncmds = ncmds;

    var sizeof_cmds: u32 = 0;
    for (self.commands.items) |cmd| {
        sizeof_cmds += cmd.cmdsize;
    }
    hdr.sizeofcmds = sizeof_cmds;

    // TODO should these be set to something else?
    hdr.flags = 0;
    hdr.reserved = 0;

    try self.base.file.?.pwriteAll(@ptrCast([*]const u8, &hdr)[0..@sizeOf(macho.mach_header_64)], 0);
}

pub fn flush(self: *MachO, module: *Module) !void {
    // Save segments first
    {
        const buf = try self.base.allocator.alloc(macho.segment_command_64, self.segments.items.len);
        defer self.base.allocator.free(buf);

        self.command_file_offset = @sizeOf(macho.mach_header_64);

        for (buf) |*seg, i| {
            seg.* = self.segments.items[i];
            self.command_file_offset.? += self.segments.items[i].cmdsize;
        }

        try self.base.file.?.pwriteAll(mem.sliceAsBytes(buf), @sizeOf(macho.mach_header_64));
    }

    switch (self.base.options.output_mode) {
        .Exe => {
            {
                // We need to add LC_LOAD_DYLINKER and LC_LOAD_DYLIB since we always
                // have to link against libSystem.dylib
                const cmdsize = commandSize(@intCast(u32, @sizeOf(macho.dylinker_command) + mem.lenZ(DEFAULT_DYLD_PATH)));
                const load_dylinker = [1]macho.dylinker_command{
                    .{
                        .cmd = macho.LC_LOAD_DYLINKER,
                        .cmdsize = cmdsize,
                        .name = @sizeOf(macho.dylinker_command),
                    },
                };
                try self.commands.append(self.base.allocator, .{
                    .cmd = macho.LC_LOAD_DYLINKER,
                    .cmdsize = cmdsize,
                });

                try self.base.file.?.pwriteAll(mem.sliceAsBytes(load_dylinker[0..1]), self.command_file_offset.?);

                const padded_path = try self.base.allocator.alloc(u8, cmdsize - @sizeOf(macho.dylinker_command));
                defer self.base.allocator.free(padded_path);
                mem.set(u8, padded_path[0..], 0);
                mem.copy(u8, padded_path[0..], mem.spanZ(DEFAULT_DYLD_PATH));

                try self.base.file.?.pwriteAll(padded_path, self.command_file_offset.? + @sizeOf(macho.dylinker_command));
                self.command_file_offset.? += cmdsize;
            }
        },
        .Obj => return error.TODOImplementWritingObjFiles,
        .Lib => return error.TODOImplementWritingLibFiles,
    }

    // if (self.entry_addr == null and self.base.options.output_mode == .Exe) {
    //     log.debug("flushing. no_entry_point_found = true\n", .{});
    //     self.error_flags.no_entry_point_found = true;
    // } else {
    log.debug("flushing. no_entry_point_found = false\n", .{});
    self.error_flags.no_entry_point_found = false;
    try self.writeMachOHeader();
    // }
}

pub fn deinit(self: *MachO) void {
    self.commands.deinit(self.base.allocator);
    self.segments.deinit(self.base.allocator);
    self.sections.deinit(self.base.allocator);
}

pub fn allocateDeclIndexes(self: *MachO, decl: *Module.Decl) !void {}

pub fn updateDecl(self: *MachO, module: *Module, decl: *Module.Decl) !void {
    // const tracy = trace(@src());
    // defer tracy.end();

    // var code_buffer = std.ArrayList(u8).init(self.base.allocator);
    // defer code_buffer.deinit();

    // var dbg_line_buffer = std.ArrayList(u8).init(self.base.allocator);
    // defer dbg_line_buffer.deinit();

    // var dbg_info_buffer = std.ArrayList(u8).init(self.base.allocator);
    // defer dbg_info_buffer.deinit();

    // var dbg_info_type_relocs: File.DbgInfoTypeRelocsTable = .{};
    // defer {
    //     for (dbg_info_type_relocs.items()) |*entry| {
    //         entry.value.relocs.deinit(self.base.allocator);
    //     }
    //     dbg_info_type_relocs.deinit(self.base.allocator);
    // }

    // const typed_value = decl.typed_value.most_recent.typed_value;
    // log.debug("typed_value = {}", .{typed_value});

    // const res = try codegen.generateSymbol(
    //     &self.base,
    //     decl.src(),
    //     typed_value,
    //     &code_buffer,
    //     &dbg_line_buffer,
    //     &dbg_info_buffer,
    //     &dbg_info_type_relocs,
    // );
    // log.debug("res = {}", .{res});

    // const code = switch (res) {
    //     .externally_managed => |x| x,
    //     .appended => code_buffer.items,
    //     .fail => |em| {
    //         decl.analysis = .codegen_failure;
    //         try module.failed_decls.put(module.gpa, decl, em);
    //         return;
    //     },
    // };
}

pub fn updateDeclLineNumber(self: *MachO, module: *Module, decl: *const Module.Decl) !void {}

pub fn updateDeclExports(
    self: *MachO,
    module: *Module,
    decl: *const Module.Decl,
    exports: []const *Module.Export,
) !void {}

pub fn freeDecl(self: *MachO, decl: *Module.Decl) void {}

pub fn getDeclVAddr(self: *MachO, decl: *const Module.Decl) u64 {
    @panic("TODO implement getDeclVAddr for MachO");
}

pub fn populateMissingMetadata(self: *MachO) !void {
    // if (self.seg_load_re_index == null) {
    //     self.seg_load_re_index = @intCast(u16, self.segment_cmds.items.len);
    //     const file_size = self.base.options.program_code_size_hint;
    //     const p_align = 0x1000;
    //     const off = self.findFreeSpace(file_size, p_align);
    //     log.debug("found LC_SEGMENT_64 free space 0x{x} to 0x{x}", .{ off, off + file_size });
    //     try self.segment_cmds.append(self.base.allocator, .{});
    //     self.entry_addr = null;
    //     self.seg_table_dirty = true;
    // }
    // if (self.seg_got_index == null) {
    //     self.seg_got_index = @intCast(u16, self.segment_cmds.items.len);
    //     const file_size = 8 * self.base.options.symbol_count_hint;
    //     // Apple recommends to page align for better performance.
    //     // TODO This is not necessarily true for MH_OBJECT which means we
    //     // could potentially shave off a couple of bytes when generating
    //     // only object files.
    //     const p_align = 0x1000;
    //     const off = self.findFreeSpace(file_size, p_align);
    //     log.debug("found LC_SEGMENT_64 free space 0x{x} to 0x{x}", .{ off, off + file_size });
    //     const default_vmaddr = 0x4000000;
    //     try self.segment_cmds.append(self.base.allocator, .{
    //         .cmd = macho.LC_SEGMENT_64,
    //         .cmdsize = @sizeOf(macho.segment_command_64),
    //         .segname = self.makeString("__TEXT"),
    //         .vmaddr = default_vmaddr,
    //         .vmsize = file_size,
    //         .fileoff = off,
    //         .filesize = file_size,
    //         .maxprot = 0x5,
    //         .initprot = 0x5,
    //         .nsects = 0,
    //         .flags = 0,
    //     });
    //     self.seg_table_dirty = true;
    // }
}

/// Returns end pos of collision, if any.
fn detectAllocCollision(self: *MachO, start: u64, size: u64) ?u64 {
    const header_size: u64 = @sizeOf(macho.mach_header_64);
    if (start < header_size)
        return header_size;

    const end = start + satMul(size, alloc_num) / alloc_den;

    // if (self.sec_table_offset) |off| {
    //     const section_size: u64 = @sizeOf(macho.section_64);
    //     const tight_size = self.sections.items.len * section_size;
    //     const increased_size = satMul(tight_size, alloc_num) / alloc_den;
    //     const test_end = off + increased_size;
    //     if (end > off and start < test_end) {
    //         return test_end;
    //     }
    // }

    // if (self.seg_table_offset) |off| {
    //     const segment_size: u64 = @sizeOf(macho.segment_command_64);
    //     const tight_size = self.segment_cmds.items.len * segment_size;
    //     const increased_size = satMul(tight_size, alloc_num) / alloc_den;
    //     const test_end = off + increased_size;
    //     if (end > off and start < test_end) {
    //         return test_end;
    //     }
    // }

    // for (self.sections.items) |section| {
    //     const increased_size = satMul(section.size, alloc_num) / alloc_den;
    //     const test_end = section.offset + increased_size;
    //     if (end > section.offset and start < test_end) {
    //         return test_end;
    //     }
    // }

    for (self.segments.items) |segment| {
        const increased_size = satMul(segment.filesize, alloc_num) / alloc_den;
        const test_end = segment_cmd.fileoff + increased_size;
        if (end > segment_cmd.fileoff and start < test_end) {
            return test_end;
        }
    }

    return null;
}

fn findFreeSpace(self: *MachO, object_size: u64, min_alignment: u16) u64 {
    var start: u64 = 0;
    while (self.detectAllocCollision(start, object_size)) |item_end| {
        start = mem.alignForwardGeneric(u64, item_end, min_alignment);
    }
    return start;
}

/// Saturating multiplication
fn satMul(a: anytype, b: anytype) @TypeOf(a, b) {
    const T = @TypeOf(a, b);
    return std.math.mul(T, a, b) catch std.math.maxInt(T);
}

fn makeString(comptime bytes: []const u8) [16]u8 {
    var buf: [16]u8 = undefined;
    if (bytes.len > buf.len) @compileError("MachO segment/section name too long");
    mem.copy(u8, buf[0..], bytes);
    return buf;
}

fn commandSize(min_size: u32) u32 {
    if (min_size % @sizeOf(u64) == 0) return min_size;

    const div = min_size / @sizeOf(u64);
    return (div + 1) * @sizeOf(u64);
}
