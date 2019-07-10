/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _WINDOWS_
#define _WINDOWS_

#include <_mingw.h>
#include <sdkddkver.h>

/* Some kludge for Obj-C.
   For Obj-C the 'interface' is a keyword, but interface is used
   in midl-code too.  To resolve this conflict for at least the
   main windows API header, we define it here temporary.  */
#ifdef __OBJC__
#pragma push_macro("interface")
#undef interface
#define interface struct
#endif

#ifndef _INC_WINDOWS
#define _INC_WINDOWS

#if defined(RC_INVOKED) && !defined(NOWINRES)

#include <winresrc.h>
#else

#ifdef RC_INVOKED
#define NOATOM
#define NOGDI
#define NOGDICAPMASKS
#define NOMETAFILE
#define NOMINMAX
#define NOMSG
#define NOOPENFILE
#define NORASTEROPS
#define NOSCROLL
#define NOSOUND
#define NOSYSMETRICS
#define NOTEXTMETRIC
#define NOWH
#define NOCOMM
#define NOKANJI
#define NOCRYPT
#define NOMCX
#endif

#if defined(__x86_64) && \
  !(defined(_X86_) || defined(__i386__) || defined(_IA64_))
#if !defined(_AMD64_)
#define _AMD64_
#endif
#endif /* _AMD64_ */

#if defined(__ia64__) && \
  !(defined(_X86_) || defined(__x86_64) || defined(_AMD64_))
#if !defined(_IA64_)
#define _IA64_
#endif
#endif /* _IA64_ */

#ifndef RC_INVOKED
#include <excpt.h>
#include <stdarg.h>
#endif

#include <windef.h>
#include <winbase.h>
#include <wingdi.h>
#include <winuser.h>
#include <winnls.h>
#include <wincon.h>
#include <winver.h>
#include <winreg.h>
#include <winnetwk.h>
#include <virtdisk.h>

#ifndef WIN32_LEAN_AND_MEAN
#include <cderr.h>
#include <dde.h>
#include <ddeml.h>
#include <dlgs.h>
#include <lzexpand.h>
#include <mmsystem.h>
#include <nb30.h>
#include <rpc.h>
#include <shellapi.h>
#include <winperf.h>
#if defined(__USE_W32_SOCKETS) || !defined(__CYGWIN__)
#include <winsock.h>
#endif
#ifndef NOCRYPT
#include <wincrypt.h>
#include <winefs.h>
#include <winscard.h>
#endif

#ifndef NOUSER
#ifndef NOGDI
#include <winspool.h>
#ifdef INC_OLE1
#include <ole.h>
#else
#include <ole2.h>
#endif
#include <commdlg.h>
#endif
#endif
#endif

#ifndef __CYGWIN__
#include <stralign.h>
#endif

#ifdef INC_OLE2
#include <ole2.h>
#endif

#ifndef NOSERVICE
#include <winsvc.h>
#endif

#ifndef NOMCX
#include <mcx.h>
#endif

#ifndef NOIME
#include <imm.h>
#endif

#endif
#endif

/* Restore old value of interface for Obj-C.  See above.  */
#ifdef __OBJC__
#pragma pop_macro("interface")
#endif

#endif
