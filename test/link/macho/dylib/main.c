#include <stdio.h>

char* hello();
extern char world[];

int main() {
  printf("%s %s", hello(), world);
  return 0;
}
