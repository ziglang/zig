/*
 * ksdebug.h
 *
 * This file is part of the ReactOS PSDK package.
 *
 * Contributors:
 *   Created by Magnus Olsen.
 *
 * THIS SOFTWARE IS NOT COPYRIGHTED
 *
 * This source code is offered for use in the public domain. You may
 * use, modify or distribute it freely.
 *
 * This code is distributed in the hope that it will be useful but
 * WITHOUT ANY WARRANTY. ALL WARRANTIES, EXPRESS OR IMPLIED ARE HEREBY
 * DISCLAIMED. This includes but is not limited to warranties of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */

#include <evntrace.h>

#if !defined(_KSDEBUG_)
#define _KSDEBUG_

#if !defined(REMIND)
#define QUOTE(x) #x
#define QQUOTE(y) QUOTE(y)
#define REMIND(str) __FILE__ "(" QQUOTE(__LINE__) ") : " str
#endif

#if defined(__cplusplus)
extern "C" {
#endif

#if (DBG)

#if defined(IRPMJFUNCDESC)
static const PCHAR IrpMjFuncDesc[] = {
  "IRP_MJ_CREATE",
  "IRP_MJ_CREATE_NAMED_PIPE",
  "IRP_MJ_CLOSE",
  "IRP_MJ_READ",
  "IRP_MJ_WRITE",
  "IRP_MJ_QUERY_INFORMATION",
  "IRP_MJ_SET_INFORMATION",
  "IRP_MJ_QUERY_EA",
  "IRP_MJ_SET_EA",
  "IRP_MJ_FLUSH_BUFFERS",
  "IRP_MJ_QUERY_VOLUME_INFORMATION",
  "IRP_MJ_SET_VOLUME_INFORMATION",
  "IRP_MJ_DIRECTORY_CONTROL",
  "IRP_MJ_FILE_SYSTEM_CONTROL",
  "IRP_MJ_DEVICE_CONTROL",
  "IRP_MJ_INTERNAL_DEVICE_CONTROL",
  "IRP_MJ_SHUTDOWN",
  "IRP_MJ_LOCK_CONTROL",
  "IRP_MJ_CLEANUP",
  "IRP_MJ_CREATE_MAILSLOT",
  "IRP_MJ_QUERY_SECURITY",
  "IRP_MJ_SET_SECURITY",
  "IRP_MJ_SET_POWER",
  "IRP_MJ_QUERY_POWER"
};
#endif /* defined(IRPMJFUNCDESC) */

#endif /* DBG */

#if defined(_NTDDK_)

#define DEBUGLVL_BLAB TRACE_LEVEL_VERBOSE
#define DEBUGLVL_VERBOSE TRACE_LEVEL_VERBOSE
#define DEBUGLVL_TERSE TRACE_LEVEL_INFORMATION
#define DEBUGLVL_ERROR TRACE_LEVEL_ERROR

#define DEBUGLVL_WARNING TRACE_LEVEL_WARNING
#define DEBUGLVL_INFO TRACE_LEVEL_INFORMATION

#if (DBG)
# if !defined( DEBUG_LEVEL )
#   if defined( DEBUG_VARIABLE )
#     if defined( KSDEBUG_INIT )
	ULONG DEBUG_VARIABLE = DEBUGLVL_TERSE;
#     else
	extern ULONG DEBUG_VARIABLE;
#     endif
#   else
#	define DEBUG_VARIABLE DEBUGLVL_TERSE
#   endif
# else
#   if defined( DEBUG_VARIABLE )
#     if defined( KSDEBUG_INIT )
	ULONG DEBUG_VARIABLE = DEBUG_LEVEL;
#     else
	extern ULONG DEBUG_VARIABLE;
#     endif
#   else
#	define DEBUG_VARIABLE DEBUG_LEVEL
#   endif
# endif

#if (NTDDI_VERSION >= NTDDI_WINXP)
#  define _DbgPrintFEx(component, lvl, strings) {		\
    if ((lvl) <= DEBUG_VARIABLE) {				\
      DbgPrintEx(component, lvl, STR_MODULENAME);		\
      DbgPrintEx(component, lvl, strings);			\
      DbgPrintEx(component, lvl, "\n");				\
      if ((lvl) == DEBUGLVL_ERROR) {				\
	DbgBreakPoint();					\
      }								\
    }								\
  }
#endif /* (NTDDI_VERSION >= NTDDI_WINXP) */

#  define _DbgPrintF(lvl, strings) {				\
    if (((lvl)==DEBUG_VARIABLE) || (lvl < DEBUG_VARIABLE)) {	\
      DbgPrint(STR_MODULENAME);					\
      DbgPrint##strings;					\
      DbgPrint("\n");						\
      if ((lvl) == DEBUGLVL_ERROR) {				\
	DbgBreakPoint();					\
      }								\
    }								\
  }

#else /* ! DBG */

#define _DbgPrintF(lvl, strings)

#if (NTDDI_VERSION >= NTDDI_WINXP)
#define _DbgPrintFEx(component, lvl, strings)
#endif

#endif /* DBG */

#endif /* defined(_NTDDK_) */

#if defined(__cplusplus)
}
#endif

#endif /* _KSDEBUG_ */
