/*
 * ioaccess.h
 *
 * Windows Device Driver Kit
 *
 * This file is part of the w32api package.
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
#ifndef __IOACCESS_H
#define __IOACCESS_H

#ifdef __cplusplus
extern "C" {
#endif

#define H2I(p) PtrToUshort(p)

#ifndef NO_PORT_MACROS

#if defined(_X86_) || defined(_M_AMD64)
#define READ_REGISTER_UCHAR(r) (*(volatile UCHAR *)(r))
#define READ_REGISTER_USHORT(r) (*(volatile USHORT *)(r))
#define READ_REGISTER_ULONG(r) (*(volatile ULONG *)(r))
#define WRITE_REGISTER_UCHAR(r, v) (*(volatile UCHAR *)(r) = (v))
#define WRITE_REGISTER_USHORT(r, v) (*(volatile USHORT *)(r) = (v))
#define WRITE_REGISTER_ULONG(r, v) (*(volatile ULONG *)(r) = (v))
#define READ_PORT_UCHAR(p) (UCHAR)(__inbyte (H2I(p)))
#define READ_PORT_USHORT(p) (USHORT)(__inword (H2I(p)))
#define READ_PORT_ULONG(p) (ULONG)(__indword (H2I(p)))
#define WRITE_PORT_UCHAR(p, v) __outbyte (H2I(p), (v))
#define WRITE_PORT_USHORT(p, v) __outword (H2I(p), (v))
#define WRITE_PORT_ULONG(p, v) __outdword (H2I(p), (v))

#define MEMORY_BARRIER()

#elif defined(_PPC_) || defined(_MIPS_) || defined(_ARM_)

#define READ_REGISTER_UCHAR(r)      (*(volatile UCHAR * const)(r))
#define READ_REGISTER_USHORT(r)     (*(volatile USHORT * const)(r))
#define READ_REGISTER_ULONG(r)      (*(volatile ULONG * const)(r))
#define WRITE_REGISTER_UCHAR(r, v)  (*(volatile UCHAR * const)(r) = (v))
#define WRITE_REGISTER_USHORT(r, v) (*(volatile USHORT * const)(r) = (v))
#define WRITE_REGISTER_ULONG(r, v)  (*(volatile ULONG * const)(r) = (v))
#define READ_PORT_UCHAR(r)          READ_REGISTER_UCHAR(r)
#define READ_PORT_USHORT(r)         READ_REGISTER_USHORT(r)
#define READ_PORT_ULONG(r)          READ_REGISTER_ULONG(r)
#define WRITE_PORT_UCHAR(p, v)      WRITE_REGISTER_UCHAR(p, (UCHAR) (v))
#define WRITE_PORT_USHORT(p, v)     WRITE_REGISTER_USHORT(p, (USHORT) (v))
#define WRITE_PORT_ULONG(p, v)      WRITE_REGISTER_ULONG(p, (ULONG) (v))

#else

#error Unsupported architecture

#endif

#endif /* NO_PORT_MACROS */

#ifdef __cplusplus
}
#endif

#endif /* __IOACCESS_H */
