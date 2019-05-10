pub const struct_ZigClangAPValue = @OpaqueType();
pub const struct_ZigClangAPSInt = @OpaqueType();
pub const struct_ZigClangASTContext = @OpaqueType();
pub const struct_ZigClangASTUnit = @OpaqueType();
pub const struct_ZigClangArraySubscriptExpr = @OpaqueType();
pub const struct_ZigClangArrayType = @OpaqueType();
pub const struct_ZigClangAttributedType = @OpaqueType();
pub const struct_ZigClangBinaryOperator = @OpaqueType();
pub const struct_ZigClangBreakStmt = @OpaqueType();
pub const struct_ZigClangBuiltinType = @OpaqueType();
pub const struct_ZigClangCStyleCastExpr = @OpaqueType();
pub const struct_ZigClangCallExpr = @OpaqueType();
pub const struct_ZigClangCaseStmt = @OpaqueType();
pub const struct_ZigClangCompoundAssignOperator = @OpaqueType();
pub const struct_ZigClangCompoundStmt = @OpaqueType();
pub const struct_ZigClangConditionalOperator = @OpaqueType();
pub const struct_ZigClangConstantArrayType = @OpaqueType();
pub const struct_ZigClangContinueStmt = @OpaqueType();
pub const struct_ZigClangDecayedType = @OpaqueType();
pub const struct_ZigClangDecl = @OpaqueType();
pub const struct_ZigClangDeclRefExpr = @OpaqueType();
pub const struct_ZigClangDeclStmt = @OpaqueType();
pub const struct_ZigClangDefaultStmt = @OpaqueType();
pub const struct_ZigClangDiagnosticOptions = @OpaqueType();
pub const struct_ZigClangDiagnosticsEngine = @OpaqueType();
pub const struct_ZigClangDoStmt = @OpaqueType();
pub const struct_ZigClangElaboratedType = @OpaqueType();
pub const struct_ZigClangEnumConstantDecl = @OpaqueType();
pub const struct_ZigClangEnumDecl = @OpaqueType();
pub const struct_ZigClangEnumType = @OpaqueType();
pub const struct_ZigClangExpr = @OpaqueType();
pub const struct_ZigClangFieldDecl = @OpaqueType();
pub const struct_ZigClangFileID = @OpaqueType();
pub const struct_ZigClangForStmt = @OpaqueType();
pub const struct_ZigClangFullSourceLoc = @OpaqueType();
pub const struct_ZigClangFunctionDecl = @OpaqueType();
pub const struct_ZigClangFunctionProtoType = @OpaqueType();
pub const struct_ZigClangIfStmt = @OpaqueType();
pub const struct_ZigClangImplicitCastExpr = @OpaqueType();
pub const struct_ZigClangIncompleteArrayType = @OpaqueType();
pub const struct_ZigClangIntegerLiteral = @OpaqueType();
pub const struct_ZigClangMacroDefinitionRecord = @OpaqueType();
pub const struct_ZigClangMemberExpr = @OpaqueType();
pub const struct_ZigClangNamedDecl = @OpaqueType();
pub const struct_ZigClangNone = @OpaqueType();
pub const struct_ZigClangPCHContainerOperations = @OpaqueType();
pub const struct_ZigClangParenExpr = @OpaqueType();
pub const struct_ZigClangParenType = @OpaqueType();
pub const struct_ZigClangParmVarDecl = @OpaqueType();
pub const struct_ZigClangPointerType = @OpaqueType();
pub const struct_ZigClangPreprocessedEntity = @OpaqueType();
pub const struct_ZigClangRecordDecl = @OpaqueType();
pub const struct_ZigClangRecordType = @OpaqueType();
pub const struct_ZigClangReturnStmt = @OpaqueType();
pub const struct_ZigClangSkipFunctionBodiesScope = @OpaqueType();
pub const struct_ZigClangSourceManager = @OpaqueType();
pub const struct_ZigClangSourceRange = @OpaqueType();
pub const struct_ZigClangStmt = @OpaqueType();
pub const struct_ZigClangStorageClass = @OpaqueType();
pub const struct_ZigClangStringLiteral = @OpaqueType();
pub const struct_ZigClangStringRef = @OpaqueType();
pub const struct_ZigClangSwitchStmt = @OpaqueType();
pub const struct_ZigClangTagDecl = @OpaqueType();
pub const struct_ZigClangType = @OpaqueType();
pub const struct_ZigClangTypedefNameDecl = @OpaqueType();
pub const struct_ZigClangTypedefType = @OpaqueType();
pub const struct_ZigClangUnaryExprOrTypeTraitExpr = @OpaqueType();
pub const struct_ZigClangUnaryOperator = @OpaqueType();
pub const struct_ZigClangValueDecl = @OpaqueType();
pub const struct_ZigClangVarDecl = @OpaqueType();
pub const struct_ZigClangWhileStmt = @OpaqueType();
pub const ZigClangFunctionType = @OpaqueType();

pub const ZigClangBO = extern enum {
    PtrMemD,
    PtrMemI,
    Mul,
    Div,
    Rem,
    Add,
    Sub,
    Shl,
    Shr,
    Cmp,
    LT,
    GT,
    LE,
    GE,
    EQ,
    NE,
    And,
    Xor,
    Or,
    LAnd,
    LOr,
    Assign,
    MulAssign,
    DivAssign,
    RemAssign,
    AddAssign,
    SubAssign,
    ShlAssign,
    ShrAssign,
    AndAssign,
    XorAssign,
    OrAssign,
    Comma,
};

pub const ZigClangUO = extern enum {
    PostInc,
    PostDec,
    PreInc,
    PreDec,
    AddrOf,
    Deref,
    Plus,
    Minus,
    Not,
    LNot,
    Real,
    Imag,
    Extension,
    Coawait,
};

pub const ZigClangTypeClass = extern enum {
    Builtin,
    Complex,
    Pointer,
    BlockPointer,
    LValueReference,
    RValueReference,
    MemberPointer,
    ConstantArray,
    IncompleteArray,
    VariableArray,
    DependentSizedArray,
    DependentSizedExtVector,
    DependentAddressSpace,
    Vector,
    DependentVector,
    ExtVector,
    FunctionProto,
    FunctionNoProto,
    UnresolvedUsing,
    Paren,
    Typedef,
    Adjusted,
    Decayed,
    TypeOfExpr,
    TypeOf,
    Decltype,
    UnaryTransform,
    Record,
    Enum,
    Elaborated,
    Attributed,
    TemplateTypeParm,
    SubstTemplateTypeParm,
    SubstTemplateTypeParmPack,
    TemplateSpecialization,
    Auto,
    DeducedTemplateSpecialization,
    InjectedClassName,
    DependentName,
    DependentTemplateSpecialization,
    PackExpansion,
    ObjCTypeParam,
    ObjCObject,
    ObjCInterface,
    ObjCObjectPointer,
    Pipe,
    Atomic,
};

pub const ZigClangStmtClass = extern enum {
    NoStmtClass = 0,
    GCCAsmStmtClass = 1,
    MSAsmStmtClass = 2,
    AttributedStmtClass = 3,
    BreakStmtClass = 4,
    CXXCatchStmtClass = 5,
    CXXForRangeStmtClass = 6,
    CXXTryStmtClass = 7,
    CapturedStmtClass = 8,
    CompoundStmtClass = 9,
    ContinueStmtClass = 10,
    CoreturnStmtClass = 11,
    CoroutineBodyStmtClass = 12,
    DeclStmtClass = 13,
    DoStmtClass = 14,
    BinaryConditionalOperatorClass = 15,
    ConditionalOperatorClass = 16,
    AddrLabelExprClass = 17,
    ArrayInitIndexExprClass = 18,
    ArrayInitLoopExprClass = 19,
    ArraySubscriptExprClass = 20,
    ArrayTypeTraitExprClass = 21,
    AsTypeExprClass = 22,
    AtomicExprClass = 23,
    BinaryOperatorClass = 24,
    CompoundAssignOperatorClass = 25,
    BlockExprClass = 26,
    CXXBindTemporaryExprClass = 27,
    CXXBoolLiteralExprClass = 28,
    CXXConstructExprClass = 29,
    CXXTemporaryObjectExprClass = 30,
    CXXDefaultArgExprClass = 31,
    CXXDefaultInitExprClass = 32,
    CXXDeleteExprClass = 33,
    CXXDependentScopeMemberExprClass = 34,
    CXXFoldExprClass = 35,
    CXXInheritedCtorInitExprClass = 36,
    CXXNewExprClass = 37,
    CXXNoexceptExprClass = 38,
    CXXNullPtrLiteralExprClass = 39,
    CXXPseudoDestructorExprClass = 40,
    CXXScalarValueInitExprClass = 41,
    CXXStdInitializerListExprClass = 42,
    CXXThisExprClass = 43,
    CXXThrowExprClass = 44,
    CXXTypeidExprClass = 45,
    CXXUnresolvedConstructExprClass = 46,
    CXXUuidofExprClass = 47,
    CallExprClass = 48,
    CUDAKernelCallExprClass = 49,
    CXXMemberCallExprClass = 50,
    CXXOperatorCallExprClass = 51,
    UserDefinedLiteralClass = 52,
    CStyleCastExprClass = 53,
    CXXFunctionalCastExprClass = 54,
    CXXConstCastExprClass = 55,
    CXXDynamicCastExprClass = 56,
    CXXReinterpretCastExprClass = 57,
    CXXStaticCastExprClass = 58,
    ObjCBridgedCastExprClass = 59,
    ImplicitCastExprClass = 60,
    CharacterLiteralClass = 61,
    ChooseExprClass = 62,
    CompoundLiteralExprClass = 63,
    ConvertVectorExprClass = 64,
    CoawaitExprClass = 65,
    CoyieldExprClass = 66,
    DeclRefExprClass = 67,
    DependentCoawaitExprClass = 68,
    DependentScopeDeclRefExprClass = 69,
    DesignatedInitExprClass = 70,
    DesignatedInitUpdateExprClass = 71,
    ExpressionTraitExprClass = 72,
    ExtVectorElementExprClass = 73,
    FixedPointLiteralClass = 74,
    FloatingLiteralClass = 75,
    ConstantExprClass = 76,
    ExprWithCleanupsClass = 77,
    FunctionParmPackExprClass = 78,
    GNUNullExprClass = 79,
    GenericSelectionExprClass = 80,
    ImaginaryLiteralClass = 81,
    ImplicitValueInitExprClass = 82,
    InitListExprClass = 83,
    IntegerLiteralClass = 84,
    LambdaExprClass = 85,
    MSPropertyRefExprClass = 86,
    MSPropertySubscriptExprClass = 87,
    MaterializeTemporaryExprClass = 88,
    MemberExprClass = 89,
    NoInitExprClass = 90,
    OMPArraySectionExprClass = 91,
    ObjCArrayLiteralClass = 92,
    ObjCAvailabilityCheckExprClass = 93,
    ObjCBoolLiteralExprClass = 94,
    ObjCBoxedExprClass = 95,
    ObjCDictionaryLiteralClass = 96,
    ObjCEncodeExprClass = 97,
    ObjCIndirectCopyRestoreExprClass = 98,
    ObjCIsaExprClass = 99,
    ObjCIvarRefExprClass = 100,
    ObjCMessageExprClass = 101,
    ObjCPropertyRefExprClass = 102,
    ObjCProtocolExprClass = 103,
    ObjCSelectorExprClass = 104,
    ObjCStringLiteralClass = 105,
    ObjCSubscriptRefExprClass = 106,
    OffsetOfExprClass = 107,
    OpaqueValueExprClass = 108,
    UnresolvedLookupExprClass = 109,
    UnresolvedMemberExprClass = 110,
    PackExpansionExprClass = 111,
    ParenExprClass = 112,
    ParenListExprClass = 113,
    PredefinedExprClass = 114,
    PseudoObjectExprClass = 115,
    ShuffleVectorExprClass = 116,
    SizeOfPackExprClass = 117,
    StmtExprClass = 118,
    StringLiteralClass = 119,
    SubstNonTypeTemplateParmExprClass = 120,
    SubstNonTypeTemplateParmPackExprClass = 121,
    TypeTraitExprClass = 122,
    TypoExprClass = 123,
    UnaryExprOrTypeTraitExprClass = 124,
    UnaryOperatorClass = 125,
    VAArgExprClass = 126,
    ForStmtClass = 127,
    GotoStmtClass = 128,
    IfStmtClass = 129,
    IndirectGotoStmtClass = 130,
    LabelStmtClass = 131,
    MSDependentExistsStmtClass = 132,
    NullStmtClass = 133,
    OMPAtomicDirectiveClass = 134,
    OMPBarrierDirectiveClass = 135,
    OMPCancelDirectiveClass = 136,
    OMPCancellationPointDirectiveClass = 137,
    OMPCriticalDirectiveClass = 138,
    OMPFlushDirectiveClass = 139,
    OMPDistributeDirectiveClass = 140,
    OMPDistributeParallelForDirectiveClass = 141,
    OMPDistributeParallelForSimdDirectiveClass = 142,
    OMPDistributeSimdDirectiveClass = 143,
    OMPForDirectiveClass = 144,
    OMPForSimdDirectiveClass = 145,
    OMPParallelForDirectiveClass = 146,
    OMPParallelForSimdDirectiveClass = 147,
    OMPSimdDirectiveClass = 148,
    OMPTargetParallelForSimdDirectiveClass = 149,
    OMPTargetSimdDirectiveClass = 150,
    OMPTargetTeamsDistributeDirectiveClass = 151,
    OMPTargetTeamsDistributeParallelForDirectiveClass = 152,
    OMPTargetTeamsDistributeParallelForSimdDirectiveClass = 153,
    OMPTargetTeamsDistributeSimdDirectiveClass = 154,
    OMPTaskLoopDirectiveClass = 155,
    OMPTaskLoopSimdDirectiveClass = 156,
    OMPTeamsDistributeDirectiveClass = 157,
    OMPTeamsDistributeParallelForDirectiveClass = 158,
    OMPTeamsDistributeParallelForSimdDirectiveClass = 159,
    OMPTeamsDistributeSimdDirectiveClass = 160,
    OMPMasterDirectiveClass = 161,
    OMPOrderedDirectiveClass = 162,
    OMPParallelDirectiveClass = 163,
    OMPParallelSectionsDirectiveClass = 164,
    OMPSectionDirectiveClass = 165,
    OMPSectionsDirectiveClass = 166,
    OMPSingleDirectiveClass = 167,
    OMPTargetDataDirectiveClass = 168,
    OMPTargetDirectiveClass = 169,
    OMPTargetEnterDataDirectiveClass = 170,
    OMPTargetExitDataDirectiveClass = 171,
    OMPTargetParallelDirectiveClass = 172,
    OMPTargetParallelForDirectiveClass = 173,
    OMPTargetTeamsDirectiveClass = 174,
    OMPTargetUpdateDirectiveClass = 175,
    OMPTaskDirectiveClass = 176,
    OMPTaskgroupDirectiveClass = 177,
    OMPTaskwaitDirectiveClass = 178,
    OMPTaskyieldDirectiveClass = 179,
    OMPTeamsDirectiveClass = 180,
    ObjCAtCatchStmtClass = 181,
    ObjCAtFinallyStmtClass = 182,
    ObjCAtSynchronizedStmtClass = 183,
    ObjCAtThrowStmtClass = 184,
    ObjCAtTryStmtClass = 185,
    ObjCAutoreleasePoolStmtClass = 186,
    ObjCForCollectionStmtClass = 187,
    ReturnStmtClass = 188,
    SEHExceptStmtClass = 189,
    SEHFinallyStmtClass = 190,
    SEHLeaveStmtClass = 191,
    SEHTryStmtClass = 192,
    CaseStmtClass = 193,
    DefaultStmtClass = 194,
    SwitchStmtClass = 195,
    WhileStmtClass = 196,
};

pub const ZigClangCK = extern enum {
    Dependent,
    BitCast,
    LValueBitCast,
    LValueToRValue,
    NoOp,
    BaseToDerived,
    DerivedToBase,
    UncheckedDerivedToBase,
    Dynamic,
    ToUnion,
    ArrayToPointerDecay,
    FunctionToPointerDecay,
    NullToPointer,
    NullToMemberPointer,
    BaseToDerivedMemberPointer,
    DerivedToBaseMemberPointer,
    MemberPointerToBoolean,
    ReinterpretMemberPointer,
    UserDefinedConversion,
    ConstructorConversion,
    IntegralToPointer,
    PointerToIntegral,
    PointerToBoolean,
    ToVoid,
    VectorSplat,
    IntegralCast,
    IntegralToBoolean,
    IntegralToFloating,
    FixedPointCast,
    FixedPointToBoolean,
    FloatingToIntegral,
    FloatingToBoolean,
    BooleanToSignedIntegral,
    FloatingCast,
    CPointerToObjCPointerCast,
    BlockPointerToObjCPointerCast,
    AnyPointerToBlockPointerCast,
    ObjCObjectLValueCast,
    FloatingRealToComplex,
    FloatingComplexToReal,
    FloatingComplexToBoolean,
    FloatingComplexCast,
    FloatingComplexToIntegralComplex,
    IntegralRealToComplex,
    IntegralComplexToReal,
    IntegralComplexToBoolean,
    IntegralComplexCast,
    IntegralComplexToFloatingComplex,
    ARCProduceObject,
    ARCConsumeObject,
    ARCReclaimReturnedObject,
    ARCExtendBlockObject,
    AtomicToNonAtomic,
    NonAtomicToAtomic,
    CopyAndAutoreleaseBlockObject,
    BuiltinFnToFnPtr,
    ZeroToOCLOpaqueType,
    AddressSpaceConversion,
    IntToOCLSampler,
};

pub const ZigClangAPValueKind = extern enum {
    Uninitialized,
    Int,
    Float,
    ComplexInt,
    ComplexFloat,
    LValue,
    Vector,
    Array,
    Struct,
    Union,
    MemberPointer,
    AddrLabelDiff,
};

pub extern fn ZigClangSourceManager_getSpellingLoc(arg0: ?*const struct_ZigClangSourceManager, Loc: struct_ZigClangSourceLocation) struct_ZigClangSourceLocation;
pub extern fn ZigClangSourceManager_getFilename(self: *const struct_ZigClangSourceManager, SpellingLoc: struct_ZigClangSourceLocation) ?[*]const u8;
pub extern fn ZigClangSourceManager_getSpellingLineNumber(arg0: ?*const struct_ZigClangSourceManager, Loc: struct_ZigClangSourceLocation) c_uint;
pub extern fn ZigClangSourceManager_getSpellingColumnNumber(arg0: ?*const struct_ZigClangSourceManager, Loc: struct_ZigClangSourceLocation) c_uint;
pub extern fn ZigClangSourceManager_getCharacterData(arg0: ?*const struct_ZigClangSourceManager, SL: struct_ZigClangSourceLocation) [*c]const u8;
pub extern fn ZigClangASTContext_getPointerType(arg0: ?*const struct_ZigClangASTContext, T: struct_ZigClangQualType) struct_ZigClangQualType;
pub extern fn ZigClangASTUnit_getASTContext(arg0: ?*struct_ZigClangASTUnit) ?*struct_ZigClangASTContext;
pub extern fn ZigClangASTUnit_getSourceManager(self: *struct_ZigClangASTUnit) *struct_ZigClangSourceManager;
pub extern fn ZigClangASTUnit_visitLocalTopLevelDecls(self: *struct_ZigClangASTUnit, context: ?*c_void, Fn: ?extern fn (?*c_void, *const struct_ZigClangDecl) bool) bool;
pub extern fn ZigClangRecordType_getDecl(record_ty: ?*const struct_ZigClangRecordType) ?*const struct_ZigClangRecordDecl;
pub extern fn ZigClangEnumType_getDecl(record_ty: ?*const struct_ZigClangEnumType) ?*const struct_ZigClangEnumDecl;
pub extern fn ZigClangRecordDecl_getCanonicalDecl(record_decl: ?*const struct_ZigClangRecordDecl) ?*const struct_ZigClangTagDecl;
pub extern fn ZigClangEnumDecl_getCanonicalDecl(arg0: ?*const struct_ZigClangEnumDecl) ?*const struct_ZigClangTagDecl;
pub extern fn ZigClangTypedefNameDecl_getCanonicalDecl(arg0: ?*const struct_ZigClangTypedefNameDecl) ?*const struct_ZigClangTypedefNameDecl;
pub extern fn ZigClangRecordDecl_getDefinition(arg0: ?*const struct_ZigClangRecordDecl) ?*const struct_ZigClangRecordDecl;
pub extern fn ZigClangEnumDecl_getDefinition(arg0: ?*const struct_ZigClangEnumDecl) ?*const struct_ZigClangEnumDecl;
pub extern fn ZigClangRecordDecl_getLocation(arg0: ?*const struct_ZigClangRecordDecl) struct_ZigClangSourceLocation;
pub extern fn ZigClangEnumDecl_getLocation(arg0: ?*const struct_ZigClangEnumDecl) struct_ZigClangSourceLocation;
pub extern fn ZigClangTypedefNameDecl_getLocation(arg0: ?*const struct_ZigClangTypedefNameDecl) struct_ZigClangSourceLocation;
pub extern fn ZigClangDecl_getLocation(self: *const ZigClangDecl) ZigClangSourceLocation;
pub extern fn ZigClangRecordDecl_isUnion(record_decl: ?*const struct_ZigClangRecordDecl) bool;
pub extern fn ZigClangRecordDecl_isStruct(record_decl: ?*const struct_ZigClangRecordDecl) bool;
pub extern fn ZigClangRecordDecl_isAnonymousStructOrUnion(record_decl: ?*const struct_ZigClangRecordDecl) bool;
pub extern fn ZigClangEnumDecl_getIntegerType(arg0: ?*const struct_ZigClangEnumDecl) struct_ZigClangQualType;
pub extern fn ZigClangDecl_getName_bytes_begin(decl: ?*const struct_ZigClangDecl) [*c]const u8;
pub extern fn ZigClangSourceLocation_eq(a: struct_ZigClangSourceLocation, b: struct_ZigClangSourceLocation) bool;
pub extern fn ZigClangTypedefType_getDecl(arg0: ?*const struct_ZigClangTypedefType) ?*const struct_ZigClangTypedefNameDecl;
pub extern fn ZigClangTypedefNameDecl_getUnderlyingType(arg0: ?*const struct_ZigClangTypedefNameDecl) struct_ZigClangQualType;
pub extern fn ZigClangQualType_getCanonicalType(arg0: struct_ZigClangQualType) struct_ZigClangQualType;
pub extern fn ZigClangQualType_getTypePtr(self: struct_ZigClangQualType) *const struct_ZigClangType;
pub extern fn ZigClangQualType_addConst(arg0: [*c]struct_ZigClangQualType) void;
pub extern fn ZigClangQualType_eq(arg0: struct_ZigClangQualType, arg1: struct_ZigClangQualType) bool;
pub extern fn ZigClangQualType_isConstQualified(arg0: struct_ZigClangQualType) bool;
pub extern fn ZigClangQualType_isVolatileQualified(arg0: struct_ZigClangQualType) bool;
pub extern fn ZigClangQualType_isRestrictQualified(arg0: struct_ZigClangQualType) bool;
pub extern fn ZigClangType_getTypeClass(self: ?*const struct_ZigClangType) ZigClangTypeClass;
pub extern fn ZigClangType_isVoidType(self: ?*const struct_ZigClangType) bool;
pub extern fn ZigClangType_getTypeClassName(self: *const struct_ZigClangType) [*]const u8;
pub extern fn ZigClangStmt_getBeginLoc(self: ?*const struct_ZigClangStmt) struct_ZigClangSourceLocation;
pub extern fn ZigClangStmt_getStmtClass(self: ?*const struct_ZigClangStmt) ZigClangStmtClass;
pub extern fn ZigClangStmt_classof_Expr(self: ?*const struct_ZigClangStmt) bool;
pub extern fn ZigClangExpr_getStmtClass(self: ?*const struct_ZigClangExpr) ZigClangStmtClass;
pub extern fn ZigClangExpr_getType(self: ?*const struct_ZigClangExpr) struct_ZigClangQualType;
pub extern fn ZigClangExpr_getBeginLoc(self: ?*const struct_ZigClangExpr) struct_ZigClangSourceLocation;
pub extern fn ZigClangAPValue_getKind(self: ?*const struct_ZigClangAPValue) ZigClangAPValueKind;
pub extern fn ZigClangAPValue_getInt(self: ?*const struct_ZigClangAPValue) ?*const struct_ZigClangAPSInt;
pub extern fn ZigClangAPValue_getArrayInitializedElts(self: ?*const struct_ZigClangAPValue) c_uint;
pub extern fn ZigClangAPValue_getArrayInitializedElt(self: ?*const struct_ZigClangAPValue, i: c_uint) ?*const struct_ZigClangAPValue;
pub extern fn ZigClangAPValue_getArrayFiller(self: ?*const struct_ZigClangAPValue) ?*const struct_ZigClangAPValue;
pub extern fn ZigClangAPValue_getArraySize(self: ?*const struct_ZigClangAPValue) c_uint;
pub extern fn ZigClangAPValue_getLValueBase(self: ?*const struct_ZigClangAPValue) struct_ZigClangAPValueLValueBase;
pub extern fn ZigClangAPSInt_isSigned(self: ?*const struct_ZigClangAPSInt) bool;
pub extern fn ZigClangAPSInt_isNegative(self: ?*const struct_ZigClangAPSInt) bool;
pub extern fn ZigClangAPSInt_negate(self: ?*const struct_ZigClangAPSInt) ?*const struct_ZigClangAPSInt;
pub extern fn ZigClangAPSInt_free(self: ?*const struct_ZigClangAPSInt) void;
pub extern fn ZigClangAPSInt_getRawData(self: ?*const struct_ZigClangAPSInt) [*c]const u64;
pub extern fn ZigClangAPSInt_getNumWords(self: ?*const struct_ZigClangAPSInt) c_uint;
pub extern fn ZigClangAPValueLValueBase_dyn_cast_Expr(self: struct_ZigClangAPValueLValueBase) ?*const struct_ZigClangExpr;
pub extern fn ZigClangASTUnit_delete(arg0: ?*struct_ZigClangASTUnit) void;

pub extern fn ZigClangFunctionDecl_getType(self: *const struct_ZigClangFunctionDecl) struct_ZigClangQualType;
pub extern fn ZigClangFunctionDecl_getLocation(self: *const struct_ZigClangFunctionDecl) struct_ZigClangSourceLocation;
pub extern fn ZigClangBuiltinType_getKind(self: *const struct_ZigClangBuiltinType) ZigClangBuiltinTypeKind;

pub extern fn ZigClangFunctionType_getNoReturnAttr(self: *const ZigClangFunctionType) bool;
pub extern fn ZigClangFunctionType_getCallConv(self: *const ZigClangFunctionType) ZigClangCallingConv;
pub extern fn ZigClangFunctionType_getReturnType(self: *const ZigClangFunctionType) ZigClangQualType;

pub extern fn ZigClangFunctionProtoType_isVariadic(self: *const struct_ZigClangFunctionProtoType) bool;
pub extern fn ZigClangFunctionProtoType_getNumParams(self: *const struct_ZigClangFunctionProtoType) c_uint;
pub extern fn ZigClangFunctionProtoType_getParamType(self: *const struct_ZigClangFunctionProtoType, i: c_uint) ZigClangQualType;

pub const ZigClangSourceLocation = struct_ZigClangSourceLocation;
pub const ZigClangQualType = struct_ZigClangQualType;
pub const ZigClangAPValueLValueBase = struct_ZigClangAPValueLValueBase;
pub const ZigClangAPValue = struct_ZigClangAPValue;
pub const ZigClangAPSInt = struct_ZigClangAPSInt;
pub const ZigClangASTContext = struct_ZigClangASTContext;
pub const ZigClangASTUnit = struct_ZigClangASTUnit;
pub const ZigClangArraySubscriptExpr = struct_ZigClangArraySubscriptExpr;
pub const ZigClangArrayType = struct_ZigClangArrayType;
pub const ZigClangAttributedType = struct_ZigClangAttributedType;
pub const ZigClangBinaryOperator = struct_ZigClangBinaryOperator;
pub const ZigClangBreakStmt = struct_ZigClangBreakStmt;
pub const ZigClangBuiltinType = struct_ZigClangBuiltinType;
pub const ZigClangCStyleCastExpr = struct_ZigClangCStyleCastExpr;
pub const ZigClangCallExpr = struct_ZigClangCallExpr;
pub const ZigClangCaseStmt = struct_ZigClangCaseStmt;
pub const ZigClangCompoundAssignOperator = struct_ZigClangCompoundAssignOperator;
pub const ZigClangCompoundStmt = struct_ZigClangCompoundStmt;
pub const ZigClangConditionalOperator = struct_ZigClangConditionalOperator;
pub const ZigClangConstantArrayType = struct_ZigClangConstantArrayType;
pub const ZigClangContinueStmt = struct_ZigClangContinueStmt;
pub const ZigClangDecayedType = struct_ZigClangDecayedType;
pub const ZigClangDecl = struct_ZigClangDecl;
pub const ZigClangDeclRefExpr = struct_ZigClangDeclRefExpr;
pub const ZigClangDeclStmt = struct_ZigClangDeclStmt;
pub const ZigClangDefaultStmt = struct_ZigClangDefaultStmt;
pub const ZigClangDiagnosticOptions = struct_ZigClangDiagnosticOptions;
pub const ZigClangDiagnosticsEngine = struct_ZigClangDiagnosticsEngine;
pub const ZigClangDoStmt = struct_ZigClangDoStmt;
pub const ZigClangElaboratedType = struct_ZigClangElaboratedType;
pub const ZigClangEnumConstantDecl = struct_ZigClangEnumConstantDecl;
pub const ZigClangEnumDecl = struct_ZigClangEnumDecl;
pub const ZigClangEnumType = struct_ZigClangEnumType;
pub const ZigClangExpr = struct_ZigClangExpr;
pub const ZigClangFieldDecl = struct_ZigClangFieldDecl;
pub const ZigClangFileID = struct_ZigClangFileID;
pub const ZigClangForStmt = struct_ZigClangForStmt;
pub const ZigClangFullSourceLoc = struct_ZigClangFullSourceLoc;
pub const ZigClangFunctionDecl = struct_ZigClangFunctionDecl;
pub const ZigClangFunctionProtoType = struct_ZigClangFunctionProtoType;
pub const ZigClangIfStmt = struct_ZigClangIfStmt;
pub const ZigClangImplicitCastExpr = struct_ZigClangImplicitCastExpr;
pub const ZigClangIncompleteArrayType = struct_ZigClangIncompleteArrayType;
pub const ZigClangIntegerLiteral = struct_ZigClangIntegerLiteral;
pub const ZigClangMacroDefinitionRecord = struct_ZigClangMacroDefinitionRecord;
pub const ZigClangMemberExpr = struct_ZigClangMemberExpr;
pub const ZigClangNamedDecl = struct_ZigClangNamedDecl;
pub const ZigClangNone = struct_ZigClangNone;
pub const ZigClangPCHContainerOperations = struct_ZigClangPCHContainerOperations;
pub const ZigClangParenExpr = struct_ZigClangParenExpr;
pub const ZigClangParenType = struct_ZigClangParenType;
pub const ZigClangParmVarDecl = struct_ZigClangParmVarDecl;
pub const ZigClangPointerType = struct_ZigClangPointerType;
pub const ZigClangPreprocessedEntity = struct_ZigClangPreprocessedEntity;
pub const ZigClangRecordDecl = struct_ZigClangRecordDecl;
pub const ZigClangRecordType = struct_ZigClangRecordType;
pub const ZigClangReturnStmt = struct_ZigClangReturnStmt;
pub const ZigClangSkipFunctionBodiesScope = struct_ZigClangSkipFunctionBodiesScope;
pub const ZigClangSourceManager = struct_ZigClangSourceManager;
pub const ZigClangSourceRange = struct_ZigClangSourceRange;
pub const ZigClangStmt = struct_ZigClangStmt;
pub const ZigClangStorageClass = struct_ZigClangStorageClass;
pub const ZigClangStringLiteral = struct_ZigClangStringLiteral;
pub const ZigClangStringRef = struct_ZigClangStringRef;
pub const ZigClangSwitchStmt = struct_ZigClangSwitchStmt;
pub const ZigClangTagDecl = struct_ZigClangTagDecl;
pub const ZigClangType = struct_ZigClangType;
pub const ZigClangTypedefNameDecl = struct_ZigClangTypedefNameDecl;
pub const ZigClangTypedefType = struct_ZigClangTypedefType;
pub const ZigClangUnaryExprOrTypeTraitExpr = struct_ZigClangUnaryExprOrTypeTraitExpr;
pub const ZigClangUnaryOperator = struct_ZigClangUnaryOperator;
pub const ZigClangValueDecl = struct_ZigClangValueDecl;
pub const ZigClangVarDecl = struct_ZigClangVarDecl;
pub const ZigClangWhileStmt = struct_ZigClangWhileStmt;

pub const struct_ZigClangSourceLocation = extern struct {
    ID: c_uint,
};

pub const Stage2ErrorMsg = extern struct {
    filename_ptr: ?[*]const u8,
    filename_len: usize,
    msg_ptr: [*]const u8,
    msg_len: usize,
    // valid until the ASTUnit is freed
    source: ?[*]const u8,
    // 0 based
    line: c_uint,
    // 0 based
    column: c_uint,
    // byte offset into source
    offset: c_uint,
};
pub extern fn ZigClangErrorMsg_delete(ptr: [*c]Stage2ErrorMsg, len: usize) void;

pub extern fn ZigClangLoadFromCommandLine(
    args_begin: [*]?[*]const u8,
    args_end: [*]?[*]const u8,
    errors_ptr: *[*]Stage2ErrorMsg,
    errors_len: *usize,
    resources_path: [*c]const u8,
) ?*ZigClangASTUnit;

pub extern fn ZigClangDecl_getKind(decl: *const ZigClangDecl) ZigClangDeclKind;
pub extern fn ZigClangDecl_getDeclKindName(decl: *const struct_ZigClangDecl) [*]const u8;

pub const ZigClangDeclKind = extern enum {
    AccessSpec,
    Block,
    Captured,
    ClassScopeFunctionSpecialization,
    Empty,
    Export,
    ExternCContext,
    FileScopeAsm,
    Friend,
    FriendTemplate,
    Import,
    LinkageSpec,
    Label,
    Namespace,
    NamespaceAlias,
    ObjCCompatibleAlias,
    ObjCCategory,
    ObjCCategoryImpl,
    ObjCImplementation,
    ObjCInterface,
    ObjCProtocol,
    ObjCMethod,
    ObjCProperty,
    BuiltinTemplate,
    ClassTemplate,
    FunctionTemplate,
    TypeAliasTemplate,
    VarTemplate,
    TemplateTemplateParm,
    Enum,
    Record,
    CXXRecord,
    ClassTemplateSpecialization,
    ClassTemplatePartialSpecialization,
    TemplateTypeParm,
    ObjCTypeParam,
    TypeAlias,
    Typedef,
    UnresolvedUsingTypename,
    Using,
    UsingDirective,
    UsingPack,
    UsingShadow,
    ConstructorUsingShadow,
    Binding,
    Field,
    ObjCAtDefsField,
    ObjCIvar,
    Function,
    CXXDeductionGuide,
    CXXMethod,
    CXXConstructor,
    CXXConversion,
    CXXDestructor,
    MSProperty,
    NonTypeTemplateParm,
    Var,
    Decomposition,
    ImplicitParam,
    OMPCapturedExpr,
    ParmVar,
    VarTemplateSpecialization,
    VarTemplatePartialSpecialization,
    EnumConstant,
    IndirectField,
    OMPDeclareReduction,
    UnresolvedUsingValue,
    OMPRequires,
    OMPThreadPrivate,
    ObjCPropertyImpl,
    PragmaComment,
    PragmaDetectMismatch,
    StaticAssert,
    TranslationUnit,
};

pub const struct_ZigClangQualType = extern struct {
    ptr: ?*c_void,
};

pub const ZigClangBuiltinTypeKind = extern enum {
    OCLImage1dRO,
    OCLImage1dArrayRO,
    OCLImage1dBufferRO,
    OCLImage2dRO,
    OCLImage2dArrayRO,
    OCLImage2dDepthRO,
    OCLImage2dArrayDepthRO,
    OCLImage2dMSAARO,
    OCLImage2dArrayMSAARO,
    OCLImage2dMSAADepthRO,
    OCLImage2dArrayMSAADepthRO,
    OCLImage3dRO,
    OCLImage1dWO,
    OCLImage1dArrayWO,
    OCLImage1dBufferWO,
    OCLImage2dWO,
    OCLImage2dArrayWO,
    OCLImage2dDepthWO,
    OCLImage2dArrayDepthWO,
    OCLImage2dMSAAWO,
    OCLImage2dArrayMSAAWO,
    OCLImage2dMSAADepthWO,
    OCLImage2dArrayMSAADepthWO,
    OCLImage3dWO,
    OCLImage1dRW,
    OCLImage1dArrayRW,
    OCLImage1dBufferRW,
    OCLImage2dRW,
    OCLImage2dArrayRW,
    OCLImage2dDepthRW,
    OCLImage2dArrayDepthRW,
    OCLImage2dMSAARW,
    OCLImage2dArrayMSAARW,
    OCLImage2dMSAADepthRW,
    OCLImage2dArrayMSAADepthRW,
    OCLImage3dRW,
    OCLIntelSubgroupAVCMcePayload,
    OCLIntelSubgroupAVCImePayload,
    OCLIntelSubgroupAVCRefPayload,
    OCLIntelSubgroupAVCSicPayload,
    OCLIntelSubgroupAVCMceResult,
    OCLIntelSubgroupAVCImeResult,
    OCLIntelSubgroupAVCRefResult,
    OCLIntelSubgroupAVCSicResult,
    OCLIntelSubgroupAVCImeResultSingleRefStreamout,
    OCLIntelSubgroupAVCImeResultDualRefStreamout,
    OCLIntelSubgroupAVCImeSingleRefStreamin,
    OCLIntelSubgroupAVCImeDualRefStreamin,
    Void,
    Bool,
    Char_U,
    UChar,
    WChar_U,
    Char8,
    Char16,
    Char32,
    UShort,
    UInt,
    ULong,
    ULongLong,
    UInt128,
    Char_S,
    SChar,
    WChar_S,
    Short,
    Int,
    Long,
    LongLong,
    Int128,
    ShortAccum,
    Accum,
    LongAccum,
    UShortAccum,
    UAccum,
    ULongAccum,
    ShortFract,
    Fract,
    LongFract,
    UShortFract,
    UFract,
    ULongFract,
    SatShortAccum,
    SatAccum,
    SatLongAccum,
    SatUShortAccum,
    SatUAccum,
    SatULongAccum,
    SatShortFract,
    SatFract,
    SatLongFract,
    SatUShortFract,
    SatUFract,
    SatULongFract,
    Half,
    Float,
    Double,
    LongDouble,
    Float16,
    Float128,
    NullPtr,
    ObjCId,
    ObjCClass,
    ObjCSel,
    OCLSampler,
    OCLEvent,
    OCLClkEvent,
    OCLQueue,
    OCLReserveID,
    Dependent,
    Overload,
    BoundMember,
    PseudoObject,
    UnknownAny,
    BuiltinFn,
    ARCUnbridgedCast,
    OMPArraySection,
};

pub const ZigClangCallingConv = extern enum {
    C,
    X86StdCall,
    X86FastCall,
    X86ThisCall,
    X86VectorCall,
    X86Pascal,
    Win64,
    X86_64SysV,
    X86RegCall,
    AAPCS,
    AAPCS_VFP,
    IntelOclBicc,
    SpirFunction,
    OpenCLKernel,
    Swift,
    PreserveMost,
    PreserveAll,
    AArch64VectorCall,
};
