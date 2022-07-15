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

    pub const createStringAttribute = LLVMCreateStringAttribute;
    extern fn LLVMCreateStringAttribute(*const Context, Key: [*]const u8, Key_Len: c_uint, Value: [*]const u8, Value_Len: c_uint) *const Attribute;

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

    pub const structCreateNamed = LLVMStructCreateNamed;
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

    pub const removeEnumAttributeAtIndex = LLVMRemoveEnumAttributeAtIndex;
    extern fn LLVMRemoveEnumAttributeAtIndex(F: *const Value, Idx: AttributeIndex, KindID: c_uint) void;

    pub const getFirstBasicBlock = LLVMGetFirstBasicBlock;
    extern fn LLVMGetFirstBasicBlock(Fn: *const Value) ?*const BasicBlock;

    pub const appendExistingBasicBlock = LLVMAppendExistingBasicBlock;
    extern fn LLVMAppendExistingBasicBlock(Fn: *const Value, BB: *const BasicBlock) void;

    pub const addIncoming = LLVMAddIncoming;
    extern fn LLVMAddIncoming(
        PhiNode: *const Value,
        IncomingValues: [*]const *const Value,
        IncomingBlocks: [*]const *const BasicBlock,
        Count: c_uint,
    ) void;

    pub const getNextInstruction = LLVMGetNextInstruction;
    extern fn LLVMGetNextInstruction(Inst: *const Value) ?*const Value;

    pub const typeOf = LLVMTypeOf;
    extern fn LLVMTypeOf(Val: *const Value) *const Type;

    pub const setGlobalConstant = LLVMSetGlobalConstant;
    extern fn LLVMSetGlobalConstant(GlobalVar: *const Value, IsConstant: Bool) void;

    pub const setLinkage = LLVMSetLinkage;
    extern fn LLVMSetLinkage(Global: *const Value, Linkage: Linkage) void;

    pub const setVisibility = LLVMSetVisibility;
    extern fn LLVMSetVisibility(Global: *const Value, Linkage: Visibility) void;

    pub const setUnnamedAddr = LLVMSetUnnamedAddr;
    extern fn LLVMSetUnnamedAddr(Global: *const Value, HasUnnamedAddr: Bool) void;

    pub const setThreadLocalMode = LLVMSetThreadLocalMode;
    extern fn LLVMSetThreadLocalMode(Global: *const Value, Mode: ThreadLocalMode) void;

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

    pub const constPtrToInt = LLVMConstPtrToInt;
    extern fn LLVMConstPtrToInt(ConstantVal: *const Value, ToType: *const Type) *const Value;

    pub const constShl = LLVMConstShl;
    extern fn LLVMConstShl(LHSConstant: *const Value, RHSConstant: *const Value) *const Value;

    pub const constOr = LLVMConstOr;
    extern fn LLVMConstOr(LHSConstant: *const Value, RHSConstant: *const Value) *const Value;

    pub const constZExt = LLVMConstZExt;
    extern fn LLVMConstZExt(ConstantVal: *const Value, ToType: *const Type) *const Value;

    pub const constZExtOrBitCast = LLVMConstZExtOrBitCast;
    extern fn LLVMConstZExtOrBitCast(ConstantVal: *const Value, ToType: *const Type) *const Value;

    pub const constNot = LLVMConstNot;
    extern fn LLVMConstNot(ConstantVal: *const Value) *const Value;

    pub const setWeak = LLVMSetWeak;
    extern fn LLVMSetWeak(CmpXchgInst: *const Value, IsWeak: Bool) void;

    pub const setOrdering = LLVMSetOrdering;
    extern fn LLVMSetOrdering(MemoryAccessInst: *const Value, Ordering: AtomicOrdering) void;

    pub const setVolatile = LLVMSetVolatile;
    extern fn LLVMSetVolatile(MemoryAccessInst: *const Value, IsVolatile: Bool) void;

    pub const setAlignment = LLVMSetAlignment;
    extern fn LLVMSetAlignment(V: *const Value, Bytes: c_uint) void;

    pub const getFunctionCallConv = LLVMGetFunctionCallConv;
    extern fn LLVMGetFunctionCallConv(Fn: *const Value) CallConv;

    pub const setFunctionCallConv = LLVMSetFunctionCallConv;
    extern fn LLVMSetFunctionCallConv(Fn: *const Value, CC: CallConv) void;

    pub const fnSetSubprogram = ZigLLVMFnSetSubprogram;
    extern fn ZigLLVMFnSetSubprogram(f: *const Value, subprogram: *DISubprogram) void;

    pub const setValueName = LLVMSetValueName;
    extern fn LLVMSetValueName(Val: *const Value, Name: [*:0]const u8) void;

    pub const setValueName2 = LLVMSetValueName2;
    extern fn LLVMSetValueName2(Val: *const Value, Name: [*]const u8, NameLen: usize) void;

    pub const getValueName = LLVMGetValueName;
    extern fn LLVMGetValueName(Val: *const Value) [*:0]const u8;

    pub const takeName = ZigLLVMTakeName;
    extern fn ZigLLVMTakeName(new_owner: *const Value, victim: *const Value) void;

    pub const deleteFunction = LLVMDeleteFunction;
    extern fn LLVMDeleteFunction(Fn: *const Value) void;

    pub const addSretAttr = ZigLLVMAddSretAttr;
    extern fn ZigLLVMAddSretAttr(fn_ref: *const Value, type_val: *const Type) void;

    pub const setCallSret = ZigLLVMSetCallSret;
    extern fn ZigLLVMSetCallSret(Call: *const Value, return_type: *const Type) void;

    pub const getParam = LLVMGetParam;
    extern fn LLVMGetParam(Fn: *const Value, Index: c_uint) *const Value;

    pub const setInitializer = LLVMSetInitializer;
    extern fn LLVMSetInitializer(GlobalVar: *const Value, ConstantVal: *const Value) void;

    pub const addCase = LLVMAddCase;
    extern fn LLVMAddCase(Switch: *const Value, OnVal: *const Value, Dest: *const BasicBlock) void;

    pub inline fn isPoison(Val: *const Value) bool {
        return LLVMIsPoison(Val).toBool();
    }
    extern fn LLVMIsPoison(Val: *const Value) Bool;

    pub const replaceAllUsesWith = LLVMReplaceAllUsesWith;
    extern fn LLVMReplaceAllUsesWith(OldVal: *const Value, NewVal: *const Value) void;

    pub const globalGetValueType = LLVMGlobalGetValueType;
    extern fn LLVMGlobalGetValueType(Global: *const Value) *const Type;

    pub const getLinkage = LLVMGetLinkage;
    extern fn LLVMGetLinkage(Global: *const Value) Linkage;

    pub const getUnnamedAddress = LLVMGetUnnamedAddress;
    extern fn LLVMGetUnnamedAddress(Global: *const Value) Bool;

    pub const getAlignment = LLVMGetAlignment;
    extern fn LLVMGetAlignment(V: *const Value) c_uint;

    pub const addFunctionAttr = ZigLLVMAddFunctionAttr;
    extern fn ZigLLVMAddFunctionAttr(Fn: *const Value, attr_name: [*:0]const u8, attr_value: [*:0]const u8) void;
};

pub const Type = opaque {
    pub const constNull = LLVMConstNull;
    extern fn LLVMConstNull(Ty: *const Type) *const Value;

    pub const constAllOnes = LLVMConstAllOnes;
    extern fn LLVMConstAllOnes(Ty: *const Type) *const Value;

    pub const constInt = LLVMConstInt;
    extern fn LLVMConstInt(IntTy: *const Type, N: c_ulonglong, SignExtend: Bool) *const Value;

    pub const constIntOfArbitraryPrecision = LLVMConstIntOfArbitraryPrecision;
    extern fn LLVMConstIntOfArbitraryPrecision(IntTy: *const Type, NumWords: c_uint, Words: [*]const u64) *const Value;

    pub const constReal = LLVMConstReal;
    extern fn LLVMConstReal(RealTy: *const Type, N: f64) *const Value;

    pub const constArray = LLVMConstArray;
    extern fn LLVMConstArray(ElementTy: *const Type, ConstantVals: [*]const *const Value, Length: c_uint) *const Value;

    pub const constNamedStruct = LLVMConstNamedStruct;
    extern fn LLVMConstNamedStruct(
        StructTy: *const Type,
        ConstantVals: [*]const *const Value,
        Count: c_uint,
    ) *const Value;

    pub const getUndef = LLVMGetUndef;
    extern fn LLVMGetUndef(Ty: *const Type) *const Value;

    pub const pointerType = LLVMPointerType;
    extern fn LLVMPointerType(ElementType: *const Type, AddressSpace: c_uint) *const Type;

    pub const arrayType = LLVMArrayType;
    extern fn LLVMArrayType(ElementType: *const Type, ElementCount: c_uint) *const Type;

    pub const vectorType = LLVMVectorType;
    extern fn LLVMVectorType(ElementType: *const Type, ElementCount: c_uint) *const Type;

    pub const structSetBody = LLVMStructSetBody;
    extern fn LLVMStructSetBody(
        StructTy: *const Type,
        ElementTypes: [*]*const Type,
        ElementCount: c_uint,
        Packed: Bool,
    ) void;

    pub const structGetTypeAtIndex = LLVMStructGetTypeAtIndex;
    extern fn LLVMStructGetTypeAtIndex(StructTy: *const Type, i: c_uint) *const Type;

    pub const getTypeKind = LLVMGetTypeKind;
    extern fn LLVMGetTypeKind(Ty: *const Type) TypeKind;

    pub const getElementType = LLVMGetElementType;
    extern fn LLVMGetElementType(Ty: *const Type) *const Type;

    pub const countStructElementTypes = LLVMCountStructElementTypes;
    extern fn LLVMCountStructElementTypes(StructTy: *const Type) c_uint;

    pub const isOpaqueStruct = LLVMIsOpaqueStruct;
    extern fn LLVMIsOpaqueStruct(StructTy: *const Type) Bool;

    pub const isSized = LLVMTypeIsSized;
    extern fn LLVMTypeIsSized(Ty: *const Type) Bool;
};

pub const Module = opaque {
    pub const createWithName = LLVMModuleCreateWithNameInContext;
    extern fn LLVMModuleCreateWithNameInContext(ModuleID: [*:0]const u8, C: *const Context) *const Module;

    pub const dispose = LLVMDisposeModule;
    extern fn LLVMDisposeModule(*const Module) void;

    pub const verify = LLVMVerifyModule;
    extern fn LLVMVerifyModule(*const Module, Action: VerifierFailureAction, OutMessage: *[*:0]const u8) Bool;

    pub const setModuleDataLayout = LLVMSetModuleDataLayout;
    extern fn LLVMSetModuleDataLayout(*const Module, *const TargetData) void;

    pub const setModulePICLevel = ZigLLVMSetModulePICLevel;
    extern fn ZigLLVMSetModulePICLevel(module: *const Module) void;

    pub const setModulePIELevel = ZigLLVMSetModulePIELevel;
    extern fn ZigLLVMSetModulePIELevel(module: *const Module) void;

    pub const setModuleCodeModel = ZigLLVMSetModuleCodeModel;
    extern fn ZigLLVMSetModuleCodeModel(module: *const Module, code_model: CodeModel) void;

    pub const addFunction = LLVMAddFunction;
    extern fn LLVMAddFunction(*const Module, Name: [*:0]const u8, FunctionTy: *const Type) *const Value;

    pub const addFunctionInAddressSpace = ZigLLVMAddFunctionInAddressSpace;
    extern fn ZigLLVMAddFunctionInAddressSpace(*const Module, Name: [*:0]const u8, FunctionTy: *const Type, AddressSpace: c_uint) *const Value;

    pub const getNamedFunction = LLVMGetNamedFunction;
    extern fn LLVMGetNamedFunction(*const Module, Name: [*:0]const u8) ?*const Value;

    pub const getIntrinsicDeclaration = LLVMGetIntrinsicDeclaration;
    extern fn LLVMGetIntrinsicDeclaration(Mod: *const Module, ID: c_uint, ParamTypes: ?[*]const *const Type, ParamCount: usize) *const Value;

    pub const printToString = LLVMPrintModuleToString;
    extern fn LLVMPrintModuleToString(*const Module) [*:0]const u8;

    pub const addGlobal = LLVMAddGlobal;
    extern fn LLVMAddGlobal(M: *const Module, Ty: *const Type, Name: [*:0]const u8) *const Value;

    pub const addGlobalInAddressSpace = LLVMAddGlobalInAddressSpace;
    extern fn LLVMAddGlobalInAddressSpace(M: *const Module, Ty: *const Type, Name: [*:0]const u8, AddressSpace: c_uint) *const Value;

    pub const getNamedGlobal = LLVMGetNamedGlobal;
    extern fn LLVMGetNamedGlobal(M: *const Module, Name: [*:0]const u8) ?*const Value;

    pub const dump = LLVMDumpModule;
    extern fn LLVMDumpModule(M: *const Module) void;

    pub const getFirstGlobalAlias = LLVMGetFirstGlobalAlias;
    extern fn LLVMGetFirstGlobalAlias(M: *const Module) *const Value;

    pub const getLastGlobalAlias = LLVMGetLastGlobalAlias;
    extern fn LLVMGetLastGlobalAlias(M: *const Module) *const Value;

    pub const addAlias = LLVMAddAlias2;
    extern fn LLVMAddAlias2(
        M: *const Module,
        Ty: *const Type,
        AddrSpace: c_uint,
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

    pub const setTarget = LLVMSetTarget;
    extern fn LLVMSetTarget(M: *const Module, Triple: [*:0]const u8) void;

    pub const addModuleDebugInfoFlag = ZigLLVMAddModuleDebugInfoFlag;
    extern fn ZigLLVMAddModuleDebugInfoFlag(module: *const Module) void;

    pub const addModuleCodeViewFlag = ZigLLVMAddModuleCodeViewFlag;
    extern fn ZigLLVMAddModuleCodeViewFlag(module: *const Module) void;

    pub const createDIBuilder = ZigLLVMCreateDIBuilder;
    extern fn ZigLLVMCreateDIBuilder(module: *const Module, allow_unresolved: bool) *DIBuilder;

    pub const setModuleInlineAsm2 = LLVMSetModuleInlineAsm2;
    extern fn LLVMSetModuleInlineAsm2(M: *const Module, Asm: [*]const u8, Len: usize) void;

    pub const printModuleToFile = LLVMPrintModuleToFile;
    extern fn LLVMPrintModuleToFile(M: *const Module, Filename: [*:0]const u8, ErrorMessage: *[*:0]const u8) Bool;
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

pub const constVector = LLVMConstVector;
extern fn LLVMConstVector(
    ScalarConstantVals: [*]*const Value,
    Size: c_uint,
) *const Value;

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
    CanThrow: Bool,
) *const Value;

pub const functionType = LLVMFunctionType;
extern fn LLVMFunctionType(
    ReturnType: *const Type,
    ParamTypes: [*]const *const Type,
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

    pub const buildZExtOrBitCast = LLVMBuildZExtOrBitCast;
    extern fn LLVMBuildZExtOrBitCast(
        *const Builder,
        Val: *const Value,
        DestTy: *const Type,
        Name: [*:0]const u8,
    ) *const Value;

    pub const buildSExt = LLVMBuildSExt;
    extern fn LLVMBuildSExt(
        *const Builder,
        Val: *const Value,
        DestTy: *const Type,
        Name: [*:0]const u8,
    ) *const Value;

    pub const buildSExtOrBitCast = LLVMBuildSExtOrBitCast;
    extern fn LLVMBuildSExtOrBitCast(
        *const Builder,
        Val: *const Value,
        DestTy: *const Type,
        Name: [*:0]const u8,
    ) *const Value;

    pub const buildCall = ZigLLVMBuildCall;
    extern fn ZigLLVMBuildCall(
        *const Builder,
        Fn: *const Value,
        Args: [*]const *const Value,
        NumArgs: c_uint,
        CC: CallConv,
        attr: CallAttr,
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

    pub const buildSAddSat = ZigLLVMBuildSAddSat;
    extern fn ZigLLVMBuildSAddSat(*const Builder, LHS: *const Value, RHS: *const Value, Name: [*:0]const u8) *const Value;

    pub const buildUAddSat = ZigLLVMBuildUAddSat;
    extern fn ZigLLVMBuildUAddSat(*const Builder, LHS: *const Value, RHS: *const Value, Name: [*:0]const u8) *const Value;

    pub const buildFSub = LLVMBuildFSub;
    extern fn LLVMBuildFSub(*const Builder, LHS: *const Value, RHS: *const Value, Name: [*:0]const u8) *const Value;

    pub const buildFNeg = LLVMBuildFNeg;
    extern fn LLVMBuildFNeg(*const Builder, V: *const Value, Name: [*:0]const u8) *const Value;

    pub const buildSub = LLVMBuildSub;
    extern fn LLVMBuildSub(*const Builder, LHS: *const Value, RHS: *const Value, Name: [*:0]const u8) *const Value;

    pub const buildNSWSub = LLVMBuildNSWSub;
    extern fn LLVMBuildNSWSub(*const Builder, LHS: *const Value, RHS: *const Value, Name: [*:0]const u8) *const Value;

    pub const buildNUWSub = LLVMBuildNUWSub;
    extern fn LLVMBuildNUWSub(*const Builder, LHS: *const Value, RHS: *const Value, Name: [*:0]const u8) *const Value;

    pub const buildSSubSat = ZigLLVMBuildSSubSat;
    extern fn ZigLLVMBuildSSubSat(*const Builder, LHS: *const Value, RHS: *const Value, Name: [*:0]const u8) *const Value;

    pub const buildUSubSat = ZigLLVMBuildUSubSat;
    extern fn ZigLLVMBuildUSubSat(*const Builder, LHS: *const Value, RHS: *const Value, Name: [*:0]const u8) *const Value;

    pub const buildFMul = LLVMBuildFMul;
    extern fn LLVMBuildFMul(*const Builder, LHS: *const Value, RHS: *const Value, Name: [*:0]const u8) *const Value;

    pub const buildMul = LLVMBuildMul;
    extern fn LLVMBuildMul(*const Builder, LHS: *const Value, RHS: *const Value, Name: [*:0]const u8) *const Value;

    pub const buildNSWMul = LLVMBuildNSWMul;
    extern fn LLVMBuildNSWMul(*const Builder, LHS: *const Value, RHS: *const Value, Name: [*:0]const u8) *const Value;

    pub const buildNUWMul = LLVMBuildNUWMul;
    extern fn LLVMBuildNUWMul(*const Builder, LHS: *const Value, RHS: *const Value, Name: [*:0]const u8) *const Value;

    pub const buildSMulFixSat = ZigLLVMBuildSMulFixSat;
    extern fn ZigLLVMBuildSMulFixSat(*const Builder, LHS: *const Value, RHS: *const Value, Name: [*:0]const u8) *const Value;

    pub const buildUMulFixSat = ZigLLVMBuildUMulFixSat;
    extern fn ZigLLVMBuildUMulFixSat(*const Builder, LHS: *const Value, RHS: *const Value, Name: [*:0]const u8) *const Value;

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

    pub const buildLShrExact = ZigLLVMBuildLShrExact;
    extern fn ZigLLVMBuildLShrExact(*const Builder, LHS: *const Value, RHS: *const Value, Name: [*:0]const u8) *const Value;

    pub const buildAShrExact = ZigLLVMBuildAShrExact;
    extern fn ZigLLVMBuildAShrExact(*const Builder, LHS: *const Value, RHS: *const Value, Name: [*:0]const u8) *const Value;

    pub const buildShl = LLVMBuildShl;
    extern fn LLVMBuildShl(*const Builder, LHS: *const Value, RHS: *const Value, Name: [*:0]const u8) *const Value;

    pub const buildNUWShl = ZigLLVMBuildNUWShl;
    extern fn ZigLLVMBuildNUWShl(*const Builder, LHS: *const Value, RHS: *const Value, Name: [*:0]const u8) *const Value;

    pub const buildNSWShl = ZigLLVMBuildNSWShl;
    extern fn ZigLLVMBuildNSWShl(*const Builder, LHS: *const Value, RHS: *const Value, Name: [*:0]const u8) *const Value;

    pub const buildSShlSat = ZigLLVMBuildSShlSat;
    extern fn ZigLLVMBuildSShlSat(*const Builder, LHS: *const Value, RHS: *const Value, Name: [*:0]const u8) *const Value;

    pub const buildUShlSat = ZigLLVMBuildUShlSat;
    extern fn ZigLLVMBuildUShlSat(*const Builder, LHS: *const Value, RHS: *const Value, Name: [*:0]const u8) *const Value;

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

    pub const buildSwitch = LLVMBuildSwitch;
    extern fn LLVMBuildSwitch(*const Builder, V: *const Value, Else: *const BasicBlock, NumCases: c_uint) *const Value;

    pub const buildPhi = LLVMBuildPhi;
    extern fn LLVMBuildPhi(*const Builder, Ty: *const Type, Name: [*:0]const u8) *const Value;

    pub const buildExtractValue = LLVMBuildExtractValue;
    extern fn LLVMBuildExtractValue(
        *const Builder,
        AggVal: *const Value,
        Index: c_uint,
        Name: [*:0]const u8,
    ) *const Value;

    pub const buildExtractElement = LLVMBuildExtractElement;
    extern fn LLVMBuildExtractElement(
        *const Builder,
        VecVal: *const Value,
        Index: *const Value,
        Name: [*:0]const u8,
    ) *const Value;

    pub const buildInsertElement = LLVMBuildInsertElement;
    extern fn LLVMBuildInsertElement(
        *const Builder,
        VecVal: *const Value,
        EltVal: *const Value,
        Index: *const Value,
        Name: [*:0]const u8,
    ) *const Value;

    pub const buildVectorSplat = LLVMBuildVectorSplat;
    extern fn LLVMBuildVectorSplat(
        *const Builder,
        ElementCount: c_uint,
        EltVal: *const Value,
        Name: [*:0]const u8,
    ) *const Value;

    pub const buildPtrToInt = LLVMBuildPtrToInt;
    extern fn LLVMBuildPtrToInt(
        *const Builder,
        Val: *const Value,
        DestTy: *const Type,
        Name: [*:0]const u8,
    ) *const Value;

    pub const buildIntToPtr = LLVMBuildIntToPtr;
    extern fn LLVMBuildIntToPtr(
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

    pub const buildInsertValue = LLVMBuildInsertValue;
    extern fn LLVMBuildInsertValue(
        *const Builder,
        AggVal: *const Value,
        EltVal: *const Value,
        Index: c_uint,
        Name: [*:0]const u8,
    ) *const Value;

    pub const buildAtomicCmpXchg = LLVMBuildAtomicCmpXchg;
    extern fn LLVMBuildAtomicCmpXchg(
        builder: *const Builder,
        ptr: *const Value,
        cmp: *const Value,
        new_val: *const Value,
        success_ordering: AtomicOrdering,
        failure_ordering: AtomicOrdering,
        is_single_threaded: Bool,
    ) *const Value;

    pub const buildSelect = LLVMBuildSelect;
    extern fn LLVMBuildSelect(
        *const Builder,
        If: *const Value,
        Then: *const Value,
        Else: *const Value,
        Name: [*:0]const u8,
    ) *const Value;

    pub const buildFence = LLVMBuildFence;
    extern fn LLVMBuildFence(
        B: *const Builder,
        ordering: AtomicOrdering,
        singleThread: Bool,
        Name: [*:0]const u8,
    ) *const Value;

    pub const buildAtomicRmw = LLVMBuildAtomicRMW;
    extern fn LLVMBuildAtomicRMW(
        B: *const Builder,
        op: AtomicRMWBinOp,
        PTR: *const Value,
        Val: *const Value,
        ordering: AtomicOrdering,
        singleThread: Bool,
    ) *const Value;

    pub const buildFPToUI = LLVMBuildFPToUI;
    extern fn LLVMBuildFPToUI(
        *const Builder,
        Val: *const Value,
        DestTy: *const Type,
        Name: [*:0]const u8,
    ) *const Value;

    pub const buildFPToSI = LLVMBuildFPToSI;
    extern fn LLVMBuildFPToSI(
        *const Builder,
        Val: *const Value,
        DestTy: *const Type,
        Name: [*:0]const u8,
    ) *const Value;

    pub const buildUIToFP = LLVMBuildUIToFP;
    extern fn LLVMBuildUIToFP(
        *const Builder,
        Val: *const Value,
        DestTy: *const Type,
        Name: [*:0]const u8,
    ) *const Value;

    pub const buildSIToFP = LLVMBuildSIToFP;
    extern fn LLVMBuildSIToFP(
        *const Builder,
        Val: *const Value,
        DestTy: *const Type,
        Name: [*:0]const u8,
    ) *const Value;

    pub const buildFPTrunc = LLVMBuildFPTrunc;
    extern fn LLVMBuildFPTrunc(
        *const Builder,
        Val: *const Value,
        DestTy: *const Type,
        Name: [*:0]const u8,
    ) *const Value;

    pub const buildFPExt = LLVMBuildFPExt;
    extern fn LLVMBuildFPExt(
        *const Builder,
        Val: *const Value,
        DestTy: *const Type,
        Name: [*:0]const u8,
    ) *const Value;

    pub const buildMemSet = ZigLLVMBuildMemSet;
    extern fn ZigLLVMBuildMemSet(
        B: *const Builder,
        Ptr: *const Value,
        Val: *const Value,
        Len: *const Value,
        Align: c_uint,
        is_volatile: bool,
    ) *const Value;

    pub const buildMemCpy = ZigLLVMBuildMemCpy;
    extern fn ZigLLVMBuildMemCpy(
        B: *const Builder,
        Dst: *const Value,
        DstAlign: c_uint,
        Src: *const Value,
        SrcAlign: c_uint,
        Size: *const Value,
        is_volatile: bool,
    ) *const Value;

    pub const buildMaxNum = ZigLLVMBuildMaxNum;
    extern fn ZigLLVMBuildMaxNum(builder: *const Builder, LHS: *const Value, RHS: *const Value, name: [*:0]const u8) *const Value;

    pub const buildMinNum = ZigLLVMBuildMinNum;
    extern fn ZigLLVMBuildMinNum(builder: *const Builder, LHS: *const Value, RHS: *const Value, name: [*:0]const u8) *const Value;

    pub const buildUMax = ZigLLVMBuildUMax;
    extern fn ZigLLVMBuildUMax(builder: *const Builder, LHS: *const Value, RHS: *const Value, name: [*:0]const u8) *const Value;

    pub const buildUMin = ZigLLVMBuildUMin;
    extern fn ZigLLVMBuildUMin(builder: *const Builder, LHS: *const Value, RHS: *const Value, name: [*:0]const u8) *const Value;

    pub const buildSMax = ZigLLVMBuildSMax;
    extern fn ZigLLVMBuildSMax(builder: *const Builder, LHS: *const Value, RHS: *const Value, name: [*:0]const u8) *const Value;

    pub const buildSMin = ZigLLVMBuildSMin;
    extern fn ZigLLVMBuildSMin(builder: *const Builder, LHS: *const Value, RHS: *const Value, name: [*:0]const u8) *const Value;

    pub const buildExactUDiv = LLVMBuildExactUDiv;
    extern fn LLVMBuildExactUDiv(*const Builder, LHS: *const Value, RHS: *const Value, Name: [*:0]const u8) *const Value;

    pub const buildExactSDiv = LLVMBuildExactSDiv;
    extern fn LLVMBuildExactSDiv(*const Builder, LHS: *const Value, RHS: *const Value, Name: [*:0]const u8) *const Value;

    pub const setCurrentDebugLocation = ZigLLVMSetCurrentDebugLocation2;
    extern fn ZigLLVMSetCurrentDebugLocation2(builder: *const Builder, line: c_uint, column: c_uint, scope: *DIScope, inlined_at: ?*DILocation) void;

    pub const clearCurrentDebugLocation = ZigLLVMClearCurrentDebugLocation;
    extern fn ZigLLVMClearCurrentDebugLocation(builder: *const Builder) void;

    pub const getCurrentDebugLocation2 = LLVMGetCurrentDebugLocation2;
    extern fn LLVMGetCurrentDebugLocation2(Builder: *const Builder) *Metadata;

    pub const setCurrentDebugLocation2 = LLVMSetCurrentDebugLocation2;
    extern fn LLVMSetCurrentDebugLocation2(Builder: *const Builder, Loc: *Metadata) void;

    pub const buildShuffleVector = LLVMBuildShuffleVector;
    extern fn LLVMBuildShuffleVector(*const Builder, V1: *const Value, V2: *const Value, Mask: *const Value, Name: [*:0]const u8) *const Value;

    pub const buildAndReduce = ZigLLVMBuildAndReduce;
    extern fn ZigLLVMBuildAndReduce(B: *const Builder, Val: *const Value) *const Value;

    pub const buildOrReduce = ZigLLVMBuildOrReduce;
    extern fn ZigLLVMBuildOrReduce(B: *const Builder, Val: *const Value) *const Value;

    pub const buildXorReduce = ZigLLVMBuildXorReduce;
    extern fn ZigLLVMBuildXorReduce(B: *const Builder, Val: *const Value) *const Value;

    pub const buildIntMaxReduce = ZigLLVMBuildIntMaxReduce;
    extern fn ZigLLVMBuildIntMaxReduce(B: *const Builder, Val: *const Value, is_signed: bool) *const Value;

    pub const buildIntMinReduce = ZigLLVMBuildIntMinReduce;
    extern fn ZigLLVMBuildIntMinReduce(B: *const Builder, Val: *const Value, is_signed: bool) *const Value;

    pub const buildFPMaxReduce = ZigLLVMBuildFPMaxReduce;
    extern fn ZigLLVMBuildFPMaxReduce(B: *const Builder, Val: *const Value) *const Value;

    pub const buildFPMinReduce = ZigLLVMBuildFPMinReduce;
    extern fn ZigLLVMBuildFPMinReduce(B: *const Builder, Val: *const Value) *const Value;

    pub const buildAddReduce = ZigLLVMBuildAddReduce;
    extern fn ZigLLVMBuildAddReduce(B: *const Builder, Val: *const Value) *const Value;

    pub const buildMulReduce = ZigLLVMBuildMulReduce;
    extern fn ZigLLVMBuildMulReduce(B: *const Builder, Val: *const Value) *const Value;

    pub const buildFPAddReduce = ZigLLVMBuildFPAddReduce;
    extern fn ZigLLVMBuildFPAddReduce(B: *const Builder, Acc: *const Value, Val: *const Value) *const Value;

    pub const buildFPMulReduce = ZigLLVMBuildFPMulReduce;
    extern fn ZigLLVMBuildFPMulReduce(B: *const Builder, Acc: *const Value, Val: *const Value) *const Value;
};

pub const MDString = opaque {
    pub const get = LLVMMDStringInContext2;
    extern fn LLVMMDStringInContext2(C: *const Context, Str: [*]const u8, SLen: usize) *MDString;
};

pub const DIScope = opaque {
    pub const toNode = ZigLLVMScopeToNode;
    extern fn ZigLLVMScopeToNode(scope: *DIScope) *DINode;
};

pub const DINode = opaque {};
pub const Metadata = opaque {};

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

    pub const createTargetDataLayout = LLVMCreateTargetDataLayout;
    extern fn LLVMCreateTargetDataLayout(*const TargetMachine) *const TargetData;
};

pub const TargetData = opaque {
    pub const dispose = LLVMDisposeTargetData;
    extern fn LLVMDisposeTargetData(*const TargetData) void;

    pub const abiAlignmentOfType = LLVMABIAlignmentOfType;
    extern fn LLVMABIAlignmentOfType(TD: *const TargetData, Ty: *const Type) c_uint;

    pub const abiSizeOfType = LLVMABISizeOfType;
    extern fn LLVMABISizeOfType(TD: *const TargetData, Ty: *const Type) c_ulonglong;
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
pub extern fn LLVMInitializeM68kTargetInfo() void;
pub extern fn LLVMInitializeCSKYTargetInfo() void;
pub extern fn LLVMInitializeVETargetInfo() void;
pub extern fn LLVMInitializeARCTargetInfo() void;

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
pub extern fn LLVMInitializeM68kTarget() void;
pub extern fn LLVMInitializeVETarget() void;
pub extern fn LLVMInitializeCSKYTarget() void;
pub extern fn LLVMInitializeARCTarget() void;

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
pub extern fn LLVMInitializeM68kTargetMC() void;
pub extern fn LLVMInitializeCSKYTargetMC() void;
pub extern fn LLVMInitializeVETargetMC() void;
pub extern fn LLVMInitializeARCTargetMC() void;

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
pub extern fn LLVMInitializeM68kAsmPrinter() void;
pub extern fn LLVMInitializeVEAsmPrinter() void;
pub extern fn LLVMInitializeARCAsmPrinter() void;

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
pub extern fn LLVMInitializeM68kAsmParser() void;
pub extern fn LLVMInitializeCSKYAsmParser() void;
pub extern fn LLVMInitializeVEAsmParser() void;

extern fn ZigLLDLinkCOFF(argc: c_int, argv: [*:null]const ?[*:0]const u8, can_exit_early: bool, disable_output: bool) bool;
extern fn ZigLLDLinkELF(argc: c_int, argv: [*:null]const ?[*:0]const u8, can_exit_early: bool, disable_output: bool) bool;
extern fn ZigLLDLinkWasm(argc: c_int, argv: [*:null]const ?[*:0]const u8, can_exit_early: bool, disable_output: bool) bool;

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
    m68k,
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
    output_lib_path: [*:0]const u8,
    kill_at: bool,
) bool;

pub const setCallElemTypeAttr = ZigLLVMSetCallElemTypeAttr;
extern fn ZigLLVMSetCallElemTypeAttr(Call: *const Value, arg_index: usize, return_type: *const Type) void;

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

pub const Visibility = enum(c_uint) {
    Default,
    Hidden,
    Protected,
};

pub const ThreadLocalMode = enum(c_uint) {
    NotThreadLocal,
    GeneralDynamicTLSModel,
    LocalDynamicTLSModel,
    InitialExecTLSModel,
    LocalExecTLSModel,
};

pub const AtomicOrdering = enum(c_uint) {
    NotAtomic = 0,
    Unordered = 1,
    Monotonic = 2,
    Acquire = 4,
    Release = 5,
    AcquireRelease = 6,
    SequentiallyConsistent = 7,
};

pub const AtomicRMWBinOp = enum(c_int) {
    Xchg,
    Add,
    Sub,
    And,
    Nand,
    Or,
    Xor,
    Max,
    Min,
    UMax,
    UMin,
    FAdd,
    FSub,
};

pub const TypeKind = enum(c_int) {
    Void,
    Half,
    Float,
    Double,
    X86_FP80,
    FP128,
    PPC_FP128,
    Label,
    Integer,
    Function,
    Struct,
    Array,
    Pointer,
    Vector,
    Metadata,
    X86_MMX,
    Token,
    ScalableVector,
    BFloat,
    X86_AMX,
};

pub const CallConv = enum(c_uint) {
    C = 0,
    Fast = 8,
    Cold = 9,
    GHC = 10,
    HiPE = 11,
    WebKit_JS = 12,
    AnyReg = 13,
    PreserveMost = 14,
    PreserveAll = 15,
    Swift = 16,
    CXX_FAST_TLS = 17,

    X86_StdCall = 64,
    X86_FastCall = 65,
    ARM_APCS = 66,
    ARM_AAPCS = 67,
    ARM_AAPCS_VFP = 68,
    MSP430_INTR = 69,
    X86_ThisCall = 70,
    PTX_Kernel = 71,
    PTX_Device = 72,
    SPIR_FUNC = 75,
    SPIR_KERNEL = 76,
    Intel_OCL_BI = 77,
    X86_64_SysV = 78,
    Win64 = 79,
    X86_VectorCall = 80,
    HHVM = 81,
    HHVM_C = 82,
    X86_INTR = 83,
    AVR_INTR = 84,
    AVR_SIGNAL = 85,
    AVR_BUILTIN = 86,
    AMDGPU_VS = 87,
    AMDGPU_GS = 88,
    AMDGPU_PS = 89,
    AMDGPU_CS = 90,
    AMDGPU_KERNEL = 91,
    X86_RegCall = 92,
    AMDGPU_HS = 93,
    MSP430_BUILTIN = 94,
    AMDGPU_LS = 95,
    AMDGPU_ES = 96,
    AArch64_VectorCall = 97,
};

pub const CallAttr = enum(c_int) {
    Auto,
    NeverTail,
    NeverInline,
    AlwaysTail,
    AlwaysInline,
};

pub const address_space = struct {
    pub const default: c_uint = 0;

    // See llvm/lib/Target/X86/X86.h
    pub const x86_64 = x86;
    pub const x86 = struct {
        pub const gs: c_uint = 256;
        pub const fs: c_uint = 257;
        pub const ss: c_uint = 258;

        pub const ptr32_sptr: c_uint = 270;
        pub const ptr32_uptr: c_uint = 271;
        pub const ptr64: c_uint = 272;
    };

    // See llvm/lib/Target/AVR/AVR.h
    pub const avr = struct {
        pub const data_memory: c_uint = 0;
        pub const program_memory: c_uint = 1;
    };

    // See llvm/lib/Target/NVPTX/NVPTX.h
    pub const nvptx = struct {
        pub const generic: c_uint = 0;
        pub const global: c_uint = 1;
        pub const constant: c_uint = 2;
        pub const shared: c_uint = 3;
        pub const param: c_uint = 4;
        pub const local: c_uint = 5;
    };

    // See llvm/lib/Target/AMDGPU/AMDGPU.h
    pub const amdgpu = struct {
        pub const flat: c_uint = 0;
        pub const global: c_uint = 1;
        pub const region: c_uint = 2;
        pub const local: c_uint = 3;
        pub const constant: c_uint = 4;
        pub const private: c_uint = 5;
        pub const constant_32bit: c_uint = 6;
        pub const buffer_fat_pointer: c_uint = 7;
        pub const param_d: c_uint = 6;
        pub const param_i: c_uint = 7;
        pub const constant_buffer_0: c_uint = 8;
        pub const constant_buffer_1: c_uint = 9;
        pub const constant_buffer_2: c_uint = 10;
        pub const constant_buffer_3: c_uint = 11;
        pub const constant_buffer_4: c_uint = 12;
        pub const constant_buffer_5: c_uint = 13;
        pub const constant_buffer_6: c_uint = 14;
        pub const constant_buffer_7: c_uint = 15;
        pub const constant_buffer_8: c_uint = 16;
        pub const constant_buffer_9: c_uint = 17;
        pub const constant_buffer_10: c_uint = 18;
        pub const constant_buffer_11: c_uint = 19;
        pub const constant_buffer_12: c_uint = 20;
        pub const constant_buffer_13: c_uint = 21;
        pub const constant_buffer_14: c_uint = 22;
        pub const constant_buffer_15: c_uint = 23;
    };
};

pub const DIEnumerator = opaque {};
pub const DILocalVariable = opaque {};
pub const DILocation = opaque {};

pub const DIGlobalVariable = opaque {
    pub const toNode = ZigLLVMGlobalVariableToNode;
    extern fn ZigLLVMGlobalVariableToNode(global_variable: *DIGlobalVariable) *DINode;

    pub const replaceLinkageName = ZigLLVMGlobalVariableReplaceLinkageName;
    extern fn ZigLLVMGlobalVariableReplaceLinkageName(global_variable: *DIGlobalVariable, linkage_name: *MDString) void;
};
pub const DIType = opaque {
    pub const toScope = ZigLLVMTypeToScope;
    extern fn ZigLLVMTypeToScope(ty: *DIType) *DIScope;

    pub const toNode = ZigLLVMTypeToNode;
    extern fn ZigLLVMTypeToNode(ty: *DIType) *DINode;
};
pub const DIFile = opaque {
    pub const toScope = ZigLLVMFileToScope;
    extern fn ZigLLVMFileToScope(difile: *DIFile) *DIScope;

    pub const toNode = ZigLLVMFileToNode;
    extern fn ZigLLVMFileToNode(difile: *DIFile) *DINode;
};
pub const DILexicalBlock = opaque {
    pub const toScope = ZigLLVMLexicalBlockToScope;
    extern fn ZigLLVMLexicalBlockToScope(lexical_block: *DILexicalBlock) *DIScope;

    pub const toNode = ZigLLVMLexicalBlockToNode;
    extern fn ZigLLVMLexicalBlockToNode(lexical_block: *DILexicalBlock) *DINode;
};
pub const DICompileUnit = opaque {
    pub const toScope = ZigLLVMCompileUnitToScope;
    extern fn ZigLLVMCompileUnitToScope(compile_unit: *DICompileUnit) *DIScope;

    pub const toNode = ZigLLVMCompileUnitToNode;
    extern fn ZigLLVMCompileUnitToNode(compile_unit: *DICompileUnit) *DINode;
};
pub const DISubprogram = opaque {
    pub const toScope = ZigLLVMSubprogramToScope;
    extern fn ZigLLVMSubprogramToScope(subprogram: *DISubprogram) *DIScope;

    pub const toNode = ZigLLVMSubprogramToNode;
    extern fn ZigLLVMSubprogramToNode(subprogram: *DISubprogram) *DINode;

    pub const replaceLinkageName = ZigLLVMSubprogramReplaceLinkageName;
    extern fn ZigLLVMSubprogramReplaceLinkageName(subprogram: *DISubprogram, linkage_name: *MDString) void;
};

pub const getDebugLoc = ZigLLVMGetDebugLoc2;
extern fn ZigLLVMGetDebugLoc2(line: c_uint, col: c_uint, scope: *DIScope, inlined_at: ?*DILocation) *DILocation;

pub const DIBuilder = opaque {
    pub const dispose = ZigLLVMDisposeDIBuilder;
    extern fn ZigLLVMDisposeDIBuilder(dib: *DIBuilder) void;

    pub const finalize = ZigLLVMDIBuilderFinalize;
    extern fn ZigLLVMDIBuilderFinalize(dib: *DIBuilder) void;

    pub const createPointerType = ZigLLVMCreateDebugPointerType;
    extern fn ZigLLVMCreateDebugPointerType(
        dib: *DIBuilder,
        pointee_type: *DIType,
        size_in_bits: u64,
        align_in_bits: u64,
        name: [*:0]const u8,
    ) *DIType;

    pub const createBasicType = ZigLLVMCreateDebugBasicType;
    extern fn ZigLLVMCreateDebugBasicType(
        dib: *DIBuilder,
        name: [*:0]const u8,
        size_in_bits: u64,
        encoding: c_uint,
    ) *DIType;

    pub const createArrayType = ZigLLVMCreateDebugArrayType;
    extern fn ZigLLVMCreateDebugArrayType(
        dib: *DIBuilder,
        size_in_bits: u64,
        align_in_bits: u64,
        elem_type: *DIType,
        elem_count: c_int,
    ) *DIType;

    pub const createEnumerator = ZigLLVMCreateDebugEnumerator;
    extern fn ZigLLVMCreateDebugEnumerator(
        dib: *DIBuilder,
        name: [*:0]const u8,
        val: i64,
    ) *DIEnumerator;

    pub const createEnumerationType = ZigLLVMCreateDebugEnumerationType;
    extern fn ZigLLVMCreateDebugEnumerationType(
        dib: *DIBuilder,
        scope: *DIScope,
        name: [*:0]const u8,
        file: *DIFile,
        line_number: c_uint,
        size_in_bits: u64,
        align_in_bits: u64,
        enumerator_array: [*]const *DIEnumerator,
        enumerator_array_len: c_int,
        underlying_type: *DIType,
        unique_id: [*:0]const u8,
    ) *DIType;

    pub const createStructType = ZigLLVMCreateDebugStructType;
    extern fn ZigLLVMCreateDebugStructType(
        dib: *DIBuilder,
        scope: *DIScope,
        name: [*:0]const u8,
        file: ?*DIFile,
        line_number: c_uint,
        size_in_bits: u64,
        align_in_bits: u64,
        flags: c_uint,
        derived_from: ?*DIType,
        types_array: [*]const *DIType,
        types_array_len: c_int,
        run_time_lang: c_uint,
        vtable_holder: ?*DIType,
        unique_id: [*:0]const u8,
    ) *DIType;

    pub const createUnionType = ZigLLVMCreateDebugUnionType;
    extern fn ZigLLVMCreateDebugUnionType(
        dib: *DIBuilder,
        scope: *DIScope,
        name: [*:0]const u8,
        file: ?*DIFile,
        line_number: c_uint,
        size_in_bits: u64,
        align_in_bits: u64,
        flags: c_uint,
        types_array: [*]const *DIType,
        types_array_len: c_int,
        run_time_lang: c_uint,
        unique_id: [*:0]const u8,
    ) *DIType;

    pub const createMemberType = ZigLLVMCreateDebugMemberType;
    extern fn ZigLLVMCreateDebugMemberType(
        dib: *DIBuilder,
        scope: *DIScope,
        name: [*:0]const u8,
        file: ?*DIFile,
        line: c_uint,
        size_in_bits: u64,
        align_in_bits: u64,
        offset_in_bits: u64,
        flags: c_uint,
        ty: *DIType,
    ) *DIType;

    pub const createReplaceableCompositeType = ZigLLVMCreateReplaceableCompositeType;
    extern fn ZigLLVMCreateReplaceableCompositeType(
        dib: *DIBuilder,
        tag: c_uint,
        name: [*:0]const u8,
        scope: *DIScope,
        file: ?*DIFile,
        line: c_uint,
    ) *DIType;

    pub const createForwardDeclType = ZigLLVMCreateDebugForwardDeclType;
    extern fn ZigLLVMCreateDebugForwardDeclType(
        dib: *DIBuilder,
        tag: c_uint,
        name: [*:0]const u8,
        scope: *DIScope,
        file: *DIFile,
        line: c_uint,
    ) *DIType;

    pub const replaceTemporary = ZigLLVMReplaceTemporary;
    extern fn ZigLLVMReplaceTemporary(dib: *DIBuilder, ty: *DIType, replacement: *DIType) void;

    pub const replaceDebugArrays = ZigLLVMReplaceDebugArrays;
    extern fn ZigLLVMReplaceDebugArrays(
        dib: *DIBuilder,
        ty: *DIType,
        types_array: [*]const *DIType,
        types_array_len: c_int,
    ) void;

    pub const createSubroutineType = ZigLLVMCreateSubroutineType;
    extern fn ZigLLVMCreateSubroutineType(
        dib: *DIBuilder,
        types_array: [*]const *DIType,
        types_array_len: c_int,
        flags: c_uint,
    ) *DIType;

    pub const createAutoVariable = ZigLLVMCreateAutoVariable;
    extern fn ZigLLVMCreateAutoVariable(
        dib: *DIBuilder,
        scope: *DIScope,
        name: [*:0]const u8,
        file: *DIFile,
        line_no: c_uint,
        ty: *DIType,
        always_preserve: bool,
        flags: c_uint,
    ) *DILocalVariable;

    pub const createGlobalVariable = ZigLLVMCreateGlobalVariable;
    extern fn ZigLLVMCreateGlobalVariable(
        dib: *DIBuilder,
        scope: *DIScope,
        name: [*:0]const u8,
        linkage_name: [*:0]const u8,
        file: *DIFile,
        line_no: c_uint,
        di_type: *DIType,
        is_local_to_unit: bool,
    ) *DIGlobalVariable;

    pub const createParameterVariable = ZigLLVMCreateParameterVariable;
    extern fn ZigLLVMCreateParameterVariable(
        dib: *DIBuilder,
        scope: *DIScope,
        name: [*:0]const u8,
        file: *DIFile,
        line_no: c_uint,
        ty: *DIType,
        always_preserve: bool,
        flags: c_uint,
        arg_no: c_uint,
    ) *DILocalVariable;

    pub const createLexicalBlock = ZigLLVMCreateLexicalBlock;
    extern fn ZigLLVMCreateLexicalBlock(
        dib: *DIBuilder,
        scope: *DIScope,
        file: *DIFile,
        line: c_uint,
        col: c_uint,
    ) *DILexicalBlock;

    pub const createCompileUnit = ZigLLVMCreateCompileUnit;
    extern fn ZigLLVMCreateCompileUnit(
        dib: *DIBuilder,
        lang: c_uint,
        difile: *DIFile,
        producer: [*:0]const u8,
        is_optimized: bool,
        flags: [*:0]const u8,
        runtime_version: c_uint,
        split_name: [*:0]const u8,
        dwo_id: u64,
        emit_debug_info: bool,
    ) *DICompileUnit;

    pub const createFile = ZigLLVMCreateFile;
    extern fn ZigLLVMCreateFile(
        dib: *DIBuilder,
        filename: [*:0]const u8,
        directory: [*:0]const u8,
    ) *DIFile;

    pub const createFunction = ZigLLVMCreateFunction;
    extern fn ZigLLVMCreateFunction(
        dib: *DIBuilder,
        scope: *DIScope,
        name: [*:0]const u8,
        linkage_name: [*:0]const u8,
        file: *DIFile,
        lineno: c_uint,
        fn_di_type: *DIType,
        is_local_to_unit: bool,
        is_definition: bool,
        scope_line: c_uint,
        flags: c_uint,
        is_optimized: bool,
        decl_subprogram: ?*DISubprogram,
    ) *DISubprogram;

    pub const createVectorType = ZigLLVMDIBuilderCreateVectorType;
    extern fn ZigLLVMDIBuilderCreateVectorType(
        dib: *DIBuilder,
        SizeInBits: u64,
        AlignInBits: u32,
        Ty: *DIType,
        elem_count: u32,
    ) *DIType;

    pub const insertDeclareAtEnd = ZigLLVMInsertDeclareAtEnd;
    extern fn ZigLLVMInsertDeclareAtEnd(
        dib: *DIBuilder,
        storage: *const Value,
        var_info: *DILocalVariable,
        debug_loc: *DILocation,
        basic_block_ref: *const BasicBlock,
    ) *const Value;

    pub const insertDeclare = ZigLLVMInsertDeclare;
    extern fn ZigLLVMInsertDeclare(
        dib: *DIBuilder,
        storage: *const Value,
        var_info: *DILocalVariable,
        debug_loc: *DILocation,
        insert_before_instr: *const Value,
    ) *const Value;

    pub const insertDbgValueIntrinsicAtEnd = ZigLLVMInsertDbgValueIntrinsicAtEnd;
    extern fn ZigLLVMInsertDbgValueIntrinsicAtEnd(
        dib: *DIBuilder,
        val: *const Value,
        var_info: *DILocalVariable,
        debug_loc: *DILocation,
        basic_block_ref: *const BasicBlock,
    ) *const Value;
};

pub const DIFlags = opaque {
    pub const Zero = 0;
    pub const Private = 1;
    pub const Protected = 2;
    pub const Public = 3;

    pub const FwdDecl = 1 << 2;
    pub const AppleBlock = 1 << 3;
    pub const BlockByrefStruct = 1 << 4;
    pub const Virtual = 1 << 5;
    pub const Artificial = 1 << 6;
    pub const Explicit = 1 << 7;
    pub const Prototyped = 1 << 8;
    pub const ObjcClassComplete = 1 << 9;
    pub const ObjectPointer = 1 << 10;
    pub const Vector = 1 << 11;
    pub const StaticMember = 1 << 12;
    pub const LValueReference = 1 << 13;
    pub const RValueReference = 1 << 14;
    pub const Reserved = 1 << 15;

    pub const SingleInheritance = 1 << 16;
    pub const MultipleInheritance = 2 << 16;
    pub const VirtualInheritance = 3 << 16;

    pub const IntroducedVirtual = 1 << 18;
    pub const BitField = 1 << 19;
    pub const NoReturn = 1 << 20;
    pub const TypePassByValue = 1 << 22;
    pub const TypePassByReference = 1 << 23;
    pub const EnumClass = 1 << 24;
    pub const Thunk = 1 << 25;
    pub const NonTrivial = 1 << 26;
    pub const BigEndian = 1 << 27;
    pub const LittleEndian = 1 << 28;
    pub const AllCallsDescribed = 1 << 29;
};
