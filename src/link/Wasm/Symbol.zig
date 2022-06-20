//! Represents a wasm symbol. Containing all of its properties,
//! as well as providing helper methods to determine its functionality
//! and how it will/must be linked.
//! The name of the symbol can be found by providing the offset, found
//! on the `name` field, to a string table in the wasm binary or object file.
const Symbol = @This();

const std = @import("std");
const types = @import("types.zig");

/// Bitfield containings flags for a symbol
/// Can contain any of the flags defined in `Flag`
flags: u32,
/// Symbol name, when the symbol is undefined the name will be taken from the import.
/// Note: This is an index into the string table.
name: u32,
/// Index into the list of objects based on set `tag`
/// NOTE: This will be set to `undefined` when `tag` is `data`
/// and the symbol is undefined.
index: u32,
/// Represents the kind of the symbol, such as a function or global.
tag: Tag,

pub const Tag = enum {
    function,
    data,
    global,
    section,
    event,
    table,
    /// synthetic kind used by the wasm linker during incremental compilation
    /// to notate a symbol has been freed, but still lives in the symbol list.
    dead,

    /// From a given symbol tag, returns the `ExternalType`
    /// Asserts the given tag can be represented as an external type.
    pub fn externalType(self: Tag) std.wasm.ExternalKind {
        return switch (self) {
            .function => .function,
            .global => .global,
            .data => .memory,
            .section => unreachable, // Not an external type
            .event => unreachable, // Not an external type
            .dead => unreachable, // Dead symbols should not be referenced
            .table => .table,
        };
    }
};

pub const Flag = enum(u32) {
    /// Indicates a weak symbol.
    /// When linking multiple modules defining the same symbol, all weak definitions are discarded
    /// in favourite of the strong definition. When no strong definition exists, all weak but one definiton is discarded.
    /// If multiple definitions remain, we get an error: symbol collision.
    WASM_SYM_BINDING_WEAK = 0x1,
    /// Indicates a local, non-exported, non-module-linked symbol.
    /// The names of local symbols are not required to be unique, unlike non-local symbols.
    WASM_SYM_BINDING_LOCAL = 0x2,
    /// Represents the binding of a symbol, indicating if it's local or not, and weak or not.
    WASM_SYM_BINDING_MASK = 0x3,
    /// Indicates a hidden symbol. Hidden symbols will not be exported to the link result, but may
    /// link to other modules.
    WASM_SYM_VISIBILITY_HIDDEN = 0x4,
    /// Indicates an undefined symbol. For non-data symbols, this must match whether the symbol is
    /// an import or is defined. For data symbols however, determines whether a segment is specified.
    WASM_SYM_UNDEFINED = 0x10,
    /// Indicates a symbol of which its intention is to be exported from the wasm module to the host environment.
    /// This differs from the visibility flag as this flag affects the static linker.
    WASM_SYM_EXPORTED = 0x20,
    /// Indicates the symbol uses an explicit symbol name, rather than reusing the name from a wasm import.
    /// Allows remapping imports from foreign WASM modules into local symbols with a different name.
    WASM_SYM_EXPLICIT_NAME = 0x40,
    /// Indicates the symbol is to be included in the linker output, regardless of whether it is used or has any references to it.
    WASM_SYM_NO_STRIP = 0x80,
    /// Indicates a symbol is TLS
    WASM_SYM_TLS = 0x100,
};

/// Verifies if the given symbol should be imported from the
/// host environment or not
pub fn requiresImport(self: Symbol) bool {
    if (!self.isUndefined()) return false;
    if (self.isWeak()) return false;
    if (self.tag == .data) return false;
    // if (self.isDefined() and self.isWeak()) return true; //TODO: Only when building shared lib

    return true;
}

pub fn hasFlag(self: Symbol, flag: Flag) bool {
    return self.flags & @enumToInt(flag) != 0;
}

pub fn setFlag(self: *Symbol, flag: Flag) void {
    self.flags |= @enumToInt(flag);
}

pub fn isUndefined(self: Symbol) bool {
    return self.flags & @enumToInt(Flag.WASM_SYM_UNDEFINED) != 0;
}

pub fn setUndefined(self: *Symbol, is_undefined: bool) void {
    if (is_undefined) {
        self.setFlag(.WASM_SYM_UNDEFINED);
    } else {
        self.flags &= ~@enumToInt(Flag.WASM_SYM_UNDEFINED);
    }
}

pub fn setGlobal(self: *Symbol, is_global: bool) void {
    if (is_global) {
        self.flags &= ~@enumToInt(Flag.WASM_SYM_BINDING_LOCAL);
    } else {
        self.setFlag(.WASM_SYM_BINDING_LOCAL);
    }
}

pub fn isDefined(self: Symbol) bool {
    return !self.isUndefined();
}

pub fn isVisible(self: Symbol) bool {
    return self.flags & @enumToInt(Flag.WASM_SYM_VISIBILITY_HIDDEN) == 0;
}

pub fn isLocal(self: Symbol) bool {
    return self.flags & @enumToInt(Flag.WASM_SYM_BINDING_LOCAL) != 0;
}

pub fn isGlobal(self: Symbol) bool {
    return self.flags & @enumToInt(Flag.WASM_SYM_BINDING_LOCAL) == 0;
}

pub fn isHidden(self: Symbol) bool {
    return self.flags & @enumToInt(Flag.WASM_SYM_VISIBILITY_HIDDEN) != 0;
}

pub fn isNoStrip(self: Symbol) bool {
    return self.flags & @enumToInt(Flag.WASM_SYM_NO_STRIP) != 0;
}

pub fn isExported(self: Symbol) bool {
    if (self.isUndefined() or self.isLocal()) return false;
    if (self.isHidden()) return false;
    if (self.hasFlag(.WASM_SYM_EXPORTED)) return true;
    if (self.hasFlag(.WASM_SYM_BINDING_WEAK)) return false;
    return true;
}

pub fn isWeak(self: Symbol) bool {
    return self.flags & @enumToInt(Flag.WASM_SYM_BINDING_WEAK) != 0;
}

/// Formats the symbol into human-readable text
pub fn format(self: Symbol, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
    _ = fmt;
    _ = options;

    const kind_fmt: u8 = switch (self.tag) {
        .function => 'F',
        .data => 'D',
        .global => 'G',
        .section => 'S',
        .event => 'E',
        .table => 'T',
        .dead => '-',
    };
    const visible: []const u8 = if (self.isVisible()) "yes" else "no";
    const binding: []const u8 = if (self.isLocal()) "local" else "global";
    const undef: []const u8 = if (self.isUndefined()) "undefined" else "";

    try writer.print(
        "{c} binding={s} visible={s} id={d} name_offset={d} {s}",
        .{ kind_fmt, binding, visible, self.index, self.name, undef },
    );
}
