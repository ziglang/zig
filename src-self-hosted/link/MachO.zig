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

const is_darwin = std.Target.current.os.tag.isDarwin();

pub const base_tag: File.Tag = File.Tag.macho;

base: File,

/// List of all load command headers that are in the file.
/// We use it to track number and size of all commands needed by the header.
commands: std.ArrayListUnmanaged(macho.load_command) = std.ArrayListUnmanaged(macho.load_command){},
command_file_offset: ?u64 = null,

/// Stored in native-endian format, depending on target endianness needs to be bswapped on read/write.
/// Same order as in the file.
segments: std.ArrayListUnmanaged(macho.segment_command_64) = std.ArrayListUnmanaged(macho.segment_command_64){},
/// Section (headers) *always* follow segment (load commands) directly!
sections: std.ArrayListUnmanaged(macho.section_64) = std.ArrayListUnmanaged(macho.section_64){},

/// Offset (index) into __TEXT segment load command.
text_segment_offset: ?u64 = null,
/// Offset (index) into __LINKEDIT segment load command.
linkedit_segment_offset: ?u664 = null,

/// Entry point load command
entry_point_cmd: ?macho.entry_point_command = null,
entry_addr: ?u64 = null,

/// The first 4GB of process' memory is reserved for the null (__PAGEZERO) segment.
/// This is also the start address for our binary.
vm_start_address: u64 = 0x100000000,

seg_table_dirty: bool = false,

error_flags: File.ErrorFlags = File.ErrorFlags{},

/// `alloc_num / alloc_den` is the factor of padding when allocating.
const alloc_num = 4;
const alloc_den = 3;

/// Default path to dyld
/// TODO instead of hardcoding it, we should probably look through some env vars and search paths
/// instead but this will do for now.
const DEFAULT_DYLD_PATH: [*:0]const u8 = "/usr/lib/dyld";

/// Default lib search path
/// TODO instead of hardcoding it, we should probably look through some env vars and search paths
/// instead but this will do for now.
const DEFAULT_LIB_SEARCH_PATH: []const u8 = "/usr/lib";

const LIB_SYSTEM_NAME: [*:0]const u8 = "System";
/// TODO we should search for libSystem and fail if it doesn't exist, instead of hardcoding it
const LIB_SYSTEM_PATH: [*:0]const u8 = DEFAULT_LIB_SEARCH_PATH ++ "/libSystem.B.dylib";

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
                .maxprot = macho.VM_PROT_NONE,
                .initprot = macho.VM_PROT_NONE,
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
            if (is_darwin) {
                {
                    // Specify path to dynamic linker dyld
                    const cmdsize = commandSize(@sizeOf(macho.dylinker_command) + mem.lenZ(DEFAULT_DYLD_PATH));
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

                    const file_offset = self.command_file_offset.? + @sizeOf(macho.dylinker_command);
                    try self.addPadding(cmdsize - @sizeOf(macho.dylinker_command), file_offset);

                    try self.base.file.?.pwriteAll(mem.spanZ(DEFAULT_DYLD_PATH), file_offset);
                    self.command_file_offset.? += cmdsize;
                }

                {
                    // Link against libSystem
                    const cmdsize = commandSize(@sizeOf(macho.dylib_command) + mem.lenZ(LIB_SYSTEM_PATH));
                    // According to Apple's manual, we should obtain current libSystem version using libc call
                    // NSVersionOfRunTimeLibrary.
                    const version = std.c.NSVersionOfRunTimeLibrary(LIB_SYSTEM_NAME);
                    const dylib = .{
                        .name = @sizeOf(macho.dylib_command),
                        .timestamp = 2, // not sure why not simply 0; this is reverse engineered from Mach-O files
                        .current_version = version,
                        .compatibility_version = 0x10000, // not sure why this either; value from reverse engineering
                    };
                    const load_dylib = [1]macho.dylib_command{
                        .{
                            .cmd = macho.LC_LOAD_DYLIB,
                            .cmdsize = cmdsize,
                            .dylib = dylib,
                        },
                    };
                    try self.commands.append(self.base.allocator, .{
                        .cmd = macho.LC_LOAD_DYLIB,
                        .cmdsize = cmdsize,
                    });

                    try self.base.file.?.pwriteAll(mem.sliceAsBytes(load_dylib[0..1]), self.command_file_offset.?);

                    const file_offset = self.command_file_offset.? + @sizeOf(macho.dylib_command);
                    try self.addPadding(cmdsize - @sizeOf(macho.dylib_command), file_offset);

                    try self.base.file.?.pwriteAll(mem.spanZ(LIB_SYSTEM_PATH), file_offset);
                    self.command_file_offset.? += cmdsize;
                }
            }
        },
        .Obj => return error.TODOImplementWritingObjFiles,
        .Lib => return error.TODOImplementWritingLibFiles,
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
    self.commands.deinit(self.base.allocator);
    self.segments.deinit(self.base.allocator);
    self.sections.deinit(self.base.allocator);
}

pub fn allocateDeclIndexes(self: *MachO, decl: *Module.Decl) !void {}

pub fn updateDecl(self: *MachO, module: *Module, decl: *Module.Decl) !void {}

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
    if (self.text_segment_offset == null) {
        self.text_segment_offset = @intCast(u64, self.segments.items.len);
        const file_size = alignSize(u64, self.base.options.program_code_size_hint, 0x1000);
        log.debug("vmsize/filesize = {}", .{file_size});
        const file_offset = 0;
        const vm_address = self.vm_start_address; // the end of __PAGEZERO segment in VM
        const protection = macho.VM_PROT_READ | macho.VM_PROT_EXECUTE;
        const cmdsize = commandSize(@sizeOf(macho.segment_command_64));
        const text_segment = .{
            .cmd = macho.LC_SEGMENT_64,
            .cmdsize = cmdsize,
            .segname = makeString("__TEXT"),
            .vmaddr = vm_address,
            .vmsize = file_size,
            .fileoff = 0, // __TEXT segment *always* starts at 0 file offset
            .filesize = 0, //file_size,
            .maxprot = protection,
            .initprot = protection,
            .nsects = 0,
            .flags = 0,
        };
        try self.commands.append(self.base.allocator, .{
            .cmd = macho.LC_SEGMENT_64,
            .cmdsize = cmdsize,
        });
        try self.segments.append(self.base.allocator, text_segment);
    }
}

fn makeString(comptime bytes: []const u8) [16]u8 {
    var buf = [_]u8{0} ** 16;
    if (bytes.len > buf.len) @compileError("MachO segment/section name too long");
    mem.copy(u8, buf[0..], bytes);
    return buf;
}

fn alignSize(comptime Int: type, min_size: anytype, alignment: Int) Int {
    const size = @intCast(Int, min_size);
    if (size % alignment == 0) return size;

    const div = size / alignment;
    return (div + 1) * alignment;
}

fn commandSize(min_size: anytype) u32 {
    return alignSize(u32, min_size, @sizeOf(u64));
}

fn addPadding(self: *MachO, size: u32, file_offset: u64) !void {
    if (size == 0) return;

    const buf = try self.base.allocator.alloc(u8, size);
    defer self.base.allocator.free(buf);

    mem.set(u8, buf[0..], 0);

    try self.base.file.?.pwriteAll(buf, file_offset);
}
