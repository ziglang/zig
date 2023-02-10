#include <stdio.h>

extern int a;
extern const char* asStr();

int main(int argc, char* argv[]) {
  printf("%d %s", a, asStr());
  return 0;
}
