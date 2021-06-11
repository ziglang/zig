#include <mqueue.h>

ssize_t mq_receive(mqd_t mqd, char *msg, size_t len, unsigned *prio)
{
	return mq_timedreceive(mqd, msg, len, prio, 0);
}
