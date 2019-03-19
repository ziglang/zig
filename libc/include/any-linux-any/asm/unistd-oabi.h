#ifndef _ASM_ARM_UNISTD_OABI_H
#define _ASM_ARM_UNISTD_OABI_H 1

#define __NR_time (__NR_SYSCALL_BASE + 13)
#define __NR_umount (__NR_SYSCALL_BASE + 22)
#define __NR_stime (__NR_SYSCALL_BASE + 25)
#define __NR_alarm (__NR_SYSCALL_BASE + 27)
#define __NR_utime (__NR_SYSCALL_BASE + 30)
#define __NR_getrlimit (__NR_SYSCALL_BASE + 76)
#define __NR_select (__NR_SYSCALL_BASE + 82)
#define __NR_readdir (__NR_SYSCALL_BASE + 89)
#define __NR_mmap (__NR_SYSCALL_BASE + 90)
#define __NR_socketcall (__NR_SYSCALL_BASE + 102)
#define __NR_syscall (__NR_SYSCALL_BASE + 113)
#define __NR_ipc (__NR_SYSCALL_BASE + 117)

#endif /* _ASM_ARM_UNISTD_OABI_H */