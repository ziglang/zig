#include <stdio.h>

double buf[65536];

double circular(double *buf);

int main() {
  double sa = circular(buf);
  //printf("%f\n", sa);
}
