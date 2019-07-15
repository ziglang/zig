/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef __MINGW_TRANSMIT_FILE_H
#define __MINGW_TRANSMIT_FILE_H

typedef struct _TRANSMIT_FILE_BUFFERS {
	LPVOID	Head;
	DWORD	HeadLength;
	LPVOID	Tail;
	DWORD	TailLength;
} TRANSMIT_FILE_BUFFERS, *PTRANSMIT_FILE_BUFFERS, *LPTRANSMIT_FILE_BUFFERS;

#endif	/* __MINGW_TRANSMIT_FILE_H */

