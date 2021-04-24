const Symbol = @This();

const std = @import("std");
const macho = std.macho;

const Allocator = std.mem.Allocator;

pub const Tag = enum {
    local,
    weak,
    strong,
    import,
    undef,
};

tag: Tag,
name: []u8,
address: u64,
section: u8,

/// Index of file where to locate this symbol.
/// Depending on context, this is either an object file, or a dylib.
file: ?u16 = null,

/// Index of this symbol within the file's symbol table.
index: ?u32 = null,

pub fn deinit(self: *Symbol, allocator: *Allocator) void {
    allocator.free(self.name);
}

pub fn isStab(sym: macho.nlist_64) bool {
    return (macho.N_STAB & sym.n_type) != 0;
}

pub fn isPext(sym: macho.nlist_64) bool {
    return (macho.N_PEXT & sym.n_type) != 0;
}

pub fn isExt(sym: macho.nlist_64) bool {
    return (macho.N_EXT & sym.n_type) != 0;
}

pub fn isSect(sym: macho.nlist_64) bool {
    const type_ = macho.N_TYPE & sym.n_type;
    return type_ == macho.N_SECT;
}

pub fn isUndf(sym: macho.nlist_64) bool {
    const type_ = macho.N_TYPE & sym.n_type;
    return type_ == macho.N_UNDF;
}

pub fn isWeakDef(sym: macho.nlist_64) bool {
    return (sym.n_desc & macho.N_WEAK_DEF) != 0;
}

/// Symbol is local if it is defined and not an extern.
pub fn isLocal(sym: macho.nlist_64) bool {
    return isSect(sym) and !isExt(sym);
}

/// Symbol is global if it is defined and an extern.
pub fn isGlobal(sym: macho.nlist_64) bool {
    return isSect(sym) and isExt(sym);
}

/// Symbol is undefined if it is not defined and an extern.
pub fn isUndef(sym: macho.nlist_64) bool {
    return isUndf(sym) and isExt(sym);
}
