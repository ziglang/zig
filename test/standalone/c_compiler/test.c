#include <assert.h>
#include <complex.h>
#include <stdio.h>
#include <stdlib.h>

typedef struct {
  int val;
} STest;

int getVal(STest* data) { return data->val; }

int main (int argc, char *argv[])
{
  STest* data = (STest*)malloc(sizeof(STest));
  data->val = 123;

  assert(getVal(data) != 456);
  int ok = (getVal(data) == 123);

  if (argc > 1) {
    fprintf(stdout, "val=%d\n", data->val);
  }

  free(data);

  if (!ok) abort();

  // Test some basic arithmetic from compiler-rt
  {
    double complex z = 0.0 + I * 4.0;
    double complex w = 0.0 + I * 16.0;
    double complex product = z * w;
    double complex quotient = z / w;

    if (!(creal(product) == -64.0)) abort();
    if (!(cimag(product) == 0.0)) abort();
    if (!(creal(quotient) == 0.25)) abort();
    if (!(cimag(quotient) == 0.0)) abort();
  }

  {
    float complex z = 4.0 + I * 4.0;
    float complex w = 2.0 - I * 2.0;
    float complex product = z * w;
    float complex quotient = z / w;

    if (!(creal(product) == 16.0)) abort();
    if (!(cimag(product) == 0.0)) abort();
    if (!(creal(quotient) == 0.0)) abort();
    if (!(cimag(quotient) == 2.0)) abort();
  }

  return EXIT_SUCCESS;
}
