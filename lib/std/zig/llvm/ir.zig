const std = @import("../../std.zig");
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
const BlockArrayAbbrev = AbbrevOp{ .array_vbr = 6 };

/// All bitcode files can optionally include a BLOCKINFO block, which contains
/// metadata about other blocks in the file.
/// The only top-level block types are MODULE, IDENTIFICATION, STRTAB and SYMTAB.
pub const BlockId = enum(u5) {
    /// BLOCKINFO_BLOCK is used to define metadata about blocks, for example,
    /// standard abbrevs that should be available to all blocks of a specified
    /// ID.
    BLOCKINFO = 0,

    /// Blocks
    MODULE = FIRST_APPLICATION,

    /// Module sub-block id's.
    PARAMATTR,
    PARAMATTR_GROUP,

    CONSTANTS,
    FUNCTION,

    /// Block intended to contains information on the bitcode versioning.
    /// Can be used to provide better error messages when we fail to parse a
    /// bitcode file.
    IDENTIFICATION,

    VALUE_SYMTAB,
    METADATA,
    METADATA_ATTACHMENT,

    TYPE,

    USELIST,

    MODULE_STRTAB,
    GLOBALVAL_SUMMARY,

    OPERAND_BUNDLE_TAGS,

    METADATA_KIND,

    STRTAB,

    FULL_LTO_GLOBALVAL_SUMMARY,

    SYMTAB,

    SYNC_SCOPE_NAMES,

    /// Block IDs 1-7 are reserved for future expansion.
    pub const FIRST_APPLICATION = 8;
};

/// Unused tags are commented out so that they are omitted in the generated
/// bitcode, which scans over this enum using reflection.
pub const FixedMetadataKind = enum(u6) {
    dbg = 0,
    //tbaa = 1,
    prof = 2,
    //fpmath = 3,
    //range = 4,
    //@"tbaa.struct" = 5,
    //@"invariant.load" = 6,
    //@"alias.scope" = 7,
    //@"noalias" = 8,
    //nontemporal = 9,
    //@"llvm.mem.parallel_loop_access" = 10,
    //nonnull = 11,
    //dereferenceable = 12,
    //dereferenceable_or_null = 13,
    //@"make.implicit" = 14,
    unpredictable = 15,
    //@"invariant.group" = 16,
    //@"align" = 17,
    //@"llvm.loop" = 18,
    //type = 19,
    //section_prefix = 20,
    //absolute_symbol = 21,
    //associated = 22,
    //callees = 23,
    //irr_loop = 24,
    //@"llvm.access.group" = 25,
    //callback = 26,
    //@"llvm.preserve.access.index" = 27,
    //vcall_visibility = 28,
    //noundef = 29,
    //annotation = 30,
    //nosanitize = 31,
    //func_sanitize = 32,
    //exclude = 33,
    //memprof = 34,
    //callsite = 35,
    //kcfi_type = 36,
    //pcsections = 37,
    //DIAssignID = 38,
    //@"coro.outside.frame" = 39,
};

pub const BlockInfoBlock = struct {
    pub const id: BlockId = .BLOCKINFO;

    pub const set_block_id = 1;

    pub const abbrevs = [_]type{};
};

/// MODULE blocks have a number of optional fields and subblocks.
pub const ModuleBlock = struct {
    pub const id: BlockId = .MODULE;

    pub const abbrevs = [_]type{
        ModuleBlock.Version,
        ModuleBlock.String,
        ModuleBlock.Variable,
        ModuleBlock.Function,
        ModuleBlock.Alias,
    };

    pub const Code = enum(u5) {
        /// VERSION:     [version#]
        VERSION = 1,
        /// TRIPLE:      [strchr x N]
        TRIPLE = 2,
        /// DATALAYOUT:  [strchr x N]
        DATALAYOUT = 3,
        /// ASM:         [strchr x N]
        ASM = 4,
        /// SECTIONNAME: [strchr x N]
        SECTIONNAME = 5,

        /// Deprecated, but still needed to read old bitcode files.
        /// DEPLIB:      [strchr x N]
        DEPLIB = 6,

        /// GLOBALVAR: [pointer type, isconst, initid,
        ///             linkage, alignment, section, visibility, threadlocal]
        GLOBALVAR = 7,

        /// FUNCTION:  [type, callingconv, isproto, linkage, paramattrs, alignment,
        ///             section, visibility, gc, unnamed_addr]
        FUNCTION = 8,

        /// ALIAS: [alias type, aliasee val#, linkage, visibility]
        ALIAS_OLD = 9,

        /// GCNAME: [strchr x N]
        GCNAME = 11,
        /// COMDAT: [selection_kind, name]
        COMDAT = 12,

        /// VSTOFFSET: [offset]
        VSTOFFSET = 13,

        /// ALIAS: [alias value type, addrspace, aliasee val#, linkage, visibility]
        ALIAS = 14,

        METADATA_VALUES_UNUSED = 15,

        /// SOURCE_FILENAME: [namechar x N]
        SOURCE_FILENAME = 16,

        /// HASH: [5*i32]
        HASH = 17,

        /// IFUNC: [ifunc value type, addrspace, resolver val#, linkage, visibility]
        IFUNC = 18,
    };

    pub const Version = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = @intFromEnum(ModuleBlock.Code.VERSION) },
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
            .{ .literal = @intFromEnum(ModuleBlock.Code.GLOBALVAR) }, // Code
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
            .{ .literal = @intFromEnum(ModuleBlock.Code.FUNCTION) }, // Code
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
            .{ .literal = @intFromEnum(ModuleBlock.Code.ALIAS) }, // Code
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

    /// PARAMATTR blocks have code for defining a parameter attribute set.
    pub const ParamattrBlock = struct {
        pub const id: BlockId = .PARAMATTR;

        pub const abbrevs = [_]type{
            ModuleBlock.ParamattrBlock.Entry,
        };

        pub const Code = enum(u2) {
            /// Deprecated, but still needed to read old bitcode files.
            /// ENTRY: [paramidx0, attr0, paramidx1, attr1...]
            ENTRY_OLD = 1,
            /// ENTRY: [attrgrp0, attrgrp1, ...]
            ENTRY = 2,
        };

        pub const Entry = struct {
            pub const ops = [_]AbbrevOp{
                .{ .literal = @intFromEnum(ModuleBlock.ParamattrBlock.Code.ENTRY) },
                .{ .array_vbr = 8 },
            };
            group_indices: []const u64,
        };
    };

    pub const ParamattrGroupBlock = struct {
        pub const id: BlockId = .PARAMATTR_GROUP;

        pub const abbrevs = [_]type{};

        pub const Code = enum(u2) {
            /// ENTRY: [grpid, idx, attr0, attr1, ...]
            CODE_ENTRY = 3,
        };
    };

    /// The constants block (CONSTANTS_BLOCK_ID) describes emission for each
    /// constant and maintains an implicit current type value.
    pub const ConstantsBlock = struct {
        pub const id: BlockId = .CONSTANTS;

        pub const abbrevs = [_]type{
            ModuleBlock.ConstantsBlock.SetType,
            ModuleBlock.ConstantsBlock.Null,
            ModuleBlock.ConstantsBlock.Undef,
            ModuleBlock.ConstantsBlock.Poison,
            ModuleBlock.ConstantsBlock.Integer,
            ModuleBlock.ConstantsBlock.Half,
            ModuleBlock.ConstantsBlock.Float,
            ModuleBlock.ConstantsBlock.Double,
            ModuleBlock.ConstantsBlock.Fp80,
            ModuleBlock.ConstantsBlock.Fp128,
            ModuleBlock.ConstantsBlock.Aggregate,
            ModuleBlock.ConstantsBlock.String,
            ModuleBlock.ConstantsBlock.CString,
            ModuleBlock.ConstantsBlock.Cast,
            ModuleBlock.ConstantsBlock.Binary,
            ModuleBlock.ConstantsBlock.Cmp,
            ModuleBlock.ConstantsBlock.ExtractElement,
            ModuleBlock.ConstantsBlock.InsertElement,
            ModuleBlock.ConstantsBlock.ShuffleVector,
            ModuleBlock.ConstantsBlock.ShuffleVectorEx,
            ModuleBlock.ConstantsBlock.BlockAddress,
            ModuleBlock.ConstantsBlock.DsoLocalEquivalentOrNoCfi,
        };

        pub const Code = enum(u6) {
            /// SETTYPE:       [typeid]
            SETTYPE = 1,
            /// NULL
            NULL = 2,
            /// UNDEF
            UNDEF = 3,
            /// INTEGER:       [intval]
            INTEGER = 4,
            /// WIDE_INTEGER:  [n x intval]
            WIDE_INTEGER = 5,
            /// FLOAT:         [fpval]
            FLOAT = 6,
            /// AGGREGATE:     [n x value number]
            AGGREGATE = 7,
            /// STRING:        [values]
            STRING = 8,
            /// CSTRING:       [values]
            CSTRING = 9,
            /// CE_BINOP:      [opcode, opval, opval]
            CE_BINOP = 10,
            /// CE_CAST:       [opcode, opty, opval]
            CE_CAST = 11,
            /// CE_GEP:        [n x operands]
            CE_GEP_OLD = 12,
            /// CE_SELECT:     [opval, opval, opval]
            CE_SELECT = 13,
            /// CE_EXTRACTELT: [opty, opval, opval]
            CE_EXTRACTELT = 14,
            /// CE_INSERTELT:  [opval, opval, opval]
            CE_INSERTELT = 15,
            /// CE_SHUFFLEVEC: [opval, opval, opval]
            CE_SHUFFLEVEC = 16,
            /// CE_CMP:        [opty, opval, opval, pred]
            CE_CMP = 17,
            /// INLINEASM:     [sideeffect|alignstack,asmstr,conststr]
            INLINEASM_OLD = 18,
            /// SHUFVEC_EX:    [opty, opval, opval, opval]
            CE_SHUFVEC_EX = 19,
            /// INBOUNDS_GEP:  [n x operands]
            CE_INBOUNDS_GEP = 20,
            /// BLOCKADDRESS:  [fnty, fnval, bb#]
            BLOCKADDRESS = 21,
            /// DATA:          [n x elements]
            DATA = 22,
            /// INLINEASM:     [sideeffect|alignstack|asmdialect,asmstr,conststr]
            INLINEASM_OLD2 = 23,
            ///  [opty, flags, n x operands]
            CE_GEP_WITH_INRANGE_INDEX_OLD = 24,
            /// CE_UNOP:       [opcode, opval]
            CE_UNOP = 25,
            /// POISON
            POISON = 26,
            /// DSO_LOCAL_EQUIVALENT [gvty, gv]
            DSO_LOCAL_EQUIVALENT = 27,
            /// INLINEASM:     [sideeffect|alignstack|asmdialect|unwind,asmstr,
            ///                 conststr]
            INLINEASM_OLD3 = 28,
            /// NO_CFI [ fty, f ]
            NO_CFI_VALUE = 29,
            /// INLINEASM:     [fnty,sideeffect|alignstack|asmdialect|unwind,
            ///                 asmstr,conststr]
            INLINEASM = 30,
            /// [opty, flags, range, n x operands]
            CE_GEP_WITH_INRANGE = 31,
            /// [opty, flags, n x operands]
            CE_GEP = 32,
            /// [ptr, key, disc, addrdisc]
            PTRAUTH = 33,
        };

        pub const SetType = struct {
            pub const ops = [_]AbbrevOp{
                .{ .literal = @intFromEnum(ModuleBlock.ConstantsBlock.Code.SETTYPE) },
                .{ .fixed_runtime = Builder.Type },
            };
            type_id: Builder.Type,
        };

        pub const Null = struct {
            pub const ops = [_]AbbrevOp{
                .{ .literal = @intFromEnum(ModuleBlock.ConstantsBlock.Code.NULL) },
            };
        };

        pub const Undef = struct {
            pub const ops = [_]AbbrevOp{
                .{ .literal = @intFromEnum(ModuleBlock.ConstantsBlock.Code.UNDEF) },
            };
        };

        pub const Poison = struct {
            pub const ops = [_]AbbrevOp{
                .{ .literal = @intFromEnum(ModuleBlock.ConstantsBlock.Code.POISON) },
            };
        };

        pub const Integer = struct {
            pub const ops = [_]AbbrevOp{
                .{ .literal = @intFromEnum(ModuleBlock.ConstantsBlock.Code.INTEGER) },
                .{ .vbr = 16 },
            };
            value: u64,
        };

        pub const Half = struct {
            pub const ops = [_]AbbrevOp{
                .{ .literal = @intFromEnum(ModuleBlock.ConstantsBlock.Code.FLOAT) },
                .{ .fixed = 16 },
            };
            value: u16,
        };

        pub const Float = struct {
            pub const ops = [_]AbbrevOp{
                .{ .literal = @intFromEnum(ModuleBlock.ConstantsBlock.Code.FLOAT) },
                .{ .fixed = 32 },
            };
            value: u32,
        };

        pub const Double = struct {
            pub const ops = [_]AbbrevOp{
                .{ .literal = @intFromEnum(ModuleBlock.ConstantsBlock.Code.FLOAT) },
                .{ .vbr = 6 },
            };
            value: u64,
        };

        pub const Fp80 = struct {
            pub const ops = [_]AbbrevOp{
                .{ .literal = @intFromEnum(ModuleBlock.ConstantsBlock.Code.FLOAT) },
                .{ .vbr = 6 },
                .{ .vbr = 6 },
            };
            hi: u64,
            lo: u16,
        };

        pub const Fp128 = struct {
            pub const ops = [_]AbbrevOp{
                .{ .literal = @intFromEnum(ModuleBlock.ConstantsBlock.Code.FLOAT) },
                .{ .vbr = 6 },
                .{ .vbr = 6 },
            };
            lo: u64,
            hi: u64,
        };

        pub const Aggregate = struct {
            pub const ops = [_]AbbrevOp{
                .{ .literal = @intFromEnum(ModuleBlock.ConstantsBlock.Code.AGGREGATE) },
                .{ .array_fixed = 32 },
            };
            values: []const Builder.Constant,
        };

        pub const String = struct {
            pub const ops = [_]AbbrevOp{
                .{ .literal = @intFromEnum(ModuleBlock.ConstantsBlock.Code.STRING) },
                .{ .array_fixed = 8 },
            };
            string: []const u8,
        };

        pub const CString = struct {
            pub const ops = [_]AbbrevOp{
                .{ .literal = @intFromEnum(ModuleBlock.ConstantsBlock.Code.CSTRING) },
                .{ .array_fixed = 8 },
            };
            string: []const u8,
        };

        pub const Cast = struct {
            const CastOpcode = Builder.CastOpcode;
            pub const ops = [_]AbbrevOp{
                .{ .literal = @intFromEnum(ModuleBlock.ConstantsBlock.Code.CE_CAST) },
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
                .{ .literal = @intFromEnum(ModuleBlock.ConstantsBlock.Code.CE_BINOP) },
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
                .{ .literal = @intFromEnum(ModuleBlock.ConstantsBlock.Code.CE_CMP) },
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
                .{ .literal = @intFromEnum(ModuleBlock.ConstantsBlock.Code.CE_EXTRACTELT) },
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
                .{ .literal = @intFromEnum(ModuleBlock.ConstantsBlock.Code.CE_INSERTELT) },
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
                .{ .literal = @intFromEnum(ModuleBlock.ConstantsBlock.Code.CE_SHUFFLEVEC) },
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
                .{ .literal = @intFromEnum(ModuleBlock.ConstantsBlock.Code.CE_SHUFVEC_EX) },
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
                .{ .literal = @intFromEnum(ModuleBlock.ConstantsBlock.Code.BLOCKADDRESS) },
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
            code: ModuleBlock.ConstantsBlock.Code,
            type_id: Builder.Type,
            function: u32,
        };
    };

    /// The function body block (FUNCTION_BLOCK_ID) describes function bodies.  It
    /// can contain a constant block (CONSTANTS_BLOCK_ID).
    pub const FunctionBlock = struct {
        pub const id: BlockId = .FUNCTION;

        pub const abbrevs = [_]type{
            ModuleBlock.FunctionBlock.DeclareBlocks,
            ModuleBlock.FunctionBlock.Call,
            ModuleBlock.FunctionBlock.CallFast,
            ModuleBlock.FunctionBlock.FNeg,
            ModuleBlock.FunctionBlock.FNegFast,
            ModuleBlock.FunctionBlock.Binary,
            ModuleBlock.FunctionBlock.BinaryNoWrap,
            ModuleBlock.FunctionBlock.BinaryExact,
            ModuleBlock.FunctionBlock.BinaryFast,
            ModuleBlock.FunctionBlock.Cmp,
            ModuleBlock.FunctionBlock.CmpFast,
            ModuleBlock.FunctionBlock.Select,
            ModuleBlock.FunctionBlock.SelectFast,
            ModuleBlock.FunctionBlock.Cast,
            ModuleBlock.FunctionBlock.Alloca,
            ModuleBlock.FunctionBlock.GetElementPtr,
            ModuleBlock.FunctionBlock.ExtractValue,
            ModuleBlock.FunctionBlock.InsertValue,
            ModuleBlock.FunctionBlock.ExtractElement,
            ModuleBlock.FunctionBlock.InsertElement,
            ModuleBlock.FunctionBlock.ShuffleVector,
            ModuleBlock.FunctionBlock.RetVoid,
            ModuleBlock.FunctionBlock.Ret,
            ModuleBlock.FunctionBlock.Unreachable,
            ModuleBlock.FunctionBlock.Load,
            ModuleBlock.FunctionBlock.LoadAtomic,
            ModuleBlock.FunctionBlock.Store,
            ModuleBlock.FunctionBlock.StoreAtomic,
            ModuleBlock.FunctionBlock.BrUnconditional,
            ModuleBlock.FunctionBlock.BrConditional,
            ModuleBlock.FunctionBlock.VaArg,
            ModuleBlock.FunctionBlock.AtomicRmw,
            ModuleBlock.FunctionBlock.CmpXchg,
            ModuleBlock.FunctionBlock.Fence,
            ModuleBlock.FunctionBlock.DebugLoc,
            ModuleBlock.FunctionBlock.DebugLocAgain,
            ModuleBlock.FunctionBlock.ColdOperandBundle,
            ModuleBlock.FunctionBlock.IndirectBr,
        };

        pub const Code = enum(u7) {
            /// DECLAREBLOCKS: [n]
            DECLAREBLOCKS = 1,

            /// BINOP:      [opcode, ty, opval, opval]
            INST_BINOP = 2,
            /// CAST:       [opcode, ty, opty, opval]
            INST_CAST = 3,
            /// GEP:        [n x operands]
            INST_GEP_OLD = 4,
            /// SELECT:     [ty, opval, opval, opval]
            INST_SELECT = 5,
            /// EXTRACTELT: [opty, opval, opval]
            INST_EXTRACTELT = 6,
            /// INSERTELT:  [ty, opval, opval, opval]
            INST_INSERTELT = 7,
            /// SHUFFLEVEC: [ty, opval, opval, opval]
            INST_SHUFFLEVEC = 8,
            /// CMP:        [opty, opval, opval, pred]
            INST_CMP = 9,

            /// RET:        [opty,opval<both optional>]
            INST_RET = 10,
            /// BR:         [bb#, bb#, cond] or [bb#]
            INST_BR = 11,
            /// SWITCH:     [opty, op0, op1, ...]
            INST_SWITCH = 12,
            /// INVOKE:     [attr, fnty, op0,op1, ...]
            INST_INVOKE = 13,
            /// UNREACHABLE
            INST_UNREACHABLE = 15,

            /// PHI:        [ty, val0,bb0, ...]
            INST_PHI = 16,
            /// ALLOCA:     [instty, opty, op, align]
            INST_ALLOCA = 19,
            /// LOAD:       [opty, op, align, vol]
            INST_LOAD = 20,
            /// VAARG:      [valistty, valist, instty]
            /// This store code encodes the pointer type, rather than the value type
            /// this is so information only available in the pointer type (e.g. address
            /// spaces) is retained.
            INST_VAARG = 23,
            /// STORE:      [ptrty,ptr,val, align, vol]
            INST_STORE_OLD = 24,

            /// EXTRACTVAL: [n x operands]
            INST_EXTRACTVAL = 26,
            /// INSERTVAL:  [n x operands]
            INST_INSERTVAL = 27,
            /// fcmp/icmp returning Int1TY or vector of Int1Ty. Same as CMP, exists to
            /// support legacy vicmp/vfcmp instructions.
            /// CMP2:       [opty, opval, opval, pred]
            INST_CMP2 = 28,
            /// new select on i1 or [N x i1]
            /// VSELECT:    [ty,opval,opval,predty,pred]
            INST_VSELECT = 29,
            /// INBOUNDS_GEP: [n x operands]
            INST_INBOUNDS_GEP_OLD = 30,
            /// INDIRECTBR: [opty, op0, op1, ...]
            INST_INDIRECTBR = 31,

            /// DEBUG_LOC_AGAIN
            DEBUG_LOC_AGAIN = 33,

            /// CALL:    [attr, cc, fnty, fnid, args...]
            INST_CALL = 34,

            /// DEBUG_LOC:  [Line,Col,ScopeVal, IAVal]
            DEBUG_LOC = 35,
            /// FENCE: [ordering, synchscope]
            INST_FENCE = 36,
            /// CMPXCHG: [ptrty, ptr, cmp, val, vol,
            ///            ordering, synchscope,
            ///            failure_ordering?, weak?]
            INST_CMPXCHG_OLD = 37,
            /// ATOMICRMW: [ptrty,ptr,val, operation,
            ///             align, vol,
            ///             ordering, synchscope]
            INST_ATOMICRMW_OLD = 38,
            /// RESUME:     [opval]
            INST_RESUME = 39,
            /// LANDINGPAD: [ty,val,val,num,id0,val0...]
            INST_LANDINGPAD_OLD = 40,
            /// LOAD: [opty, op, align, vol,
            ///        ordering, synchscope]
            INST_LOADATOMIC = 41,
            /// STORE: [ptrty,ptr,val, align, vol
            ///         ordering, synchscope]
            INST_STOREATOMIC_OLD = 42,

            /// GEP:  [inbounds, n x operands]
            INST_GEP = 43,
            /// STORE: [ptrty,ptr,valty,val, align, vol]
            INST_STORE = 44,
            /// STORE: [ptrty,ptr,val, align, vol
            INST_STOREATOMIC = 45,
            /// CMPXCHG: [ptrty, ptr, cmp, val, vol,
            ///           success_ordering, synchscope,
            ///           failure_ordering, weak]
            INST_CMPXCHG = 46,
            /// LANDINGPAD: [ty,val,num,id0,val0...]
            INST_LANDINGPAD = 47,
            /// CLEANUPRET: [val] or [val,bb#]
            INST_CLEANUPRET = 48,
            /// CATCHRET: [val,bb#]
            INST_CATCHRET = 49,
            /// CATCHPAD: [bb#,bb#,num,args...]
            INST_CATCHPAD = 50,
            /// CLEANUPPAD: [num,args...]
            INST_CLEANUPPAD = 51,
            /// CATCHSWITCH: [num,args...] or [num,args...,bb]
            INST_CATCHSWITCH = 52,
            /// OPERAND_BUNDLE: [tag#, value...]
            OPERAND_BUNDLE = 55,
            /// UNOP:       [opcode, ty, opval]
            INST_UNOP = 56,
            /// CALLBR:     [attr, cc, norm, transfs,
            ///              fnty, fnid, args...]
            INST_CALLBR = 57,
            /// FREEZE: [opty, opval]
            INST_FREEZE = 58,
            /// ATOMICRMW: [ptrty, ptr, valty, val,
            ///             operation, align, vol,
            ///             ordering, synchscope]
            INST_ATOMICRMW = 59,
            /// BLOCKADDR_USERS: [value...]
            BLOCKADDR_USERS = 60,

            /// [DILocation, DILocalVariable, DIExpression, ValueAsMetadata]
            DEBUG_RECORD_VALUE = 61,
            /// [DILocation, DILocalVariable, DIExpression, ValueAsMetadata]
            DEBUG_RECORD_DECLARE = 62,
            /// [DILocation, DILocalVariable, DIExpression, ValueAsMetadata,
            ///  DIAssignID, DIExpression (addr), ValueAsMetadata (addr)]
            DEBUG_RECORD_ASSIGN = 63,
            /// [DILocation, DILocalVariable, DIExpression, Value]
            DEBUG_RECORD_VALUE_SIMPLE = 64,
            /// [DILocation, DILabel]
            DEBUG_RECORD_LABEL = 65,
        };

        pub const DeclareBlocks = struct {
            pub const ops = [_]AbbrevOp{
                .{ .literal = @intFromEnum(ModuleBlock.FunctionBlock.Code.DECLAREBLOCKS) },
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
                .{ .literal = @intFromEnum(ModuleBlock.FunctionBlock.Code.INST_CALL) },
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
                .{ .literal = @intFromEnum(ModuleBlock.FunctionBlock.Code.INST_CALL) },
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
                .{ .literal = @intFromEnum(ModuleBlock.FunctionBlock.Code.INST_UNOP) },
                ValueAbbrev,
                .{ .literal = 0 },
            };

            val: u32,
        };

        pub const FNegFast = struct {
            pub const ops = [_]AbbrevOp{
                .{ .literal = @intFromEnum(ModuleBlock.FunctionBlock.Code.INST_UNOP) },
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
                .{ .literal = @intFromEnum(ModuleBlock.FunctionBlock.Code.INST_BINOP) },
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
                .{ .literal = @intFromEnum(ModuleBlock.FunctionBlock.Code.INST_BINOP) },
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
                .{ .literal = @intFromEnum(ModuleBlock.FunctionBlock.Code.INST_BINOP) },
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
                .{ .literal = @intFromEnum(ModuleBlock.FunctionBlock.Code.INST_BINOP) },
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
                .{ .literal = @intFromEnum(ModuleBlock.FunctionBlock.Code.INST_CMP2) },
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
                .{ .literal = @intFromEnum(ModuleBlock.FunctionBlock.Code.INST_CMP2) },
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
                .{ .literal = @intFromEnum(ModuleBlock.FunctionBlock.Code.INST_VSELECT) },
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
                .{ .literal = @intFromEnum(ModuleBlock.FunctionBlock.Code.INST_VSELECT) },
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
                .{ .literal = @intFromEnum(ModuleBlock.FunctionBlock.Code.INST_CAST) },
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
                .{ .literal = @intFromEnum(ModuleBlock.FunctionBlock.Code.INST_ALLOCA) },
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
                .{ .literal = @intFromEnum(ModuleBlock.FunctionBlock.Code.INST_RET) },
            };
        };

        pub const Ret = struct {
            pub const ops = [_]AbbrevOp{
                .{ .literal = @intFromEnum(ModuleBlock.FunctionBlock.Code.INST_RET) },
                ValueAbbrev,
            };
            val: u32,
        };

        pub const GetElementPtr = struct {
            pub const ops = [_]AbbrevOp{
                .{ .literal = @intFromEnum(ModuleBlock.FunctionBlock.Code.INST_GEP) },
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
                .{ .literal = @intFromEnum(ModuleBlock.FunctionBlock.Code.INST_EXTRACTVAL) },
                ValueAbbrev,
                ValueArrayAbbrev,
            };

            val: u32,
            indices: []const u32,
        };

        pub const InsertValue = struct {
            pub const ops = [_]AbbrevOp{
                .{ .literal = @intFromEnum(ModuleBlock.FunctionBlock.Code.INST_INSERTVAL) },
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
                .{ .literal = @intFromEnum(ModuleBlock.FunctionBlock.Code.INST_EXTRACTELT) },
                ValueAbbrev,
                ValueAbbrev,
            };

            val: u32,
            index: u32,
        };

        pub const InsertElement = struct {
            pub const ops = [_]AbbrevOp{
                .{ .literal = @intFromEnum(ModuleBlock.FunctionBlock.Code.INST_INSERTELT) },
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
                .{ .literal = @intFromEnum(ModuleBlock.FunctionBlock.Code.INST_SHUFFLEVEC) },
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
                .{ .literal = @intFromEnum(ModuleBlock.FunctionBlock.Code.INST_UNREACHABLE) },
            };
        };

        pub const Load = struct {
            pub const ops = [_]AbbrevOp{
                .{ .literal = @intFromEnum(ModuleBlock.FunctionBlock.Code.INST_LOAD) },
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
                .{ .literal = @intFromEnum(ModuleBlock.FunctionBlock.Code.INST_LOADATOMIC) },
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
                .{ .literal = @intFromEnum(ModuleBlock.FunctionBlock.Code.INST_STORE) },
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
                .{ .literal = @intFromEnum(ModuleBlock.FunctionBlock.Code.INST_STOREATOMIC) },
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
                .{ .literal = @intFromEnum(ModuleBlock.FunctionBlock.Code.INST_BR) },
                BlockAbbrev,
            };
            block: u32,
        };

        pub const BrConditional = struct {
            pub const ops = [_]AbbrevOp{
                .{ .literal = @intFromEnum(ModuleBlock.FunctionBlock.Code.INST_BR) },
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
                .{ .literal = @intFromEnum(ModuleBlock.FunctionBlock.Code.INST_VAARG) },
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
                .{ .literal = @intFromEnum(ModuleBlock.FunctionBlock.Code.INST_ATOMICRMW) },
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
                .{ .literal = @intFromEnum(ModuleBlock.FunctionBlock.Code.INST_CMPXCHG) },
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
                .{ .literal = @intFromEnum(ModuleBlock.FunctionBlock.Code.INST_FENCE) },
                .{ .fixed = @bitSizeOf(Builder.AtomicOrdering) },
                .{ .fixed = @bitSizeOf(Builder.SyncScope) },
            };
            ordering: Builder.AtomicOrdering,
            sync_scope: Builder.SyncScope,
        };

        pub const DebugLoc = struct {
            pub const ops = [_]AbbrevOp{
                .{ .literal = @intFromEnum(ModuleBlock.FunctionBlock.Code.DEBUG_LOC) },
                LineAbbrev,
                ColumnAbbrev,
                MetadataAbbrev,
                MetadataAbbrev,
                .{ .literal = 0 },
            };
            line: u32,
            column: u32,
            scope: Builder.Metadata.Optional,
            inlined_at: Builder.Metadata.Optional,
        };

        pub const DebugLocAgain = struct {
            pub const ops = [_]AbbrevOp{
                .{ .literal = @intFromEnum(ModuleBlock.FunctionBlock.Code.DEBUG_LOC_AGAIN) },
            };
        };

        pub const ColdOperandBundle = struct {
            pub const ops = [_]AbbrevOp{
                .{ .literal = @intFromEnum(ModuleBlock.FunctionBlock.Code.OPERAND_BUNDLE) },
                .{ .literal = 0 },
            };
        };

        pub const IndirectBr = struct {
            pub const ops = [_]AbbrevOp{
                .{ .literal = @intFromEnum(ModuleBlock.FunctionBlock.Code.INST_INDIRECTBR) },
                .{ .fixed_runtime = Builder.Type },
                ValueAbbrev,
                BlockArrayAbbrev,
            };
            ty: Builder.Type,
            addr: Builder.Value,
            targets: []const Builder.Function.Block.Index,
        };

        pub const ValueSymtabBlock = struct {
            pub const id: BlockId = .VALUE_SYMTAB;

            pub const abbrevs = [_]type{
                ModuleBlock.FunctionBlock.ValueSymtabBlock.BlockEntry,
            };

            /// Value symbol table codes.
            pub const Code = enum(u3) {
                /// VST_ENTRY: [valueid, namechar x N]
                ENTRY = 1,
                /// VST_BBENTRY: [bbid, namechar x N]
                BBENTRY = 2,
                /// VST_FNENTRY: [valueid, offset, namechar x N]
                FNENTRY = 3,
                /// VST_COMBINED_ENTRY: [valueid, refguid]
                COMBINED_ENTRY = 5,
            };

            pub const BlockEntry = struct {
                pub const ops = [_]AbbrevOp{
                    .{ .literal = @intFromEnum(ModuleBlock.FunctionBlock.ValueSymtabBlock.Code.BBENTRY) },
                    ValueAbbrev,
                    .{ .array_fixed = 8 },
                };
                value_id: u32,
                string: []const u8,
            };
        };

        pub const MetadataBlock = struct {
            pub const id: BlockId = .METADATA;

            pub const abbrevs = [_]type{
                ModuleBlock.FunctionBlock.MetadataBlock.Value,
            };

            pub const Value = struct {
                pub const ops = [_]AbbrevOp{
                    .{ .literal = @intFromEnum(ModuleBlock.MetadataBlock.Code.VALUE) },
                    .{ .fixed = 32 }, // variable
                    .{ .fixed = 32 }, // expression
                };

                ty: Builder.Type,
                value: Builder.Value,
            };
        };

        pub const MetadataAttachmentBlock = struct {
            pub const id: BlockId = .METADATA_ATTACHMENT;

            pub const abbrevs = [_]type{
                ModuleBlock.FunctionBlock.MetadataAttachmentBlock.AttachmentGlobalSingle,
                ModuleBlock.FunctionBlock.MetadataAttachmentBlock.AttachmentInstructionSingle,
            };

            pub const AttachmentGlobalSingle = struct {
                pub const ops = [_]AbbrevOp{
                    .{ .literal = @intFromEnum(ModuleBlock.MetadataBlock.Code.ATTACHMENT) },
                    .{ .fixed = 1 },
                    MetadataAbbrev,
                };
                kind: FixedMetadataKind,
                metadata: Builder.Metadata,
            };

            pub const AttachmentInstructionSingle = struct {
                pub const ops = [_]AbbrevOp{
                    .{ .literal = @intFromEnum(ModuleBlock.MetadataBlock.Code.ATTACHMENT) },
                    ValueAbbrev,
                    .{ .fixed = 5 },
                    MetadataAbbrev,
                };
                inst: u32,
                kind: FixedMetadataKind,
                metadata: Builder.Metadata,
            };
        };
    };

    pub const MetadataBlock = struct {
        pub const id: BlockId = .METADATA;

        pub const abbrevs = [_]type{
            ModuleBlock.MetadataBlock.Strings,
            ModuleBlock.MetadataBlock.File,
            ModuleBlock.MetadataBlock.CompileUnit,
            ModuleBlock.MetadataBlock.Subprogram,
            ModuleBlock.MetadataBlock.LexicalBlock,
            ModuleBlock.MetadataBlock.Location,
            ModuleBlock.MetadataBlock.BasicType,
            ModuleBlock.MetadataBlock.CompositeType,
            ModuleBlock.MetadataBlock.DerivedType,
            ModuleBlock.MetadataBlock.SubroutineType,
            ModuleBlock.MetadataBlock.Enumerator,
            ModuleBlock.MetadataBlock.Subrange,
            ModuleBlock.MetadataBlock.Expression,
            ModuleBlock.MetadataBlock.Node,
            ModuleBlock.MetadataBlock.LocalVar,
            ModuleBlock.MetadataBlock.Parameter,
            ModuleBlock.MetadataBlock.GlobalVar,
            ModuleBlock.MetadataBlock.GlobalVarExpression,
            ModuleBlock.MetadataBlock.Constant,
            ModuleBlock.MetadataBlock.Name,
            ModuleBlock.MetadataBlock.NamedNode,
            ModuleBlock.MetadataBlock.GlobalDeclAttachment,
        };

        pub const Code = enum(u6) {
            /// MDSTRING:      [values]
            STRING_OLD = 1,
            /// VALUE:         [type num, value num]
            VALUE = 2,
            /// NODE:          [n x md num]
            NODE = 3,
            /// STRING:        [values]
            NAME = 4,
            /// DISTINCT_NODE: [n x md num]
            DISTINCT_NODE = 5,
            /// [n x [id, name]]
            KIND = 6,
            /// [distinct, line, col, scope, inlined-at?]
            LOCATION = 7,
            /// OLD_NODE:      [n x (type num, value num)]
            OLD_NODE = 8,
            /// OLD_FN_NODE:   [n x (type num, value num)]
            OLD_FN_NODE = 9,
            /// NAMED_NODE:    [n x mdnodes]
            NAMED_NODE = 10,
            /// [m x [value, [n x [id, mdnode]]]
            ATTACHMENT = 11,
            /// [distinct, tag, vers, header, n x md num]
            GENERIC_DEBUG = 12,
            /// [distinct, count, lo]
            SUBRANGE = 13,
            /// [isUnsigned|distinct, value, name]
            ENUMERATOR = 14,
            /// [distinct, tag, name, size, align, enc]
            BASIC_TYPE = 15,
            /// [distinct, filename, directory, checksumkind, checksum]
            FILE = 16,
            /// [distinct, ...]
            DERIVED_TYPE = 17,
            /// [distinct, ...]
            COMPOSITE_TYPE = 18,
            /// [distinct, flags, types, cc]
            SUBROUTINE_TYPE = 19,
            /// [distinct, ...]
            COMPILE_UNIT = 20,
            /// [distinct, ...]
            SUBPROGRAM = 21,
            /// [distinct, scope, file, line, column]
            LEXICAL_BLOCK = 22,
            ///[distinct, scope, file, discriminator]
            LEXICAL_BLOCK_FILE = 23,
            /// [distinct, scope, file, name, line, exportSymbols]
            NAMESPACE = 24,
            /// [distinct, scope, name, type, ...]
            TEMPLATE_TYPE = 25,
            /// [distinct, scope, name, type, value, ...]
            TEMPLATE_VALUE = 26,
            /// [distinct, ...]
            GLOBAL_VAR = 27,
            /// [distinct, ...]
            LOCAL_VAR = 28,
            /// [distinct, n x element]
            EXPRESSION = 29,
            /// [distinct, name, file, line, ...]
            OBJC_PROPERTY = 30,
            /// [distinct, tag, scope, entity, line, name]
            IMPORTED_ENTITY = 31,
            /// [distinct, scope, name, ...]
            MODULE = 32,
            /// [distinct, macinfo, line, name, value]
            MACRO = 33,
            /// [distinct, macinfo, line, file, ...]
            MACRO_FILE = 34,
            /// [count, offset] blob([lengths][chars])
            STRINGS = 35,
            /// [valueid, n x [id, mdnode]]
            GLOBAL_DECL_ATTACHMENT = 36,
            /// [distinct, var, expr]
            GLOBAL_VAR_EXPR = 37,
            /// [offset]
            INDEX_OFFSET = 38,
            /// [bitpos]
            INDEX = 39,
            /// [distinct, scope, name, file, line]
            LABEL = 40,
            /// [distinct, name, size, align,...]
            STRING_TYPE = 41,
            /// [distinct, scope, name, variable,...]
            COMMON_BLOCK = 44,
            /// [distinct, count, lo, up, stride]
            GENERIC_SUBRANGE = 45,
            /// [n x [type num, value num]]
            ARG_LIST = 46,
            /// [distinct, ...]
            ASSIGN_ID = 47,
        };

        pub const Strings = struct {
            pub const ops = [_]AbbrevOp{
                .{ .literal = @intFromEnum(ModuleBlock.MetadataBlock.Code.STRINGS) },
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
                .{ .literal = @intFromEnum(ModuleBlock.MetadataBlock.Code.FILE) },
                .{ .literal = 0 }, // is distinct
                MetadataAbbrev, // filename
                MetadataAbbrev, // directory
                .{ .literal = 0 }, // checksum
                .{ .literal = 0 }, // checksum
            };

            filename: Builder.Metadata.String.Optional,
            directory: Builder.Metadata.String.Optional,
        };

        pub const CompileUnit = struct {
            pub const ops = [_]AbbrevOp{
                .{ .literal = @intFromEnum(ModuleBlock.MetadataBlock.Code.COMPILE_UNIT) },
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

            file: Builder.Metadata.Optional,
            producer: Builder.Metadata.String.Optional,
            is_optimized: bool,
            enums: Builder.Metadata.Optional,
            globals: Builder.Metadata.Optional,
        };

        pub const Subprogram = struct {
            pub const ops = [_]AbbrevOp{
                .{ .literal = @intFromEnum(ModuleBlock.MetadataBlock.Code.SUBPROGRAM) },
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

            scope: Builder.Metadata.Optional,
            name: Builder.Metadata.String.Optional,
            linkage_name: Builder.Metadata.String.Optional,
            file: Builder.Metadata.Optional,
            line: u32,
            ty: Builder.Metadata.Optional,
            scope_line: u32,
            sp_flags: Builder.Metadata.Subprogram.DISPFlags,
            flags: Builder.Metadata.DIFlags,
            compile_unit: Builder.Metadata.Optional,
        };

        pub const LexicalBlock = struct {
            pub const ops = [_]AbbrevOp{
                .{ .literal = @intFromEnum(ModuleBlock.MetadataBlock.Code.LEXICAL_BLOCK) },
                .{ .literal = 0 }, // is distinct
                MetadataAbbrev, // scope
                MetadataAbbrev, // file
                LineAbbrev, // line
                ColumnAbbrev, // column
            };

            scope: Builder.Metadata.Optional,
            file: Builder.Metadata.Optional,
            line: u32,
            column: u32,
        };

        pub const Location = struct {
            pub const ops = [_]AbbrevOp{
                .{ .literal = @intFromEnum(ModuleBlock.MetadataBlock.Code.LOCATION) },
                .{ .literal = 0 }, // is distinct
                LineAbbrev, // line
                ColumnAbbrev, // column
                MetadataAbbrev, // scope
                MetadataAbbrev, // inlined at
                .{ .literal = 0 }, // is implicit code
            };

            line: u32,
            column: u32,
            scope: Builder.Metadata,
            inlined_at: Builder.Metadata.Optional,
        };

        pub const BasicType = struct {
            pub const ops = [_]AbbrevOp{
                .{ .literal = @intFromEnum(ModuleBlock.MetadataBlock.Code.BASIC_TYPE) },
                .{ .literal = 0 }, // is distinct
                .{ .literal = std.dwarf.TAG.base_type }, // tag
                MetadataAbbrev, // name
                .{ .vbr = 6 }, // size in bits
                .{ .literal = 0 }, // align in bits
                .{ .vbr = 8 }, // encoding
                .{ .literal = 0 }, // flags
            };

            name: Builder.Metadata.String.Optional,
            size_in_bits: u64,
            encoding: u32,
        };

        pub const CompositeType = struct {
            pub const ops = [_]AbbrevOp{
                .{ .literal = @intFromEnum(ModuleBlock.MetadataBlock.Code.COMPOSITE_TYPE) },
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
            name: Builder.Metadata.String.Optional,
            file: Builder.Metadata.Optional,
            line: u32,
            scope: Builder.Metadata.Optional,
            underlying_type: Builder.Metadata.Optional,
            size_in_bits: u64,
            align_in_bits: u64,
            flags: Builder.Metadata.DIFlags,
            elements: Builder.Metadata.Optional,
        };

        pub const DerivedType = struct {
            pub const ops = [_]AbbrevOp{
                .{ .literal = @intFromEnum(ModuleBlock.MetadataBlock.Code.DERIVED_TYPE) },
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
            name: Builder.Metadata.String.Optional,
            file: Builder.Metadata.Optional,
            line: u32,
            scope: Builder.Metadata.Optional,
            underlying_type: Builder.Metadata.Optional,
            size_in_bits: u64,
            align_in_bits: u64,
            offset_in_bits: u64,
        };

        pub const SubroutineType = struct {
            pub const ops = [_]AbbrevOp{
                .{ .literal = @intFromEnum(ModuleBlock.MetadataBlock.Code.SUBROUTINE_TYPE) },
                .{ .literal = 0 | 0x2 }, // is distinct | has no old type refs
                .{ .literal = 0 }, // flags
                MetadataAbbrev, // types
                .{ .literal = 0 }, // cc
            };

            types: Builder.Metadata.Optional,
        };

        pub const Enumerator = struct {
            pub const Flags = packed struct(u3) {
                distinct: bool = false,
                unsigned: bool,
                bigint: bool = true,
            };

            pub const ops = [_]AbbrevOp{
                .{ .literal = @intFromEnum(ModuleBlock.MetadataBlock.Code.ENUMERATOR) },
                .{ .fixed = @bitSizeOf(Flags) }, // flags
                .{ .vbr = 6 }, // bit width
                MetadataAbbrev, // name
                .{ .vbr = 16 }, // integer value
            };

            flags: Flags,
            bit_width: u32,
            name: Builder.Metadata.String.Optional,
            value: u64,
        };

        pub const Subrange = struct {
            pub const ops = [_]AbbrevOp{
                .{ .literal = @intFromEnum(ModuleBlock.MetadataBlock.Code.SUBRANGE) },
                .{ .literal = 0 | (2 << 1) }, // is distinct | version
                MetadataAbbrev, // count
                MetadataAbbrev, // lower bound
                .{ .literal = 0 }, // upper bound
                .{ .literal = 0 }, // stride
            };

            count: Builder.Metadata.Optional,
            lower_bound: Builder.Metadata.Optional,
        };

        pub const Expression = struct {
            pub const ops = [_]AbbrevOp{
                .{ .literal = @intFromEnum(ModuleBlock.MetadataBlock.Code.EXPRESSION) },
                .{ .literal = 0 | (3 << 1) }, // is distinct | version
                MetadataArrayAbbrev, // elements
            };

            elements: []const u32,
        };

        pub const Node = struct {
            pub const ops = [_]AbbrevOp{
                .{ .literal = @intFromEnum(ModuleBlock.MetadataBlock.Code.NODE) },
                MetadataArrayAbbrev, // elements
            };

            elements: []const Builder.Metadata.Optional,
        };

        pub const LocalVar = struct {
            pub const ops = [_]AbbrevOp{
                .{ .literal = @intFromEnum(ModuleBlock.MetadataBlock.Code.LOCAL_VAR) },
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

            scope: Builder.Metadata.Optional,
            name: Builder.Metadata.String.Optional,
            file: Builder.Metadata.Optional,
            line: u32,
            ty: Builder.Metadata.Optional,
        };

        pub const Parameter = struct {
            pub const ops = [_]AbbrevOp{
                .{ .literal = @intFromEnum(ModuleBlock.MetadataBlock.Code.LOCAL_VAR) },
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

            scope: Builder.Metadata.Optional,
            name: Builder.Metadata.String.Optional,
            file: Builder.Metadata.Optional,
            line: u32,
            ty: Builder.Metadata.Optional,
            arg: u32,
        };

        pub const GlobalVar = struct {
            pub const ops = [_]AbbrevOp{
                .{ .literal = @intFromEnum(ModuleBlock.MetadataBlock.Code.GLOBAL_VAR) },
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

            scope: Builder.Metadata.Optional,
            name: Builder.Metadata.String.Optional,
            linkage_name: Builder.Metadata.String.Optional,
            file: Builder.Metadata.Optional,
            line: u32,
            ty: Builder.Metadata.Optional,
            local: bool,
        };

        pub const GlobalVarExpression = struct {
            pub const ops = [_]AbbrevOp{
                .{ .literal = @intFromEnum(ModuleBlock.MetadataBlock.Code.GLOBAL_VAR_EXPR) },
                .{ .literal = 0 }, // is distinct
                MetadataAbbrev, // variable
                MetadataAbbrev, // expression
            };

            variable: Builder.Metadata.Optional,
            expression: Builder.Metadata.Optional,
        };

        pub const Constant = struct {
            pub const ops = [_]AbbrevOp{
                .{ .literal = @intFromEnum(ModuleBlock.MetadataBlock.Code.VALUE) },
                MetadataAbbrev, // type
                MetadataAbbrev, // value
            };

            ty: Builder.Type,
            constant: Builder.Constant,
        };

        pub const Name = struct {
            pub const ops = [_]AbbrevOp{
                .{ .literal = @intFromEnum(ModuleBlock.MetadataBlock.Code.NAME) },
                .{ .array_fixed = 8 }, // name
            };

            name: []const u8,
        };

        pub const NamedNode = struct {
            pub const ops = [_]AbbrevOp{
                .{ .literal = @intFromEnum(ModuleBlock.MetadataBlock.Code.NAMED_NODE) },
                MetadataArrayAbbrev, // elements
            };

            elements: []const Builder.Metadata,
        };

        pub const GlobalDeclAttachment = struct {
            pub const ops = [_]AbbrevOp{
                .{ .literal = @intFromEnum(ModuleBlock.MetadataBlock.Code.GLOBAL_DECL_ATTACHMENT) },
                ValueAbbrev, // value id
                .{ .fixed = 1 }, // kind
                MetadataAbbrev, // elements
            };

            value: Builder.Constant,
            kind: FixedMetadataKind,
            metadata: Builder.Metadata,
        };
    };

    /// TYPE blocks have codes for each type primitive they use.
    pub const TypeBlock = struct {
        pub const id: BlockId = .TYPE;

        pub const abbrevs = [_]type{
            ModuleBlock.TypeBlock.NumEntry,
            ModuleBlock.TypeBlock.Simple,
            ModuleBlock.TypeBlock.Opaque,
            ModuleBlock.TypeBlock.Integer,
            ModuleBlock.TypeBlock.StructAnon,
            ModuleBlock.TypeBlock.StructNamed,
            ModuleBlock.TypeBlock.StructName,
            ModuleBlock.TypeBlock.Array,
            ModuleBlock.TypeBlock.Vector,
            ModuleBlock.TypeBlock.Pointer,
            ModuleBlock.TypeBlock.Target,
            ModuleBlock.TypeBlock.Function,
        };

        pub const Code = enum(u5) {
            /// NUMENTRY: [numentries]
            NUMENTRY = 1,

            // Type Codes
            /// VOID
            VOID = 2,
            /// FLOAT
            FLOAT = 3,
            /// DOUBLE
            DOUBLE = 4,
            /// LABEL
            LABEL = 5,
            /// OPAQUE
            OPAQUE = 6,
            /// INTEGER: [width]
            INTEGER = 7,
            /// POINTER: [pointee type]
            POINTER = 8,

            /// FUNCTION: [vararg, attrid, retty, paramty x N]
            FUNCTION_OLD = 9,

            /// HALF
            HALF = 10,

            /// ARRAY: [numelts, eltty]
            ARRAY = 11,
            /// VECTOR: [numelts, eltty]
            VECTOR = 12,

            // These are not with the other floating point types because they're
            // a late addition, and putting them in the right place breaks
            // binary compatibility.
            /// X86 LONG DOUBLE
            X86_FP80 = 13,
            /// LONG DOUBLE (112 bit mantissa)
            FP128 = 14,
            /// PPC LONG DOUBLE (2 doubles)
            PPC_FP128 = 15,

            /// METADATA
            METADATA = 16,

            /// X86 MMX
            X86_MMX = 17,

            /// STRUCT_ANON: [ispacked, eltty x N]
            STRUCT_ANON = 18,
            /// STRUCT_NAME: [strchr x N]
            STRUCT_NAME = 19,
            /// STRUCT_NAMED: [ispacked, eltty x N]
            STRUCT_NAMED = 20,

            /// FUNCTION: [vararg, retty, paramty x N]
            FUNCTION = 21,

            /// TOKEN
            TOKEN = 22,

            /// BRAIN FLOATING POINT
            BFLOAT = 23,
            /// X86 AMX
            X86_AMX = 24,

            /// OPAQUE_POINTER: [addrspace]
            OPAQUE_POINTER = 25,

            /// TARGET_TYPE
            TARGET_TYPE = 26,
        };

        pub const NumEntry = struct {
            pub const ops = [_]AbbrevOp{
                .{ .literal = @intFromEnum(ModuleBlock.TypeBlock.Code.NUMENTRY) },
                .{ .fixed = 32 },
            };
            num: u32,
        };

        pub const Simple = struct {
            pub const ops = [_]AbbrevOp{
                .{ .vbr = 4 },
            };
            code: ModuleBlock.TypeBlock.Code,
        };

        pub const Opaque = struct {
            pub const ops = [_]AbbrevOp{
                .{ .literal = @intFromEnum(ModuleBlock.TypeBlock.Code.OPAQUE) },
                .{ .literal = 0 },
            };
        };

        pub const Integer = struct {
            pub const ops = [_]AbbrevOp{
                .{ .literal = @intFromEnum(ModuleBlock.TypeBlock.Code.INTEGER) },
                .{ .fixed = 28 },
            };
            width: u28,
        };

        pub const StructAnon = struct {
            pub const ops = [_]AbbrevOp{
                .{ .literal = @intFromEnum(ModuleBlock.TypeBlock.Code.STRUCT_ANON) },
                .{ .fixed = 1 },
                .{ .array_fixed_runtime = Builder.Type },
            };
            is_packed: bool,
            types: []const Builder.Type,
        };

        pub const StructNamed = struct {
            pub const ops = [_]AbbrevOp{
                .{ .literal = @intFromEnum(ModuleBlock.TypeBlock.Code.STRUCT_NAMED) },
                .{ .fixed = 1 },
                .{ .array_fixed_runtime = Builder.Type },
            };
            is_packed: bool,
            types: []const Builder.Type,
        };

        pub const StructName = struct {
            pub const ops = [_]AbbrevOp{
                .{ .literal = @intFromEnum(ModuleBlock.TypeBlock.Code.STRUCT_NAME) },
                .{ .array_fixed = 8 },
            };
            string: []const u8,
        };

        pub const Array = struct {
            pub const ops = [_]AbbrevOp{
                .{ .literal = @intFromEnum(ModuleBlock.TypeBlock.Code.ARRAY) },
                .{ .vbr = 16 },
                .{ .fixed_runtime = Builder.Type },
            };
            len: u64,
            child: Builder.Type,
        };

        pub const Vector = struct {
            pub const ops = [_]AbbrevOp{
                .{ .literal = @intFromEnum(ModuleBlock.TypeBlock.Code.VECTOR) },
                .{ .vbr = 16 },
                .{ .fixed_runtime = Builder.Type },
            };
            len: u64,
            child: Builder.Type,
        };

        pub const Pointer = struct {
            pub const ops = [_]AbbrevOp{
                .{ .literal = @intFromEnum(ModuleBlock.TypeBlock.Code.OPAQUE_POINTER) },
                .{ .vbr = 4 },
            };
            addr_space: Builder.AddrSpace,
        };

        pub const Target = struct {
            pub const ops = [_]AbbrevOp{
                .{ .literal = @intFromEnum(ModuleBlock.TypeBlock.Code.TARGET_TYPE) },
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
                .{ .literal = @intFromEnum(ModuleBlock.TypeBlock.Code.FUNCTION) },
                .{ .fixed = 1 },
                .{ .fixed_runtime = Builder.Type },
                .{ .array_fixed_runtime = Builder.Type },
            };
            is_vararg: bool,
            return_type: Builder.Type,
            param_types: []const Builder.Type,
        };
    };

    pub const OperandBundleTagsBlock = struct {
        pub const id: BlockId = .OPERAND_BUNDLE_TAGS;

        pub const abbrevs = [_]type{
            ModuleBlock.OperandBundleTagsBlock.OperandBundleTag,
        };

        pub const Code = enum(u1) {
            /// TAG: [strchr x N]
            OPERAND_BUNDLE_TAG = 1,
        };

        pub const OperandBundleTag = struct {
            pub const ops = [_]AbbrevOp{
                .{ .literal = @intFromEnum(ModuleBlock.OperandBundleTagsBlock.Code.OPERAND_BUNDLE_TAG) },
                .array_char6,
            };
            tag: []const u8,
        };
    };

    pub const MetadataKindBlock = struct {
        pub const id: BlockId = .METADATA_KIND;

        pub const abbrevs = [_]type{
            ModuleBlock.MetadataKindBlock.Kind,
        };

        pub const Kind = struct {
            pub const ops = [_]AbbrevOp{
                .{ .literal = @intFromEnum(ModuleBlock.MetadataBlock.Code.KIND) },
                .{ .vbr = 4 },
                .{ .array_fixed = 8 },
            };
            id: u32,
            name: []const u8,
        };
    };
};

/// Identification block contains a string that describes the producer details,
/// and an epoch that defines the auto-upgrade capability.
pub const IdentificationBlock = struct {
    pub const id: BlockId = .IDENTIFICATION;

    pub const abbrevs = [_]type{
        IdentificationBlock.Version,
        IdentificationBlock.Epoch,
    };

    pub const Code = enum(u2) {
        /// IDENTIFICATION:      [strchr x N]
        STRING = 1,
        /// EPOCH:               [epoch#]
        EPOCH = 2,
    };

    pub const Version = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = @intFromEnum(IdentificationBlock.Code.STRING) },
            .{ .array_fixed = 8 },
        };
        string: []const u8,
    };

    pub const Epoch = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = @intFromEnum(IdentificationBlock.Code.EPOCH) },
            .{ .vbr = 6 },
        };
        epoch: u32,
    };
};

pub const StrtabBlock = struct {
    pub const id: BlockId = .STRTAB;

    pub const abbrevs = [_]type{Blob};

    pub const Code = enum(u1) {
        BLOB = 1,
    };

    pub const Blob = struct {
        pub const ops = [_]AbbrevOp{
            .{ .literal = @intFromEnum(StrtabBlock.Code.BLOB) },
            .blob,
        };
        blob: []const u8,
    };
};
