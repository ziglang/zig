#include "time32.h"
#include <mqueue.h>
#include <time.h>

ssize_t __mq_timedreceive_time32(mqd_t mqd, char *restrict msg, size_t len, unsigned *restrict prio, const struct timespec32 *restrict ts32)
{
	return mq_timedreceive(mqd, msg, len, prio, ts32 ? (&(struct timespec){
		.tv_sec = ts32->tv_sec, .tv_nsec = ts32->tv_nsec}) : 0);
}
