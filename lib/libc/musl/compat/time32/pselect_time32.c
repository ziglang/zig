#include "time32.h"
#include <time.h>
#include <sys/select.h>

int __pselect_time32(int n, fd_set *restrict rfds, fd_set *restrict wfds, fd_set *restrict efds, const struct timespec32 *restrict ts32, const sigset_t *restrict mask)
{
	return pselect(n, rfds, wfds, efds, !ts32 ? 0 : (&(struct timespec){
		.tv_sec = ts32->tv_sec, .tv_nsec = ts32->tv_nsec}), mask);
}
