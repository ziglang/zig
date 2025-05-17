//===------------------------------- unwind.h -----------------------------===//
//
//                     The LLVM Compiler Infrastructure
//
// This file is dual licensed under the MIT and the University of Illinois Open
// Source Licenses. See LICENSE.TXT for details.
//
//
// C++ ABI Level 1 ABI documented at:
//   http://mentorembedded.github.io/cxx-abi/abi-eh.html
//
//===----------------------------------------------------------------------===//

#ifndef _UNWIND_H
#define _UNWIND_H

#include <stdint.h>
#include <stddef.h>

typedef enum {
  _URC_NO_REASON = 0,
  _URC_FOREIGN_EXCEPTION_CAUGHT = 1,
  _URC_FATAL_PHASE2_ERROR = 2,
  _URC_FATAL_PHASE1_ERROR = 3,
  _URC_NORMAL_STOP = 4,
  _URC_END_OF_STACK = 5,
  _URC_HANDLER_FOUND = 6,
  _URC_INSTALL_CONTEXT = 7,
  _URC_CONTINUE_UNWIND = 8
} _Unwind_Reason_Code;

typedef enum {
  _UA_SEARCH_PHASE = 1,
  _UA_CLEANUP_PHASE = 2,
  _UA_HANDLER_FRAME = 4,
  _UA_FORCE_UNWIND = 8,
  _UA_END_OF_STACK = 16 /* GCC extension */
} _Unwind_Action;

struct _Unwind_Context;

struct _Unwind_Exception {
  uint64_t exception_class;
  void (*exception_cleanup)(_Unwind_Reason_Code, struct _Unwind_Exception *);
  uintptr_t private_1;
  uintptr_t private_2;
} __attribute__((__aligned__));

typedef _Unwind_Reason_Code (*_Unwind_Stop_Fn)(int, _Unwind_Action, uint64_t,
                                               struct _Unwind_Exception *,
                                               struct _Unwind_Context *,
                                               void *);

typedef _Unwind_Reason_Code (*__personality_routine)(int, _Unwind_Action,
                                                     uint64_t,
                                                     struct _Unwind_Exception *,
                                                     struct _Unwind_Context *);

#ifdef _UNWIND_GCC_EXTENSIONS
struct dwarf_eh_bases {
  void *tbase;
  void *dbase;
  void *func;
};
#endif

__BEGIN_DECLS

_Unwind_Reason_Code _Unwind_RaiseException(struct _Unwind_Exception *);
void _Unwind_Resume(struct _Unwind_Exception *) __dead;
_Unwind_Reason_Code _Unwind_Resume_or_Rethrow(struct _Unwind_Exception *);
_Unwind_Reason_Code _Unwind_ForcedUnwind(struct _Unwind_Exception *,
                                         _Unwind_Stop_Fn, void *);
void _Unwind_DeleteException(struct _Unwind_Exception *);
uintptr_t _Unwind_GetGR(struct _Unwind_Context *, int);
void _Unwind_SetGR(struct _Unwind_Context *, int, uintptr_t);
uintptr_t _Unwind_GetIP(struct _Unwind_Context *);
uintptr_t _Unwind_GetIPInfo(struct _Unwind_Context *, int *);
uintptr_t _Unwind_GetCFA(struct _Unwind_Context *);
void _Unwind_SetIP(struct _Unwind_Context *, uintptr_t);
uintptr_t _Unwind_GetRegionStart(struct _Unwind_Context *);
uintptr_t _Unwind_GetLanguageSpecificData(struct _Unwind_Context *);
uintptr_t _Unwind_GetDataRelBase(struct _Unwind_Context *);
uintptr_t _Unwind_GetTextRelBase(struct _Unwind_Context *);

typedef _Unwind_Reason_Code (*_Unwind_Trace_Fn)(struct _Unwind_Context *,
                                                void *);
_Unwind_Reason_Code _Unwind_Backtrace(_Unwind_Trace_Fn, void *);
void *_Unwind_FindEnclosingFunction(void *);

void __register_frame(const void *);
void __register_frame_info(const void *, void *);
void __deregister_frame(const void *);
void *__deregister_frame_info(const void *);

#ifdef _UNWIND_GCC_EXTENSIONS
void *_Unwind_Find_FDE(void *, struct dwarf_eh_bases *);
#endif

__END_DECLS

#endif // _UNWIND_H