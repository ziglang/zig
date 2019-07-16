#include <unistd.h>
#include <fcntl.h>
#include <errno.h>

int truncate(const char *pathname, _off_t len){
  int ret, err;
  int fd = _open(pathname,_O_BINARY|_O_RDWR);
  if (fd == -1) return fd;
  ret = ftruncate(fd,len);
  _get_errno(&err);
  _close(fd);
  _set_errno(err);
  return ret;
}

int truncate64(const char *pathname, _off64_t len){
  int ret, err;
  int fd = _open(pathname,_O_BINARY|_O_RDWR);
  if (fd == -1) return fd;
  ret = ftruncate64(fd,len);
  _get_errno(&err);
  _close(fd);
  _set_errno(err);
  return ret;
}
