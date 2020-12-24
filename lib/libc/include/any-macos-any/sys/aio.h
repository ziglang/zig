/*
 * Copyright (c) 2003-2006 Apple Computer, Inc. All rights reserved.
 *
 * @APPLE_OSREFERENCE_LICENSE_HEADER_START@
 *
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. The rights granted to you under the License
 * may not be used to create, or enable the creation or redistribution of,
 * unlawful or unlicensed copies of an Apple operating system, or to
 * circumvent, violate, or enable the circumvention or violation of, any
 * terms of an Apple operating system software license agreement.
 *
 * Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this file.
 *
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 *
 * @APPLE_OSREFERENCE_LICENSE_HEADER_END@
 */
/*
 *	File:	sys/aio.h
 *	Author:	Umesh Vaishampayan [umeshv@apple.com]
 *			05-Feb-2003	umeshv	Created.
 *
 *	Header file for POSIX Asynchronous IO APIs
 *
 */

#ifndef _SYS_AIO_H_
#define _SYS_AIO_H_

#include <sys/signal.h>
#include <sys/_types.h>
#include <sys/cdefs.h>

/*
 * [XSI] Inclusion of the <aio.h> header may make visible symbols defined
 * in the headers <fcntl.h>, <signal.h>, <sys/types.h>, and <time.h>.
 *
 * In our case, this is limited to struct timespec, off_t and ssize_t.
 */
#include <sys/_types/_timespec.h>

#include <sys/_types/_off_t.h>
#include <sys/_types/_ssize_t.h>

/*
 * A aio_fsync() options that the calling thread is to continue execution
 * while the lio_listio() operation is being performed, and no notification
 * is given when the operation is complete
 *
 * [XSI] from <fcntl.h>
 */
#include <sys/_types/_o_sync.h>
#include <sys/_types/_o_dsync.h>

struct aiocb {
	int             aio_fildes;             /* File descriptor */
	off_t           aio_offset;             /* File offset */
	volatile void   *aio_buf;               /* Location of buffer */
	size_t          aio_nbytes;             /* Length of transfer */
	int             aio_reqprio;            /* Request priority offset */
	struct sigevent aio_sigevent;           /* Signal number and value */
	int             aio_lio_opcode;         /* Operation to be performed */
};


/*
 * aio_cancel() return values
 */

/*
 * none of the requested operations could be canceled since they are
 * already complete.
 */
#define AIO_ALLDONE                     0x1

/* all requested operations have been canceled */
#define AIO_CANCELED            0x2

/*
 * some of the requested operations could not be canceled since
 * they are in progress
 */
#define AIO_NOTCANCELED         0x4


/*
 * lio_listio operation options
 */

#define LIO_NOP                 0x0     /* option indicating that no transfer is requested */
#define LIO_READ                0x1             /* option requesting a read */
#define LIO_WRITE               0x2             /* option requesting a write */

/*
 * lio_listio() modes
 */

/*
 * A lio_listio() synchronization operation indicating
 * that the calling thread is to continue execution while
 * the lio_listio() operation is being performed, and no
 * notification is given when the operation is complete
 */
#define LIO_NOWAIT              0x1

/*
 * A lio_listio() synchronization operation indicating
 * that the calling thread is to suspend until the
 * lio_listio() operation is complete.
 */
#define LIO_WAIT                0x2

/*
 * Maximum number of operations in single lio_listio call
 */
#define AIO_LISTIO_MAX          16


/*
 * Prototypes
 */

__BEGIN_DECLS

/*
 * Attempt to cancel one or more asynchronous I/O requests currently outstanding
 * against file descriptor fd. The aiocbp argument points to the asynchronous I/O
 * control block for a particular request to be canceled.  If aiocbp is NULL, then
 * all outstanding cancelable asynchronous I/O requests against fd shall be canceled.
 */
int             aio_cancel( int fd,
    struct aiocb * aiocbp );

/*
 * Return the error status associated with the aiocb structure referenced by the
 * aiocbp argument. The error status for an asynchronous I/O operation is the errno
 * value that would be set by the corresponding read(), write(),  or fsync()
 * operation.  If the operation has not yet completed, then the error status shall
 * be equal to [EINPROGRESS].
 */
int             aio_error( const struct aiocb * aiocbp );

/*
 * Asynchronously force all I/O operations associated with the file indicated by
 * the file descriptor aio_fildes member of the aiocb structure referenced by the
 * aiocbp argument and queued at the time of the call to aio_fsync() to the
 * synchronized I/O completion state.  The function call shall return when the
 * synchronization request has been initiated or queued.  op O_SYNC is the only
 * supported opertation at this time.
 * The aiocbp argument refers to an asynchronous I/O control block. The aiocbp
 * value may be used as an argument to aio_error() and aio_return() in order to
 * determine the error status and return status, respectively, of the asynchronous
 * operation while it is proceeding.  When the request is queued, the error status
 * for the operation is [EINPROGRESS]. When all data has been successfully
 * transferred, the error status shall be reset to reflect the success or failure
 * of the operation.
 */
int             aio_fsync( int op,
    struct aiocb * aiocbp );

/*
 * Read aiocbp->aio_nbytes from the file associated with aiocbp->aio_fildes into
 * the buffer pointed to by aiocbp->aio_buf.  The function call shall return when
 * the read request has been initiated or queued.
 * The aiocbp value may be used as an argument to aio_error() and aio_return() in
 * order to determine the error status and return status, respectively, of the
 * asynchronous operation while it is proceeding. If an error condition is
 * encountered during queuing, the function call shall return without having
 * initiated or queued the request. The requested operation takes place at the
 * absolute position in the file as given by aio_offset, as if lseek() were called
 * immediately prior to the operation with an offset equal to aio_offset and a
 * whence equal to SEEK_SET.  After a successful call to enqueue an asynchronous
 * I/O operation, the value of the file offset for the file is unspecified.
 */
int             aio_read( struct aiocb * aiocbp );

/*
 * Return the return status associated with the aiocb structure referenced by
 * the aiocbp argument.  The return status for an asynchronous I/O operation is
 * the value that would be returned by the corresponding read(), write(), or
 * fsync() function call.  If the error status for the operation is equal to
 * [EINPROGRESS], then the return status for the operation is undefined.  The
 * aio_return() function may be called exactly once to retrieve the return status
 * of a given asynchronous operation; thereafter, if the same aiocb structure
 * is used in a call to aio_return() or aio_error(), an error may be returned.
 * When the aiocb structure referred to by aiocbp is used to submit another
 * asynchronous operation, then aio_return() may be successfully used to
 * retrieve the return status of that operation.
 */
ssize_t aio_return( struct aiocb * aiocbp );

/*
 * Suspend the calling thread until at least one of the asynchronous I/O
 * operations referenced by the aiocblist argument has completed, until a signal
 * interrupts the function, or, if timeout is not NULL, until the time
 * interval specified by timeout has passed.  If any of the aiocb structures
 * in the aiocblist correspond to completed asynchronous I/O operations (that is,
 * the error status for the operation is not equal to [EINPROGRESS]) at the
 * time of the call, the function shall return without suspending the calling
 * thread.  The aiocblist argument is an array of pointers to asynchronous I/O
 * control blocks.  The nent argument indicates the number of elements in the
 * array.  Each aiocb structure pointed to has been used in initiating an
 * asynchronous I/O request via aio_read(), aio_write(), or lio_listio(). This
 * array may contain NULL pointers, which are ignored.
 */
int             aio_suspend( const struct aiocb *const aiocblist[],
    int nent,
    const struct timespec * timeoutp ) __DARWIN_ALIAS_C(aio_suspend);

/*
 * Write aiocbp->aio_nbytes to the file associated with aiocbp->aio_fildes from
 * the buffer pointed to by aiocbp->aio_buf.  The function shall return when the
 * write request has been initiated or, at a minimum, queued.
 * The aiocbp argument may be used as an argument to aio_error() and aio_return()
 * in order to determine the error status and return status, respectively, of the
 * asynchronous operation while it is proceeding.
 */
int             aio_write( struct aiocb * aiocbp );

/*
 * Initiate a list of I/O requests with a single function call.  The mode
 * argument takes one of the values LIO_WAIT or LIO_NOWAIT and determines whether
 * the function returns when the I/O operations have been completed, or as soon
 * as the operations have been queued.  If the mode argument is LIO_WAIT, the
 * function shall wait until all I/O is complete and the sig argument shall be
 * ignored.
 * If the mode argument is LIO_NOWAIT, the function shall return immediately, and
 * asynchronous notification shall occur, according to the sig argument, when all
 * the I/O operations complete.  If sig is NULL, then no asynchronous notification
 * shall occur.
 */
int             lio_listio( int mode,
    struct aiocb *const aiocblist[],
    int nent,
    struct sigevent *sigp );
__END_DECLS

#endif /* _SYS_AIO_H_ */