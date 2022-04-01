#include "vmprof_memory.h"

#ifdef VMPROF_APPLE
/* On OS X we can get RSS using the Mach API. */
#include <mach/mach.h>
#include <mach/message.h>
#include <mach/kern_return.h>
#include <mach/task_info.h>

static mach_port_t mach_task;
#elif defined(VMPROF_UNIX)
#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
/* On '''normal''' Unices we can get RSS from '/proc/<pid>/status'. */
static int proc_file = -1;
#endif

int setup_rss(void)
{
#ifdef VMPROF_LINUX
    char buf[128];

    sprintf(buf, "/proc/%d/status", getpid());
    proc_file = open(buf, O_RDONLY);
    return proc_file;
#elif defined(VMPROF_APPLE)
    mach_task = mach_task_self();
    return 0;
#else
    return 0;
#endif
}

int teardown_rss(void)
{
#ifdef VMPROF_LINUX
    close(proc_file);
    proc_file = -1;
    return 0;
#else
    return 0;
#endif
}

long get_current_proc_rss(void)
{
#ifdef VMPROF_LINUX
    char buf[1024];
    int i = 0;

    if (lseek(proc_file, 0, SEEK_SET) == -1)
        return -1;
    if (read(proc_file, buf, 1024) == -1)
        return -1;
    while (i < 1020) {
        if (strncmp(buf + i, "VmRSS:\t", 7) == 0) {
            i += 7;
            return atoi(buf + i);
        }
        i++;
    }
    return -1;
#elif defined(VMPROF_APPLE)
    mach_msg_type_number_t out_count = MACH_TASK_BASIC_INFO_COUNT;
    mach_task_basic_info_data_t taskinfo = { .resident_size = 0 };

    kern_return_t error = task_info(mach_task, MACH_TASK_BASIC_INFO, (task_info_t)&taskinfo, &out_count);
    if (error == KERN_SUCCESS) {
        return (long)(taskinfo.resident_size / 1024);
    } else {
        return -1;
    }
#else
    return -1; // not implemented
#endif
}
