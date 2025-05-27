/*-
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2013 FreeBSD Foundation
 *
 * This software was developed by Pawel Jakub Dawidek under sponsorship from
 * the FreeBSD Foundation.
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
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef _SYS_CAPRIGHTS_H_
#define	_SYS_CAPRIGHTS_H_

/*
 * The top two bits in the first element of the cr_rights[] array contain
 * total number of elements in the array - 2. This means if those two bits are
 * equal to 0, we have 2 array elements.
 * The top two bits in all remaining array elements should be 0.
 * The next five bits contain array index. Only one bit is used and bit position
 * in this five-bits range defines array index. This means there can be at most
 * five array elements.
 */
#define	CAP_RIGHTS_VERSION_00	0
/*
#define	CAP_RIGHTS_VERSION_01	1
#define	CAP_RIGHTS_VERSION_02	2
#define	CAP_RIGHTS_VERSION_03	3
*/
#define	CAP_RIGHTS_VERSION	CAP_RIGHTS_VERSION_00

struct cap_rights {
	uint64_t	cr_rights[CAP_RIGHTS_VERSION + 2];
};

#ifndef	_CAP_RIGHTS_T_DECLARED
#define	_CAP_RIGHTS_T_DECLARED
typedef	struct cap_rights	cap_rights_t;
#endif

#ifdef _KERNEL
extern cap_rights_t cap_accept_rights;
extern cap_rights_t cap_bind_rights;
extern cap_rights_t cap_connect_rights;
extern cap_rights_t cap_event_rights;
extern cap_rights_t cap_fchdir_rights;
extern cap_rights_t cap_fchflags_rights;
extern cap_rights_t cap_fchmod_rights;
extern cap_rights_t cap_fchown_rights;
extern cap_rights_t cap_fcntl_rights;
extern cap_rights_t cap_fexecve_rights;
extern cap_rights_t cap_flock_rights;
extern cap_rights_t cap_fpathconf_rights;
extern cap_rights_t cap_fstat_rights;
extern cap_rights_t cap_fstatfs_rights;
extern cap_rights_t cap_fsync_rights;
extern cap_rights_t cap_ftruncate_rights;
extern cap_rights_t cap_futimes_rights;
extern cap_rights_t cap_getpeername_rights;
extern cap_rights_t cap_getsockopt_rights;
extern cap_rights_t cap_getsockname_rights;
extern cap_rights_t cap_ioctl_rights;
extern cap_rights_t cap_linkat_source_rights;
extern cap_rights_t cap_linkat_target_rights;
extern cap_rights_t cap_listen_rights;
extern cap_rights_t cap_mkdirat_rights;
extern cap_rights_t cap_mkfifoat_rights;
extern cap_rights_t cap_mknodat_rights;
extern cap_rights_t cap_mmap_rights;
extern cap_rights_t cap_no_rights;
extern cap_rights_t cap_pdgetpid_rights;
extern cap_rights_t cap_pdkill_rights;
extern cap_rights_t cap_pread_rights;
extern cap_rights_t cap_pwrite_rights;
extern cap_rights_t cap_read_rights;
extern cap_rights_t cap_recv_rights;
extern cap_rights_t cap_renameat_source_rights;
extern cap_rights_t cap_renameat_target_rights;
extern cap_rights_t cap_seek_rights;
extern cap_rights_t cap_send_rights;
extern cap_rights_t cap_send_connect_rights;
extern cap_rights_t cap_setsockopt_rights;
extern cap_rights_t cap_shutdown_rights;
extern cap_rights_t cap_symlinkat_rights;
extern cap_rights_t cap_unlinkat_rights;
extern cap_rights_t cap_write_rights;
#endif

#endif /* !_SYS_CAPRIGHTS_H_ */