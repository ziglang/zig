const Symbol = @This();

const std = @import("std");
const macho = std.macho;

/// MachO representation of this symbol.
inner: macho.nlist_64,

/// Index of file where to locate this symbol.
/// Depending on context, this is either an object file, or a dylib.
file: ?u16 = null,

/// Index of this symbol within the file's symbol table.
index: ?u32 = null,

pub fn isStab(self: Symbol) bool {
    return (macho.N_STAB & self.inner.n_type) != 0;
}

pub fn isPext(self: Symbol) bool {
    return (macho.N_PEXT & self.inner.n_type) != 0;
}

pub fn isExt(self: Symbol) bool {
    return (macho.N_EXT & self.inner.n_type) != 0;
}

pub fn isSect(self: Symbol) bool {
    const type_ = macho.N_TYPE & self.inner.n_type;
    return type_ == macho.N_SECT;
}

pub fn isUndf(self: Symbol) bool {
    const type_ = macho.N_TYPE & self.inner.n_type;
    return type_ == macho.N_UNDF;
}

pub fn isWeakDef(self: Symbol) bool {
    return self.inner.n_desc == macho.N_WEAK_DEF;
}

/// Symbol is local if it is either a stab or it is defined and not an extern.
pub fn isLocal(self: Symbol) bool {
    return self.isStab() or (self.isSect() and !self.isExt());
}

/// Symbol is global if it is defined and an extern.
pub fn isGlobal(self: Symbol) bool {
    return self.isSect() and self.isExt();
}

/// Symbol is undefined if it is not defined and an extern.
pub fn isUndef(self: Symbol) bool {
    return self.isUndf() and self.isExt();
}
