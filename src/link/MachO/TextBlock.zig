const TextBlock = @This();

const std = @import("std");
const commands = @import("commands.zig");
const log = std.log.scoped(.text_block);
const macho = std.macho;
const mem = std.mem;
const reloc = @import("reloc.zig");

const Allocator = mem.Allocator;
const Relocation = reloc.Relocation;
const Zld = @import("Zld.zig");

allocator: *Allocator,
local_sym_index: u32,
stab: ?Stab = null,
aliases: std.ArrayList(u32),
references: std.AutoArrayHashMap(u32, void),
contained: ?[]SymbolAtOffset = null,
code: []u8,
relocs: std.ArrayList(Relocation),
size: u64,
alignment: u32,
rebases: std.ArrayList(u64),
bindings: std.ArrayList(SymbolAtOffset),
dices: std.ArrayList(macho.data_in_code_entry),
next: ?*TextBlock = null,
prev: ?*TextBlock = null,

pub const SymbolAtOffset = struct {
    local_sym_index: u32,
    offset: u64,
    stab: ?Stab = null,
};

pub const Stab = union(enum) {
    function: u64,
    static,
    global,

    pub fn asNlists(stab: Stab, local_sym_index: u32, zld: *Zld) ![]macho.nlist_64 {
        var nlists = std.ArrayList(macho.nlist_64).init(zld.allocator);
        defer nlists.deinit();

        const sym = zld.locals.items[local_sym_index];
        const reg = sym.payload.regular;

        switch (stab) {
            .function => |size| {
                try nlists.ensureUnusedCapacity(4);
                const section_id = reg.sectionId(zld);
                nlists.appendAssumeCapacity(.{
                    .n_strx = 0,
                    .n_type = macho.N_BNSYM,
                    .n_sect = section_id,
                    .n_desc = 0,
                    .n_value = reg.address,
                });
                nlists.appendAssumeCapacity(.{
                    .n_strx = sym.strx,
                    .n_type = macho.N_FUN,
                    .n_sect = section_id,
                    .n_desc = 0,
                    .n_value = reg.address,
                });
                nlists.appendAssumeCapacity(.{
                    .n_strx = 0,
                    .n_type = macho.N_FUN,
                    .n_sect = 0,
                    .n_desc = 0,
                    .n_value = size,
                });
                nlists.appendAssumeCapacity(.{
                    .n_strx = 0,
                    .n_type = macho.N_ENSYM,
                    .n_sect = section_id,
                    .n_desc = 0,
                    .n_value = size,
                });
            },
            .global => {
                try nlists.append(.{
                    .n_strx = sym.strx,
                    .n_type = macho.N_GSYM,
                    .n_sect = 0,
                    .n_desc = 0,
                    .n_value = 0,
                });
            },
            .static => {
                try nlists.append(.{
                    .n_strx = sym.strx,
                    .n_type = macho.N_STSYM,
                    .n_sect = reg.sectionId(zld),
                    .n_desc = 0,
                    .n_value = reg.address,
                });
            },
        }

        return nlists.toOwnedSlice();
    }
};

pub fn init(allocator: *Allocator) TextBlock {
    return .{
        .allocator = allocator,
        .local_sym_index = undefined,
        .aliases = std.ArrayList(u32).init(allocator),
        .references = std.AutoArrayHashMap(u32, void).init(allocator),
        .code = undefined,
        .relocs = std.ArrayList(Relocation).init(allocator),
        .size = undefined,
        .alignment = undefined,
        .rebases = std.ArrayList(u64).init(allocator),
        .bindings = std.ArrayList(SymbolAtOffset).init(allocator),
        .dices = std.ArrayList(macho.data_in_code_entry).init(allocator),
    };
}

pub fn deinit(self: *TextBlock) void {
    self.aliases.deinit();
    self.references.deinit();
    if (self.contained) |contained| {
        self.allocator.free(contained);
    }
    self.allocator.free(self.code);
    self.relocs.deinit();
    self.rebases.deinit();
    self.bindings.deinit();
    self.dices.deinit();
}

pub fn resolveRelocs(self: *TextBlock, zld: *Zld) !void {
    for (self.relocs.items) |rel| {
        log.debug("relocating {}", .{rel});

        const source_addr = blk: {
            const sym = zld.locals.items[self.local_sym_index];
            break :blk sym.payload.regular.address + rel.offset;
        };
        const target_addr = blk: {
            const is_via_got = switch (rel.payload) {
                .pointer_to_got => true,
                .page => |page| page.kind == .got,
                .page_off => |page_off| page_off.kind == .got,
                .load => |load| load.kind == .got,
                else => false,
            };

            if (is_via_got) {
                const dc_seg = zld.load_commands.items[zld.data_const_segment_cmd_index.?].Segment;
                const got = dc_seg.sections.items[zld.got_section_index.?];
                const got_index = rel.target.got_index orelse {
                    log.err("expected GOT entry for symbol '{s}'", .{zld.getString(rel.target.strx)});
                    log.err("  this is an internal linker error", .{});
                    return error.FailedToResolveRelocationTarget;
                };
                break :blk got.addr + got_index * @sizeOf(u64);
            }

            switch (rel.target.payload) {
                .regular => |reg| {
                    const is_tlv = is_tlv: {
                        const sym = zld.locals.items[self.local_sym_index];
                        const seg = zld.load_commands.items[sym.payload.regular.segment_id].Segment;
                        const sect = seg.sections.items[sym.payload.regular.section_id];
                        break :is_tlv commands.sectionType(sect) == macho.S_THREAD_LOCAL_VARIABLES;
                    };
                    if (is_tlv) {
                        // For TLV relocations, the value specified as a relocation is the displacement from the
                        // TLV initializer (either value in __thread_data or zero-init in __thread_bss) to the first
                        // defined TLV template init section in the following order:
                        // * wrt to __thread_data if defined, then
                        // * wrt to __thread_bss
                        const seg = zld.load_commands.items[zld.data_segment_cmd_index.?].Segment;
                        const base_address = inner: {
                            if (zld.tlv_data_section_index) |i| {
                                break :inner seg.sections.items[i].addr;
                            } else if (zld.tlv_bss_section_index) |i| {
                                break :inner seg.sections.items[i].addr;
                            } else {
                                log.err("threadlocal variables present but no initializer sections found", .{});
                                log.err("  __thread_data not found", .{});
                                log.err("  __thread_bss not found", .{});
                                return error.FailedToResolveRelocationTarget;
                            }
                        };
                        break :blk reg.address - base_address;
                    }

                    break :blk reg.address;
                },
                .proxy => {
                    if (mem.eql(u8, zld.getString(rel.target.strx), "__tlv_bootstrap")) {
                        break :blk 0; // Dynamically bound by dyld.
                    }

                    const segment = zld.load_commands.items[zld.text_segment_cmd_index.?].Segment;
                    const stubs = segment.sections.items[zld.stubs_section_index.?];
                    const stubs_index = rel.target.stubs_index orelse {
                        // TODO verify in TextBlock that the symbol is indeed dynamically bound.
                        break :blk 0; // Dynamically bound by dyld.
                    };
                    break :blk stubs.addr + stubs_index * stubs.reserved2;
                },
                else => {
                    log.err("failed to resolve symbol '{s}' as a relocation target", .{
                        zld.getString(rel.target.strx),
                    });
                    log.err("  this is an internal linker error", .{});
                    return error.FailedToResolveRelocationTarget;
                },
            }
        };

        log.debug("  | source_addr = 0x{x}", .{source_addr});
        log.debug("  | target_addr = 0x{x}", .{target_addr});

        try rel.resolve(self, source_addr, target_addr);
    }
}

pub fn print_this(self: *const TextBlock, zld: *Zld) void {
    log.warn("TextBlock", .{});
    log.warn("  {}: {}", .{ self.local_sym_index, zld.locals.items[self.local_sym_index] });
    if (self.stab) |stab| {
        log.warn("  stab: {}", .{stab});
    }
    if (self.aliases.items.len > 0) {
        log.warn("  aliases:", .{});
        for (self.aliases.items) |index| {
            log.warn("    {}: {}", .{ index, zld.locals.items[index] });
        }
    }
    if (self.references.count() > 0) {
        log.warn("  references:", .{});
        for (self.references.keys()) |index| {
            log.warn("    {}: {}", .{ index, zld.locals.items[index] });
        }
    }
    if (self.contained) |contained| {
        log.warn("  contained symbols:", .{});
        for (contained) |sym_at_off| {
            if (sym_at_off.stab) |stab| {
                log.warn("    {}: {}, stab: {}\n", .{
                    sym_at_off.offset,
                    zld.locals.items[sym_at_off.local_sym_index],
                    stab,
                });
            } else {
                log.warn("    {}: {}\n", .{
                    sym_at_off.offset,
                    zld.locals.items[sym_at_off.local_sym_index],
                });
            }
        }
    }
    log.warn("  code.len = {}", .{self.code.len});
    if (self.relocs.items.len > 0) {
        log.warn("  relocations:", .{});
        for (self.relocs.items) |rel| {
            log.warn("    {}", .{rel});
        }
    }
    if (self.rebases.items.len > 0) {
        log.warn("  rebases: {any}", .{self.rebases.items});
    }
    if (self.bindings.items.len > 0) {
        log.warn("  bindings: {any}", .{self.bindings.items});
    }
    if (self.dices.items.len > 0) {
        log.warn("  dices: {any}", .{self.dices.items});
    }
    log.warn("  size = {}", .{self.size});
    log.warn("  align = {}", .{self.alignment});
}

pub fn print(self: *const TextBlock, zld: *Zld) void {
    if (self.prev) |prev| {
        prev.print(zld);
    }
    self.print_this(zld);
}
