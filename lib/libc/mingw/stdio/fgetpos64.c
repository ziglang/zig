#include <stdio.h>

int __cdecl fgetpos64(FILE * __restrict__ _File ,fpos_t * __restrict__ _Pos){
  return fgetpos(_File, _Pos);
}
