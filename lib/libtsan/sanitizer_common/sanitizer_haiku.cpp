//===-- sanitizer_haiku.cpp -----------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file is shared between Sanitizer run-time libraries and implements
// Haiku-specific functions from sanitizer_libc.h.
//===----------------------------------------------------------------------===//

#include "sanitizer_platform.h"

#if SANITIZER_HAIKU

#  include "sanitizer_common.h"
#  include "sanitizer_flags.h"
#  include "sanitizer_getauxval.h"
#  include "sanitizer_internal_defs.h"
#  include "sanitizer_libc.h"
#  include "sanitizer_linux.h"
#  include "sanitizer_mutex.h"
#  include "sanitizer_placement_new.h"
#  include "sanitizer_procmaps.h"

#  include <sys/param.h>
#  include <sys/types.h>

#  include <sys/mman.h>
#  include <sys/resource.h>
#  include <sys/stat.h>
#  include <sys/time.h>

#  include <dlfcn.h>
#  include <errno.h>
#  include <fcntl.h>
#  include <limits.h>
#  include <link.h>
#  include <pthread.h>
#  include <sched.h>
#  include <signal.h>
#  include <unistd.h>

#  include "system/vm_defs.h"
#  include "system/syscalls.h"
#  include "shared/syscall_utils.h"

namespace __sanitizer {

static void *GetRealLibcAddress(const char *symbol) {
  void *real = dlsym(RTLD_NEXT, symbol);
  if (!real)
    real = dlsym(RTLD_DEFAULT, symbol);
  if (!real) {
    Printf("GetRealLibcAddress failed for symbol=%s", symbol);
    Die();
  }
  return real;
}

#  define _REAL(func, ...) real##_##func(__VA_ARGS__)
#  define DEFINE__REAL(ret_type, func, ...)                              \
    static ret_type (*real_##func)(__VA_ARGS__) = NULL;                  \
    if (!real_##func) {                                                  \
      real_##func = (ret_type(*)(__VA_ARGS__))GetRealLibcAddress(#func); \
    }                                                                    \
    CHECK(real_##func);

// --------------- sanitizer_libc.h
uptr internal_mmap(void *addr, uptr length, int prot, int flags, int fd,
                   u64 offset) {
  if ((flags & MAP_ANONYMOUS) != 0)
    fd = -1;

  int mapping =
      (flags & MAP_SHARED) != 0 ? REGION_NO_PRIVATE_MAP : REGION_PRIVATE_MAP;

  uint32 addressSpec;
  if ((flags & MAP_FIXED) != 0)
    addressSpec = B_EXACT_ADDRESS;
  else if (addr != NULL)
    addressSpec = B_BASE_ADDRESS;
  else
    addressSpec = B_RANDOMIZED_ANY_ADDRESS;

  uint32 areaProtection = 0;
  if ((prot & PROT_READ) != 0)
    areaProtection |= B_READ_AREA;
  if ((prot & PROT_WRITE) != 0)
    areaProtection |= B_WRITE_AREA;
  if ((prot & PROT_EXEC) != 0)
    areaProtection |= B_EXECUTE_AREA;

  if ((flags & MAP_NORESERVE) != 0)
    areaProtection |= B_OVERCOMMITTING_AREA;

  area_id area = _kern_map_file("sanitizer mmap", &addr, addressSpec, length,
                                areaProtection, mapping, true, fd, offset);
  if (area < 0)
    RETURN_AND_SET_ERRNO(area);
  return (uptr)addr;
}

uptr internal_munmap(void *addr, uptr length) {
  DEFINE__REAL(int, munmap, void *a, uptr b);
  return _REAL(munmap, addr, length);
}

uptr internal_mremap(void *old_address, uptr old_size, uptr new_size, int flags,
                     void *new_address) {
  CHECK(false && "internal_mremap is unimplemented on Haiku");
  return 0;
}

int internal_mprotect(void *addr, uptr length, int prot) {
  DEFINE__REAL(int, mprotect, void *a, uptr b, int c);
  return _REAL(mprotect, addr, length, prot);
}

int internal_madvise(uptr addr, uptr length, int advice) {
  DEFINE__REAL(int, madvise, void *a, uptr b, int c);
  return _REAL(madvise, (void *)addr, length, advice);
}

uptr internal_close(fd_t fd) {
  CHECK(&_kern_close);
  RETURN_AND_SET_ERRNO(_kern_close(fd));
}

uptr internal_open(const char *filename, int flags) {
  CHECK(&_kern_open);
  RETURN_AND_SET_ERRNO(_kern_open(-1, filename, flags, 0));
}

uptr internal_open(const char *filename, int flags, u32 mode) {
  CHECK(&_kern_open);
  RETURN_AND_SET_ERRNO(_kern_open(-1, filename, flags, mode));
}

uptr internal_read(fd_t fd, void *buf, uptr count) {
  sptr res;
  CHECK(&_kern_read);
  HANDLE_EINTR(res, (sptr)_kern_read(fd, -1, buf, (size_t)count));
  RETURN_AND_SET_ERRNO(res);
  return res;
}

uptr internal_write(fd_t fd, const void *buf, uptr count) {
  sptr res;
  CHECK(&_kern_write);
  HANDLE_EINTR(res, (sptr)_kern_write(fd, -1, buf, count));
  RETURN_AND_SET_ERRNO(res);
  return res;
}

uptr internal_ftruncate(fd_t fd, uptr size) {
  sptr res;
  DEFINE__REAL(int, ftruncate, int, off_t);
  return _REAL(ftruncate, fd, size);
  return res;
}

uptr internal_stat(const char *path, void *buf) {
  DEFINE__REAL(int, _stat_current, const char *a, void *b);
  return _REAL(_stat_current, path, buf);
}

uptr internal_lstat(const char *path, void *buf) {
  DEFINE__REAL(int, _lstat_current, const char *a, void *b);
  return _REAL(_lstat_current, path, buf);
}

uptr internal_fstat(fd_t fd, void *buf) {
  DEFINE__REAL(int, _fstat_current, int a, void *b);
  return _REAL(_fstat_current, fd, buf);
}

uptr internal_filesize(fd_t fd) {
  struct stat st;
  if (internal_fstat(fd, &st))
    return -1;
  return (uptr)st.st_size;
}

uptr internal_dup(int oldfd) {
  DEFINE__REAL(int, dup, int a);
  return _REAL(dup, oldfd);
}

uptr internal_dup2(int oldfd, int newfd) {
  DEFINE__REAL(int, dup2, int a, int b);
  return _REAL(dup2, oldfd, newfd);
}

uptr internal_readlink(const char *path, char *buf, uptr bufsize) {
  CHECK(&_kern_read_link);
  RETURN_AND_SET_ERRNO(_kern_read_link(-1, path, buf, &bufsize));
}

uptr internal_unlink(const char *path) {
  DEFINE__REAL(int, unlink, const char *a);
  return _REAL(unlink, path);
}

uptr internal_rename(const char *oldpath, const char *newpath) {
  DEFINE__REAL(int, rename, const char *a, const char *b);
  return _REAL(rename, oldpath, newpath);
}

uptr internal_sched_yield() {
  CHECK(&_kern_thread_yield);
  _kern_thread_yield();
  return 0;
}

void internal__exit(int exitcode) {
  DEFINE__REAL(void, _exit, int a);
  _REAL(_exit, exitcode);
  Die();  // Unreachable.
}

void internal_usleep(u64 useconds) {
  _kern_snooze_etc(useconds, B_SYSTEM_TIMEBASE, B_RELATIVE_TIMEOUT, NULL);
}

uptr internal_execve(const char *filename, char *const argv[],
                     char *const envp[]) {
  DEFINE__REAL(int, execve, const char *, char *const[], char *const[]);
  return _REAL(execve, filename, argv, envp);
}

#  if 0
tid_t GetTid() {
  DEFINE__REAL(int, _lwp_self);
  return _REAL(_lwp_self);
}

int TgKill(pid_t pid, tid_t tid, int sig) {
  DEFINE__REAL(int, _lwp_kill, int a, int b);
  (void)pid;
  return _REAL(_lwp_kill, tid, sig);
}

u64 NanoTime() {
  timeval tv;
  DEFINE__REAL(int, __gettimeofday50, void *a, void *b);
  internal_memset(&tv, 0, sizeof(tv));
  _REAL(__gettimeofday50, &tv, 0);
  return (u64)tv.tv_sec * 1000 * 1000 * 1000 + tv.tv_usec * 1000;
}
#  endif

uptr internal_clock_gettime(__sanitizer_clockid_t clk_id, void *tp) {
  DEFINE__REAL(int, __clock_gettime50, __sanitizer_clockid_t a, void *b);
  return _REAL(__clock_gettime50, clk_id, tp);
}

uptr internal_ptrace(int request, int pid, void *addr, int data) {
  DEFINE__REAL(int, ptrace, int a, int b, void *c, int d);
  return _REAL(ptrace, request, pid, addr, data);
}

uptr internal_waitpid(int pid, int *status, int options) {
  DEFINE__REAL(int, waitpid, pid_t, int *, int);
  return _REAL(waitpid, pid, status, options);
}

uptr internal_getpid() {
  DEFINE__REAL(int, getpid);
  return _REAL(getpid);
}

uptr internal_getppid() {
  DEFINE__REAL(int, getppid);
  return _REAL(getppid);
}

int internal_dlinfo(void *handle, int request, void *p) {
  DEFINE__REAL(int, dlinfo, void *a, int b, void *c);
  return _REAL(dlinfo, handle, request, p);
}

uptr internal_getdents(fd_t fd, void *dirp, unsigned int count) {
  DEFINE__REAL(int, __getdents30, int a, void *b, size_t c);
  return _REAL(__getdents30, fd, dirp, count);
}

uptr internal_lseek(fd_t fd, OFF_T offset, int whence) {
  CHECK(&_kern_seek);
  off_t result = _kern_seek(fd, offset, whence);
  if (result < 0) {
    errno = result;
    return -1;
  }
  return result;
}

uptr internal_prctl(int option, uptr arg2, uptr arg3, uptr arg4, uptr arg5) {
  Printf("internal_prctl not implemented for Haiku");
  Die();
  return 0;
}

uptr internal_sigaltstack(const void *ss, void *oss) {
  DEFINE__REAL(int, __sigaltstack14, const void *a, void *b);
  return _REAL(__sigaltstack14, ss, oss);
}

int internal_fork() {
  DEFINE__REAL(int, fork);
  return _REAL(fork);
}

#  if 0
int internal_sysctl(const int *name, unsigned int namelen, void *oldp,
                    uptr *oldlenp, const void *newp, uptr newlen) {
  CHECK(&__sysctl);
  return __sysctl(name, namelen, oldp, (size_t *)oldlenp, newp, (size_t)newlen);
}
#  endif

int internal_sysctlbyname(const char *sname, void *oldp, uptr *oldlenp,
                          const void *newp, uptr newlen) {
  DEFINE__REAL(int, sysctlbyname, const char *a, void *b, size_t *c,
               const void *d, size_t e);
  return _REAL(sysctlbyname, sname, oldp, (size_t *)oldlenp, newp,
               (size_t)newlen);
}

uptr internal_sigprocmask(int how, __sanitizer_sigset_t *set,
                          __sanitizer_sigset_t *oldset) {
  CHECK(&_kern_set_signal_mask);
  return _kern_set_signal_mask(how, set, oldset);
}

void internal_sigfillset(__sanitizer_sigset_t *set) {
  DEFINE__REAL(int, __sigfillset14, const void *a);
  (void)_REAL(__sigfillset14, set);
}

void internal_sigemptyset(__sanitizer_sigset_t *set) {
  DEFINE__REAL(int, __sigemptyset14, const void *a);
  (void)_REAL(__sigemptyset14, set);
}

void internal_sigdelset(__sanitizer_sigset_t *set, int signo) {
  DEFINE__REAL(int, __sigdelset14, const void *a, int b);
  (void)_REAL(__sigdelset14, set, signo);
}

uptr internal_clone(int (*fn)(void *), void *child_stack, int flags,
                    void *arg) {
  DEFINE__REAL(int, clone, int (*a)(void *b), void *c, int d, void *e);

  return _REAL(clone, fn, child_stack, flags, arg);
}

}  // namespace __sanitizer

#endif
