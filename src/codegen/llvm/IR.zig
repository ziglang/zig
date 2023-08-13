const std = @import("std");
const Builder = @import("Builder.zig");
const Bitcode = @import("Bitcode.zig");

const AbbrevOp = Bitcode.AbbrevOp;

pub const MAGIC: u32 = 0xdec04342;

pub const Identification = struct {
    pub const id = 13;

    pub const abbrevs = [_]type{
        Version,
        Epoch,
    };

    pub const Version = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 1 },
            .array_char6,
        };
        string: []const u8,
    };

    pub const Epoch = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 2 },
            .{ .vbr = 6 },
        };
        epoch: u32,
    };
};

pub const Module = struct {
    pub const id = 8;

    pub const abbrevs = [_]type{
        Version,
        String,
        Variable,
        Function,
        Alias,
    };

    pub const Version = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 1 },
            .{ .literal = 2 },
        };
    };

    pub const String = struct {
        pub const ops = [_]AbbrevOp{
            .{ .vbr = 4 },
            .{ .array_fixed = 8 },
        };
        code: u16,
        string: []const u8,
    };

    pub const Variable = struct {
        const AddrSpaceAndIsConst = packed struct {
            is_const: bool,
            one: u1 = 1,
            addr_space: Builder.AddrSpace,
        };

        pub const ops = [_]AbbrevOp{
            .{ .literal = 7 }, // Code
            .{ .vbr = 16 }, // strtab_offset
            .{ .vbr = 16 }, // strtab_size
            .{ .fixed = @bitSizeOf(Builder.Type) },
            .{ .fixed = @bitSizeOf(AddrSpaceAndIsConst) }, // isconst
            .{ .fixed = 32 }, // initid
            .{ .fixed = @bitSizeOf(Builder.Linkage) },
            .{ .fixed = @bitSizeOf(Builder.Alignment) },
            .{ .vbr = 16 }, // section
            .{ .fixed = @bitSizeOf(Builder.Visibility) },
            .{ .fixed = @bitSizeOf(Builder.ThreadLocal) }, // threadlocal
            .{ .fixed = @bitSizeOf(Builder.UnnamedAddr) },
            .{ .fixed = @bitSizeOf(Builder.ExternallyInitialized) },
            .{ .fixed = @bitSizeOf(Builder.DllStorageClass) },
            .{ .literal = 0 }, // comdat
            .{ .literal = 0 }, // attributes
            .{ .fixed = @bitSizeOf(Builder.Preemption) },
        };
        strtab_offset: usize,
        strtab_size: usize,
        type_index: Builder.Type,
        is_const: AddrSpaceAndIsConst,
        initid: u32,
        linkage: Builder.Linkage,
        alignment: std.meta.Int(.unsigned, @bitSizeOf(Builder.Alignment)),
        section: usize,
        visibility: Builder.Visibility,
        thread_local: Builder.ThreadLocal,
        unnamed_addr: Builder.UnnamedAddr,
        externally_initialized: Builder.ExternallyInitialized,
        dllstorageclass: Builder.DllStorageClass,
        preemption: Builder.Preemption,
    };

    pub const Function = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 8 }, // Code
            .{ .vbr = 16 }, // strtab_offset
            .{ .vbr = 16 }, // strtab_size
            .{ .fixed = @bitSizeOf(Builder.Type) },
            .{ .fixed = @bitSizeOf(Builder.CallConv) },
            .{ .fixed = 1 }, // isproto
            .{ .fixed = @bitSizeOf(Builder.Linkage) },
            .{ .vbr = 16 }, // paramattr
            .{ .fixed = @bitSizeOf(Builder.Alignment) },
            .{ .vbr = 16 }, // section
            .{ .fixed = @bitSizeOf(Builder.Visibility) },
            .{ .literal = 0 }, // gc
            .{ .fixed = @bitSizeOf(Builder.UnnamedAddr) },
            .{ .literal = 0 }, // prologuedata
            .{ .fixed = @bitSizeOf(Builder.DllStorageClass) },
            .{ .literal = 0 }, // comdat
            // .{ .literal = 0 }, // prefixdata
            .{ .literal = 0 }, // personalityfn
            .{ .fixed = @bitSizeOf(Builder.Preemption) },
            .{ .fixed = @bitSizeOf(Builder.AddrSpace) },
        };
        strtab_offset: usize,
        strtab_size: usize,
        type_index: Builder.Type,
        call_conv: Builder.CallConv,
        is_proto: bool,
        linkage: Builder.Linkage,
        paramattr: usize,
        alignment: std.meta.Int(.unsigned, @bitSizeOf(Builder.Alignment)),
        section: usize,
        visibility: Builder.Visibility,
        unnamed_addr: Builder.UnnamedAddr,
        dllstorageclass: Builder.DllStorageClass,
        preemption: Builder.Preemption,
        addr_space: Builder.AddrSpace,
    };

    pub const Alias = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 9 }, // Code
            .{ .vbr = 16 }, // strtab_offset
            .{ .vbr = 16 }, // strtab_size
            .{ .fixed = @bitSizeOf(Builder.Type) },
            .{ .fixed = @bitSizeOf(Builder.AddrSpace) },
            .{ .fixed = 32 }, // aliasee val
            .{ .fixed = @bitSizeOf(Builder.Linkage) },
            .{ .fixed = @bitSizeOf(Builder.Visibility) },
            .{ .fixed = @bitSizeOf(Builder.DllStorageClass) },
            .{ .fixed = @bitSizeOf(Builder.ThreadLocal) },
            .{ .fixed = @bitSizeOf(Builder.UnnamedAddr) },
            .{ .fixed = @bitSizeOf(Builder.Preemption) },
        };
        strtab_offset: usize,
        strtab_size: usize,
        type_index: Builder.Type,
        addr_space: Builder.AddrSpace,
        aliasee: u32,
        linkage: Builder.Linkage,
        visibility: Builder.Visibility,
        dllstorageclass: Builder.DllStorageClass,
        thread_local: Builder.ThreadLocal,
        unnamed_addr: Builder.UnnamedAddr,
        preemption: Builder.Preemption,
    };
};

pub const Type = struct {
    pub const id = 17;

    pub const abbrevs = [_]type{
        NumEntry,
        Simple,
        Integer,
        StructAnon,
        StructNamed,
        StructName,
        Array,
        Vector,
        Pointer,
        Target,
        Function,
    };

    pub const NumEntry = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 1 },
            .{ .fixed = 32 },
        };
        num: u32,
    };

    pub const Simple = struct {
        pub const ops = [_]AbbrevOp{
            .{ .vbr = 4 },
        };
        code: u5,
    };

    pub const Integer = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 7 },
            .{ .fixed = 28 },
        };
        width: u28,
    };

    pub const StructAnon = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 18 },
            .{ .fixed = 1 },
            .{ .array_fixed = 32 },
        };
        is_packed: bool,
        types: []const Builder.Type,
    };

    pub const StructNamed = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 20 },
            .{ .fixed = 1 },
            .{ .array_fixed = 32 },
        };
        is_packed: bool,
        types: []const Builder.Type,
    };

    pub const StructName = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 19 },
            .{ .array_fixed = 8 },
        };
        string: []const u8,
    };

    pub const Array = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 11 },
            .{ .vbr = 16 },
            .{ .fixed = 32 },
        };
        len: u64,
        child: Builder.Type,
    };

    pub const Vector = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 12 },
            .{ .vbr = 16 },
            .{ .fixed = 32 },
        };
        len: u64,
        child: Builder.Type,
    };

    pub const Pointer = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 25 },
            .{ .vbr = 4 },
        };
        addr_space: Builder.AddrSpace,
    };

    pub const Target = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 26 },
            .{ .vbr = 4 },
            .{ .array_fixed = 32 },
            .{ .array_fixed = 32 },
        };
        num_types: u32,
        types: []const Builder.Type,
        ints: []const u32,
    };

    pub const Function = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 21 },
            .{ .fixed = 1 },
            .{ .fixed = 32 },
            .{ .array_fixed = 32 },
        };
        is_vararg: bool,
        return_type: Builder.Type,
        param_types: []const Builder.Type,
    };
};

pub const Paramattr = struct {
    pub const id = 9;

    pub const abbrevs = [_]type{
        Entry,
    };

    pub const Entry = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 2 },
            .{ .array_vbr = 8 },
        };
        group_indices: []const u32,
    };
};

pub const ParamattrGroup = struct {
    pub const id = 10;

    pub const abbrevs = [_]type{};
};

pub const Constants = struct {
    pub const id = 11;

    pub const abbrevs = [_]type{
        SetType,
        Null,
        Undef,
        Poison,
        Integer,
        Half,
        Float,
        Double,
        Aggregate,
        String,
        CString,
    };

    pub const SetType = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 1 },
            .{ .fixed = 32 },
        };
        type_id: Builder.Type,
    };

    pub const Null = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 2 },
        };
    };

    pub const Undef = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 3 },
        };
    };

    pub const Poison = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 26 },
        };
    };

    pub const Integer = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 4 },
            .{ .vbr = 16 },
        };
        value: std.math.big.Limb,
    };

    pub const Half = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 6 },
            .{ .fixed = 16 },
        };
        value: u16,
    };

    pub const Float = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 6 },
            .{ .fixed = 32 },
        };
        value: u32,
    };

    pub const Double = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 6 },
            .{ .vbr = 32 },
        };
        value: u64,
    };

    pub const Aggregate = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 7 },
            .{ .array_fixed = 32 },
        };
        values: []const Builder.Constant,
    };

    pub const String = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 8 },
            .{ .array_fixed = 8 },
        };
        string: []const u8,
    };

    pub const CString = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 9 },
            .{ .array_fixed = 8 },
        };
        string: []const u8,
    };
};

pub const Strtab = struct {
    pub const id = 23;

    pub const abbrevs = [_]type{Blob};

    pub const Blob = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 1 },
            .blob,
        };
        blob: []const u8,
    };
};
