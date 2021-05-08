// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const magic = 0xeb9f;
const version = 1;

pub const ext = @import("btf_ext.zig");

/// All offsets are in bytes relative to the end of this header
pub const Header = packed struct {
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

pub const Type = packed struct {
    name_off: u32,
    info: packed struct {
        /// number of struct's members
        vlen: u16,

        unused_1: u8,
        kind: Kind,
        unused_2: u3,

        /// used by Struct, Union, and Fwd
        kind_flag: bool,
    },

    /// size is used by Int, Enum, Struct, Union, and DataSec, it tells the size
    /// of the type it is describing
    ///
    /// type is used by Ptr, Typedef, Volatile, Const, Restrict, Func,
    /// FuncProto, and Var. It is a type_id referring to another type
    size_type: union { size: u32, typ: u32 },
};

/// For some kinds, Type is immediately followed by extra data
pub const Kind = enum(u4) {
    unknown,
    int,
    ptr,
    array,
    structure,
    kind_union,
    enumeration,
    fwd,
    typedef,
    kind_volatile,
    constant,
    restrict,
    func,
    funcProto,
    variable,
    dataSec,
};

/// Int kind is followed by this struct
pub const IntInfo = packed struct {
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

/// Enum kind is followed by this struct
pub const Enum = packed struct {
    name_off: u32,
    val: i32,
};

/// Array kind is followd by this struct
pub const Array = packed struct {
    typ: u32,
    index_type: u32,
    nelems: u32,
};

/// Struct and Union kinds are followed by multiple Member structs. The exact
/// number is stored in vlen
pub const Member = packed struct {
    name_off: u32,
    typ: u32,

    /// if the kind_flag is set, offset contains both member bitfield size and
    /// bit offset, the bitfield size is set for bitfield members. If the type
    /// info kind_flag is not set, the offset contains only bit offset
    offset: packed struct {
        bit: u24,
        bitfield_size: u8,
    },
};

/// FuncProto is followed by multiple Params, the exact number is stored in vlen
pub const Param = packed struct {
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

/// Var kind is followd by a single Var struct to describe additional
/// information related to the variable such as its linkage
pub const Var = packed struct {
    linkage: u32,
};

/// Datasec kind is followed by multible VarSecInfo to describe all Var kind
/// types it contains along with it's in-section offset as well as size.
pub const VarSecInfo = packed struct {
    typ: u32,
    offset: u32,
    size: u32,
};
