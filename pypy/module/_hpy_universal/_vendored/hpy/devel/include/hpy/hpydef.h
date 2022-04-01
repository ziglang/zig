#ifndef HPY_UNIVERSAL_HPYDEF_H
#define HPY_UNIVERSAL_HPYDEF_H

#include <stddef.h> /* to make sure "offsetof" is available for our users */

#include "hpy/hpyfunc.h"
#include "hpy/autogen_hpyslot.h"

typedef struct {
    HPySlot_Slot slot;     // The slot to fill
    void *impl;            // Function pointer to the implementation
    void *cpy_trampoline;  // Used by CPython to call impl
} HPySlot;

typedef struct {
    const char *name;             // The name of the built-in function/method
    const char *doc;              // The __doc__ attribute, or NULL
    void *impl;                   // Function pointer to the implementation
    void *cpy_trampoline;         // Used by CPython to call impl
    HPyFunc_Signature signature;  // Indicates impl's expected the signature
} HPyMeth;

typedef enum {
    HPyMember_SHORT = 0,
    HPyMember_INT = 1,
    HPyMember_LONG = 2,
    HPyMember_FLOAT = 3,
    HPyMember_DOUBLE = 4,
    HPyMember_STRING = 5,
    HPyMember_OBJECT = 6,
    HPyMember_CHAR = 7,   /* 1-character string */
    HPyMember_BYTE = 8,   /* 8-bit signed int */
    /* unsigned variants: */
    HPyMember_UBYTE = 9,
    HPyMember_USHORT = 10,
    HPyMember_UINT = 11,
    HPyMember_ULONG = 12,

    /* Added by Jack: strings contained in the structure */
    HPyMember_STRING_INPLACE = 13,

    /* Added by Lillo: bools contained in the structure (assumed char) */
    HPyMember_BOOL = 14,
    HPyMember_OBJECT_EX = 16,  /* Like T_OBJECT, but raises AttributeError
                                  when the value is NULL, instead of
                                  converting to None. */
    HPyMember_LONGLONG = 17,
    HPyMember_ULONGLONG = 18,

    HPyMember_HPYSSIZET = 19,  /* HPy_ssize_t */
    HPyMember_NONE = 20,       /* Value is always None */

} HPyMember_FieldType;

typedef struct {
    const char *name;
    HPyMember_FieldType type;
    HPy_ssize_t offset;
    int readonly;
    const char *doc;
} HPyMember;

typedef struct {
    const char *name;
    void *getter_impl;            // Function pointer to the implementation
    void *setter_impl;            // Same; this may be NULL
    void *getter_cpy_trampoline;  // Used by CPython to call getter_impl
    void *setter_cpy_trampoline;  // Same; this may be NULL
    const char *doc;
    void *closure;
} HPyGetSet;

typedef enum {
    HPyDef_Kind_Slot = 1,
    HPyDef_Kind_Meth = 2,
    HPyDef_Kind_Member = 3,
    HPyDef_Kind_GetSet = 4,
} HPyDef_Kind;

typedef struct {
    HPyDef_Kind kind;
    union {
        HPySlot slot;
        HPyMeth meth;
        HPyMember member;
        HPyGetSet getset;
    };
} HPyDef;

// macros to automatically define HPyDefs of various kinds

/* ~~~ HPySlot_SIG ~~~

  Macro-magic to automatically determine the HPyFunc_Signature from a
  symbolic slot name such as HPy_tp_repr, HPy_nb_add, etc.
 */

#define HPySlot_SIG(SLOT) _HPySlot_SIG__##SLOT
// Macros such as _HPySlot_SIG__HPy_tp_add &co. are defined in autogen_hpyslot.h



/* ~~~ HPyDef_SLOT ~~~

   This is the official version of HPyDef_SLOT, which automatically determines
   the SIG from the SLOT. The anonymous enum is needed to get a nice
   compile-time error in case we pass a SLOT which does not exist, see the
   more detailed explanation in the comments around HPyFunc_DECLARE in
   hpyfunc.h
*/
#define HPyDef_SLOT(SYM, IMPL, SLOT)                            \
    enum { SYM##_slot = SLOT };                                 \
    _HPyDef_SLOT(SYM, IMPL, SLOT, HPySlot_SIG(SLOT))

// this is the actual implementation, after we determined the SIG
#define _HPyDef_SLOT(SYM, IMPL, SLOT, SIG)                              \
    HPyFunc_DECLARE(IMPL, SIG);                                         \
    HPyFunc_TRAMPOLINE(SYM##_trampoline, IMPL, SIG);                    \
    HPyDef SYM = {                                                      \
        .kind = HPyDef_Kind_Slot,                                       \
        .slot = {                                                       \
            .slot = SLOT,                                               \
            .impl = IMPL,                                               \
            .cpy_trampoline = SYM##_trampoline                          \
        }                                                               \
    };


#define HPyDef_METH(SYM, NAME, IMPL, SIG, ...)                          \
    HPyFunc_DECLARE(IMPL, SIG);                                         \
    HPyFunc_TRAMPOLINE(SYM##_trampoline, IMPL, SIG);                    \
    HPyDef SYM = {                                                      \
        .kind = HPyDef_Kind_Meth,                                       \
        .meth = {                                                       \
            .name = NAME,                                               \
            .impl = IMPL,                                               \
            .cpy_trampoline = SYM##_trampoline,                         \
            .signature = SIG,                                           \
            __VA_ARGS__                                                 \
        }                                                               \
    };

#define HPyDef_MEMBER(SYM, NAME, TYPE, OFFSET, ...) \
    HPyDef SYM = {                                  \
        .kind = HPyDef_Kind_Member,                 \
        .member = {                                 \
            .name = NAME,                           \
            .type = TYPE,                           \
            .offset = OFFSET,                       \
            __VA_ARGS__                             \
        }                                           \
    };

#define HPyDef_GET(SYM, NAME, GETIMPL, ...)                                 \
    HPyFunc_DECLARE(GETIMPL, HPyFunc_GETTER);                               \
    HPyFunc_TRAMPOLINE(SYM##_get_trampoline, GETIMPL, HPyFunc_GETTER);      \
    HPyDef SYM = {                                                          \
        .kind = HPyDef_Kind_GetSet,                                         \
        .getset = {                                                         \
            .name = NAME,                                                   \
            .getter_impl = GETIMPL,                                         \
            .getter_cpy_trampoline = SYM##_get_trampoline,                  \
            __VA_ARGS__                                                     \
        }                                                                   \
    };

#define HPyDef_SET(SYM, NAME, SETIMPL, ...)                                 \
    HPyFunc_DECLARE(SETIMPL, HPyFunc_SETTER);                               \
    HPyFunc_TRAMPOLINE(SYM##_set_trampoline, SETIMPL, HPyFunc_SETTER);      \
    HPyDef SYM = {                                                          \
        .kind = HPyDef_Kind_GetSet,                                         \
        .getset = {                                                         \
            .name = NAME,                                                   \
            .setter_impl = SETIMPL,                                         \
            .setter_cpy_trampoline = SYM##_set_trampoline,                  \
            __VA_ARGS__                                                     \
        }                                                                   \
    };

#define HPyDef_GETSET(SYM, NAME, GETIMPL, SETIMPL, ...)                     \
    HPyFunc_DECLARE(GETIMPL, HPyFunc_GETTER);                               \
    HPyFunc_DECLARE(SETIMPL, HPyFunc_SETTER);                               \
    HPyFunc_TRAMPOLINE(SYM##_get_trampoline, GETIMPL, HPyFunc_GETTER);      \
    HPyFunc_TRAMPOLINE(SYM##_set_trampoline, SETIMPL, HPyFunc_SETTER);      \
    HPyDef SYM = {                                                          \
        .kind = HPyDef_Kind_GetSet,                                         \
        .getset = {                                                         \
            .name = NAME,                                                   \
            .getter_impl = GETIMPL,                                         \
            .setter_impl = SETIMPL,                                         \
            .getter_cpy_trampoline = SYM##_get_trampoline,                  \
            .setter_cpy_trampoline = SYM##_set_trampoline,                  \
            __VA_ARGS__                                                     \
        }                                                                   \
    };

#endif /* HPY_UNIVERSAL_HPYDEF_H */
