
int _chsize(int _FileHandle,long _Size);
int ftruncate(int __fd,int __length);

int ftruncate(int __fd,int __length)
{
  return _chsize (__fd,__length);
}
