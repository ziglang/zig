#include "hpy.h"

// work around rffi's lack of support for unions
typedef struct {
    HPyDef_Kind kind;
    HPySlot slot;
} _pypy_HPyDef_as_slot;

typedef struct {
    HPyDef_Kind kind;
    HPyMember member;
} _pypy_HPyDef_as_member;

typedef struct {
    HPyDef_Kind kind;
    HPyGetSet getset;
} _pypy_HPyDef_as_getset;
