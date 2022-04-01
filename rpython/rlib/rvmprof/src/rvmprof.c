#define _GNU_SOURCE 1

#ifdef RPYTHON_LL2CTYPES
   /* only for testing: ll2ctypes sets RPY_EXTERN from the command-line */

#else
#  include "common_header.h"
#  include "structdef.h"
#  include "src/threadlocal.h"
#  include "rvmprof.h"
#  include "forwarddecl.h"
#endif


#include "vmprof_common.h"

#include "shared/vmprof_get_custom_offset.h"
#ifdef VMPROF_UNIX
#include "shared/vmprof_unix.h"
#else
#include "shared/vmprof_win.h"
#endif


#ifdef RPYTHON_LL2CTYPES
int IS_VMPROF_EVAL(void * ptr) { return 0; }
#else
int IS_VMPROF_EVAL(void * ptr)
{
    return ptr == __vmprof_eval_vmprof;
}
#endif

long vmprof_get_profile_path(char * buffer, long size)
{
    return vmp_fd_to_path(vmp_profile_fileno(), buffer, size);
}

int vmprof_stop_sampling(void)
{
    vmprof_ignore_signals(1);
    return vmp_profile_fileno();
}

void vmprof_start_sampling(void)
{
    vmprof_ignore_signals(0);
}
