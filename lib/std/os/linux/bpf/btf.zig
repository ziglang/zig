const std = @import("../../../std.zig");

pub const magic = 0xeb9f;
pub const version = 1;

pub const ext = @import("btf_ext.zig");

/// All offsets are in bytes relative to the end of this header
pub const Header = extern struct {
    magic: u16,
    version: u8,
    flags: u8,
    hdr_len: u32,

    /// offset of type section
    type_off: u32,

    /// length of type section
    type_len: u32,

    /// offset of string section
    str_off: u32,

    /// length of string section
    str_len: u32,
};

/// Max number of type identifiers
pub const max_type = 0xfffff;

/// Max offset into string section
pub const max_name_offset = 0xffffff;

/// Max number of struct/union/enum member of func args
pub const max_vlen = 0xffff;

pub const Type = extern struct {
    name_off: u32,
    info: packed struct(u32) {
        /// number of struct's members
        vlen: u16,

        unused_1: u8,
        kind: Kind,
        unused_2: u2,

        /// used by Struct, Union, and Fwd
        kind_flag: bool,
    },

    /// size is used by Int, Enum, Struct, Union, and DataSec, it tells the size
    /// of the type it is describing
    ///
    /// type is used by Ptr, Typedef, Volatile, Const, Restrict, Func,
    /// FuncProto, and Var. It is a type_id referring to another type
    size_type: extern union { size: u32, typ: u32 },
};

/// For some kinds, Type is immediately followed by extra data
pub const Kind = enum(u5) {
    unknown,
    int,
    ptr,
    array,
    @"struct",
    @"union",
    @"enum",
    fwd,
    typedef,
    @"volatile",
    @"const",
    restrict,
    func,
    func_proto,
    @"var",
    datasec,
    float,
    decl_tag,
    type_tag,
    enum64,
};

/// int kind is followed by this struct
pub const IntInfo = packed struct(u32) {
    bits: u8,
    unused: u8,
    offset: u8,
    encoding: enum(u4) {
        signed = 1 << 0,
        char = 1 << 1,
        boolean = 1 << 2,
    },
};

test "IntInfo is 32 bits" {
    try std.testing.expectEqual(@bitSizeOf(IntInfo), 32);
}

/// enum kind is followed by this struct
pub const Enum = extern struct {
    name_off: u32,
    val: i32,
};

/// enum64 kind is followed by this struct
pub const Enum64 = extern struct {
    name_off: u32,
    val_lo32: i32,
    val_hi32: i32,
};

/// array kind is followed by this struct
pub const Array = extern struct {
    typ: u32,
    index_type: u32,
    nelems: u32,
};

/// struct and union kinds are followed by multiple Member structs. The exact
/// number is stored in vlen
pub const Member = extern struct {
    name_off: u32,
    typ: u32,

    /// if the kind_flag is set, offset contains both member bitfield size and
    /// bit offset, the bitfield size is set for bitfield members. If the type
    /// info kind_flag is not set, the offset contains only bit offset
    offset: packed struct(u32) {
        bit: u24,
        bitfield_size: u8,
    },
};

/// func_proto is followed by multiple Params, the exact number is stored in vlen
pub const Param = extern struct {
    name_off: u32,
    typ: u32,
};

pub const VarLinkage = enum {
    static,
    global_allocated,
    global_extern,
};

pub const FuncLinkage = enum {
    static,
    global,
    external,
};

/// var kind is followed by a single Var struct to describe additional
/// information related to the variable such as its linkage
pub const Var = extern struct {
    linkage: u32,
};

/// datasec kind is followed by multiple VarSecInfo to describe all Var kind
/// types it contains along with it's in-section offset as well as size.
pub const VarSecInfo = extern struct {
    typ: u32,
    offset: u32,
    size: u32,
};

// decl_tag kind is followed by a single DeclTag struct to describe
// additional information related to the tag applied location.
// If component_idx == -1, the tag is applied to a struct, union,
// variable or function. Otherwise, it is applied to a struct/union
// member or a func argument, and component_idx indicates which member
// or argument (0 ... vlen-1).
pub const DeclTag = extern struct {
    component_idx: u32,
};
