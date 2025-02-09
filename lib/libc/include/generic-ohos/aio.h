#ifndef _AIO_H
#define _AIO_H

#ifdef __cplusplus
extern "C" {
#endif

#include <features.h>
#include <signal.h>
#include <time.h>

#define __NEED_ssize_t
#define __NEED_off_t

#include <bits/alltypes.h>

struct aiocb {
	int aio_fildes, aio_lio_opcode, aio_reqprio;
	volatile void *aio_buf;
	size_t aio_nbytes;
	struct sigevent aio_sigevent;
	void *__td;
	int __lock[2];
	volatile int __err;
	ssize_t __ret;
	off_t aio_offset;
	void *__next, *__prev;
	char __dummy4[32-2*sizeof(void *)];
};

#define AIO_CANCELED 0
#define AIO_NOTCANCELED 1
#define AIO_ALLDONE 2

#define LIO_READ 0
#define LIO_WRITE 1
#define LIO_NOP 2

#define LIO_WAIT 0
#define LIO_NOWAIT 1

#if defined(_LARGEFILE64_SOURCE) || defined(_GNU_SOURCE)
#define aiocb64 aiocb
#define off64_t off_t
#endif

#ifdef __cplusplus
}
#endif

#endif
