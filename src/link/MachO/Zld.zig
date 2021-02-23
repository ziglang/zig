const Zld = @This();

const std = @import("std");
const assert = std.debug.assert;
const dwarf = std.dwarf;
const leb = std.leb;
const mem = std.mem;
const meta = std.meta;
const fs = std.fs;
const macho = std.macho;
const math = std.math;
const log = std.log.scoped(.zld);

const Allocator = mem.Allocator;
const CodeSignature = @import("CodeSignature.zig");
const Archive = @import("Archive.zig");
const Object = @import("Object.zig");
const Trie = @import("Trie.zig");

usingnamespace @import("commands.zig");
usingnamespace @import("bind.zig");
usingnamespace @import("reloc.zig");

allocator: *Allocator,

arch: ?std.Target.Cpu.Arch = null,
page_size: ?u16 = null,
file: ?fs.File = null,
out_path: ?[]const u8 = null,

// TODO Eventually, we will want to keep track of the  archives themselves to be able to exclude objects
// contained within from landing in the final artifact. For now however, since we don't optimise the binary
// at all, we just move all objects from the archives into the final artifact.
objects: std.ArrayListUnmanaged(Object) = .{},

load_commands: std.ArrayListUnmanaged(LoadCommand) = .{},

pagezero_segment_cmd_index: ?u16 = null,
text_segment_cmd_index: ?u16 = null,
data_segment_cmd_index: ?u16 = null,
linkedit_segment_cmd_index: ?u16 = null,
dyld_info_cmd_index: ?u16 = null,
symtab_cmd_index: ?u16 = null,
dysymtab_cmd_index: ?u16 = null,
dylinker_cmd_index: ?u16 = null,
libsystem_cmd_index: ?u16 = null,
data_in_code_cmd_index: ?u16 = null,
function_starts_cmd_index: ?u16 = null,
main_cmd_index: ?u16 = null,
version_min_cmd_index: ?u16 = null,
source_version_cmd_index: ?u16 = null,
uuid_cmd_index: ?u16 = null,
code_signature_cmd_index: ?u16 = null,

text_section_index: ?u16 = null,
stubs_section_index: ?u16 = null,
stub_helper_section_index: ?u16 = null,
got_section_index: ?u16 = null,
tlv_section_index: ?u16 = null,
la_symbol_ptr_section_index: ?u16 = null,
data_section_index: ?u16 = null,

locals: std.StringArrayHashMapUnmanaged(macho.nlist_64) = .{},
exports: std.StringArrayHashMapUnmanaged(macho.nlist_64) = .{},
nonlazy_imports: std.StringArrayHashMapUnmanaged(Import) = .{},
lazy_imports: std.StringArrayHashMapUnmanaged(Import) = .{},
threadlocal_imports: std.StringArrayHashMapUnmanaged(Import) = .{},
local_rebases: std.ArrayListUnmanaged(Pointer) = .{},

strtab: std.ArrayListUnmanaged(u8) = .{},

stub_helper_stubs_start_off: ?u64 = null,

segments_directory: std.AutoHashMapUnmanaged([16]u8, u16) = .{},
directory: std.AutoHashMapUnmanaged(DirectoryKey, DirectoryEntry) = .{},

const DirectoryKey = struct {
    segname: [16]u8,
    sectname: [16]u8,
};

const DirectoryEntry = struct {
    seg_index: u16,
    sect_index: u16,
};

const DebugInfo = struct {
    inner: dwarf.DwarfInfo,
    debug_info: []u8,
    debug_abbrev: []u8,
    debug_str: []u8,
    debug_line: []u8,
    debug_ranges: []u8,

    pub fn parseFromObject(allocator: *Allocator, object: Object) !?DebugInfo {
        var debug_info = blk: {
            const index = object.dwarf_debug_info_index orelse return null;
            break :blk try object.readSection(allocator, index);
        };
        var debug_abbrev = blk: {
            const index = object.dwarf_debug_abbrev_index orelse return null;
            break :blk try object.readSection(allocator, index);
        };
        var debug_str = blk: {
            const index = object.dwarf_debug_str_index orelse return null;
            break :blk try object.readSection(allocator, index);
        };
        var debug_line = blk: {
            const index = object.dwarf_debug_line_index orelse return null;
            break :blk try object.readSection(allocator, index);
        };
        var debug_ranges = blk: {
            if (object.dwarf_debug_ranges_index) |ind| {
                break :blk try object.readSection(allocator, ind);
            }
            break :blk try allocator.alloc(u8, 0);
        };

        var inner: dwarf.DwarfInfo = .{
            .endian = .Little,
            .debug_info = debug_info,
            .debug_abbrev = debug_abbrev,
            .debug_str = debug_str,
            .debug_line = debug_line,
            .debug_ranges = debug_ranges,
        };
        try dwarf.openDwarfDebugInfo(&inner, allocator);

        return DebugInfo{
            .inner = inner,
            .debug_info = debug_info,
            .debug_abbrev = debug_abbrev,
            .debug_str = debug_str,
            .debug_line = debug_line,
            .debug_ranges = debug_ranges,
        };
    }

    pub fn deinit(self: *DebugInfo, allocator: *Allocator) void {
        allocator.free(self.debug_info);
        allocator.free(self.debug_abbrev);
        allocator.free(self.debug_str);
        allocator.free(self.debug_line);
        allocator.free(self.debug_ranges);
        self.inner.abbrev_table_list.deinit();
        self.inner.compile_unit_list.deinit();
        self.inner.func_list.deinit();
    }
};

pub const Import = struct {
    /// MachO symbol table entry.
    symbol: macho.nlist_64,

    /// Id of the dynamic library where the specified entries can be found.
    dylib_ordinal: i64,

    /// Index of this import within the import list.
    index: u32,
};

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

pub fn init(allocator: *Allocator) Zld {
    return .{ .allocator = allocator };
}

pub fn deinit(self: *Zld) void {
    self.strtab.deinit(self.allocator);
    self.local_rebases.deinit(self.allocator);
    for (self.lazy_imports.items()) |*entry| {
        self.allocator.free(entry.key);
    }
    self.lazy_imports.deinit(self.allocator);
    for (self.threadlocal_imports.items()) |*entry| {
        self.allocator.free(entry.key);
    }
    self.threadlocal_imports.deinit(self.allocator);
    for (self.nonlazy_imports.items()) |*entry| {
        self.allocator.free(entry.key);
    }
    self.nonlazy_imports.deinit(self.allocator);
    for (self.exports.items()) |*entry| {
        self.allocator.free(entry.key);
    }
    self.exports.deinit(self.allocator);
    for (self.locals.items()) |*entry| {
        self.allocator.free(entry.key);
    }
    self.locals.deinit(self.allocator);
    for (self.objects.items) |*object| {
        object.deinit();
    }
    self.objects.deinit(self.allocator);
    for (self.load_commands.items) |*lc| {
        lc.deinit(self.allocator);
    }
    self.load_commands.deinit(self.allocator);
    self.segments_directory.deinit(self.allocator);
    self.directory.deinit(self.allocator);
    if (self.file) |*f| f.close();
}

pub fn link(self: *Zld, files: []const []const u8, out_path: []const u8) !void {
    if (files.len == 0) return error.NoInputFiles;
    if (out_path.len == 0) return error.EmptyOutputPath;

    if (self.arch == null) {
        // Try inferring the arch from the object files.
        self.arch = blk: {
            const file = try fs.cwd().openFile(files[0], .{});
            defer file.close();
            var reader = file.reader();
            const header = try reader.readStruct(macho.mach_header_64);
            const arch: std.Target.Cpu.Arch = switch (header.cputype) {
                macho.CPU_TYPE_X86_64 => .x86_64,
                macho.CPU_TYPE_ARM64 => .aarch64,
                else => |value| {
                    log.err("unsupported cpu architecture 0x{x}", .{value});
                    return error.UnsupportedCpuArchitecture;
                },
            };
            break :blk arch;
        };
    }

    self.page_size = switch (self.arch.?) {
        .aarch64 => 0x4000,
        .x86_64 => 0x1000,
        else => unreachable,
    };
    self.out_path = out_path;
    self.file = try fs.cwd().createFile(out_path, .{
        .truncate = true,
        .read = true,
        .mode = if (std.Target.current.os.tag == .windows) 0 else 0o777,
    });

    try self.populateMetadata();
    try self.parseInputFiles(files);
    try self.resolveImports();
    self.allocateTextSegment();
    self.allocateDataSegment();
    self.allocateLinkeditSegment();
    try self.writeStubHelperCommon();
    try self.resolveSymbols();
    try self.doRelocs();
    try self.flush();
}

fn parseInputFiles(self: *Zld, files: []const []const u8) !void {
    for (files) |file_name| {
        const file = try fs.cwd().openFile(file_name, .{});

        try_object: {
            var object = Object.initFromFile(self.allocator, self.arch.?, file_name, file) catch |err| switch (err) {
                error.NotObject => break :try_object,
                else => |e| return e,
            };
            const index = self.objects.items.len;
            try self.objects.append(self.allocator, object);
            const p_object = &self.objects.items[index];
            try self.parseObjectFile(p_object);
            continue;
        }

        try_archive: {
            var archive = Archive.initFromFile(self.allocator, self.arch.?, file_name, file) catch |err| switch (err) {
                error.NotArchive => break :try_archive,
                else => |e| return e,
            };
            defer archive.deinit();
            while (archive.objects.popOrNull()) |object| {
                const index = self.objects.items.len;
                try self.objects.append(self.allocator, object);
                const p_object = &self.objects.items[index];
                try self.parseObjectFile(p_object);
            }
            continue;
        }

        log.err("unexpected file type: expected object '.o' or archive '.a': {s}", .{file_name});
        return error.UnexpectedInputFileType;
    }
}

fn parseObjectFile(self: *Zld, object: *const Object) !void {
    const seg_cmd = object.load_commands.items[object.segment_cmd_index.?].Segment;
    for (seg_cmd.sections.items) |sect| {
        const sectname = parseName(&sect.sectname);

        const seg_index = self.segments_directory.get(sect.segname) orelse {
            log.info("segname {s} not found in the output artifact", .{sect.segname});
            continue;
        };
        const seg = &self.load_commands.items[seg_index].Segment;
        const res = try self.directory.getOrPut(self.allocator, .{
            .segname = sect.segname,
            .sectname = sect.sectname,
        });
        if (!res.found_existing) {
            const sect_index = @intCast(u16, seg.sections.items.len);
            if (mem.eql(u8, sectname, "__thread_vars")) {
                self.tlv_section_index = sect_index;
            }
            try seg.append(self.allocator, .{
                .sectname = makeStaticString(&sect.sectname),
                .segname = makeStaticString(&sect.segname),
                .addr = 0,
                .size = 0,
                .offset = 0,
                .@"align" = sect.@"align",
                .reloff = 0,
                .nreloc = 0,
                .flags = sect.flags,
                .reserved1 = 0,
                .reserved2 = 0,
                .reserved3 = 0,
            });
            res.entry.value = .{
                .seg_index = seg_index,
                .sect_index = sect_index,
            };
        }
        const dest_sect = &seg.sections.items[res.entry.value.sect_index];
        dest_sect.size += sect.size;
        seg.inner.filesize += sect.size;
    }
}

fn resolveImports(self: *Zld) !void {
    var imports = std.StringArrayHashMap(bool).init(self.allocator);
    defer imports.deinit();

    for (self.objects.items) |object| {
        for (object.symtab.items) |sym| {
            if (isLocal(&sym)) continue;

            const name = object.getString(sym.n_strx);
            const res = try imports.getOrPut(name);
            if (isExport(&sym)) {
                res.entry.value = false;
                continue;
            }
            if (res.found_existing and !res.entry.value)
                continue;
            res.entry.value = true;
        }
    }

    for (imports.items()) |entry| {
        if (!entry.value) continue;

        const sym_name = entry.key;
        const n_strx = try self.makeString(sym_name);
        var new_sym: macho.nlist_64 = .{
            .n_strx = n_strx,
            .n_type = macho.N_UNDF | macho.N_EXT,
            .n_value = 0,
            .n_desc = macho.REFERENCE_FLAG_UNDEFINED_NON_LAZY | macho.N_SYMBOL_RESOLVER,
            .n_sect = 0,
        };
        var key = try self.allocator.dupe(u8, sym_name);
        // TODO handle symbol resolution from non-libc dylibs.
        const dylib_ordinal = 1;

        // TODO need to rework this. Perhaps should create a set of all possible libc
        // symbols which are expected to be nonlazy?
        if (mem.eql(u8, sym_name, "___stdoutp") or
            mem.eql(u8, sym_name, "___stderrp") or
            mem.eql(u8, sym_name, "___stdinp") or
            mem.eql(u8, sym_name, "___stack_chk_guard") or
            mem.eql(u8, sym_name, "_environ"))
        {
            log.debug("writing nonlazy symbol '{s}'", .{sym_name});
            const index = @intCast(u32, self.nonlazy_imports.items().len);
            try self.nonlazy_imports.putNoClobber(self.allocator, key, .{
                .symbol = new_sym,
                .dylib_ordinal = dylib_ordinal,
                .index = index,
            });
        } else if (mem.eql(u8, sym_name, "__tlv_bootstrap")) {
            log.debug("writing threadlocal symbol '{s}'", .{sym_name});
            const index = @intCast(u32, self.threadlocal_imports.items().len);
            try self.threadlocal_imports.putNoClobber(self.allocator, key, .{
                .symbol = new_sym,
                .dylib_ordinal = dylib_ordinal,
                .index = index,
            });
        } else {
            log.debug("writing lazy symbol '{s}'", .{sym_name});
            const index = @intCast(u32, self.lazy_imports.items().len);
            try self.lazy_imports.putNoClobber(self.allocator, key, .{
                .symbol = new_sym,
                .dylib_ordinal = dylib_ordinal,
                .index = index,
            });
        }
    }

    const n_strx = try self.makeString("dyld_stub_binder");
    const name = try self.allocator.dupe(u8, "dyld_stub_binder");
    log.debug("writing nonlazy symbol 'dyld_stub_binder'", .{});
    const index = @intCast(u32, self.nonlazy_imports.items().len);
    try self.nonlazy_imports.putNoClobber(self.allocator, name, .{
        .symbol = .{
            .n_strx = n_strx,
            .n_type = std.macho.N_UNDF | std.macho.N_EXT,
            .n_sect = 0,
            .n_desc = std.macho.REFERENCE_FLAG_UNDEFINED_NON_LAZY | std.macho.N_SYMBOL_RESOLVER,
            .n_value = 0,
        },
        .dylib_ordinal = 1,
        .index = index,
    });
}

fn allocateTextSegment(self: *Zld) void {
    const seg = &self.load_commands.items[self.text_segment_cmd_index.?].Segment;
    const nexterns = @intCast(u32, self.lazy_imports.items().len);

    // Set stubs and stub_helper sizes
    const stubs = &seg.sections.items[self.stubs_section_index.?];
    const stub_helper = &seg.sections.items[self.stub_helper_section_index.?];
    stubs.size += nexterns * stubs.reserved2;

    const stub_size: u4 = switch (self.arch.?) {
        .x86_64 => 10,
        .aarch64 => 3 * @sizeOf(u32),
        else => unreachable,
    };
    stub_helper.size += nexterns * stub_size;

    var sizeofcmds: u64 = 0;
    for (self.load_commands.items) |lc| {
        sizeofcmds += lc.cmdsize();
    }

    self.allocateSegment(self.text_segment_cmd_index.?, 0, sizeofcmds, true);
}

fn allocateDataSegment(self: *Zld) void {
    const seg = &self.load_commands.items[self.data_segment_cmd_index.?].Segment;
    const nonlazy = @intCast(u32, self.nonlazy_imports.items().len);
    const lazy = @intCast(u32, self.lazy_imports.items().len);

    // Set got size
    const got = &seg.sections.items[self.got_section_index.?];
    got.size += nonlazy * @sizeOf(u64);

    // Set la_symbol_ptr and data size
    const la_symbol_ptr = &seg.sections.items[self.la_symbol_ptr_section_index.?];
    const data = &seg.sections.items[self.data_section_index.?];
    la_symbol_ptr.size += lazy * @sizeOf(u64);
    data.size += @sizeOf(u64); // TODO when do we need more?

    const text_seg = self.load_commands.items[self.text_segment_cmd_index.?].Segment;
    const offset = text_seg.inner.fileoff + text_seg.inner.filesize;
    self.allocateSegment(self.data_segment_cmd_index.?, offset, 0, false);
}

fn allocateLinkeditSegment(self: *Zld) void {
    const data_seg = self.load_commands.items[self.data_segment_cmd_index.?].Segment;
    const offset = data_seg.inner.fileoff + data_seg.inner.filesize;
    self.allocateSegment(self.linkedit_segment_cmd_index.?, offset, 0, false);
}

fn allocateSegment(self: *Zld, index: u16, offset: u64, start: u64, reverse: bool) void {
    const base_vmaddr = self.load_commands.items[self.pagezero_segment_cmd_index.?].Segment.inner.vmsize;
    const seg = &self.load_commands.items[index].Segment;

    // Calculate segment size
    var total_size = start;
    for (seg.sections.items) |sect| {
        total_size += sect.size;
    }
    const aligned_size = mem.alignForwardGeneric(u64, total_size, self.page_size.?);
    seg.inner.vmaddr = base_vmaddr + offset;
    seg.inner.vmsize = aligned_size;
    seg.inner.fileoff = offset;
    seg.inner.filesize = aligned_size;

    // Allocate section offsets
    if (reverse) {
        var end_off: u64 = seg.inner.fileoff + seg.inner.filesize;
        var count: usize = seg.sections.items.len;
        while (count > 0) : (count -= 1) {
            const sec = &seg.sections.items[count - 1];
            end_off -= mem.alignForwardGeneric(u64, sec.size, @sizeOf(u32)); // TODO Should we always align to 4?
            sec.offset = @intCast(u32, end_off);
            sec.addr = base_vmaddr + end_off;
        }
    } else {
        var next_off: u64 = seg.inner.fileoff;
        for (seg.sections.items) |*sect| {
            sect.offset = @intCast(u32, next_off);
            sect.addr = base_vmaddr + next_off;
            next_off += mem.alignForwardGeneric(u64, sect.size, @sizeOf(u32)); // TODO Should we always align to 4?
        }
    }
}

fn writeStubHelperCommon(self: *Zld) !void {
    const text_segment = &self.load_commands.items[self.text_segment_cmd_index.?].Segment;
    const stub_helper = &text_segment.sections.items[self.stub_helper_section_index.?];
    const data_segment = &self.load_commands.items[self.data_segment_cmd_index.?].Segment;
    const data = &data_segment.sections.items[self.data_section_index.?];
    const la_symbol_ptr = data_segment.sections.items[self.la_symbol_ptr_section_index.?];
    const got = &data_segment.sections.items[self.got_section_index.?];

    self.stub_helper_stubs_start_off = blk: {
        switch (self.arch.?) {
            .x86_64 => {
                const code_size = 15;
                var code: [code_size]u8 = undefined;
                // lea %r11, [rip + disp]
                code[0] = 0x4c;
                code[1] = 0x8d;
                code[2] = 0x1d;
                {
                    const target_addr = data.addr + data.size - @sizeOf(u64);
                    const displacement = try math.cast(u32, target_addr - stub_helper.addr - 7);
                    mem.writeIntLittle(u32, code[3..7], displacement);
                }
                // push %r11
                code[7] = 0x41;
                code[8] = 0x53;
                // jmp [rip + disp]
                code[9] = 0xff;
                code[10] = 0x25;
                {
                    const dyld_stub_binder = self.nonlazy_imports.get("dyld_stub_binder").?;
                    const addr = (got.addr + dyld_stub_binder.index * @sizeOf(u64));
                    const displacement = try math.cast(u32, addr - stub_helper.addr - code_size);
                    mem.writeIntLittle(u32, code[11..], displacement);
                }
                try self.file.?.pwriteAll(&code, stub_helper.offset);
                break :blk stub_helper.offset + code_size;
            },
            .aarch64 => {
                var code: [4 * @sizeOf(u32)]u8 = undefined;
                {
                    const target_addr = data.addr + data.size - @sizeOf(u64);
                    const displacement = @bitCast(u21, try math.cast(i21, target_addr - stub_helper.addr));
                    // adr x17, disp
                    mem.writeIntLittle(u32, code[0..4], Arm64.adr(17, displacement).toU32());
                }
                // stp x16, x17, [sp, #-16]!
                code[4] = 0xf0;
                code[5] = 0x47;
                code[6] = 0xbf;
                code[7] = 0xa9;
                {
                    const dyld_stub_binder = self.nonlazy_imports.get("dyld_stub_binder").?;
                    const addr = (got.addr + dyld_stub_binder.index * @sizeOf(u64));
                    const displacement = try math.divExact(u64, addr - stub_helper.addr - 2 * @sizeOf(u32), 4);
                    const literal = try math.cast(u19, displacement);
                    // ldr x16, label
                    mem.writeIntLittle(u32, code[8..12], Arm64.ldr(16, literal, 1).toU32());
                }
                // br x16
                code[12] = 0x00;
                code[13] = 0x02;
                code[14] = 0x1f;
                code[15] = 0xd6;
                try self.file.?.pwriteAll(&code, stub_helper.offset);
                break :blk stub_helper.offset + 4 * @sizeOf(u32);
            },
            else => unreachable,
        }
    };

    for (self.lazy_imports.items()) |_, i| {
        const index = @intCast(u32, i);
        try self.writeLazySymbolPointer(index);
        try self.writeStub(index);
        try self.writeStubInStubHelper(index);
    }
}

fn writeLazySymbolPointer(self: *Zld, index: u32) !void {
    const text_segment = self.load_commands.items[self.text_segment_cmd_index.?].Segment;
    const stub_helper = text_segment.sections.items[self.stub_helper_section_index.?];
    const data_segment = self.load_commands.items[self.data_segment_cmd_index.?].Segment;
    const la_symbol_ptr = data_segment.sections.items[self.la_symbol_ptr_section_index.?];

    const stub_size: u4 = switch (self.arch.?) {
        .x86_64 => 10,
        .aarch64 => 3 * @sizeOf(u32),
        else => unreachable,
    };
    const stub_off = self.stub_helper_stubs_start_off.? + index * stub_size;
    const end = stub_helper.addr + stub_off - stub_helper.offset;
    var buf: [@sizeOf(u64)]u8 = undefined;
    mem.writeIntLittle(u64, &buf, end);
    const off = la_symbol_ptr.offset + index * @sizeOf(u64);
    log.debug("writing lazy symbol pointer entry 0x{x} at 0x{x}", .{ end, off });
    try self.file.?.pwriteAll(&buf, off);
}

fn writeStub(self: *Zld, index: u32) !void {
    const text_segment = self.load_commands.items[self.text_segment_cmd_index.?].Segment;
    const stubs = text_segment.sections.items[self.stubs_section_index.?];
    const data_segment = self.load_commands.items[self.data_segment_cmd_index.?].Segment;
    const la_symbol_ptr = data_segment.sections.items[self.la_symbol_ptr_section_index.?];

    const stub_off = stubs.offset + index * stubs.reserved2;
    const stub_addr = stubs.addr + index * stubs.reserved2;
    const la_ptr_addr = la_symbol_ptr.addr + index * @sizeOf(u64);
    log.debug("writing stub at 0x{x}", .{stub_off});
    var code = try self.allocator.alloc(u8, stubs.reserved2);
    defer self.allocator.free(code);
    switch (self.arch.?) {
        .x86_64 => {
            assert(la_ptr_addr >= stub_addr + stubs.reserved2);
            const displacement = try math.cast(u32, la_ptr_addr - stub_addr - stubs.reserved2);
            // jmp
            code[0] = 0xff;
            code[1] = 0x25;
            mem.writeIntLittle(u32, code[2..][0..4], displacement);
        },
        .aarch64 => {
            assert(la_ptr_addr >= stub_addr);
            const displacement = try math.divExact(u64, la_ptr_addr - stub_addr, 4);
            const literal = try math.cast(u19, displacement);
            // ldr x16, literal
            mem.writeIntLittle(u32, code[0..4], Arm64.ldr(16, literal, 1).toU32());
            // br x16
            mem.writeIntLittle(u32, code[4..8], Arm64.br(16).toU32());
        },
        else => unreachable,
    }
    try self.file.?.pwriteAll(code, stub_off);
}

fn writeStubInStubHelper(self: *Zld, index: u32) !void {
    const text_segment = self.load_commands.items[self.text_segment_cmd_index.?].Segment;
    const stub_helper = text_segment.sections.items[self.stub_helper_section_index.?];

    const stub_size: u4 = switch (self.arch.?) {
        .x86_64 => 10,
        .aarch64 => 3 * @sizeOf(u32),
        else => unreachable,
    };
    const stub_off = self.stub_helper_stubs_start_off.? + index * stub_size;
    var code = try self.allocator.alloc(u8, stub_size);
    defer self.allocator.free(code);
    switch (self.arch.?) {
        .x86_64 => {
            const displacement = try math.cast(
                i32,
                @intCast(i64, stub_helper.offset) - @intCast(i64, stub_off) - stub_size,
            );
            // pushq
            code[0] = 0x68;
            mem.writeIntLittle(u32, code[1..][0..4], 0x0); // Just a placeholder populated in `populateLazyBindOffsetsInStubHelper`.
            // jmpq
            code[5] = 0xe9;
            mem.writeIntLittle(u32, code[6..][0..4], @bitCast(u32, displacement));
        },
        .aarch64 => {
            const displacement = try math.cast(i28, @intCast(i64, stub_helper.offset) - @intCast(i64, stub_off) - 4);
            const literal = @divExact(stub_size - @sizeOf(u32), 4);
            // ldr w16, literal
            mem.writeIntLittle(u32, code[0..4], Arm64.ldr(16, literal, 0).toU32());
            // b disp
            mem.writeIntLittle(u32, code[4..8], Arm64.b(displacement).toU32());
            mem.writeIntLittle(u32, code[8..12], 0x0); // Just a placeholder populated in `populateLazyBindOffsetsInStubHelper`.
        },
        else => unreachable,
    }
    try self.file.?.pwriteAll(code, stub_off);
}

fn resolveSymbols(self: *Zld) !void {
    const Address = struct {
        addr: u64,
        size: u64,
    };
    var next_address = std.AutoHashMap(DirectoryKey, Address).init(self.allocator);
    defer next_address.deinit();

    for (self.objects.items) |object| {
        const seg = object.load_commands.items[object.segment_cmd_index.?].Segment;

        for (seg.sections.items) |sect| {
            const key: DirectoryKey = .{
                .segname = sect.segname,
                .sectname = sect.sectname,
            };
            const indices = self.directory.get(key) orelse continue;
            const out_seg = self.load_commands.items[indices.seg_index].Segment;
            const out_sect = out_seg.sections.items[indices.sect_index];

            const res = try next_address.getOrPut(key);
            const next = &res.entry.value;
            if (res.found_existing) {
                next.addr += next.size;
            } else {
                next.addr = out_sect.addr;
            }
            next.size = sect.size;
        }

        for (object.symtab.items) |sym| {
            if (isImport(&sym)) continue;

            const sym_name = object.getString(sym.n_strx);

            if (isLocal(&sym) and self.locals.get(sym_name) != null) {
                log.debug("symbol '{s}' already exists; skipping", .{sym_name});
                continue;
            }

            const sect = seg.sections.items[sym.n_sect - 1];
            const key: DirectoryKey = .{
                .segname = sect.segname,
                .sectname = sect.sectname,
            };
            const res = self.directory.get(key) orelse continue;

            const n_strx = try self.makeString(sym_name);
            const n_value = sym.n_value - sect.addr + next_address.get(key).?.addr;

            log.debug("resolving '{s}' as local symbol at 0x{x}", .{ sym_name, n_value });

            var n_sect = res.sect_index + 1;
            for (self.load_commands.items) |sseg, i| {
                if (i == res.seg_index) {
                    break;
                }
                n_sect += @intCast(u16, sseg.Segment.sections.items.len);
            }

            var out_name = try self.allocator.dupe(u8, sym_name);
            try self.locals.putNoClobber(self.allocator, out_name, .{
                .n_strx = n_strx,
                .n_value = n_value,
                .n_type = macho.N_SECT,
                .n_desc = sym.n_desc,
                .n_sect = @intCast(u8, n_sect),
            });
        }
    }
}

fn doRelocs(self: *Zld) !void {
    const Space = struct {
        address: u64,
        offset: u64,
        size: u64,
    };
    var next_space = std.AutoHashMap(DirectoryKey, Space).init(self.allocator);
    defer next_space.deinit();

    for (self.objects.items) |object| {
        log.debug("\n\n", .{});
        log.debug("relocating object {s}", .{object.name});

        const seg = object.load_commands.items[object.segment_cmd_index.?].Segment;

        for (seg.sections.items) |sect| {
            const key: DirectoryKey = .{
                .segname = sect.segname,
                .sectname = sect.sectname,
            };
            const indices = self.directory.get(key) orelse continue;
            const out_seg = self.load_commands.items[indices.seg_index].Segment;
            const out_sect = out_seg.sections.items[indices.sect_index];

            const res = try next_space.getOrPut(key);
            const next = &res.entry.value;
            if (res.found_existing) {
                next.offset += next.size;
                next.address += next.size;
            } else {
                next.offset = out_sect.offset;
                next.address = out_sect.addr;
            }
            next.size = sect.size;
        }

        for (seg.sections.items) |sect| {
            const segname = parseName(&sect.segname);
            const sectname = parseName(&sect.sectname);

            const key: DirectoryKey = .{
                .segname = sect.segname,
                .sectname = sect.sectname,
            };
            const next = next_space.get(key) orelse continue;

            var code = try self.allocator.alloc(u8, sect.size);
            defer self.allocator.free(code);
            _ = try object.file.preadAll(code, sect.offset);

            // Parse relocs (if any)
            var raw_relocs = try self.allocator.alloc(u8, @sizeOf(macho.relocation_info) * sect.nreloc);
            defer self.allocator.free(raw_relocs);
            _ = try object.file.preadAll(raw_relocs, sect.reloff);
            const relocs = mem.bytesAsSlice(macho.relocation_info, raw_relocs);

            var addend: ?u64 = null;
            var sub: ?i64 = null;

            for (relocs) |rel| {
                const off = @intCast(u32, rel.r_address);
                const this_addr = next.address + off;

                switch (self.arch.?) {
                    .aarch64 => {
                        const rel_type = @intToEnum(macho.reloc_type_arm64, rel.r_type);
                        log.debug("{s}", .{rel_type});
                        log.debug("    | source address 0x{x}", .{this_addr});
                        log.debug("    | offset 0x{x}", .{off});

                        if (rel_type == .ARM64_RELOC_ADDEND) {
                            addend = rel.r_symbolnum;
                            log.debug("    | calculated addend = 0x{x}", .{addend});
                            // TODO followed by either PAGE21 or PAGEOFF12 only.
                            continue;
                        }
                    },
                    .x86_64 => {
                        const rel_type = @intToEnum(macho.reloc_type_x86_64, rel.r_type);
                        log.debug("{s}", .{rel_type});
                        log.debug("    | source address 0x{x}", .{this_addr});
                        log.debug("    | offset 0x{x}", .{off});
                    },
                    else => {},
                }

                const target_addr = try self.relocTargetAddr(object, rel, next_space);
                log.debug("    | target address 0x{x}", .{target_addr});
                if (rel.r_extern == 1) {
                    const target_symname = object.getString(object.symtab.items[rel.r_symbolnum].n_strx);
                    log.debug("    | target symbol '{s}'", .{target_symname});
                } else {
                    const target_sectname = seg.sections.items[rel.r_symbolnum - 1].sectname;
                    log.debug("    | target section '{s}'", .{parseName(&target_sectname)});
                }

                switch (self.arch.?) {
                    .x86_64 => {
                        const rel_type = @intToEnum(macho.reloc_type_x86_64, rel.r_type);

                        switch (rel_type) {
                            .X86_64_RELOC_BRANCH,
                            .X86_64_RELOC_GOT_LOAD,
                            .X86_64_RELOC_GOT,
                            => {
                                assert(rel.r_length == 2);
                                const inst = code[off..][0..4];
                                const displacement = @bitCast(u32, @intCast(i32, @intCast(i64, target_addr) - @intCast(i64, this_addr) - 4));
                                mem.writeIntLittle(u32, inst, displacement);
                            },
                            .X86_64_RELOC_TLV => {
                                assert(rel.r_length == 2);
                                // We need to rewrite the opcode from movq to leaq.
                                code[off - 2] = 0x8d;
                                // Add displacement.
                                const inst = code[off..][0..4];
                                const displacement = @bitCast(u32, @intCast(i32, @intCast(i64, target_addr) - @intCast(i64, this_addr) - 4));
                                mem.writeIntLittle(u32, inst, displacement);
                            },
                            .X86_64_RELOC_SIGNED,
                            .X86_64_RELOC_SIGNED_1,
                            .X86_64_RELOC_SIGNED_2,
                            .X86_64_RELOC_SIGNED_4,
                            => {
                                assert(rel.r_length == 2);
                                const inst = code[off..][0..4];
                                const offset: i32 = blk: {
                                    if (rel.r_extern == 1) {
                                        break :blk mem.readIntLittle(i32, inst);
                                    } else {
                                        // TODO it might be required here to parse the offset from the instruction placeholder,
                                        // compare the displacement with the original displacement in the .o file, and adjust
                                        // the displacement in the resultant binary file.
                                        const correction: i4 = switch (rel_type) {
                                            .X86_64_RELOC_SIGNED => 0,
                                            .X86_64_RELOC_SIGNED_1 => 1,
                                            .X86_64_RELOC_SIGNED_2 => 2,
                                            .X86_64_RELOC_SIGNED_4 => 4,
                                            else => unreachable,
                                        };
                                        break :blk correction;
                                    }
                                };
                                log.debug("    | calculated addend 0x{x}", .{offset});
                                const result = @intCast(i64, target_addr) - @intCast(i64, this_addr) - 4 + offset;
                                const displacement = @bitCast(u32, @intCast(i32, result));
                                mem.writeIntLittle(u32, inst, displacement);
                            },
                            .X86_64_RELOC_SUBTRACTOR => {
                                sub = @intCast(i64, target_addr);
                            },
                            .X86_64_RELOC_UNSIGNED => {
                                switch (rel.r_length) {
                                    3 => {
                                        const inst = code[off..][0..8];
                                        const offset = mem.readIntLittle(i64, inst);
                                        log.debug("    | calculated addend 0x{x}", .{offset});
                                        const result = if (sub) |s|
                                            @intCast(i64, target_addr) - s + offset
                                        else
                                            @intCast(i64, target_addr) + offset;
                                        mem.writeIntLittle(u64, inst, @bitCast(u64, result));
                                        sub = null;

                                        // TODO should handle this better.
                                        if (mem.eql(u8, segname, "__DATA")) outer: {
                                            if (!mem.eql(u8, sectname, "__data") and
                                                !mem.eql(u8, sectname, "__const") and
                                                !mem.eql(u8, sectname, "__mod_init_func")) break :outer;
                                            const this_seg = self.load_commands.items[self.data_segment_cmd_index.?].Segment;
                                            const this_offset = next.address + off - this_seg.inner.vmaddr;
                                            try self.local_rebases.append(self.allocator, .{
                                                .offset = this_offset,
                                                .segment_id = @intCast(u16, self.data_segment_cmd_index.?),
                                            });
                                        }
                                    },
                                    2 => {
                                        const inst = code[off..][0..4];
                                        const offset = mem.readIntLittle(i32, inst);
                                        log.debug("    | calculated addend 0x{x}", .{offset});
                                        const result = if (sub) |s|
                                            @intCast(i64, target_addr) - s + offset
                                        else
                                            @intCast(i64, target_addr) + offset;
                                        mem.writeIntLittle(u32, inst, @truncate(u32, @bitCast(u64, result)));
                                        sub = null;
                                    },
                                    else => |len| {
                                        log.err("unexpected relocation length 0x{x}", .{len});
                                        return error.UnexpectedRelocationLength;
                                    },
                                }
                            },
                        }
                    },
                    .aarch64 => {
                        const rel_type = @intToEnum(macho.reloc_type_arm64, rel.r_type);

                        switch (rel_type) {
                            .ARM64_RELOC_BRANCH26 => {
                                assert(rel.r_length == 2);
                                const inst = code[off..][0..4];
                                const displacement = @intCast(i28, @intCast(i64, target_addr) - @intCast(i64, this_addr));
                                var parsed = mem.bytesAsValue(meta.TagPayload(Arm64, Arm64.Branch), inst);
                                parsed.disp = @truncate(u26, @bitCast(u28, displacement) >> 2);
                            },
                            .ARM64_RELOC_PAGE21,
                            .ARM64_RELOC_GOT_LOAD_PAGE21,
                            .ARM64_RELOC_TLVP_LOAD_PAGE21,
                            => {
                                assert(rel.r_length == 2);
                                const inst = code[off..][0..4];
                                const ta = if (addend) |a| target_addr + a else target_addr;
                                const this_page = @intCast(i32, this_addr >> 12);
                                const target_page = @intCast(i32, ta >> 12);
                                const pages = @bitCast(u21, @intCast(i21, target_page - this_page));
                                log.debug("    | moving by {} pages", .{pages});
                                var parsed = mem.bytesAsValue(meta.TagPayload(Arm64, Arm64.Address), inst);
                                parsed.immhi = @truncate(u19, pages >> 2);
                                parsed.immlo = @truncate(u2, pages);
                                addend = null;
                            },
                            .ARM64_RELOC_PAGEOFF12,
                            .ARM64_RELOC_GOT_LOAD_PAGEOFF12,
                            => {
                                const inst = code[off..][0..4];
                                if (Arm64.isArithmetic(inst)) {
                                    log.debug("    | detected ADD opcode", .{});
                                    // add
                                    var parsed = mem.bytesAsValue(meta.TagPayload(Arm64, Arm64.Add), inst);
                                    const ta = if (addend) |a| target_addr + a else target_addr;
                                    const narrowed = @truncate(u12, ta);
                                    parsed.offset = narrowed;
                                } else {
                                    log.debug("    | detected LDR/STR opcode", .{});
                                    // ldr/str
                                    var parsed = mem.bytesAsValue(meta.TagPayload(Arm64, Arm64.LoadRegister), inst);
                                    const ta = if (addend) |a| target_addr + a else target_addr;
                                    const narrowed = @truncate(u12, ta);
                                    const offset = if (parsed.size == 1) @divExact(narrowed, 8) else @divExact(narrowed, 4);
                                    parsed.offset = @truncate(u12, offset);
                                }
                                addend = null;
                            },
                            .ARM64_RELOC_TLVP_LOAD_PAGEOFF12 => {
                                // TODO why is this necessary?
                                const RegInfo = struct {
                                    rt: u5,
                                    rn: u5,
                                    size: u1,
                                };
                                const inst = code[off..][0..4];
                                const parsed: RegInfo = blk: {
                                    if (Arm64.isArithmetic(inst)) {
                                        const curr = mem.bytesAsValue(meta.TagPayload(Arm64, Arm64.Add), inst);
                                        break :blk .{ .rt = curr.rt, .rn = curr.rn, .size = curr.size };
                                    } else {
                                        const curr = mem.bytesAsValue(meta.TagPayload(Arm64, Arm64.LoadRegister), inst);
                                        break :blk .{ .rt = curr.rt, .rn = curr.rn, .size = curr.size };
                                    }
                                };
                                const ta = if (addend) |a| target_addr + a else target_addr;
                                const narrowed = @truncate(u12, ta);
                                log.debug("    | rewriting TLV access to ADD opcode", .{});
                                // For TLV, we always generate an add instruction.
                                mem.writeIntLittle(u32, inst, Arm64.add(parsed.rt, parsed.rn, narrowed, parsed.size).toU32());
                            },
                            .ARM64_RELOC_SUBTRACTOR => {
                                sub = @intCast(i64, target_addr);
                            },
                            .ARM64_RELOC_UNSIGNED => {
                                switch (rel.r_length) {
                                    3 => {
                                        const inst = code[off..][0..8];
                                        const offset = mem.readIntLittle(i64, inst);
                                        log.debug("    | calculated addend 0x{x}", .{offset});
                                        const result = if (sub) |s|
                                            @intCast(i64, target_addr) - s + offset
                                        else
                                            @intCast(i64, target_addr) + offset;
                                        mem.writeIntLittle(u64, inst, @bitCast(u64, result));
                                        sub = null;

                                        // TODO should handle this better.
                                        if (mem.eql(u8, segname, "__DATA")) outer: {
                                            if (!mem.eql(u8, sectname, "__data") and
                                                !mem.eql(u8, sectname, "__const") and
                                                !mem.eql(u8, sectname, "__mod_init_func")) break :outer;
                                            const this_seg = self.load_commands.items[self.data_segment_cmd_index.?].Segment;
                                            const this_offset = next.address + off - this_seg.inner.vmaddr;
                                            try self.local_rebases.append(self.allocator, .{
                                                .offset = this_offset,
                                                .segment_id = @intCast(u16, self.data_segment_cmd_index.?),
                                            });
                                        }
                                    },
                                    2 => {
                                        const inst = code[off..][0..4];
                                        const offset = mem.readIntLittle(i32, inst);
                                        log.debug("    | calculated addend 0x{x}", .{offset});
                                        const result = if (sub) |s|
                                            @intCast(i64, target_addr) - s + offset
                                        else
                                            @intCast(i64, target_addr) + offset;
                                        mem.writeIntLittle(u32, inst, @truncate(u32, @bitCast(u64, result)));
                                        sub = null;
                                    },
                                    else => |len| {
                                        log.err("unexpected relocation length 0x{x}", .{len});
                                        return error.UnexpectedRelocationLength;
                                    },
                                }
                            },
                            .ARM64_RELOC_POINTER_TO_GOT => return error.TODOArm64RelocPointerToGot,
                            else => unreachable,
                        }
                    },
                    else => unreachable,
                }
            }

            log.debug("writing contents of '{s},{s}' section from '{s}' from 0x{x} to 0x{x}", .{
                segname,
                sectname,
                object.name,
                next.offset,
                next.offset + next.size,
            });

            if (mem.eql(u8, sectname, "__bss") or
                mem.eql(u8, sectname, "__thread_bss") or
                mem.eql(u8, sectname, "__thread_vars"))
            {
                // Zero-out the space
                var zeroes = try self.allocator.alloc(u8, next.size);
                defer self.allocator.free(zeroes);
                mem.set(u8, zeroes, 0);
                try self.file.?.pwriteAll(zeroes, next.offset);
            } else {
                try self.file.?.pwriteAll(code, next.offset);
            }
        }
    }
}

fn relocTargetAddr(self: *Zld, object: Object, rel: macho.relocation_info, next_space: anytype) !u64 {
    const seg = object.load_commands.items[object.segment_cmd_index.?].Segment;
    const target_addr = blk: {
        if (rel.r_extern == 1) {
            const sym = object.symtab.items[rel.r_symbolnum];
            if (isLocal(&sym) or isExport(&sym)) {
                // Relocate using section offsets only.
                const source_sect = seg.sections.items[sym.n_sect - 1];
                const target_space = next_space.get(.{
                    .segname = source_sect.segname,
                    .sectname = source_sect.sectname,
                }).?;
                break :blk target_space.address + sym.n_value - source_sect.addr;
            } else if (isImport(&sym)) {
                // Relocate to either the artifact's local symbol, or an import from
                // shared library.
                const sym_name = object.getString(sym.n_strx);
                if (self.locals.get(sym_name)) |loc| {
                    break :blk loc.n_value;
                } else if (self.lazy_imports.get(sym_name)) |ext| {
                    const segment = self.load_commands.items[self.text_segment_cmd_index.?].Segment;
                    const stubs = segment.sections.items[self.stubs_section_index.?];
                    break :blk stubs.addr + ext.index * stubs.reserved2;
                } else if (self.nonlazy_imports.get(sym_name)) |ext| {
                    const segment = self.load_commands.items[self.data_segment_cmd_index.?].Segment;
                    const got = segment.sections.items[self.got_section_index.?];
                    break :blk got.addr + ext.index * @sizeOf(u64);
                } else if (self.threadlocal_imports.get(sym_name)) |ext| {
                    const segment = self.load_commands.items[self.data_segment_cmd_index.?].Segment;
                    const tlv = segment.sections.items[self.tlv_section_index.?];
                    break :blk tlv.addr + ext.index * @sizeOf(u64);
                } else {
                    log.err("failed to resolve symbol '{s}' as a relocation target", .{sym_name});
                    return error.FailedToResolveRelocationTarget;
                }
            } else {
                log.err("unexpected symbol {}, {s}", .{ sym, object.getString(sym.n_strx) });
                return error.UnexpectedSymbolWhenRelocating;
            }
        } else {
            // TODO I think we need to reparse the relocation_info as scattered_relocation_info
            // here to get the actual section plus offset into that section of the relocated
            // symbol. Unless the fine-grained location is encoded within the cell in the code
            // buffer?
            const source_sectname = seg.sections.items[rel.r_symbolnum - 1];
            const target_space = next_space.get(.{
                .segname = source_sectname.segname,
                .sectname = source_sectname.sectname,
            }).?;
            break :blk target_space.address;
        }
    };
    return target_addr;
}

fn populateMetadata(self: *Zld) !void {
    if (self.pagezero_segment_cmd_index == null) {
        self.pagezero_segment_cmd_index = @intCast(u16, self.load_commands.items.len);
        try self.load_commands.append(self.allocator, .{
            .Segment = SegmentCommand.empty(.{
                .cmd = macho.LC_SEGMENT_64,
                .cmdsize = @sizeOf(macho.segment_command_64),
                .segname = makeStaticString("__PAGEZERO"),
                .vmaddr = 0,
                .vmsize = 0x100000000, // size always set to 4GB
                .fileoff = 0,
                .filesize = 0,
                .maxprot = 0,
                .initprot = 0,
                .nsects = 0,
                .flags = 0,
            }),
        });
        try self.addSegmentToDir(0);
    }

    if (self.text_segment_cmd_index == null) {
        self.text_segment_cmd_index = @intCast(u16, self.load_commands.items.len);
        try self.load_commands.append(self.allocator, .{
            .Segment = SegmentCommand.empty(.{
                .cmd = macho.LC_SEGMENT_64,
                .cmdsize = @sizeOf(macho.segment_command_64),
                .segname = makeStaticString("__TEXT"),
                .vmaddr = 0x100000000, // always starts at 4GB
                .vmsize = 0,
                .fileoff = 0,
                .filesize = 0,
                .maxprot = macho.VM_PROT_READ | macho.VM_PROT_EXECUTE,
                .initprot = macho.VM_PROT_READ | macho.VM_PROT_EXECUTE,
                .nsects = 0,
                .flags = 0,
            }),
        });
        try self.addSegmentToDir(self.text_segment_cmd_index.?);
    }

    if (self.text_section_index == null) {
        const text_seg = &self.load_commands.items[self.text_segment_cmd_index.?].Segment;
        self.text_section_index = @intCast(u16, text_seg.sections.items.len);
        const alignment: u2 = switch (self.arch.?) {
            .x86_64 => 0,
            .aarch64 => 2,
            else => unreachable, // unhandled architecture type
        };
        try text_seg.append(self.allocator, .{
            .sectname = makeStaticString("__text"),
            .segname = makeStaticString("__TEXT"),
            .addr = 0,
            .size = 0,
            .offset = 0,
            .@"align" = alignment,
            .reloff = 0,
            .nreloc = 0,
            .flags = macho.S_REGULAR | macho.S_ATTR_PURE_INSTRUCTIONS | macho.S_ATTR_SOME_INSTRUCTIONS,
            .reserved1 = 0,
            .reserved2 = 0,
            .reserved3 = 0,
        });
        try self.addSectionToDir(.{
            .seg_index = self.text_segment_cmd_index.?,
            .sect_index = self.text_section_index.?,
        });
    }

    if (self.stubs_section_index == null) {
        const text_seg = &self.load_commands.items[self.text_segment_cmd_index.?].Segment;
        self.stubs_section_index = @intCast(u16, text_seg.sections.items.len);
        const alignment: u2 = switch (self.arch.?) {
            .x86_64 => 0,
            .aarch64 => 2,
            else => unreachable, // unhandled architecture type
        };
        const stub_size: u4 = switch (self.arch.?) {
            .x86_64 => 6,
            .aarch64 => 2 * @sizeOf(u32),
            else => unreachable, // unhandled architecture type
        };
        try text_seg.append(self.allocator, .{
            .sectname = makeStaticString("__stubs"),
            .segname = makeStaticString("__TEXT"),
            .addr = 0,
            .size = 0,
            .offset = 0,
            .@"align" = alignment,
            .reloff = 0,
            .nreloc = 0,
            .flags = macho.S_SYMBOL_STUBS | macho.S_ATTR_PURE_INSTRUCTIONS | macho.S_ATTR_SOME_INSTRUCTIONS,
            .reserved1 = 0,
            .reserved2 = stub_size,
            .reserved3 = 0,
        });
        try self.addSectionToDir(.{
            .seg_index = self.text_segment_cmd_index.?,
            .sect_index = self.stubs_section_index.?,
        });
    }

    if (self.stub_helper_section_index == null) {
        const text_seg = &self.load_commands.items[self.text_segment_cmd_index.?].Segment;
        self.stub_helper_section_index = @intCast(u16, text_seg.sections.items.len);
        const alignment: u2 = switch (self.arch.?) {
            .x86_64 => 0,
            .aarch64 => 2,
            else => unreachable, // unhandled architecture type
        };
        const stub_helper_size: u5 = switch (self.arch.?) {
            .x86_64 => 15,
            .aarch64 => 6 * @sizeOf(u32),
            else => unreachable,
        };
        try text_seg.append(self.allocator, .{
            .sectname = makeStaticString("__stub_helper"),
            .segname = makeStaticString("__TEXT"),
            .addr = 0,
            .size = stub_helper_size,
            .offset = 0,
            .@"align" = alignment,
            .reloff = 0,
            .nreloc = 0,
            .flags = macho.S_REGULAR | macho.S_ATTR_PURE_INSTRUCTIONS | macho.S_ATTR_SOME_INSTRUCTIONS,
            .reserved1 = 0,
            .reserved2 = 0,
            .reserved3 = 0,
        });
        try self.addSectionToDir(.{
            .seg_index = self.text_segment_cmd_index.?,
            .sect_index = self.stub_helper_section_index.?,
        });
    }

    if (self.data_segment_cmd_index == null) {
        self.data_segment_cmd_index = @intCast(u16, self.load_commands.items.len);
        try self.load_commands.append(self.allocator, .{
            .Segment = SegmentCommand.empty(.{
                .cmd = macho.LC_SEGMENT_64,
                .cmdsize = @sizeOf(macho.segment_command_64),
                .segname = makeStaticString("__DATA"),
                .vmaddr = 0,
                .vmsize = 0,
                .fileoff = 0,
                .filesize = 0,
                .maxprot = macho.VM_PROT_READ | macho.VM_PROT_WRITE,
                .initprot = macho.VM_PROT_READ | macho.VM_PROT_WRITE,
                .nsects = 0,
                .flags = 0,
            }),
        });
        try self.addSegmentToDir(self.data_segment_cmd_index.?);
    }

    if (self.got_section_index == null) {
        const data_seg = &self.load_commands.items[self.data_segment_cmd_index.?].Segment;
        self.got_section_index = @intCast(u16, data_seg.sections.items.len);
        try data_seg.append(self.allocator, .{
            .sectname = makeStaticString("__got"),
            .segname = makeStaticString("__DATA"),
            .addr = 0,
            .size = 0,
            .offset = 0,
            .@"align" = 3, // 2^3 = @sizeOf(u64)
            .reloff = 0,
            .nreloc = 0,
            .flags = macho.S_NON_LAZY_SYMBOL_POINTERS,
            .reserved1 = 0,
            .reserved2 = 0,
            .reserved3 = 0,
        });
        try self.addSectionToDir(.{
            .seg_index = self.data_segment_cmd_index.?,
            .sect_index = self.got_section_index.?,
        });
    }

    if (self.la_symbol_ptr_section_index == null) {
        const data_seg = &self.load_commands.items[self.data_segment_cmd_index.?].Segment;
        self.la_symbol_ptr_section_index = @intCast(u16, data_seg.sections.items.len);
        try data_seg.append(self.allocator, .{
            .sectname = makeStaticString("__la_symbol_ptr"),
            .segname = makeStaticString("__DATA"),
            .addr = 0,
            .size = 0,
            .offset = 0,
            .@"align" = 3, // 2^3 = @sizeOf(u64)
            .reloff = 0,
            .nreloc = 0,
            .flags = macho.S_LAZY_SYMBOL_POINTERS,
            .reserved1 = 0,
            .reserved2 = 0,
            .reserved3 = 0,
        });
        try self.addSectionToDir(.{
            .seg_index = self.data_segment_cmd_index.?,
            .sect_index = self.la_symbol_ptr_section_index.?,
        });
    }

    if (self.data_section_index == null) {
        const data_seg = &self.load_commands.items[self.data_segment_cmd_index.?].Segment;
        self.data_section_index = @intCast(u16, data_seg.sections.items.len);
        try data_seg.append(self.allocator, .{
            .sectname = makeStaticString("__data"),
            .segname = makeStaticString("__DATA"),
            .addr = 0,
            .size = 0,
            .offset = 0,
            .@"align" = 3, // 2^3 = @sizeOf(u64)
            .reloff = 0,
            .nreloc = 0,
            .flags = macho.S_REGULAR,
            .reserved1 = 0,
            .reserved2 = 0,
            .reserved3 = 0,
        });
        try self.addSectionToDir(.{
            .seg_index = self.data_segment_cmd_index.?,
            .sect_index = self.data_section_index.?,
        });
    }

    if (self.linkedit_segment_cmd_index == null) {
        self.linkedit_segment_cmd_index = @intCast(u16, self.load_commands.items.len);
        try self.load_commands.append(self.allocator, .{
            .Segment = SegmentCommand.empty(.{
                .cmd = macho.LC_SEGMENT_64,
                .cmdsize = @sizeOf(macho.segment_command_64),
                .segname = makeStaticString("__LINKEDIT"),
                .vmaddr = 0,
                .vmsize = 0,
                .fileoff = 0,
                .filesize = 0,
                .maxprot = macho.VM_PROT_READ,
                .initprot = macho.VM_PROT_READ,
                .nsects = 0,
                .flags = 0,
            }),
        });
        try self.addSegmentToDir(self.linkedit_segment_cmd_index.?);
    }

    if (self.dyld_info_cmd_index == null) {
        self.dyld_info_cmd_index = @intCast(u16, self.load_commands.items.len);
        try self.load_commands.append(self.allocator, .{
            .DyldInfoOnly = .{
                .cmd = macho.LC_DYLD_INFO_ONLY,
                .cmdsize = @sizeOf(macho.dyld_info_command),
                .rebase_off = 0,
                .rebase_size = 0,
                .bind_off = 0,
                .bind_size = 0,
                .weak_bind_off = 0,
                .weak_bind_size = 0,
                .lazy_bind_off = 0,
                .lazy_bind_size = 0,
                .export_off = 0,
                .export_size = 0,
            },
        });
    }

    if (self.symtab_cmd_index == null) {
        self.symtab_cmd_index = @intCast(u16, self.load_commands.items.len);
        try self.load_commands.append(self.allocator, .{
            .Symtab = .{
                .cmd = macho.LC_SYMTAB,
                .cmdsize = @sizeOf(macho.symtab_command),
                .symoff = 0,
                .nsyms = 0,
                .stroff = 0,
                .strsize = 0,
            },
        });
        try self.strtab.append(self.allocator, 0);
    }

    if (self.dysymtab_cmd_index == null) {
        self.dysymtab_cmd_index = @intCast(u16, self.load_commands.items.len);
        try self.load_commands.append(self.allocator, .{
            .Dysymtab = .{
                .cmd = macho.LC_DYSYMTAB,
                .cmdsize = @sizeOf(macho.dysymtab_command),
                .ilocalsym = 0,
                .nlocalsym = 0,
                .iextdefsym = 0,
                .nextdefsym = 0,
                .iundefsym = 0,
                .nundefsym = 0,
                .tocoff = 0,
                .ntoc = 0,
                .modtaboff = 0,
                .nmodtab = 0,
                .extrefsymoff = 0,
                .nextrefsyms = 0,
                .indirectsymoff = 0,
                .nindirectsyms = 0,
                .extreloff = 0,
                .nextrel = 0,
                .locreloff = 0,
                .nlocrel = 0,
            },
        });
    }

    if (self.dylinker_cmd_index == null) {
        self.dylinker_cmd_index = @intCast(u16, self.load_commands.items.len);
        const cmdsize = @intCast(u32, mem.alignForwardGeneric(
            u64,
            @sizeOf(macho.dylinker_command) + mem.lenZ(DEFAULT_DYLD_PATH),
            @sizeOf(u64),
        ));
        var dylinker_cmd = emptyGenericCommandWithData(macho.dylinker_command{
            .cmd = macho.LC_LOAD_DYLINKER,
            .cmdsize = cmdsize,
            .name = @sizeOf(macho.dylinker_command),
        });
        dylinker_cmd.data = try self.allocator.alloc(u8, cmdsize - dylinker_cmd.inner.name);
        mem.set(u8, dylinker_cmd.data, 0);
        mem.copy(u8, dylinker_cmd.data, mem.spanZ(DEFAULT_DYLD_PATH));
        try self.load_commands.append(self.allocator, .{ .Dylinker = dylinker_cmd });
    }

    if (self.libsystem_cmd_index == null) {
        self.libsystem_cmd_index = @intCast(u16, self.load_commands.items.len);
        const cmdsize = @intCast(u32, mem.alignForwardGeneric(
            u64,
            @sizeOf(macho.dylib_command) + mem.lenZ(LIB_SYSTEM_PATH),
            @sizeOf(u64),
        ));
        // TODO Find a way to work out runtime version from the OS version triple stored in std.Target.
        // In the meantime, we're gonna hardcode to the minimum compatibility version of 0.0.0.
        const min_version = 0x0;
        var dylib_cmd = emptyGenericCommandWithData(macho.dylib_command{
            .cmd = macho.LC_LOAD_DYLIB,
            .cmdsize = cmdsize,
            .dylib = .{
                .name = @sizeOf(macho.dylib_command),
                .timestamp = 2, // not sure why not simply 0; this is reverse engineered from Mach-O files
                .current_version = min_version,
                .compatibility_version = min_version,
            },
        });
        dylib_cmd.data = try self.allocator.alloc(u8, cmdsize - dylib_cmd.inner.dylib.name);
        mem.set(u8, dylib_cmd.data, 0);
        mem.copy(u8, dylib_cmd.data, mem.spanZ(LIB_SYSTEM_PATH));
        try self.load_commands.append(self.allocator, .{ .Dylib = dylib_cmd });
    }

    if (self.main_cmd_index == null) {
        self.main_cmd_index = @intCast(u16, self.load_commands.items.len);
        try self.load_commands.append(self.allocator, .{
            .Main = .{
                .cmd = macho.LC_MAIN,
                .cmdsize = @sizeOf(macho.entry_point_command),
                .entryoff = 0x0,
                .stacksize = 0,
            },
        });
    }

    if (self.source_version_cmd_index == null) {
        self.source_version_cmd_index = @intCast(u16, self.load_commands.items.len);
        try self.load_commands.append(self.allocator, .{
            .SourceVersion = .{
                .cmd = macho.LC_SOURCE_VERSION,
                .cmdsize = @sizeOf(macho.source_version_command),
                .version = 0x0,
            },
        });
    }

    if (self.uuid_cmd_index == null) {
        self.uuid_cmd_index = @intCast(u16, self.load_commands.items.len);
        var uuid_cmd: macho.uuid_command = .{
            .cmd = macho.LC_UUID,
            .cmdsize = @sizeOf(macho.uuid_command),
            .uuid = undefined,
        };
        std.crypto.random.bytes(&uuid_cmd.uuid);
        try self.load_commands.append(self.allocator, .{ .Uuid = uuid_cmd });
    }

    if (self.code_signature_cmd_index == null and self.arch.? == .aarch64) {
        self.code_signature_cmd_index = @intCast(u16, self.load_commands.items.len);
        try self.load_commands.append(self.allocator, .{
            .LinkeditData = .{
                .cmd = macho.LC_CODE_SIGNATURE,
                .cmdsize = @sizeOf(macho.linkedit_data_command),
                .dataoff = 0,
                .datasize = 0,
            },
        });
    }
}

fn flush(self: *Zld) !void {
    {
        const seg = &self.load_commands.items[self.data_segment_cmd_index.?].Segment;
        for (seg.sections.items) |*sect| {
            const sectname = parseName(&sect.sectname);
            if (mem.eql(u8, sectname, "__bss") or mem.eql(u8, sectname, "__thread_bss")) {
                sect.offset = 0;
            }
        }
    }
    {
        const seg = &self.load_commands.items[self.text_segment_cmd_index.?].Segment;
        for (seg.sections.items) |*sect| {
            if (mem.eql(u8, parseName(&sect.sectname), "__eh_frame")) {
                sect.flags = 0;
            }
        }
    }
    try self.setEntryPoint();
    try self.writeRebaseInfoTable();
    try self.writeBindInfoTable();
    try self.writeLazyBindInfoTable();
    try self.writeExportInfo();

    {
        const seg = &self.load_commands.items[self.linkedit_segment_cmd_index.?].Segment;
        const symtab = &self.load_commands.items[self.symtab_cmd_index.?].Symtab;
        symtab.symoff = @intCast(u32, seg.inner.fileoff + seg.inner.filesize);
    }

    try self.writeDebugInfo();
    try self.writeSymbolTable();
    try self.writeDynamicSymbolTable();
    try self.writeStringTable();

    {
        // Seal __LINKEDIT size
        const seg = &self.load_commands.items[self.linkedit_segment_cmd_index.?].Segment;
        seg.inner.vmsize = mem.alignForwardGeneric(u64, seg.inner.filesize, self.page_size.?);
    }

    if (self.arch.? == .aarch64) {
        try self.writeCodeSignaturePadding();
    }

    try self.writeLoadCommands();
    try self.writeHeader();

    if (self.arch.? == .aarch64) {
        try self.writeCodeSignature();
    }

    if (comptime std.Target.current.isDarwin() and std.Target.current.cpu.arch == .aarch64) {
        try fs.cwd().copyFile(self.out_path.?, fs.cwd(), self.out_path.?, .{});
    }
}

fn setEntryPoint(self: *Zld) !void {
    // TODO we should respect the -entry flag passed in by the user to set a custom
    // entrypoint. For now, assume default of `_main`.
    const seg = self.load_commands.items[self.text_segment_cmd_index.?].Segment;
    const text = seg.sections.items[self.text_section_index.?];
    const entry_sym = self.locals.get("_main") orelse return error.MissingMainEntrypoint;

    const name = try self.allocator.dupe(u8, "_main");
    try self.exports.putNoClobber(self.allocator, name, .{
        .n_strx = entry_sym.n_strx,
        .n_value = entry_sym.n_value,
        .n_type = macho.N_SECT | macho.N_EXT,
        .n_desc = entry_sym.n_desc,
        .n_sect = entry_sym.n_sect,
    });

    const ec = &self.load_commands.items[self.main_cmd_index.?].Main;
    ec.entryoff = @intCast(u32, entry_sym.n_value - seg.inner.vmaddr);
}

fn writeRebaseInfoTable(self: *Zld) !void {
    const data_seg = self.load_commands.items[self.data_segment_cmd_index.?].Segment;

    var pointers = std.ArrayList(Pointer).init(self.allocator);
    defer pointers.deinit();
    try pointers.ensureCapacity(self.lazy_imports.items().len);

    if (self.la_symbol_ptr_section_index) |idx| {
        const sect = data_seg.sections.items[idx];
        const base_offset = sect.addr - data_seg.inner.vmaddr;
        const segment_id = @intCast(u16, self.data_segment_cmd_index.?);
        for (self.lazy_imports.items()) |entry| {
            pointers.appendAssumeCapacity(.{
                .offset = base_offset + entry.value.index * @sizeOf(u64),
                .segment_id = segment_id,
            });
        }
    }

    try pointers.ensureCapacity(pointers.items.len + self.local_rebases.items.len);

    const nlocals = self.local_rebases.items.len;
    var i = nlocals;
    while (i > 0) : (i -= 1) {
        pointers.appendAssumeCapacity(self.local_rebases.items[i - 1]);
    }

    const size = try rebaseInfoSize(pointers.items);
    var buffer = try self.allocator.alloc(u8, @intCast(usize, size));
    defer self.allocator.free(buffer);

    var stream = std.io.fixedBufferStream(buffer);
    try writeRebaseInfo(pointers.items, stream.writer());

    const seg = &self.load_commands.items[self.linkedit_segment_cmd_index.?].Segment;
    const dyld_info = &self.load_commands.items[self.dyld_info_cmd_index.?].DyldInfoOnly;
    dyld_info.rebase_off = @intCast(u32, seg.inner.fileoff);
    dyld_info.rebase_size = @intCast(u32, mem.alignForwardGeneric(u64, buffer.len, @sizeOf(u64)));
    seg.inner.filesize += dyld_info.rebase_size;

    log.debug("writing rebase info from 0x{x} to 0x{x}", .{ dyld_info.rebase_off, dyld_info.rebase_off + dyld_info.rebase_size });

    try self.file.?.pwriteAll(buffer, dyld_info.rebase_off);
}

fn writeBindInfoTable(self: *Zld) !void {
    const data_seg = self.load_commands.items[self.data_segment_cmd_index.?].Segment;

    var pointers = std.ArrayList(Pointer).init(self.allocator);
    defer pointers.deinit();
    try pointers.ensureCapacity(self.nonlazy_imports.items().len + self.threadlocal_imports.items().len);

    if (self.got_section_index) |idx| {
        const sect = data_seg.sections.items[idx];
        const base_offset = sect.addr - data_seg.inner.vmaddr;
        const segment_id = @intCast(u16, self.data_segment_cmd_index.?);
        for (self.nonlazy_imports.items()) |entry| {
            pointers.appendAssumeCapacity(.{
                .offset = base_offset + entry.value.index * @sizeOf(u64),
                .segment_id = segment_id,
                .dylib_ordinal = entry.value.dylib_ordinal,
                .name = entry.key,
            });
        }
    }

    if (self.tlv_section_index) |idx| {
        const sect = data_seg.sections.items[idx];
        const base_offset = sect.addr - data_seg.inner.vmaddr;
        const segment_id = @intCast(u16, self.data_segment_cmd_index.?);
        for (self.threadlocal_imports.items()) |entry| {
            pointers.appendAssumeCapacity(.{
                .offset = base_offset + entry.value.index * @sizeOf(u64),
                .segment_id = segment_id,
                .dylib_ordinal = entry.value.dylib_ordinal,
                .name = entry.key,
            });
        }
    }

    const size = try bindInfoSize(pointers.items);
    var buffer = try self.allocator.alloc(u8, @intCast(usize, size));
    defer self.allocator.free(buffer);

    var stream = std.io.fixedBufferStream(buffer);
    try writeBindInfo(pointers.items, stream.writer());

    const seg = &self.load_commands.items[self.linkedit_segment_cmd_index.?].Segment;
    const dyld_info = &self.load_commands.items[self.dyld_info_cmd_index.?].DyldInfoOnly;
    dyld_info.bind_off = @intCast(u32, seg.inner.fileoff + seg.inner.filesize);
    dyld_info.bind_size = @intCast(u32, mem.alignForwardGeneric(u64, buffer.len, @alignOf(u64)));
    seg.inner.filesize += dyld_info.bind_size;

    log.debug("writing binding info from 0x{x} to 0x{x}", .{ dyld_info.bind_off, dyld_info.bind_off + dyld_info.bind_size });

    try self.file.?.pwriteAll(buffer, dyld_info.bind_off);
}

fn writeLazyBindInfoTable(self: *Zld) !void {
    const data_seg = self.load_commands.items[self.data_segment_cmd_index.?].Segment;

    var pointers = std.ArrayList(Pointer).init(self.allocator);
    defer pointers.deinit();
    try pointers.ensureCapacity(self.lazy_imports.items().len);

    if (self.la_symbol_ptr_section_index) |idx| {
        const sect = data_seg.sections.items[idx];
        const base_offset = sect.addr - data_seg.inner.vmaddr;
        const segment_id = @intCast(u16, self.data_segment_cmd_index.?);
        for (self.lazy_imports.items()) |entry| {
            pointers.appendAssumeCapacity(.{
                .offset = base_offset + entry.value.index * @sizeOf(u64),
                .segment_id = segment_id,
                .dylib_ordinal = entry.value.dylib_ordinal,
                .name = entry.key,
            });
        }
    }

    const size = try lazyBindInfoSize(pointers.items);
    var buffer = try self.allocator.alloc(u8, @intCast(usize, size));
    defer self.allocator.free(buffer);

    var stream = std.io.fixedBufferStream(buffer);
    try writeLazyBindInfo(pointers.items, stream.writer());

    const seg = &self.load_commands.items[self.linkedit_segment_cmd_index.?].Segment;
    const dyld_info = &self.load_commands.items[self.dyld_info_cmd_index.?].DyldInfoOnly;
    dyld_info.lazy_bind_off = @intCast(u32, seg.inner.fileoff + seg.inner.filesize);
    dyld_info.lazy_bind_size = @intCast(u32, mem.alignForwardGeneric(u64, buffer.len, @alignOf(u64)));
    seg.inner.filesize += dyld_info.lazy_bind_size;

    log.debug("writing lazy binding info from 0x{x} to 0x{x}", .{ dyld_info.lazy_bind_off, dyld_info.lazy_bind_off + dyld_info.lazy_bind_size });

    try self.file.?.pwriteAll(buffer, dyld_info.lazy_bind_off);
    try self.populateLazyBindOffsetsInStubHelper(buffer);
}

fn populateLazyBindOffsetsInStubHelper(self: *Zld, buffer: []const u8) !void {
    var stream = std.io.fixedBufferStream(buffer);
    var reader = stream.reader();
    var offsets = std.ArrayList(u32).init(self.allocator);
    try offsets.append(0);
    defer offsets.deinit();
    var valid_block = false;

    while (true) {
        const inst = reader.readByte() catch |err| switch (err) {
            error.EndOfStream => break,
            else => return err,
        };
        const imm: u8 = inst & macho.BIND_IMMEDIATE_MASK;
        const opcode: u8 = inst & macho.BIND_OPCODE_MASK;

        switch (opcode) {
            macho.BIND_OPCODE_DO_BIND => {
                valid_block = true;
            },
            macho.BIND_OPCODE_DONE => {
                if (valid_block) {
                    const offset = try stream.getPos();
                    try offsets.append(@intCast(u32, offset));
                }
                valid_block = false;
            },
            macho.BIND_OPCODE_SET_SYMBOL_TRAILING_FLAGS_IMM => {
                var next = try reader.readByte();
                while (next != @as(u8, 0)) {
                    next = try reader.readByte();
                }
            },
            macho.BIND_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB => {
                _ = try leb.readULEB128(u64, reader);
            },
            macho.BIND_OPCODE_SET_DYLIB_ORDINAL_ULEB => {
                _ = try leb.readULEB128(u64, reader);
            },
            macho.BIND_OPCODE_SET_ADDEND_SLEB => {
                _ = try leb.readILEB128(i64, reader);
            },
            else => {},
        }
    }
    assert(self.lazy_imports.items().len <= offsets.items.len);

    const stub_size: u4 = switch (self.arch.?) {
        .x86_64 => 10,
        .aarch64 => 3 * @sizeOf(u32),
        else => unreachable,
    };
    const off: u4 = switch (self.arch.?) {
        .x86_64 => 1,
        .aarch64 => 2 * @sizeOf(u32),
        else => unreachable,
    };
    var buf: [@sizeOf(u32)]u8 = undefined;
    for (self.lazy_imports.items()) |entry| {
        const symbol = entry.value;
        const placeholder_off = self.stub_helper_stubs_start_off.? + symbol.index * stub_size + off;
        mem.writeIntLittle(u32, &buf, offsets.items[symbol.index]);
        try self.file.?.pwriteAll(&buf, placeholder_off);
    }
}

fn writeExportInfo(self: *Zld) !void {
    var trie = Trie.init(self.allocator);
    defer trie.deinit();

    const text_segment = self.load_commands.items[self.text_segment_cmd_index.?].Segment;
    for (self.exports.items()) |entry| {
        const name = entry.key;
        const symbol = entry.value;
        // TODO figure out if we should put all exports into the export trie
        assert(symbol.n_value >= text_segment.inner.vmaddr);
        try trie.put(.{
            .name = name,
            .vmaddr_offset = symbol.n_value - text_segment.inner.vmaddr,
            .export_flags = macho.EXPORT_SYMBOL_FLAGS_KIND_REGULAR,
        });
    }

    try trie.finalize();
    var buffer = try self.allocator.alloc(u8, @intCast(usize, trie.size));
    defer self.allocator.free(buffer);
    var stream = std.io.fixedBufferStream(buffer);
    const nwritten = try trie.write(stream.writer());
    assert(nwritten == trie.size);

    const seg = &self.load_commands.items[self.linkedit_segment_cmd_index.?].Segment;
    const dyld_info = &self.load_commands.items[self.dyld_info_cmd_index.?].DyldInfoOnly;
    dyld_info.export_off = @intCast(u32, seg.inner.fileoff + seg.inner.filesize);
    dyld_info.export_size = @intCast(u32, mem.alignForwardGeneric(u64, buffer.len, @alignOf(u64)));
    seg.inner.filesize += dyld_info.export_size;

    log.debug("writing export info from 0x{x} to 0x{x}", .{ dyld_info.export_off, dyld_info.export_off + dyld_info.export_size });

    try self.file.?.pwriteAll(buffer, dyld_info.export_off);
}

fn writeDebugInfo(self: *Zld) !void {
    var stabs = std.ArrayList(macho.nlist_64).init(self.allocator);
    defer stabs.deinit();

    for (self.objects.items) |object| {
        var debug_info = blk: {
            var di = try DebugInfo.parseFromObject(self.allocator, object);
            break :blk di orelse continue;
        };
        defer debug_info.deinit(self.allocator);

        const compile_unit = try debug_info.inner.findCompileUnit(0x0); // We assume there is only one CU.
        const name = try compile_unit.die.getAttrString(&debug_info.inner, dwarf.AT_name);
        const comp_dir = try compile_unit.die.getAttrString(&debug_info.inner, dwarf.AT_comp_dir);

        {
            const tu_path = try std.fs.path.join(self.allocator, &[_][]const u8{ comp_dir, name });
            defer self.allocator.free(tu_path);
            const dirname = std.fs.path.dirname(tu_path) orelse "./";
            // Current dir
            try stabs.append(.{
                .n_strx = try self.makeString(tu_path[0 .. dirname.len + 1]),
                .n_type = macho.N_SO,
                .n_sect = 0,
                .n_desc = 0,
                .n_value = 0,
            });
            // Artifact name
            try stabs.append(.{
                .n_strx = try self.makeString(tu_path[dirname.len + 1 ..]),
                .n_type = macho.N_SO,
                .n_sect = 0,
                .n_desc = 0,
                .n_value = 0,
            });
            // Path to object file with debug info
            var buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
            const path = object.name;
            const full_path = try std.os.realpath(path, &buffer);
            const stat = try object.file.stat();
            const mtime = @intCast(u64, @divFloor(stat.mtime, 1_000_000_000));
            try stabs.append(.{
                .n_strx = try self.makeString(full_path),
                .n_type = macho.N_OSO,
                .n_sect = 0,
                .n_desc = 1,
                .n_value = mtime,
            });
        }

        for (object.symtab.items) |source_sym| {
            const symname = object.getString(source_sym.n_strx);
            const source_addr = source_sym.n_value;
            const target_sym = self.locals.get(symname) orelse continue;

            const maybe_size = blk: for (debug_info.inner.func_list.items) |func| {
                if (func.pc_range) |range| {
                    if (source_addr >= range.start and source_addr < range.end) {
                        break :blk range.end - range.start;
                    }
                }
            } else null;

            if (maybe_size) |size| {
                try stabs.append(.{
                    .n_strx = 0,
                    .n_type = macho.N_BNSYM,
                    .n_sect = target_sym.n_sect,
                    .n_desc = 0,
                    .n_value = target_sym.n_value,
                });
                try stabs.append(.{
                    .n_strx = target_sym.n_strx,
                    .n_type = macho.N_FUN,
                    .n_sect = target_sym.n_sect,
                    .n_desc = 0,
                    .n_value = target_sym.n_value,
                });
                try stabs.append(.{
                    .n_strx = 0,
                    .n_type = macho.N_FUN,
                    .n_sect = 0,
                    .n_desc = 0,
                    .n_value = size,
                });
                try stabs.append(.{
                    .n_strx = 0,
                    .n_type = macho.N_ENSYM,
                    .n_sect = target_sym.n_sect,
                    .n_desc = 0,
                    .n_value = size,
                });
            } else {
                // TODO need a way to differentiate symbols: global, static, local, etc.
                try stabs.append(.{
                    .n_strx = target_sym.n_strx,
                    .n_type = macho.N_STSYM,
                    .n_sect = target_sym.n_sect,
                    .n_desc = 0,
                    .n_value = target_sym.n_value,
                });
            }
        }

        // Close the source file!
        try stabs.append(.{
            .n_strx = 0,
            .n_type = macho.N_SO,
            .n_sect = 0,
            .n_desc = 0,
            .n_value = 0,
        });
    }

    if (stabs.items.len == 0) return;

    // Write stabs into the symbol table
    const linkedit = &self.load_commands.items[self.linkedit_segment_cmd_index.?].Segment;
    const symtab = &self.load_commands.items[self.symtab_cmd_index.?].Symtab;

    symtab.nsyms = @intCast(u32, stabs.items.len);

    const stabs_off = symtab.symoff;
    const stabs_size = symtab.nsyms * @sizeOf(macho.nlist_64);
    log.debug("writing symbol stabs from 0x{x} to 0x{x}", .{ stabs_off, stabs_size + stabs_off });
    try self.file.?.pwriteAll(mem.sliceAsBytes(stabs.items), stabs_off);

    linkedit.inner.filesize += stabs_size;

    // Update dynamic symbol table.
    const dysymtab = &self.load_commands.items[self.dysymtab_cmd_index.?].Dysymtab;
    dysymtab.nlocalsym = symtab.nsyms;
}

fn writeSymbolTable(self: *Zld) !void {
    const seg = &self.load_commands.items[self.linkedit_segment_cmd_index.?].Segment;
    const symtab = &self.load_commands.items[self.symtab_cmd_index.?].Symtab;

    const nlocals = self.locals.items().len;
    var locals = std.ArrayList(macho.nlist_64).init(self.allocator);
    defer locals.deinit();

    try locals.ensureCapacity(nlocals);
    for (self.locals.items()) |entry| {
        locals.appendAssumeCapacity(entry.value);
    }

    const nexports = self.exports.items().len;
    var exports = std.ArrayList(macho.nlist_64).init(self.allocator);
    defer exports.deinit();

    try exports.ensureCapacity(nexports);
    for (self.exports.items()) |entry| {
        exports.appendAssumeCapacity(entry.value);
    }

    const nundefs = self.lazy_imports.items().len + self.nonlazy_imports.items().len + self.threadlocal_imports.items().len;
    var undefs = std.ArrayList(macho.nlist_64).init(self.allocator);
    defer undefs.deinit();

    try undefs.ensureCapacity(nundefs);
    for (self.lazy_imports.items()) |entry| {
        undefs.appendAssumeCapacity(entry.value.symbol);
    }
    for (self.nonlazy_imports.items()) |entry| {
        undefs.appendAssumeCapacity(entry.value.symbol);
    }
    for (self.threadlocal_imports.items()) |entry| {
        undefs.appendAssumeCapacity(entry.value.symbol);
    }

    const locals_off = symtab.symoff + symtab.nsyms * @sizeOf(macho.nlist_64);
    const locals_size = nlocals * @sizeOf(macho.nlist_64);
    log.debug("writing local symbols from 0x{x} to 0x{x}", .{ locals_off, locals_size + locals_off });
    try self.file.?.pwriteAll(mem.sliceAsBytes(locals.items), locals_off);

    const exports_off = locals_off + locals_size;
    const exports_size = nexports * @sizeOf(macho.nlist_64);
    log.debug("writing exported symbols from 0x{x} to 0x{x}", .{ exports_off, exports_size + exports_off });
    try self.file.?.pwriteAll(mem.sliceAsBytes(exports.items), exports_off);

    const undefs_off = exports_off + exports_size;
    const undefs_size = nundefs * @sizeOf(macho.nlist_64);
    log.debug("writing undefined symbols from 0x{x} to 0x{x}", .{ undefs_off, undefs_size + undefs_off });
    try self.file.?.pwriteAll(mem.sliceAsBytes(undefs.items), undefs_off);

    symtab.nsyms += @intCast(u32, nlocals + nexports + nundefs);
    seg.inner.filesize += locals_size + exports_size + undefs_size;

    // Update dynamic symbol table.
    const dysymtab = &self.load_commands.items[self.dysymtab_cmd_index.?].Dysymtab;
    dysymtab.nlocalsym += @intCast(u32, nlocals);
    dysymtab.iextdefsym = dysymtab.nlocalsym;
    dysymtab.nextdefsym = @intCast(u32, nexports);
    dysymtab.iundefsym = dysymtab.nlocalsym + dysymtab.nextdefsym;
    dysymtab.nundefsym = @intCast(u32, nundefs);
}

fn writeDynamicSymbolTable(self: *Zld) !void {
    const seg = &self.load_commands.items[self.linkedit_segment_cmd_index.?].Segment;
    const text_segment = &self.load_commands.items[self.text_segment_cmd_index.?].Segment;
    const stubs = &text_segment.sections.items[self.stubs_section_index.?];
    const data_segment = &self.load_commands.items[self.data_segment_cmd_index.?].Segment;
    const got = &data_segment.sections.items[self.got_section_index.?];
    const la_symbol_ptr = &data_segment.sections.items[self.la_symbol_ptr_section_index.?];
    const dysymtab = &self.load_commands.items[self.dysymtab_cmd_index.?].Dysymtab;

    const lazy = self.lazy_imports.items();
    const nonlazy = self.nonlazy_imports.items();
    dysymtab.indirectsymoff = @intCast(u32, seg.inner.fileoff + seg.inner.filesize);
    dysymtab.nindirectsyms = @intCast(u32, lazy.len * 2 + nonlazy.len);
    const needed_size = dysymtab.nindirectsyms * @sizeOf(u32);
    seg.inner.filesize += needed_size;

    log.debug("writing indirect symbol table from 0x{x} to 0x{x}", .{
        dysymtab.indirectsymoff,
        dysymtab.indirectsymoff + needed_size,
    });

    var buf = try self.allocator.alloc(u8, needed_size);
    defer self.allocator.free(buf);
    var stream = std.io.fixedBufferStream(buf);
    var writer = stream.writer();

    stubs.reserved1 = 0;
    for (self.lazy_imports.items()) |_, i| {
        const symtab_idx = @intCast(u32, dysymtab.iundefsym + i);
        try writer.writeIntLittle(u32, symtab_idx);
    }

    const base_id = @intCast(u32, lazy.len);
    got.reserved1 = base_id;
    for (self.nonlazy_imports.items()) |_, i| {
        const symtab_idx = @intCast(u32, dysymtab.iundefsym + i + base_id);
        try writer.writeIntLittle(u32, symtab_idx);
    }

    la_symbol_ptr.reserved1 = got.reserved1 + @intCast(u32, nonlazy.len);
    for (self.lazy_imports.items()) |_, i| {
        const symtab_idx = @intCast(u32, dysymtab.iundefsym + i);
        try writer.writeIntLittle(u32, symtab_idx);
    }

    try self.file.?.pwriteAll(buf, dysymtab.indirectsymoff);
}

fn writeStringTable(self: *Zld) !void {
    const seg = &self.load_commands.items[self.linkedit_segment_cmd_index.?].Segment;
    const symtab = &self.load_commands.items[self.symtab_cmd_index.?].Symtab;
    symtab.stroff = @intCast(u32, seg.inner.fileoff + seg.inner.filesize);
    symtab.strsize = @intCast(u32, mem.alignForwardGeneric(u64, self.strtab.items.len, @alignOf(u64)));
    seg.inner.filesize += symtab.strsize;

    log.debug("writing string table from 0x{x} to 0x{x}", .{ symtab.stroff, symtab.stroff + symtab.strsize });

    try self.file.?.pwriteAll(self.strtab.items, symtab.stroff);

    if (symtab.strsize > self.strtab.items.len and self.arch.? == .x86_64) {
        // This is the last section, so we need to pad it out.
        try self.file.?.pwriteAll(&[_]u8{0}, seg.inner.fileoff + seg.inner.filesize - 1);
    }
}

fn writeCodeSignaturePadding(self: *Zld) !void {
    const seg = &self.load_commands.items[self.linkedit_segment_cmd_index.?].Segment;
    const code_sig_cmd = &self.load_commands.items[self.code_signature_cmd_index.?].LinkeditData;
    const fileoff = seg.inner.fileoff + seg.inner.filesize;
    const needed_size = CodeSignature.calcCodeSignaturePaddingSize(
        self.out_path.?,
        fileoff,
        self.page_size.?,
    );
    code_sig_cmd.dataoff = @intCast(u32, fileoff);
    code_sig_cmd.datasize = needed_size;

    // Advance size of __LINKEDIT segment
    seg.inner.filesize += needed_size;
    seg.inner.vmsize = mem.alignForwardGeneric(u64, seg.inner.filesize, self.page_size.?);

    log.debug("writing code signature padding from 0x{x} to 0x{x}", .{ fileoff, fileoff + needed_size });

    // Pad out the space. We need to do this to calculate valid hashes for everything in the file
    // except for code signature data.
    try self.file.?.pwriteAll(&[_]u8{0}, fileoff + needed_size - 1);
}

fn writeCodeSignature(self: *Zld) !void {
    const text_seg = self.load_commands.items[self.text_segment_cmd_index.?].Segment;
    const code_sig_cmd = self.load_commands.items[self.code_signature_cmd_index.?].LinkeditData;

    var code_sig = CodeSignature.init(self.allocator, self.page_size.?);
    defer code_sig.deinit();
    try code_sig.calcAdhocSignature(
        self.file.?,
        self.out_path.?,
        text_seg.inner,
        code_sig_cmd,
        .Exe,
    );

    var buffer = try self.allocator.alloc(u8, code_sig.size());
    defer self.allocator.free(buffer);
    var stream = std.io.fixedBufferStream(buffer);
    try code_sig.write(stream.writer());

    log.debug("writing code signature from 0x{x} to 0x{x}", .{ code_sig_cmd.dataoff, code_sig_cmd.dataoff + buffer.len });

    try self.file.?.pwriteAll(buffer, code_sig_cmd.dataoff);
}

fn writeLoadCommands(self: *Zld) !void {
    var sizeofcmds: u32 = 0;
    for (self.load_commands.items) |lc| {
        sizeofcmds += lc.cmdsize();
    }

    var buffer = try self.allocator.alloc(u8, sizeofcmds);
    defer self.allocator.free(buffer);
    var writer = std.io.fixedBufferStream(buffer).writer();
    for (self.load_commands.items) |lc| {
        try lc.write(writer);
    }

    const off = @sizeOf(macho.mach_header_64);
    log.debug("writing {} load commands from 0x{x} to 0x{x}", .{ self.load_commands.items.len, off, off + sizeofcmds });
    try self.file.?.pwriteAll(buffer, off);
}

fn writeHeader(self: *Zld) !void {
    var header: macho.mach_header_64 = undefined;
    header.magic = macho.MH_MAGIC_64;

    const CpuInfo = struct {
        cpu_type: macho.cpu_type_t,
        cpu_subtype: macho.cpu_subtype_t,
    };

    const cpu_info: CpuInfo = switch (self.arch.?) {
        .aarch64 => .{
            .cpu_type = macho.CPU_TYPE_ARM64,
            .cpu_subtype = macho.CPU_SUBTYPE_ARM_ALL,
        },
        .x86_64 => .{
            .cpu_type = macho.CPU_TYPE_X86_64,
            .cpu_subtype = macho.CPU_SUBTYPE_X86_64_ALL,
        },
        else => return error.UnsupportedCpuArchitecture,
    };
    header.cputype = cpu_info.cpu_type;
    header.cpusubtype = cpu_info.cpu_subtype;
    header.filetype = macho.MH_EXECUTE;
    header.flags = macho.MH_NOUNDEFS | macho.MH_DYLDLINK | macho.MH_PIE | macho.MH_TWOLEVEL;
    header.reserved = 0;

    if (self.tlv_section_index) |_|
        header.flags |= macho.MH_HAS_TLV_DESCRIPTORS;

    header.ncmds = @intCast(u32, self.load_commands.items.len);
    header.sizeofcmds = 0;
    for (self.load_commands.items) |cmd| {
        header.sizeofcmds += cmd.cmdsize();
    }
    log.debug("writing Mach-O header {}", .{header});
    try self.file.?.pwriteAll(mem.asBytes(&header), 0);
}

pub fn makeStaticString(bytes: []const u8) [16]u8 {
    var buf = [_]u8{0} ** 16;
    assert(bytes.len <= buf.len);
    mem.copy(u8, &buf, bytes);
    return buf;
}

fn makeString(self: *Zld, bytes: []const u8) !u32 {
    try self.strtab.ensureCapacity(self.allocator, self.strtab.items.len + bytes.len + 1);
    const offset = @intCast(u32, self.strtab.items.len);
    log.debug("writing new string '{s}' into string table at offset 0x{x}", .{ bytes, offset });
    self.strtab.appendSliceAssumeCapacity(bytes);
    self.strtab.appendAssumeCapacity(0);
    return offset;
}

fn getString(self: *const Zld, str_off: u32) []const u8 {
    assert(str_off < self.strtab.items.len);
    return mem.spanZ(@ptrCast([*:0]const u8, self.strtab.items.ptr + str_off));
}

pub fn parseName(name: *const [16]u8) []const u8 {
    const len = mem.indexOfScalar(u8, name, @as(u8, 0)) orelse name.len;
    return name[0..len];
}

fn addSegmentToDir(self: *Zld, idx: u16) !void {
    const segment_cmd = self.load_commands.items[idx].Segment;
    return self.segments_directory.putNoClobber(self.allocator, segment_cmd.inner.segname, idx);
}

fn addSectionToDir(self: *Zld, value: DirectoryEntry) !void {
    const seg = self.load_commands.items[value.seg_index].Segment;
    const sect = seg.sections.items[value.sect_index];
    return self.directory.putNoClobber(self.allocator, .{
        .segname = sect.segname,
        .sectname = sect.sectname,
    }, value);
}

fn isLocal(sym: *const macho.nlist_64) callconv(.Inline) bool {
    if (isExtern(sym)) return false;
    const tt = macho.N_TYPE & sym.n_type;
    return tt == macho.N_SECT;
}

fn isExport(sym: *const macho.nlist_64) callconv(.Inline) bool {
    if (!isExtern(sym)) return false;
    const tt = macho.N_TYPE & sym.n_type;
    return tt == macho.N_SECT;
}

fn isImport(sym: *const macho.nlist_64) callconv(.Inline) bool {
    if (!isExtern(sym)) return false;
    const tt = macho.N_TYPE & sym.n_type;
    return tt == macho.N_UNDF;
}

fn isExtern(sym: *const macho.nlist_64) callconv(.Inline) bool {
    if ((sym.n_type & macho.N_EXT) == 0) return false;
    return (sym.n_type & macho.N_PEXT) == 0;
}
