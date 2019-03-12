#include <dirent.h>
#include <unistd.h>
#include "__dirent.h"
#include "lock.h"

void rewinddir(DIR *dir)
{
	LOCK(dir->lock);
	lseek(dir->fd, 0, SEEK_SET);
	dir->buf_pos = dir->buf_end = 0;
	dir->tell = 0;
	UNLOCK(dir->lock);
}
