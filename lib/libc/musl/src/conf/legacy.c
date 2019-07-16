#include <sys/sysinfo.h>
#include <unistd.h>

int get_nprocs_conf()
{
	return sysconf(_SC_NPROCESSORS_CONF);
}

int get_nprocs()
{
	return sysconf(_SC_NPROCESSORS_ONLN);
}

long get_phys_pages()
{
	return sysconf(_SC_PHYS_PAGES);	
}

long get_avphys_pages()
{
	return sysconf(_SC_AVPHYS_PAGES);	
}
