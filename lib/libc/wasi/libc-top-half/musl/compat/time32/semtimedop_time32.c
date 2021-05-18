#include "time32.h"
#define _GNU_SOURCE
#include <sys/sem.h>
#include <time.h>

int __semtimedop_time32(int id, struct sembuf *buf, size_t n, const struct timespec32 *ts32)
{
	return semtimedop(id, buf, n, !ts32 ? 0 : (&(struct timespec){
		.tv_sec = ts32->tv_sec, .tv_nsec = ts32->tv_nsec}));
}
