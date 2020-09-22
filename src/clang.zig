const builtin = @import("builtin");

pub const struct_ZigClangConditionalOperator = @Type(.Opaque);
pub const struct_ZigClangBinaryConditionalOperator = @Type(.Opaque);
pub const struct_ZigClangAbstractConditionalOperator = @Type(.Opaque);
pub const struct_ZigClangAPInt = @Type(.Opaque);
pub const struct_ZigClangAPSInt = @Type(.Opaque);
pub const struct_ZigClangAPFloat = @Type(.Opaque);
pub const struct_ZigClangASTContext = @Type(.Opaque);
pub const struct_ZigClangASTUnit = @Type(.Opaque);
pub const struct_ZigClangArraySubscriptExpr = @Type(.Opaque);
pub const struct_ZigClangArrayType = @Type(.Opaque);
pub const struct_ZigClangAttributedType = @Type(.Opaque);
pub const struct_ZigClangBinaryOperator = @Type(.Opaque);
pub const struct_ZigClangBreakStmt = @Type(.Opaque);
pub const struct_ZigClangBuiltinType = @Type(.Opaque);
pub const struct_ZigClangCStyleCastExpr = @Type(.Opaque);
pub const struct_ZigClangCallExpr = @Type(.Opaque);
pub const struct_ZigClangCaseStmt = @Type(.Opaque);
pub const struct_ZigClangCompoundAssignOperator = @Type(.Opaque);
pub const struct_ZigClangCompoundStmt = @Type(.Opaque);
pub const struct_ZigClangConstantArrayType = @Type(.Opaque);
pub const struct_ZigClangContinueStmt = @Type(.Opaque);
pub const struct_ZigClangDecayedType = @Type(.Opaque);
pub const ZigClangDecl = @Type(.Opaque);
pub const struct_ZigClangDeclRefExpr = @Type(.Opaque);
pub const struct_ZigClangDeclStmt = @Type(.Opaque);
pub const struct_ZigClangDefaultStmt = @Type(.Opaque);
pub const struct_ZigClangDiagnosticOptions = @Type(.Opaque);
pub const struct_ZigClangDiagnosticsEngine = @Type(.Opaque);
pub const struct_ZigClangDoStmt = @Type(.Opaque);
pub const struct_ZigClangElaboratedType = @Type(.Opaque);
pub const struct_ZigClangEnumConstantDecl = @Type(.Opaque);
pub const struct_ZigClangEnumDecl = @Type(.Opaque);
pub const struct_ZigClangEnumType = @Type(.Opaque);
pub const struct_ZigClangExpr = @Type(.Opaque);
pub const struct_ZigClangFieldDecl = @Type(.Opaque);
pub const struct_ZigClangFileID = @Type(.Opaque);
pub const struct_ZigClangForStmt = @Type(.Opaque);
pub const struct_ZigClangFullSourceLoc = @Type(.Opaque);
pub const struct_ZigClangFunctionDecl = @Type(.Opaque);
pub const struct_ZigClangFunctionProtoType = @Type(.Opaque);
pub const struct_ZigClangIfStmt = @Type(.Opaque);
pub const struct_ZigClangImplicitCastExpr = @Type(.Opaque);
pub const struct_ZigClangIncompleteArrayType = @Type(.Opaque);
pub const struct_ZigClangIntegerLiteral = @Type(.Opaque);
pub const struct_ZigClangMacroDefinitionRecord = @Type(.Opaque);
pub const struct_ZigClangMacroExpansion = @Type(.Opaque);
pub const struct_ZigClangMacroQualifiedType = @Type(.Opaque);
pub const struct_ZigClangMemberExpr = @Type(.Opaque);
pub const struct_ZigClangNamedDecl = @Type(.Opaque);
pub const struct_ZigClangNone = @Type(.Opaque);
pub const struct_ZigClangOpaqueValueExpr = @Type(.Opaque);
pub const struct_ZigClangPCHContainerOperations = @Type(.Opaque);
pub const struct_ZigClangParenExpr = @Type(.Opaque);
pub const struct_ZigClangParenType = @Type(.Opaque);
pub const struct_ZigClangParmVarDecl = @Type(.Opaque);
pub const struct_ZigClangPointerType = @Type(.Opaque);
pub const struct_ZigClangPreprocessedEntity = @Type(.Opaque);
pub const struct_ZigClangRecordDecl = @Type(.Opaque);
pub const struct_ZigClangRecordType = @Type(.Opaque);
pub const struct_ZigClangReturnStmt = @Type(.Opaque);
pub const struct_ZigClangSkipFunctionBodiesScope = @Type(.Opaque);
pub const struct_ZigClangSourceManager = @Type(.Opaque);
pub const struct_ZigClangSourceRange = @Type(.Opaque);
pub const ZigClangStmt = @Type(.Opaque);
pub const struct_ZigClangStringLiteral = @Type(.Opaque);
pub const struct_ZigClangStringRef = @Type(.Opaque);
pub const struct_ZigClangSwitchStmt = @Type(.Opaque);
pub const struct_ZigClangTagDecl = @Type(.Opaque);
pub const struct_ZigClangType = @Type(.Opaque);
pub const struct_ZigClangTypedefNameDecl = @Type(.Opaque);
pub const struct_ZigClangTypedefType = @Type(.Opaque);
pub const struct_ZigClangUnaryExprOrTypeTraitExpr = @Type(.Opaque);
pub const struct_ZigClangUnaryOperator = @Type(.Opaque);
pub const struct_ZigClangValueDecl = @Type(.Opaque);
pub const struct_ZigClangVarDecl = @Type(.Opaque);
pub const struct_ZigClangWhileStmt = @Type(.Opaque);
pub const struct_ZigClangFunctionType = @Type(.Opaque);
pub const struct_ZigClangPredefinedExpr = @Type(.Opaque);
pub const struct_ZigClangInitListExpr = @Type(.Opaque);
pub const ZigClangPreprocessingRecord = @Type(.Opaque);
pub const ZigClangFloatingLiteral = @Type(.Opaque);
pub const ZigClangConstantExpr = @Type(.Opaque);
pub const ZigClangCharacterLiteral = @Type(.Opaque);
pub const ZigClangStmtExpr = @Type(.Opaque);

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
    Adjusted,
    Decayed,
    ConstantArray,
    DependentSizedArray,
    IncompleteArray,
    VariableArray,
    Atomic,
    Attributed,
    BlockPointer,
    Builtin,
    Complex,
    Decltype,
    Auto,
    DeducedTemplateSpecialization,
    DependentAddressSpace,
    DependentName,
    DependentSizedExtVector,
    DependentTemplateSpecialization,
    DependentVector,
    Elaborated,
    FunctionNoProto,
    FunctionProto,
    InjectedClassName,
    MacroQualified,
    MemberPointer,
    ObjCObjectPointer,
    ObjCObject,
    ObjCInterface,
    ObjCTypeParam,
    PackExpansion,
    Paren,
    Pipe,
    Pointer,
    LValueReference,
    RValueReference,
    SubstTemplateTypeParmPack,
    SubstTemplateTypeParm,
    Enum,
    Record,
    TemplateSpecialization,
    TemplateTypeParm,
    TypeOfExpr,
    TypeOf,
    Typedef,
    UnaryTransform,
    UnresolvedUsing,
    Vector,
    ExtVector,
};

const ZigClangStmtClass = extern enum {
    NoStmtClass,
    GCCAsmStmtClass,
    MSAsmStmtClass,
    BreakStmtClass,
    CXXCatchStmtClass,
    CXXForRangeStmtClass,
    CXXTryStmtClass,
    CapturedStmtClass,
    CompoundStmtClass,
    ContinueStmtClass,
    CoreturnStmtClass,
    CoroutineBodyStmtClass,
    DeclStmtClass,
    DoStmtClass,
    ForStmtClass,
    GotoStmtClass,
    IfStmtClass,
    IndirectGotoStmtClass,
    MSDependentExistsStmtClass,
    NullStmtClass,
    OMPAtomicDirectiveClass,
    OMPBarrierDirectiveClass,
    OMPCancelDirectiveClass,
    OMPCancellationPointDirectiveClass,
    OMPCriticalDirectiveClass,
    OMPFlushDirectiveClass,
    OMPDistributeDirectiveClass,
    OMPDistributeParallelForDirectiveClass,
    OMPDistributeParallelForSimdDirectiveClass,
    OMPDistributeSimdDirectiveClass,
    OMPForDirectiveClass,
    OMPForSimdDirectiveClass,
    OMPMasterTaskLoopDirectiveClass,
    OMPMasterTaskLoopSimdDirectiveClass,
    OMPParallelForDirectiveClass,
    OMPParallelForSimdDirectiveClass,
    OMPParallelMasterTaskLoopDirectiveClass,
    OMPParallelMasterTaskLoopSimdDirectiveClass,
    OMPSimdDirectiveClass,
    OMPTargetParallelForSimdDirectiveClass,
    OMPTargetSimdDirectiveClass,
    OMPTargetTeamsDistributeDirectiveClass,
    OMPTargetTeamsDistributeParallelForDirectiveClass,
    OMPTargetTeamsDistributeParallelForSimdDirectiveClass,
    OMPTargetTeamsDistributeSimdDirectiveClass,
    OMPTaskLoopDirectiveClass,
    OMPTaskLoopSimdDirectiveClass,
    OMPTeamsDistributeDirectiveClass,
    OMPTeamsDistributeParallelForDirectiveClass,
    OMPTeamsDistributeParallelForSimdDirectiveClass,
    OMPTeamsDistributeSimdDirectiveClass,
    OMPMasterDirectiveClass,
    OMPOrderedDirectiveClass,
    OMPParallelDirectiveClass,
    OMPParallelMasterDirectiveClass,
    OMPParallelSectionsDirectiveClass,
    OMPSectionDirectiveClass,
    OMPSectionsDirectiveClass,
    OMPSingleDirectiveClass,
    OMPTargetDataDirectiveClass,
    OMPTargetDirectiveClass,
    OMPTargetEnterDataDirectiveClass,
    OMPTargetExitDataDirectiveClass,
    OMPTargetParallelDirectiveClass,
    OMPTargetParallelForDirectiveClass,
    OMPTargetTeamsDirectiveClass,
    OMPTargetUpdateDirectiveClass,
    OMPTaskDirectiveClass,
    OMPTaskgroupDirectiveClass,
    OMPTaskwaitDirectiveClass,
    OMPTaskyieldDirectiveClass,
    OMPTeamsDirectiveClass,
    ObjCAtCatchStmtClass,
    ObjCAtFinallyStmtClass,
    ObjCAtSynchronizedStmtClass,
    ObjCAtThrowStmtClass,
    ObjCAtTryStmtClass,
    ObjCAutoreleasePoolStmtClass,
    ObjCForCollectionStmtClass,
    ReturnStmtClass,
    SEHExceptStmtClass,
    SEHFinallyStmtClass,
    SEHLeaveStmtClass,
    SEHTryStmtClass,
    CaseStmtClass,
    DefaultStmtClass,
    SwitchStmtClass,
    AttributedStmtClass,
    BinaryConditionalOperatorClass,
    ConditionalOperatorClass,
    AddrLabelExprClass,
    ArrayInitIndexExprClass,
    ArrayInitLoopExprClass,
    ArraySubscriptExprClass,
    ArrayTypeTraitExprClass,
    AsTypeExprClass,
    AtomicExprClass,
    BinaryOperatorClass,
    CompoundAssignOperatorClass,
    BlockExprClass,
    CXXBindTemporaryExprClass,
    CXXBoolLiteralExprClass,
    CXXConstructExprClass,
    CXXTemporaryObjectExprClass,
    CXXDefaultArgExprClass,
    CXXDefaultInitExprClass,
    CXXDeleteExprClass,
    CXXDependentScopeMemberExprClass,
    CXXFoldExprClass,
    CXXInheritedCtorInitExprClass,
    CXXNewExprClass,
    CXXNoexceptExprClass,
    CXXNullPtrLiteralExprClass,
    CXXPseudoDestructorExprClass,
    CXXRewrittenBinaryOperatorClass,
    CXXScalarValueInitExprClass,
    CXXStdInitializerListExprClass,
    CXXThisExprClass,
    CXXThrowExprClass,
    CXXTypeidExprClass,
    CXXUnresolvedConstructExprClass,
    CXXUuidofExprClass,
    CallExprClass,
    CUDAKernelCallExprClass,
    CXXMemberCallExprClass,
    CXXOperatorCallExprClass,
    UserDefinedLiteralClass,
    BuiltinBitCastExprClass,
    CStyleCastExprClass,
    CXXFunctionalCastExprClass,
    CXXConstCastExprClass,
    CXXDynamicCastExprClass,
    CXXReinterpretCastExprClass,
    CXXStaticCastExprClass,
    ObjCBridgedCastExprClass,
    ImplicitCastExprClass,
    CharacterLiteralClass,
    ChooseExprClass,
    CompoundLiteralExprClass,
    ConceptSpecializationExprClass,
    ConvertVectorExprClass,
    CoawaitExprClass,
    CoyieldExprClass,
    DeclRefExprClass,
    DependentCoawaitExprClass,
    DependentScopeDeclRefExprClass,
    DesignatedInitExprClass,
    DesignatedInitUpdateExprClass,
    ExpressionTraitExprClass,
    ExtVectorElementExprClass,
    FixedPointLiteralClass,
    FloatingLiteralClass,
    ConstantExprClass,
    ExprWithCleanupsClass,
    FunctionParmPackExprClass,
    GNUNullExprClass,
    GenericSelectionExprClass,
    ImaginaryLiteralClass,
    ImplicitValueInitExprClass,
    InitListExprClass,
    IntegerLiteralClass,
    LambdaExprClass,
    MSPropertyRefExprClass,
    MSPropertySubscriptExprClass,
    MaterializeTemporaryExprClass,
    MemberExprClass,
    NoInitExprClass,
    OMPArraySectionExprClass,
    ObjCArrayLiteralClass,
    ObjCAvailabilityCheckExprClass,
    ObjCBoolLiteralExprClass,
    ObjCBoxedExprClass,
    ObjCDictionaryLiteralClass,
    ObjCEncodeExprClass,
    ObjCIndirectCopyRestoreExprClass,
    ObjCIsaExprClass,
    ObjCIvarRefExprClass,
    ObjCMessageExprClass,
    ObjCPropertyRefExprClass,
    ObjCProtocolExprClass,
    ObjCSelectorExprClass,
    ObjCStringLiteralClass,
    ObjCSubscriptRefExprClass,
    OffsetOfExprClass,
    OpaqueValueExprClass,
    UnresolvedLookupExprClass,
    UnresolvedMemberExprClass,
    PackExpansionExprClass,
    ParenExprClass,
    ParenListExprClass,
    PredefinedExprClass,
    PseudoObjectExprClass,
    RequiresExprClass,
    ShuffleVectorExprClass,
    SizeOfPackExprClass,
    SourceLocExprClass,
    StmtExprClass,
    StringLiteralClass,
    SubstNonTypeTemplateParmExprClass,
    SubstNonTypeTemplateParmPackExprClass,
    TypeTraitExprClass,
    TypoExprClass,
    UnaryExprOrTypeTraitExprClass,
    UnaryOperatorClass,
    VAArgExprClass,
    LabelStmtClass,
    WhileStmtClass,
};

pub const ZigClangCK = extern enum {
    Dependent,
    BitCast,
    LValueBitCast,
    LValueToRValueBitCast,
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
    FixedPointToIntegral,
    IntegralToFixedPoint,
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
    None,
    Indeterminate,
    Int,
    Float,
    FixedPoint,
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
    LifetimeExtendedTemporary,
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
    Concept,
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
    OMPDeclareMapper,
    OMPDeclareReduction,
    UnresolvedUsingValue,
    OMPAllocate,
    OMPRequires,
    OMPThreadPrivate,
    ObjCPropertyImpl,
    PragmaComment,
    PragmaDetectMismatch,
    RequiresExprBody,
    StaticAssert,
    TranslationUnit,
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
    SveInt8,
    SveInt16,
    SveInt32,
    SveInt64,
    SveUint8,
    SveUint16,
    SveUint32,
    SveUint64,
    SveFloat16,
    SveFloat32,
    SveFloat64,
    SveBool,
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

pub const ZigClangStorageClass = extern enum {
    None,
    Extern,
    Static,
    PrivateExtern,
    Auto,
    Register,
};

pub const ZigClangAPFloat_roundingMode = extern enum {
    NearestTiesToEven,
    TowardPositive,
    TowardNegative,
    TowardZero,
    NearestTiesToAway,
};

pub const ZigClangStringLiteral_StringKind = extern enum {
    Ascii,
    Wide,
    UTF8,
    UTF16,
    UTF32,
};

pub const ZigClangCharacterLiteral_CharacterKind = extern enum {
    Ascii,
    Wide,
    UTF8,
    UTF16,
    UTF32,
};

pub const ZigClangRecordDecl_field_iterator = extern struct {
    opaque: *c_void,
};

pub const ZigClangEnumDecl_enumerator_iterator = extern struct {
    opaque: *c_void,
};

pub const ZigClangPreprocessingRecord_iterator = extern struct {
    I: c_int,
    Self: *ZigClangPreprocessingRecord,
};

pub const ZigClangPreprocessedEntity_EntityKind = extern enum {
    InvalidKind,
    MacroExpansionKind,
    MacroDefinitionKind,
    InclusionDirectiveKind,
};

pub const ZigClangExpr_ConstExprUsage = extern enum {
    EvaluateForCodeGen,
    EvaluateForMangling,
};

pub const ZigClangUnaryExprOrTypeTrait_Kind = extern enum {
    SizeOf,
    AlignOf,
    VecStep,
    OpenMPRequiredSimdAlign,
    PreferredAlignOf,
};

pub extern fn ZigClangSourceManager_getSpellingLoc(self: ?*const struct_ZigClangSourceManager, Loc: struct_ZigClangSourceLocation) struct_ZigClangSourceLocation;
pub extern fn ZigClangSourceManager_getFilename(self: *const struct_ZigClangSourceManager, SpellingLoc: struct_ZigClangSourceLocation) ?[*:0]const u8;
pub extern fn ZigClangSourceManager_getSpellingLineNumber(self: ?*const struct_ZigClangSourceManager, Loc: struct_ZigClangSourceLocation) c_uint;
pub extern fn ZigClangSourceManager_getSpellingColumnNumber(self: ?*const struct_ZigClangSourceManager, Loc: struct_ZigClangSourceLocation) c_uint;
pub extern fn ZigClangSourceManager_getCharacterData(self: ?*const struct_ZigClangSourceManager, SL: struct_ZigClangSourceLocation) [*:0]const u8;
pub extern fn ZigClangASTContext_getPointerType(self: ?*const struct_ZigClangASTContext, T: struct_ZigClangQualType) struct_ZigClangQualType;
pub extern fn ZigClangASTUnit_getASTContext(self: ?*struct_ZigClangASTUnit) ?*struct_ZigClangASTContext;
pub extern fn ZigClangASTUnit_getSourceManager(self: *struct_ZigClangASTUnit) *struct_ZigClangSourceManager;
pub extern fn ZigClangASTUnit_visitLocalTopLevelDecls(self: *struct_ZigClangASTUnit, context: ?*c_void, Fn: ?fn (?*c_void, *const ZigClangDecl) callconv(.C) bool) bool;
pub extern fn ZigClangRecordType_getDecl(record_ty: ?*const struct_ZigClangRecordType) *const struct_ZigClangRecordDecl;
pub extern fn ZigClangTagDecl_isThisDeclarationADefinition(self: *const ZigClangTagDecl) bool;
pub extern fn ZigClangEnumType_getDecl(record_ty: ?*const struct_ZigClangEnumType) *const struct_ZigClangEnumDecl;
pub extern fn ZigClangRecordDecl_getCanonicalDecl(record_decl: ?*const struct_ZigClangRecordDecl) ?*const struct_ZigClangTagDecl;
pub extern fn ZigClangFieldDecl_getCanonicalDecl(field_decl: ?*const struct_ZigClangFieldDecl) ?*const struct_ZigClangFieldDecl;
pub extern fn ZigClangFieldDecl_getAlignedAttribute(field_decl: ?*const struct_ZigClangFieldDecl, *const ZigClangASTContext) c_uint;
pub extern fn ZigClangEnumDecl_getCanonicalDecl(self: ?*const struct_ZigClangEnumDecl) ?*const struct_ZigClangTagDecl;
pub extern fn ZigClangTypedefNameDecl_getCanonicalDecl(self: ?*const struct_ZigClangTypedefNameDecl) ?*const struct_ZigClangTypedefNameDecl;
pub extern fn ZigClangFunctionDecl_getCanonicalDecl(self: ?*const struct_ZigClangFunctionDecl) ?*const struct_ZigClangFunctionDecl;
pub extern fn ZigClangParmVarDecl_getOriginalType(self: ?*const struct_ZigClangParmVarDecl) struct_ZigClangQualType;
pub extern fn ZigClangVarDecl_getCanonicalDecl(self: ?*const struct_ZigClangVarDecl) ?*const struct_ZigClangVarDecl;
pub extern fn ZigClangVarDecl_getSectionAttribute(self: *const ZigClangVarDecl, len: *usize) ?[*]const u8;
pub extern fn ZigClangFunctionDecl_getAlignedAttribute(self: *const ZigClangFunctionDecl, *const ZigClangASTContext) c_uint;
pub extern fn ZigClangVarDecl_getAlignedAttribute(self: *const ZigClangVarDecl, *const ZigClangASTContext) c_uint;
pub extern fn ZigClangRecordDecl_getPackedAttribute(self: ?*const struct_ZigClangRecordDecl) bool;
pub extern fn ZigClangRecordDecl_getDefinition(self: ?*const struct_ZigClangRecordDecl) ?*const struct_ZigClangRecordDecl;
pub extern fn ZigClangEnumDecl_getDefinition(self: ?*const struct_ZigClangEnumDecl) ?*const struct_ZigClangEnumDecl;
pub extern fn ZigClangRecordDecl_getLocation(self: ?*const struct_ZigClangRecordDecl) struct_ZigClangSourceLocation;
pub extern fn ZigClangEnumDecl_getLocation(self: ?*const struct_ZigClangEnumDecl) struct_ZigClangSourceLocation;
pub extern fn ZigClangTypedefNameDecl_getLocation(self: ?*const struct_ZigClangTypedefNameDecl) struct_ZigClangSourceLocation;
pub extern fn ZigClangDecl_getLocation(self: *const ZigClangDecl) ZigClangSourceLocation;
pub extern fn ZigClangRecordDecl_isUnion(record_decl: ?*const struct_ZigClangRecordDecl) bool;
pub extern fn ZigClangRecordDecl_isStruct(record_decl: ?*const struct_ZigClangRecordDecl) bool;
pub extern fn ZigClangRecordDecl_isAnonymousStructOrUnion(record_decl: ?*const struct_ZigClangRecordDecl) bool;
pub extern fn ZigClangRecordDecl_field_begin(*const struct_ZigClangRecordDecl) ZigClangRecordDecl_field_iterator;
pub extern fn ZigClangRecordDecl_field_end(*const struct_ZigClangRecordDecl) ZigClangRecordDecl_field_iterator;
pub extern fn ZigClangRecordDecl_field_iterator_next(ZigClangRecordDecl_field_iterator) ZigClangRecordDecl_field_iterator;
pub extern fn ZigClangRecordDecl_field_iterator_deref(ZigClangRecordDecl_field_iterator) *const struct_ZigClangFieldDecl;
pub extern fn ZigClangRecordDecl_field_iterator_neq(ZigClangRecordDecl_field_iterator, ZigClangRecordDecl_field_iterator) bool;
pub extern fn ZigClangEnumDecl_getIntegerType(self: ?*const struct_ZigClangEnumDecl) struct_ZigClangQualType;
pub extern fn ZigClangEnumDecl_enumerator_begin(*const ZigClangEnumDecl) ZigClangEnumDecl_enumerator_iterator;
pub extern fn ZigClangEnumDecl_enumerator_end(*const ZigClangEnumDecl) ZigClangEnumDecl_enumerator_iterator;
pub extern fn ZigClangEnumDecl_enumerator_iterator_next(ZigClangEnumDecl_enumerator_iterator) ZigClangEnumDecl_enumerator_iterator;
pub extern fn ZigClangEnumDecl_enumerator_iterator_deref(ZigClangEnumDecl_enumerator_iterator) *const ZigClangEnumConstantDecl;
pub extern fn ZigClangEnumDecl_enumerator_iterator_neq(ZigClangEnumDecl_enumerator_iterator, ZigClangEnumDecl_enumerator_iterator) bool;
pub extern fn ZigClangDecl_castToNamedDecl(decl: *const ZigClangDecl) ?*const ZigClangNamedDecl;
pub extern fn ZigClangNamedDecl_getName_bytes_begin(decl: ?*const struct_ZigClangNamedDecl) [*:0]const u8;
pub extern fn ZigClangSourceLocation_eq(a: struct_ZigClangSourceLocation, b: struct_ZigClangSourceLocation) bool;
pub extern fn ZigClangTypedefType_getDecl(self: ?*const struct_ZigClangTypedefType) *const struct_ZigClangTypedefNameDecl;
pub extern fn ZigClangTypedefNameDecl_getUnderlyingType(self: ?*const struct_ZigClangTypedefNameDecl) struct_ZigClangQualType;
pub extern fn ZigClangQualType_getCanonicalType(self: struct_ZigClangQualType) struct_ZigClangQualType;
pub extern fn ZigClangQualType_getTypeClass(self: struct_ZigClangQualType) ZigClangTypeClass;
pub extern fn ZigClangQualType_getTypePtr(self: struct_ZigClangQualType) *const struct_ZigClangType;
pub extern fn ZigClangQualType_addConst(self: *struct_ZigClangQualType) void;
pub extern fn ZigClangQualType_eq(self: struct_ZigClangQualType, arg1: struct_ZigClangQualType) bool;
pub extern fn ZigClangQualType_isConstQualified(self: struct_ZigClangQualType) bool;
pub extern fn ZigClangQualType_isVolatileQualified(self: struct_ZigClangQualType) bool;
pub extern fn ZigClangQualType_isRestrictQualified(self: struct_ZigClangQualType) bool;
pub extern fn ZigClangType_getTypeClass(self: ?*const struct_ZigClangType) ZigClangTypeClass;
pub extern fn ZigClangType_getPointeeType(self: ?*const struct_ZigClangType) struct_ZigClangQualType;
pub extern fn ZigClangType_isVoidType(self: ?*const struct_ZigClangType) bool;
pub extern fn ZigClangType_isConstantArrayType(self: ?*const struct_ZigClangType) bool;
pub extern fn ZigClangType_isRecordType(self: ?*const struct_ZigClangType) bool;
pub extern fn ZigClangType_isIncompleteOrZeroLengthArrayType(self: ?*const struct_ZigClangType, *const ZigClangASTContext) bool;
pub extern fn ZigClangType_isArrayType(self: ?*const struct_ZigClangType) bool;
pub extern fn ZigClangType_isBooleanType(self: ?*const struct_ZigClangType) bool;
pub extern fn ZigClangType_getTypeClassName(self: *const struct_ZigClangType) [*:0]const u8;
pub extern fn ZigClangType_getAsArrayTypeUnsafe(self: *const ZigClangType) *const ZigClangArrayType;
pub extern fn ZigClangType_getAsRecordType(self: *const ZigClangType) ?*const ZigClangRecordType;
pub extern fn ZigClangType_getAsUnionType(self: *const ZigClangType) ?*const ZigClangRecordType;
pub extern fn ZigClangStmt_getBeginLoc(self: *const ZigClangStmt) struct_ZigClangSourceLocation;
pub extern fn ZigClangStmt_getStmtClass(self: ?*const ZigClangStmt) ZigClangStmtClass;
pub extern fn ZigClangStmt_classof_Expr(self: ?*const ZigClangStmt) bool;
pub extern fn ZigClangExpr_getStmtClass(self: *const struct_ZigClangExpr) ZigClangStmtClass;
pub extern fn ZigClangExpr_getType(self: *const struct_ZigClangExpr) struct_ZigClangQualType;
pub extern fn ZigClangExpr_getBeginLoc(self: *const struct_ZigClangExpr) struct_ZigClangSourceLocation;
pub extern fn ZigClangInitListExpr_getInit(self: ?*const struct_ZigClangInitListExpr, i: c_uint) *const ZigClangExpr;
pub extern fn ZigClangInitListExpr_getArrayFiller(self: ?*const struct_ZigClangInitListExpr) *const ZigClangExpr;
pub extern fn ZigClangInitListExpr_getNumInits(self: ?*const struct_ZigClangInitListExpr) c_uint;
pub extern fn ZigClangInitListExpr_getInitializedFieldInUnion(self: ?*const struct_ZigClangInitListExpr) ?*ZigClangFieldDecl;
pub extern fn ZigClangAPValue_getKind(self: ?*const struct_ZigClangAPValue) ZigClangAPValueKind;
pub extern fn ZigClangAPValue_getInt(self: ?*const struct_ZigClangAPValue) *const struct_ZigClangAPSInt;
pub extern fn ZigClangAPValue_getArrayInitializedElts(self: ?*const struct_ZigClangAPValue) c_uint;
pub extern fn ZigClangAPValue_getArraySize(self: ?*const struct_ZigClangAPValue) c_uint;
pub extern fn ZigClangAPValue_getLValueBase(self: ?*const struct_ZigClangAPValue) struct_ZigClangAPValueLValueBase;
pub extern fn ZigClangAPSInt_isSigned(self: *const struct_ZigClangAPSInt) bool;
pub extern fn ZigClangAPSInt_isNegative(self: *const struct_ZigClangAPSInt) bool;
pub extern fn ZigClangAPSInt_negate(self: *const struct_ZigClangAPSInt) *const struct_ZigClangAPSInt;
pub extern fn ZigClangAPSInt_free(self: *const struct_ZigClangAPSInt) void;
pub extern fn ZigClangAPSInt_getRawData(self: *const struct_ZigClangAPSInt) [*:0]const u64;
pub extern fn ZigClangAPSInt_getNumWords(self: *const struct_ZigClangAPSInt) c_uint;

pub extern fn ZigClangAPInt_getLimitedValue(self: *const struct_ZigClangAPInt, limit: u64) u64;
pub extern fn ZigClangAPValueLValueBase_dyn_cast_Expr(self: struct_ZigClangAPValueLValueBase) ?*const struct_ZigClangExpr;
pub extern fn ZigClangASTUnit_delete(self: ?*struct_ZigClangASTUnit) void;

pub extern fn ZigClangFunctionDecl_getType(self: *const ZigClangFunctionDecl) struct_ZigClangQualType;
pub extern fn ZigClangFunctionDecl_getLocation(self: *const ZigClangFunctionDecl) struct_ZigClangSourceLocation;
pub extern fn ZigClangFunctionDecl_hasBody(self: *const ZigClangFunctionDecl) bool;
pub extern fn ZigClangFunctionDecl_getStorageClass(self: *const ZigClangFunctionDecl) ZigClangStorageClass;
pub extern fn ZigClangFunctionDecl_getParamDecl(self: *const ZigClangFunctionDecl, i: c_uint) *const struct_ZigClangParmVarDecl;
pub extern fn ZigClangFunctionDecl_getBody(self: *const ZigClangFunctionDecl) *const ZigClangStmt;
pub extern fn ZigClangFunctionDecl_doesDeclarationForceExternallyVisibleDefinition(self: *const ZigClangFunctionDecl) bool;
pub extern fn ZigClangFunctionDecl_isThisDeclarationADefinition(self: *const ZigClangFunctionDecl) bool;
pub extern fn ZigClangFunctionDecl_doesThisDeclarationHaveABody(self: *const ZigClangFunctionDecl) bool;
pub extern fn ZigClangFunctionDecl_isInlineSpecified(self: *const ZigClangFunctionDecl) bool;
pub extern fn ZigClangFunctionDecl_isDefined(self: *const ZigClangFunctionDecl) bool;
pub extern fn ZigClangFunctionDecl_getDefinition(self: *const ZigClangFunctionDecl) ?*const struct_ZigClangFunctionDecl;
pub extern fn ZigClangFunctionDecl_getSectionAttribute(self: *const ZigClangFunctionDecl, len: *usize) ?[*]const u8;

pub extern fn ZigClangBuiltinType_getKind(self: *const struct_ZigClangBuiltinType) ZigClangBuiltinTypeKind;

pub extern fn ZigClangFunctionType_getNoReturnAttr(self: *const ZigClangFunctionType) bool;
pub extern fn ZigClangFunctionType_getCallConv(self: *const ZigClangFunctionType) ZigClangCallingConv;
pub extern fn ZigClangFunctionType_getReturnType(self: *const ZigClangFunctionType) ZigClangQualType;

pub extern fn ZigClangFunctionProtoType_isVariadic(self: *const struct_ZigClangFunctionProtoType) bool;
pub extern fn ZigClangFunctionProtoType_getNumParams(self: *const struct_ZigClangFunctionProtoType) c_uint;
pub extern fn ZigClangFunctionProtoType_getParamType(self: *const struct_ZigClangFunctionProtoType, i: c_uint) ZigClangQualType;
pub extern fn ZigClangFunctionProtoType_getReturnType(self: *const ZigClangFunctionProtoType) ZigClangQualType;

pub const ZigClangSourceLocation = struct_ZigClangSourceLocation;
pub const ZigClangQualType = struct_ZigClangQualType;
pub const ZigClangConditionalOperator = struct_ZigClangConditionalOperator;
pub const ZigClangBinaryConditionalOperator = struct_ZigClangBinaryConditionalOperator;
pub const ZigClangAbstractConditionalOperator = struct_ZigClangAbstractConditionalOperator;
pub const ZigClangAPValueLValueBase = struct_ZigClangAPValueLValueBase;
pub const ZigClangAPValue = struct_ZigClangAPValue;
pub const ZigClangAPSInt = struct_ZigClangAPSInt;
pub const ZigClangAPFloat = struct_ZigClangAPFloat;
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
pub const ZigClangConstantArrayType = struct_ZigClangConstantArrayType;
pub const ZigClangContinueStmt = struct_ZigClangContinueStmt;
pub const ZigClangDecayedType = struct_ZigClangDecayedType;
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
pub const ZigClangMacroExpansion = struct_ZigClangMacroExpansion;
pub const ZigClangMacroQualifiedType = struct_ZigClangMacroQualifiedType;
pub const ZigClangMemberExpr = struct_ZigClangMemberExpr;
pub const ZigClangNamedDecl = struct_ZigClangNamedDecl;
pub const ZigClangNone = struct_ZigClangNone;
pub const ZigClangOpaqueValueExpr = struct_ZigClangOpaqueValueExpr;
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
pub const ZigClangFunctionType = struct_ZigClangFunctionType;
pub const ZigClangPredefinedExpr = struct_ZigClangPredefinedExpr;
pub const ZigClangInitListExpr = struct_ZigClangInitListExpr;

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

pub const struct_ZigClangQualType = extern struct {
    ptr: ?*c_void,
};

pub const struct_ZigClangAPValueLValueBase = extern struct {
    Ptr: ?*c_void,
    CallIndex: c_uint,
    Version: c_uint,
};

pub extern fn ZigClangErrorMsg_delete(ptr: [*]Stage2ErrorMsg, len: usize) void;

pub extern fn ZigClangLoadFromCommandLine(
    args_begin: [*]?[*]const u8,
    args_end: [*]?[*]const u8,
    errors_ptr: *[*]Stage2ErrorMsg,
    errors_len: *usize,
    resources_path: [*:0]const u8,
) ?*ZigClangASTUnit;

pub extern fn ZigClangDecl_getKind(decl: *const ZigClangDecl) ZigClangDeclKind;
pub extern fn ZigClangDecl_getDeclKindName(decl: *const ZigClangDecl) [*:0]const u8;

pub const ZigClangCompoundStmt_const_body_iterator = [*]const *ZigClangStmt;

pub extern fn ZigClangCompoundStmt_body_begin(self: *const ZigClangCompoundStmt) ZigClangCompoundStmt_const_body_iterator;
pub extern fn ZigClangCompoundStmt_body_end(self: *const ZigClangCompoundStmt) ZigClangCompoundStmt_const_body_iterator;

pub const ZigClangDeclStmt_const_decl_iterator = [*]const *ZigClangDecl;

pub extern fn ZigClangDeclStmt_decl_begin(self: *const ZigClangDeclStmt) ZigClangDeclStmt_const_decl_iterator;
pub extern fn ZigClangDeclStmt_decl_end(self: *const ZigClangDeclStmt) ZigClangDeclStmt_const_decl_iterator;

pub extern fn ZigClangVarDecl_getLocation(self: *const struct_ZigClangVarDecl) ZigClangSourceLocation;
pub extern fn ZigClangVarDecl_hasInit(self: *const struct_ZigClangVarDecl) bool;
pub extern fn ZigClangVarDecl_getStorageClass(self: *const ZigClangVarDecl) ZigClangStorageClass;
pub extern fn ZigClangVarDecl_getType(self: ?*const struct_ZigClangVarDecl) struct_ZigClangQualType;
pub extern fn ZigClangVarDecl_getInit(*const ZigClangVarDecl) ?*const ZigClangExpr;
pub extern fn ZigClangVarDecl_getTLSKind(self: ?*const struct_ZigClangVarDecl) ZigClangVarDecl_TLSKind;
pub const ZigClangVarDecl_TLSKind = extern enum {
    None,
    Static,
    Dynamic,
};

pub extern fn ZigClangImplicitCastExpr_getBeginLoc(*const ZigClangImplicitCastExpr) ZigClangSourceLocation;
pub extern fn ZigClangImplicitCastExpr_getCastKind(*const ZigClangImplicitCastExpr) ZigClangCK;
pub extern fn ZigClangImplicitCastExpr_getSubExpr(*const ZigClangImplicitCastExpr) *const ZigClangExpr;

pub extern fn ZigClangArrayType_getElementType(*const ZigClangArrayType) ZigClangQualType;
pub extern fn ZigClangIncompleteArrayType_getElementType(*const ZigClangIncompleteArrayType) ZigClangQualType;

pub extern fn ZigClangConstantArrayType_getElementType(self: *const struct_ZigClangConstantArrayType) ZigClangQualType;
pub extern fn ZigClangConstantArrayType_getSize(self: *const struct_ZigClangConstantArrayType) *const struct_ZigClangAPInt;
pub extern fn ZigClangDeclRefExpr_getDecl(*const ZigClangDeclRefExpr) *const ZigClangValueDecl;
pub extern fn ZigClangDeclRefExpr_getFoundDecl(*const ZigClangDeclRefExpr) *const ZigClangNamedDecl;

pub extern fn ZigClangParenType_getInnerType(*const ZigClangParenType) ZigClangQualType;

pub extern fn ZigClangElaboratedType_getNamedType(*const ZigClangElaboratedType) ZigClangQualType;

pub extern fn ZigClangAttributedType_getEquivalentType(*const ZigClangAttributedType) ZigClangQualType;

pub extern fn ZigClangMacroQualifiedType_getModifiedType(*const ZigClangMacroQualifiedType) ZigClangQualType;

pub extern fn ZigClangCStyleCastExpr_getBeginLoc(*const ZigClangCStyleCastExpr) ZigClangSourceLocation;
pub extern fn ZigClangCStyleCastExpr_getSubExpr(*const ZigClangCStyleCastExpr) *const ZigClangExpr;
pub extern fn ZigClangCStyleCastExpr_getType(*const ZigClangCStyleCastExpr) ZigClangQualType;

pub const ZigClangExprEvalResult = struct_ZigClangExprEvalResult;
pub const struct_ZigClangExprEvalResult = extern struct {
    HasSideEffects: bool,
    HasUndefinedBehavior: bool,
    SmallVectorImpl: ?*c_void,
    Val: ZigClangAPValue,
};

pub const struct_ZigClangAPValue = extern struct {
    Kind: ZigClangAPValueKind,
    Data: if (builtin.os.tag == .windows and builtin.abi == .msvc) [52]u8 else [68]u8,
};
pub extern fn ZigClangVarDecl_getTypeSourceInfo_getType(self: *const struct_ZigClangVarDecl) struct_ZigClangQualType;

pub extern fn ZigClangIntegerLiteral_EvaluateAsInt(*const ZigClangIntegerLiteral, *ZigClangExprEvalResult, *const ZigClangASTContext) bool;
pub extern fn ZigClangIntegerLiteral_getBeginLoc(*const ZigClangIntegerLiteral) ZigClangSourceLocation;
pub extern fn ZigClangIntegerLiteral_isZero(*const ZigClangIntegerLiteral, *bool, *const ZigClangASTContext) bool;

pub extern fn ZigClangReturnStmt_getRetValue(*const ZigClangReturnStmt) ?*const ZigClangExpr;

pub extern fn ZigClangBinaryOperator_getOpcode(*const ZigClangBinaryOperator) ZigClangBO;
pub extern fn ZigClangBinaryOperator_getBeginLoc(*const ZigClangBinaryOperator) ZigClangSourceLocation;
pub extern fn ZigClangBinaryOperator_getLHS(*const ZigClangBinaryOperator) *const ZigClangExpr;
pub extern fn ZigClangBinaryOperator_getRHS(*const ZigClangBinaryOperator) *const ZigClangExpr;
pub extern fn ZigClangBinaryOperator_getType(*const ZigClangBinaryOperator) ZigClangQualType;

pub extern fn ZigClangDecayedType_getDecayedType(*const ZigClangDecayedType) ZigClangQualType;

pub extern fn ZigClangStringLiteral_getKind(*const ZigClangStringLiteral) ZigClangStringLiteral_StringKind;
pub extern fn ZigClangStringLiteral_getString_bytes_begin_size(*const ZigClangStringLiteral, *usize) [*]const u8;

pub extern fn ZigClangParenExpr_getSubExpr(*const ZigClangParenExpr) *const ZigClangExpr;

pub extern fn ZigClangFieldDecl_isAnonymousStructOrUnion(*const struct_ZigClangFieldDecl) bool;
pub extern fn ZigClangFieldDecl_isBitField(*const struct_ZigClangFieldDecl) bool;
pub extern fn ZigClangFieldDecl_getType(*const struct_ZigClangFieldDecl) struct_ZigClangQualType;
pub extern fn ZigClangFieldDecl_getLocation(*const struct_ZigClangFieldDecl) struct_ZigClangSourceLocation;

pub extern fn ZigClangEnumConstantDecl_getInitExpr(*const ZigClangEnumConstantDecl) ?*const ZigClangExpr;
pub extern fn ZigClangEnumConstantDecl_getInitVal(*const ZigClangEnumConstantDecl) *const ZigClangAPSInt;

pub extern fn ZigClangASTUnit_getLocalPreprocessingEntities_begin(*ZigClangASTUnit) ZigClangPreprocessingRecord_iterator;
pub extern fn ZigClangASTUnit_getLocalPreprocessingEntities_end(*ZigClangASTUnit) ZigClangPreprocessingRecord_iterator;
pub extern fn ZigClangPreprocessingRecord_iterator_deref(ZigClangPreprocessingRecord_iterator) *ZigClangPreprocessedEntity;
pub extern fn ZigClangPreprocessedEntity_getKind(*const ZigClangPreprocessedEntity) ZigClangPreprocessedEntity_EntityKind;

pub extern fn ZigClangMacroDefinitionRecord_getName_getNameStart(*const ZigClangMacroDefinitionRecord) [*:0]const u8;
pub extern fn ZigClangMacroDefinitionRecord_getSourceRange_getBegin(*const ZigClangMacroDefinitionRecord) ZigClangSourceLocation;
pub extern fn ZigClangMacroDefinitionRecord_getSourceRange_getEnd(*const ZigClangMacroDefinitionRecord) ZigClangSourceLocation;

pub extern fn ZigClangMacroExpansion_getDefinition(*const ZigClangMacroExpansion) *const ZigClangMacroDefinitionRecord;

pub extern fn ZigClangIfStmt_getThen(*const ZigClangIfStmt) *const ZigClangStmt;
pub extern fn ZigClangIfStmt_getElse(*const ZigClangIfStmt) ?*const ZigClangStmt;
pub extern fn ZigClangIfStmt_getCond(*const ZigClangIfStmt) *const ZigClangStmt;

pub extern fn ZigClangWhileStmt_getCond(*const ZigClangWhileStmt) *const ZigClangExpr;
pub extern fn ZigClangWhileStmt_getBody(*const ZigClangWhileStmt) *const ZigClangStmt;

pub extern fn ZigClangDoStmt_getCond(*const ZigClangDoStmt) *const ZigClangExpr;
pub extern fn ZigClangDoStmt_getBody(*const ZigClangDoStmt) *const ZigClangStmt;

pub extern fn ZigClangForStmt_getInit(*const ZigClangForStmt) ?*const ZigClangStmt;
pub extern fn ZigClangForStmt_getCond(*const ZigClangForStmt) ?*const ZigClangExpr;
pub extern fn ZigClangForStmt_getInc(*const ZigClangForStmt) ?*const ZigClangExpr;
pub extern fn ZigClangForStmt_getBody(*const ZigClangForStmt) *const ZigClangStmt;

pub extern fn ZigClangAPFloat_toString(self: *const ZigClangAPFloat, precision: c_uint, maxPadding: c_uint, truncateZero: bool) [*:0]const u8;
pub extern fn ZigClangAPFloat_getValueAsApproximateDouble(*const ZigClangFloatingLiteral) f64;

pub extern fn ZigClangAbstractConditionalOperator_getCond(*const ZigClangAbstractConditionalOperator) *const ZigClangExpr;
pub extern fn ZigClangAbstractConditionalOperator_getTrueExpr(*const ZigClangAbstractConditionalOperator) *const ZigClangExpr;
pub extern fn ZigClangAbstractConditionalOperator_getFalseExpr(*const ZigClangAbstractConditionalOperator) *const ZigClangExpr;

pub extern fn ZigClangSwitchStmt_getConditionVariableDeclStmt(*const ZigClangSwitchStmt) ?*const ZigClangDeclStmt;
pub extern fn ZigClangSwitchStmt_getCond(*const ZigClangSwitchStmt) *const ZigClangExpr;
pub extern fn ZigClangSwitchStmt_getBody(*const ZigClangSwitchStmt) *const ZigClangStmt;
pub extern fn ZigClangSwitchStmt_isAllEnumCasesCovered(*const ZigClangSwitchStmt) bool;

pub extern fn ZigClangCaseStmt_getLHS(*const ZigClangCaseStmt) *const ZigClangExpr;
pub extern fn ZigClangCaseStmt_getRHS(*const ZigClangCaseStmt) ?*const ZigClangExpr;
pub extern fn ZigClangCaseStmt_getBeginLoc(*const ZigClangCaseStmt) ZigClangSourceLocation;
pub extern fn ZigClangCaseStmt_getSubStmt(*const ZigClangCaseStmt) *const ZigClangStmt;

pub extern fn ZigClangDefaultStmt_getSubStmt(*const ZigClangDefaultStmt) *const ZigClangStmt;

pub extern fn ZigClangExpr_EvaluateAsConstantExpr(*const ZigClangExpr, *ZigClangExprEvalResult, ZigClangExpr_ConstExprUsage, *const ZigClangASTContext) bool;

pub extern fn ZigClangPredefinedExpr_getFunctionName(*const ZigClangPredefinedExpr) *const ZigClangStringLiteral;

pub extern fn ZigClangCharacterLiteral_getBeginLoc(*const ZigClangCharacterLiteral) ZigClangSourceLocation;
pub extern fn ZigClangCharacterLiteral_getKind(*const ZigClangCharacterLiteral) ZigClangCharacterLiteral_CharacterKind;
pub extern fn ZigClangCharacterLiteral_getValue(*const ZigClangCharacterLiteral) c_uint;

pub extern fn ZigClangStmtExpr_getSubStmt(*const ZigClangStmtExpr) *const ZigClangCompoundStmt;

pub extern fn ZigClangMemberExpr_getBase(*const ZigClangMemberExpr) *const ZigClangExpr;
pub extern fn ZigClangMemberExpr_isArrow(*const ZigClangMemberExpr) bool;
pub extern fn ZigClangMemberExpr_getMemberDecl(*const ZigClangMemberExpr) *const ZigClangValueDecl;

pub extern fn ZigClangArraySubscriptExpr_getBase(*const ZigClangArraySubscriptExpr) *const ZigClangExpr;
pub extern fn ZigClangArraySubscriptExpr_getIdx(*const ZigClangArraySubscriptExpr) *const ZigClangExpr;

pub extern fn ZigClangCallExpr_getCallee(*const ZigClangCallExpr) *const ZigClangExpr;
pub extern fn ZigClangCallExpr_getNumArgs(*const ZigClangCallExpr) c_uint;
pub extern fn ZigClangCallExpr_getArgs(*const ZigClangCallExpr) [*]const *const ZigClangExpr;

pub extern fn ZigClangUnaryExprOrTypeTraitExpr_getTypeOfArgument(*const ZigClangUnaryExprOrTypeTraitExpr) ZigClangQualType;
pub extern fn ZigClangUnaryExprOrTypeTraitExpr_getBeginLoc(*const ZigClangUnaryExprOrTypeTraitExpr) ZigClangSourceLocation;
pub extern fn ZigClangUnaryExprOrTypeTraitExpr_getKind(*const ZigClangUnaryExprOrTypeTraitExpr) ZigClangUnaryExprOrTypeTrait_Kind;

pub extern fn ZigClangUnaryOperator_getOpcode(*const ZigClangUnaryOperator) ZigClangUO;
pub extern fn ZigClangUnaryOperator_getType(*const ZigClangUnaryOperator) ZigClangQualType;
pub extern fn ZigClangUnaryOperator_getSubExpr(*const ZigClangUnaryOperator) *const ZigClangExpr;
pub extern fn ZigClangUnaryOperator_getBeginLoc(*const ZigClangUnaryOperator) ZigClangSourceLocation;

pub extern fn ZigClangOpaqueValueExpr_getSourceExpr(*const ZigClangOpaqueValueExpr) ?*const ZigClangExpr;

pub extern fn ZigClangCompoundAssignOperator_getType(*const ZigClangCompoundAssignOperator) ZigClangQualType;
pub extern fn ZigClangCompoundAssignOperator_getComputationLHSType(*const ZigClangCompoundAssignOperator) ZigClangQualType;
pub extern fn ZigClangCompoundAssignOperator_getComputationResultType(*const ZigClangCompoundAssignOperator) ZigClangQualType;
pub extern fn ZigClangCompoundAssignOperator_getBeginLoc(*const ZigClangCompoundAssignOperator) ZigClangSourceLocation;
pub extern fn ZigClangCompoundAssignOperator_getOpcode(*const ZigClangCompoundAssignOperator) ZigClangBO;
pub extern fn ZigClangCompoundAssignOperator_getLHS(*const ZigClangCompoundAssignOperator) *const ZigClangExpr;
pub extern fn ZigClangCompoundAssignOperator_getRHS(*const ZigClangCompoundAssignOperator) *const ZigClangExpr;
