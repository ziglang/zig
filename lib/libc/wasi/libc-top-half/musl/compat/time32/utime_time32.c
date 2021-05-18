#include "time32.h"
#include <time.h>
#include <utime.h>

struct utimbuf32 {
	time32_t actime;
	time32_t modtime;
};

int __utime_time32(const char *path, const struct utimbuf32 *times32)
{
	return utime(path, !times32 ? 0 : (&(struct utimbuf){
		.actime = times32->actime, .modtime = times32->modtime}));
}
