/*	$NetBSD: rump_syscallshotgun.h,v 1.1 2016/01/31 23:14:34 pooka Exp $	*/

/*
 * Copyright (c) 2009 Antti Kantee.  All Rights Reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS
 * OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

/*
 * "shotgun approach to rump syscalls", as stated in the original
 * commit message
 */

#ifndef _RUMP_RUMP_SYSCALLSHOTGUN_H_
#define _RUMP_RUMP_SYSCALLSHOTGUN_H_

#ifdef RUMP_SYS_NETWORKING
#include <sys/socket.h>
#define socket(a,b,c) rump_sys_socket(a,b,c)
#define accept(a,b,c) rump_sys_accept(a,b,c)
#define bind(a,b,c) rump_sys_bind(a,b,c)
#define connect(a,b,c) rump_sys_connect(a,b,c)
#define getpeername(a,b,c) rump_sys_getpeername(a,b,c)
#define getsockname(a,b,c) rump_sys_getsockname(a,b,c)
#define listen(a,b) rump_sys_listen(a,b)
#define recvfrom(a,b,c,d,e,f) rump_sys_recvfrom(a,b,c,d,e,f)
#define recvmsg(a,b,c) rump_sys_recvmsg(a,b,c)
#define sendto(a,b,c,d,e,f) rump_sys_sendto(a,b,c,d,e,f)
#define sendmsg(a,b,c) rump_sys_sendmsg(a,b,c)
#define getsockopt(a,b,c,d,e) rump_sys_getsockopt(a,b,c,d,e)
#define setsockopt(a,b,c,d,e) rump_sys_setsockopt(a,b,c,d,e)
#define shutdown(a,b) rump_sys_shutdown(a,b)
#endif /* RUMP_SYS_NETWORKING */

#ifdef RUMP_SYS_IOCTL
#include <sys/ioctl.h>
#define ioctl(...) rump_sys_ioctl(__VA_ARGS__)
#define fcntl(...) rump_sys_fcntl(__VA_ARGS__)
#endif /* RUMP_SYS_IOCTL */

#ifdef RUMP_SYS_CLOSE
#include <fcntl.h>
#define close(a) rump_sys_close(a)
#endif /* RUMP_SYS_CLOSE */

#ifdef RUMP_SYS_OPEN
#include <fcntl.h>
#define open(...) rump_sys_open(__VA_ARGS__)
#endif /* RUMP_SYS_OPEN */

#ifdef RUMP_SYS_READWRITE
#include <fcntl.h>
#define read(a,b,c) rump_sys_read(a,b,c)
#define readv(a,b,c) rump_sys_readv(a,b,c)
#define pread(a,b,c,d) rump_sys_pread(a,b,c,d)
#define preadv(a,b,c,d) rump_sys_preadv(a,b,c,d)
#define write(a,b,c) rump_sys_write(a,b,c)
#define writev(a,b,c) rump_sys_writev(a,b,c)
#define pwrite(a,b,c,d) rump_sys_pwrite(a,b,c,d)
#define pwritev(a,b,c,d) rump_sys_pwritev(a,b,c,d)
#endif /* RUMP_SYS_READWRITE */

#ifdef RUMP_SYS_FILEOPS
#include <stdlib.h>
#include <unistd.h>
#define mkdir(a,b) rump_sys_mkdir(a,b)
#define rmdir(a) rump_sys_rmdir(a)
#define link(a,b) rump_sys_link(a,b)
#define symlink(a,b) rump_sys_symlink(a,b)
#define unlink(a) rump_sys_unlink(a)
#define readlink(a,b,c) rump_sys_readlink(a,b,c)
#define chdir(a) rump_sys_chdir(a)
#define fsync(a) rump_sys_fsync(a)
#define sync() rump_sys_sync()
#define chown(a,b,c) rump_sys_chown(a,b,c)
#define fchown(a,b,c) rump_sys_fchown(a,b,c)
#define lchown(a,b,c) rump_sys_lchown(a,b,c)
#define lseek(a,b,c) rump_sys_lseek(a,b,c)
#define mknod(a,b,c) rump_sys_mknod(a,b,c)
#define rename(a,b) rump_sys_rename(a,b)
#define truncate(a,b) rump_sys_truncate(a,b)
#define ftruncate(a,b) rump_sys_ftruncate(a,b)
#define umask(a) rump_sys_umask(a)
#define getdents(a,b,c) rump_sys_getdents(a,b,c)
#endif /* RUMP_SYS_FILEOPS */

#ifdef RUMP_SYS_STAT
#include <sys/stat.h>
#define stat(a,b) rump_sys_stat(a,b)
#define fstat(a,b) rump_sys_fstat(a,b)
#define lstat(a,b) rump_sys_lstat(a,b)
#endif /* RUMP_SYS_STAT */

#ifdef RUMP_SYS_PROCOPS
#include <unistd.h>
#define getpid() rump_sys_getpid()
#endif /* RUMP_SYS_PROCOPS */

#endif /* _RUMP_RUMP_SYSCALLSHOTGUN_H_ */