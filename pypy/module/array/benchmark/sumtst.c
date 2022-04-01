#include <stdlib.h>

double sum(double *img);

void main() {
  double *img=malloc(640*480*4*sizeof(double));
  int sa=0;
  for (int l=0; l<500; l++) sum(img);
}
