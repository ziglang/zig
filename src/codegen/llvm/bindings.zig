//! We do this instead of @cImport because the self-hosted compiler is easier
//! to bootstrap if it does not depend on translate-c.

/// Do not compare directly to .True, use toBool() instead.
pub const Bool = enum(c_int) {
    False,
    True,
    _,

    pub fn fromBool(b: bool) Bool {
        return @intToEnum(Bool, @boolToInt(b));
    }

    pub fn toBool(b: Bool) bool {
        return b != .False;
    }
};
pub const AttributeIndex = c_uint;

/// Make sure to use the *InContext functions instead of the global ones.
pub const Context = opaque {
    pub const create = LLVMContextCreate;
    extern fn LLVMContextCreate() *const Context;

    pub const dispose = LLVMContextDispose;
    extern fn LLVMContextDispose(C: *const Context) void;

    pub const createEnumAttribute = LLVMCreateEnumAttribute;
    extern fn LLVMCreateEnumAttribute(*const Context, KindID: c_uint, Val: u64) *const Attribute;

    pub const intType = LLVMIntTypeInContext;
    extern fn LLVMIntTypeInContext(C: *const Context, NumBits: c_uint) *const Type;

    pub const halfType = LLVMHalfTypeInContext;
    extern fn LLVMHalfTypeInContext(C: *const Context) *const Type;

    pub const floatType = LLVMFloatTypeInContext;
    extern fn LLVMFloatTypeInContext(C: *const Context) *const Type;

    pub const doubleType = LLVMDoubleTypeInContext;
    extern fn LLVMDoubleTypeInContext(C: *const Context) *const Type;

    pub const x86FP80Type = LLVMX86FP80TypeInContext;
    extern fn LLVMX86FP80TypeInContext(C: *const Context) *const Type;

    pub const fp128Type = LLVMFP128TypeInContext;
    extern fn LLVMFP128TypeInContext(C: *const Context) *const Type;

    pub const voidType = LLVMVoidTypeInContext;
    extern fn LLVMVoidTypeInContext(C: *const Context) *const Type;

    pub const structType = LLVMStructTypeInContext;
    extern fn LLVMStructTypeInContext(
        C: *const Context,
        ElementTypes: [*]const *const Type,
        ElementCount: c_uint,
        Packed: Bool,
    ) *const Type;

    const structCreateNamed = LLVMStructCreateNamed;
    extern fn LLVMStructCreateNamed(C: *const Context, Name: [*:0]const u8) *const Type;

    pub const constString = LLVMConstStringInContext;
    extern fn LLVMConstStringInContext(C: *const Context, Str: [*]const u8, Length: c_uint, DontNullTerminate: Bool) *const Value;

    pub const constStruct = LLVMConstStructInContext;
    extern fn LLVMConstStructInContext(
        C: *const Context,
        ConstantVals: [*]const *const Value,
        Count: c_uint,
        Packed: Bool,
    ) *const Value;

    pub const createBasicBlock = LLVMCreateBasicBlockInContext;
    extern fn LLVMCreateBasicBlockInContext(C: *const Context, Name: [*:0]const u8) *const BasicBlock;

    pub const appendBasicBlock = LLVMAppendBasicBlockInContext;
    extern fn LLVMAppendBasicBlockInContext(C: *const Context, Fn: *const Value, Name: [*:0]const u8) *const BasicBlock;

    pub const createBuilder = LLVMCreateBuilderInContext;
    extern fn LLVMCreateBuilderInContext(C: *const Context) *const Builder;
};

pub const Value = opaque {
    pub const addAttributeAtIndex = LLVMAddAttributeAtIndex;
    extern fn LLVMAddAttributeAtIndex(*const Value, Idx: AttributeIndex, A: *const Attribute) void;

    pub const getFirstBasicBlock = LLVMGetFirstBasicBlock;
    extern fn LLVMGetFirstBasicBlock(Fn: *const Value) ?*const BasicBlock;

    pub const appendExistingBasicBlock = LLVMAppendExistingBasicBlock;
    extern fn LLVMAppendExistingBasicBlock(Fn: *const Value, BB: *const BasicBlock) void;

    pub const addIncoming = LLVMAddIncoming;
    extern fn LLVMAddIncoming(PhiNode: *const Value, IncomingValues: [*]*const Value, IncomingBlocks: [*]*const BasicBlock, Count: c_uint) void;

    pub const getNextInstruction = LLVMGetNextInstruction;
    extern fn LLVMGetNextInstruction(Inst: *const Value) ?*const Value;

    pub const typeOf = LLVMTypeOf;
    extern fn LLVMTypeOf(Val: *const Value) *const Type;

    pub const setGlobalConstant = LLVMSetGlobalConstant;
    extern fn LLVMSetGlobalConstant(GlobalVar: *const Value, IsConstant: Bool) void;

    pub const setLinkage = LLVMSetLinkage;
    extern fn LLVMSetLinkage(Global: *const Value, Linkage: Linkage) void;

    pub const setUnnamedAddr = LLVMSetUnnamedAddr;
    extern fn LLVMSetUnnamedAddr(Global: *const Value, HasUnnamedAddr: Bool) void;

    pub const deleteGlobal = LLVMDeleteGlobal;
    extern fn LLVMDeleteGlobal(GlobalVar: *const Value) void;

    pub const getNextGlobalAlias = LLVMGetNextGlobalAlias;
    extern fn LLVMGetNextGlobalAlias(GA: *const Value) *const Value;

    pub const getAliasee = LLVMAliasGetAliasee;
    extern fn LLVMAliasGetAliasee(Alias: *const Value) *const Value;

    pub const setAliasee = LLVMAliasSetAliasee;
    extern fn LLVMAliasSetAliasee(Alias: *const Value, Aliasee: *const Value) void;

    pub const constInBoundsGEP = LLVMConstInBoundsGEP;
    extern fn LLVMConstInBoundsGEP(
        ConstantVal: *const Value,
        ConstantIndices: [*]const *const Value,
        NumIndices: c_uint,
    ) *const Value;

    pub const constBitCast = LLVMConstBitCast;
    extern fn LLVMConstBitCast(ConstantVal: *const Value, ToType: *const Type) *const Value;

    pub const constIntToPtr = LLVMConstIntToPtr;
    extern fn LLVMConstIntToPtr(ConstantVal: *const Value, ToType: *const Type) *const Value;
};

pub const Type = opaque {
    pub const constNull = LLVMConstNull;
    extern fn LLVMConstNull(Ty: *const Type) *const Value;

    pub const constAllOnes = LLVMConstAllOnes;
    extern fn LLVMConstAllOnes(Ty: *const Type) *const Value;

    pub const constInt = LLVMConstInt;
    extern fn LLVMConstInt(IntTy: *const Type, N: c_ulonglong, SignExtend: Bool) *const Value;

    pub const constReal = LLVMConstReal;
    extern fn LLVMConstReal(RealTy: *const Type, N: f64) *const Value;

    pub const constArray = LLVMConstArray;
    extern fn LLVMConstArray(ElementTy: *const Type, ConstantVals: [*]*const Value, Length: c_uint) *const Value;

    pub const getUndef = LLVMGetUndef;
    extern fn LLVMGetUndef(Ty: *const Type) *const Value;

    pub const pointerType = LLVMPointerType;
    extern fn LLVMPointerType(ElementType: *const Type, AddressSpace: c_uint) *const Type;

    pub const arrayType = LLVMArrayType;
    extern fn LLVMArrayType(ElementType: *const Type, ElementCount: c_uint) *const Type;

    pub const structSetBody = LLVMStructSetBody;
    extern fn LLVMStructSetBody(
        StructTy: *const Type,
        ElementTypes: [*]*const Type,
        ElementCount: c_uint,
        Packed: Bool,
    ) void;
};

pub const Module = opaque {
    pub const createWithName = LLVMModuleCreateWithNameInContext;
    extern fn LLVMModuleCreateWithNameInContext(ModuleID: [*:0]const u8, C: *const Context) *const Module;

    pub const dispose = LLVMDisposeModule;
    extern fn LLVMDisposeModule(*const Module) void;

    pub const verify = LLVMVerifyModule;
    extern fn LLVMVerifyModule(*const Module, Action: VerifierFailureAction, OutMessage: *[*:0]const u8) Bool;

    pub const addFunction = LLVMAddFunction;
    extern fn LLVMAddFunction(*const Module, Name: [*:0]const u8, FunctionTy: *const Type) *const Value;

    pub const getNamedFunction = LLVMGetNamedFunction;
    extern fn LLVMGetNamedFunction(*const Module, Name: [*:0]const u8) ?*const Value;

    pub const getIntrinsicDeclaration = LLVMGetIntrinsicDeclaration;
    extern fn LLVMGetIntrinsicDeclaration(Mod: *const Module, ID: c_uint, ParamTypes: ?[*]*const Type, ParamCount: usize) *const Value;

    pub const printToString = LLVMPrintModuleToString;
    extern fn LLVMPrintModuleToString(*const Module) [*:0]const u8;

    pub const addGlobal = LLVMAddGlobal;
    extern fn LLVMAddGlobal(M: *const Module, Ty: *const Type, Name: [*:0]const u8) *const Value;

    pub const getNamedGlobal = LLVMGetNamedGlobal;
    extern fn LLVMGetNamedGlobal(M: *const Module, Name: [*:0]const u8) ?*const Value;

    pub const dump = LLVMDumpModule;
    extern fn LLVMDumpModule(M: *const Module) void;

    pub const getFirstGlobalAlias = LLVMGetFirstGlobalAlias;
    extern fn LLVMGetFirstGlobalAlias(M: *const Module) *const Value;

    pub const getLastGlobalAlias = LLVMGetLastGlobalAlias;
    extern fn LLVMGetLastGlobalAlias(M: *const Module) *const Value;

    pub const addAlias = LLVMAddAlias;
    extern fn LLVMAddAlias(
        M: *const Module,
        Ty: *const Type,
        Aliasee: *const Value,
        Name: [*:0]const u8,
    ) *const Value;

    pub const getNamedGlobalAlias = LLVMGetNamedGlobalAlias;
    extern fn LLVMGetNamedGlobalAlias(
        M: *const Module,
        /// Empirically, LLVM will call strlen() on `Name` and so it
        /// must be both null terminated and also have `NameLen` set
        /// to the size.
        Name: [*:0]const u8,
        NameLen: usize,
    ) ?*const Value;
};

pub const lookupIntrinsicID = LLVMLookupIntrinsicID;
extern fn LLVMLookupIntrinsicID(Name: [*]const u8, NameLen: usize) c_uint;

pub const disposeMessage = LLVMDisposeMessage;
extern fn LLVMDisposeMessage(Message: [*:0]const u8) void;

pub const VerifierFailureAction = enum(c_int) {
    AbortProcess,
    PrintMessage,
    ReturnStatus,
};

pub const constNeg = LLVMConstNeg;
extern fn LLVMConstNeg(ConstantVal: *const Value) *const Value;

pub const setInitializer = LLVMSetInitializer;
extern fn LLVMSetInitializer(GlobalVar: *const Value, ConstantVal: *const Value) void;

pub const getParam = LLVMGetParam;
extern fn LLVMGetParam(Fn: *const Value, Index: c_uint) *const Value;

pub const getEnumAttributeKindForName = LLVMGetEnumAttributeKindForName;
extern fn LLVMGetEnumAttributeKindForName(Name: [*]const u8, SLen: usize) c_uint;

pub const getInlineAsm = LLVMGetInlineAsm;
extern fn LLVMGetInlineAsm(
    Ty: *const Type,
    AsmString: [*]const u8,
    AsmStringSize: usize,
    Constraints: [*]const u8,
    ConstraintsSize: usize,
    HasSideEffects: Bool,
    IsAlignStack: Bool,
    Dialect: InlineAsmDialect,
) *const Value;

pub const functionType = LLVMFunctionType;
extern fn LLVMFunctionType(
    ReturnType: *const Type,
    ParamTypes: [*]*const Type,
    ParamCount: c_uint,
    IsVarArg: Bool,
) *const Type;

pub const InlineAsmDialect = enum(c_uint) { ATT, Intel };

pub const Attribute = opaque {};

pub const Builder = opaque {
    pub const dispose = LLVMDisposeBuilder;
    extern fn LLVMDisposeBuilder(Builder: *const Builder) void;

    pub const positionBuilder = LLVMPositionBuilder;
    extern fn LLVMPositionBuilder(
        Builder: *const Builder,
        Block: *const BasicBlock,
        Instr: *const Value,
    ) void;

    pub const positionBuilderAtEnd = LLVMPositionBuilderAtEnd;
    extern fn LLVMPositionBuilderAtEnd(Builder: *const Builder, Block: *const BasicBlock) void;

    pub const getInsertBlock = LLVMGetInsertBlock;
    extern fn LLVMGetInsertBlock(Builder: *const Builder) *const BasicBlock;

    pub const buildZExt = LLVMBuildZExt;
    extern fn LLVMBuildZExt(
        *const Builder,
        Value: *const Value,
        DestTy: *const Type,
        Name: [*:0]const u8,
    ) *const Value;

    pub const buildCall = LLVMBuildCall;
    extern fn LLVMBuildCall(
        *const Builder,
        Fn: *const Value,
        Args: [*]*const Value,
        NumArgs: c_uint,
        Name: [*:0]const u8,
    ) *const Value;

    pub const buildCall2 = LLVMBuildCall2;
    extern fn LLVMBuildCall2(
        *const Builder,
        *const Type,
        Fn: *const Value,
        Args: [*]*const Value,
        NumArgs: c_uint,
        Name: [*:0]const u8,
    ) *const Value;

    pub const buildRetVoid = LLVMBuildRetVoid;
    extern fn LLVMBuildRetVoid(*const Builder) *const Value;

    pub const buildRet = LLVMBuildRet;
    extern fn LLVMBuildRet(*const Builder, V: *const Value) *const Value;

    pub const buildUnreachable = LLVMBuildUnreachable;
    extern fn LLVMBuildUnreachable(*const Builder) *const Value;

    pub const buildAlloca = LLVMBuildAlloca;
    extern fn LLVMBuildAlloca(*const Builder, Ty: *const Type, Name: [*:0]const u8) *const Value;

    pub const buildStore = LLVMBuildStore;
    extern fn LLVMBuildStore(*const Builder, Val: *const Value, Ptr: *const Value) *const Value;

    pub const buildLoad = LLVMBuildLoad;
    extern fn LLVMBuildLoad(*const Builder, PointerVal: *const Value, Name: [*:0]const u8) *const Value;

    pub const buildNeg = LLVMBuildNeg;
    extern fn LLVMBuildNeg(*const Builder, V: *const Value, Name: [*:0]const u8) *const Value;

    pub const buildNot = LLVMBuildNot;
    extern fn LLVMBuildNot(*const Builder, V: *const Value, Name: [*:0]const u8) *const Value;

    pub const buildFAdd = LLVMBuildFAdd;
    extern fn LLVMBuildFAdd(*const Builder, LHS: *const Value, RHS: *const Value, Name: [*:0]const u8) *const Value;

    pub const buildAdd = LLVMBuildAdd;
    extern fn LLVMBuildAdd(*const Builder, LHS: *const Value, RHS: *const Value, Name: [*:0]const u8) *const Value;

    pub const buildNSWAdd = LLVMBuildNSWAdd;
    extern fn LLVMBuildNSWAdd(*const Builder, LHS: *const Value, RHS: *const Value, Name: [*:0]const u8) *const Value;

    pub const buildNUWAdd = LLVMBuildNUWAdd;
    extern fn LLVMBuildNUWAdd(*const Builder, LHS: *const Value, RHS: *const Value, Name: [*:0]const u8) *const Value;

    pub const buildFSub = LLVMBuildFSub;
    extern fn LLVMBuildFSub(*const Builder, LHS: *const Value, RHS: *const Value, Name: [*:0]const u8) *const Value;

    pub const buildSub = LLVMBuildSub;
    extern fn LLVMBuildSub(*const Builder, LHS: *const Value, RHS: *const Value, Name: [*:0]const u8) *const Value;

    pub const buildNSWSub = LLVMBuildNSWSub;
    extern fn LLVMBuildNSWSub(*const Builder, LHS: *const Value, RHS: *const Value, Name: [*:0]const u8) *const Value;

    pub const buildNUWSub = LLVMBuildNUWSub;
    extern fn LLVMBuildNUWSub(*const Builder, LHS: *const Value, RHS: *const Value, Name: [*:0]const u8) *const Value;

    pub const buildFMul = LLVMBuildFMul;
    extern fn LLVMBuildFMul(*const Builder, LHS: *const Value, RHS: *const Value, Name: [*:0]const u8) *const Value;

    pub const buildMul = LLVMBuildMul;
    extern fn LLVMBuildMul(*const Builder, LHS: *const Value, RHS: *const Value, Name: [*:0]const u8) *const Value;

    pub const buildNSWMul = LLVMBuildNSWMul;
    extern fn LLVMBuildNSWMul(*const Builder, LHS: *const Value, RHS: *const Value, Name: [*:0]const u8) *const Value;

    pub const buildNUWMul = LLVMBuildNUWMul;
    extern fn LLVMBuildNUWMul(*const Builder, LHS: *const Value, RHS: *const Value, Name: [*:0]const u8) *const Value;

    pub const buildUDiv = LLVMBuildUDiv;
    extern fn LLVMBuildUDiv(*const Builder, LHS: *const Value, RHS: *const Value, Name: [*:0]const u8) *const Value;

    pub const buildSDiv = LLVMBuildSDiv;
    extern fn LLVMBuildSDiv(*const Builder, LHS: *const Value, RHS: *const Value, Name: [*:0]const u8) *const Value;

    pub const buildFDiv = LLVMBuildFDiv;
    extern fn LLVMBuildFDiv(*const Builder, LHS: *const Value, RHS: *const Value, Name: [*:0]const u8) *const Value;

    pub const buildURem = LLVMBuildURem;
    extern fn LLVMBuildURem(*const Builder, LHS: *const Value, RHS: *const Value, Name: [*:0]const u8) *const Value;

    pub const buildSRem = LLVMBuildSRem;
    extern fn LLVMBuildSRem(*const Builder, LHS: *const Value, RHS: *const Value, Name: [*:0]const u8) *const Value;

    pub const buildFRem = LLVMBuildFRem;
    extern fn LLVMBuildFRem(*const Builder, LHS: *const Value, RHS: *const Value, Name: [*:0]const u8) *const Value;

    pub const buildAnd = LLVMBuildAnd;
    extern fn LLVMBuildAnd(*const Builder, LHS: *const Value, RHS: *const Value, Name: [*:0]const u8) *const Value;

    pub const buildLShr = LLVMBuildLShr;
    extern fn LLVMBuildLShr(*const Builder, LHS: *const Value, RHS: *const Value, Name: [*:0]const u8) *const Value;

    pub const buildAShr = LLVMBuildAShr;
    extern fn LLVMBuildAShr(*const Builder, LHS: *const Value, RHS: *const Value, Name: [*:0]const u8) *const Value;

    pub const buildShl = LLVMBuildShl;
    extern fn LLVMBuildShl(*const Builder, LHS: *const Value, RHS: *const Value, Name: [*:0]const u8) *const Value;

    pub const buildOr = LLVMBuildOr;
    extern fn LLVMBuildOr(*const Builder, LHS: *const Value, RHS: *const Value, Name: [*:0]const u8) *const Value;

    pub const buildXor = LLVMBuildXor;
    extern fn LLVMBuildXor(*const Builder, LHS: *const Value, RHS: *const Value, Name: [*:0]const u8) *const Value;

    pub const buildIntCast2 = LLVMBuildIntCast2;
    extern fn LLVMBuildIntCast2(*const Builder, Val: *const Value, DestTy: *const Type, IsSigned: Bool, Name: [*:0]const u8) *const Value;

    pub const buildBitCast = LLVMBuildBitCast;
    extern fn LLVMBuildBitCast(*const Builder, Val: *const Value, DestTy: *const Type, Name: [*:0]const u8) *const Value;

    pub const buildInBoundsGEP = LLVMBuildInBoundsGEP;
    extern fn LLVMBuildInBoundsGEP(
        B: *const Builder,
        Pointer: *const Value,
        Indices: [*]const *const Value,
        NumIndices: c_uint,
        Name: [*:0]const u8,
    ) *const Value;

    pub const buildInBoundsGEP2 = LLVMBuildInBoundsGEP2;
    extern fn LLVMBuildInBoundsGEP2(
        B: *const Builder,
        Ty: *const Type,
        Pointer: *const Value,
        Indices: [*]const *const Value,
        NumIndices: c_uint,
        Name: [*:0]const u8,
    ) *const Value;

    pub const buildICmp = LLVMBuildICmp;
    extern fn LLVMBuildICmp(*const Builder, Op: IntPredicate, LHS: *const Value, RHS: *const Value, Name: [*:0]const u8) *const Value;

    pub const buildFCmp = LLVMBuildFCmp;
    extern fn LLVMBuildFCmp(*const Builder, Op: RealPredicate, LHS: *const Value, RHS: *const Value, Name: [*:0]const u8) *const Value;

    pub const buildBr = LLVMBuildBr;
    extern fn LLVMBuildBr(*const Builder, Dest: *const BasicBlock) *const Value;

    pub const buildCondBr = LLVMBuildCondBr;
    extern fn LLVMBuildCondBr(*const Builder, If: *const Value, Then: *const BasicBlock, Else: *const BasicBlock) *const Value;

    pub const buildPhi = LLVMBuildPhi;
    extern fn LLVMBuildPhi(*const Builder, Ty: *const Type, Name: [*:0]const u8) *const Value;

    pub const buildExtractValue = LLVMBuildExtractValue;
    extern fn LLVMBuildExtractValue(
        *const Builder,
        AggVal: *const Value,
        Index: c_uint,
        Name: [*:0]const u8,
    ) *const Value;

    pub const buildPtrToInt = LLVMBuildPtrToInt;
    extern fn LLVMBuildPtrToInt(
        *const Builder,
        Val: *const Value,
        DestTy: *const Type,
        Name: [*:0]const u8,
    ) *const Value;

    pub const buildStructGEP = LLVMBuildStructGEP;
    extern fn LLVMBuildStructGEP(
        B: *const Builder,
        Pointer: *const Value,
        Idx: c_uint,
        Name: [*:0]const u8,
    ) *const Value;

    pub const buildTrunc = LLVMBuildTrunc;
    extern fn LLVMBuildTrunc(
        *const Builder,
        Val: *const Value,
        DestTy: *const Type,
        Name: [*:0]const u8,
    ) *const Value;
};

pub const IntPredicate = enum(c_uint) {
    EQ = 32,
    NE = 33,
    UGT = 34,
    UGE = 35,
    ULT = 36,
    ULE = 37,
    SGT = 38,
    SGE = 39,
    SLT = 40,
    SLE = 41,
};

pub const RealPredicate = enum(c_uint) {
    OEQ = 1,
    OGT = 2,
    OGE = 3,
    OLT = 4,
    OLE = 5,
    ONE = 6,
    ORD = 7,
    UNO = 8,
    UEQ = 9,
    UGT = 10,
    UGE = 11,
    ULT = 12,
    ULE = 13,
    UNE = 14,
};

pub const BasicBlock = opaque {
    pub const deleteBasicBlock = LLVMDeleteBasicBlock;
    extern fn LLVMDeleteBasicBlock(BB: *const BasicBlock) void;

    pub const getFirstInstruction = LLVMGetFirstInstruction;
    extern fn LLVMGetFirstInstruction(BB: *const BasicBlock) ?*const Value;
};

pub const TargetMachine = opaque {
    pub const create = ZigLLVMCreateTargetMachine;
    extern fn ZigLLVMCreateTargetMachine(
        T: *const Target,
        Triple: [*:0]const u8,
        CPU: ?[*:0]const u8,
        Features: ?[*:0]const u8,
        Level: CodeGenOptLevel,
        Reloc: RelocMode,
        CodeModel: CodeModel,
        function_sections: bool,
        float_abi: ABIType,
        abi_name: ?[*:0]const u8,
    ) *const TargetMachine;

    pub const dispose = LLVMDisposeTargetMachine;
    extern fn LLVMDisposeTargetMachine(T: *const TargetMachine) void;

    pub const emitToFile = ZigLLVMTargetMachineEmitToFile;
    extern fn ZigLLVMTargetMachineEmitToFile(
        T: *const TargetMachine,
        M: *const Module,
        ErrorMessage: *[*:0]const u8,
        is_debug: bool,
        is_small: bool,
        time_report: bool,
        tsan: bool,
        lto: bool,
        asm_filename: ?[*:0]const u8,
        bin_filename: ?[*:0]const u8,
        llvm_ir_filename: ?[*:0]const u8,
        bitcode_filename: ?[*:0]const u8,
    ) bool;
};

pub const CodeModel = enum(c_int) {
    Default,
    JITDefault,
    Tiny,
    Small,
    Kernel,
    Medium,
    Large,
};

pub const CodeGenOptLevel = enum(c_int) {
    None,
    Less,
    Default,
    Aggressive,
};

pub const RelocMode = enum(c_int) {
    Default,
    Static,
    PIC,
    DynamicNoPIC,
    ROPI,
    RWPI,
    ROPI_RWPI,
};

pub const CodeGenFileType = enum(c_int) {
    AssemblyFile,
    ObjectFile,
};

pub const ABIType = enum(c_int) {
    /// Target-specific (either soft or hard depending on triple, etc).
    Default,
    /// Soft float.
    Soft,
    // Hard float.
    Hard,
};

pub const Target = opaque {
    pub const getFromTriple = LLVMGetTargetFromTriple;
    extern fn LLVMGetTargetFromTriple(Triple: [*:0]const u8, T: **const Target, ErrorMessage: *[*:0]const u8) Bool;
};

pub extern fn LLVMInitializeAArch64TargetInfo() void;
pub extern fn LLVMInitializeAMDGPUTargetInfo() void;
pub extern fn LLVMInitializeARMTargetInfo() void;
pub extern fn LLVMInitializeAVRTargetInfo() void;
pub extern fn LLVMInitializeBPFTargetInfo() void;
pub extern fn LLVMInitializeHexagonTargetInfo() void;
pub extern fn LLVMInitializeLanaiTargetInfo() void;
pub extern fn LLVMInitializeMipsTargetInfo() void;
pub extern fn LLVMInitializeMSP430TargetInfo() void;
pub extern fn LLVMInitializeNVPTXTargetInfo() void;
pub extern fn LLVMInitializePowerPCTargetInfo() void;
pub extern fn LLVMInitializeRISCVTargetInfo() void;
pub extern fn LLVMInitializeSparcTargetInfo() void;
pub extern fn LLVMInitializeSystemZTargetInfo() void;
pub extern fn LLVMInitializeWebAssemblyTargetInfo() void;
pub extern fn LLVMInitializeX86TargetInfo() void;
pub extern fn LLVMInitializeXCoreTargetInfo() void;

pub extern fn LLVMInitializeAArch64Target() void;
pub extern fn LLVMInitializeAMDGPUTarget() void;
pub extern fn LLVMInitializeARMTarget() void;
pub extern fn LLVMInitializeAVRTarget() void;
pub extern fn LLVMInitializeBPFTarget() void;
pub extern fn LLVMInitializeHexagonTarget() void;
pub extern fn LLVMInitializeLanaiTarget() void;
pub extern fn LLVMInitializeMipsTarget() void;
pub extern fn LLVMInitializeMSP430Target() void;
pub extern fn LLVMInitializeNVPTXTarget() void;
pub extern fn LLVMInitializePowerPCTarget() void;
pub extern fn LLVMInitializeRISCVTarget() void;
pub extern fn LLVMInitializeSparcTarget() void;
pub extern fn LLVMInitializeSystemZTarget() void;
pub extern fn LLVMInitializeWebAssemblyTarget() void;
pub extern fn LLVMInitializeX86Target() void;
pub extern fn LLVMInitializeXCoreTarget() void;

pub extern fn LLVMInitializeAArch64TargetMC() void;
pub extern fn LLVMInitializeAMDGPUTargetMC() void;
pub extern fn LLVMInitializeARMTargetMC() void;
pub extern fn LLVMInitializeAVRTargetMC() void;
pub extern fn LLVMInitializeBPFTargetMC() void;
pub extern fn LLVMInitializeHexagonTargetMC() void;
pub extern fn LLVMInitializeLanaiTargetMC() void;
pub extern fn LLVMInitializeMipsTargetMC() void;
pub extern fn LLVMInitializeMSP430TargetMC() void;
pub extern fn LLVMInitializeNVPTXTargetMC() void;
pub extern fn LLVMInitializePowerPCTargetMC() void;
pub extern fn LLVMInitializeRISCVTargetMC() void;
pub extern fn LLVMInitializeSparcTargetMC() void;
pub extern fn LLVMInitializeSystemZTargetMC() void;
pub extern fn LLVMInitializeWebAssemblyTargetMC() void;
pub extern fn LLVMInitializeX86TargetMC() void;
pub extern fn LLVMInitializeXCoreTargetMC() void;

pub extern fn LLVMInitializeAArch64AsmPrinter() void;
pub extern fn LLVMInitializeAMDGPUAsmPrinter() void;
pub extern fn LLVMInitializeARMAsmPrinter() void;
pub extern fn LLVMInitializeAVRAsmPrinter() void;
pub extern fn LLVMInitializeBPFAsmPrinter() void;
pub extern fn LLVMInitializeHexagonAsmPrinter() void;
pub extern fn LLVMInitializeLanaiAsmPrinter() void;
pub extern fn LLVMInitializeMipsAsmPrinter() void;
pub extern fn LLVMInitializeMSP430AsmPrinter() void;
pub extern fn LLVMInitializeNVPTXAsmPrinter() void;
pub extern fn LLVMInitializePowerPCAsmPrinter() void;
pub extern fn LLVMInitializeRISCVAsmPrinter() void;
pub extern fn LLVMInitializeSparcAsmPrinter() void;
pub extern fn LLVMInitializeSystemZAsmPrinter() void;
pub extern fn LLVMInitializeWebAssemblyAsmPrinter() void;
pub extern fn LLVMInitializeX86AsmPrinter() void;
pub extern fn LLVMInitializeXCoreAsmPrinter() void;

pub extern fn LLVMInitializeAArch64AsmParser() void;
pub extern fn LLVMInitializeAMDGPUAsmParser() void;
pub extern fn LLVMInitializeARMAsmParser() void;
pub extern fn LLVMInitializeAVRAsmParser() void;
pub extern fn LLVMInitializeBPFAsmParser() void;
pub extern fn LLVMInitializeHexagonAsmParser() void;
pub extern fn LLVMInitializeLanaiAsmParser() void;
pub extern fn LLVMInitializeMipsAsmParser() void;
pub extern fn LLVMInitializeMSP430AsmParser() void;
pub extern fn LLVMInitializePowerPCAsmParser() void;
pub extern fn LLVMInitializeRISCVAsmParser() void;
pub extern fn LLVMInitializeSparcAsmParser() void;
pub extern fn LLVMInitializeSystemZAsmParser() void;
pub extern fn LLVMInitializeWebAssemblyAsmParser() void;
pub extern fn LLVMInitializeX86AsmParser() void;

extern fn ZigLLDLinkCOFF(argc: c_int, argv: [*:null]const ?[*:0]const u8, can_exit_early: bool) c_int;
extern fn ZigLLDLinkELF(argc: c_int, argv: [*:null]const ?[*:0]const u8, can_exit_early: bool) c_int;
extern fn ZigLLDLinkWasm(argc: c_int, argv: [*:null]const ?[*:0]const u8, can_exit_early: bool) c_int;

pub const LinkCOFF = ZigLLDLinkCOFF;
pub const LinkELF = ZigLLDLinkELF;
pub const LinkWasm = ZigLLDLinkWasm;

pub const ObjectFormatType = enum(c_int) {
    Unknown,
    COFF,
    ELF,
    GOFF,
    MachO,
    Wasm,
    XCOFF,
};

pub const WriteArchive = ZigLLVMWriteArchive;
extern fn ZigLLVMWriteArchive(
    archive_name: [*:0]const u8,
    file_names_ptr: [*]const [*:0]const u8,
    file_names_len: usize,
    os_type: OSType,
) bool;

pub const OSType = enum(c_int) {
    UnknownOS,
    Ananas,
    CloudABI,
    Darwin,
    DragonFly,
    FreeBSD,
    Fuchsia,
    IOS,
    KFreeBSD,
    Linux,
    Lv2,
    MacOSX,
    NetBSD,
    OpenBSD,
    Solaris,
    Win32,
    ZOS,
    Haiku,
    Minix,
    RTEMS,
    NaCl,
    AIX,
    CUDA,
    NVCL,
    AMDHSA,
    PS4,
    ELFIAMCU,
    TvOS,
    WatchOS,
    Mesa3D,
    Contiki,
    AMDPAL,
    HermitCore,
    Hurd,
    WASI,
    Emscripten,
};

pub const ArchType = enum(c_int) {
    UnknownArch,
    arm,
    armeb,
    aarch64,
    aarch64_be,
    aarch64_32,
    arc,
    avr,
    bpfel,
    bpfeb,
    csky,
    hexagon,
    mips,
    mipsel,
    mips64,
    mips64el,
    msp430,
    ppc,
    ppcle,
    ppc64,
    ppc64le,
    r600,
    amdgcn,
    riscv32,
    riscv64,
    sparc,
    sparcv9,
    sparcel,
    systemz,
    tce,
    tcele,
    thumb,
    thumbeb,
    x86,
    x86_64,
    xcore,
    nvptx,
    nvptx64,
    le32,
    le64,
    amdil,
    amdil64,
    hsail,
    hsail64,
    spir,
    spir64,
    kalimba,
    shave,
    lanai,
    wasm32,
    wasm64,
    renderscript32,
    renderscript64,
    ve,
};

pub const ParseCommandLineOptions = ZigLLVMParseCommandLineOptions;
extern fn ZigLLVMParseCommandLineOptions(argc: usize, argv: [*]const [*:0]const u8) void;

pub const WriteImportLibrary = ZigLLVMWriteImportLibrary;
extern fn ZigLLVMWriteImportLibrary(
    def_path: [*:0]const u8,
    arch: ArchType,
    output_lib_path: [*c]const u8,
    kill_at: bool,
) bool;

pub const Linkage = enum(c_uint) {
    External,
    AvailableExternally,
    LinkOnceAny,
    LinkOnceODR,
    LinkOnceODRAutoHide,
    WeakAny,
    WeakODR,
    Appending,
    Internal,
    Private,
    DLLImport,
    DLLExport,
    ExternalWeak,
    Ghost,
    Common,
    LinkerPrivate,
    LinkerPrivateWeak,
};
