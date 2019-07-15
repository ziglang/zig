#include <stdio.h>

int __cdecl fsetpos64(FILE *_File,const fpos_t *_Pos){ /* fsetpos already 64bit */
  return fsetpos(_File,_Pos);
}
