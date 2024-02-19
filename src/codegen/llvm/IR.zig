const std = @import("std");
const Builder = @import("Builder.zig");
const bitcode_writer = @import("bitcode_writer.zig");

const AbbrevOp = bitcode_writer.AbbrevOp;

pub const MAGIC: u32 = 0xdec04342;

const ValueAbbrev = AbbrevOp{ .vbr = 6 };
const ValueArrayAbbrev = AbbrevOp{ .array_vbr = 6 };

const ConstantAbbrev = AbbrevOp{ .vbr = 6 };
const ConstantArrayAbbrev = AbbrevOp{ .array_vbr = 6 };

const BlockAbbrev = AbbrevOp{ .vbr = 6 };

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
            .{ .literal = 9 }, // Code
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
        lo: u64,
        hi: u16,
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

pub const FunctionBlock = struct {
    pub const id = 12;

    pub const abbrevs = [_]type{
        DeclareBlocks,
        Call,
        CallFast,
        FNeg,
        FNegFast,
        Binary,
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