#include <sys/mman.h>
#include <fcntl.h>
#include <sys/stat.h>
#include "syscall.h"
#include "kstat.h"

const char unsigned *__map_file(const char *pathname, size_t *size)
{
	struct kstat st;
	const unsigned char *map = MAP_FAILED;
	int fd = sys_open(pathname, O_RDONLY|O_CLOEXEC|O_NONBLOCK);
	if (fd < 0) return 0;
	if (!syscall(SYS_fstat, fd, &st)) {
		map = __mmap(0, st.st_size, PROT_READ, MAP_SHARED, fd, 0);
		*size = st.st_size;
	}
	__syscall(SYS_close, fd);
	return map == MAP_FAILED ? 0 : map;
}
