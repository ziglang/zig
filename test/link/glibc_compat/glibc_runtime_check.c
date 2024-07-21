/*
 * Exercise complicating glibc symbols from C code.  Complicating symbols
 * are ones that have moved between glibc versions, or use floating point
 * parameters, or have otherwise tripped up the Zig glibc compatibility
 * code.
 */
#include <assert.h>
#include <errno.h>
#include <features.h>
#include <fcntl.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/auxv.h>
#include <sys/stat.h>
#include <unistd.h>

/* errno is compilcated (thread-local, dynamically provided, etc). */
static void check_errno()
{
	int invalid_fd = open("/doesnotexist", O_RDONLY);
	assert(invalid_fd == -1);
	assert(errno == ENOENT);
}

/* fstat has moved around in glibc (between libc_nonshared and libc) */
static void check_fstat()
{
	int self_fd = open("/proc/self/exe", O_RDONLY);

	struct stat statbuf = {0};
	int rc = fstat(self_fd, &statbuf);

	assert(rc == 0);

	assert(statbuf.st_dev != 0);
	assert(statbuf.st_ino != 0);
	assert(statbuf.st_mode != 0);
	assert(statbuf.st_size > 0);
	assert(statbuf.st_blocks > 0);
	assert(statbuf.st_ctim.tv_sec > 0);

	close(self_fd);
}

/* Some targets have a complicated ABI for floats and doubles */
static void check_fp_abi()
{
	// Picked "pow" as it takes and returns doubles
	assert(pow(10.0, 10.0) == 10000000000.0);
	assert(powf(10.0f, 10.0f) == 10000000000.0f);
}

/* strlcpy introduced in glibc 2.38 */
static void check_strlcpy()
{
#if (__GLIBC__ == 2 && __GLIBC_MINOR__ >= 38) || (__GLIBC__ > 2)
	char target[4] = {0};
	strlcpy(target, "this is a source string", 4);

	assert(strcmp(target, "thi") == 0);
#endif
}

/* reallocarray introduced in glibc 2.26 */
static void check_reallocarray()
{
#if (__GLIBC__ == 2 && __GLIBC_MINOR__ >= 26) || (__GLIBC__ > 2)
	const size_t el_size = 32;
	void* base = reallocarray(NULL, 10, el_size);
	void* grown = reallocarray(base, 100, el_size);

	assert(base != NULL);
	assert(grown != NULL);

	free(grown);
#endif
}

/* getauxval introduced in glibc 2.16 */
static void check_getauxval()
{
#if (__GLIBC__ == 2 && __GLIBC_MINOR__ >= 16) || (__GLIBC__ > 2)
	int pgsz = getauxval(AT_PAGESZ);
	assert(pgsz >= 4*1024);
#endif
}

/* atexit() is part of libc_nonshared */
static void force_exit_0()
{
	exit(0);
}

static void check_atexit()
{
	int rc = atexit(force_exit_0);
	assert(rc == 0);
}

int main() {
	int rc;

	check_errno();
	check_fstat();
	check_fp_abi();
	check_strlcpy();
	check_reallocarray();
	check_getauxval();
	check_atexit();

	exit(99); // exit code overridden by atexit handler
}
