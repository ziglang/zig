#include <stdint.h>

void main() {
  short s = -80;
  short* s_ptr = &s;
  unsigned short us = 160;
  unsigned short* us_ptr = &us;
  intptr_t i_ptr = 400;
  uintptr_t u_ptr = 800;

  s = (short)s_ptr;
  s_ptr = (short*)s;

  us = (unsigned short)us_ptr;
  us_ptr = (unsigned short*)us;

  s = (short)i_ptr;
  i_ptr = (intptr_t)s;

  s_ptr = (short*)i_ptr;
  i_ptr = (intptr_t)s_ptr;

  s = (short)u_ptr;
  u_ptr = (uintptr_t)s;

  s_ptr = (short*)u_ptr;
  u_ptr = (uintptr_t)s_ptr;
}

// run-translated-c
// c_frontends=aro,clang
// link_libc=true
