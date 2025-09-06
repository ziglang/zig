#ifndef _MQUEUE_H
#define _MQUEUE_H
#ifdef __cplusplus
extern "C" {
#endif

#include <features.h>

#define __NEED_size_t
#define __NEED_ssize_t
#define __NEED_pthread_attr_t
#define __NEED_time_t
#define __NEED_struct_timespec
#include <bits/alltypes.h>

typedef int mqd_t;
struct mq_attr {
	long mq_flags, mq_maxmsg, mq_msgsize, mq_curmsgs, __unused1[4];
};
struct sigevent;

#ifdef __cplusplus
}
#endif
#endif
