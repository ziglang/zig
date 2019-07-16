/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _MSPLOG_H_
#define _MSPLOG_H_

#ifdef MSPLOG

#include <rtutils.h>

#define MSP_ERROR ((DWORD)0x00010000 | TRACE_USE_MASK)
#define MSP_WARN ((DWORD)0x00020000 | TRACE_USE_MASK)
#define MSP_INFO ((DWORD)0x00040000 | TRACE_USE_MASK)
#define MSP_TRACE ((DWORD)0x00080000 | TRACE_USE_MASK)
#define MSP_EVENT ((DWORD)0x00100000 | TRACE_USE_MASK)

WINBOOL NTAPI MSPLogRegister(LPCTSTR szName);
void NTAPI MSPLogDeRegister();
void NTAPI LogPrint(DWORD dwDbgLevel,LPCSTR DbgMessage,...);

#define MSPLOGREGISTER(arg) MSPLogRegister(arg)
#define MSPLOGDEREGISTER() MSPLogDeRegister()

extern WINBOOL g_bMSPBaseTracingOn;

#define LOG(arg) g_bMSPBaseTracingOn?LogPrint arg:0
#else
#define MSPLOGREGISTER(arg)
#define MSPLOGDEREGISTER()
#define LOG(arg)
#endif

#define DECLARE_LOG_ADDREF_RELEASE(x)
#define CMSPComObject CComObject
#endif
