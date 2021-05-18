#include "time32.h"
#include <mqueue.h>
#include <time.h>

int __mq_timedsend_time32(mqd_t mqd, const char *msg, size_t len, unsigned prio, const struct timespec32 *ts32)
{
	return mq_timedsend(mqd, msg, len, prio, ts32 ? (&(struct timespec){
		.tv_sec = ts32->tv_sec, .tv_nsec = ts32->tv_nsec}) : 0);
}
