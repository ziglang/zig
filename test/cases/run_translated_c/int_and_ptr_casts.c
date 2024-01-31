#include <stdint.h>

int main() {
  int8_t foo8;
  uint8_t ufoo8;
  void* void_ptr;
  intptr_t i_ptr;
  uintptr_t u_ptr;
  __int128 bigint;
  unsigned __int128 biguint;

  foo8 = -1;
  void_ptr = (void *)foo8;
  i_ptr = (intptr_t)void_ptr;
  if (i_ptr != -1) return 1;

  ufoo8 = 255;
  void_ptr = (void *)ufoo8;
  u_ptr = (uintptr_t)void_ptr;
  if (u_ptr != 255) return 2;

  i_ptr = -1;
  void_ptr = (void *)i_ptr;
  i_ptr = (intptr_t)void_ptr;
  if (i_ptr != -1) return 3;

  u_ptr = -1;
  void_ptr = (void *)u_ptr;
  u_ptr = (uintptr_t)void_ptr;
  if (u_ptr != -1) return 4;
  
  bigint = -1;
  void_ptr = (void *)bigint;
  bigint = (__int128)void_ptr;
  u_ptr = -1;
  __int128 bigint_compare = u_ptr;
  if (bigint != bigint_compare) return 5;

  biguint = -1;
  void_ptr = (void *)biguint;
  biguint = (unsigned __int128)void_ptr;
  u_ptr = -1;
  unsigned __int128 biguint_compare = u_ptr;
  if (biguint != biguint_compare) return 6;

  return 0;
}

// run-translated-c
// c_frontends=clang
// targets=x86_64-linux
