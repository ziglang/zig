#include <stdint.h>
#include <stdlib.h>

int main() {
  int16_t foo16;
  uint16_t ufoo16;
  void* void_ptr;
  intptr_t i_ptr;
  uintptr_t u_ptr;
  __int128 bigint;
  unsigned __int128 biguint;

  foo16 = -1;
  void_ptr = (void *)foo16;
  i_ptr = (intptr_t)void_ptr;
  if (i_ptr != -1) abort();

  ufoo16 = -1;
  void_ptr = (void *)ufoo16;
  u_ptr = (uintptr_t)void_ptr;
  if (u_ptr != 0xFFFF) abort();

  i_ptr = -1;
  void_ptr = (void *)i_ptr;
  i_ptr = (intptr_t)void_ptr;
  if (i_ptr != -1) abort();

  u_ptr = -1;
  void_ptr = (void *)u_ptr;
  u_ptr = (uintptr_t)void_ptr;
  if (u_ptr != -1) abort();
  
  bigint = -1;
  void_ptr = (void *)bigint;
  bigint = (__int128)void_ptr;
  if (bigint != 0xFFFFFFFFFFFFFFFF) abort();

  biguint = 0xFFFFFFFFFFFFFFFF + 64;
  void_ptr = (void *)biguint;
  biguint = (unsigned __int128)void_ptr;
  if (biguint != 64-1) abort();

  return 0;
}

// run-translated-c
// c_frontends=clang
// targets=x86_64-linux-none,x86_64-macos-none,x86_64-windows-none,
// link_libc=true
