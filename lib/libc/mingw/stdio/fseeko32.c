/*non-standard*/
#include <stdio.h>

int fseeko(FILE* stream, _off_t offset, int whence){
  _off64_t off = offset;
  return fseeko64(stream,off,whence);
}
