const Atom = @This();

const std = @import("std");
const types = @import("types.zig");
const Wasm = @import("../Wasm.zig");
const Symbol = @import("Symbol.zig");

const leb = std.leb;
const log = std.log.scoped(.link);
const mem = std.mem;
const Allocator = mem.Allocator;

/// symbol index of the symbol representing this atom
sym_index: u32,
/// Size of the atom, used to calculate section sizes in the final binary
size: u32,
/// List of relocations belonging to this atom
relocs: std.ArrayListUnmanaged(types.Relocation) = .{},
/// Contains the binary data of an atom, which can be non-relocated
code: std.ArrayListUnmanaged(u8) = .{},
/// For code this is 1, for data this is set to the highest value of all segments
alignment: u32,
/// Offset into the section where the atom lives, this already accounts
/// for alignment.
offset: u32,

/// Next atom in relation to this atom.
/// When null, this atom is the last atom
next: ?*Atom,
/// Previous atom in relation to this atom.
/// is null when this atom is the first in its order
prev: ?*Atom,

/// Contains atoms local to a decl, all managed by this `Atom`.
/// When the parent atom is being freed, it will also do so for all local atoms.
locals: std.ArrayListUnmanaged(Atom) = .{},

/// Represents a default empty wasm `Atom`
pub const empty: Atom = .{
    .alignment = 0,
    .next = null,
    .offset = 0,
    .prev = null,
    .size = 0,
    .sym_index = 0,
};

/// Frees all resources owned by this `Atom`.
pub fn deinit(self: *Atom, gpa: Allocator) void {
    self.relocs.deinit(gpa);
    self.code.deinit(gpa);

    while (self.locals.popOrNull()) |*local| {
        local.deinit(gpa);
    }
    self.locals.deinit(gpa);
}

/// Sets the length of relocations and code to '0',
/// effectively resetting them and allowing them to be re-populated.
pub fn clear(self: *Atom) void {
    self.relocs.clearRetainingCapacity();
    self.code.clearRetainingCapacity();
}

pub fn format(self: Atom, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
    _ = fmt;
    _ = options;
    writer.print("Atom{{ .sym_index = {d}, .alignment = {d}, .size = {d}, .offset = 0x{x:0>8} }}", .{
        self.sym_index,
        self.alignment,
        self.size,
        self.offset,
    });
}

/// Returns the first `Atom` from a given atom
pub fn getFirst(self: *Atom) *Atom {
    var tmp = self;
    while (tmp.prev) |prev| tmp = prev;
    return tmp;
}

/// Returns the atom for the given `symbol_index`.
/// This can be either the `Atom` itself, or one of its locals.
pub fn symbolAtom(self: *Atom, symbol_index: u32) *Atom {
    if (self.sym_index == symbol_index) return self;
    return for (self.locals.items) |*local_atom| {
        if (local_atom.sym_index == symbol_index) break local_atom;
    } else unreachable; // Used a symbol index not present in this atom or its children.
}

/// Resolves the relocations within the atom, writing the new value
/// at the calculated offset.
pub fn resolveRelocs(self: *Atom, wasm_bin: *const Wasm) !void {
    const symbol: Symbol = wasm_bin.symbols.items[self.sym_index];
    log.debug("Resolving relocs in atom '{s}' count({d})", .{
        symbol.name,
        self.relocs.items.len,
    });

    for (self.relocs.items) |reloc| {
        const value = try relocationValue(reloc, wasm_bin);
        log.debug("Relocating '{s}' referenced in '{s}' offset=0x{x:0>8} value={d}", .{
            wasm_bin.symbols.items[reloc.index].name,
            symbol.name,
            reloc.offset,
            value,
        });

        switch (reloc.relocation_type) {
            .R_WASM_TABLE_INDEX_I32,
            .R_WASM_FUNCTION_OFFSET_I32,
            .R_WASM_GLOBAL_INDEX_I32,
            .R_WASM_MEMORY_ADDR_I32,
            .R_WASM_SECTION_OFFSET_I32,
            => std.mem.writeIntLittle(u32, self.code.items[reloc.offset..][0..4], @intCast(u32, value)),
            .R_WASM_TABLE_INDEX_I64,
            .R_WASM_MEMORY_ADDR_I64,
            => std.mem.writeIntLittle(u64, self.code.items[reloc.offset..][0..8], value),
            .R_WASM_GLOBAL_INDEX_LEB,
            .R_WASM_EVENT_INDEX_LEB,
            .R_WASM_FUNCTION_INDEX_LEB,
            .R_WASM_MEMORY_ADDR_LEB,
            .R_WASM_MEMORY_ADDR_SLEB,
            .R_WASM_TABLE_INDEX_SLEB,
            .R_WASM_TABLE_NUMBER_LEB,
            .R_WASM_TYPE_INDEX_LEB,
            => leb.writeUnsignedFixed(5, self.code.items[reloc.offset..][0..5], @intCast(u32, value)),
            .R_WASM_MEMORY_ADDR_LEB64,
            .R_WASM_MEMORY_ADDR_SLEB64,
            .R_WASM_TABLE_INDEX_SLEB64,
            => leb.writeUnsignedFixed(10, self.code.items[reloc.offset..][0..10], value),
        }
    }
}

/// From a given `relocation` will return the new value to be written.
/// All values will be represented as a `u64` as all values can fit within it.
/// The final value must be casted to the correct size.
fn relocationValue(relocation: types.Relocation, wasm_bin: *const Wasm) !u64 {
    const symbol: Symbol = wasm_bin.symbols.items[relocation.index];
    return switch (relocation.relocation_type) {
        .R_WASM_FUNCTION_INDEX_LEB => symbol.index,
        .R_WASM_TABLE_NUMBER_LEB => symbol.index,
        .R_WASM_TABLE_INDEX_I32,
        .R_WASM_TABLE_INDEX_I64,
        .R_WASM_TABLE_INDEX_SLEB,
        .R_WASM_TABLE_INDEX_SLEB64,
        => return wasm_bin.function_table.get(relocation.index) orelse 0,
        .R_WASM_TYPE_INDEX_LEB => wasm_bin.functions.items[symbol.index].type_index,
        .R_WASM_GLOBAL_INDEX_I32,
        .R_WASM_GLOBAL_INDEX_LEB,
        => symbol.index,
        .R_WASM_MEMORY_ADDR_I32,
        .R_WASM_MEMORY_ADDR_I64,
        .R_WASM_MEMORY_ADDR_LEB,
        .R_WASM_MEMORY_ADDR_LEB64,
        .R_WASM_MEMORY_ADDR_SLEB,
        .R_WASM_MEMORY_ADDR_SLEB64,
        => blk: {
            if (symbol.isUndefined() and (symbol.tag == .data or symbol.isWeak())) {
                return 0;
            }
            const segment_name = wasm_bin.segment_info.items[symbol.index].outputName();
            const atom_index = wasm_bin.data_segments.get(segment_name).?;
            var target_atom = wasm_bin.atoms.getPtr(atom_index).?.*.getFirst();
            while (true) {
                if (target_atom.sym_index == relocation.index) break;
                target_atom = target_atom.next orelse break;
            }
            const segment = wasm_bin.segments.items[atom_index];
            break :blk target_atom.offset + segment.offset + (relocation.addend orelse 0);
        },
        .R_WASM_EVENT_INDEX_LEB => symbol.index,
        .R_WASM_SECTION_OFFSET_I32,
        .R_WASM_FUNCTION_OFFSET_I32,
        => relocation.offset,
    };
}
