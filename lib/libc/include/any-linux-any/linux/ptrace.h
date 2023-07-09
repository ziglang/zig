/* SPDX-License-Identifier: GPL-2.0 WITH Linux-syscall-note */
#ifndef _LINUX_PTRACE_H
#define _LINUX_PTRACE_H
/* ptrace.h */
/* structs and defines to help the user use the ptrace system call. */

/* has the defines to get at the registers. */

#include <linux/types.h>

#define PTRACE_TRACEME		   0
#define PTRACE_PEEKTEXT		   1
#define PTRACE_PEEKDATA		   2
#define PTRACE_PEEKUSR		   3
#define PTRACE_POKETEXT		   4
#define PTRACE_POKEDATA		   5
#define PTRACE_POKEUSR		   6
#define PTRACE_CONT		   7
#define PTRACE_KILL		   8
#define PTRACE_SINGLESTEP	   9

#define PTRACE_ATTACH		  16
#define PTRACE_DETACH		  17

#define PTRACE_SYSCALL		  24

/* 0x4200-0x4300 are reserved for architecture-independent additions.  */
#define PTRACE_SETOPTIONS	0x4200
#define PTRACE_GETEVENTMSG	0x4201
#define PTRACE_GETSIGINFO	0x4202
#define PTRACE_SETSIGINFO	0x4203

/*
 * Generic ptrace interface that exports the architecture specific regsets
 * using the corresponding NT_* types (which are also used in the core dump).
 * Please note that the NT_PRSTATUS note type in a core dump contains a full
 * 'struct elf_prstatus'. But the user_regset for NT_PRSTATUS contains just the
 * elf_gregset_t that is the pr_reg field of 'struct elf_prstatus'. For all the
 * other user_regset flavors, the user_regset layout and the ELF core dump note
 * payload are exactly the same layout.
 *
 * This interface usage is as follows:
 *	struct iovec iov = { buf, len};
 *
 *	ret = ptrace(PTRACE_GETREGSET/PTRACE_SETREGSET, pid, NT_XXX_TYPE, &iov);
 *
 * On the successful completion, iov.len will be updated by the kernel,
 * specifying how much the kernel has written/read to/from the user's iov.buf.
 */
#define PTRACE_GETREGSET	0x4204
#define PTRACE_SETREGSET	0x4205

#define PTRACE_SEIZE		0x4206
#define PTRACE_INTERRUPT	0x4207
#define PTRACE_LISTEN		0x4208

#define PTRACE_PEEKSIGINFO	0x4209

struct ptrace_peeksiginfo_args {
	__u64 off;	/* from which siginfo to start */
	__u32 flags;
	__s32 nr;	/* how may siginfos to take */
};

#define PTRACE_GETSIGMASK	0x420a
#define PTRACE_SETSIGMASK	0x420b

#define PTRACE_SECCOMP_GET_FILTER	0x420c
#define PTRACE_SECCOMP_GET_METADATA	0x420d

struct seccomp_metadata {
	__u64 filter_off;	/* Input: which filter */
	__u64 flags;		/* Output: filter's flags */
};

#define PTRACE_GET_SYSCALL_INFO		0x420e
#define PTRACE_SYSCALL_INFO_NONE	0
#define PTRACE_SYSCALL_INFO_ENTRY	1
#define PTRACE_SYSCALL_INFO_EXIT	2
#define PTRACE_SYSCALL_INFO_SECCOMP	3

struct ptrace_syscall_info {
	__u8 op;	/* PTRACE_SYSCALL_INFO_* */
	__u8 pad[3];
	__u32 arch;
	__u64 instruction_pointer;
	__u64 stack_pointer;
	union {
		struct {
			__u64 nr;
			__u64 args[6];
		} entry;
		struct {
			__s64 rval;
			__u8 is_error;
		} exit;
		struct {
			__u64 nr;
			__u64 args[6];
			__u32 ret_data;
		} seccomp;
	};
};

#define PTRACE_GET_RSEQ_CONFIGURATION	0x420f

struct ptrace_rseq_configuration {
	__u64 rseq_abi_pointer;
	__u32 rseq_abi_size;
	__u32 signature;
	__u32 flags;
	__u32 pad;
};

/*
 * These values are stored in task->ptrace_message
 * by ptrace_stop to describe the current syscall-stop.
 */
#define PTRACE_EVENTMSG_SYSCALL_ENTRY	1
#define PTRACE_EVENTMSG_SYSCALL_EXIT	2

/* Read signals from a shared (process wide) queue */
#define PTRACE_PEEKSIGINFO_SHARED	(1 << 0)

/* Wait extended result codes for the above trace options.  */
#define PTRACE_EVENT_FORK	1
#define PTRACE_EVENT_VFORK	2
#define PTRACE_EVENT_CLONE	3
#define PTRACE_EVENT_EXEC	4
#define PTRACE_EVENT_VFORK_DONE	5
#define PTRACE_EVENT_EXIT	6
#define PTRACE_EVENT_SECCOMP	7
/* Extended result codes which enabled by means other than options.  */
#define PTRACE_EVENT_STOP	128

/* Options set using PTRACE_SETOPTIONS or using PTRACE_SEIZE @data param */
#define PTRACE_O_TRACESYSGOOD	1
#define PTRACE_O_TRACEFORK	(1 << PTRACE_EVENT_FORK)
#define PTRACE_O_TRACEVFORK	(1 << PTRACE_EVENT_VFORK)
#define PTRACE_O_TRACECLONE	(1 << PTRACE_EVENT_CLONE)
#define PTRACE_O_TRACEEXEC	(1 << PTRACE_EVENT_EXEC)
#define PTRACE_O_TRACEVFORKDONE	(1 << PTRACE_EVENT_VFORK_DONE)
#define PTRACE_O_TRACEEXIT	(1 << PTRACE_EVENT_EXIT)
#define PTRACE_O_TRACESECCOMP	(1 << PTRACE_EVENT_SECCOMP)

/* eventless options */
#define PTRACE_O_EXITKILL		(1 << 20)
#define PTRACE_O_SUSPEND_SECCOMP	(1 << 21)

#define PTRACE_O_MASK		(\
	0x000000ff | PTRACE_O_EXITKILL | PTRACE_O_SUSPEND_SECCOMP)

#include <asm/ptrace.h>


#endif /* _LINUX_PTRACE_H */