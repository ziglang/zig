#include <stdio.h>

char* hello();
extern char world[];

int main(int argc, char* argv[]) {
  printf("%s %s", hello(), world);
  return 0;
}
