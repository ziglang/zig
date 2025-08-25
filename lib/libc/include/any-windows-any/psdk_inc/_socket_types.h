/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef ___WSA_SOCKET_TYPES_H
#define ___WSA_SOCKET_TYPES_H

#if 1
typedef UINT_PTR	SOCKET;
#else
typedef INT_PTR		SOCKET;
#endif

#define INVALID_SOCKET	(SOCKET)(~0)
#define SOCKET_ERROR	(-1)

#endif /* ___WSA_SOCKET_TYPES_H */

