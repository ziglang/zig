/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */
#ifndef __CORHDR_H__
#define __CORHDR_H__

#ifdef __cplusplus
extern "C" {
#endif

typedef enum CorTypeAttr {
  tdVisibilityMask = 0x7,
  tdNotPublic = 0x0,
  tdPublic = 0x1,
  tdNestedPublic = 0x2,
  tdNestedPrivate = 0x3,
  tdNestedFamily = 0x4,
  tdNestedAssembly = 0x5,
  tdNestedFamANDAssem = 0x6,
  tdNestedFamORAssem = 0x7,
  tdLayoutMask = 0x18,
  tdAutoLayout = 0x0,
  tdSequentialLayout = 0x8,
  tdExplicitLayout = 0x10,
  tdClassSemanticsMask = 0x20,
  tdClass = 0x0,
  tdInterface = 0x20,
  tdAbstract = 0x80,
  tdSealed = 0x100,
  tdSpecialName = 0x400,
  tdImport = 0x1000,
  tdSerializable = 0x2000,
  tdWindowsRuntime = 0x4000,
  tdStringFormatMask = 0x30000,
  tdAnsiClass = 0x0,
  tdUnicodeClass = 0x10000,
  tdAutoClass = 0x20000,
  tdCustomFormatClass = 0x30000,
  tdCustomFormatMask = 0xc00000,
  tdBeforeFieldInit = 0x100000,
  tdForwarder = 0x200000,
  tdReservedMask = 0x40800,
  tdRTSpecialName = 0x800,
  tdHasSecurity = 0x40000
} CorTypeAttr;

typedef enum CorMethodAttr {
  mdMemberAccessMask = 0x0007,
  mdPrivateScope = 0x0,
  mdPrivate = 0x1,
  mdFamANDAssem = 0x2,
  mdAssem = 0x3,
  mdFamily = 0x4,
  mdFamORAssem = 0x5,
  mdPublic = 0x6,
  mdUnmanagedExport = 0x8,
  mdStatic = 0x10,
  mdFinal = 0x20,
  mdVirtual = 0x40,
  mdHideBySig = 0x80,
  mdVtableLayoutMask = 0x100,
  mdReuseSlot = 0x0,
  mdNewSlot = 0x100,
  mdCheckAccessOnOverride = 0x200,
  mdAbstract = 0x400,
  mdSpecialName = 0x800,
  mdPinvokeImpl = 0x2000,
  mdReservedMask = 0xd000,
  mdRTSpecialName = 0x1000,
  mdHasSecurity = 0x4000,
  mdRequireSecObject = 0x8000
} CorMethodAttr;

#ifndef __IMAGE_COR20_HEADER_DEFINED__
#define __IMAGE_COR20_HEADER_DEFINED__
typedef enum ReplacesCorHdrNumericDefines {
  COMIMAGE_FLAGS_ILONLY = 0x1,
  COMIMAGE_FLAGS_32BITREQUIRED = 0x2,
  COMIMAGE_FLAGS_IL_LIBRARY = 0x4,
  COMIMAGE_FLAGS_STRONGNAMESIGNED = 0x8,
  COMIMAGE_FLAGS_NATIVE_ENTRYPOINT = 0x10,
  COMIMAGE_FLAGS_TRACKDEBUGDATA = 0x10000,
  COMIMAGE_FLAGS_32BITPREFERRED = 0x20000,
  COR_VERSION_MAJOR_V2 = 2,
  COR_VERSION_MAJOR = COR_VERSION_MAJOR_V2,
  COR_VERSION_MINOR = 5,
  COR_DELETED_NAME_LENGTH = 8,
  COR_VTABLEGAP_NAME_LENGTH = 8,
  NATIVE_TYPE_MAX_CB = 1,
  COR_ILMETHOD_SECT_SMALL_MAX_DATASIZE = 0xff,
  COR_VTABLE_32BIT = 0x1,
  COR_VTABLE_64BIT = 0x2,
  COR_VTABLE_FROM_UNMANAGED = 0x4,
  COR_VTABLE_FROM_UNMANAGED_RETAIN_APPDOMAIN = 0x8,
  COR_VTABLE_CALL_MOST_DERIVED = 0x10,
  MAX_CLASS_NAME = 1024,
  MAX_PACKAGE_NAME = 1024
} ReplacesCorHdrNumericDefines;

typedef struct IMAGE_COR20_HEADER {
  DWORD cb;
  WORD MajorRuntimeVersion;
  WORD MinorRuntimeVersion;
  IMAGE_DATA_DIRECTORY MetaData;
  DWORD Flags;
  __C89_NAMELESS union {
    DWORD EntryPointToken;
    DWORD EntryPointRVA;
  };
  IMAGE_DATA_DIRECTORY Resources;
  IMAGE_DATA_DIRECTORY StrongNameSignature;
  IMAGE_DATA_DIRECTORY CodeManagerTable;
  IMAGE_DATA_DIRECTORY VTableFixups;
  IMAGE_DATA_DIRECTORY ExportAddressTableJumps;
  IMAGE_DATA_DIRECTORY ManagedNativeHeader;
} IMAGE_COR20_HEADER,*PIMAGE_COR20_HEADER;
#else
#define COR_VTABLE_FROM_UNMANAGED_RETAIN_APPDOMAIN 0x8
#define COMIMAGE_FLAGS_32BITPREFERRED 0x20000
#endif

typedef enum CorFieldAttr {
  fdFieldAccessMask = 0x0007,
  fdPrivateScope = 0x0000,
  fdPrivate = 0x0001,
  fdFamANDAssem = 0x0002,
  fdAssembly = 0x0003,
  fdFamily = 0x0004,
  fdFamORAssem = 0x0005,
  fdPublic = 0x0006,

  fdStatic = 0x0010,
  fdInitOnly = 0x0020,
  fdLiteral = 0x0040,
  fdNotSerialized = 0x0080,
  fdHasFieldRVA = 0x0100,
  fdSpecialName = 0x0200,
  fdRTSpecialName = 0x0400,
  fdHasFieldMarshal = 0x1000,
  fdPinvokeImpl = 0x2000,
  fdHasDefault = 0x8000,
  fdReservedMask = 0x9500
} CorFieldAttr;

typedef enum CorParamAttr {
  pdIn = 0x1,
  pdOut = 0x2,
  pdOptional = 0x10,
  pdReservedMask = 0xf000,
  pdHasDefault = 0x1000,
  pdHasFieldMarshal = 0x2000,
  pdUnused = 0xcfe0
} CorParamAttr;

typedef enum CorPropertyAttr {
  prReservedMask = 0xf400,
  prSpecialName = 0x0200,
  prRTSpecialName = 0x0400,
  prHasDefault = 0x1000,
  prUnused = 0xe9ff
} CorPropertyAttr;

typedef enum CorEventAttr {
  evSpecialName = 0x0200,
  evReservedMask = 0x0400,
  evRTSpecialName = 0x0400
} CorEventAttr;

typedef enum CorMethodSemanticsAttr {
  msSetter = 0x1,
  msGetter = 0x2,
  msOther = 0x4,
  msAddOn = 0x8,
  msRemoveOn = 0x10,
  msFire = 0x20
} CorMethodSemanticsAttr;

typedef enum CorDeclSecurity {
  dclActionMask = 0x001f,
  dclActionNil = 0x0000,
  dclRequest = 0x0001,
  dclDemand = 0x0002,
  dclAssert = 0x0003,
  dclDeny = 0x0004,
  dclPermitOnly = 0x0005,
  dclLinktimeCheck = 0x0006,
  dclInheritanceCheck = 0x0007,
  dclRequestMinimum = 0x0008,
  dclRequestOptional = 0x0009,
  dclRequestRefuse = 0x000a,
  dclPrejitGrant = 0x000b,
  dclPrejitDenied = 0x000c,
  dclNonCasDemand = 0x000d,
  dclNonCasLinkDemand = 0x000e,
  dclNonCasInheritance = 0x000f,
  dclMaximumValue = 0x000f
} CorDeclSecurity;

typedef enum CorMethodImpl {
  miCodeTypeMask = 0x0003,
  miIL = 0x0000,
  miNative = 0x0001,
  miOPTIL = 0x0002,
  miRuntime = 0x0003,
  miManagedMask = 0x0004,
  miUnmanaged = 0x0004,
  miManaged = 0x0,
  miNoInlining = 0x0008,
  miForwardRef = 0x0010,
  miSynchronized = 0x0020,
  miNoOptimization = 0x0040,
  miPreserveSig = 0x0080,
  miAggressiveInlining = 0x0100,
  miInternalCall = 0x1000,
  miUserMask = miManagedMask | miForwardRef | miPreserveSig | miInternalCall | miSynchronized | miNoInlining | miAggressiveInlining | miNoOptimization,
  miMaxMethodImplVal = 0xffff
} CorMethodImpl;

typedef enum CorPinvokeMap {
  pmNoMangle = 0x0001,
  pmCharSetMask = 0x0006,
  pmCharSetNotSpec = 0x0,
  pmCharSetAnsi = 0x0002,
  pmCharSetUnicode = 0x0004,
  pmCharSetAuto = 0x0006,
  pmBestFitMask = 0x0030,
  pmBestFitUseAssem = 0x0,
  pmBestFitEnabled = 0x0010,
  pmBestFitDisabled = 0x0020,
  pmSupportsLastError = 0x0040,
  pmCallConvMask = 0x0700,
  pmCallConvWinapi = 0x0100,
  pmCallConvCdecl = 0x0200,
  pmCallConvStdcall = 0x0300,
  pmCallConvThiscall = 0x0400,
  pmCallConvFastcall = 0x0500,
  pmThrowOnUnmappableCharMask = 0x3000,
  pmThrowOnUnmappableCharUseAssem = 0x0,
  pmThrowOnUnmappableCharEnabled = 0x1000,
  pmThrowOnUnmappableCharDisabled = 0x2000,
  pmMaxValue = 0xffff
} CorPinvokeMap;

typedef enum CorAssemblyFlags {
  afPublicKey = 0x0001,
  afPA_Mask = 0x0070,
  afPA_FullMask = 0x00f0,
  afPA_None = 0x0,
  afPA_MSIL = 0x0010,
  afPA_x86 = 0x0020,
  afPA_IA64 = 0x0030,
  afPA_AMD64 = 0x0040,
  afPA_ARM = 0x0050,
  afPA_NoPlatform = 0x0070,
  afPA_Specified = 0x0080,
  afPA_Shift = 0x0004,
  afRetargetable = 0x0100,
  afContentType_Mask = 0x0e00,
  afContentType_Default = 0x0,
  afContentType_WindowsRuntime = 0x0200,
  afEnableJITcompileTracking = 0x8000,
  afDisableJITcompileOptimizer = 0x4000
} CorAssemblyFlags;

typedef enum CorManifestResourceFlags {
  mrVisibilityMask = 0x0007,
  mrPublic = 0x0001,
  mrPrivate = 0x0002
} CorManifestResourceFlags;

typedef enum CorFileFlags {
  ffContainsMetaData = 0x0000,
  ffContainsNoMetaData = 0x0001
} CorFileFlags;

typedef enum CorPEKind {
  peNot = 0x00000000,
  peILonly = 0x00000001,
  pe32BitRequired=0x00000002,
  pe32Plus = 0x00000004,
  pe32Unmanaged=0x00000008,
  pe32BitPreferred=0x00000010
} CorPEKind;

typedef enum CorGenericParamAttr {
  gpVarianceMask = 0x0003,
  gpNonVariant = 0x0000,
  gpCovariant = 0x0001,
  gpContravariant = 0x0002,
  gpSpecialConstraintMask = 0x001c,
  gpNoSpecialConstraint = 0x0000,
  gpReferenceTypeConstraint = 0x0004,
  gpNotNullableValueTypeConstraint = 0x0008,
  gpDefaultConstructorConstraint = 0x0010
} CorGenericParamAttr;

typedef enum CorElementType {
  ELEMENT_TYPE_END = 0x00,
  ELEMENT_TYPE_VOID = 0x01,
  ELEMENT_TYPE_BOOLEAN = 0x02,
  ELEMENT_TYPE_CHAR = 0x03,
  ELEMENT_TYPE_I1 = 0x04,
  ELEMENT_TYPE_U1 = 0x05,
  ELEMENT_TYPE_I2 = 0x06,
  ELEMENT_TYPE_U2 = 0x07,
  ELEMENT_TYPE_I4 = 0x08,
  ELEMENT_TYPE_U4 = 0x09,
  ELEMENT_TYPE_I8 = 0x0a,
  ELEMENT_TYPE_U8 = 0x0b,
  ELEMENT_TYPE_R4 = 0x0c,
  ELEMENT_TYPE_R8 = 0x0d,
  ELEMENT_TYPE_STRING = 0x0e,
  ELEMENT_TYPE_PTR = 0x0f,
  ELEMENT_TYPE_BYREF = 0x10,
  ELEMENT_TYPE_VALUETYPE = 0x11,
  ELEMENT_TYPE_CLASS = 0x12,
  ELEMENT_TYPE_VAR = 0x13,
  ELEMENT_TYPE_ARRAY = 0x14,
  ELEMENT_TYPE_GENERICINST = 0x15,
  ELEMENT_TYPE_TYPEDBYREF = 0x16,
  ELEMENT_TYPE_I = 0x18,
  ELEMENT_TYPE_U = 0x19,
  ELEMENT_TYPE_FNPTR = 0x1b,
  ELEMENT_TYPE_OBJECT = 0x1c,
  ELEMENT_TYPE_SZARRAY = 0x1d,
  ELEMENT_TYPE_MVAR = 0x1e,
  ELEMENT_TYPE_CMOD_REQD = 0x1f,
  ELEMENT_TYPE_CMOD_OPT = 0x20,
  ELEMENT_TYPE_INTERNAL = 0x21,
  ELEMENT_TYPE_MAX = 0x22,
  ELEMENT_TYPE_MODIFIER = 0x40,
  ELEMENT_TYPE_SENTINEL = 0x01 | ELEMENT_TYPE_MODIFIER,
  ELEMENT_TYPE_PINNED = 0x05 | ELEMENT_TYPE_MODIFIER
} CorElementType;

typedef enum CorSerializationType {
  SERIALIZATION_TYPE_UNDEFINED = 0,
  SERIALIZATION_TYPE_BOOLEAN = ELEMENT_TYPE_BOOLEAN,
  SERIALIZATION_TYPE_CHAR = ELEMENT_TYPE_CHAR,
  SERIALIZATION_TYPE_I1 = ELEMENT_TYPE_I1,
  SERIALIZATION_TYPE_U1 = ELEMENT_TYPE_U1,
  SERIALIZATION_TYPE_I2 = ELEMENT_TYPE_I2,
  SERIALIZATION_TYPE_U2 = ELEMENT_TYPE_U2,
  SERIALIZATION_TYPE_I4 = ELEMENT_TYPE_I4,
  SERIALIZATION_TYPE_U4 = ELEMENT_TYPE_U4,
  SERIALIZATION_TYPE_I8 = ELEMENT_TYPE_I8,
  SERIALIZATION_TYPE_U8 = ELEMENT_TYPE_U8,
  SERIALIZATION_TYPE_R4 = ELEMENT_TYPE_R4,
  SERIALIZATION_TYPE_R8 = ELEMENT_TYPE_R8,
  SERIALIZATION_TYPE_STRING = ELEMENT_TYPE_STRING,
  SERIALIZATION_TYPE_SZARRAY = ELEMENT_TYPE_SZARRAY,
  SERIALIZATION_TYPE_TYPE = 0x50,
  SERIALIZATION_TYPE_TAGGED_OBJECT= 0x51,
  SERIALIZATION_TYPE_FIELD = 0x53,
  SERIALIZATION_TYPE_PROPERTY = 0x54,
  SERIALIZATION_TYPE_ENUM = 0x55
} CorSerializationType;

typedef enum CorCallingConvention {
  IMAGE_CEE_CS_CALLCONV_DEFAULT = 0x0,
  IMAGE_CEE_CS_CALLCONV_VARARG = 0x5,
  IMAGE_CEE_CS_CALLCONV_FIELD = 0x6,
  IMAGE_CEE_CS_CALLCONV_LOCAL_SIG = 0x7,
  IMAGE_CEE_CS_CALLCONV_PROPERTY = 0x8,
  IMAGE_CEE_CS_CALLCONV_UNMGD = 0x9,
  IMAGE_CEE_CS_CALLCONV_GENERICINST = 0xa,
  IMAGE_CEE_CS_CALLCONV_NATIVEVARARG = 0xb,
  IMAGE_CEE_CS_CALLCONV_MAX = 0xc,
  IMAGE_CEE_CS_CALLCONV_MASK = 0x0f,
  IMAGE_CEE_CS_CALLCONV_HASTHIS = 0x20,
  IMAGE_CEE_CS_CALLCONV_EXPLICITTHIS = 0x40,
  IMAGE_CEE_CS_CALLCONV_GENERIC = 0x10
} CorCallingConvention;

typedef enum CorUnmanagedCallingConvention {
  IMAGE_CEE_UNMANAGED_CALLCONV_C = 0x1,
  IMAGE_CEE_UNMANAGED_CALLCONV_STDCALL = 0x2,
  IMAGE_CEE_UNMANAGED_CALLCONV_THISCALL = 0x3,
  IMAGE_CEE_UNMANAGED_CALLCONV_FASTCALL = 0x4,
  IMAGE_CEE_CS_CALLCONV_C = IMAGE_CEE_UNMANAGED_CALLCONV_C,
  IMAGE_CEE_CS_CALLCONV_STDCALL = IMAGE_CEE_UNMANAGED_CALLCONV_STDCALL,
  IMAGE_CEE_CS_CALLCONV_THISCALL = IMAGE_CEE_UNMANAGED_CALLCONV_THISCALL,
  IMAGE_CEE_CS_CALLCONV_FASTCALL = IMAGE_CEE_UNMANAGED_CALLCONV_FASTCALL
} CorUnmanagedCallingConvention;

typedef enum CorArgType {
  IMAGE_CEE_CS_END = 0x0,
  IMAGE_CEE_CS_VOID = 0x1,
  IMAGE_CEE_CS_I4 = 0x2,
  IMAGE_CEE_CS_I8 = 0x3,
  IMAGE_CEE_CS_R4 = 0x4,
  IMAGE_CEE_CS_R8 = 0x5,
  IMAGE_CEE_CS_PTR = 0x6,
  IMAGE_CEE_CS_OBJECT = 0x7,
  IMAGE_CEE_CS_STRUCT4 = 0x8,
  IMAGE_CEE_CS_STRUCT32 = 0x9,
  IMAGE_CEE_CS_BYVALUE = 0xa
} CorArgType;

typedef enum CorNativeType {
  NATIVE_TYPE_END = 0x0,
  NATIVE_TYPE_VOID = 0x1,
  NATIVE_TYPE_BOOLEAN = 0x2,
  NATIVE_TYPE_I1 = 0x3,
  NATIVE_TYPE_U1 = 0x4,
  NATIVE_TYPE_I2 = 0x5,
  NATIVE_TYPE_U2 = 0x6,
  NATIVE_TYPE_I4 = 0x7,
  NATIVE_TYPE_U4 = 0x8,
  NATIVE_TYPE_I8 = 0x9,
  NATIVE_TYPE_U8 = 0xa,
  NATIVE_TYPE_R4 = 0xb,
  NATIVE_TYPE_R8 = 0xc,
  NATIVE_TYPE_SYSCHAR = 0xd,
  NATIVE_TYPE_VARIANT = 0xe,
  NATIVE_TYPE_CURRENCY = 0xf,
  NATIVE_TYPE_PTR = 0x10,
  NATIVE_TYPE_DECIMAL = 0x11,
  NATIVE_TYPE_DATE = 0x12,
  NATIVE_TYPE_BSTR = 0x13,
  NATIVE_TYPE_LPSTR = 0x14,
  NATIVE_TYPE_LPWSTR = 0x15,
  NATIVE_TYPE_LPTSTR = 0x16,
  NATIVE_TYPE_FIXEDSYSSTRING = 0x17,
  NATIVE_TYPE_OBJECTREF = 0x18,
  NATIVE_TYPE_IUNKNOWN = 0x19,
  NATIVE_TYPE_IDISPATCH = 0x1a,
  NATIVE_TYPE_STRUCT = 0x1b,
  NATIVE_TYPE_INTF = 0x1c,
  NATIVE_TYPE_SAFEARRAY = 0x1d,
  NATIVE_TYPE_FIXEDARRAY = 0x1e,
  NATIVE_TYPE_INT = 0x1f,
  NATIVE_TYPE_UINT = 0x20,
  NATIVE_TYPE_NESTEDSTRUCT = 0x21,
  NATIVE_TYPE_BYVALSTR = 0x22,
  NATIVE_TYPE_ANSIBSTR = 0x23,
  NATIVE_TYPE_TBSTR = 0x24,
  NATIVE_TYPE_VARIANTBOOL = 0x25,
  NATIVE_TYPE_FUNC = 0x26,
  NATIVE_TYPE_ASANY = 0x28,
  NATIVE_TYPE_ARRAY = 0x2a,
  NATIVE_TYPE_LPSTRUCT = 0x2b,
  NATIVE_TYPE_CUSTOMMARSHALER = 0x2c,
  NATIVE_TYPE_ERROR = 0x2d,
  NATIVE_TYPE_IINSPECTABLE = 0x2e,
  NATIVE_TYPE_HSTRING = 0x2f,
  NATIVE_TYPE_MAX = 0x50
} CorNativeType;

typedef enum CorDescrGroupMethodType {
  DESCR_GROUP_METHODDEF = 0,
  DESCR_GROUP_METHODIMPL = 1
} CorDescrGroupMethodType;

typedef enum CorILMethodSect {
  CorILMethod_Sect_KindMask = 0x3f,
  CorILMethod_Sect_Reserved = 0,
  CorILMethod_Sect_EHTable = 1,
  CorILMethod_Sect_OptILTable = 2,
  CorILMethod_Sect_FatFormat = 0x40,
  CorILMethod_Sect_MoreSects = 0x80
} CorILMethodSect;

typedef enum CorILMethodFlags {
  CorILMethod_InitLocals = 0x0010,
  CorILMethod_MoreSects = 0x0008,
  CorILMethod_CompressedIL = 0x0040,
  CorILMethod_FormatShift = 3,
  CorILMethod_FormatMask = 0x0007,
  CorILMethod_SmallFormat = 0x0,
  CorILMethod_TinyFormat = 0x0002,
  CorILMethod_FatFormat = 0x0003,
  CorILMethod_TinyFormat1 = 0x0006
} CorILMethodFlags;

typedef enum CorExceptionFlag {
  COR_ILEXCEPTION_CLAUSE_NONE,
  COR_ILEXCEPTION_CLAUSE_OFFSETLEN = 0x0,
  COR_ILEXCEPTION_CLAUSE_DEPRECATED = 0x0,
  COR_ILEXCEPTION_CLAUSE_FILTER = 0x1,
  COR_ILEXCEPTION_CLAUSE_FINALLY = 0x2,
  COR_ILEXCEPTION_CLAUSE_FAULT = 0x4,
  COR_ILEXCEPTION_CLAUSE_DUPLICATED = 0x8
} CorExceptionFlag;

typedef enum CorCheckDuplicatesFor {
  MDDupAll = 0xffffffff,
  MDDupENC = MDDupAll,
  MDNoDupChecks = 0x00000000,
  MDDupTypeDef = 0x00000001,
  MDDupInterfaceImpl = 0x00000002,
  MDDupMethodDef = 0x00000004,
  MDDupTypeRef = 0x00000008,
  MDDupMemberRef = 0x00000010,
  MDDupCustomAttribute = 0x00000020,
  MDDupParamDef = 0x00000040,
  MDDupPermission = 0x00000080,
  MDDupProperty = 0x00000100,
  MDDupEvent = 0x00000200,
  MDDupFieldDef = 0x00000400,
  MDDupSignature = 0x00000800,
  MDDupModuleRef = 0x00001000,
  MDDupTypeSpec = 0x00002000,
  MDDupImplMap = 0x00004000,
  MDDupAssemblyRef = 0x00008000,
  MDDupFile = 0x00010000,
  MDDupExportedType = 0x00020000,
  MDDupManifestResource = 0x00040000,
  MDDupGenericParam = 0x00080000,
  MDDupMethodSpec = 0x00100000,
  MDDupGenericParamConstraint = 0x00200000,
  MDDupAssembly = 0x10000000,
  MDDupDefault = MDNoDupChecks | MDDupTypeRef | MDDupMemberRef | MDDupSignature | MDDupTypeSpec | MDDupMethodSpec
} CorCheckDuplicatesFor;

typedef enum CorRefToDefCheck {
  MDRefToDefDefault = 0x00000003,
  MDRefToDefAll = 0xffffffff,
  MDRefToDefNone = 0x00000000,
  MDTypeRefToDef = 0x00000001,
  MDMemberRefToDef = 0x00000002
} CorRefToDefCheck;

typedef enum CorNotificationForTokenMovement {
  MDNotifyDefault = 0x0000000f,
  MDNotifyAll = 0xffffffff,
  MDNotifyNone = 0x00000000,
  MDNotifyMethodDef = 0x00000001,
  MDNotifyMemberRef = 0x00000002,
  MDNotifyFieldDef = 0x00000004,
  MDNotifyTypeRef = 0x00000008,
  MDNotifyTypeDef = 0x00000010,
  MDNotifyParamDef = 0x00000020,
  MDNotifyInterfaceImpl = 0x00000040,
  MDNotifyProperty = 0x00000080,
  MDNotifyEvent = 0x00000100,
  MDNotifySignature = 0x00000200,
  MDNotifyTypeSpec = 0x00000400,
  MDNotifyCustomAttribute = 0x00000800,
  MDNotifySecurityValue = 0x00001000,
  MDNotifyPermission = 0x00002000,
  MDNotifyModuleRef = 0x00004000,
  MDNotifyNameSpace = 0x00008000,
  MDNotifyAssemblyRef = 0x01000000,
  MDNotifyFile = 0x02000000,
  MDNotifyExportedType = 0x04000000,
  MDNotifyResource = 0x08000000
} CorNotificationForTokenMovement;

typedef enum CorSetENC {
  MDSetENCOn = 0x00000001,
  MDSetENCOff = 0x00000002,
  MDUpdateENC = 0x00000001,
  MDUpdateFull = 0x00000002,
  MDUpdateExtension = 0x00000003,
  MDUpdateIncremental = 0x00000004,
  MDUpdateDelta = 0x00000005,
  MDUpdateMask = 0x00000007
} CorSetENC;

typedef enum CorErrorIfEmitOutOfOrder {
  MDErrorOutOfOrderDefault = 0x00000000,
  MDErrorOutOfOrderNone = 0x00000000,
  MDErrorOutOfOrderAll = 0xffffffff,
  MDMethodOutOfOrder = 0x00000001,
  MDFieldOutOfOrder = 0x00000002,
  MDParamOutOfOrder = 0x00000004,
  MDPropertyOutOfOrder = 0x00000008,
  MDEventOutOfOrder = 0x00000010
} CorErrorIfEmitOutOfOrder;

typedef enum CorImportOptions {
  MDImportOptionDefault = 0x00000000,
  MDImportOptionAll = 0xffffffff,
  MDImportOptionAllTypeDefs = 0x00000001,
  MDImportOptionAllMethodDefs = 0x00000002,
  MDImportOptionAllFieldDefs = 0x00000004,
  MDImportOptionAllProperties = 0x00000008,
  MDImportOptionAllEvents = 0x00000010,
  MDImportOptionAllCustomAttributes = 0x00000020,
  MDImportOptionAllExportedTypes = 0x00000040
} CorImportOptions;

typedef enum CorThreadSafetyOptions {
  MDThreadSafetyDefault = 0x00000000,
  MDThreadSafetyOff = 0x00000000,
  MDThreadSafetyOn = 0x00000001
} CorThreadSafetyOptions;

typedef enum CorLinkerOptions {
  MDAssembly = 0x00000000,
  MDNetModule = 0x00000001
} CorLinkerOptions;

typedef enum MergeFlags {
  MergeFlagsNone = 0,
  MergeManifest = 0x00000001,
  DropMemberRefCAs = 0x00000002,
  NoDupCheck = 0x00000004,
  MergeExportedTypes = 0x00000008
} MergeFlags;

typedef enum CorLocalRefPreservation {
  MDPreserveLocalRefsNone = 0x00000000,
  MDPreserveLocalTypeRef = 0x00000001,
  MDPreserveLocalMemberRef = 0x00000002
} CorLocalRefPreservation;

typedef enum CorTokenType {
  mdtModule = 0x00000000,
  mdtTypeRef = 0x01000000,
  mdtTypeDef = 0x02000000,
  mdtFieldDef = 0x04000000,
  mdtMethodDef = 0x06000000,
  mdtParamDef = 0x08000000,
  mdtInterfaceImpl = 0x09000000,
  mdtMemberRef = 0x0a000000,
  mdtCustomAttribute = 0x0c000000,
  mdtPermission = 0x0e000000,
  mdtSignature = 0x11000000,
  mdtEvent = 0x14000000,
  mdtProperty = 0x17000000,
  mdtMethodImpl = 0x19000000,
  mdtModuleRef = 0x1a000000,
  mdtTypeSpec = 0x1b000000,
  mdtAssembly = 0x20000000,
  mdtAssemblyRef = 0x23000000,
  mdtFile = 0x26000000,
  mdtExportedType = 0x27000000,
  mdtManifestResource = 0x28000000,
  mdtGenericParam = 0x2a000000,
  mdtMethodSpec = 0x2b000000,
  mdtGenericParamConstraint = 0x2c000000,
  mdtString = 0x70000000,
  mdtName = 0x71000000,
  mdtBaseType = 0x72000000
} CorTokenType;

typedef enum CorOpenFlags {
  ofReadWriteMask = 0x00000001,
  ofRead = 0x00000000,
  ofWrite = 0x00000001,
  ofCopyMemory = 0x00000002,
  ofReadOnly = 0x00000010,
  ofTakeOwnership = 0x00000020,
  ofNoTypeLib = 0x00000080,
  ofNoTransform = 0x00001000,
  ofReserved1 = 0x00000100,
  ofReserved2 = 0x00000200,
  ofReserved3 = 0x00000400,
  ofReserved = 0xffffef40
} CorOpenFlags;

typedef enum CorAttributeTargets {
  catAssembly = 0x0001,
  catModule = 0x0002,
  catClass = 0x0004,
  catStruct = 0x0008,
  catEnum = 0x0010,
  catConstructor = 0x0020,
  catMethod = 0x0040,
  catProperty = 0x0080,
  catField = 0x0100,
  catEvent = 0x0200,
  catInterface = 0x0400,
  catParameter = 0x0800,
  catDelegate = 0x1000,
  catGenericParameter = 0x4000,
  catAll = catAssembly | catModule | catClass | catStruct | catEnum | catConstructor
    | catMethod | catProperty | catField | catEvent | catInterface | catParameter | catDelegate | catGenericParameter,
  catClassMembers = catClass | catStruct | catEnum | catConstructor | catMethod | catProperty | catField | catEvent | catDelegate | catInterface
} CorAttributeTargets;

typedef enum CorFileMapping {
  fmFlat = 0,
  fmExecutableImage = 1
} CorFileMapping;

typedef enum CompilationRelaxationsEnum {
  CompilationRelaxations_NoStringInterning = 0x8
} CompilationRelaxationEnum;

typedef enum NGenHintEnum {
  NGenDefault = 0x0,
  NGenEager = 0x1,
  NGenLazy = 0x2,
  NGenNever = 0x3
} NGenHintEnum;

typedef enum LoadHintEnum {
  LoadDefault = 0x0,
  LoadAlways = 0x01,
  LoadSometimes = 0x2,
  LoadNever = 0x3
} LoadHintEnum;

#ifndef _CORSAVESIZE_DEFINED_
#define _CORSAVESIZE_DEFINED_
typedef enum CorSaveSize {
  cssAccurate = 0x0000,
  cssQuick = 0x0001,
  cssDiscardTransientCAs = 0x0002
} CorSaveSize;
#endif

typedef enum NativeTypeArrayFlags {
  ntaSizeParamIndexSpecified = 0x0001,
  ntaReserved = 0xfffe
} NativeTypeArrayFlags;

typedef LPVOID mdScope;
typedef ULONG32 mdToken;
typedef mdToken mdModule;
typedef mdToken mdTypeRef;
typedef mdToken mdTypeDef;
typedef mdToken mdFieldDef;
typedef mdToken mdMethodDef;
typedef mdToken mdParamDef;
typedef mdToken mdInterfaceImpl;
typedef mdToken mdMemberRef;
typedef mdToken mdCustomAttribute;
typedef mdToken mdPermission;
typedef mdToken mdSignature;
typedef mdToken mdEvent;
typedef mdToken mdProperty;
typedef mdToken mdModuleRef;
typedef mdToken mdAssembly;
typedef mdToken mdAssemblyRef;
typedef mdToken mdFile;
typedef mdToken mdExportedType;
typedef mdToken mdManifestResource;
typedef mdToken mdTypeSpec;
typedef mdToken mdGenericParam;
typedef mdToken mdMethodSpec;
typedef mdToken mdGenericParamConstraint;
typedef mdToken mdString;
typedef mdToken mdCPToken;
typedef ULONG RID;
typedef CorTypeAttr CorRegTypeAttr;
typedef void *HCORENUM;
typedef unsigned char COR_SIGNATURE;
typedef COR_SIGNATURE *PCOR_SIGNATURE;
typedef const COR_SIGNATURE *PCCOR_SIGNATURE;
typedef const char *MDUTF8CSTR;
typedef char *MDUTF8STR;
typedef void *PSECURITY_PROPS;
typedef void *PSECURITY_VALUE;
typedef void **PPSECURITY_PROPS;
typedef void **PPSECURITY_VALUE;

typedef struct COR_SECATTR {
  mdMemberRef tkCtor;
  const void *pCustomAttribute;
  ULONG cbCustomAttribute;
} COR_SECATTR;

typedef struct IMAGE_COR_ILMETHOD_SECT_SMALL {
  BYTE Kind;
  BYTE DataSize;
} IMAGE_COR_ILMETHOD_SECT_SMALL;

typedef struct IMAGE_COR_ILMETHOD_SECT_FAT {
  unsigned int Kind : 8;
  unsigned int DataSize : 24;
} IMAGE_COR_ILMETHOD_SECT_FAT;

typedef struct IMAGE_COR_ILMETHOD_SECT_EH_CLAUSE_FAT {
  CorExceptionFlag Flags;
  DWORD TryOffset;
  DWORD TryLength;
  DWORD HandlerOffset;
  DWORD HandlerLength;
  __C89_NAMELESS union {
    DWORD ClassToken;
    DWORD FilterOffset;
  };
} IMAGE_COR_ILMETHOD_SECT_EH_CLAUSE_FAT;

typedef struct IMAGE_COR_ILMETHOD_SECT_EH_FAT {
  IMAGE_COR_ILMETHOD_SECT_FAT SectFat;
  IMAGE_COR_ILMETHOD_SECT_EH_CLAUSE_FAT Clauses[1];
} IMAGE_COR_ILMETHOD_SECT_EH_FAT;

typedef struct IMAGE_COR_ILMETHOD_SECT_EH_CLAUSE_SMALL {
  unsigned int Flags : 16;
  unsigned int TryOffset : 16;
  unsigned int TryLength : 8;
  unsigned int HandlerOffset : 16;
  unsigned int HandlerLength : 8;
  __C89_NAMELESS union {
    DWORD ClassToken;
    DWORD FilterOffset;
  };
} IMAGE_COR_ILMETHOD_SECT_EH_CLAUSE_SMALL;

typedef struct IMAGE_COR_ILMETHOD_SECT_EH_SMALL {
  IMAGE_COR_ILMETHOD_SECT_SMALL SectSmall;
  WORD Reserved;
  IMAGE_COR_ILMETHOD_SECT_EH_CLAUSE_SMALL Clauses[1];
} IMAGE_COR_ILMETHOD_SECT_EH_SMALL;

typedef union IMAGE_COR_ILMETHOD_SECT_EH {
  IMAGE_COR_ILMETHOD_SECT_EH_SMALL Small;
  IMAGE_COR_ILMETHOD_SECT_EH_FAT Fat;
} IMAGE_COR_ILMETHOD_SECT_EH;

typedef struct IMAGE_COR_ILMETHOD_TINY {
  BYTE Flags_CodeSize;
} IMAGE_COR_ILMETHOD_TINY;

typedef struct IMAGE_COR_ILMETHOD_FAT {
  unsigned int Flags : 12;
  unsigned int Size : 4;
  unsigned int MaxStack : 16;
  DWORD CodeSize;
  mdSignature LocalVarSigTok;
} IMAGE_COR_ILMETHOD_FAT;

typedef union IMAGE_COR_ILMETHOD {
  IMAGE_COR_ILMETHOD_TINY Tiny;
  IMAGE_COR_ILMETHOD_FAT Fat;
} IMAGE_COR_ILMETHOD;

typedef struct IMAGE_COR_VTABLEFIXUP {
  ULONG RVA;
  USHORT Count;
  USHORT Type;
} IMAGE_COR_VTABLEFIXUP;

#ifndef _COR_FIELD_OFFSET_
#define _COR_FIELD_OFFSET_
typedef struct COR_FIELD_OFFSET {
  mdFieldDef ridOfField;
  ULONG ulOffset;
} COR_FIELD_OFFSET;
#endif

#ifndef IMAGE_DIRECTORY_ENTRY_COMHEADER
#define IMAGE_DIRECTORY_ENTRY_COMHEADER 14
#endif

#define FRAMEWORK_REGISTRY_KEY "Software\\Microsoft\\.NETFramework"
#define FRAMEWORK_REGISTRY_KEY_W L"Software\\Microsoft\\.NETFramework"

#ifdef _WIN64
#define USER_FRAMEWORK_REGISTRY_KEY "Software\\Microsoft\\.NETFramework64"
#define USER_FRAMEWORK_REGISTRY_KEY_W L"Software\\Microsoft\\.NETFramework64"
#else
#define USER_FRAMEWORK_REGISTRY_KEY "Software\\Microsoft\\.NETFramework"
#define USER_FRAMEWORK_REGISTRY_KEY_W L"Software\\Microsoft\\.NETFramework"
#endif

#define COR_CTOR_METHOD_NAME ".ctor"
#define COR_CTOR_METHOD_NAME_W L".ctor"
#define COR_CCTOR_METHOD_NAME ".cctor"
#define COR_CCTOR_METHOD_NAME_W L".cctor"

#define COR_ENUM_FIELD_NAME "value__"
#define COR_ENUM_FIELD_NAME_W L"value__"

#define COR_DELETED_NAME_A "_Deleted"
#define COR_DELETED_NAME_W L"_Deleted"
#define COR_VTABLEGAP_NAME_A "_VtblGap"
#define COR_VTABLEGAP_NAME_W L"_VtblGap"

#define COR_IS_32BIT_REQUIRED(_FLAGS) (((_FLAGS) & (COMIMAGE_FLAGS_32BITREQUIRED | COMIMAGE_FLAGS_32BITPREFERRED)) == (COMIMAGE_FLAGS_32BITREQUIRED))
#define COR_IS_32BIT_PREFERRED(_FLAGS) (((_FLAGS) & (COMIMAGE_FLAGS_32BITREQUIRED | COMIMAGE_FLAGS_32BITPREFERRED)) == (COMIMAGE_FLAGS_32BITREQUIRED | COMIMAGE_FLAGS_32BITPREFERRED))
#define COR_SET_32BIT_REQUIRED(_FLAGS) do { _FLAGS = (_FLAGS & ~COMIMAGE_FLAGS_32BITPREFERRED) | COMIMAGE_FLAGS_32BITREQUIRED; } while (0)
#define COR_SET_32BIT_PREFERRED(_FLAGS) do { _FLAGS |= COMIMAGE_FLAGS_32BITPREFERRED | COMIMAGE_FLAGS_32BITREQUIRED; } while (0)
#define COR_CLEAR_32BIT_REQUIRED(_flagsfield) do { _FLAGS &= ~ (COMIMAGE_FLAGS_32BITREQUIRED | COMIMAGE_FLAGS_32BITPREFERRED); } while (0)
#define COR_CLEAR_32BIT_PREFERRED(_FLAGS) do { _FLAGS &= ~ (COMIMAGE_FLAGS_32BITREQUIRED | COMIMAGE_FLAGS_32BITPREFERRED); } while (0)

#define COR_IS_METHOD_MANAGED_IL(flags) ((flags & 0xf) == (miIL | miManaged))
#define COR_IS_METHOD_MANAGED_OPTIL(flags) ((flags & 0xf) == (miOPTIL | miManaged))
#define COR_IS_METHOD_MANAGED_NATIVE(flags) ((flags & 0xf) == (miNative | miManaged))
#define COR_IS_METHOD_UNMANAGED_NATIVE(flags) ((flags & 0xf) == (miNative | miUnmanaged))

#define CMOD_CALLCONV_NAMESPACE_OLD "System.Runtime.InteropServices"
#define CMOD_CALLCONV_NAMESPACE "System.Runtime.CompilerServices"
#define CMOD_CALLCONV_NAME_CDECL "CallConvCdecl"
#define CMOD_CALLCONV_NAME_STDCALL "CallConvStdcall"
#define CMOD_CALLCONV_NAME_THISCALL "CallConvThiscall"
#define CMOD_CALLCONV_NAME_FASTCALL "CallConvFastcall"

#define IsDeletedName(strName) (strncmp (strName, COR_DELETED_NAME_A, COR_DELETED_NAME_LENGTH) == 0)
#define IsVtblGapName(strName) (strncmp (strName, COR_VTABLEGAP_NAME_A, COR_VTABLEGAP_NAME_LENGTH) == 0)

#define IsTdNotPublic(x) (((x) & tdVisibilityMask) == tdNotPublic)
#define IsTdPublic(x) (((x) & tdVisibilityMask) == tdPublic)
#define IsTdNestedPublic(x) (((x) & tdVisibilityMask) == tdNestedPublic)
#define IsTdNestedPrivate(x) (((x) & tdVisibilityMask) == tdNestedPrivate)
#define IsTdNestedFamily(x) (((x) & tdVisibilityMask) == tdNestedFamily)
#define IsTdNestedAssembly(x) (((x) & tdVisibilityMask) == tdNestedAssembly)
#define IsTdNestedFamANDAssem(x) (((x) & tdVisibilityMask) == tdNestedFamANDAssem)
#define IsTdNestedFamORAssem(x) (((x) & tdVisibilityMask) == tdNestedFamORAssem)
#define IsTdNested(x) (((x) & tdVisibilityMask) >= tdNestedPublic)
#define IsTdAutoLayout(x) (((x) & tdLayoutMask) == tdAutoLayout)
#define IsTdSequentialLayout(x) (((x) & tdLayoutMask) == tdSequentialLayout)
#define IsTdExplicitLayout(x) (((x) & tdLayoutMask) == tdExplicitLayout)
#define IsTdClass(x) (((x) & tdClassSemanticsMask) == tdClass)
#define IsTdInterface(x) (((x) & tdClassSemanticsMask) == tdInterface)
#define IsTdAbstract(x) ((x) & tdAbstract)
#define IsTdSealed(x) ((x) & tdSealed)
#define IsTdSpecialName(x) ((x) & tdSpecialName)
#define IsTdImport(x) ((x) & tdImport)
#define IsTdSerializable(x) ((x) & tdSerializable)
#define IsTdWindowsRuntime(x) ((x) & tdWindowsRuntime)
#define IsTdAnsiClass(x) (((x) & tdStringFormatMask) == tdAnsiClass)
#define IsTdUnicodeClass(x) (((x) & tdStringFormatMask) == tdUnicodeClass)
#define IsTdAutoClass(x) (((x) & tdStringFormatMask) == tdAutoClass)
#define IsTdCustomFormatClass(x) (((x) & tdStringFormatMask) == tdCustomFormatClass)
#define IsTdBeforeFieldInit(x) ((x) & tdBeforeFieldInit)
#define IsTdForwarder(x) ((x) & tdForwarder)
#define IsTdRTSpecialName(x) ((x) & tdRTSpecialName)
#define IsTdHasSecurity(x) ((x) & tdHasSecurity)

#define IsMdPrivateScope(x) (((x) & mdMemberAccessMask) == mdPrivateScope)
#define IsMdPrivate(x) (((x) & mdMemberAccessMask) == mdPrivate)
#define IsMdFamANDAssem(x) (((x) & mdMemberAccessMask) == mdFamANDAssem)
#define IsMdAssem(x) (((x) & mdMemberAccessMask) == mdAssem)
#define IsMdFamily(x) (((x) & mdMemberAccessMask) == mdFamily)
#define IsMdFamORAssem(x) (((x) & mdMemberAccessMask) == mdFamORAssem)
#define IsMdPublic(x) (((x) & mdMemberAccessMask) == mdPublic)
#define IsMdUnmanagedExport(x) ((x) & mdUnmanagedExport)
#define IsMdStatic(x) ((x) & mdStatic)
#define IsMdFinal(x) ((x) & mdFinal)
#define IsMdVirtual(x) ((x) & mdVirtual)
#define IsMdHideBySig(x) ((x) & mdHideBySig)
#define IsMdReuseSlot(x) (((x) & mdVtableLayoutMask) == mdReuseSlot)
#define IsMdNewSlot(x) (((x) & mdVtableLayoutMask) == mdNewSlot)
#define IsMdCheckAccessOnOverride(x) ((x) & mdCheckAccessOnOverride)
#define IsMdAbstract(x) ((x) & mdAbstract)
#define IsMdSpecialName(x) ((x) & mdSpecialName)
#define IsMdPinvokeImpl(x) ((x) & mdPinvokeImpl)
#define IsMdRTSpecialName(x) ((x) & mdRTSpecialName)
#define IsMdInstanceInitializer(x, str) (((x) & mdRTSpecialName) && !strcmp ((str), COR_CTOR_METHOD_NAME))
#define IsMdInstanceInitializerW(x, str) (((x) & mdRTSpecialName) && !wcscmp ((str), COR_CTOR_METHOD_NAME_W))
#define IsMdClassConstructor(x, str) (((x) & mdRTSpecialName) && !strcmp ((str), COR_CCTOR_METHOD_NAME))
#define IsMdClassConstructorW(x, str) (((x) & mdRTSpecialName) && !wcscmp ((str), COR_CCTOR_METHOD_NAME_W))
#define IsMdHasSecurity(x) ((x) & mdHasSecurity)
#define IsMdRequireSecObject(x) ((x) & mdRequireSecObject)

#define IsFdPrivateScope(x) (((x) & fdFieldAccessMask) == fdPrivateScope)
#define IsFdPrivate(x) (((x) & fdFieldAccessMask) == fdPrivate)
#define IsFdFamANDAssem(x) (((x) & fdFieldAccessMask) == fdFamANDAssem)
#define IsFdAssembly(x) (((x) & fdFieldAccessMask) == fdAssembly)
#define IsFdFamily(x) (((x) & fdFieldAccessMask) == fdFamily)
#define IsFdFamORAssem(x) (((x) & fdFieldAccessMask) == fdFamORAssem)
#define IsFdPublic(x) (((x) & fdFieldAccessMask) == fdPublic)
#define IsFdStatic(x) ((x) & fdStatic)
#define IsFdInitOnly(x) ((x) & fdInitOnly)
#define IsFdLiteral(x) ((x) & fdLiteral)
#define IsFdNotSerialized(x) ((x) & fdNotSerialized)
#define IsFdHasFieldRVA(x) ((x) & fdHasFieldRVA)
#define IsFdSpecialName(x) ((x) & fdSpecialName)
#define IsFdRTSpecialName(x) ((x) & fdRTSpecialName)
#define IsFdHasFieldMarshal(x) ((x) & fdHasFieldMarshal)
#define IsFdPinvokeImpl(x) ((x) & fdPinvokeImpl)
#define IsFdHasDefault(x) ((x) & fdHasDefault)

#define IsPdIn(x) ((x) & pdIn)
#define IsPdOut(x) ((x) & pdOut)
#define IsPdOptional(x) ((x) & pdOptional)
#define IsPdHasDefault(x) ((x) & pdHasDefault)
#define IsPdHasFieldMarshal(x) ((x) & pdHasFieldMarshal)

#define IsPrSpecialName(x) ((x) & prSpecialName)
#define IsPrRTSpecialName(x) ((x) & prRTSpecialName)
#define IsPrHasDefault(x) ((x) & prHasDefault)

#define IsEvSpecialName(x) ((x) & evSpecialName)
#define IsEvRTSpecialName(x) ((x) & evRTSpecialName)

#define IsMsSetter(x) ((x) & msSetter)
#define IsMsGetter(x) ((x) & msGetter)
#define IsMsOther(x) ((x) & msOther)
#define IsMsAddOn(x) ((x) & msAddOn)
#define IsMsRemoveOn(x) ((x) & msRemoveOn)
#define IsMsFire(x) ((x) & msFire)

#define IsDclActionNil(x) (((x) & dclActionMask) == dclActionNil)
#define IsDclActionAnyStackModifier(x) ((((x) & dclActionMask) == dclAssert) || (((x) & dclActionMask) == dclDeny) || (((x) & dclActionMask) == dclPermitOnly))
#define IsAssemblyDclAction(x) (((x) >= dclRequestMinimum) && ((x) <= dclRequestRefuse))
#define IsNGenOnlyDclAction(x) (((x) == dclPrejitGrant) || ((x) == dclPrejitDenied))

#define IsMiIL(x) (((x) & miCodeTypeMask) == miIL)
#define IsMiNative(x) (((x) & miCodeTypeMask) == miNative)
#define IsMiOPTIL(x) (((x) & miCodeTypeMask) == miOPTIL)
#define IsMiRuntime(x) (((x) & miCodeTypeMask) == miRuntime)
#define IsMiUnmanaged(x) (((x) & miManagedMask) == miUnmanaged)
#define IsMiManaged(x) (((x) & miManagedMask) == miManaged)
#define IsMiNoInlining(x) ((x) & miNoInlining)
#define IsMiForwardRef(x) ((x) & miForwardRef)
#define IsMiSynchronized(x) ((x) & miSynchronized)
#define IsMiNoOptimization(x) ((x) & miNoOptimization)
#define IsMiPreserveSig(x) ((x) & miPreserveSig)
#define IsMiAggressiveInlining(x) ((x) & miAggressiveInlining)
#define IsMiInternalCall(x) ((x) & miInternalCall)

#define IsPmNoMangle(x) ((x) & pmNoMangle)
#define IsPmCharSetNotSpec(x) (((x) & pmCharSetMask) == pmCharSetNotSpec)
#define IsPmCharSetAnsi(x) (((x) & pmCharSetMask) == pmCharSetAnsi)
#define IsPmCharSetUnicode(x) (((x) & pmCharSetMask) == pmCharSetUnicode)
#define IsPmCharSetAuto(x) (((x) & pmCharSetMask) == pmCharSetAuto)
#define IsPmSupportsLastError(x) ((x) & pmSupportsLastError)
#define IsPmCallConvWinapi(x) (((x) & pmCallConvMask) == pmCallConvWinapi)
#define IsPmCallConvCdecl(x) (((x) & pmCallConvMask) == pmCallConvCdecl)
#define IsPmCallConvStdcall(x) (((x) & pmCallConvMask) == pmCallConvStdcall)
#define IsPmCallConvThiscall(x) (((x) & pmCallConvMask) == pmCallConvThiscall)
#define IsPmCallConvFastcall(x) (((x) & pmCallConvMask) == pmCallConvFastcall)
#define IsPmBestFitEnabled(x) (((x) & pmBestFitMask) == pmBestFitEnabled)
#define IsPmBestFitDisabled(x) (((x) & pmBestFitMask) == pmBestFitDisabled)
#define IsPmBestFitUseAssem(x) (((x) & pmBestFitMask) == pmBestFitUseAssem)
#define IsPmThrowOnUnmappableCharEnabled(x) (((x) & pmThrowOnUnmappableCharMask) == pmThrowOnUnmappableCharEnabled)
#define IsPmThrowOnUnmappableCharDisabled(x) (((x) & pmThrowOnUnmappableCharMask) == pmThrowOnUnmappableCharDisabled)
#define IsPmThrowOnUnmappableCharUseAssem(x) (((x) & pmThrowOnUnmappableCharMask) == pmThrowOnUnmappableCharUseAssem)

#define IsAfRetargetable(x) ((x) & afRetargetable)
#define IsAfContentType_Default(x) (((x) & afContentType_Mask) == afContentType_Default)
#define IsAfContentType_WindowsRuntime(x) (((x) & afContentType_Mask) == afContentType_WindowsRuntime)
#define IsAfPA_MSIL(x) (((x) & afPA_Mask) == afPA_MSIL)
#define IsAfPA_x86(x) (((x) & afPA_Mask) == afPA_x86)
#define IsAfPA_IA64(x) (((x) & afPA_Mask) == afPA_IA64)
#define IsAfPA_AMD64(x) (((x) & afPA_Mask) == afPA_AMD64)
#define IsAfPA_ARM(x) (((x) & afPA_Mask) == afPA_ARM)
#define IsAfPA_NoPlatform(x) (((x) & afPA_FullMask) == afPA_NoPlatform)
#define IsAfPA_Specified(x) ((x) & afPA_Specified)
#define PAIndex(x) (((x) & afPA_Mask) >> afPA_Shift)
#define PAFlag(x) (((x) << afPA_Shift) & afPA_Mask)
#define PrepareForSaving(x) ((x) &(((x) & afPA_Specified) ? ~afPA_Specified : ~afPA_FullMask))
#define IsAfEnableJITcompileTracking(x) ((x) & afEnableJITcompileTracking)
#define IsAfDisableJITcompileOptimizer(x) ((x) & afDisableJITcompileOptimizer)
#define IsAfPublicKey(x) ((x) & afPublicKey)
#define IsAfPublicKeyToken(x) (((x) & afPublicKey) == 0)

#define IsMrPublic(x) (((x) & mrVisibilityMask) == mrPublic)
#define IsMrPrivate(x) (((x) & mrVisibilityMask) == mrPrivate)

#define IsFfContainsMetaData(x) (! ((x) & ffContainsNoMetaData))
#define IsFfContainsNoMetaData(x) ((x) & ffContainsNoMetaData)

#define IMAGE_CEE_CS_CALLCONV_INSTANTIATION IMAGE_CEE_CS_CALLCONV_GENERICINST

#define IsENCDelta(x) (((x) & MDUpdateMask) == MDUpdateDelta)

#define RidToToken(rid, tktype) ((rid) |= (tktype))
#define TokenFromRid(rid, tktype) ((rid) | (tktype))
#define RidFromToken(tk) ((RID) ((tk) & 0x00ffffff))
#define TypeFromToken(tk) ((ULONG32) ((tk) & 0xff000000))
#define IsNilToken(tk) ((RidFromToken (tk)) == 0)

#define mdTokenNil ((mdToken)0)
#define mdModuleNil ((mdModule)mdtModule)
#define mdTypeRefNil ((mdTypeRef)mdtTypeRef)
#define mdTypeDefNil ((mdTypeDef)mdtTypeDef)
#define mdFieldDefNil ((mdFieldDef)mdtFieldDef)
#define mdMethodDefNil ((mdMethodDef)mdtMethodDef)
#define mdParamDefNil ((mdParamDef)mdtParamDef)
#define mdInterfaceImplNil ((mdInterfaceImpl)mdtInterfaceImpl)
#define mdMemberRefNil ((mdMemberRef)mdtMemberRef)
#define mdCustomAttributeNil ((mdCustomAttribute)mdtCustomAttribute)
#define mdPermissionNil ((mdPermission)mdtPermission)
#define mdSignatureNil ((mdSignature)mdtSignature)
#define mdEventNil ((mdEvent)mdtEvent)
#define mdPropertyNil ((mdProperty)mdtProperty)
#define mdModuleRefNil ((mdModuleRef)mdtModuleRef)
#define mdTypeSpecNil ((mdTypeSpec)mdtTypeSpec)
#define mdAssemblyNil ((mdAssembly)mdtAssembly)
#define mdAssemblyRefNil ((mdAssemblyRef)mdtAssemblyRef)
#define mdFileNil ((mdFile)mdtFile)
#define mdExportedTypeNil ((mdExportedType)mdtExportedType)
#define mdManifestResourceNil ((mdManifestResource)mdtManifestResource)
#define mdGenericParamNil ((mdGenericParam)mdtGenericParam)
#define mdGenericParamConstraintNil ((mdGenericParamConstraint)mdtGenericParamConstraint)
#define mdMethodSpecNil ((mdMethodSpec)mdtMethodSpec)
#define mdStringNil ((mdString)mdtString)

#define IsOfRead(x) (((x) & ofReadWriteMask) == ofRead)
#define IsOfReadWrite(x) (((x) & ofReadWriteMask) == ofWrite)
#define IsOfCopyMemory(x) ((x) & ofCopyMemory)
#define IsOfReadOnly(x) ((x) & ofReadOnly)
#define IsOfTakeOwnership(x) ((x) & ofTakeOwnership)
#define IsOfReserved(x) (((x) & ofReserved) != 0)

#ifndef IMAGE_CEE_CS_CALLCONV_DEFAULT_HASTHIS
#define IMAGE_CEE_CS_CALLCONV_DEFAULT_HASTHIS (IMAGE_CEE_CS_CALLCONV_DEFAULT | IMAGE_CEE_CS_CALLCONV_HASTHIS)
#endif

#define INTEROP_AUTOPROXY_TYPE_W L"System.Runtime.InteropServices.AutomationProxyAttribute"
#define INTEROP_AUTOPROXY_TYPE "System.Runtime.InteropServices.AutomationProxyAttribute"
#define INTEROP_AUTOPROXY_SIG {IMAGE_CEE_CS_CALLCONV_DEFAULT_HASTHIS, 1, ELEMENT_TYPE_VOID, ELEMENT_TYPE_BOOLEAN}
#define INTEROP_BESTFITMAPPING_TYPE_W L"System.Runtime.InteropServices.BestFitMappingAttribute"
#define INTEROP_BESTFITMAPPING_TYPE "System.Runtime.InteropServices.BestFitMappingAttribute"
#define INTEROP_BESTFITMAPPING_SIG {IMAGE_CEE_CS_CALLCONV_DEFAULT_HASTHIS, 2, ELEMENT_TYPE_VOID, ELEMENT_TYPE_BOOLEAN, ELEMENT_TYPE_BOOLEAN}
#define INTEROP_CLASSINTERFACE_TYPE_W L"System.Runtime.InteropServices.ClassInterfaceAttribute"
#define INTEROP_CLASSINTERFACE_TYPE "System.Runtime.InteropServices.ClassInterfaceAttribute"
#define INTEROP_CLASSINTERFACE_SIG {IMAGE_CEE_CS_CALLCONV_DEFAULT_HASTHIS, 1, ELEMENT_TYPE_VOID, ELEMENT_TYPE_I2}
#define INTEROP_COCLASS_TYPE_W L"System.Runtime.InteropServices.CoClassAttribute"
#define INTEROP_COCLASS_TYPE "System.Runtime.InteropServices.CoClassAttribute"
#define INTEROP_COMALIASNAME_TYPE_W L"System.Runtime.InteropServices.ComAliasNameAttribute"
#define INTEROP_COMALIASNAME_TYPE "System.Runtime.InteropServices.ComAliasNameAttribute"
#define INTEROP_COMALIASNAME_SIG {IMAGE_CEE_CS_CALLCONV_DEFAULT_HASTHIS, 1, ELEMENT_TYPE_VOID, ELEMENT_TYPE_STRING}
#define INTEROP_COMCOMPATIBLEVERSION_TYPE_W L"System.Runtime.InteropServices.ComCompatibleVersionAttribute"
#define INTEROP_COMCOMPATIBLEVERSION_TYPE "System.Runtime.InteropServices.ComCompatibleVersionAttribute"
#define INTEROP_COMCOMPATIBLEVERSION_SIG {IMAGE_CEE_CS_CALLCONV_DEFAULT_HASTHIS, 4, ELEMENT_TYPE_VOID, ELEMENT_TYPE_I2, ELEMENT_TYPE_I2, ELEMENT_TYPE_I2, ELEMENT_TYPE_I2}
#define INTEROP_COMCONVERSIONLOSS_TYPE_W L"System.Runtime.InteropServices.ComConversionLossAttribute"
#define INTEROP_COMCONVERSIONLOSS_TYPE "System.Runtime.InteropServices.ComConversionLossAttribute"
#define INTEROP_COMCONVERSIONLOSS_SIG {IMAGE_CEE_CS_CALLCONV_DEFAULT_HASTHIS, 0, ELEMENT_TYPE_VOID}
#define INTEROP_COMDEFAULTINTERFACE_TYPE_W L"System.Runtime.InteropServices.ComDefaultInterfaceAttribute"
#define INTEROP_COMDEFAULTINTERFACE_TYPE "System.Runtime.InteropServices.ComDefaultInterfaceAttribute"
#define INTEROP_COMEMULATE_TYPE_W L"System.Runtime.InteropServices.ComEmulateAttribute"
#define INTEROP_COMEMULATE_TYPE "System.Runtime.InteropServices.ComEmulateAttribute"
#define INTEROP_COMEMULATE_SIG {IMAGE_CEE_CS_CALLCONV_DEFAULT_HASTHIS, 1, ELEMENT_TYPE_VOID, ELEMENT_TYPE_STRING}
#define INTEROP_COMEVENTINTERFACE_TYPE_W L"System.Runtime.InteropServices.ComEventInterfaceAttribute"
#define INTEROP_COMEVENTINTERFACE_TYPE "System.Runtime.InteropServices.ComEventInterfaceAttribute"
#define INTEROP_COMIMPORT_TYPE_W L"System.Runtime.InteropServices.ComImportAttribute"
#define INTEROP_COMIMPORT_TYPE "System.Runtime.InteropServices.ComImportAttribute"
#define INTEROP_COMIMPORT_SIG {IMAGE_CEE_CS_CALLCONV_DEFAULT_HASTHIS, 0, ELEMENT_TYPE_VOID}
#define INTEROP_COMREGISTERFUNCTION_TYPE_W L"System.Runtime.InteropServices.ComRegisterFunctionAttribute"
#define INTEROP_COMREGISTERFUNCTION_TYPE "System.Runtime.InteropServices.ComRegisterFunctionAttribute"
#define INTEROP_COMREGISTERFUNCTION_SIG {IMAGE_CEE_CS_CALLCONV_DEFAULT_HASTHIS, 0, ELEMENT_TYPE_VOID}
#define INTEROP_COMSOURCEINTERFACES_TYPE_W L"System.Runtime.InteropServices.ComSourceInterfacesAttribute"
#define INTEROP_COMSOURCEINTERFACES_TYPE "System.Runtime.InteropServices.ComSourceInterfacesAttribute"
#define INTEROP_COMSOURCEINTERFACES_SIG {IMAGE_CEE_CS_CALLCONV_DEFAULT_HASTHIS, 1, ELEMENT_TYPE_VOID, ELEMENT_TYPE_STRING}
#define INTEROP_COMSUBSTITUTABLEINTERFACE_TYPE_W L"System.Runtime.InteropServices.ComSubstitutableInterfaceAttribute"
#define INTEROP_COMSUBSTITUTABLEINTERFACE_TYPE "System.Runtime.InteropServices.ComSubstitutableInterfaceAttribute"
#define INTEROP_COMSUBSTITUTABLEINTERFACE_SIG {IMAGE_CEE_CS_CALLCONV_DEFAULT_HASTHIS, 0, ELEMENT_TYPE_VOID}
#define INTEROP_COMUNREGISTERFUNCTION_TYPE_W L"System.Runtime.InteropServices.ComUnregisterFunctionAttribute"
#define INTEROP_COMUNREGISTERFUNCTION_TYPE "System.Runtime.InteropServices.ComUnregisterFunctionAttribute"
#define INTEROP_COMUNREGISTERFUNCTION_SIG {IMAGE_CEE_CS_CALLCONV_DEFAULT_HASTHIS, 0, ELEMENT_TYPE_VOID}
#define INTEROP_COMVISIBLE_TYPE_W L"System.Runtime.InteropServices.ComVisibleAttribute"
#define INTEROP_COMVISIBLE_TYPE "System.Runtime.InteropServices.ComVisibleAttribute"
#define INTEROP_COMVISIBLE_SIG {IMAGE_CEE_CS_CALLCONV_DEFAULT_HASTHIS, 1, ELEMENT_TYPE_VOID, ELEMENT_TYPE_BOOLEAN}
#define INTEROP_DATETIMEVALUE_TYPE_W L"System.Runtime.CompilerServices.DateTimeConstantAttribute"
#define INTEROP_DATETIMEVALUE_TYPE "System.Runtime.CompilerServices.DateTimeConstantAttribute"
#define INTEROP_DATETIMEVALUE_SIG {IMAGE_CEE_CS_CALLCONV_DEFAULT_HASTHIS, 1, ELEMENT_TYPE_VOID, ELEMENT_TYPE_I8}
#define INTEROP_DECIMALVALUE_TYPE_W L"System.Runtime.CompilerServices.DecimalConstantAttribute"
#define INTEROP_DECIMALVALUE_TYPE "System.Runtime.CompilerServices.DecimalConstantAttribute"
#define INTEROP_DECIMALVALUE_SIG {IMAGE_CEE_CS_CALLCONV_DEFAULT_HASTHIS, 5, ELEMENT_TYPE_VOID, ELEMENT_TYPE_U1, ELEMENT_TYPE_U1, ELEMENT_TYPE_U4, ELEMENT_TYPE_U4, ELEMENT_TYPE_U4}
#define INTEROP_DEFAULTMEMBER_TYPE_W L"System.Reflection.DefaultMemberAttribute"
#define INTEROP_DEFAULTMEMBER_TYPE "System.Reflection.DefaultMemberAttribute"
#define INTEROP_DEFAULTMEMBER_SIG {IMAGE_CEE_CS_CALLCONV_DEFAULT_HASTHIS, 1, ELEMENT_TYPE_VOID, ELEMENT_TYPE_STRING}
#define INTEROP_DISPID_TYPE_W L"System.Runtime.InteropServices.DispIdAttribute"
#define INTEROP_DISPID_TYPE "System.Runtime.InteropServices.DispIdAttribute"
#define INTEROP_DISPID_SIG {IMAGE_CEE_CS_CALLCONV_DEFAULT_HASTHIS, 1, ELEMENT_TYPE_VOID, ELEMENT_TYPE_I4}
#define INTEROP_GUID_TYPE_W L"System.Runtime.InteropServices.GuidAttribute"
#define INTEROP_GUID_TYPE "System.Runtime.InteropServices.GuidAttribute"
#define INTEROP_GUID_SIG {IMAGE_CEE_CS_CALLCONV_DEFAULT_HASTHIS, 1, ELEMENT_TYPE_VOID, ELEMENT_TYPE_STRING}
#define INTEROP_IDISPATCHIMPL_TYPE_W L"System.Runtime.InteropServices.IDispatchImplAttribute"
#define INTEROP_IDISPATCHIMPL_TYPE "System.Runtime.InteropServices.IDispatchImplAttribute"
#define INTEROP_IDISPATCHIMPL_SIG {IMAGE_CEE_CS_CALLCONV_DEFAULT_HASTHIS, 1, ELEMENT_TYPE_VOID, ELEMENT_TYPE_I2}
#define INTEROP_IDISPATCHVALUE_TYPE_W L"System.Runtime.CompilerServices.IDispatchConstantAttribute"
#define INTEROP_IDISPATCHVALUE_TYPE "System.Runtime.CompilerServices.IDispatchConstantAttribute"
#define INTEROP_IDISPATCHVALUE_SIG {IMAGE_CEE_CS_CALLCONV_DEFAULT_HASTHIS, 0, ELEMENT_TYPE_VOID}
#define INTEROP_IMPORTEDFROMTYPELIB_TYPE_W L"System.Runtime.InteropServices.ImportedFromTypeLibAttribute"
#define INTEROP_IMPORTEDFROMTYPELIB_TYPE "System.Runtime.InteropServices.ImportedFromTypeLibAttribute"
#define INTEROP_IMPORTEDFROMTYPELIB_SIG {IMAGE_CEE_CS_CALLCONV_DEFAULT_HASTHIS, 1, ELEMENT_TYPE_VOID, ELEMENT_TYPE_STRING}
#define INTEROP_IN_TYPE_W L"System.Runtime.InteropServices.InAttribute"
#define INTEROP_IN_TYPE "System.Runtime.InteropServices.InAttribute"
#define INTEROP_IN_SIG {IMAGE_CEE_CS_CALLCONV_DEFAULT_HASTHIS, 0, ELEMENT_TYPE_VOID}
#define INTEROP_INTERFACETYPE_TYPE_W L"System.Runtime.InteropServices.InterfaceTypeAttribute"
#define INTEROP_INTERFACETYPE_TYPE "System.Runtime.InteropServices.InterfaceTypeAttribute"
#define INTEROP_INTERFACETYPE_SIG {IMAGE_CEE_CS_CALLCONV_DEFAULT_HASTHIS, 1, ELEMENT_TYPE_VOID, ELEMENT_TYPE_I2}
#define INTEROP_IUNKNOWNVALUE_TYPE_W L"System.Runtime.CompilerServices.IUnknownConstantAttribute"
#define INTEROP_IUNKNOWNVALUE_TYPE "System.Runtime.CompilerServices.IUnknownConstantAttribute"
#define INTEROP_IUNKNOWNVALUE_SIG {IMAGE_CEE_CS_CALLCONV_DEFAULT_HASTHIS, 0, ELEMENT_TYPE_VOID}
#define INTEROP_LCIDCONVERSION_TYPE_W L"System.Runtime.InteropServices.LCIDConversionAttribute"
#define INTEROP_LCIDCONVERSION_TYPE "System.Runtime.InteropServices.LCIDConversionAttribute"
#define INTEROP_LCIDCONVERSION_SIG {IMAGE_CEE_CS_CALLCONV_DEFAULT_HASTHIS, 1, ELEMENT_TYPE_VOID, ELEMENT_TYPE_I4}
#define INTEROP_MARSHALAS_TYPE_W L"System.Runtime.InteropServices.MarshalAsAttribute"
#define INTEROP_MARSHALAS_TYPE "System.Runtime.InteropServices.MarshalAsAttribute"
#define INTEROP_MARSHALAS_SIG {IMAGE_CEE_CS_CALLCONV_DEFAULT_HASTHIS, 1, ELEMENT_TYPE_VOID, ELEMENT_TYPE_I2}
#define INTEROP_OUT_TYPE_W L"System.Runtime.InteropServices.OutAttribute"
#define INTEROP_OUT_TYPE "System.Runtime.InteropServices.OutAttribute"
#define INTEROP_OUT_SIG {IMAGE_CEE_CS_CALLCONV_DEFAULT_HASTHIS, 0, ELEMENT_TYPE_VOID}
#define INTEROP_PARAMARRAY_TYPE_W L"System.ParamArrayAttribute"
#define INTEROP_PARAMARRAY_TYPE "System.ParamArrayAttribute"
#define INTEROP_PARAMARRAY_SIG {IMAGE_CEE_CS_CALLCONV_DEFAULT_HASTHIS, 0, ELEMENT_TYPE_VOID}
#define INTEROP_PRESERVESIG_TYPE_W L"System.Runtime.InteropServices.PreserveSigAttribure"
#define INTEROP_PRESERVESIG_TYPE "System.Runtime.InteropServices.PreserveSigAttribure"
#define INTEROP_PRESERVESIG_SIG {IMAGE_CEE_CS_CALLCONV_DEFAULT_HASTHIS, 0, ELEMENT_TYPE_BOOLEAN}
#define INTEROP_PRIMARYINTEROPASSEMBLY_TYPE_W L"System.Runtime.InteropServices.PrimaryInteropAssemblyAttribute"
#define INTEROP_PRIMARYINTEROPASSEMBLY_TYPE "System.Runtime.InteropServices.PrimaryInteropAssemblyAttribute"
#define INTEROP_PRIMARYINTEROPASSEMBLY_SIG {IMAGE_CEE_CS_CALLCONV_DEFAULT_HASTHIS, 2, ELEMENT_TYPE_VOID, ELEMENT_TYPE_I4, ELEMENT_TYPE_I4}
#define INTEROP_SERIALIZABLE_TYPE_W L"System.SerializableAttribute"
#define INTEROP_SERIALIZABLE_TYPE "System.SerializableAttribute"
#define INTEROP_SERIALIZABLE_SIG {IMAGE_CEE_CS_CALLCONV_DEFAULT_HASTHIS, 0, ELEMENT_TYPE_VOID}
#define INTEROP_SETWIN32CONTEXTINIDISPATCHATTRIBUTE_TYPE_W L"System.Runtime.InteropServices.SetWin32ContextInIDispatchAttribute"
#define INTEROP_SETWIN32CONTEXTINIDISPATCHATTRIBUTE_TYPE "System.Runtime.InteropServices.SetWin32ContextInIDispatchAttribute"
#define INTEROP_SETWIN32CONTEXTINIDISPATCHATTRIBUTE_SIG {IMAGE_CEE_CS_CALLCONV_DEFAULT_HASTHIS, 0, ELEMENT_TYPE_VOID}
#define INTEROP_TYPELIBFUNC_TYPE_W L"System.Runtime.InteropServices.TypeLibFuncAttribute"
#define INTEROP_TYPELIBFUNC_TYPE "System.Runtime.InteropServices.TypeLibFuncAttribute"
#define INTEROP_TYPELIBIMPORTCLASS_TYPE_W L"System.Runtime.InteropServices.TypeLibImportClassAttribute"
#define INTEROP_TYPELIBIMPORTCLASS_TYPE "System.Runtime.InteropServices.TypeLibImportClassAttribute"
#define INTEROP_TYPELIBFUNC_SIG {IMAGE_CEE_CS_CALLCONV_DEFAULT_HASTHIS, 1, ELEMENT_TYPE_VOID, ELEMENT_TYPE_I2}
#define INTEROP_TYPELIBTYPE_TYPE_W L"System.Runtime.InteropServices.TypeLibTypeAttribute"
#define INTEROP_TYPELIBTYPE_TYPE "System.Runtime.InteropServices.TypeLibTypeAttribute"
#define INTEROP_TYPELIBTYPE_SIG {IMAGE_CEE_CS_CALLCONV_DEFAULT_HASTHIS, 1, ELEMENT_TYPE_VOID, ELEMENT_TYPE_I2}
#define INTEROP_TYPELIBVAR_TYPE_W L"System.Runtime.InteropServices.TypeLibVarAttribute"
#define INTEROP_TYPELIBVAR_TYPE "System.Runtime.InteropServices.TypeLibVarAttribute"
#define INTEROP_TYPELIBVAR_SIG {IMAGE_CEE_CS_CALLCONV_DEFAULT_HASTHIS, 1, ELEMENT_TYPE_VOID, ELEMENT_TYPE_I2}
#define INTEROP_TYPELIBVERSION_TYPE_W L"System.Runtime.InteropServices.TypeLibVersionAttribute"
#define INTEROP_TYPELIBVERSION_TYPE "System.Runtime.InteropServices.TypeLibVersionAttribute"
#define INTEROP_TYPELIBVERSION_SIG {IMAGE_CEE_CS_CALLCONV_DEFAULT_HASTHIS, 2, ELEMENT_TYPE_VOID, ELEMENT_TYPE_I2, ELEMENT_TYPE_I2}

#define FORWARD_INTEROP_STUB_METHOD_TYPE_W L"System.Runtime.InteropServices.ManagedToNativeComInteropStubAttribute"
#define FORWARD_INTEROP_STUB_METHOD_TYPE "System.Runtime.InteropServices.ManagedToNativeComInteropStubAttribute"

#define FRIEND_ACCESS_ALLOWED_ATTRIBUTE_TYPE_W L"System.Runtime.CompilerServices.FriendAccessAllowedAttribute"
#define FRIEND_ACCESS_ALLOWED_ATTRIBUTE_TYPE "System.Runtime.CompilerServices.FriendAccessAllowedAttribute"
#define FRIEND_ACCESS_ALLOWED_SIG {IMAGE_CEE_CS_CALLCONV_DEFAULT_HASTHIS, 0, ELEMENT_TYPE_VOID}
#define FRIEND_ASSEMBLY_TYPE_W L"System.Runtime.CompilerServices.InternalsVisibleToAttribute"
#define FRIEND_ASSEMBLY_TYPE "System.Runtime.CompilerServices.InternalsVisibleToAttribute"
#define FRIEND_ASSEMBLY_SIG {IMAGE_CEE_CS_CALLCONV_DEFAULT_HASTHIS, 2, ELEMENT_TYPE_VOID, ELEMENT_TYPE_STRING, ELEMENT_TYPE_BOOLEAN}

#define DEFAULTDEPENDENCY_TYPE_W L"System.Runtime.CompilerServices.DefaultDependencyAttribute"
#define DEFAULTDEPENDENCY_TYPE "System.Runtime.CompilerServices.DefaultDependencyAttribute"

#define DEFAULTDOMAIN_LOADEROPTIMIZATION_TYPE_W L"System.LoaderOptimizationAttribute"
#define DEFAULTDOMAIN_LOADEROPTIMIZATION_TYPE "System.LoaderOptimizationAttribute"
#define DEFAULTDOMAIN_LOADEROPTIMIZATION_SIG {IMAGE_CEE_CS_CALLCONV_DEFAULT_HASTHIS, 1, ELEMENT_TYPE_VOID, ELEMENT_TYPE_I1}
#define DEFAULTDOMAIN_MTA_TYPE_W L"System.MTAThreadAttribute"
#define DEFAULTDOMAIN_MTA_TYPE "System.MTAThreadAttribute"
#define DEFAULTDOMAIN_MTA_SIG {IMAGE_CEE_CS_CALLCONV_DEFAULT_HASTHIS, 0, ELEMENT_TYPE_VOID}
#define DEFAULTDOMAIN_STA_TYPE_W L"System.STAThreadAttribute"
#define DEFAULTDOMAIN_STA_TYPE "System.STAThreadAttribute"
#define DEFAULTDOMAIN_STA_SIG {IMAGE_CEE_CS_CALLCONV_DEFAULT_HASTHIS, 0, ELEMENT_TYPE_VOID}

#define DEPENDENCY_TYPE_W L"System.Runtime.CompilerServices.DependencyAttribute"
#define DEPENDENCY_TYPE "System.Runtime.CompilerServices.DependencyAttribute"

#define RUNTIMECOMPATIBILITY_TYPE_W L"System.Runtime.CompilerServices.RuntimeCompatibilityAttribute"
#define RUNTIMECOMPATIBILITY_TYPE "System.Runtime.CompilerServices.RuntimeCompatibilityAttribute"

#define TARGET_FRAMEWORK_TYPE_W L"System.Runtime.Versioning.TargetFrameworkAttribute"
#define TARGET_FRAMEWORK_TYPE "System.Runtime.Versioning.TargetFrameworkAttribute"

#define TARGETEDPATCHBAND_W L"System.Runtime.AssemblyTargetedPatchBandAttribute"
#define TARGETEDPATCHBAND "System.Runtime.AssemblyTargetedPatchBandAttribute"
#define TARGETEDPATCHOPTOUT_W L"System.Runtime.TargetedPatchingOptOutAttribute"
#define TARGETEDPATCHOPTOUT "System.Runtime.TargetedPatchingOptOutAttribute"

#define COMPILATIONRELAXATIONS_TYPE_W L"System.Runtime.CompilerServices.CompilationRelaxationsAttribute"
#define COMPILATIONRELAXATIONS_TYPE "System.Runtime.CompilerServices.CompilationRelaxationsAttribute"

#ifdef __cplusplus
}
#endif

#endif
