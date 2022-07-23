#include <stdio.h>

void printMe() {
  printf("Hello!\n");
}

int main(int argc, char* argv[]) {
  printMe();
  return 0;
}

void iAmUnused() {
  printf("YOU SHALL NOT PASS!\n");
}
