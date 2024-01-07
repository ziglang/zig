#include <stdbool.h>

int main() {
  bool b = true;
  float f;
  f = (float)b;
  f = (float)(10.0f > 1.0f);
  return 0;
}

// run-translated-c
// c_frontend=clang
// link_libc=true
//
