#include <stdio.h>

int a = 42;

const char* asStr() {
  static char str[3];
  sprintf(str, "%d", 42);
  return str;
}
