pub fn addCases(cases: *tests.LibcContext) void {
    cases.addLibcTestCase("api/main.c", true, .{});

    cases.addLibcTestCase("functional/argv.c", true, .{});
    cases.addLibcTestCase("functional/basename.c", true, .{});
    cases.addLibcTestCase("functional/clocale_mbfuncs.c", true, .{});
    cases.addLibcTestCase("functional/clock_gettime.c", true, .{});
    cases.addLibcTestCase("functional/crypt.c", true, .{});
    cases.addLibcTestCase("functional/dirname.c", true, .{});
    cases.addLibcTestCase("functional/env.c", true, .{});
    cases.addLibcTestCase("functional/fcntl.c", false, .{});
    cases.addLibcTestCase("functional/fdopen.c", false, .{});
    cases.addLibcTestCase("functional/fnmatch.c", true, .{});
    cases.addLibcTestCase("functional/fscanf.c", false, .{});
    cases.addLibcTestCase("functional/fwscanf.c", false, .{});
    cases.addLibcTestCase("functional/iconv_open.c", true, .{});
    cases.addLibcTestCase("functional/inet_pton.c", false, .{});
    // "functional/ipc_msg.c": Probably a bug in qemu
    // "functional/ipc_sem.c": Probably a bug in qemu
    // "functional/ipc_shm.c": Probably a bug in qemu
    cases.addLibcTestCase("functional/mbc.c", true, .{});
    cases.addLibcTestCase("functional/memstream.c", true, .{});
    // "functional/mntent.c": https://www.openwall.com/lists/musl/2024/10/22/1
    cases.addLibcTestCase("functional/popen.c", false, .{});
    cases.addLibcTestCase("functional/pthread_cancel-points.c", false, .{});
    cases.addLibcTestCase("functional/pthread_cancel.c", false, .{});
    cases.addLibcTestCase("functional/pthread_cond.c", false, .{});
    cases.addLibcTestCase("functional/pthread_mutex.c", false, .{});
    // "functional/pthread_mutex_pi.c": Probably a bug in qemu (big/little endian FUTEX_LOCK_PI)
    // "functional/pthread_robust.c": https://gitlab.com/qemu-project/qemu/-/issues/2424
    cases.addLibcTestCase("functional/pthread_tsd.c", false, .{});
    cases.addLibcTestCase("functional/qsort.c", true, .{});
    cases.addLibcTestCase("functional/random.c", true, .{});
    cases.addLibcTestCase("functional/search_hsearch.c", false, .{}); // The test suite of wasi-libc runs this test case
    cases.addLibcTestCase("functional/search_insque.c", true, .{});
    cases.addLibcTestCase("functional/search_lsearch.c", true, .{});
    cases.addLibcTestCase("functional/search_tsearch.c", true, .{});
    cases.addLibcTestCase("functional/sem_init.c", false, .{});
    cases.addLibcTestCase("functional/sem_open.c", false, .{});
    cases.addLibcTestCase("functional/setjmp.c", false, .{});
    cases.addLibcTestCase("functional/snprintf.c", true, .{});
    cases.addLibcTestCase("functional/socket.c", false, .{});
    cases.addLibcTestCase("functional/spawn.c", false, .{});
    cases.addLibcTestCase("functional/sscanf.c", true, .{});
    cases.addLibcTestCase("functional/sscanf_long.c", false, .{});
    cases.addLibcTestCase("functional/stat.c", false, .{});
    cases.addLibcTestCase("functional/strftime.c", true, .{});
    cases.addLibcTestCase("functional/string.c", true, .{});
    cases.addLibcTestCase("functional/string_memcpy.c", true, .{});
    cases.addLibcTestCase("functional/string_memmem.c", true, .{});
    cases.addLibcTestCase("functional/string_memset.c", true, .{});
    cases.addLibcTestCase("functional/string_strchr.c", true, .{});
    cases.addLibcTestCase("functional/string_strcspn.c", true, .{});
    cases.addLibcTestCase("functional/string_strstr.c", true, .{});
    cases.addLibcTestCase("functional/strtod.c", true, .{});
    cases.addLibcTestCase("functional/strtod_long.c", true, .{});
    cases.addLibcTestCase("functional/strtod_simple.c", true, .{});
    cases.addLibcTestCase("functional/strtof.c", true, .{});
    cases.addLibcTestCase("functional/strtol.c", true, .{});
    cases.addLibcTestCase("functional/strtold.c", true, .{});
    cases.addLibcTestCase("functional/swprintf.c", true, .{});
    cases.addLibcTestCase("functional/tgmath.c", true, .{});
    cases.addLibcTestCase("functional/time.c", false, .{});
    cases.addLibcTestCase("functional/tls_align.c", true, .{ .additional_src_file = "functional/tls_align_dso.c" });
    cases.addLibcTestCase("functional/tls_init.c", false, .{});
    cases.addLibcTestCase("functional/tls_local_exec.c", false, .{});
    cases.addLibcTestCase("functional/udiv.c", true, .{});
    cases.addLibcTestCase("functional/ungetc.c", false, .{});
    // cases.addLibcTestCase("functional/utime.c", false, .{}); - fails under heavy load; futimens not reflected in subsequent fstat
    cases.addLibcTestCase("functional/vfork.c", false, .{});
    cases.addLibcTestCase("functional/wcsstr.c", true, .{});
    cases.addLibcTestCase("functional/wcstol.c", true, .{});

    // cases.addLibcTestCase("regression/daemon-failure.c", false, .{}); - unexpected ENOMEM with high FD limit
    cases.addLibcTestCase("regression/dn_expand-empty.c", false, .{});
    cases.addLibcTestCase("regression/dn_expand-ptr-0.c", false, .{});
    cases.addLibcTestCase("regression/execle-env.c", false, .{});
    cases.addLibcTestCase("regression/fflush-exit.c", false, .{});
    cases.addLibcTestCase("regression/fgets-eof.c", true, .{});
    cases.addLibcTestCase("regression/fgetwc-buffering.c", false, .{});
    cases.addLibcTestCase("regression/flockfile-list.c", false, .{});
    cases.addLibcTestCase("regression/fpclassify-invalid-ld80.c", true, .{});
    cases.addLibcTestCase("regression/ftello-unflushed-append.c", false, .{});
    cases.addLibcTestCase("regression/getpwnam_r-crash.c", false, .{});
    cases.addLibcTestCase("regression/getpwnam_r-errno.c", false, .{});
    cases.addLibcTestCase("regression/iconv-roundtrips.c", true, .{});
    cases.addLibcTestCase("regression/inet_ntop-v4mapped.c", true, .{});
    cases.addLibcTestCase("regression/inet_pton-empty-last-field.c", true, .{});
    cases.addLibcTestCase("regression/iswspace-null.c", true, .{});
    cases.addLibcTestCase("regression/lrand48-signextend.c", true, .{});
    cases.addLibcTestCase("regression/lseek-large.c", false, .{});
    cases.addLibcTestCase("regression/malloc-0.c", true, .{});
    // "regression/malloc-brk-fail.c": QEMU OOM
    // cases.addLibcTestCase("regression/malloc-oom.c", false, .{}); // wasi-libc: requires t_memfill; QEMU OOM
    cases.addLibcTestCase("regression/mbsrtowcs-overflow.c", true, .{});
    cases.addLibcTestCase("regression/memmem-oob-read.c", true, .{});
    cases.addLibcTestCase("regression/memmem-oob.c", true, .{});
    cases.addLibcTestCase("regression/mkdtemp-failure.c", false, .{});
    cases.addLibcTestCase("regression/mkstemp-failure.c", false, .{});
    cases.addLibcTestCase("regression/printf-1e9-oob.c", true, .{});
    cases.addLibcTestCase("regression/printf-fmt-g-round.c", true, .{});
    cases.addLibcTestCase("regression/printf-fmt-g-zeros.c", true, .{});
    cases.addLibcTestCase("regression/printf-fmt-n.c", true, .{});
    // "regression/pthread-robust-detach.c": https://gitlab.com/qemu-project/qemu/-/issues/2424
    cases.addLibcTestCase("regression/pthread_atfork-errno-clobber.c", false, .{});
    cases.addLibcTestCase("regression/pthread_cancel-sem_wait.c", false, .{});
    cases.addLibcTestCase("regression/pthread_cond-smasher.c", false, .{});
    cases.addLibcTestCase("regression/pthread_cond_wait-cancel_ignored.c", false, .{});
    cases.addLibcTestCase("regression/pthread_condattr_setclock.c", false, .{});
    // "regression/pthread_create-oom.c": QEMU OOM
    cases.addLibcTestCase("regression/pthread_exit-cancel.c", false, .{});
    cases.addLibcTestCase("regression/pthread_exit-dtor.c", false, .{});
    cases.addLibcTestCase("regression/pthread_once-deadlock.c", false, .{});
    cases.addLibcTestCase("regression/pthread_rwlock-ebusy.c", false, .{});
    cases.addLibcTestCase("regression/putenv-doublefree.c", true, .{});
    cases.addLibcTestCase("regression/raise-race.c", false, .{});
    cases.addLibcTestCase("regression/regex-backref-0.c", true, .{});
    cases.addLibcTestCase("regression/regex-bracket-icase.c", true, .{});
    cases.addLibcTestCase("regression/regex-ere-backref.c", true, .{});
    cases.addLibcTestCase("regression/regex-escaped-high-byte.c", true, .{});
    cases.addLibcTestCase("regression/regex-negated-range.c", true, .{});
    cases.addLibcTestCase("regression/regexec-nosub.c", true, .{});
    cases.addLibcTestCase("regression/rewind-clear-error.c", false, .{});
    cases.addLibcTestCase("regression/rlimit-open-files.c", false, .{});
    cases.addLibcTestCase("regression/scanf-bytes-consumed.c", true, .{});
    cases.addLibcTestCase("regression/scanf-match-literal-eof.c", true, .{});
    cases.addLibcTestCase("regression/scanf-nullbyte-char.c", true, .{});
    cases.addLibcTestCase("regression/sem_close-unmap.c", false, .{});
    // "regression/setenv-oom.c": QEMU OOM
    cases.addLibcTestCase("regression/setvbuf-unget.c", true, .{});
    cases.addLibcTestCase("regression/sigaltstack.c", false, .{});
    cases.addLibcTestCase("regression/sigprocmask-internal.c", false, .{});
    cases.addLibcTestCase("regression/sigreturn.c", true, .{});
    cases.addLibcTestCase("regression/sscanf-eof.c", true, .{});
    cases.addLibcTestCase("regression/strverscmp.c", true, .{});
    cases.addLibcTestCase("regression/syscall-sign-extend.c", false, .{});
    cases.addLibcTestCase("regression/uselocale-0.c", true, .{});
    cases.addLibcTestCase("regression/wcsncpy-read-overflow.c", true, .{});
    cases.addLibcTestCase("regression/wcsstr-false-negative.c", true, .{});
}

const std = @import("std");
const tests = @import("tests.zig");
