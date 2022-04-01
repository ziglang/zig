from rpython.rtyper.lltypesystem import rffi, lltype

# shared ll definitions
C_SCOPE       = rffi.SIZE_T
C_NULL_SCOPE  = rffi.cast(C_SCOPE, 0)
C_TYPE        = C_SCOPE
C_NULL_TYPE   = rffi.cast(C_TYPE, 0)
C_ENUM        = rffi.VOIDP
C_NULL_ENUM   = rffi.cast(C_ENUM, 0)
C_OBJECT      = rffi.VOIDP
C_NULL_OBJECT = rffi.cast(C_OBJECT, 0)
C_METHOD      = rffi.INTPTR_T

C_INDEX       = rffi.SIZE_T
C_INDEX_ARRAY = rffi.CArrayPtr(rffi.SIZE_T)
C_FUNC_PTR    = rffi.VOIDP

C_EXCTYPE     = rffi.ULONG
