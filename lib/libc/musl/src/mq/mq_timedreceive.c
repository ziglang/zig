#include <mqueue.h>
#include <errno.h>
#include "syscall.h"

#define IS32BIT(x) !((x)+0x80000000ULL>>32)
#define CLAMP(x) (int)(IS32BIT(x) ? (x) : 0x7fffffffU+((0ULL+(x))>>63))

ssize_t mq_timedreceive(mqd_t mqd, char *restrict msg, size_t len, unsigned *restrict prio, const struct timespec *restrict at)
{
#ifdef SYS_mq_timedreceive_time64
	time_t s = at ? at->tv_sec : 0;
	long ns = at ? at->tv_nsec : 0;
	long r = -ENOSYS;
	if (SYS_mq_timedreceive == SYS_mq_timedreceive_time64 || !IS32BIT(s))
		r = __syscall_cp(SYS_mq_timedreceive_time64, mqd, msg, len, prio,
			at ? ((long long []){at->tv_sec, at->tv_nsec}) : 0);
	if (SYS_mq_timedreceive == SYS_mq_timedreceive_time64 || r != -ENOSYS)
		return __syscall_ret(r);
	return syscall_cp(SYS_mq_timedreceive, mqd, msg, len, prio,
		at ? ((long[]){CLAMP(s), ns}) : 0);
#else
	return syscall_cp(SYS_mq_timedreceive, mqd, msg, len, prio, at);
#endif
}
