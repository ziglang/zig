#include <dirent.h>
#include <unistd.h>
#include "__dirent.h"
#include "lock.h"

void seekdir(DIR *dir, long off)
{
	LOCK(dir->lock);
	dir->tell = lseek(dir->fd, off, SEEK_SET);
	dir->buf_pos = dir->buf_end = 0;
	UNLOCK(dir->lock);
}
