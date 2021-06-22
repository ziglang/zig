#include <sys/sysinfo.h>
#include "syscall.h"

#define klong long long
#define kulong unsigned long long

struct kernel_sysinfo {
	klong uptime;
	kulong loads[3];
	kulong totalram;
	kulong freeram;
	kulong sharedram;
	kulong bufferram;
	kulong totalswap;
	kulong freeswap;
	short procs;
	short pad;
	kulong totalhigh;
	kulong freehigh;
	unsigned mem_unit;
};

int __lsysinfo(struct sysinfo *info)
{
	struct kernel_sysinfo tmp;
	int ret = syscall(SYS_sysinfo, &tmp);
	if(ret == -1) return ret;
	info->uptime = tmp.uptime;
	info->loads[0] = tmp.loads[0];
	info->loads[1] = tmp.loads[1];
	info->loads[2] = tmp.loads[2];
	kulong shifts;
	kulong max = tmp.totalram | tmp.totalswap;
	__asm__("bsr %1,%0" : "=r"(shifts) : "r"(max));
	shifts = shifts >= 32 ? shifts - 31 : 0;
	info->totalram = tmp.totalram >> shifts;
	info->freeram = tmp.freeram >> shifts;
	info->sharedram = tmp.sharedram >> shifts;
	info->bufferram = tmp.bufferram >> shifts;
	info->totalswap = tmp.totalswap >> shifts;
	info->freeswap = tmp.freeswap >> shifts;
	info->procs = tmp.procs ;
	info->totalhigh = tmp.totalhigh >> shifts;
	info->freehigh = tmp.freehigh >> shifts;
	info->mem_unit = (tmp.mem_unit ? tmp.mem_unit : 1) << shifts;
	return ret;
}

weak_alias(__lsysinfo, sysinfo);
