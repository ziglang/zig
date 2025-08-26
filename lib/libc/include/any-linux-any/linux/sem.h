/* SPDX-License-Identifier: GPL-2.0 WITH Linux-syscall-note */
#ifndef _LINUX_SEM_H
#define _LINUX_SEM_H

#include <linux/ipc.h>

/* semop flags */
#define SEM_UNDO        0x1000  /* undo the operation on exit */

/* semctl Command Definitions. */
#define GETPID  11       /* get sempid */
#define GETVAL  12       /* get semval */
#define GETALL  13       /* get all semval's */
#define GETNCNT 14       /* get semncnt */
#define GETZCNT 15       /* get semzcnt */
#define SETVAL  16       /* set semval */
#define SETALL  17       /* set all semval's */

/* ipcs ctl cmds */
#define SEM_STAT 18
#define SEM_INFO 19
#define SEM_STAT_ANY 20

/* Obsolete, used only for backwards compatibility and libc5 compiles */
struct semid_ds {
	struct ipc_perm	sem_perm;		/* permissions .. see ipc.h */
	__kernel_old_time_t sem_otime;		/* last semop time */
	__kernel_old_time_t sem_ctime;		/* create/last semctl() time */
	struct sem	*sem_base;		/* ptr to first semaphore in array */
	struct sem_queue *sem_pending;		/* pending operations to be processed */
	struct sem_queue **sem_pending_last;	/* last pending operation */
	struct sem_undo	*undo;			/* undo requests on this array */
	unsigned short	sem_nsems;		/* no. of semaphores in array */
};

/* Include the definition of semid64_ds */
#include <asm/sembuf.h>

/* semop system calls takes an array of these. */
struct sembuf {
	unsigned short  sem_num;	/* semaphore index in array */
	short		sem_op;		/* semaphore operation */
	short		sem_flg;	/* operation flags */
};

/* arg for semctl system calls. */
union semun {
	int val;			/* value for SETVAL */
	struct semid_ds *buf;	/* buffer for IPC_STAT & IPC_SET */
	unsigned short *array;	/* array for GETALL & SETALL */
	struct seminfo *__buf;	/* buffer for IPC_INFO */
	void *__pad;
};

struct  seminfo {
	int semmap;
	int semmni;
	int semmns;
	int semmnu;
	int semmsl;
	int semopm;
	int semume;
	int semusz;
	int semvmx;
	int semaem;
};

/*
 * SEMMNI, SEMMSL and SEMMNS are default values which can be
 * modified by sysctl.
 * The values has been chosen to be larger than necessary for any
 * known configuration.
 *
 * SEMOPM should not be increased beyond 1000, otherwise there is the
 * risk that semop()/semtimedop() fails due to kernel memory fragmentation when
 * allocating the sop array.
 */


#define SEMMNI  32000           /* <= IPCMNI  max # of semaphore identifiers */
#define SEMMSL  32000           /* <= INT_MAX max num of semaphores per id */
#define SEMMNS  (SEMMNI*SEMMSL) /* <= INT_MAX max # of semaphores in system */
#define SEMOPM  500	        /* <= 1 000 max num of ops per semop call */
#define SEMVMX  32767           /* <= 32767 semaphore maximum value */
#define SEMAEM  SEMVMX          /* adjust on exit max value */

/* unused */
#define SEMUME  SEMOPM          /* max num of undo entries per process */
#define SEMMNU  SEMMNS          /* num of undo structures system wide */
#define SEMMAP  SEMMNS          /* # of entries in semaphore map */
#define SEMUSZ  20		/* sizeof struct sem_undo */


#endif /* _LINUX_SEM_H */