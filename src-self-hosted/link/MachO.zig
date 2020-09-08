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

const LoadCommand = union(enum) {
    Segment: macho.segment_command_64,
    LinkeditData: macho.linkedit_data_command,
    Symtab: macho.symtab_command,
    Dysymtab: macho.dysymtab_command,

    pub fn cmdsize(self: LoadCommand) u32 {
        return switch (self) {
            .Segment => |x| x.cmdsize,
            .LinkeditData => |x| x.cmdsize,
            .Symtab => |x| x.cmdsize,
            .Dysymtab => |x| x.cmdsize,
        };
    }

    pub fn write(self: LoadCommand, file: *fs.File, offset: u64) !void {
        return switch (self) {
            .Segment => |cmd| writeGeneric(cmd, file, offset),
            .LinkeditData => |cmd| writeGeneric(cmd, file, offset),
            .Symtab => |cmd| writeGeneric(cmd, file, offset),
            .Dysymtab => |cmd| writeGeneric(cmd, file, offset),
        };
    }

    fn writeGeneric(cmd: anytype, file: *fs.File, offset: u64) !void {
        const slice = [1]@TypeOf(cmd){cmd};
        return file.pwriteAll(mem.sliceAsBytes(slice[0..1]), offset);
    }
};

base: File,

/// Table of all load commands
load_commands: std.ArrayListUnmanaged(LoadCommand) = .{},
segment_cmd_index: ?u16 = null,
symtab_cmd_index: ?u16 = null,
dysymtab_cmd_index: ?u16 = null,
data_in_code_cmd_index: ?u16 = null,

/// Table of all sections
sections: std.ArrayListUnmanaged(macho.section_64) = .{},

/// __TEXT segment sections
text_section_index: ?u16 = null,
cstring_section_index: ?u16 = null,
const_text_section_index: ?u16 = null,
stubs_section_index: ?u16 = null,
stub_helper_section_index: ?u16 = null,

/// __DATA segment sections
got_section_index: ?u16 = null,
const_data_section_index: ?u16 = null,

entry_addr: ?u64 = null,

/// Table of all symbols used.
/// Internally references string table for names (which are optional).
symbol_table: std.ArrayListUnmanaged(macho.nlist_64) = .{},

/// Table of symbol names aka the string table.
string_table: std.ArrayListUnmanaged(u8) = .{},

/// Table of symbol vaddr values. The values is the absolute vaddr value.
/// If the vaddr of the executable __TEXT segment vaddr changes, the entire offset
/// table needs to be rewritten.
offset_table: std.ArrayListUnmanaged(u64) = .{},

error_flags: File.ErrorFlags = File.ErrorFlags{},

cmd_table_dirty: bool = false,

/// Pointer to the last allocated text block
last_text_block: ?*TextBlock = null,

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
    /// Index into the symbol table
    symbol_table_index: ?u32,
    /// Index into offset table
    offset_table_index: ?u32,
    /// Size of this text block
    size: u64,
    /// Points to the previous and next neighbours
    prev: ?*TextBlock,
    next: ?*TextBlock,

    pub const empty = TextBlock{
        .symbol_table_index = null,
        .offset_table_index = null,
        .size = 0,
        .prev = null,
        .next = null,
    };
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

    try self.populateMissingMetadata();

    return self;
}

pub fn flush(self: *MachO, module: *Module) !void {
    switch (self.base.options.output_mode) {
        .Exe => {
            var last_cmd_offset: usize = @sizeOf(macho.mach_header_64);
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

                try self.base.file.?.pwriteAll(mem.sliceAsBytes(load_dylinker[0..1]), last_cmd_offset);

                const file_offset = last_cmd_offset + @sizeOf(macho.dylinker_command);
                try self.addPadding(cmdsize - @sizeOf(macho.dylinker_command), file_offset);

                try self.base.file.?.pwriteAll(mem.spanZ(DEFAULT_DYLD_PATH), file_offset);
                last_cmd_offset += cmdsize;
            }

            {
                // Link against libSystem
                const cmdsize = commandSize(@sizeOf(macho.dylib_command) + mem.lenZ(LIB_SYSTEM_PATH));
                // TODO Find a way to work out runtime version from the OS version triple stored in std.Target.
                // In the meantime, we're gonna hardcode to the minimum compatibility version of 1.0.0.
                const min_version = 0x10000;
                const dylib = .{
                    .name = @sizeOf(macho.dylib_command),
                    .timestamp = 2, // not sure why not simply 0; this is reverse engineered from Mach-O files
                    .current_version = min_version,
                    .compatibility_version = min_version,
                };
                const load_dylib = [1]macho.dylib_command{
                    .{
                        .cmd = macho.LC_LOAD_DYLIB,
                        .cmdsize = cmdsize,
                        .dylib = dylib,
                    },
                };

                try self.base.file.?.pwriteAll(mem.sliceAsBytes(load_dylib[0..1]), last_cmd_offset);

                const file_offset = last_cmd_offset + @sizeOf(macho.dylib_command);
                try self.addPadding(cmdsize - @sizeOf(macho.dylib_command), file_offset);

                try self.base.file.?.pwriteAll(mem.spanZ(LIB_SYSTEM_PATH), file_offset);
                last_cmd_offset += cmdsize;
            }
        },
        .Obj => {
            {
                const symtab = &self.load_commands.items[self.symtab_cmd_index.?].Symtab;
                symtab.nsyms = @intCast(u32, self.symbol_table.items.len);
                const allocated_size = self.allocatedSize(symtab.stroff);
                const needed_size = self.string_table.items.len;
                log.debug("allocated_size = 0x{x}, needed_size = 0x{x}\n", .{ allocated_size, needed_size });

                if (needed_size > allocated_size) {
                    symtab.strsize = 0;
                    symtab.stroff = @intCast(u32, self.findFreeSpace(needed_size, 1));
                }
                symtab.strsize = @intCast(u32, needed_size);

                log.debug("writing string table from 0x{x} to 0x{x}\n", .{ symtab.stroff, symtab.stroff + symtab.strsize });

                try self.base.file.?.pwriteAll(self.string_table.items, symtab.stroff);
            }

            var last_cmd_offset: usize = @sizeOf(macho.mach_header_64);
            for (self.load_commands.items) |cmd| {
                try cmd.write(&self.base.file.?, last_cmd_offset);
                last_cmd_offset += cmd.cmdsize();
            }
            const off = @sizeOf(macho.mach_header_64) + @sizeOf(macho.segment_command_64);
            try self.base.file.?.pwriteAll(mem.sliceAsBytes(self.sections.items), off);
        },
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
    self.offset_table.deinit(self.base.allocator);
    self.string_table.deinit(self.base.allocator);
    self.symbol_table.deinit(self.base.allocator);
    self.sections.deinit(self.base.allocator);
    self.load_commands.deinit(self.base.allocator);
}

pub fn allocateDeclIndexes(self: *MachO, decl: *Module.Decl) !void {
    if (decl.link.macho.symbol_table_index) |_| return;

    try self.symbol_table.ensureCapacity(self.base.allocator, self.symbol_table.items.len + 1);
    try self.offset_table.ensureCapacity(self.base.allocator, self.offset_table.items.len + 1);

    log.debug("allocating symbol index {} for {}\n", .{ self.symbol_table.items.len, decl.name });
    decl.link.macho.symbol_table_index = @intCast(u32, self.symbol_table.items.len);
    _ = self.symbol_table.addOneAssumeCapacity();

    decl.link.macho.offset_table_index = @intCast(u32, self.offset_table.items.len);
    _ = self.offset_table.addOneAssumeCapacity();

    self.symbol_table.items[decl.link.macho.symbol_table_index.?] = .{
        .n_strx = 0,
        .n_type = 0,
        .n_sect = 0,
        .n_desc = 0,
        .n_value = 0,
    };
    self.offset_table.items[decl.link.macho.offset_table_index.?] = 0;
}

pub fn updateDecl(self: *MachO, module: *Module, decl: *Module.Decl) !void {
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
    log.debug("generated code {}\n", .{code});

    const required_alignment = typed_value.ty.abiAlignment(self.base.options.target);
    const symbol = &self.symbol_table.items[decl.link.macho.symbol_table_index.?];

    const decl_name = mem.spanZ(decl.name);
    const name_str_index = try self.makeString(decl_name);
    const addr = try self.allocateTextBlock(&decl.link.macho, code.len, required_alignment);
    log.debug("allocated text block for {} at 0x{x}\n", .{ decl_name, addr });
    log.debug("updated text section {}\n", .{self.sections.items[self.text_section_index.?]});

    symbol.* = .{
        .n_strx = name_str_index,
        .n_type = macho.N_SECT,
        .n_sect = @intCast(u8, self.text_section_index.?) + 1,
        .n_desc = 0,
        .n_value = addr,
    };

    // Since we updated the vaddr and the size, each corresponding export symbol also needs to be updated.
    const decl_exports = module.decl_exports.get(decl) orelse &[0]*Module.Export{};
    try self.updateDeclExports(module, decl, decl_exports);
    try self.writeSymbol(decl.link.macho.symbol_table_index.?);

    const text_section = self.sections.items[self.text_section_index.?];
    const section_offset = symbol.n_value - text_section.addr;
    const file_offset = text_section.offset + section_offset;
    log.debug("file_offset 0x{x}\n", .{file_offset});

    try self.base.file.?.pwriteAll(code, file_offset);
}

pub fn updateDeclLineNumber(self: *MachO, module: *Module, decl: *const Module.Decl) !void {}

pub fn updateDeclExports(
    self: *MachO,
    module: *Module,
    decl: *const Module.Decl,
    exports: []const *Module.Export,
) !void {
    const tracy = trace(@src());
    defer tracy.end();

    if (decl.link.macho.symbol_table_index == null) return;

    const decl_sym = &self.symbol_table.items[decl.link.macho.symbol_table_index.?];
    // TODO implement
    if (exports.len == 0) return;

    const exp = exports[0];
    self.entry_addr = decl_sym.n_value;
    decl_sym.n_type |= macho.N_EXT;
    exp.link.sym_index = 0;
}

pub fn freeDecl(self: *MachO, decl: *Module.Decl) void {}

pub fn getDeclVAddr(self: *MachO, decl: *const Module.Decl) u64 {
    return self.symbol_table.items[decl.link.macho.symbol_table_index.?].n_value;
}

pub fn populateMissingMetadata(self: *MachO) !void {
    if (self.segment_cmd_index == null) {
        self.segment_cmd_index = @intCast(u16, self.load_commands.items.len);
        try self.load_commands.append(self.base.allocator, .{
            .Segment = .{
                .cmd = macho.LC_SEGMENT_64,
                .cmdsize = @sizeOf(macho.segment_command_64),
                .segname = makeStaticString(""),
                .vmaddr = 0,
                .vmsize = 0,
                .fileoff = 0,
                .filesize = 0,
                .maxprot = 0,
                .initprot = 0,
                .nsects = 0,
                .flags = 0,
            },
        });
        self.cmd_table_dirty = true;
    }
    if (self.symtab_cmd_index == null) {
        self.symtab_cmd_index = @intCast(u16, self.load_commands.items.len);
        try self.load_commands.append(self.base.allocator, .{
            .Symtab = .{
                .cmd = macho.LC_SYMTAB,
                .cmdsize = @sizeOf(macho.symtab_command),
                .symoff = 0,
                .nsyms = 0,
                .stroff = 0,
                .strsize = 0,
            },
        });
        self.cmd_table_dirty = true;
    }
    if (self.text_section_index == null) {
        self.text_section_index = @intCast(u16, self.sections.items.len);
        const segment = &self.load_commands.items[self.segment_cmd_index.?].Segment;
        segment.cmdsize += @sizeOf(macho.section_64);
        segment.nsects += 1;

        const file_size = self.base.options.program_code_size_hint;
        const off = @intCast(u32, self.findFreeSpace(file_size, 1));
        const flags = macho.S_REGULAR | macho.S_ATTR_PURE_INSTRUCTIONS | macho.S_ATTR_SOME_INSTRUCTIONS;

        log.debug("found __text section free space 0x{x} to 0x{x}\n", .{ off, off + file_size });

        try self.sections.append(self.base.allocator, .{
            .sectname = makeStaticString("__text"),
            .segname = makeStaticString("__TEXT"),
            .addr = 0,
            .size = file_size,
            .offset = off,
            .@"align" = 0x1000,
            .reloff = 0,
            .nreloc = 0,
            .flags = flags,
            .reserved1 = 0,
            .reserved2 = 0,
            .reserved3 = 0,
        });

        segment.vmsize += file_size;
        segment.filesize += file_size;
        segment.fileoff = off;

        log.debug("initial text section {}\n", .{self.sections.items[self.text_section_index.?]});
    }
    {
        const symtab = &self.load_commands.items[self.symtab_cmd_index.?].Symtab;
        if (symtab.symoff == 0) {
            const p_align = @sizeOf(macho.nlist_64);
            const nsyms = self.base.options.symbol_count_hint;
            const file_size = p_align * nsyms;
            const off = @intCast(u32, self.findFreeSpace(file_size, p_align));
            log.debug("found symbol table free space 0x{x} to 0x{x}\n", .{ off, off + file_size });
            symtab.symoff = off;
            symtab.nsyms = @intCast(u32, nsyms);
        }
        if (symtab.stroff == 0) {
            try self.string_table.append(self.base.allocator, 0);
            const file_size = @intCast(u32, self.string_table.items.len);
            const off = @intCast(u32, self.findFreeSpace(file_size, 1));
            log.debug("found string table free space 0x{x} to 0x{x}\n", .{ off, off + file_size });
            symtab.stroff = off;
            symtab.strsize = file_size;
        }
    }
}

fn allocateTextBlock(self: *MachO, text_block: *TextBlock, new_block_size: u64, alignment: u64) !u64 {
    const segment = &self.load_commands.items[self.segment_cmd_index.?].Segment;
    const text_section = &self.sections.items[self.text_section_index.?];
    const new_block_ideal_capacity = new_block_size * alloc_num / alloc_den;

    var block_placement: ?*TextBlock = null;
    const addr = blk: {
        if (self.last_text_block) |last| {
            const last_symbol = self.symbol_table.items[last.symbol_table_index.?];
            const end_addr = last_symbol.n_value + last.size;
            const new_start_addr = mem.alignForwardGeneric(u64, end_addr, alignment);
            block_placement = last;
            break :blk new_start_addr;
        } else {
            break :blk text_section.addr;
        }
    };
    log.debug("computed symbol address 0x{x}\n", .{addr});

    const expand_text_section = block_placement == null or block_placement.?.next == null;
    if (expand_text_section) {
        const text_capacity = self.allocatedSize(text_section.offset);
        const needed_size = (addr + new_block_size) - text_section.addr;
        log.debug("text capacity 0x{x}, needed size 0x{x}\n", .{ text_capacity, needed_size });
        assert(needed_size <= text_capacity); // TODO handle growth

        self.last_text_block = text_block;
        text_section.size = needed_size;
        segment.vmsize = needed_size;
        segment.filesize = needed_size;
        if (alignment < text_section.@"align") {
            text_section.@"align" = @intCast(u32, alignment);
        }
    }
    text_block.size = new_block_size;

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

    return addr;
}

fn makeStaticString(comptime bytes: []const u8) [16]u8 {
    var buf = [_]u8{0} ** 16;
    if (bytes.len > buf.len) @compileError("string too long; max 16 bytes");
    mem.copy(u8, buf[0..], bytes);
    return buf;
}

fn makeString(self: *MachO, bytes: []const u8) !u32 {
    try self.string_table.ensureCapacity(self.base.allocator, self.string_table.items.len + bytes.len + 1);
    const result = self.string_table.items.len;
    self.string_table.appendSliceAssumeCapacity(bytes);
    self.string_table.appendAssumeCapacity(0);
    return @intCast(u32, result);
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

fn addPadding(self: *MachO, size: u64, file_offset: u64) !void {
    if (size == 0) return;

    const buf = try self.base.allocator.alloc(u8, size);
    defer self.base.allocator.free(buf);

    mem.set(u8, buf[0..], 0);

    try self.base.file.?.pwriteAll(buf, file_offset);
}

fn detectAllocCollision(self: *MachO, start: u64, size: u64) ?u64 {
    const hdr_size: u64 = @sizeOf(macho.mach_header_64);
    if (start < hdr_size)
        return hdr_size;

    const end = start + satMul(size, alloc_num) / alloc_den;

    {
        const off = @sizeOf(macho.mach_header_64);
        var tight_size: u64 = 0;
        for (self.load_commands.items) |cmd| {
            tight_size += cmd.cmdsize();
        }
        const increased_size = satMul(tight_size, alloc_num) / alloc_den;
        const test_end = off + increased_size;
        if (end > off and start < test_end) {
            return test_end;
        }
    }

    for (self.sections.items) |section| {
        const increased_size = satMul(section.size, alloc_num) / alloc_den;
        const test_end = section.offset + increased_size;
        if (end > section.offset and start < test_end) {
            return test_end;
        }
    }

    if (self.symtab_cmd_index) |symtab_index| {
        const symtab = self.load_commands.items[symtab_index].Symtab;
        {
            const tight_size = @sizeOf(macho.nlist_64) * symtab.nsyms;
            const increased_size = satMul(tight_size, alloc_num) / alloc_den;
            const test_end = symtab.symoff + increased_size;
            if (end > symtab.symoff and start < test_end) {
                return test_end;
            }
        }
        {
            const increased_size = satMul(symtab.strsize, alloc_num) / alloc_den;
            const test_end = symtab.stroff + increased_size;
            if (end > symtab.stroff and start < test_end) {
                return test_end;
            }
        }
    }

    return null;
}

fn allocatedSize(self: *MachO, start: u64) u64 {
    if (start == 0)
        return 0;
    var min_pos: u64 = std.math.maxInt(u64);
    {
        const off = @sizeOf(macho.mach_header_64);
        if (off > start and off < min_pos) min_pos = off;
    }
    for (self.sections.items) |section| {
        if (section.offset <= start) continue;
        if (section.offset < min_pos) min_pos = section.offset;
    }
    if (self.symtab_cmd_index) |symtab_index| {
        const symtab = self.load_commands.items[symtab_index].Symtab;
        if (symtab.symoff > start and symtab.symoff < min_pos) min_pos = symtab.symoff;
        if (symtab.stroff > start and symtab.stroff < min_pos) min_pos = symtab.stroff;
    }
    return min_pos - start;
}

fn findFreeSpace(self: *MachO, object_size: u64, min_alignment: u16) u64 {
    var start: u64 = 0;
    while (self.detectAllocCollision(start, object_size)) |item_end| {
        start = mem.alignForwardGeneric(u64, item_end, min_alignment);
    }
    return start;
}

fn writeSymbol(self: *MachO, index: usize) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const symtab = &self.load_commands.items[self.symtab_cmd_index.?].Symtab;
    const sym = [1]macho.nlist_64{self.symbol_table.items[index]};
    const off = symtab.symoff + @sizeOf(macho.nlist_64) * index;
    log.debug("writing symbol {} at 0x{x}\n", .{ sym[0], off });
    try self.base.file.?.pwriteAll(mem.sliceAsBytes(sym[0..1]), off);
}

/// Writes Mach-O file header.
/// Should be invoked last as it needs up-to-date values of ncmds and sizeof_cmds bookkeeping
/// variables.
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
    hdr.ncmds = @intCast(u32, self.load_commands.items.len);

    var sizeofcmds: u32 = 0;
    for (self.load_commands.items) |cmd| {
        sizeofcmds += cmd.cmdsize();
    }

    hdr.sizeofcmds = sizeofcmds;

    // TODO should these be set to something else?
    hdr.flags = 0;
    hdr.reserved = 0;

    log.debug("writing Mach-O header {}\n", .{hdr});

    try self.base.file.?.pwriteAll(@ptrCast([*]const u8, &hdr)[0..@sizeOf(macho.mach_header_64)], 0);
}

/// Saturating multiplication
fn satMul(a: anytype, b: anytype) @TypeOf(a, b) {
    const T = @TypeOf(a, b);
    return std.math.mul(T, a, b) catch std.math.maxInt(T);
}
