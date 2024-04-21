const std = @import("std");
const Builder = @import("Builder.zig");
const bitcode_writer = @import("bitcode_writer.zig");

const AbbrevOp = bitcode_writer.AbbrevOp;

pub const MAGIC: u32 = 0xdec04342;

const ValueAbbrev = AbbrevOp{ .vbr = 6 };
const ValueArrayAbbrev = AbbrevOp{ .array_vbr = 6 };

const ConstantAbbrev = AbbrevOp{ .vbr = 6 };
const ConstantArrayAbbrev = AbbrevOp{ .array_vbr = 6 };

const MetadataAbbrev = AbbrevOp{ .vbr = 16 };
const MetadataArrayAbbrev = AbbrevOp{ .array_vbr = 16 };

const LineAbbrev = AbbrevOp{ .vbr = 8 };
const ColumnAbbrev = AbbrevOp{ .vbr = 8 };

const BlockAbbrev = AbbrevOp{ .vbr = 6 };

pub const MetadataKind = enum(u1) {
    dbg = 0,
};

pub const Identification = struct {
    pub const id = 13;

    pub const abbrevs = [_]type{
        Version,
        Epoch,
    };

    pub const Version = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 1 },
            .{ .array_fixed = 8 },
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
            .{ .fixed_runtime = Builder.Type },
            .{ .fixed = @bitSizeOf(AddrSpaceAndIsConst) }, // isconst
            ConstantAbbrev, // initid
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
            .{ .fixed_runtime = Builder.Type },
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
            .{ .literal = 0 }, // prefixdata
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
            .{ .literal = 14 }, // Code
            .{ .vbr = 16 }, // strtab_offset
            .{ .vbr = 16 }, // strtab_size
            .{ .fixed_runtime = Builder.Type },
            .{ .fixed = @bitSizeOf(Builder.AddrSpace) },
            ConstantAbbrev, // aliasee val
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

pub const BlockInfo = struct {
    pub const id = 0;

    pub const set_block_id = 1;

    pub const abbrevs = [_]type{};
};

pub const Type = struct {
    pub const id = 17;

    pub const abbrevs = [_]type{
        NumEntry,
        Simple,
        Opaque,
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

    pub const Opaque = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 6 },
            .{ .literal = 0 },
        };
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
            .{ .array_fixed_runtime = Builder.Type },
        };
        is_packed: bool,
        types: []const Builder.Type,
    };

    pub const StructNamed = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 20 },
            .{ .fixed = 1 },
            .{ .array_fixed_runtime = Builder.Type },
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
            .{ .fixed_runtime = Builder.Type },
        };
        len: u64,
        child: Builder.Type,
    };

    pub const Vector = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 12 },
            .{ .vbr = 16 },
            .{ .fixed_runtime = Builder.Type },
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
            .{ .array_fixed_runtime = Builder.Type },
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
            .{ .fixed_runtime = Builder.Type },
            .{ .array_fixed_runtime = Builder.Type },
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
        group_indices: []const u64,
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
        Fp80,
        Fp128,
        Aggregate,
        String,
        CString,
        Cast,
        Binary,
        Cmp,
        ExtractElement,
        InsertElement,
        ShuffleVector,
        ShuffleVectorEx,
        BlockAddress,
        DsoLocalEquivalentOrNoCfi,
    };

    pub const SetType = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 1 },
            .{ .fixed_runtime = Builder.Type },
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
        value: u64,
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
            .{ .vbr = 6 },
        };
        value: u64,
    };

    pub const Fp80 = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 6 },
            .{ .vbr = 6 },
            .{ .vbr = 6 },
        };
        hi: u64,
        lo: u16,
    };

    pub const Fp128 = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 6 },
            .{ .vbr = 6 },
            .{ .vbr = 6 },
        };
        lo: u64,
        hi: u64,
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

    pub const Cast = struct {
        const CastOpcode = Builder.CastOpcode;
        pub const ops = [_]AbbrevOp{
            .{ .literal = 11 },
            .{ .fixed = @bitSizeOf(CastOpcode) },
            .{ .fixed_runtime = Builder.Type },
            ConstantAbbrev,
        };

        opcode: CastOpcode,
        type_index: Builder.Type,
        val: Builder.Constant,
    };

    pub const Binary = struct {
        const BinaryOpcode = Builder.BinaryOpcode;
        pub const ops = [_]AbbrevOp{
            .{ .literal = 10 },
            .{ .fixed = @bitSizeOf(BinaryOpcode) },
            ConstantAbbrev,
            ConstantAbbrev,
        };

        opcode: BinaryOpcode,
        lhs: Builder.Constant,
        rhs: Builder.Constant,
    };

    pub const Cmp = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 17 },
            .{ .fixed_runtime = Builder.Type },
            ConstantAbbrev,
            ConstantAbbrev,
            .{ .vbr = 6 },
        };

        ty: Builder.Type,
        lhs: Builder.Constant,
        rhs: Builder.Constant,
        pred: u32,
    };

    pub const ExtractElement = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 14 },
            .{ .fixed_runtime = Builder.Type },
            ConstantAbbrev,
            .{ .fixed_runtime = Builder.Type },
            ConstantAbbrev,
        };

        val_type: Builder.Type,
        val: Builder.Constant,
        index_type: Builder.Type,
        index: Builder.Constant,
    };

    pub const InsertElement = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 15 },
            ConstantAbbrev,
            ConstantAbbrev,
            .{ .fixed_runtime = Builder.Type },
            ConstantAbbrev,
        };

        val: Builder.Constant,
        elem: Builder.Constant,
        index_type: Builder.Type,
        index: Builder.Constant,
    };

    pub const ShuffleVector = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 16 },
            ValueAbbrev,
            ValueAbbrev,
            ValueAbbrev,
        };

        lhs: Builder.Constant,
        rhs: Builder.Constant,
        mask: Builder.Constant,
    };

    pub const ShuffleVectorEx = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 19 },
            .{ .fixed_runtime = Builder.Type },
            ValueAbbrev,
            ValueAbbrev,
            ValueAbbrev,
        };

        ty: Builder.Type,
        lhs: Builder.Constant,
        rhs: Builder.Constant,
        mask: Builder.Constant,
    };

    pub const BlockAddress = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 21 },
            .{ .fixed_runtime = Builder.Type },
            ConstantAbbrev,
            BlockAbbrev,
        };
        type_id: Builder.Type,
        function: u32,
        block: u32,
    };

    pub const DsoLocalEquivalentOrNoCfi = struct {
        pub const ops = [_]AbbrevOp{
            .{ .fixed = 5 },
            .{ .fixed_runtime = Builder.Type },
            ConstantAbbrev,
        };
        code: u5,
        type_id: Builder.Type,
        function: u32,
    };
};

pub const MetadataKindBlock = struct {
    pub const id = 22;

    pub const abbrevs = [_]type{
        Kind,
    };

    pub const Kind = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 6 },
            .{ .vbr = 4 },
            .{ .array_fixed = 8 },
        };
        id: u32,
        name: []const u8,
    };
};

pub const MetadataAttachmentBlock = struct {
    pub const id = 16;

    pub const abbrevs = [_]type{
        AttachmentSingle,
    };

    pub const AttachmentSingle = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 11 },
            .{ .fixed = 1 },
            MetadataAbbrev,
        };
        kind: MetadataKind,
        metadata: Builder.Metadata,
    };
};

pub const MetadataBlock = struct {
    pub const id = 15;

    pub const abbrevs = [_]type{
        Strings,
        File,
        CompileUnit,
        Subprogram,
        LexicalBlock,
        Location,
        BasicType,
        CompositeType,
        DerivedType,
        SubroutineType,
        Enumerator,
        Subrange,
        Expression,
        Node,
        LocalVar,
        Parameter,
        GlobalVar,
        GlobalVarExpression,
        Constant,
        Name,
        NamedNode,
        GlobalDeclAttachment,
    };

    pub const Strings = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 35 },
            .{ .vbr = 6 },
            .{ .vbr = 6 },
            .blob,
        };
        num_strings: u32,
        strings_offset: u32,
        blob: []const u8,
    };

    pub const File = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 16 },
            .{ .literal = 0 }, // is distinct
            MetadataAbbrev, // filename
            MetadataAbbrev, // directory
            .{ .literal = 0 }, // checksum
            .{ .literal = 0 }, // checksum
        };

        filename: Builder.MetadataString,
        directory: Builder.MetadataString,
    };

    pub const CompileUnit = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 20 },
            .{ .literal = 1 }, // is distinct
            .{ .literal = std.dwarf.LANG.C99 }, // source language
            MetadataAbbrev, // file
            MetadataAbbrev, // producer
            .{ .fixed = 1 }, // isOptimized
            .{ .literal = 0 }, // raw flags
            .{ .literal = 0 }, // runtime version
            .{ .literal = 0 }, // split debug file name
            .{ .literal = 1 }, // emission kind
            MetadataAbbrev, // enums
            .{ .literal = 0 }, // retained types
            .{ .literal = 0 }, // subprograms
            MetadataAbbrev, // globals
            .{ .literal = 0 }, // imported entities
            .{ .literal = 0 }, // DWO ID
            .{ .literal = 0 }, // macros
            .{ .literal = 0 }, // split debug inlining
            .{ .literal = 0 }, // debug info profiling
            .{ .literal = 0 }, // name table kind
            .{ .literal = 0 }, // ranges base address
            .{ .literal = 0 }, // raw sysroot
            .{ .literal = 0 }, // raw SDK
        };

        file: Builder.Metadata,
        producer: Builder.MetadataString,
        is_optimized: bool,
        enums: Builder.Metadata,
        globals: Builder.Metadata,
    };

    pub const Subprogram = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 21 },
            .{ .literal = 0b111 }, // is distinct | has sp flags | has flags
            MetadataAbbrev, // scope
            MetadataAbbrev, // name
            MetadataAbbrev, // linkage name
            MetadataAbbrev, // file
            LineAbbrev, // line
            MetadataAbbrev, // type
            LineAbbrev, // scope line
            .{ .literal = 0 }, // containing type
            .{ .fixed = 32 }, // sp flags
            .{ .literal = 0 }, // virtual index
            .{ .fixed = 32 }, // flags
            MetadataAbbrev, // compile unit
            .{ .literal = 0 }, // template params
            .{ .literal = 0 }, // declaration
            .{ .literal = 0 }, // retained nodes
            .{ .literal = 0 }, // this adjustment
            .{ .literal = 0 }, // thrown types
            .{ .literal = 0 }, // annotations
            .{ .literal = 0 }, // target function name
        };

        scope: Builder.Metadata,
        name: Builder.MetadataString,
        linkage_name: Builder.MetadataString,
        file: Builder.Metadata,
        line: u32,
        ty: Builder.Metadata,
        scope_line: u32,
        sp_flags: Builder.Metadata.Subprogram.DISPFlags,
        flags: Builder.Metadata.DIFlags,
        compile_unit: Builder.Metadata,
    };

    pub const LexicalBlock = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 22 },
            .{ .literal = 0 }, // is distinct
            MetadataAbbrev, // scope
            MetadataAbbrev, // file
            LineAbbrev, // line
            ColumnAbbrev, // column
        };

        scope: Builder.Metadata,
        file: Builder.Metadata,
        line: u32,
        column: u32,
    };

    pub const Location = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 7 },
            .{ .literal = 0 }, // is distinct
            LineAbbrev, // line
            ColumnAbbrev, // column
            MetadataAbbrev, // scope
            MetadataAbbrev, // inlined at
            .{ .literal = 0 }, // is implicit code
        };

        line: u32,
        column: u32,
        scope: u32,
        inlined_at: Builder.Metadata,
    };

    pub const BasicType = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 15 },
            .{ .literal = 0 }, // is distinct
            .{ .literal = std.dwarf.TAG.base_type }, // tag
            MetadataAbbrev, // name
            .{ .vbr = 6 }, // size in bits
            .{ .literal = 0 }, // align in bits
            .{ .vbr = 8 }, // encoding
            .{ .literal = 0 }, // flags
        };

        name: Builder.MetadataString,
        size_in_bits: u64,
        encoding: u32,
    };

    pub const CompositeType = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 18 },
            .{ .literal = 0 | 0x2 }, // is distinct | is not used in old type ref
            .{ .fixed = 32 }, // tag
            MetadataAbbrev, // name
            MetadataAbbrev, // file
            LineAbbrev, // line
            MetadataAbbrev, // scope
            MetadataAbbrev, // underlying type
            .{ .vbr = 6 }, // size in bits
            .{ .vbr = 6 }, // align in bits
            .{ .literal = 0 }, // offset in bits
            .{ .fixed = 32 }, // flags
            MetadataAbbrev, // elements
            .{ .literal = 0 }, // runtime lang
            .{ .literal = 0 }, // vtable holder
            .{ .literal = 0 }, // template params
            .{ .literal = 0 }, // raw id
            .{ .literal = 0 }, // discriminator
            .{ .literal = 0 }, // data location
            .{ .literal = 0 }, // associated
            .{ .literal = 0 }, // allocated
            .{ .literal = 0 }, // rank
            .{ .literal = 0 }, // annotations
        };

        tag: u32,
        name: Builder.MetadataString,
        file: Builder.Metadata,
        line: u32,
        scope: Builder.Metadata,
        underlying_type: Builder.Metadata,
        size_in_bits: u64,
        align_in_bits: u64,
        flags: Builder.Metadata.DIFlags,
        elements: Builder.Metadata,
    };

    pub const DerivedType = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 17 },
            .{ .literal = 0 }, // is distinct
            .{ .fixed = 32 }, // tag
            MetadataAbbrev, // name
            MetadataAbbrev, // file
            LineAbbrev, // line
            MetadataAbbrev, // scope
            MetadataAbbrev, // underlying type
            .{ .vbr = 6 }, // size in bits
            .{ .vbr = 6 }, // align in bits
            .{ .vbr = 6 }, // offset in bits
            .{ .literal = 0 }, // flags
            .{ .literal = 0 }, // extra data
        };

        tag: u32,
        name: Builder.MetadataString,
        file: Builder.Metadata,
        line: u32,
        scope: Builder.Metadata,
        underlying_type: Builder.Metadata,
        size_in_bits: u64,
        align_in_bits: u64,
        offset_in_bits: u64,
    };

    pub const SubroutineType = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 19 },
            .{ .literal = 0 | 0x2 }, // is distinct | has no old type refs
            .{ .literal = 0 }, // flags
            MetadataAbbrev, // types
            .{ .literal = 0 }, // cc
        };

        types: Builder.Metadata,
    };

    pub const Enumerator = struct {
        pub const id = 14;

        pub const Flags = packed struct(u3) {
            distinct: bool = false,
            unsigned: bool,
            bigint: bool = true,
        };

        pub const ops = [_]AbbrevOp{
            .{ .literal = Enumerator.id },
            .{ .fixed = @bitSizeOf(Flags) }, // flags
            .{ .vbr = 6 }, // bit width
            MetadataAbbrev, // name
            .{ .vbr = 16 }, // integer value
        };

        flags: Flags,
        bit_width: u32,
        name: Builder.MetadataString,
        value: u64,
    };

    pub const Subrange = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 13 },
            .{ .literal = 0b10 }, // is distinct | version
            MetadataAbbrev, // count
            MetadataAbbrev, // lower bound
            .{ .literal = 0 }, // upper bound
            .{ .literal = 0 }, // stride
        };

        count: Builder.Metadata,
        lower_bound: Builder.Metadata,
    };

    pub const Expression = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 29 },
            .{ .literal = 0 | (3 << 1) }, // is distinct | version
            MetadataArrayAbbrev, // elements
        };

        elements: []const u32,
    };

    pub const Node = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 3 },
            MetadataArrayAbbrev, // elements
        };

        elements: []const Builder.Metadata,
    };

    pub const LocalVar = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 28 },
            .{ .literal = 0b10 }, // is distinct | has alignment
            MetadataAbbrev, // scope
            MetadataAbbrev, // name
            MetadataAbbrev, // file
            LineAbbrev, // line
            MetadataAbbrev, // type
            .{ .literal = 0 }, // arg
            .{ .literal = 0 }, // flags
            .{ .literal = 0 }, // align bits
            .{ .literal = 0 }, // annotations
        };

        scope: Builder.Metadata,
        name: Builder.MetadataString,
        file: Builder.Metadata,
        line: u32,
        ty: Builder.Metadata,
    };

    pub const Parameter = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 28 },
            .{ .literal = 0b10 }, // is distinct | has alignment
            MetadataAbbrev, // scope
            MetadataAbbrev, // name
            MetadataAbbrev, // file
            LineAbbrev, // line
            MetadataAbbrev, // type
            .{ .vbr = 4 }, // arg
            .{ .literal = 0 }, // flags
            .{ .literal = 0 }, // align bits
            .{ .literal = 0 }, // annotations
        };

        scope: Builder.Metadata,
        name: Builder.MetadataString,
        file: Builder.Metadata,
        line: u32,
        ty: Builder.Metadata,
        arg: u32,
    };

    pub const GlobalVar = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 27 },
            .{ .literal = 0b101 }, // is distinct | version
            MetadataAbbrev, // scope
            MetadataAbbrev, // name
            MetadataAbbrev, // linkage name
            MetadataAbbrev, // file
            LineAbbrev, // line
            MetadataAbbrev, // type
            .{ .fixed = 1 }, // local
            .{ .literal = 1 }, // defined
            .{ .literal = 0 }, // static data members declaration
            .{ .literal = 0 }, // template params
            .{ .literal = 0 }, // align in bits
            .{ .literal = 0 }, // annotations
        };

        scope: Builder.Metadata,
        name: Builder.MetadataString,
        linkage_name: Builder.MetadataString,
        file: Builder.Metadata,
        line: u32,
        ty: Builder.Metadata,
        local: bool,
    };

    pub const GlobalVarExpression = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 37 },
            .{ .literal = 0 }, // is distinct
            MetadataAbbrev, // variable
            MetadataAbbrev, // expression
        };

        variable: Builder.Metadata,
        expression: Builder.Metadata,
    };

    pub const Constant = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 2 },
            MetadataAbbrev, // type
            MetadataAbbrev, // value
        };

        ty: Builder.Type,
        constant: Builder.Constant,
    };

    pub const Name = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 4 },
            .{ .array_fixed = 8 }, // name
        };

        name: []const u8,
    };

    pub const NamedNode = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 10 },
            MetadataArrayAbbrev, // elements
        };

        elements: []const Builder.Metadata,
    };

    pub const GlobalDeclAttachment = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 36 },
            ValueAbbrev, // value id
            .{ .fixed = 1 }, // kind
            MetadataAbbrev, // elements
        };

        value: Builder.Constant,
        kind: MetadataKind,
        metadata: Builder.Metadata,
    };
};

pub const FunctionMetadataBlock = struct {
    pub const id = 15;

    pub const abbrevs = [_]type{
        Value,
    };

    pub const Value = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 2 },
            .{ .fixed = 32 }, // variable
            .{ .fixed = 32 }, // expression
        };

        ty: Builder.Type,
        value: Builder.Value,
    };
};

pub const FunctionBlock = struct {
    pub const id = 12;

    pub const abbrevs = [_]type{
        DeclareBlocks,
        Call,
        CallFast,
        FNeg,
        FNegFast,
        Binary,
        BinaryNoWrap,
        BinaryExact,
        BinaryFast,
        Cmp,
        CmpFast,
        Select,
        SelectFast,
        Cast,
        Alloca,
        GetElementPtr,
        ExtractValue,
        InsertValue,
        ExtractElement,
        InsertElement,
        ShuffleVector,
        RetVoid,
        Ret,
        Unreachable,
        Load,
        LoadAtomic,
        Store,
        StoreAtomic,
        BrUnconditional,
        BrConditional,
        VaArg,
        AtomicRmw,
        CmpXchg,
        Fence,
        DebugLoc,
        DebugLocAgain,
    };

    pub const DeclareBlocks = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 1 },
            .{ .vbr = 8 },
        };
        num_blocks: usize,
    };

    pub const Call = struct {
        pub const CallType = packed struct(u17) {
            tail: bool = false,
            call_conv: Builder.CallConv,
            reserved: u3 = 0,
            must_tail: bool = false,
            // We always use the explicit type version as that is what LLVM does
            explicit_type: bool = true,
            no_tail: bool = false,
        };
        pub const ops = [_]AbbrevOp{
            .{ .literal = 34 },
            .{ .fixed_runtime = Builder.FunctionAttributes },
            .{ .fixed = @bitSizeOf(CallType) },
            .{ .fixed_runtime = Builder.Type },
            ValueAbbrev, // Callee
            ValueArrayAbbrev, // Args
        };

        attributes: Builder.FunctionAttributes,
        call_type: CallType,
        type_id: Builder.Type,
        callee: Builder.Value,
        args: []const Builder.Value,
    };

    pub const CallFast = struct {
        const CallType = packed struct(u18) {
            tail: bool = false,
            call_conv: Builder.CallConv,
            reserved: u3 = 0,
            must_tail: bool = false,
            // We always use the explicit type version as that is what LLVM does
            explicit_type: bool = true,
            no_tail: bool = false,
            fast: bool = true,
        };

        pub const ops = [_]AbbrevOp{
            .{ .literal = 34 },
            .{ .fixed_runtime = Builder.FunctionAttributes },
            .{ .fixed = @bitSizeOf(CallType) },
            .{ .fixed = @bitSizeOf(Builder.FastMath) },
            .{ .fixed_runtime = Builder.Type },
            ValueAbbrev, // Callee
            ValueArrayAbbrev, // Args
        };

        attributes: Builder.FunctionAttributes,
        call_type: CallType,
        fast_math: Builder.FastMath,
        type_id: Builder.Type,
        callee: Builder.Value,
        args: []const Builder.Value,
    };

    pub const FNeg = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 56 },
            ValueAbbrev,
            .{ .literal = 0 },
        };

        val: u32,
    };

    pub const FNegFast = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 56 },
            ValueAbbrev,
            .{ .literal = 0 },
            .{ .fixed = @bitSizeOf(Builder.FastMath) },
        };

        val: u32,
        fast_math: Builder.FastMath,
    };

    pub const Binary = struct {
        const BinaryOpcode = Builder.BinaryOpcode;
        pub const ops = [_]AbbrevOp{
            .{ .literal = 2 },
            ValueAbbrev,
            ValueAbbrev,
            .{ .fixed = @bitSizeOf(BinaryOpcode) },
        };

        lhs: u32,
        rhs: u32,
        opcode: BinaryOpcode,
    };

    pub const BinaryNoWrap = struct {
        const BinaryOpcode = Builder.BinaryOpcode;
        pub const ops = [_]AbbrevOp{
            .{ .literal = 2 },
            ValueAbbrev,
            ValueAbbrev,
            .{ .fixed = @bitSizeOf(BinaryOpcode) },
            .{ .fixed = 2 },
        };

        lhs: u32,
        rhs: u32,
        opcode: BinaryOpcode,
        flags: packed struct(u2) {
            no_unsigned_wrap: bool,
            no_signed_wrap: bool,
        },
    };

    pub const BinaryExact = struct {
        const BinaryOpcode = Builder.BinaryOpcode;
        pub const ops = [_]AbbrevOp{
            .{ .literal = 2 },
            ValueAbbrev,
            ValueAbbrev,
            .{ .fixed = @bitSizeOf(BinaryOpcode) },
            .{ .literal = 1 },
        };

        lhs: u32,
        rhs: u32,
        opcode: BinaryOpcode,
    };

    pub const BinaryFast = struct {
        const BinaryOpcode = Builder.BinaryOpcode;
        pub const ops = [_]AbbrevOp{
            .{ .literal = 2 },
            ValueAbbrev,
            ValueAbbrev,
            .{ .fixed = @bitSizeOf(BinaryOpcode) },
            .{ .fixed = @bitSizeOf(Builder.FastMath) },
        };

        lhs: u32,
        rhs: u32,
        opcode: BinaryOpcode,
        fast_math: Builder.FastMath,
    };

    pub const Cmp = struct {
        const CmpPredicate = Builder.CmpPredicate;
        pub const ops = [_]AbbrevOp{
            .{ .literal = 28 },
            ValueAbbrev,
            ValueAbbrev,
            .{ .fixed = @bitSizeOf(CmpPredicate) },
        };

        lhs: u32,
        rhs: u32,
        pred: CmpPredicate,
    };

    pub const CmpFast = struct {
        const CmpPredicate = Builder.CmpPredicate;
        pub const ops = [_]AbbrevOp{
            .{ .literal = 28 },
            ValueAbbrev,
            ValueAbbrev,
            .{ .fixed = @bitSizeOf(CmpPredicate) },
            .{ .fixed = @bitSizeOf(Builder.FastMath) },
        };

        lhs: u32,
        rhs: u32,
        pred: CmpPredicate,
        fast_math: Builder.FastMath,
    };

    pub const Select = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 29 },
            ValueAbbrev,
            ValueAbbrev,
            ValueAbbrev,
        };

        lhs: u32,
        rhs: u32,
        cond: u32,
    };

    pub const SelectFast = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 29 },
            ValueAbbrev,
            ValueAbbrev,
            ValueAbbrev,
            .{ .fixed = @bitSizeOf(Builder.FastMath) },
        };

        lhs: u32,
        rhs: u32,
        cond: u32,
        fast_math: Builder.FastMath,
    };

    pub const Cast = struct {
        const CastOpcode = Builder.CastOpcode;
        pub const ops = [_]AbbrevOp{
            .{ .literal = 3 },
            ValueAbbrev,
            .{ .fixed_runtime = Builder.Type },
            .{ .fixed = @bitSizeOf(CastOpcode) },
        };

        val: u32,
        type_index: Builder.Type,
        opcode: CastOpcode,
    };

    pub const Alloca = struct {
        pub const Flags = packed struct(u11) {
            align_lower: u5,
            inalloca: bool,
            explicit_type: bool,
            swift_error: bool,
            align_upper: u3,
        };
        pub const ops = [_]AbbrevOp{
            .{ .literal = 19 },
            .{ .fixed_runtime = Builder.Type },
            .{ .fixed_runtime = Builder.Type },
            ValueAbbrev,
            .{ .fixed = @bitSizeOf(Flags) },
        };

        inst_type: Builder.Type,
        len_type: Builder.Type,
        len_value: u32,
        flags: Flags,
    };

    pub const RetVoid = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 10 },
        };
    };

    pub const Ret = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 10 },
            ValueAbbrev,
        };
        val: u32,
    };

    pub const GetElementPtr = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 43 },
            .{ .fixed = 1 },
            .{ .fixed_runtime = Builder.Type },
            ValueAbbrev,
            ValueArrayAbbrev,
        };

        is_inbounds: bool,
        type_index: Builder.Type,
        base: Builder.Value,
        indices: []const Builder.Value,
    };

    pub const ExtractValue = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 26 },
            ValueAbbrev,
            ValueArrayAbbrev,
        };

        val: u32,
        indices: []const u32,
    };

    pub const InsertValue = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 27 },
            ValueAbbrev,
            ValueAbbrev,
            ValueArrayAbbrev,
        };

        val: u32,
        elem: u32,
        indices: []const u32,
    };

    pub const ExtractElement = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 6 },
            ValueAbbrev,
            ValueAbbrev,
        };

        val: u32,
        index: u32,
    };

    pub const InsertElement = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 7 },
            ValueAbbrev,
            ValueAbbrev,
            ValueAbbrev,
        };

        val: u32,
        elem: u32,
        index: u32,
    };

    pub const ShuffleVector = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 8 },
            ValueAbbrev,
            ValueAbbrev,
            ValueAbbrev,
        };

        lhs: u32,
        rhs: u32,
        mask: u32,
    };

    pub const Unreachable = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 15 },
        };
    };

    pub const Load = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 20 },
            ValueAbbrev,
            .{ .fixed_runtime = Builder.Type },
            .{ .fixed = @bitSizeOf(Builder.Alignment) },
            .{ .fixed = 1 },
        };
        ptr: u32,
        ty: Builder.Type,
        alignment: std.meta.Int(.unsigned, @bitSizeOf(Builder.Alignment)),
        is_volatile: bool,
    };

    pub const LoadAtomic = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 41 },
            ValueAbbrev,
            .{ .fixed_runtime = Builder.Type },
            .{ .fixed = @bitSizeOf(Builder.Alignment) },
            .{ .fixed = 1 },
            .{ .fixed = @bitSizeOf(Builder.AtomicOrdering) },
            .{ .fixed = @bitSizeOf(Builder.SyncScope) },
        };
        ptr: u32,
        ty: Builder.Type,
        alignment: std.meta.Int(.unsigned, @bitSizeOf(Builder.Alignment)),
        is_volatile: bool,
        success_ordering: Builder.AtomicOrdering,
        sync_scope: Builder.SyncScope,
    };

    pub const Store = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 44 },
            ValueAbbrev,
            ValueAbbrev,
            .{ .fixed = @bitSizeOf(Builder.Alignment) },
            .{ .fixed = 1 },
        };
        ptr: u32,
        val: u32,
        alignment: std.meta.Int(.unsigned, @bitSizeOf(Builder.Alignment)),
        is_volatile: bool,
    };

    pub const StoreAtomic = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 45 },
            ValueAbbrev,
            ValueAbbrev,
            .{ .fixed = @bitSizeOf(Builder.Alignment) },
            .{ .fixed = 1 },
            .{ .fixed = @bitSizeOf(Builder.AtomicOrdering) },
            .{ .fixed = @bitSizeOf(Builder.SyncScope) },
        };
        ptr: u32,
        val: u32,
        alignment: std.meta.Int(.unsigned, @bitSizeOf(Builder.Alignment)),
        is_volatile: bool,
        success_ordering: Builder.AtomicOrdering,
        sync_scope: Builder.SyncScope,
    };

    pub const BrUnconditional = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 11 },
            BlockAbbrev,
        };
        block: u32,
    };

    pub const BrConditional = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 11 },
            BlockAbbrev,
            BlockAbbrev,
            BlockAbbrev,
        };
        then_block: u32,
        else_block: u32,
        condition: u32,
    };

    pub const VaArg = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 23 },
            .{ .fixed_runtime = Builder.Type },
            ValueAbbrev,
            .{ .fixed_runtime = Builder.Type },
        };
        list_type: Builder.Type,
        list: u32,
        type: Builder.Type,
    };

    pub const AtomicRmw = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 59 },
            ValueAbbrev,
            ValueAbbrev,
            .{ .fixed = @bitSizeOf(Builder.Function.Instruction.AtomicRmw.Operation) },
            .{ .fixed = 1 },
            .{ .fixed = @bitSizeOf(Builder.AtomicOrdering) },
            .{ .fixed = @bitSizeOf(Builder.SyncScope) },
            .{ .fixed = @bitSizeOf(Builder.Alignment) },
        };
        ptr: u32,
        val: u32,
        operation: Builder.Function.Instruction.AtomicRmw.Operation,
        is_volatile: bool,
        success_ordering: Builder.AtomicOrdering,
        sync_scope: Builder.SyncScope,
        alignment: std.meta.Int(.unsigned, @bitSizeOf(Builder.Alignment)),
    };

    pub const CmpXchg = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 46 },
            ValueAbbrev,
            ValueAbbrev,
            ValueAbbrev,
            .{ .fixed = 1 },
            .{ .fixed = @bitSizeOf(Builder.AtomicOrdering) },
            .{ .fixed = @bitSizeOf(Builder.SyncScope) },
            .{ .fixed = @bitSizeOf(Builder.AtomicOrdering) },
            .{ .fixed = 1 },
            .{ .fixed = @bitSizeOf(Builder.Alignment) },
        };
        ptr: u32,
        cmp: u32,
        new: u32,
        is_volatile: bool,
        success_ordering: Builder.AtomicOrdering,
        sync_scope: Builder.SyncScope,
        failure_ordering: Builder.AtomicOrdering,
        is_weak: bool,
        alignment: std.meta.Int(.unsigned, @bitSizeOf(Builder.Alignment)),
    };

    pub const Fence = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 36 },
            .{ .fixed = @bitSizeOf(Builder.AtomicOrdering) },
            .{ .fixed = @bitSizeOf(Builder.SyncScope) },
        };
        ordering: Builder.AtomicOrdering,
        sync_scope: Builder.SyncScope,
    };

    pub const DebugLoc = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 35 },
            LineAbbrev,
            ColumnAbbrev,
            MetadataAbbrev,
            MetadataAbbrev,
            .{ .literal = 0 },
        };
        line: u32,
        column: u32,
        scope: Builder.Metadata,
        inlined_at: Builder.Metadata,
    };

    pub const DebugLocAgain = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 33 },
        };
    };
};

pub const FunctionValueSymbolTable = struct {
    pub const id = 14;

    pub const abbrevs = [_]type{
        BlockEntry,
    };

    pub const BlockEntry = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = 2 },
            ValueAbbrev,
            .{ .array_fixed = 8 },
        };
        value_id: u32,
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
