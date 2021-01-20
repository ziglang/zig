pub const builtin = @import("builtin");

pub const SourceLocation = extern struct {
    ID: c_uint,

    pub const eq = ZigClangSourceLocation_eq;
    extern fn ZigClangSourceLocation_eq(a: SourceLocation, b: SourceLocation) bool;
};

pub const QualType = extern struct {
    ptr: ?*c_void,

    pub const getCanonicalType = ZigClangQualType_getCanonicalType;
    extern fn ZigClangQualType_getCanonicalType(QualType) QualType;

    pub const getTypePtr = ZigClangQualType_getTypePtr;
    extern fn ZigClangQualType_getTypePtr(QualType) *const Type;

    pub const getTypeClass = ZigClangQualType_getTypeClass;
    extern fn ZigClangQualType_getTypeClass(QualType) TypeClass;

    pub const addConst = ZigClangQualType_addConst;
    extern fn ZigClangQualType_addConst(*QualType) void;

    pub const eq = ZigClangQualType_eq;
    extern fn ZigClangQualType_eq(QualType, arg1: QualType) bool;

    pub const isConstQualified = ZigClangQualType_isConstQualified;
    extern fn ZigClangQualType_isConstQualified(QualType) bool;

    pub const isVolatileQualified = ZigClangQualType_isVolatileQualified;
    extern fn ZigClangQualType_isVolatileQualified(QualType) bool;

    pub const isRestrictQualified = ZigClangQualType_isRestrictQualified;
    extern fn ZigClangQualType_isRestrictQualified(QualType) bool;
};

pub const APValueLValueBase = extern struct {
    Ptr: ?*c_void,
    CallIndex: c_uint,
    Version: c_uint,

    pub const dyn_cast_Expr = ZigClangAPValueLValueBase_dyn_cast_Expr;
    extern fn ZigClangAPValueLValueBase_dyn_cast_Expr(APValueLValueBase) ?*const Expr;
};

pub const APValueKind = extern enum {
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

pub const APValue = extern struct {
    Kind: APValueKind,
    Data: if (builtin.os.tag == .windows and builtin.abi == .msvc) [52]u8 else [68]u8,

    pub const getKind = ZigClangAPValue_getKind;
    extern fn ZigClangAPValue_getKind(*const APValue) APValueKind;

    pub const getInt = ZigClangAPValue_getInt;
    extern fn ZigClangAPValue_getInt(*const APValue) *const APSInt;

    pub const getArrayInitializedElts = ZigClangAPValue_getArrayInitializedElts;
    extern fn ZigClangAPValue_getArrayInitializedElts(*const APValue) c_uint;

    pub const getArraySize = ZigClangAPValue_getArraySize;
    extern fn ZigClangAPValue_getArraySize(*const APValue) c_uint;

    pub const getLValueBase = ZigClangAPValue_getLValueBase;
    extern fn ZigClangAPValue_getLValueBase(*const APValue) APValueLValueBase;
};

pub const ExprEvalResult = extern struct {
    HasSideEffects: bool,
    HasUndefinedBehavior: bool,
    SmallVectorImpl: ?*c_void,
    Val: APValue,
};

pub const AbstractConditionalOperator = opaque {
    pub const getCond = ZigClangAbstractConditionalOperator_getCond;
    extern fn ZigClangAbstractConditionalOperator_getCond(*const AbstractConditionalOperator) *const Expr;

    pub const getTrueExpr = ZigClangAbstractConditionalOperator_getTrueExpr;
    extern fn ZigClangAbstractConditionalOperator_getTrueExpr(*const AbstractConditionalOperator) *const Expr;

    pub const getFalseExpr = ZigClangAbstractConditionalOperator_getFalseExpr;
    extern fn ZigClangAbstractConditionalOperator_getFalseExpr(*const AbstractConditionalOperator) *const Expr;
};

pub const APFloat = opaque {
    pub const toString = ZigClangAPFloat_toString;
    extern fn ZigClangAPFloat_toString(*const APFloat, precision: c_uint, maxPadding: c_uint, truncateZero: bool) [*:0]const u8;
};

pub const APInt = opaque {
    pub const getLimitedValue = ZigClangAPInt_getLimitedValue;
    extern fn ZigClangAPInt_getLimitedValue(*const APInt, limit: u64) u64;
};

pub const APSInt = opaque {
    pub const isSigned = ZigClangAPSInt_isSigned;
    extern fn ZigClangAPSInt_isSigned(*const APSInt) bool;

    pub const isNegative = ZigClangAPSInt_isNegative;
    extern fn ZigClangAPSInt_isNegative(*const APSInt) bool;

    pub const negate = ZigClangAPSInt_negate;
    extern fn ZigClangAPSInt_negate(*const APSInt) *const APSInt;

    pub const free = ZigClangAPSInt_free;
    extern fn ZigClangAPSInt_free(*const APSInt) void;

    pub const getRawData = ZigClangAPSInt_getRawData;
    extern fn ZigClangAPSInt_getRawData(*const APSInt) [*:0]const u64;

    pub const getNumWords = ZigClangAPSInt_getNumWords;
    extern fn ZigClangAPSInt_getNumWords(*const APSInt) c_uint;
};

pub const ASTContext = opaque {
    pub const getPointerType = ZigClangASTContext_getPointerType;
    extern fn ZigClangASTContext_getPointerType(*const ASTContext, T: QualType) QualType;
};

pub const ASTUnit = opaque {
    pub const delete = ZigClangASTUnit_delete;
    extern fn ZigClangASTUnit_delete(*ASTUnit) void;

    pub const getASTContext = ZigClangASTUnit_getASTContext;
    extern fn ZigClangASTUnit_getASTContext(*ASTUnit) *ASTContext;

    pub const getSourceManager = ZigClangASTUnit_getSourceManager;
    extern fn ZigClangASTUnit_getSourceManager(*ASTUnit) *SourceManager;

    pub const visitLocalTopLevelDecls = ZigClangASTUnit_visitLocalTopLevelDecls;
    extern fn ZigClangASTUnit_visitLocalTopLevelDecls(*ASTUnit, context: ?*c_void, Fn: ?fn (?*c_void, *const Decl) callconv(.C) bool) bool;

    pub const getLocalPreprocessingEntities_begin = ZigClangASTUnit_getLocalPreprocessingEntities_begin;
    extern fn ZigClangASTUnit_getLocalPreprocessingEntities_begin(*ASTUnit) PreprocessingRecord.iterator;

    pub const getLocalPreprocessingEntities_end = ZigClangASTUnit_getLocalPreprocessingEntities_end;
    extern fn ZigClangASTUnit_getLocalPreprocessingEntities_end(*ASTUnit) PreprocessingRecord.iterator;
};

pub const ArraySubscriptExpr = opaque {
    pub const getBase = ZigClangArraySubscriptExpr_getBase;
    extern fn ZigClangArraySubscriptExpr_getBase(*const ArraySubscriptExpr) *const Expr;

    pub const getIdx = ZigClangArraySubscriptExpr_getIdx;
    extern fn ZigClangArraySubscriptExpr_getIdx(*const ArraySubscriptExpr) *const Expr;
};

pub const ArrayType = opaque {
    pub const getElementType = ZigClangArrayType_getElementType;
    extern fn ZigClangArrayType_getElementType(*const ArrayType) QualType;
};

pub const AttributedType = opaque {
    pub const getEquivalentType = ZigClangAttributedType_getEquivalentType;
    extern fn ZigClangAttributedType_getEquivalentType(*const AttributedType) QualType;
};

pub const BinaryOperator = opaque {
    pub const getOpcode = ZigClangBinaryOperator_getOpcode;
    extern fn ZigClangBinaryOperator_getOpcode(*const BinaryOperator) BO;

    pub const getBeginLoc = ZigClangBinaryOperator_getBeginLoc;
    extern fn ZigClangBinaryOperator_getBeginLoc(*const BinaryOperator) SourceLocation;

    pub const getLHS = ZigClangBinaryOperator_getLHS;
    extern fn ZigClangBinaryOperator_getLHS(*const BinaryOperator) *const Expr;

    pub const getRHS = ZigClangBinaryOperator_getRHS;
    extern fn ZigClangBinaryOperator_getRHS(*const BinaryOperator) *const Expr;

    pub const getType = ZigClangBinaryOperator_getType;
    extern fn ZigClangBinaryOperator_getType(*const BinaryOperator) QualType;
};

pub const BinaryConditionalOperator = opaque {};

pub const BreakStmt = opaque {};

pub const BuiltinType = opaque {
    pub const getKind = ZigClangBuiltinType_getKind;
    extern fn ZigClangBuiltinType_getKind(*const BuiltinType) BuiltinTypeKind;
};

pub const CStyleCastExpr = opaque {
    pub const getBeginLoc = ZigClangCStyleCastExpr_getBeginLoc;
    extern fn ZigClangCStyleCastExpr_getBeginLoc(*const CStyleCastExpr) SourceLocation;

    pub const getSubExpr = ZigClangCStyleCastExpr_getSubExpr;
    extern fn ZigClangCStyleCastExpr_getSubExpr(*const CStyleCastExpr) *const Expr;

    pub const getType = ZigClangCStyleCastExpr_getType;
    extern fn ZigClangCStyleCastExpr_getType(*const CStyleCastExpr) QualType;
};

pub const CallExpr = opaque {
    pub const getCallee = ZigClangCallExpr_getCallee;
    extern fn ZigClangCallExpr_getCallee(*const CallExpr) *const Expr;

    pub const getNumArgs = ZigClangCallExpr_getNumArgs;
    extern fn ZigClangCallExpr_getNumArgs(*const CallExpr) c_uint;

    pub const getArgs = ZigClangCallExpr_getArgs;
    extern fn ZigClangCallExpr_getArgs(*const CallExpr) [*]const *const Expr;
};

pub const CaseStmt = opaque {
    pub const getLHS = ZigClangCaseStmt_getLHS;
    extern fn ZigClangCaseStmt_getLHS(*const CaseStmt) *const Expr;

    pub const getRHS = ZigClangCaseStmt_getRHS;
    extern fn ZigClangCaseStmt_getRHS(*const CaseStmt) ?*const Expr;

    pub const getBeginLoc = ZigClangCaseStmt_getBeginLoc;
    extern fn ZigClangCaseStmt_getBeginLoc(*const CaseStmt) SourceLocation;

    pub const getSubStmt = ZigClangCaseStmt_getSubStmt;
    extern fn ZigClangCaseStmt_getSubStmt(*const CaseStmt) *const Stmt;
};

pub const CharacterLiteral = opaque {
    pub const getBeginLoc = ZigClangCharacterLiteral_getBeginLoc;
    extern fn ZigClangCharacterLiteral_getBeginLoc(*const CharacterLiteral) SourceLocation;

    pub const getKind = ZigClangCharacterLiteral_getKind;
    extern fn ZigClangCharacterLiteral_getKind(*const CharacterLiteral) CharacterLiteral_CharacterKind;

    pub const getValue = ZigClangCharacterLiteral_getValue;
    extern fn ZigClangCharacterLiteral_getValue(*const CharacterLiteral) c_uint;
};

pub const CompoundAssignOperator = opaque {
    pub const getType = ZigClangCompoundAssignOperator_getType;
    extern fn ZigClangCompoundAssignOperator_getType(*const CompoundAssignOperator) QualType;

    pub const getComputationLHSType = ZigClangCompoundAssignOperator_getComputationLHSType;
    extern fn ZigClangCompoundAssignOperator_getComputationLHSType(*const CompoundAssignOperator) QualType;

    pub const getComputationResultType = ZigClangCompoundAssignOperator_getComputationResultType;
    extern fn ZigClangCompoundAssignOperator_getComputationResultType(*const CompoundAssignOperator) QualType;

    pub const getBeginLoc = ZigClangCompoundAssignOperator_getBeginLoc;
    extern fn ZigClangCompoundAssignOperator_getBeginLoc(*const CompoundAssignOperator) SourceLocation;

    pub const getOpcode = ZigClangCompoundAssignOperator_getOpcode;
    extern fn ZigClangCompoundAssignOperator_getOpcode(*const CompoundAssignOperator) BO;

    pub const getLHS = ZigClangCompoundAssignOperator_getLHS;
    extern fn ZigClangCompoundAssignOperator_getLHS(*const CompoundAssignOperator) *const Expr;

    pub const getRHS = ZigClangCompoundAssignOperator_getRHS;
    extern fn ZigClangCompoundAssignOperator_getRHS(*const CompoundAssignOperator) *const Expr;
};

pub const CompoundStmt = opaque {
    pub const body_begin = ZigClangCompoundStmt_body_begin;
    extern fn ZigClangCompoundStmt_body_begin(*const CompoundStmt) const_body_iterator;

    pub const body_end = ZigClangCompoundStmt_body_end;
    extern fn ZigClangCompoundStmt_body_end(*const CompoundStmt) const_body_iterator;

    pub const const_body_iterator = [*]const *Stmt;
};

pub const ConditionalOperator = opaque {};

pub const ConstantArrayType = opaque {
    pub const getElementType = ZigClangConstantArrayType_getElementType;
    extern fn ZigClangConstantArrayType_getElementType(*const ConstantArrayType) QualType;

    pub const getSize = ZigClangConstantArrayType_getSize;
    extern fn ZigClangConstantArrayType_getSize(*const ConstantArrayType) *const APInt;
};

pub const ConstantExpr = opaque {};

pub const ContinueStmt = opaque {};

pub const DecayedType = opaque {
    pub const getDecayedType = ZigClangDecayedType_getDecayedType;
    extern fn ZigClangDecayedType_getDecayedType(*const DecayedType) QualType;
};

pub const Decl = opaque {
    pub const getLocation = ZigClangDecl_getLocation;
    extern fn ZigClangDecl_getLocation(*const Decl) SourceLocation;

    pub const castToNamedDecl = ZigClangDecl_castToNamedDecl;
    extern fn ZigClangDecl_castToNamedDecl(decl: *const Decl) ?*const NamedDecl;

    pub const getKind = ZigClangDecl_getKind;
    extern fn ZigClangDecl_getKind(decl: *const Decl) DeclKind;

    pub const getDeclKindName = ZigClangDecl_getDeclKindName;
    extern fn ZigClangDecl_getDeclKindName(decl: *const Decl) [*:0]const u8;
};

pub const DeclRefExpr = opaque {
    pub const getDecl = ZigClangDeclRefExpr_getDecl;
    extern fn ZigClangDeclRefExpr_getDecl(*const DeclRefExpr) *const ValueDecl;

    pub const getFoundDecl = ZigClangDeclRefExpr_getFoundDecl;
    extern fn ZigClangDeclRefExpr_getFoundDecl(*const DeclRefExpr) *const NamedDecl;
};

pub const DeclStmt = opaque {
    pub const decl_begin = ZigClangDeclStmt_decl_begin;
    extern fn ZigClangDeclStmt_decl_begin(*const DeclStmt) const_decl_iterator;

    pub const decl_end = ZigClangDeclStmt_decl_end;
    extern fn ZigClangDeclStmt_decl_end(*const DeclStmt) const_decl_iterator;

    pub const const_decl_iterator = [*]const *Decl;
};

pub const DefaultStmt = opaque {
    pub const getSubStmt = ZigClangDefaultStmt_getSubStmt;
    extern fn ZigClangDefaultStmt_getSubStmt(*const DefaultStmt) *const Stmt;
};

pub const DiagnosticOptions = opaque {};

pub const DiagnosticsEngine = opaque {};

pub const DoStmt = opaque {
    pub const getCond = ZigClangDoStmt_getCond;
    extern fn ZigClangDoStmt_getCond(*const DoStmt) *const Expr;

    pub const getBody = ZigClangDoStmt_getBody;
    extern fn ZigClangDoStmt_getBody(*const DoStmt) *const Stmt;
};

pub const ElaboratedType = opaque {
    pub const getNamedType = ZigClangElaboratedType_getNamedType;
    extern fn ZigClangElaboratedType_getNamedType(*const ElaboratedType) QualType;
};

pub const EnumConstantDecl = opaque {
    pub const getInitExpr = ZigClangEnumConstantDecl_getInitExpr;
    extern fn ZigClangEnumConstantDecl_getInitExpr(*const EnumConstantDecl) ?*const Expr;

    pub const getInitVal = ZigClangEnumConstantDecl_getInitVal;
    extern fn ZigClangEnumConstantDecl_getInitVal(*const EnumConstantDecl) *const APSInt;
};

pub const EnumDecl = opaque {
    pub const getCanonicalDecl = ZigClangEnumDecl_getCanonicalDecl;
    extern fn ZigClangEnumDecl_getCanonicalDecl(*const EnumDecl) ?*const TagDecl;

    pub const getIntegerType = ZigClangEnumDecl_getIntegerType;
    extern fn ZigClangEnumDecl_getIntegerType(*const EnumDecl) QualType;

    pub const getDefinition = ZigClangEnumDecl_getDefinition;
    extern fn ZigClangEnumDecl_getDefinition(*const EnumDecl) ?*const EnumDecl;

    pub const getLocation = ZigClangEnumDecl_getLocation;
    extern fn ZigClangEnumDecl_getLocation(*const EnumDecl) SourceLocation;

    pub const enumerator_begin = ZigClangEnumDecl_enumerator_begin;
    extern fn ZigClangEnumDecl_enumerator_begin(*const EnumDecl) enumerator_iterator;

    pub const enumerator_end = ZigClangEnumDecl_enumerator_end;
    extern fn ZigClangEnumDecl_enumerator_end(*const EnumDecl) enumerator_iterator;

    pub const enumerator_iterator = extern struct {
        ptr: *c_void,

        pub const next = ZigClangEnumDecl_enumerator_iterator_next;
        extern fn ZigClangEnumDecl_enumerator_iterator_next(enumerator_iterator) enumerator_iterator;

        pub const deref = ZigClangEnumDecl_enumerator_iterator_deref;
        extern fn ZigClangEnumDecl_enumerator_iterator_deref(enumerator_iterator) *const EnumConstantDecl;

        pub const neq = ZigClangEnumDecl_enumerator_iterator_neq;
        extern fn ZigClangEnumDecl_enumerator_iterator_neq(enumerator_iterator, enumerator_iterator) bool;
    };
};

pub const EnumType = opaque {
    pub const getDecl = ZigClangEnumType_getDecl;
    extern fn ZigClangEnumType_getDecl(*const EnumType) *const EnumDecl;
};

pub const Expr = opaque {
    pub const getStmtClass = ZigClangExpr_getStmtClass;
    extern fn ZigClangExpr_getStmtClass(*const Expr) StmtClass;

    pub const getType = ZigClangExpr_getType;
    extern fn ZigClangExpr_getType(*const Expr) QualType;

    pub const getBeginLoc = ZigClangExpr_getBeginLoc;
    extern fn ZigClangExpr_getBeginLoc(*const Expr) SourceLocation;

    pub const EvaluateAsConstantExpr = ZigClangExpr_EvaluateAsConstantExpr;
    extern fn ZigClangExpr_EvaluateAsConstantExpr(*const Expr, *ExprEvalResult, Expr_ConstExprUsage, *const ASTContext) bool;
};

pub const FieldDecl = opaque {
    pub const getCanonicalDecl = ZigClangFieldDecl_getCanonicalDecl;
    extern fn ZigClangFieldDecl_getCanonicalDecl(*const FieldDecl) ?*const FieldDecl;

    pub const getAlignedAttribute = ZigClangFieldDecl_getAlignedAttribute;
    extern fn ZigClangFieldDecl_getAlignedAttribute(*const FieldDecl, *const ASTContext) c_uint;

    pub const isAnonymousStructOrUnion = ZigClangFieldDecl_isAnonymousStructOrUnion;
    extern fn ZigClangFieldDecl_isAnonymousStructOrUnion(*const FieldDecl) bool;

    pub const isBitField = ZigClangFieldDecl_isBitField;
    extern fn ZigClangFieldDecl_isBitField(*const FieldDecl) bool;

    pub const getType = ZigClangFieldDecl_getType;
    extern fn ZigClangFieldDecl_getType(*const FieldDecl) QualType;

    pub const getLocation = ZigClangFieldDecl_getLocation;
    extern fn ZigClangFieldDecl_getLocation(*const FieldDecl) SourceLocation;
};

pub const FileID = opaque {};

pub const FloatingLiteral = opaque {
    pub const getValueAsApproximateDouble = ZigClangFloatingLiteral_getValueAsApproximateDouble;
    extern fn ZigClangFloatingLiteral_getValueAsApproximateDouble(*const FloatingLiteral) f64;
};

pub const ForStmt = opaque {
    pub const getInit = ZigClangForStmt_getInit;
    extern fn ZigClangForStmt_getInit(*const ForStmt) ?*const Stmt;

    pub const getCond = ZigClangForStmt_getCond;
    extern fn ZigClangForStmt_getCond(*const ForStmt) ?*const Expr;

    pub const getInc = ZigClangForStmt_getInc;
    extern fn ZigClangForStmt_getInc(*const ForStmt) ?*const Expr;

    pub const getBody = ZigClangForStmt_getBody;
    extern fn ZigClangForStmt_getBody(*const ForStmt) *const Stmt;
};

pub const FullSourceLoc = opaque {};

pub const FunctionDecl = opaque {
    pub const getType = ZigClangFunctionDecl_getType;
    extern fn ZigClangFunctionDecl_getType(*const FunctionDecl) QualType;

    pub const getLocation = ZigClangFunctionDecl_getLocation;
    extern fn ZigClangFunctionDecl_getLocation(*const FunctionDecl) SourceLocation;

    pub const hasBody = ZigClangFunctionDecl_hasBody;
    extern fn ZigClangFunctionDecl_hasBody(*const FunctionDecl) bool;

    pub const getStorageClass = ZigClangFunctionDecl_getStorageClass;
    extern fn ZigClangFunctionDecl_getStorageClass(*const FunctionDecl) StorageClass;

    pub const getParamDecl = ZigClangFunctionDecl_getParamDecl;
    extern fn ZigClangFunctionDecl_getParamDecl(*const FunctionDecl, i: c_uint) *const ParmVarDecl;

    pub const getBody = ZigClangFunctionDecl_getBody;
    extern fn ZigClangFunctionDecl_getBody(*const FunctionDecl) *const Stmt;

    pub const doesDeclarationForceExternallyVisibleDefinition = ZigClangFunctionDecl_doesDeclarationForceExternallyVisibleDefinition;
    extern fn ZigClangFunctionDecl_doesDeclarationForceExternallyVisibleDefinition(*const FunctionDecl) bool;

    pub const isThisDeclarationADefinition = ZigClangFunctionDecl_isThisDeclarationADefinition;
    extern fn ZigClangFunctionDecl_isThisDeclarationADefinition(*const FunctionDecl) bool;

    pub const doesThisDeclarationHaveABody = ZigClangFunctionDecl_doesThisDeclarationHaveABody;
    extern fn ZigClangFunctionDecl_doesThisDeclarationHaveABody(*const FunctionDecl) bool;

    pub const isInlineSpecified = ZigClangFunctionDecl_isInlineSpecified;
    extern fn ZigClangFunctionDecl_isInlineSpecified(*const FunctionDecl) bool;

    pub const isDefined = ZigClangFunctionDecl_isDefined;
    extern fn ZigClangFunctionDecl_isDefined(*const FunctionDecl) bool;

    pub const getDefinition = ZigClangFunctionDecl_getDefinition;
    extern fn ZigClangFunctionDecl_getDefinition(*const FunctionDecl) ?*const FunctionDecl;

    pub const getSectionAttribute = ZigClangFunctionDecl_getSectionAttribute;
    extern fn ZigClangFunctionDecl_getSectionAttribute(*const FunctionDecl, len: *usize) ?[*]const u8;

    pub const getCanonicalDecl = ZigClangFunctionDecl_getCanonicalDecl;
    extern fn ZigClangFunctionDecl_getCanonicalDecl(*const FunctionDecl) ?*const FunctionDecl;

    pub const getAlignedAttribute = ZigClangFunctionDecl_getAlignedAttribute;
    extern fn ZigClangFunctionDecl_getAlignedAttribute(*const FunctionDecl, *const ASTContext) c_uint;
};

pub const FunctionProtoType = opaque {
    pub const isVariadic = ZigClangFunctionProtoType_isVariadic;
    extern fn ZigClangFunctionProtoType_isVariadic(*const FunctionProtoType) bool;

    pub const getNumParams = ZigClangFunctionProtoType_getNumParams;
    extern fn ZigClangFunctionProtoType_getNumParams(*const FunctionProtoType) c_uint;

    pub const getParamType = ZigClangFunctionProtoType_getParamType;
    extern fn ZigClangFunctionProtoType_getParamType(*const FunctionProtoType, i: c_uint) QualType;

    pub const getReturnType = ZigClangFunctionProtoType_getReturnType;
    extern fn ZigClangFunctionProtoType_getReturnType(*const FunctionProtoType) QualType;
};

pub const FunctionType = opaque {
    pub const getNoReturnAttr = ZigClangFunctionType_getNoReturnAttr;
    extern fn ZigClangFunctionType_getNoReturnAttr(*const FunctionType) bool;

    pub const getCallConv = ZigClangFunctionType_getCallConv;
    extern fn ZigClangFunctionType_getCallConv(*const FunctionType) CallingConv;

    pub const getReturnType = ZigClangFunctionType_getReturnType;
    extern fn ZigClangFunctionType_getReturnType(*const FunctionType) QualType;
};

pub const IfStmt = opaque {
    pub const getThen = ZigClangIfStmt_getThen;
    extern fn ZigClangIfStmt_getThen(*const IfStmt) *const Stmt;

    pub const getElse = ZigClangIfStmt_getElse;
    extern fn ZigClangIfStmt_getElse(*const IfStmt) ?*const Stmt;

    pub const getCond = ZigClangIfStmt_getCond;
    extern fn ZigClangIfStmt_getCond(*const IfStmt) *const Stmt;
};

pub const ImplicitCastExpr = opaque {
    pub const getBeginLoc = ZigClangImplicitCastExpr_getBeginLoc;
    extern fn ZigClangImplicitCastExpr_getBeginLoc(*const ImplicitCastExpr) SourceLocation;

    pub const getCastKind = ZigClangImplicitCastExpr_getCastKind;
    extern fn ZigClangImplicitCastExpr_getCastKind(*const ImplicitCastExpr) CK;

    pub const getSubExpr = ZigClangImplicitCastExpr_getSubExpr;
    extern fn ZigClangImplicitCastExpr_getSubExpr(*const ImplicitCastExpr) *const Expr;
};

pub const IncompleteArrayType = opaque {
    pub const getElementType = ZigClangIncompleteArrayType_getElementType;
    extern fn ZigClangIncompleteArrayType_getElementType(*const IncompleteArrayType) QualType;
};

pub const IntegerLiteral = opaque {
    pub const EvaluateAsInt = ZigClangIntegerLiteral_EvaluateAsInt;
    extern fn ZigClangIntegerLiteral_EvaluateAsInt(*const IntegerLiteral, *ExprEvalResult, *const ASTContext) bool;

    pub const getBeginLoc = ZigClangIntegerLiteral_getBeginLoc;
    extern fn ZigClangIntegerLiteral_getBeginLoc(*const IntegerLiteral) SourceLocation;

    pub const isZero = ZigClangIntegerLiteral_isZero;
    extern fn ZigClangIntegerLiteral_isZero(*const IntegerLiteral, *bool, *const ASTContext) bool;
};

pub const MacroDefinitionRecord = opaque {
    pub const getName_getNameStart = ZigClangMacroDefinitionRecord_getName_getNameStart;
    extern fn ZigClangMacroDefinitionRecord_getName_getNameStart(*const MacroDefinitionRecord) [*:0]const u8;

    pub const getSourceRange_getBegin = ZigClangMacroDefinitionRecord_getSourceRange_getBegin;
    extern fn ZigClangMacroDefinitionRecord_getSourceRange_getBegin(*const MacroDefinitionRecord) SourceLocation;

    pub const getSourceRange_getEnd = ZigClangMacroDefinitionRecord_getSourceRange_getEnd;
    extern fn ZigClangMacroDefinitionRecord_getSourceRange_getEnd(*const MacroDefinitionRecord) SourceLocation;
};

pub const MacroQualifiedType = opaque {
    pub const getModifiedType = ZigClangMacroQualifiedType_getModifiedType;
    extern fn ZigClangMacroQualifiedType_getModifiedType(*const MacroQualifiedType) QualType;
};

pub const MemberExpr = opaque {
    pub const getBase = ZigClangMemberExpr_getBase;
    extern fn ZigClangMemberExpr_getBase(*const MemberExpr) *const Expr;

    pub const isArrow = ZigClangMemberExpr_isArrow;
    extern fn ZigClangMemberExpr_isArrow(*const MemberExpr) bool;

    pub const getMemberDecl = ZigClangMemberExpr_getMemberDecl;
    extern fn ZigClangMemberExpr_getMemberDecl(*const MemberExpr) *const ValueDecl;
};

pub const NamedDecl = opaque {
    pub const getName_bytes_begin = ZigClangNamedDecl_getName_bytes_begin;
    extern fn ZigClangNamedDecl_getName_bytes_begin(decl: *const NamedDecl) [*:0]const u8;
};

pub const None = opaque {};

pub const OpaqueValueExpr = opaque {
    pub const getSourceExpr = ZigClangOpaqueValueExpr_getSourceExpr;
    extern fn ZigClangOpaqueValueExpr_getSourceExpr(*const OpaqueValueExpr) ?*const Expr;
};

pub const PCHContainerOperations = opaque {};

pub const ParenExpr = opaque {
    pub const getSubExpr = ZigClangParenExpr_getSubExpr;
    extern fn ZigClangParenExpr_getSubExpr(*const ParenExpr) *const Expr;
};

pub const ParenType = opaque {
    pub const getInnerType = ZigClangParenType_getInnerType;
    extern fn ZigClangParenType_getInnerType(*const ParenType) QualType;
};

pub const ParmVarDecl = opaque {
    pub const getOriginalType = ZigClangParmVarDecl_getOriginalType;
    extern fn ZigClangParmVarDecl_getOriginalType(*const ParmVarDecl) QualType;
};

pub const PointerType = opaque {};

pub const PredefinedExpr = opaque {
    pub const getFunctionName = ZigClangPredefinedExpr_getFunctionName;
    extern fn ZigClangPredefinedExpr_getFunctionName(*const PredefinedExpr) *const StringLiteral;
};

pub const PreprocessedEntity = opaque {
    pub const getKind = ZigClangPreprocessedEntity_getKind;
    extern fn ZigClangPreprocessedEntity_getKind(*const PreprocessedEntity) PreprocessedEntity_EntityKind;
};

pub const PreprocessingRecord = opaque {
    pub const iterator = extern struct {
        I: c_int,
        Self: *PreprocessingRecord,

        pub const deref = ZigClangPreprocessingRecord_iterator_deref;
        extern fn ZigClangPreprocessingRecord_iterator_deref(iterator) *PreprocessedEntity;
    };
};

pub const RecordDecl = opaque {
    pub const getCanonicalDecl = ZigClangRecordDecl_getCanonicalDecl;
    extern fn ZigClangRecordDecl_getCanonicalDecl(*const RecordDecl) ?*const TagDecl;

    pub const isUnion = ZigClangRecordDecl_isUnion;
    extern fn ZigClangRecordDecl_isUnion(*const RecordDecl) bool;

    pub const isStruct = ZigClangRecordDecl_isStruct;
    extern fn ZigClangRecordDecl_isStruct(*const RecordDecl) bool;

    pub const isAnonymousStructOrUnion = ZigClangRecordDecl_isAnonymousStructOrUnion;
    extern fn ZigClangRecordDecl_isAnonymousStructOrUnion(record_decl: ?*const RecordDecl) bool;

    pub const getPackedAttribute = ZigClangRecordDecl_getPackedAttribute;
    extern fn ZigClangRecordDecl_getPackedAttribute(*const RecordDecl) bool;

    pub const getDefinition = ZigClangRecordDecl_getDefinition;
    extern fn ZigClangRecordDecl_getDefinition(*const RecordDecl) ?*const RecordDecl;

    pub const getLocation = ZigClangRecordDecl_getLocation;
    extern fn ZigClangRecordDecl_getLocation(*const RecordDecl) SourceLocation;

    pub const field_begin = ZigClangRecordDecl_field_begin;
    extern fn ZigClangRecordDecl_field_begin(*const RecordDecl) field_iterator;

    pub const field_end = ZigClangRecordDecl_field_end;
    extern fn ZigClangRecordDecl_field_end(*const RecordDecl) field_iterator;

    pub const field_iterator = extern struct {
        ptr: *c_void,

        pub const next = ZigClangRecordDecl_field_iterator_next;
        extern fn ZigClangRecordDecl_field_iterator_next(field_iterator) field_iterator;

        pub const deref = ZigClangRecordDecl_field_iterator_deref;
        extern fn ZigClangRecordDecl_field_iterator_deref(field_iterator) *const FieldDecl;

        pub const neq = ZigClangRecordDecl_field_iterator_neq;
        extern fn ZigClangRecordDecl_field_iterator_neq(field_iterator, field_iterator) bool;
    };
};

pub const RecordType = opaque {
    pub const getDecl = ZigClangRecordType_getDecl;
    extern fn ZigClangRecordType_getDecl(*const RecordType) *const RecordDecl;
};

pub const ReturnStmt = opaque {
    pub const getRetValue = ZigClangReturnStmt_getRetValue;
    extern fn ZigClangReturnStmt_getRetValue(*const ReturnStmt) ?*const Expr;
};

pub const SkipFunctionBodiesScope = opaque {};

pub const SourceManager = opaque {
    pub const getSpellingLoc = ZigClangSourceManager_getSpellingLoc;
    extern fn ZigClangSourceManager_getSpellingLoc(*const SourceManager, Loc: SourceLocation) SourceLocation;

    pub const getFilename = ZigClangSourceManager_getFilename;
    extern fn ZigClangSourceManager_getFilename(*const SourceManager, SpellingLoc: SourceLocation) ?[*:0]const u8;

    pub const getSpellingLineNumber = ZigClangSourceManager_getSpellingLineNumber;
    extern fn ZigClangSourceManager_getSpellingLineNumber(*const SourceManager, Loc: SourceLocation) c_uint;

    pub const getSpellingColumnNumber = ZigClangSourceManager_getSpellingColumnNumber;
    extern fn ZigClangSourceManager_getSpellingColumnNumber(*const SourceManager, Loc: SourceLocation) c_uint;

    pub const getCharacterData = ZigClangSourceManager_getCharacterData;
    extern fn ZigClangSourceManager_getCharacterData(*const SourceManager, SL: SourceLocation) [*:0]const u8;
};

pub const SourceRange = opaque {};

pub const Stmt = opaque {
    pub const getBeginLoc = ZigClangStmt_getBeginLoc;
    extern fn ZigClangStmt_getBeginLoc(*const Stmt) SourceLocation;

    pub const getStmtClass = ZigClangStmt_getStmtClass;
    extern fn ZigClangStmt_getStmtClass(*const Stmt) StmtClass;

    pub const classof_Expr = ZigClangStmt_classof_Expr;
    extern fn ZigClangStmt_classof_Expr(*const Stmt) bool;
};

pub const StmtExpr = opaque {
    pub const getSubStmt = ZigClangStmtExpr_getSubStmt;
    extern fn ZigClangStmtExpr_getSubStmt(*const StmtExpr) *const CompoundStmt;
};

pub const StringLiteral = opaque {
    pub const getKind = ZigClangStringLiteral_getKind;
    extern fn ZigClangStringLiteral_getKind(*const StringLiteral) StringLiteral_StringKind;

    pub const getCodeUnit = ZigClangStringLiteral_getCodeUnit;
    extern fn ZigClangStringLiteral_getCodeUnit(*const StringLiteral, usize) u32;

    pub const getLength = ZigClangStringLiteral_getLength;
    extern fn ZigClangStringLiteral_getLength(*const StringLiteral) c_uint;

    pub const getCharByteWidth = ZigClangStringLiteral_getCharByteWidth;
    extern fn ZigClangStringLiteral_getCharByteWidth(*const StringLiteral) c_uint;

    pub const getString_bytes_begin_size = ZigClangStringLiteral_getString_bytes_begin_size;
    extern fn ZigClangStringLiteral_getString_bytes_begin_size(*const StringLiteral, *usize) [*]const u8;
};

pub const StringRef = opaque {};

pub const SwitchStmt = opaque {
    pub const getConditionVariableDeclStmt = ZigClangSwitchStmt_getConditionVariableDeclStmt;
    extern fn ZigClangSwitchStmt_getConditionVariableDeclStmt(*const SwitchStmt) ?*const DeclStmt;

    pub const getCond = ZigClangSwitchStmt_getCond;
    extern fn ZigClangSwitchStmt_getCond(*const SwitchStmt) *const Expr;

    pub const getBody = ZigClangSwitchStmt_getBody;
    extern fn ZigClangSwitchStmt_getBody(*const SwitchStmt) *const Stmt;

    pub const isAllEnumCasesCovered = ZigClangSwitchStmt_isAllEnumCasesCovered;
    extern fn ZigClangSwitchStmt_isAllEnumCasesCovered(*const SwitchStmt) bool;
};

pub const TagDecl = opaque {
    pub const isThisDeclarationADefinition = ZigClangTagDecl_isThisDeclarationADefinition;
    extern fn ZigClangTagDecl_isThisDeclarationADefinition(*const TagDecl) bool;
};

pub const Type = opaque {
    pub const getTypeClass = ZigClangType_getTypeClass;
    extern fn ZigClangType_getTypeClass(*const Type) TypeClass;

    pub const getPointeeType = ZigClangType_getPointeeType;
    extern fn ZigClangType_getPointeeType(*const Type) QualType;

    pub const isVoidType = ZigClangType_isVoidType;
    extern fn ZigClangType_isVoidType(*const Type) bool;

    pub const isConstantArrayType = ZigClangType_isConstantArrayType;
    extern fn ZigClangType_isConstantArrayType(*const Type) bool;

    pub const isRecordType = ZigClangType_isRecordType;
    extern fn ZigClangType_isRecordType(*const Type) bool;

    pub const isIncompleteOrZeroLengthArrayType = ZigClangType_isIncompleteOrZeroLengthArrayType;
    extern fn ZigClangType_isIncompleteOrZeroLengthArrayType(*const Type, *const ASTContext) bool;

    pub const isArrayType = ZigClangType_isArrayType;
    extern fn ZigClangType_isArrayType(*const Type) bool;

    pub const isBooleanType = ZigClangType_isBooleanType;
    extern fn ZigClangType_isBooleanType(*const Type) bool;

    pub const getTypeClassName = ZigClangType_getTypeClassName;
    extern fn ZigClangType_getTypeClassName(*const Type) [*:0]const u8;

    pub const getAsArrayTypeUnsafe = ZigClangType_getAsArrayTypeUnsafe;
    extern fn ZigClangType_getAsArrayTypeUnsafe(*const Type) *const ArrayType;

    pub const getAsRecordType = ZigClangType_getAsRecordType;
    extern fn ZigClangType_getAsRecordType(*const Type) ?*const RecordType;

    pub const getAsUnionType = ZigClangType_getAsUnionType;
    extern fn ZigClangType_getAsUnionType(*const Type) ?*const RecordType;
};

pub const TypedefNameDecl = opaque {
    pub const getUnderlyingType = ZigClangTypedefNameDecl_getUnderlyingType;
    extern fn ZigClangTypedefNameDecl_getUnderlyingType(*const TypedefNameDecl) QualType;

    pub const getCanonicalDecl = ZigClangTypedefNameDecl_getCanonicalDecl;
    extern fn ZigClangTypedefNameDecl_getCanonicalDecl(*const TypedefNameDecl) ?*const TypedefNameDecl;

    pub const getLocation = ZigClangTypedefNameDecl_getLocation;
    extern fn ZigClangTypedefNameDecl_getLocation(*const TypedefNameDecl) SourceLocation;
};

pub const TypedefType = opaque {
    pub const getDecl = ZigClangTypedefType_getDecl;
    extern fn ZigClangTypedefType_getDecl(*const TypedefType) *const TypedefNameDecl;
};

pub const UnaryExprOrTypeTraitExpr = opaque {
    pub const getTypeOfArgument = ZigClangUnaryExprOrTypeTraitExpr_getTypeOfArgument;
    extern fn ZigClangUnaryExprOrTypeTraitExpr_getTypeOfArgument(*const UnaryExprOrTypeTraitExpr) QualType;

    pub const getBeginLoc = ZigClangUnaryExprOrTypeTraitExpr_getBeginLoc;
    extern fn ZigClangUnaryExprOrTypeTraitExpr_getBeginLoc(*const UnaryExprOrTypeTraitExpr) SourceLocation;

    pub const getKind = ZigClangUnaryExprOrTypeTraitExpr_getKind;
    extern fn ZigClangUnaryExprOrTypeTraitExpr_getKind(*const UnaryExprOrTypeTraitExpr) UnaryExprOrTypeTrait_Kind;
};

pub const UnaryOperator = opaque {
    pub const getOpcode = ZigClangUnaryOperator_getOpcode;
    extern fn ZigClangUnaryOperator_getOpcode(*const UnaryOperator) UO;

    pub const getType = ZigClangUnaryOperator_getType;
    extern fn ZigClangUnaryOperator_getType(*const UnaryOperator) QualType;

    pub const getSubExpr = ZigClangUnaryOperator_getSubExpr;
    extern fn ZigClangUnaryOperator_getSubExpr(*const UnaryOperator) *const Expr;

    pub const getBeginLoc = ZigClangUnaryOperator_getBeginLoc;
    extern fn ZigClangUnaryOperator_getBeginLoc(*const UnaryOperator) SourceLocation;
};

pub const ValueDecl = opaque {};

pub const VarDecl = opaque {
    pub const getLocation = ZigClangVarDecl_getLocation;
    extern fn ZigClangVarDecl_getLocation(*const VarDecl) SourceLocation;

    pub const hasInit = ZigClangVarDecl_hasInit;
    extern fn ZigClangVarDecl_hasInit(*const VarDecl) bool;

    pub const getStorageClass = ZigClangVarDecl_getStorageClass;
    extern fn ZigClangVarDecl_getStorageClass(*const VarDecl) StorageClass;

    pub const getType = ZigClangVarDecl_getType;
    extern fn ZigClangVarDecl_getType(*const VarDecl) QualType;

    pub const getInit = ZigClangVarDecl_getInit;
    extern fn ZigClangVarDecl_getInit(*const VarDecl) ?*const Expr;

    pub const getTLSKind = ZigClangVarDecl_getTLSKind;
    extern fn ZigClangVarDecl_getTLSKind(*const VarDecl) VarDecl_TLSKind;

    pub const getCanonicalDecl = ZigClangVarDecl_getCanonicalDecl;
    extern fn ZigClangVarDecl_getCanonicalDecl(*const VarDecl) ?*const VarDecl;

    pub const getSectionAttribute = ZigClangVarDecl_getSectionAttribute;
    extern fn ZigClangVarDecl_getSectionAttribute(*const VarDecl, len: *usize) ?[*]const u8;

    pub const getAlignedAttribute = ZigClangVarDecl_getAlignedAttribute;
    extern fn ZigClangVarDecl_getAlignedAttribute(*const VarDecl, *const ASTContext) c_uint;

    pub const getTypeSourceInfo_getType = ZigClangVarDecl_getTypeSourceInfo_getType;
    extern fn ZigClangVarDecl_getTypeSourceInfo_getType(*const VarDecl) QualType;
};

pub const WhileStmt = opaque {
    pub const getCond = ZigClangWhileStmt_getCond;
    extern fn ZigClangWhileStmt_getCond(*const WhileStmt) *const Expr;

    pub const getBody = ZigClangWhileStmt_getBody;
    extern fn ZigClangWhileStmt_getBody(*const WhileStmt) *const Stmt;
};

pub const InitListExpr = opaque {
    pub const getInit = ZigClangInitListExpr_getInit;
    extern fn ZigClangInitListExpr_getInit(*const InitListExpr, i: c_uint) *const Expr;

    pub const getArrayFiller = ZigClangInitListExpr_getArrayFiller;
    extern fn ZigClangInitListExpr_getArrayFiller(*const InitListExpr) *const Expr;

    pub const getNumInits = ZigClangInitListExpr_getNumInits;
    extern fn ZigClangInitListExpr_getNumInits(*const InitListExpr) c_uint;

    pub const getInitializedFieldInUnion = ZigClangInitListExpr_getInitializedFieldInUnion;
    extern fn ZigClangInitListExpr_getInitializedFieldInUnion(*const InitListExpr) ?*FieldDecl;
};

pub const BO = extern enum {
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

pub const UO = extern enum {
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

pub const TypeClass = extern enum {
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
    DependentExtInt,
    DependentName,
    DependentSizedExtVector,
    DependentTemplateSpecialization,
    DependentVector,
    Elaborated,
    ExtInt,
    FunctionNoProto,
    FunctionProto,
    InjectedClassName,
    MacroQualified,
    ConstantMatrix,
    DependentSizedMatrix,
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

const StmtClass = extern enum {
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
    OMPDepobjDirectiveClass,
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
    OMPScanDirectiveClass,
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
    CXXAddrspaceCastExprClass,
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
    MatrixSubscriptExprClass,
    MemberExprClass,
    NoInitExprClass,
    OMPArraySectionExprClass,
    OMPArrayShapingExprClass,
    OMPIteratorExprClass,
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
    RecoveryExprClass,
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

pub const CK = extern enum {
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

pub const DeclKind = extern enum {
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
    MSGuid,
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

pub const BuiltinTypeKind = extern enum {
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
    SveBFloat16,
    SveInt8x2,
    SveInt16x2,
    SveInt32x2,
    SveInt64x2,
    SveUint8x2,
    SveUint16x2,
    SveUint32x2,
    SveUint64x2,
    SveFloat16x2,
    SveFloat32x2,
    SveFloat64x2,
    SveBFloat16x2,
    SveInt8x3,
    SveInt16x3,
    SveInt32x3,
    SveInt64x3,
    SveUint8x3,
    SveUint16x3,
    SveUint32x3,
    SveUint64x3,
    SveFloat16x3,
    SveFloat32x3,
    SveFloat64x3,
    SveBFloat16x3,
    SveInt8x4,
    SveInt16x4,
    SveInt32x4,
    SveInt64x4,
    SveUint8x4,
    SveUint16x4,
    SveUint32x4,
    SveUint64x4,
    SveFloat16x4,
    SveFloat32x4,
    SveFloat64x4,
    SveBFloat16x4,
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
    BFloat16,
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
    IncompleteMatrixIdx,
    OMPArraySection,
    OMPArrayShaping,
    OMPIterator,
};

pub const CallingConv = extern enum {
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

pub const StorageClass = extern enum {
    None,
    Extern,
    Static,
    PrivateExtern,
    Auto,
    Register,
};

pub const APFloat_roundingMode = extern enum(i8) {
    TowardZero = 0,
    NearestTiesToEven = 1,
    TowardPositive = 2,
    TowardNegative = 3,
    NearestTiesToAway = 4,
    Dynamic = 7,
    Invalid = -1,
};

pub const StringLiteral_StringKind = extern enum {
    Ascii,
    Wide,
    UTF8,
    UTF16,
    UTF32,
};

pub const CharacterLiteral_CharacterKind = extern enum {
    Ascii,
    Wide,
    UTF8,
    UTF16,
    UTF32,
};

pub const VarDecl_TLSKind = extern enum {
    None,
    Static,
    Dynamic,
};

pub const ElaboratedTypeKeyword = extern enum {
    Struct,
    Interface,
    Union,
    Class,
    Enum,
    Typename,
    None,
};

pub const PreprocessedEntity_EntityKind = extern enum {
    InvalidKind,
    MacroExpansionKind,
    MacroDefinitionKind,
    InclusionDirectiveKind,
};

pub const Expr_ConstExprUsage = extern enum {
    EvaluateForCodeGen,
    EvaluateForMangling,
};

pub const UnaryExprOrTypeTrait_Kind = extern enum {
    SizeOf,
    AlignOf,
    VecStep,
    OpenMPRequiredSimdAlign,
    PreferredAlignOf,
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

    pub const delete = ZigClangErrorMsg_delete;
    extern fn ZigClangErrorMsg_delete(ptr: [*]Stage2ErrorMsg, len: usize) void;
};

pub const LoadFromCommandLine = ZigClangLoadFromCommandLine;
extern fn ZigClangLoadFromCommandLine(
    args_begin: [*]?[*]const u8,
    args_end: [*]?[*]const u8,
    errors_ptr: *[*]Stage2ErrorMsg,
    errors_len: *usize,
    resources_path: [*:0]const u8,
) ?*ASTUnit;
