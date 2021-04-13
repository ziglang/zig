const Zld = @This();

const std = @import("std");
const assert = std.debug.assert;
const leb = std.leb;
const mem = std.mem;
const meta = std.meta;
const fs = std.fs;
const macho = std.macho;
const math = std.math;
const log = std.log.scoped(.zld);
const aarch64 = @import("../../codegen/aarch64.zig");
const reloc = @import("reloc.zig");

const Allocator = mem.Allocator;
const Archive = @import("Archive.zig");
const CodeSignature = @import("CodeSignature.zig");
const Object = @import("Object.zig");
const Symbol = @import("Symbol.zig");
const Trie = @import("Trie.zig");

usingnamespace @import("commands.zig");
usingnamespace @import("bind.zig");

allocator: *Allocator,

arch: ?std.Target.Cpu.Arch = null,
page_size: ?u16 = null,
file: ?fs.File = null,
out_path: ?[]const u8 = null,

objects: std.ArrayListUnmanaged(Object) = .{},
archives: std.ArrayListUnmanaged(Archive) = .{},

load_commands: std.ArrayListUnmanaged(LoadCommand) = .{},

pagezero_segment_cmd_index: ?u16 = null,
text_segment_cmd_index: ?u16 = null,
data_const_segment_cmd_index: ?u16 = null,
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

// __TEXT segment sections
text_section_index: ?u16 = null,
stubs_section_index: ?u16 = null,
stub_helper_section_index: ?u16 = null,
text_const_section_index: ?u16 = null,
cstring_section_index: ?u16 = null,

// __DATA_CONST segment sections
got_section_index: ?u16 = null,
mod_init_func_section_index: ?u16 = null,
mod_term_func_section_index: ?u16 = null,
data_const_section_index: ?u16 = null,

// __DATA segment sections
tlv_section_index: ?u16 = null,
tlv_data_section_index: ?u16 = null,
tlv_bss_section_index: ?u16 = null,
la_symbol_ptr_section_index: ?u16 = null,
data_section_index: ?u16 = null,
bss_section_index: ?u16 = null,

symtab: std.StringArrayHashMapUnmanaged(Symbol) = .{},
strtab: std.ArrayListUnmanaged(u8) = .{},
strtab_dir: std.StringHashMapUnmanaged(u32) = .{},

threadlocal_offsets: std.ArrayListUnmanaged(u64) = .{},
local_rebases: std.ArrayListUnmanaged(Pointer) = .{},
stubs: std.StringArrayHashMapUnmanaged(u32) = .{},
got_entries: std.StringArrayHashMapUnmanaged(GotEntry) = .{},

stub_helper_stubs_start_off: ?u64 = null,

mappings: std.AutoHashMapUnmanaged(MappingKey, SectionMapping) = .{},
unhandled_sections: std.AutoHashMapUnmanaged(MappingKey, u0) = .{},

const GotEntry = struct {
    tag: enum {
        local,
        import,
    },
    index: u32,
    target_addr: u64,
    file: u16,
};

const MappingKey = struct {
    object_id: u16,
    source_sect_id: u16,
};

pub const SectionMapping = struct {
    source_sect_id: u16,
    target_seg_id: u16,
    target_sect_id: u16,
    offset: u32,
};

/// Default path to dyld
const DEFAULT_DYLD_PATH: [*:0]const u8 = "/usr/lib/dyld";

const LIB_SYSTEM_NAME: [*:0]const u8 = "System";
/// TODO this should be inferred from included libSystem.tbd or similar.
const LIB_SYSTEM_PATH: [*:0]const u8 = "/usr/lib/libSystem.B.dylib";

pub fn init(allocator: *Allocator) Zld {
    return .{ .allocator = allocator };
}

pub fn deinit(self: *Zld) void {
    self.threadlocal_offsets.deinit(self.allocator);
    self.local_rebases.deinit(self.allocator);

    for (self.stubs.items()) |entry| {
        self.allocator.free(entry.key);
    }
    self.stubs.deinit(self.allocator);

    for (self.got_entries.items()) |entry| {
        self.allocator.free(entry.key);
    }
    self.got_entries.deinit(self.allocator);

    for (self.load_commands.items) |*lc| {
        lc.deinit(self.allocator);
    }
    self.load_commands.deinit(self.allocator);

    for (self.objects.items) |*object| {
        object.deinit();
    }
    self.objects.deinit(self.allocator);

    for (self.archives.items) |*archive| {
        archive.deinit();
    }
    self.archives.deinit(self.allocator);

    self.mappings.deinit(self.allocator);
    self.unhandled_sections.deinit(self.allocator);

    for (self.symtab.items()) |*entry| {
        entry.value.deinit(self.allocator);
    }
    self.symtab.deinit(self.allocator);
    self.strtab.deinit(self.allocator);

    {
        var it = self.strtab_dir.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key);
        }
    }
    self.strtab_dir.deinit(self.allocator);
}

pub fn closeFiles(self: Zld) void {
    for (self.objects.items) |object| {
        object.closeFile();
    }
    for (self.archives.items) |archive| {
        archive.closeFile();
    }
    if (self.file) |f| f.close();
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
    try self.resolveSymbols();
    try self.resolveStubsAndGotEntries();
    try self.updateMetadata();
    try self.sortSections();
    try self.allocateTextSegment();
    try self.allocateDataConstSegment();
    try self.allocateDataSegment();
    self.allocateLinkeditSegment();
    try self.allocateSymbols();
    try self.allocateStubsAndGotEntries();
    try self.writeStubHelperCommon();
    try self.resolveRelocsAndWriteSections();
    try self.flush();
}

fn parseInputFiles(self: *Zld, files: []const []const u8) !void {
    const Input = struct {
        kind: enum {
            object,
            archive,
        },
        file: fs.File,
        name: []const u8,
    };
    var classified = std.ArrayList(Input).init(self.allocator);
    defer classified.deinit();

    // First, classify input files as either object or archive.
    for (files) |file_name| {
        const file = try fs.cwd().openFile(file_name, .{});
        const full_path = full_path: {
            var buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
            const path = try std.fs.realpath(file_name, &buffer);
            break :full_path try self.allocator.dupe(u8, path);
        };

        try_object: {
            const header = try file.reader().readStruct(macho.mach_header_64);
            if (header.filetype != macho.MH_OBJECT) {
                try file.seekTo(0);
                break :try_object;
            }

            try file.seekTo(0);
            try classified.append(.{
                .kind = .object,
                .file = file,
                .name = full_path,
            });
            continue;
        }

        try_archive: {
            const magic = try file.reader().readBytesNoEof(Archive.SARMAG);
            if (!mem.eql(u8, &magic, Archive.ARMAG)) {
                try file.seekTo(0);
                break :try_archive;
            }

            try file.seekTo(0);
            try classified.append(.{
                .kind = .archive,
                .file = file,
                .name = full_path,
            });
            continue;
        }

        log.debug("unexpected input file of unknown type '{s}'", .{file_name});
    }

    // Based on our classification, proceed with parsing.
    for (classified.items) |input| {
        switch (input.kind) {
            .object => {
                var object = Object.init(self.allocator);
                object.arch = self.arch.?;
                object.name = try self.allocator.dupe(u8, input.name);
                object.file = input.file;
                try object.parse();
                try self.objects.append(self.allocator, object);
            },
            .archive => {
                var archive = Archive.init(self.allocator);
                archive.arch = self.arch.?;
                archive.name = try self.allocator.dupe(u8, input.name);
                archive.file = input.file;
                try archive.parse();
                try self.archives.append(self.allocator, archive);
            },
        }
    }
}

fn mapAndUpdateSections(
    self: *Zld,
    object_id: u16,
    source_sect_id: u16,
    target_seg_id: u16,
    target_sect_id: u16,
) !void {
    const object = self.objects.items[object_id];
    const source_seg = object.load_commands.items[object.segment_cmd_index.?].Segment;
    const source_sect = source_seg.sections.items[source_sect_id];
    const target_seg = &self.load_commands.items[target_seg_id].Segment;
    const target_sect = &target_seg.sections.items[target_sect_id];

    const alignment = try math.powi(u32, 2, target_sect.@"align");
    const offset = mem.alignForwardGeneric(u64, target_sect.size, alignment);
    const size = mem.alignForwardGeneric(u64, source_sect.size, alignment);
    const key = MappingKey{
        .object_id = object_id,
        .source_sect_id = source_sect_id,
    };
    try self.mappings.putNoClobber(self.allocator, key, .{
        .source_sect_id = source_sect_id,
        .target_seg_id = target_seg_id,
        .target_sect_id = target_sect_id,
        .offset = @intCast(u32, offset),
    });
    log.debug("{s}: {s},{s} mapped to {s},{s} from 0x{x} to 0x{x}", .{
        object.name,
        parseName(&source_sect.segname),
        parseName(&source_sect.sectname),
        parseName(&target_sect.segname),
        parseName(&target_sect.sectname),
        offset,
        offset + size,
    });

    target_sect.size = offset + size;
}

fn updateMetadata(self: *Zld) !void {
    for (self.objects.items) |object, id| {
        const object_id = @intCast(u16, id);
        const object_seg = object.load_commands.items[object.segment_cmd_index.?].Segment;
        const text_seg = &self.load_commands.items[self.text_segment_cmd_index.?].Segment;
        const data_const_seg = &self.load_commands.items[self.data_const_segment_cmd_index.?].Segment;
        const data_seg = &self.load_commands.items[self.data_segment_cmd_index.?].Segment;

        // Create missing metadata
        for (object_seg.sections.items) |source_sect, sect_id| {
            if (sect_id == object.text_section_index.?) continue;
            const segname = parseName(&source_sect.segname);
            const sectname = parseName(&source_sect.sectname);
            const flags = source_sect.flags;

            switch (flags) {
                macho.S_REGULAR, macho.S_4BYTE_LITERALS, macho.S_8BYTE_LITERALS, macho.S_16BYTE_LITERALS => {
                    if (mem.eql(u8, segname, "__TEXT")) {
                        if (self.text_const_section_index != null) continue;

                        self.text_const_section_index = @intCast(u16, text_seg.sections.items.len);
                        try text_seg.addSection(self.allocator, .{
                            .sectname = makeStaticString("__const"),
                            .segname = makeStaticString("__TEXT"),
                            .addr = 0,
                            .size = 0,
                            .offset = 0,
                            .@"align" = 0,
                            .reloff = 0,
                            .nreloc = 0,
                            .flags = macho.S_REGULAR,
                            .reserved1 = 0,
                            .reserved2 = 0,
                            .reserved3 = 0,
                        });
                    } else if (mem.eql(u8, segname, "__DATA")) {
                        if (!mem.eql(u8, sectname, "__const")) continue;
                        if (self.data_const_section_index != null) continue;

                        self.data_const_section_index = @intCast(u16, data_const_seg.sections.items.len);
                        try data_const_seg.addSection(self.allocator, .{
                            .sectname = makeStaticString("__const"),
                            .segname = makeStaticString("__DATA_CONST"),
                            .addr = 0,
                            .size = 0,
                            .offset = 0,
                            .@"align" = 0,
                            .reloff = 0,
                            .nreloc = 0,
                            .flags = macho.S_REGULAR,
                            .reserved1 = 0,
                            .reserved2 = 0,
                            .reserved3 = 0,
                        });
                    }
                },
                macho.S_CSTRING_LITERALS => {
                    if (!mem.eql(u8, segname, "__TEXT")) continue;
                    if (self.cstring_section_index != null) continue;

                    self.cstring_section_index = @intCast(u16, text_seg.sections.items.len);
                    try text_seg.addSection(self.allocator, .{
                        .sectname = makeStaticString("__cstring"),
                        .segname = makeStaticString("__TEXT"),
                        .addr = 0,
                        .size = 0,
                        .offset = 0,
                        .@"align" = 0,
                        .reloff = 0,
                        .nreloc = 0,
                        .flags = macho.S_CSTRING_LITERALS,
                        .reserved1 = 0,
                        .reserved2 = 0,
                        .reserved3 = 0,
                    });
                },
                macho.S_MOD_INIT_FUNC_POINTERS => {
                    if (!mem.eql(u8, segname, "__DATA")) continue;
                    if (self.mod_init_func_section_index != null) continue;

                    self.mod_init_func_section_index = @intCast(u16, data_const_seg.sections.items.len);
                    try data_const_seg.addSection(self.allocator, .{
                        .sectname = makeStaticString("__mod_init_func"),
                        .segname = makeStaticString("__DATA_CONST"),
                        .addr = 0,
                        .size = 0,
                        .offset = 0,
                        .@"align" = 0,
                        .reloff = 0,
                        .nreloc = 0,
                        .flags = macho.S_MOD_INIT_FUNC_POINTERS,
                        .reserved1 = 0,
                        .reserved2 = 0,
                        .reserved3 = 0,
                    });
                },
                macho.S_MOD_TERM_FUNC_POINTERS => {
                    if (!mem.eql(u8, segname, "__DATA")) continue;
                    if (self.mod_term_func_section_index != null) continue;

                    self.mod_term_func_section_index = @intCast(u16, data_const_seg.sections.items.len);
                    try data_const_seg.addSection(self.allocator, .{
                        .sectname = makeStaticString("__mod_term_func"),
                        .segname = makeStaticString("__DATA_CONST"),
                        .addr = 0,
                        .size = 0,
                        .offset = 0,
                        .@"align" = 0,
                        .reloff = 0,
                        .nreloc = 0,
                        .flags = macho.S_MOD_TERM_FUNC_POINTERS,
                        .reserved1 = 0,
                        .reserved2 = 0,
                        .reserved3 = 0,
                    });
                },
                macho.S_ZEROFILL => {
                    if (!mem.eql(u8, segname, "__DATA")) continue;
                    if (self.bss_section_index != null) continue;

                    self.bss_section_index = @intCast(u16, data_seg.sections.items.len);
                    try data_seg.addSection(self.allocator, .{
                        .sectname = makeStaticString("__bss"),
                        .segname = makeStaticString("__DATA"),
                        .addr = 0,
                        .size = 0,
                        .offset = 0,
                        .@"align" = 0,
                        .reloff = 0,
                        .nreloc = 0,
                        .flags = macho.S_ZEROFILL,
                        .reserved1 = 0,
                        .reserved2 = 0,
                        .reserved3 = 0,
                    });
                },
                macho.S_THREAD_LOCAL_VARIABLES => {
                    if (!mem.eql(u8, segname, "__DATA")) continue;
                    if (self.tlv_section_index != null) continue;

                    self.tlv_section_index = @intCast(u16, data_seg.sections.items.len);
                    try data_seg.addSection(self.allocator, .{
                        .sectname = makeStaticString("__thread_vars"),
                        .segname = makeStaticString("__DATA"),
                        .addr = 0,
                        .size = 0,
                        .offset = 0,
                        .@"align" = 0,
                        .reloff = 0,
                        .nreloc = 0,
                        .flags = macho.S_THREAD_LOCAL_VARIABLES,
                        .reserved1 = 0,
                        .reserved2 = 0,
                        .reserved3 = 0,
                    });
                },
                macho.S_THREAD_LOCAL_REGULAR => {
                    if (!mem.eql(u8, segname, "__DATA")) continue;
                    if (self.tlv_data_section_index != null) continue;

                    self.tlv_data_section_index = @intCast(u16, data_seg.sections.items.len);
                    try data_seg.addSection(self.allocator, .{
                        .sectname = makeStaticString("__thread_data"),
                        .segname = makeStaticString("__DATA"),
                        .addr = 0,
                        .size = 0,
                        .offset = 0,
                        .@"align" = 0,
                        .reloff = 0,
                        .nreloc = 0,
                        .flags = macho.S_THREAD_LOCAL_REGULAR,
                        .reserved1 = 0,
                        .reserved2 = 0,
                        .reserved3 = 0,
                    });
                },
                macho.S_THREAD_LOCAL_ZEROFILL => {
                    if (!mem.eql(u8, segname, "__DATA")) continue;
                    if (self.tlv_bss_section_index != null) continue;

                    self.tlv_bss_section_index = @intCast(u16, data_seg.sections.items.len);
                    try data_seg.addSection(self.allocator, .{
                        .sectname = makeStaticString("__thread_bss"),
                        .segname = makeStaticString("__DATA"),
                        .addr = 0,
                        .size = 0,
                        .offset = 0,
                        .@"align" = 0,
                        .reloff = 0,
                        .nreloc = 0,
                        .flags = macho.S_THREAD_LOCAL_ZEROFILL,
                        .reserved1 = 0,
                        .reserved2 = 0,
                        .reserved3 = 0,
                    });
                },
                else => {
                    log.debug("unhandled section type 0x{x} for '{s}/{s}'", .{ flags, segname, sectname });
                },
            }
        }

        // Find ideal section alignment.
        for (object_seg.sections.items) |source_sect| {
            if (self.getMatchingSection(source_sect)) |res| {
                const target_seg = &self.load_commands.items[res.seg].Segment;
                const target_sect = &target_seg.sections.items[res.sect];
                target_sect.@"align" = math.max(target_sect.@"align", source_sect.@"align");
            }
        }

        // Update section mappings
        for (object_seg.sections.items) |source_sect, sect_id| {
            const source_sect_id = @intCast(u16, sect_id);
            if (self.getMatchingSection(source_sect)) |res| {
                try self.mapAndUpdateSections(object_id, source_sect_id, res.seg, res.sect);
                continue;
            }

            const segname = parseName(&source_sect.segname);
            const sectname = parseName(&source_sect.sectname);
            log.debug("section '{s}/{s}' will be unmapped", .{ segname, sectname });
            try self.unhandled_sections.putNoClobber(self.allocator, .{
                .object_id = object_id,
                .source_sect_id = source_sect_id,
            }, 0);
        }
    }
}

const MatchingSection = struct {
    seg: u16,
    sect: u16,
};

fn getMatchingSection(self: *Zld, section: macho.section_64) ?MatchingSection {
    const segname = parseName(&section.segname);
    const sectname = parseName(&section.sectname);
    const res: ?MatchingSection = blk: {
        switch (section.flags) {
            macho.S_4BYTE_LITERALS, macho.S_8BYTE_LITERALS, macho.S_16BYTE_LITERALS => {
                break :blk .{
                    .seg = self.text_segment_cmd_index.?,
                    .sect = self.text_const_section_index.?,
                };
            },
            macho.S_CSTRING_LITERALS => {
                break :blk .{
                    .seg = self.text_segment_cmd_index.?,
                    .sect = self.cstring_section_index.?,
                };
            },
            macho.S_MOD_INIT_FUNC_POINTERS => {
                break :blk .{
                    .seg = self.data_const_segment_cmd_index.?,
                    .sect = self.mod_init_func_section_index.?,
                };
            },
            macho.S_MOD_TERM_FUNC_POINTERS => {
                break :blk .{
                    .seg = self.data_const_segment_cmd_index.?,
                    .sect = self.mod_term_func_section_index.?,
                };
            },
            macho.S_ZEROFILL => {
                break :blk .{
                    .seg = self.data_segment_cmd_index.?,
                    .sect = self.bss_section_index.?,
                };
            },
            macho.S_THREAD_LOCAL_VARIABLES => {
                break :blk .{
                    .seg = self.data_segment_cmd_index.?,
                    .sect = self.tlv_section_index.?,
                };
            },
            macho.S_THREAD_LOCAL_REGULAR => {
                break :blk .{
                    .seg = self.data_segment_cmd_index.?,
                    .sect = self.tlv_data_section_index.?,
                };
            },
            macho.S_THREAD_LOCAL_ZEROFILL => {
                break :blk .{
                    .seg = self.data_segment_cmd_index.?,
                    .sect = self.tlv_bss_section_index.?,
                };
            },
            macho.S_REGULAR | macho.S_ATTR_PURE_INSTRUCTIONS | macho.S_ATTR_SOME_INSTRUCTIONS => {
                break :blk .{
                    .seg = self.text_segment_cmd_index.?,
                    .sect = self.text_section_index.?,
                };
            },
            macho.S_REGULAR => {
                if (mem.eql(u8, segname, "__TEXT")) {
                    break :blk .{
                        .seg = self.text_segment_cmd_index.?,
                        .sect = self.text_const_section_index.?,
                    };
                } else if (mem.eql(u8, segname, "__DATA")) {
                    if (mem.eql(u8, sectname, "__data")) {
                        break :blk .{
                            .seg = self.data_segment_cmd_index.?,
                            .sect = self.data_section_index.?,
                        };
                    } else if (mem.eql(u8, sectname, "__const")) {
                        break :blk .{
                            .seg = self.data_const_segment_cmd_index.?,
                            .sect = self.data_const_section_index.?,
                        };
                    }
                }
                break :blk null;
            },
            else => {
                break :blk null;
            },
        }
    };
    return res;
}

fn sortSections(self: *Zld) !void {
    var text_index_mapping = std.AutoHashMap(u16, u16).init(self.allocator);
    defer text_index_mapping.deinit();
    var data_const_index_mapping = std.AutoHashMap(u16, u16).init(self.allocator);
    defer data_const_index_mapping.deinit();
    var data_index_mapping = std.AutoHashMap(u16, u16).init(self.allocator);
    defer data_index_mapping.deinit();

    {
        // __TEXT segment
        const seg = &self.load_commands.items[self.text_segment_cmd_index.?].Segment;
        var sections = seg.sections.toOwnedSlice(self.allocator);
        defer self.allocator.free(sections);
        try seg.sections.ensureCapacity(self.allocator, sections.len);

        const indices = &[_]*?u16{
            &self.text_section_index,
            &self.stubs_section_index,
            &self.stub_helper_section_index,
            &self.text_const_section_index,
            &self.cstring_section_index,
        };
        for (indices) |maybe_index| {
            const new_index: u16 = if (maybe_index.*) |index| blk: {
                const idx = @intCast(u16, seg.sections.items.len);
                seg.sections.appendAssumeCapacity(sections[index]);
                try text_index_mapping.putNoClobber(index, idx);
                break :blk idx;
            } else continue;
            maybe_index.* = new_index;
        }
    }

    {
        // __DATA_CONST segment
        const seg = &self.load_commands.items[self.data_const_segment_cmd_index.?].Segment;
        var sections = seg.sections.toOwnedSlice(self.allocator);
        defer self.allocator.free(sections);
        try seg.sections.ensureCapacity(self.allocator, sections.len);

        const indices = &[_]*?u16{
            &self.got_section_index,
            &self.mod_init_func_section_index,
            &self.mod_term_func_section_index,
            &self.data_const_section_index,
        };
        for (indices) |maybe_index| {
            const new_index: u16 = if (maybe_index.*) |index| blk: {
                const idx = @intCast(u16, seg.sections.items.len);
                seg.sections.appendAssumeCapacity(sections[index]);
                try data_const_index_mapping.putNoClobber(index, idx);
                break :blk idx;
            } else continue;
            maybe_index.* = new_index;
        }
    }

    {
        // __DATA segment
        const seg = &self.load_commands.items[self.data_segment_cmd_index.?].Segment;
        var sections = seg.sections.toOwnedSlice(self.allocator);
        defer self.allocator.free(sections);
        try seg.sections.ensureCapacity(self.allocator, sections.len);

        // __DATA segment
        const indices = &[_]*?u16{
            &self.la_symbol_ptr_section_index,
            &self.tlv_section_index,
            &self.data_section_index,
            &self.tlv_data_section_index,
            &self.tlv_bss_section_index,
            &self.bss_section_index,
        };
        for (indices) |maybe_index| {
            const new_index: u16 = if (maybe_index.*) |index| blk: {
                const idx = @intCast(u16, seg.sections.items.len);
                seg.sections.appendAssumeCapacity(sections[index]);
                try data_index_mapping.putNoClobber(index, idx);
                break :blk idx;
            } else continue;
            maybe_index.* = new_index;
        }
    }

    var it = self.mappings.iterator();
    while (it.next()) |entry| {
        const mapping = &entry.value;
        if (self.text_segment_cmd_index.? == mapping.target_seg_id) {
            const new_index = text_index_mapping.get(mapping.target_sect_id) orelse unreachable;
            mapping.target_sect_id = new_index;
        } else if (self.data_const_segment_cmd_index.? == mapping.target_seg_id) {
            const new_index = data_const_index_mapping.get(mapping.target_sect_id) orelse unreachable;
            mapping.target_sect_id = new_index;
        } else if (self.data_segment_cmd_index.? == mapping.target_seg_id) {
            const new_index = data_index_mapping.get(mapping.target_sect_id) orelse unreachable;
            mapping.target_sect_id = new_index;
        } else unreachable;
    }
}

fn allocateTextSegment(self: *Zld) !void {
    const seg = &self.load_commands.items[self.text_segment_cmd_index.?].Segment;
    const nstubs = @intCast(u32, self.stubs.items().len);

    const base_vmaddr = self.load_commands.items[self.pagezero_segment_cmd_index.?].Segment.inner.vmsize;
    seg.inner.fileoff = 0;
    seg.inner.vmaddr = base_vmaddr;

    // Set stubs and stub_helper sizes
    const stubs = &seg.sections.items[self.stubs_section_index.?];
    const stub_helper = &seg.sections.items[self.stub_helper_section_index.?];
    stubs.size += nstubs * stubs.reserved2;

    const stub_size: u4 = switch (self.arch.?) {
        .x86_64 => 10,
        .aarch64 => 3 * @sizeOf(u32),
        else => unreachable,
    };
    stub_helper.size += nstubs * stub_size;

    var sizeofcmds: u64 = 0;
    for (self.load_commands.items) |lc| {
        sizeofcmds += lc.cmdsize();
    }

    try self.allocateSegment(self.text_segment_cmd_index.?, @sizeOf(macho.mach_header_64) + sizeofcmds);

    // Shift all sections to the back to minimize jump size between __TEXT and __DATA segments.
    var min_alignment: u32 = 0;
    for (seg.sections.items) |sect| {
        const alignment = try math.powi(u32, 2, sect.@"align");
        min_alignment = math.max(min_alignment, alignment);
    }

    assert(min_alignment > 0);
    const last_sect_idx = seg.sections.items.len - 1;
    const last_sect = seg.sections.items[last_sect_idx];
    const shift: u32 = blk: {
        const diff = seg.inner.filesize - last_sect.offset - last_sect.size;
        const factor = @divTrunc(diff, min_alignment);
        break :blk @intCast(u32, factor * min_alignment);
    };

    if (shift > 0) {
        for (seg.sections.items) |*sect| {
            sect.offset += shift;
            sect.addr += shift;
        }
    }
}

fn allocateDataConstSegment(self: *Zld) !void {
    const seg = &self.load_commands.items[self.data_const_segment_cmd_index.?].Segment;
    const nentries = @intCast(u32, self.got_entries.items().len);

    const text_seg = self.load_commands.items[self.text_segment_cmd_index.?].Segment;
    seg.inner.fileoff = text_seg.inner.fileoff + text_seg.inner.filesize;
    seg.inner.vmaddr = text_seg.inner.vmaddr + text_seg.inner.vmsize;

    // Set got size
    const got = &seg.sections.items[self.got_section_index.?];
    got.size += nentries * @sizeOf(u64);

    try self.allocateSegment(self.data_const_segment_cmd_index.?, 0);
}

fn allocateDataSegment(self: *Zld) !void {
    const seg = &self.load_commands.items[self.data_segment_cmd_index.?].Segment;
    const nstubs = @intCast(u32, self.stubs.items().len);

    const data_const_seg = self.load_commands.items[self.data_const_segment_cmd_index.?].Segment;
    seg.inner.fileoff = data_const_seg.inner.fileoff + data_const_seg.inner.filesize;
    seg.inner.vmaddr = data_const_seg.inner.vmaddr + data_const_seg.inner.vmsize;

    // Set la_symbol_ptr and data size
    const la_symbol_ptr = &seg.sections.items[self.la_symbol_ptr_section_index.?];
    const data = &seg.sections.items[self.data_section_index.?];
    la_symbol_ptr.size += nstubs * @sizeOf(u64);
    data.size += @sizeOf(u64); // We need at least 8bytes for address of dyld_stub_binder

    try self.allocateSegment(self.data_segment_cmd_index.?, 0);
}

fn allocateLinkeditSegment(self: *Zld) void {
    const seg = &self.load_commands.items[self.linkedit_segment_cmd_index.?].Segment;
    const data_seg = self.load_commands.items[self.data_segment_cmd_index.?].Segment;
    seg.inner.fileoff = data_seg.inner.fileoff + data_seg.inner.filesize;
    seg.inner.vmaddr = data_seg.inner.vmaddr + data_seg.inner.vmsize;
}

fn allocateSegment(self: *Zld, index: u16, offset: u64) !void {
    const base_vmaddr = self.load_commands.items[self.pagezero_segment_cmd_index.?].Segment.inner.vmsize;
    const seg = &self.load_commands.items[index].Segment;

    // Allocate the sections according to their alignment at the beginning of the segment.
    var start: u64 = offset;
    for (seg.sections.items) |*sect| {
        const alignment = try math.powi(u32, 2, sect.@"align");
        const start_aligned = mem.alignForwardGeneric(u64, start, alignment);
        const end_aligned = mem.alignForwardGeneric(u64, start_aligned + sect.size, alignment);
        sect.offset = @intCast(u32, seg.inner.fileoff + start_aligned);
        sect.addr = seg.inner.vmaddr + start_aligned;
        start = end_aligned;
    }

    const seg_size_aligned = mem.alignForwardGeneric(u64, start, self.page_size.?);
    seg.inner.filesize = seg_size_aligned;
    seg.inner.vmsize = seg_size_aligned;
}

fn allocateSymbols(self: *Zld) !void {
    for (self.objects.items) |*object, object_id| {
        for (object.locals.items()) |*entry| {
            const source_sym = object.symtab.items[entry.value.index.?];
            const source_sect_id = source_sym.n_sect - 1;

            // TODO I am more and more convinced we should store the mapping as part of the Object struct.
            const target_mapping = self.mappings.get(.{
                .object_id = @intCast(u16, object_id),
                .source_sect_id = source_sect_id,
            }) orelse {
                if (self.unhandled_sections.get(.{
                    .object_id = @intCast(u16, object_id),
                    .source_sect_id = source_sect_id,
                }) != null) continue;

                log.err("section not mapped for symbol '{s}'", .{entry.value.name});
                return error.SectionNotMappedForSymbol;
            };

            const source_seg = object.load_commands.items[object.segment_cmd_index.?].Segment;
            const source_sect = source_seg.sections.items[source_sect_id];
            const target_seg = self.load_commands.items[target_mapping.target_seg_id].Segment;
            const target_sect = target_seg.sections.items[target_mapping.target_sect_id];
            const target_addr = target_sect.addr + target_mapping.offset;
            const n_value = source_sym.n_value - source_sect.addr + target_addr;

            log.debug("resolving local symbol '{s}' at 0x{x}", .{ entry.value.name, n_value });

            // TODO there might be a more generic way of doing this.
            var n_sect: u8 = 0;
            for (self.load_commands.items) |cmd, cmd_id| {
                if (cmd != .Segment) break;
                if (cmd_id == target_mapping.target_seg_id) {
                    n_sect += @intCast(u8, target_mapping.target_sect_id) + 1;
                    break;
                }
                n_sect += @intCast(u8, cmd.Segment.sections.items.len);
            }

            entry.value.address = n_value;
            entry.value.section = n_sect;
        }
    }

    for (self.symtab.items()) |*entry| {
        if (entry.value.tag == .import) continue;

        const object_id = entry.value.file orelse unreachable;
        const object = self.objects.items[object_id];
        const local = object.locals.get(entry.key) orelse unreachable;

        log.debug("resolving {} symbol '{s}' at 0x{x}", .{ entry.value.tag, entry.key, local.address });

        entry.value.address = local.address;
        entry.value.section = local.section;
    }
}

fn allocateStubsAndGotEntries(self: *Zld) !void {
    for (self.got_entries.items()) |*entry| {
        if (entry.value.tag == .import) continue;

        const object = self.objects.items[entry.value.file];
        entry.value.target_addr = target_addr: {
            if (object.locals.get(entry.key)) |local| {
                break :target_addr local.address;
            }
            const global = self.symtab.get(entry.key) orelse unreachable;
            break :target_addr global.address;
        };

        log.debug("resolving GOT entry '{s}' at 0x{x}", .{
            entry.key,
            entry.value.target_addr,
        });
    }
}

fn writeStubHelperCommon(self: *Zld) !void {
    const text_segment = &self.load_commands.items[self.text_segment_cmd_index.?].Segment;
    const stub_helper = &text_segment.sections.items[self.stub_helper_section_index.?];
    const data_const_segment = &self.load_commands.items[self.data_const_segment_cmd_index.?].Segment;
    const got = &data_const_segment.sections.items[self.got_section_index.?];
    const data_segment = &self.load_commands.items[self.data_segment_cmd_index.?].Segment;
    const data = &data_segment.sections.items[self.data_section_index.?];
    const la_symbol_ptr = data_segment.sections.items[self.la_symbol_ptr_section_index.?];

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
                    const dyld_stub_binder = self.got_entries.get("dyld_stub_binder").?;
                    const addr = (got.addr + dyld_stub_binder.index * @sizeOf(u64));
                    const displacement = try math.cast(u32, addr - stub_helper.addr - code_size);
                    mem.writeIntLittle(u32, code[11..], displacement);
                }
                try self.file.?.pwriteAll(&code, stub_helper.offset);
                break :blk stub_helper.offset + code_size;
            },
            .aarch64 => {
                var code: [6 * @sizeOf(u32)]u8 = undefined;
                data_blk_outer: {
                    const this_addr = stub_helper.addr;
                    const target_addr = data.addr + data.size - @sizeOf(u64);
                    data_blk: {
                        const displacement = math.cast(i21, target_addr - this_addr) catch |_| break :data_blk;
                        // adr x17, disp
                        mem.writeIntLittle(u32, code[0..4], aarch64.Instruction.adr(.x17, displacement).toU32());
                        // nop
                        mem.writeIntLittle(u32, code[4..8], aarch64.Instruction.nop().toU32());
                        break :data_blk_outer;
                    }
                    data_blk: {
                        const new_this_addr = this_addr + @sizeOf(u32);
                        const displacement = math.cast(i21, target_addr - new_this_addr) catch |_| break :data_blk;
                        // nop
                        mem.writeIntLittle(u32, code[0..4], aarch64.Instruction.nop().toU32());
                        // adr x17, disp
                        mem.writeIntLittle(u32, code[4..8], aarch64.Instruction.adr(.x17, displacement).toU32());
                        break :data_blk_outer;
                    }
                    // Jump is too big, replace adr with adrp and add.
                    const this_page = @intCast(i32, this_addr >> 12);
                    const target_page = @intCast(i32, target_addr >> 12);
                    const pages = @intCast(i21, target_page - this_page);
                    mem.writeIntLittle(u32, code[0..4], aarch64.Instruction.adrp(.x17, pages).toU32());
                    const narrowed = @truncate(u12, target_addr);
                    mem.writeIntLittle(u32, code[4..8], aarch64.Instruction.add(.x17, .x17, narrowed, false).toU32());
                }
                // stp x16, x17, [sp, #-16]!
                code[8] = 0xf0;
                code[9] = 0x47;
                code[10] = 0xbf;
                code[11] = 0xa9;
                binder_blk_outer: {
                    const dyld_stub_binder = self.got_entries.get("dyld_stub_binder").?;
                    const this_addr = stub_helper.addr + 3 * @sizeOf(u32);
                    const target_addr = (got.addr + dyld_stub_binder.index * @sizeOf(u64));
                    binder_blk: {
                        const displacement = math.divExact(u64, target_addr - this_addr, 4) catch |_| break :binder_blk;
                        const literal = math.cast(u18, displacement) catch |_| break :binder_blk;
                        // ldr x16, label
                        mem.writeIntLittle(u32, code[12..16], aarch64.Instruction.ldr(.x16, .{
                            .literal = literal,
                        }).toU32());
                        // nop
                        mem.writeIntLittle(u32, code[16..20], aarch64.Instruction.nop().toU32());
                        break :binder_blk_outer;
                    }
                    binder_blk: {
                        const new_this_addr = this_addr + @sizeOf(u32);
                        const displacement = math.divExact(u64, target_addr - new_this_addr, 4) catch |_| break :binder_blk;
                        const literal = math.cast(u18, displacement) catch |_| break :binder_blk;
                        // Pad with nop to please division.
                        // nop
                        mem.writeIntLittle(u32, code[12..16], aarch64.Instruction.nop().toU32());
                        // ldr x16, label
                        mem.writeIntLittle(u32, code[16..20], aarch64.Instruction.ldr(.x16, .{
                            .literal = literal,
                        }).toU32());
                        break :binder_blk_outer;
                    }
                    // Use adrp followed by ldr(immediate).
                    const this_page = @intCast(i32, this_addr >> 12);
                    const target_page = @intCast(i32, target_addr >> 12);
                    const pages = @intCast(i21, target_page - this_page);
                    mem.writeIntLittle(u32, code[12..16], aarch64.Instruction.adrp(.x16, pages).toU32());
                    const narrowed = @truncate(u12, target_addr);
                    const offset = try math.divExact(u12, narrowed, 8);
                    mem.writeIntLittle(u32, code[16..20], aarch64.Instruction.ldr(.x16, .{
                        .register = .{
                            .rn = .x16,
                            .offset = aarch64.Instruction.LoadStoreOffset.imm(offset),
                        },
                    }).toU32());
                }
                // br x16
                code[20] = 0x00;
                code[21] = 0x02;
                code[22] = 0x1f;
                code[23] = 0xd6;
                try self.file.?.pwriteAll(&code, stub_helper.offset);
                break :blk stub_helper.offset + 6 * @sizeOf(u32);
            },
            else => unreachable,
        }
    };

    for (self.stubs.items()) |entry| {
        const index = entry.value;
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
            outer: {
                const this_addr = stub_addr;
                const target_addr = la_ptr_addr;
                inner: {
                    const displacement = math.divExact(u64, target_addr - this_addr, 4) catch |_| break :inner;
                    const literal = math.cast(u18, displacement) catch |_| break :inner;
                    // ldr x16, literal
                    mem.writeIntLittle(u32, code[0..4], aarch64.Instruction.ldr(.x16, .{
                        .literal = literal,
                    }).toU32());
                    // nop
                    mem.writeIntLittle(u32, code[4..8], aarch64.Instruction.nop().toU32());
                    break :outer;
                }
                inner: {
                    const new_this_addr = this_addr + @sizeOf(u32);
                    const displacement = math.divExact(u64, target_addr - new_this_addr, 4) catch |_| break :inner;
                    const literal = math.cast(u18, displacement) catch |_| break :inner;
                    // nop
                    mem.writeIntLittle(u32, code[0..4], aarch64.Instruction.nop().toU32());
                    // ldr x16, literal
                    mem.writeIntLittle(u32, code[4..8], aarch64.Instruction.ldr(.x16, .{
                        .literal = literal,
                    }).toU32());
                    break :outer;
                }
                // Use adrp followed by ldr(immediate).
                const this_page = @intCast(i32, this_addr >> 12);
                const target_page = @intCast(i32, target_addr >> 12);
                const pages = @intCast(i21, target_page - this_page);
                mem.writeIntLittle(u32, code[0..4], aarch64.Instruction.adrp(.x16, pages).toU32());
                const narrowed = @truncate(u12, target_addr);
                const offset = try math.divExact(u12, narrowed, 8);
                mem.writeIntLittle(u32, code[4..8], aarch64.Instruction.ldr(.x16, .{
                    .register = .{
                        .rn = .x16,
                        .offset = aarch64.Instruction.LoadStoreOffset.imm(offset),
                    },
                }).toU32());
            }
            // br x16
            mem.writeIntLittle(u32, code[8..12], aarch64.Instruction.br(.x16).toU32());
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
            mem.writeIntLittle(u32, code[0..4], aarch64.Instruction.ldr(.w16, .{
                .literal = literal,
            }).toU32());
            // b disp
            mem.writeIntLittle(u32, code[4..8], aarch64.Instruction.b(displacement).toU32());
            mem.writeIntLittle(u32, code[8..12], 0x0); // Just a placeholder populated in `populateLazyBindOffsetsInStubHelper`.
        },
        else => unreachable,
    }
    try self.file.?.pwriteAll(code, stub_off);
}

fn resolveSymbolsInObject(self: *Zld, object_id: u16) !void {
    const object = self.objects.items[object_id];
    log.debug("resolving symbols in '{s}'", .{object.name});

    for (object.symtab.items) |sym, sym_id| {
        if (Symbol.isLocal(sym)) {
            // If symbol is local to CU, we don't put it in the global symbol table.
            continue;
        } else if (Symbol.isGlobal(sym)) {
            const sym_name = object.getString(sym.n_strx);
            const global = self.symtab.getEntry(sym_name) orelse {
                // Put new global symbol into the symbol table.
                const name = try self.allocator.dupe(u8, sym_name);
                try self.symtab.putNoClobber(self.allocator, name, .{
                    .tag = if (Symbol.isWeakDef(sym)) .weak else .strong,
                    .name = name,
                    .address = 0,
                    .section = 0,
                    .file = object_id,
                    .index = @intCast(u32, sym_id),
                });
                continue;
            };

            switch (global.value.tag) {
                .weak => continue, // If symbol is weak, nothing to do.
                .strong => {
                    log.err("symbol '{s}' defined multiple times", .{sym_name});
                    return error.MultipleSymbolDefinitions;
                },
                else => {},
            }

            global.value.tag = .strong;
            global.value.file = object_id;
            global.value.index = @intCast(u32, sym_id);
        } else if (Symbol.isUndef(sym)) {
            const sym_name = object.getString(sym.n_strx);
            if (self.symtab.contains(sym_name)) continue; // Nothing to do if we already found a definition.

            const name = try self.allocator.dupe(u8, sym_name);
            try self.symtab.putNoClobber(self.allocator, name, .{
                .tag = .undef,
                .name = name,
                .address = 0,
                .section = 0,
            });
        } else unreachable;
    }
}

fn resolveSymbols(self: *Zld) !void {
    // First pass, resolve symbols in provided objects.
    for (self.objects.items) |object, object_id| {
        try self.resolveSymbolsInObject(@intCast(u16, object_id));
    }

    // Second pass, resolve symbols in static libraries.
    var next_sym: usize = 0;
    var nsyms: usize = self.symtab.items().len;
    while (next_sym < nsyms) : (next_sym += 1) {
        const sym = self.symtab.items()[next_sym];
        if (sym.value.tag != .undef) continue;

        const sym_name = sym.value.name;
        for (self.archives.items) |archive| {
            // Check if the entry exists in a static archive.
            const offsets = archive.toc.get(sym_name) orelse {
                // No hit.
                continue;
            };
            assert(offsets.items.len > 0);

            const object = try archive.parseObject(offsets.items[0]);
            const object_id = @intCast(u16, self.objects.items.len);
            try self.objects.append(self.allocator, object);
            try self.resolveSymbolsInObject(object_id);

            nsyms = self.symtab.items().len;
            break;
        }
    }

    // Third pass, resolve symbols in dynamic libraries.
    // TODO Implement libSystem as a hard-coded library, or ship with
    // a libSystem.B.tbd definition file?
    for (self.symtab.items()) |*entry| {
        if (entry.value.tag != .undef) continue;

        entry.value.tag = .import;
        entry.value.file = 0;
    }

    // If there are any undefs left, flag an error.
    var has_unresolved = false;
    for (self.symtab.items()) |entry| {
        if (entry.value.tag != .undef) continue;

        has_unresolved = true;
        log.err("undefined reference to symbol '{s}'", .{entry.value.name});
    }
    if (has_unresolved) {
        return error.UndefinedSymbolReference;
    }

    // Finally put dyld_stub_binder as an Import
    var name = try self.allocator.dupe(u8, "dyld_stub_binder");
    try self.symtab.putNoClobber(self.allocator, name, .{
        .tag = .import,
        .name = name,
        .address = 0,
        .section = 0,
        .file = 0,
    });
}

fn resolveStubsAndGotEntries(self: *Zld) !void {
    for (self.objects.items) |object, object_id| {
        log.debug("resolving stubs and got entries from {s}", .{object.name});

        for (object.sections.items) |sect| {
            const relocs = sect.relocs orelse continue;
            for (relocs) |rel| {
                switch (rel.@"type") {
                    .unsigned => continue,
                    .got_page, .got_page_off, .got_load, .got => {
                        const sym = object.symtab.items[rel.target.symbol];
                        const sym_name = object.getString(sym.n_strx);

                        if (self.got_entries.contains(sym_name)) continue;

                        // TODO clean this up
                        const is_import = self.symtab.get(sym_name).?.tag == .import;
                        var name = try self.allocator.dupe(u8, sym_name);
                        const index = @intCast(u32, self.got_entries.items().len);
                        try self.got_entries.putNoClobber(self.allocator, name, .{
                            .tag = if (is_import) .import else .local,
                            .index = index,
                            .target_addr = 0,
                            .file = if (is_import) 0 else @intCast(u16, object_id),
                        });

                        log.debug("    | found GOT entry {s}: {}", .{ sym_name, self.got_entries.get(sym_name) });
                    },
                    else => {
                        if (rel.target != .symbol) continue;

                        const sym = object.symtab.items[rel.target.symbol];
                        const sym_name = object.getString(sym.n_strx);

                        if (!Symbol.isUndef(sym)) continue;

                        const in_globals = self.symtab.get(sym_name) orelse unreachable;

                        if (in_globals.tag != .import) continue;
                        if (self.stubs.contains(sym_name)) continue;

                        var name = try self.allocator.dupe(u8, sym_name);
                        const index = @intCast(u32, self.stubs.items().len);
                        try self.stubs.putNoClobber(self.allocator, name, index);

                        log.debug("    | found stub {s}: {}", .{ sym_name, self.stubs.get(sym_name) });
                    },
                }
            }
        }
    }

    // Finally, put dyld_stub_binder as the final GOT entry
    var name = try self.allocator.dupe(u8, "dyld_stub_binder");
    const index = @intCast(u32, self.got_entries.items().len);
    try self.got_entries.putNoClobber(self.allocator, name, .{
        .tag = .import,
        .index = index,
        .target_addr = 0,
        .file = 0,
    });

    log.debug("    | found GOT entry dyld_stub_binder: {}", .{self.got_entries.get("dyld_stub_binder")});
}

fn resolveRelocsAndWriteSections(self: *Zld) !void {
    for (self.objects.items) |object, object_id| {
        log.debug("relocating object {s}", .{object.name});

        for (object.sections.items) |sect, source_sect_id| {
            const segname = parseName(&sect.inner.segname);
            const sectname = parseName(&sect.inner.sectname);

            // Get mapping
            const target_mapping = self.mappings.get(.{
                .object_id = @intCast(u16, object_id),
                .source_sect_id = @intCast(u16, source_sect_id),
            }) orelse {
                log.debug("no mapping for {s},{s}; skipping", .{ segname, sectname });
                continue;
            };
            const target_seg = self.load_commands.items[target_mapping.target_seg_id].Segment;
            const target_sect = target_seg.sections.items[target_mapping.target_sect_id];
            const target_sect_addr = target_sect.addr + target_mapping.offset;
            const target_sect_off = target_sect.offset + target_mapping.offset;

            if (sect.relocs) |relocs| {
                for (relocs) |rel| {
                    const source_addr = target_sect_addr + rel.offset;

                    var args: reloc.Relocation.ResolveArgs = .{
                        .source_addr = source_addr,
                        .target_addr = undefined,
                    };

                    switch (rel.@"type") {
                        .unsigned => {
                            args.target_addr = try self.relocTargetAddr(@intCast(u16, object_id), rel.target);

                            const unsigned = rel.cast(reloc.Unsigned) orelse unreachable;
                            if (unsigned.subtractor) |subtractor| {
                                args.subtractor = try self.relocTargetAddr(@intCast(u16, object_id), subtractor);
                            }
                            if (rel.target == .section) {
                                const source_sect = object.sections.items[rel.target.section];
                                args.source_sect_addr = source_sect.inner.addr;
                            }

                            rebases: {
                                var hit: bool = false;
                                if (target_mapping.target_seg_id == self.data_segment_cmd_index.?) {
                                    if (self.data_section_index) |index| {
                                        if (index == target_mapping.target_sect_id) hit = true;
                                    }
                                }
                                if (target_mapping.target_seg_id == self.data_const_segment_cmd_index.?) {
                                    if (self.data_const_section_index) |index| {
                                        if (index == target_mapping.target_sect_id) hit = true;
                                    }
                                }

                                if (!hit) break :rebases;

                                try self.local_rebases.append(self.allocator, .{
                                    .offset = source_addr - target_seg.inner.vmaddr,
                                    .segment_id = target_mapping.target_seg_id,
                                });
                            }
                            // TLV is handled via a separate offset mechanism.
                            // Calculate the offset to the initializer.
                            if (target_sect.flags == macho.S_THREAD_LOCAL_VARIABLES) tlv: {
                                const sym = object.symtab.items[rel.target.symbol];
                                const sym_name = object.getString(sym.n_strx);

                                // TODO we don't want to save offset to tlv_bootstrap
                                if (mem.eql(u8, sym_name, "__tlv_bootstrap")) break :tlv;

                                const base_addr = blk: {
                                    if (self.tlv_data_section_index) |index| {
                                        const tlv_data = target_seg.sections.items[index];
                                        break :blk tlv_data.addr;
                                    } else {
                                        const tlv_bss = target_seg.sections.items[self.tlv_bss_section_index.?];
                                        break :blk tlv_bss.addr;
                                    }
                                };
                                // Since we require TLV data to always preceed TLV bss section, we calculate
                                // offsets wrt to the former if it is defined; otherwise, wrt to the latter.
                                try self.threadlocal_offsets.append(self.allocator, args.target_addr - base_addr);
                            }
                        },
                        .got_page, .got_page_off, .got_load, .got => {
                            const dc_seg = self.load_commands.items[self.data_const_segment_cmd_index.?].Segment;
                            const got = dc_seg.sections.items[self.got_section_index.?];
                            const sym = object.symtab.items[rel.target.symbol];
                            const sym_name = object.getString(sym.n_strx);
                            const entry = self.got_entries.get(sym_name) orelse unreachable;
                            args.target_addr = got.addr + entry.index * @sizeOf(u64);
                        },
                        else => |tt| {
                            if (tt == .signed and rel.target == .section) {
                                const source_sect = object.sections.items[rel.target.section];
                                args.source_sect_addr = source_sect.inner.addr;
                            }
                            args.target_addr = try self.relocTargetAddr(@intCast(u16, object_id), rel.target);
                        },
                    }

                    try rel.resolve(args);
                }
            }

            log.debug("writing contents of '{s},{s}' section from '{s}' from 0x{x} to 0x{x}", .{
                segname,
                sectname,
                object.name,
                target_sect_off,
                target_sect_off + sect.code.len,
            });

            if (target_sect.flags == macho.S_ZEROFILL or
                target_sect.flags == macho.S_THREAD_LOCAL_ZEROFILL or
                target_sect.flags == macho.S_THREAD_LOCAL_VARIABLES)
            {
                log.debug("zeroing out '{s},{s}' from 0x{x} to 0x{x}", .{
                    parseName(&target_sect.segname),
                    parseName(&target_sect.sectname),
                    target_sect_off,
                    target_sect_off + sect.code.len,
                });
                // Zero-out the space
                var zeroes = try self.allocator.alloc(u8, sect.code.len);
                defer self.allocator.free(zeroes);
                mem.set(u8, zeroes, 0);
                try self.file.?.pwriteAll(zeroes, target_sect_off);
            } else {
                try self.file.?.pwriteAll(sect.code, target_sect_off);
            }
        }
    }
}

fn relocTargetAddr(self: *Zld, object_id: u16, target: reloc.Relocation.Target) !u64 {
    const object = self.objects.items[object_id];
    const target_addr = blk: {
        switch (target) {
            .symbol => |sym_id| {
                const sym = object.symtab.items[sym_id];
                const sym_name = object.getString(sym.n_strx);

                if (Symbol.isSect(sym)) {
                    log.debug("    | local symbol '{s}'", .{sym_name});
                    if (object.locals.get(sym_name)) |local| {
                        break :blk local.address;
                    }
                    // For temp locals, i.e., symbols prefixed with l... we relocate
                    // based on section addressing.
                    const source_sect_id = sym.n_sect - 1;
                    const target_mapping = self.mappings.get(.{
                        .object_id = object_id,
                        .source_sect_id = source_sect_id,
                    }) orelse unreachable;

                    const source_seg = object.load_commands.items[object.segment_cmd_index.?].Segment;
                    const source_sect = source_seg.sections.items[source_sect_id];
                    const target_seg = self.load_commands.items[target_mapping.target_seg_id].Segment;
                    const target_sect = target_seg.sections.items[target_mapping.target_sect_id];
                    const target_addr = target_sect.addr + target_mapping.offset;
                    break :blk sym.n_value - source_sect.addr + target_addr;
                } else {
                    if (self.stubs.get(sym_name)) |index| {
                        log.debug("    | symbol stub '{s}'", .{sym_name});
                        const segment = self.load_commands.items[self.text_segment_cmd_index.?].Segment;
                        const stubs = segment.sections.items[self.stubs_section_index.?];
                        break :blk stubs.addr + index * stubs.reserved2;
                    } else if (mem.eql(u8, sym_name, "__tlv_bootstrap")) {
                        log.debug("    | symbol '__tlv_bootstrap'", .{});
                        const segment = self.load_commands.items[self.data_segment_cmd_index.?].Segment;
                        const tlv = segment.sections.items[self.tlv_section_index.?];
                        break :blk tlv.addr;
                    } else {
                        const global = self.symtab.get(sym_name) orelse {
                            log.err("failed to resolve symbol '{s}' as a relocation target", .{sym_name});
                            return error.FailedToResolveRelocationTarget;
                        };
                        log.debug("    | global symbol '{s}'", .{sym_name});
                        break :blk global.address;
                    }
                }
            },
            .section => |sect_id| {
                const target_mapping = self.mappings.get(.{
                    .object_id = object_id,
                    .source_sect_id = sect_id,
                }) orelse unreachable;
                const target_seg = self.load_commands.items[target_mapping.target_seg_id].Segment;
                const target_sect = target_seg.sections.items[target_mapping.target_sect_id];
                break :blk target_sect.addr + target_mapping.offset;
            },
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
    }

    if (self.text_section_index == null) {
        const text_seg = &self.load_commands.items[self.text_segment_cmd_index.?].Segment;
        self.text_section_index = @intCast(u16, text_seg.sections.items.len);
        const alignment: u2 = switch (self.arch.?) {
            .x86_64 => 0,
            .aarch64 => 2,
            else => unreachable, // unhandled architecture type
        };
        try text_seg.addSection(self.allocator, .{
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
            .aarch64 => 3 * @sizeOf(u32),
            else => unreachable, // unhandled architecture type
        };
        try text_seg.addSection(self.allocator, .{
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
    }

    if (self.stub_helper_section_index == null) {
        const text_seg = &self.load_commands.items[self.text_segment_cmd_index.?].Segment;
        self.stub_helper_section_index = @intCast(u16, text_seg.sections.items.len);
        const alignment: u2 = switch (self.arch.?) {
            .x86_64 => 0,
            .aarch64 => 2,
            else => unreachable, // unhandled architecture type
        };
        const stub_helper_size: u6 = switch (self.arch.?) {
            .x86_64 => 15,
            .aarch64 => 6 * @sizeOf(u32),
            else => unreachable,
        };
        try text_seg.addSection(self.allocator, .{
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
    }

    if (self.data_const_segment_cmd_index == null) {
        self.data_const_segment_cmd_index = @intCast(u16, self.load_commands.items.len);
        try self.load_commands.append(self.allocator, .{
            .Segment = SegmentCommand.empty(.{
                .cmd = macho.LC_SEGMENT_64,
                .cmdsize = @sizeOf(macho.segment_command_64),
                .segname = makeStaticString("__DATA_CONST"),
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
    }

    if (self.got_section_index == null) {
        const data_const_seg = &self.load_commands.items[self.data_const_segment_cmd_index.?].Segment;
        self.got_section_index = @intCast(u16, data_const_seg.sections.items.len);
        try data_const_seg.addSection(self.allocator, .{
            .sectname = makeStaticString("__got"),
            .segname = makeStaticString("__DATA_CONST"),
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
    }

    if (self.la_symbol_ptr_section_index == null) {
        const data_seg = &self.load_commands.items[self.data_segment_cmd_index.?].Segment;
        self.la_symbol_ptr_section_index = @intCast(u16, data_seg.sections.items.len);
        try data_seg.addSection(self.allocator, .{
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
    }

    if (self.data_section_index == null) {
        const data_seg = &self.load_commands.items[self.data_segment_cmd_index.?].Segment;
        self.data_section_index = @intCast(u16, data_seg.sections.items.len);
        try data_seg.addSection(self.allocator, .{
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

    if (self.data_in_code_cmd_index == null and self.arch.? == .x86_64) {
        self.data_in_code_cmd_index = @intCast(u16, self.load_commands.items.len);
        try self.load_commands.append(self.allocator, .{
            .LinkeditData = .{
                .cmd = macho.LC_DATA_IN_CODE,
                .cmdsize = @sizeOf(macho.linkedit_data_command),
                .dataoff = 0,
                .datasize = 0,
            },
        });
    }
}

fn flush(self: *Zld) !void {
    if (self.bss_section_index) |index| {
        const seg = &self.load_commands.items[self.data_segment_cmd_index.?].Segment;
        const sect = &seg.sections.items[index];
        sect.offset = 0;
    }

    if (self.tlv_bss_section_index) |index| {
        const seg = &self.load_commands.items[self.data_segment_cmd_index.?].Segment;
        const sect = &seg.sections.items[index];
        sect.offset = 0;
    }

    if (self.tlv_section_index) |index| {
        const seg = self.load_commands.items[self.data_segment_cmd_index.?].Segment;
        const sect = &seg.sections.items[index];

        var buffer = try self.allocator.alloc(u8, sect.size);
        defer self.allocator.free(buffer);
        _ = try self.file.?.preadAll(buffer, sect.offset);

        var stream = std.io.fixedBufferStream(buffer);
        var writer = stream.writer();

        const seek_amt = 2 * @sizeOf(u64);
        while (self.threadlocal_offsets.popOrNull()) |offset| {
            try writer.context.seekBy(seek_amt);
            try writer.writeIntLittle(u64, offset);
        }

        try self.file.?.pwriteAll(buffer, sect.offset);
    }

    try self.writeGotEntries();
    try self.setEntryPoint();
    try self.writeRebaseInfoTable();
    try self.writeBindInfoTable();
    try self.writeLazyBindInfoTable();
    try self.writeExportInfo();
    if (self.arch.? == .x86_64) {
        try self.writeDataInCode();
    }

    {
        const seg = &self.load_commands.items[self.linkedit_segment_cmd_index.?].Segment;
        const symtab = &self.load_commands.items[self.symtab_cmd_index.?].Symtab;
        symtab.symoff = @intCast(u32, seg.inner.fileoff + seg.inner.filesize);
    }

    try self.writeDebugInfo();
    try self.writeSymbolTable();
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

fn writeGotEntries(self: *Zld) !void {
    const seg = self.load_commands.items[self.data_const_segment_cmd_index.?].Segment;
    const sect = seg.sections.items[self.got_section_index.?];

    var buffer = try self.allocator.alloc(u8, self.got_entries.items().len * @sizeOf(u64));
    defer self.allocator.free(buffer);

    var stream = std.io.fixedBufferStream(buffer);
    var writer = stream.writer();

    for (self.got_entries.items()) |entry| {
        try writer.writeIntLittle(u64, entry.value.target_addr);
    }

    log.debug("writing GOT pointers at 0x{x} to 0x{x}", .{ sect.offset, sect.offset + buffer.len });

    try self.file.?.pwriteAll(buffer, sect.offset);
}

fn setEntryPoint(self: *Zld) !void {
    // TODO we should respect the -entry flag passed in by the user to set a custom
    // entrypoint. For now, assume default of `_main`.
    const seg = self.load_commands.items[self.text_segment_cmd_index.?].Segment;
    const text = seg.sections.items[self.text_section_index.?];
    const entry_sym = self.symtab.get("_main") orelse return error.MissingMainEntrypoint;
    const ec = &self.load_commands.items[self.main_cmd_index.?].Main;
    ec.entryoff = @intCast(u32, entry_sym.address - seg.inner.vmaddr);
}

fn writeRebaseInfoTable(self: *Zld) !void {
    var pointers = std.ArrayList(Pointer).init(self.allocator);
    defer pointers.deinit();

    try pointers.ensureCapacity(self.local_rebases.items.len);
    pointers.appendSliceAssumeCapacity(self.local_rebases.items);

    if (self.got_section_index) |idx| {
        // TODO this should be cleaned up!
        const seg = self.load_commands.items[self.data_const_segment_cmd_index.?].Segment;
        const sect = seg.sections.items[idx];
        const base_offset = sect.addr - seg.inner.vmaddr;
        const segment_id = @intCast(u16, self.data_const_segment_cmd_index.?);

        for (self.got_entries.items()) |entry| {
            if (entry.value.tag == .import) continue;

            try pointers.append(.{
                .offset = base_offset + entry.value.index * @sizeOf(u64),
                .segment_id = segment_id,
            });
        }
    }

    if (self.mod_init_func_section_index) |idx| {
        // TODO audit and investigate this.
        const seg = self.load_commands.items[self.data_const_segment_cmd_index.?].Segment;
        const sect = seg.sections.items[idx];
        const npointers = sect.size * @sizeOf(u64);
        const base_offset = sect.addr - seg.inner.vmaddr;
        const segment_id = @intCast(u16, self.data_const_segment_cmd_index.?);

        try pointers.ensureCapacity(pointers.items.len + npointers);
        var i: usize = 0;
        while (i < npointers) : (i += 1) {
            pointers.appendAssumeCapacity(.{
                .offset = base_offset + i * @sizeOf(u64),
                .segment_id = segment_id,
            });
        }
    }

    if (self.mod_term_func_section_index) |idx| {
        // TODO audit and investigate this.
        const seg = self.load_commands.items[self.data_const_segment_cmd_index.?].Segment;
        const sect = seg.sections.items[idx];
        const npointers = sect.size * @sizeOf(u64);
        const base_offset = sect.addr - seg.inner.vmaddr;
        const segment_id = @intCast(u16, self.data_const_segment_cmd_index.?);

        try pointers.ensureCapacity(pointers.items.len + npointers);
        var i: usize = 0;
        while (i < npointers) : (i += 1) {
            pointers.appendAssumeCapacity(.{
                .offset = base_offset + i * @sizeOf(u64),
                .segment_id = segment_id,
            });
        }
    }

    if (self.la_symbol_ptr_section_index) |idx| {
        const seg = self.load_commands.items[self.data_segment_cmd_index.?].Segment;
        const sect = seg.sections.items[idx];
        const base_offset = sect.addr - seg.inner.vmaddr;
        const segment_id = @intCast(u16, self.data_segment_cmd_index.?);

        try pointers.ensureCapacity(pointers.items.len + self.stubs.items().len);
        for (self.stubs.items()) |entry| {
            pointers.appendAssumeCapacity(.{
                .offset = base_offset + entry.value * @sizeOf(u64),
                .segment_id = segment_id,
            });
        }
    }

    std.sort.sort(Pointer, pointers.items, {}, pointerCmp);

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
    var pointers = std.ArrayList(Pointer).init(self.allocator);
    defer pointers.deinit();

    if (self.got_section_index) |idx| {
        const seg = self.load_commands.items[self.data_const_segment_cmd_index.?].Segment;
        const sect = seg.sections.items[idx];
        const base_offset = sect.addr - seg.inner.vmaddr;
        const segment_id = @intCast(u16, self.data_const_segment_cmd_index.?);

        for (self.got_entries.items()) |entry| {
            if (entry.value.tag == .local) continue;

            const dylib_ordinal = dylib_ordinal: {
                const sym = self.symtab.get(entry.key) orelse continue; // local indirection
                if (sym.tag != .import) continue; // local indirection
                break :dylib_ordinal sym.file.? + 1;
            };

            try pointers.append(.{
                .offset = base_offset + entry.value.index * @sizeOf(u64),
                .segment_id = segment_id,
                .dylib_ordinal = dylib_ordinal,
                .name = entry.key,
            });
        }
    }

    if (self.tlv_section_index) |idx| {
        const seg = self.load_commands.items[self.data_segment_cmd_index.?].Segment;
        const sect = seg.sections.items[idx];
        const base_offset = sect.addr - seg.inner.vmaddr;
        const segment_id = @intCast(u16, self.data_segment_cmd_index.?);

        const sym = self.symtab.get("__tlv_bootstrap") orelse unreachable;
        const dylib_ordinal = sym.file.? + 1;

        try pointers.append(.{
            .offset = base_offset,
            .segment_id = segment_id,
            .dylib_ordinal = dylib_ordinal,
            .name = "__tlv_bootstrap",
        });
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
    var pointers = std.ArrayList(Pointer).init(self.allocator);
    defer pointers.deinit();

    if (self.la_symbol_ptr_section_index) |idx| {
        const seg = self.load_commands.items[self.data_segment_cmd_index.?].Segment;
        const sect = seg.sections.items[idx];
        const base_offset = sect.addr - seg.inner.vmaddr;
        const segment_id = @intCast(u16, self.data_segment_cmd_index.?);

        try pointers.ensureCapacity(self.stubs.items().len);

        for (self.stubs.items()) |entry| {
            const dylib_ordinal = dylib_ordinal: {
                const sym = self.symtab.get(entry.key) orelse unreachable;
                assert(sym.tag == .import);
                break :dylib_ordinal sym.file.? + 1;
            };

            pointers.appendAssumeCapacity(.{
                .offset = base_offset + entry.value * @sizeOf(u64),
                .segment_id = segment_id,
                .dylib_ordinal = dylib_ordinal,
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
    assert(self.stubs.items().len <= offsets.items.len);

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
    for (self.stubs.items()) |entry| {
        const placeholder_off = self.stub_helper_stubs_start_off.? + entry.value * stub_size + off;
        mem.writeIntLittle(u32, &buf, offsets.items[entry.value]);
        try self.file.?.pwriteAll(&buf, placeholder_off);
    }
}

fn writeExportInfo(self: *Zld) !void {
    var trie = Trie.init(self.allocator);
    defer trie.deinit();

    const text_segment = self.load_commands.items[self.text_segment_cmd_index.?].Segment;

    // TODO export items for dylibs
    const sym = self.symtab.get("_main") orelse return error.MissingMainEntrypoint;
    assert(sym.address >= text_segment.inner.vmaddr);

    try trie.put(.{
        .name = "_main",
        .vmaddr_offset = sym.address - text_segment.inner.vmaddr,
        .export_flags = macho.EXPORT_SYMBOL_FLAGS_KIND_REGULAR,
    });

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

    for (self.objects.items) |object, object_id| {
        const tu_path = object.tu_path orelse continue;
        const tu_mtime = object.tu_mtime orelse continue;
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
        try stabs.append(.{
            .n_strx = try self.makeString(object.name.?),
            .n_type = macho.N_OSO,
            .n_sect = 0,
            .n_desc = 1,
            .n_value = tu_mtime,
        });

        for (object.stabs.items) |stab| {
            const entry = object.locals.items()[stab.symbol];
            const sym = entry.value;

            switch (stab.tag) {
                .function => {
                    try stabs.append(.{
                        .n_strx = 0,
                        .n_type = macho.N_BNSYM,
                        .n_sect = sym.section,
                        .n_desc = 0,
                        .n_value = sym.address,
                    });
                    try stabs.append(.{
                        .n_strx = try self.makeString(sym.name),
                        .n_type = macho.N_FUN,
                        .n_sect = sym.section,
                        .n_desc = 0,
                        .n_value = sym.address,
                    });
                    try stabs.append(.{
                        .n_strx = 0,
                        .n_type = macho.N_FUN,
                        .n_sect = 0,
                        .n_desc = 0,
                        .n_value = stab.size.?,
                    });
                    try stabs.append(.{
                        .n_strx = 0,
                        .n_type = macho.N_ENSYM,
                        .n_sect = sym.section,
                        .n_desc = 0,
                        .n_value = stab.size.?,
                    });
                },
                .global => {
                    try stabs.append(.{
                        .n_strx = try self.makeString(sym.name),
                        .n_type = macho.N_GSYM,
                        .n_sect = 0,
                        .n_desc = 0,
                        .n_value = 0,
                    });
                },
                .static => {
                    try stabs.append(.{
                        .n_strx = try self.makeString(sym.name),
                        .n_type = macho.N_STSYM,
                        .n_sect = sym.section,
                        .n_desc = 0,
                        .n_value = sym.address,
                    });
                },
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

fn populateStringTable(self: *Zld) !void {
    for (self.objects.items) |*object| {
        for (object.symtab.items) |*sym| {
            switch (sym.tag) {
                .undef, .import => continue,
                else => {},
            }
            const sym_name = object.getString(sym.inner.n_strx);
            const n_strx = try self.makeString(sym_name);
            sym.inner.n_strx = n_strx;
        }
    }

    for (self.symtab.items()) |*entry| {
        if (entry.value.tag != .import) continue;

        const n_strx = try self.makeString(entry.key);
        entry.value.inner.n_strx = n_strx;
    }
}

fn writeSymbolTable(self: *Zld) !void {
    const seg = &self.load_commands.items[self.linkedit_segment_cmd_index.?].Segment;
    const symtab = &self.load_commands.items[self.symtab_cmd_index.?].Symtab;

    var locals = std.ArrayList(macho.nlist_64).init(self.allocator);
    defer locals.deinit();

    for (self.objects.items) |object| {
        for (object.locals.items()) |entry| {
            const sym = entry.value;
            if (sym.tag != .local) continue;

            try locals.append(.{
                .n_strx = try self.makeString(sym.name),
                .n_type = macho.N_SECT,
                .n_sect = sym.section,
                .n_desc = 0,
                .n_value = sym.address,
            });
        }
    }

    var exports = std.ArrayList(macho.nlist_64).init(self.allocator);
    defer exports.deinit();

    var undefs = std.ArrayList(macho.nlist_64).init(self.allocator);
    defer undefs.deinit();

    var undefs_ids = std.StringHashMap(u32).init(self.allocator);
    defer undefs_ids.deinit();

    var undef_id: u32 = 0;
    for (self.symtab.items()) |entry| {
        const sym = entry.value;
        switch (sym.tag) {
            .weak, .strong => {
                try exports.append(.{
                    .n_strx = try self.makeString(sym.name),
                    .n_type = macho.N_SECT | macho.N_EXT,
                    .n_sect = sym.section,
                    .n_desc = 0,
                    .n_value = sym.address,
                });
            },
            .import => {
                try undefs.append(.{
                    .n_strx = try self.makeString(sym.name),
                    .n_type = macho.N_UNDF | macho.N_EXT,
                    .n_sect = 0,
                    .n_desc = macho.N_SYMBOL_RESOLVER | macho.REFERENCE_FLAG_UNDEFINED_NON_LAZY,
                    .n_value = 0,
                });
                try undefs_ids.putNoClobber(sym.name, undef_id);
                undef_id += 1;
            },
            else => unreachable,
        }
    }

    const nlocals = locals.items.len;
    const nexports = exports.items.len;
    const nundefs = undefs.items.len;

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

    const text_segment = &self.load_commands.items[self.text_segment_cmd_index.?].Segment;
    const stubs = &text_segment.sections.items[self.stubs_section_index.?];
    const data_const_segment = &self.load_commands.items[self.data_const_segment_cmd_index.?].Segment;
    const got = &data_const_segment.sections.items[self.got_section_index.?];
    const data_segment = &self.load_commands.items[self.data_segment_cmd_index.?].Segment;
    const la_symbol_ptr = &data_segment.sections.items[self.la_symbol_ptr_section_index.?];

    const nstubs = @intCast(u32, self.stubs.items().len);
    const ngot_entries = @intCast(u32, self.got_entries.items().len);

    dysymtab.indirectsymoff = @intCast(u32, seg.inner.fileoff + seg.inner.filesize);
    dysymtab.nindirectsyms = nstubs * 2 + ngot_entries;

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
    for (self.stubs.items()) |entry| {
        const id = undefs_ids.get(entry.key) orelse unreachable;
        try writer.writeIntLittle(u32, dysymtab.iundefsym + id);
    }

    got.reserved1 = nstubs;
    for (self.got_entries.items()) |entry| {
        if (entry.value.tag == .import) {
            const id = undefs_ids.get(entry.key) orelse unreachable;
            try writer.writeIntLittle(u32, dysymtab.iundefsym + id);
        } else {
            try writer.writeIntLittle(u32, macho.INDIRECT_SYMBOL_LOCAL);
        }
    }

    la_symbol_ptr.reserved1 = got.reserved1 + ngot_entries;
    for (self.stubs.items()) |entry| {
        const id = undefs_ids.get(entry.key) orelse unreachable;
        try writer.writeIntLittle(u32, dysymtab.iundefsym + id);
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

fn writeDataInCode(self: *Zld) !void {
    const seg = &self.load_commands.items[self.linkedit_segment_cmd_index.?].Segment;
    const dice_cmd = &self.load_commands.items[self.data_in_code_cmd_index.?].LinkeditData;
    const fileoff = seg.inner.fileoff + seg.inner.filesize;

    var buf = std.ArrayList(u8).init(self.allocator);
    defer buf.deinit();

    const text_seg = self.load_commands.items[self.text_segment_cmd_index.?].Segment;
    const text_sect = text_seg.sections.items[self.text_section_index.?];
    for (self.objects.items) |object, object_id| {
        const source_seg = object.load_commands.items[object.segment_cmd_index.?].Segment;
        const source_sect = source_seg.sections.items[object.text_section_index.?];
        const target_mapping = self.mappings.get(.{
            .object_id = @intCast(u16, object_id),
            .source_sect_id = object.text_section_index.?,
        }) orelse continue;

        try buf.ensureCapacity(
            buf.items.len + object.data_in_code_entries.items.len * @sizeOf(macho.data_in_code_entry),
        );
        for (object.data_in_code_entries.items) |dice| {
            const new_dice: macho.data_in_code_entry = .{
                .offset = text_sect.offset + target_mapping.offset + dice.offset,
                .length = dice.length,
                .kind = dice.kind,
            };
            buf.appendSliceAssumeCapacity(mem.asBytes(&new_dice));
        }
    }
    const datasize = @intCast(u32, buf.items.len);

    dice_cmd.dataoff = @intCast(u32, fileoff);
    dice_cmd.datasize = datasize;
    seg.inner.filesize += datasize;

    log.debug("writing data-in-code from 0x{x} to 0x{x}", .{ fileoff, fileoff + datasize });

    try self.file.?.pwriteAll(buf.items, fileoff);
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
    if (self.strtab_dir.get(bytes)) |offset| {
        log.debug("reusing '{s}' from string table at offset 0x{x}", .{ bytes, offset });
        return offset;
    }

    try self.strtab.ensureCapacity(self.allocator, self.strtab.items.len + bytes.len + 1);
    const offset = @intCast(u32, self.strtab.items.len);
    log.debug("writing new string '{s}' into string table at offset 0x{x}", .{ bytes, offset });
    self.strtab.appendSliceAssumeCapacity(bytes);
    self.strtab.appendAssumeCapacity(0);
    try self.strtab_dir.putNoClobber(self.allocator, try self.allocator.dupe(u8, bytes), offset);
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
