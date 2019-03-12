#include <mqueue.h>

int mq_send(mqd_t mqd, const char *msg, size_t len, unsigned prio)
{
	return mq_timedsend(mqd, msg, len, prio, 0);
}
