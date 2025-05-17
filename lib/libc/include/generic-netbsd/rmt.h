/*	$NetBSD: rmt.h,v 1.8 2016/01/22 23:15:58 dholland Exp $	*/

/*
 *	rmt.h
 *
 *	Added routines to replace open(), close(), lseek(), ioctl(), etc.
 *	The preprocessor can be used to remap these the rmtopen(), etc
 *	thus minimizing source changes.
 *
 *	This file must be included before <sys/stat.h>, since it redefines
 *	stat to be rmtstat, so that struct stat xyzzy; declarations work
 *	properly.
 *
 *	-- Fred Fish (w/some changes by Arnold Robbins)
 */

#ifndef _RMT_H_
#define _RMT_H_

#include <sys/cdefs.h>
#include <sys/types.h>

#if _FORTIFY_SOURCE > 0
#define __ssp_weak_name(x)	rmt ## x
#include <ssp/unistd.h>
#endif 

__BEGIN_DECLS
int	isrmt(int);
int	rmtaccess(const char *, int);
int	rmtclose(int);
int	rmtcreat(const char *, mode_t);
int	rmtdup(int);
int	rmtfcntl(int, int, ...);
int	rmtfstat(int, struct stat *);
int	rmtioctl(int, unsigned long, ...);
int	rmtisatty(int);
off_t	rmtlseek(int, off_t, int);
int	rmtlstat(const char *, struct stat *);
int	rmtopen(const char *, int, ...);
ssize_t	rmtread(int, void *, size_t);
int	rmtstat(const char *, struct stat *);
ssize_t	rmtwrite(int, const void *, size_t);
__END_DECLS

#ifndef __RMTLIB_PRIVATE	/* don't remap if building librmt */
#define access rmtaccess
#define close rmtclose
#define creat rmtcreat
#define dup rmtdup
#define fcntl rmtfcntl
#define fstat rmtfstat
#define ioctl rmtioctl
#define isatty rmtisatty
#define lseek rmtlseek
#define lstat rmtlstat
#define open rmtopen
#if __SSP_FORTIFY_LEVEL == 0
#define read rmtread
#endif
#define stat rmtstat
#define write rmtwrite
#endif /* __RMTLIB_PRIVATE */

#endif /* _RMT_H_ */