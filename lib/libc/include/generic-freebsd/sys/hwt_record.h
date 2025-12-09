/*-
 * Copyright (c) 2023-2025 Ruslan Bukin <br@bsdpad.com>
 *
 * This work was supported by Innovate UK project 105694, "Digital Security
 * by Design (DSbD) Technology Platform Prototype".
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

/* User-visible header. */

#ifndef _SYS_HWT_RECORD_H_
#define _SYS_HWT_RECORD_H_

enum hwt_record_type {
	HWT_RECORD_MMAP,
	HWT_RECORD_MUNMAP,
	HWT_RECORD_EXECUTABLE,
	HWT_RECORD_KERNEL,
	HWT_RECORD_THREAD_CREATE,
	HWT_RECORD_THREAD_SET_NAME,
	HWT_RECORD_BUFFER
};

#ifdef _KERNEL
struct hwt_record_entry {
	TAILQ_ENTRY(hwt_record_entry)	next;
	enum hwt_record_type record_type;
	union {
		/*
		 * Used for MMAP, EXECUTABLE, INTERP,
		 * and KERNEL records.
		 */
		struct {
			char *fullpath;
			uintptr_t addr;
			uintptr_t baseaddr;
		};
		/* Used for BUFFER records. */
		struct {
			int buf_id;
			int curpage;
			vm_offset_t offset;
		};
		/* Used for THREAD_* records. */
		int thread_id;
	};
};
#endif

#endif /* !_SYS_HWT_RECORD_H_ */