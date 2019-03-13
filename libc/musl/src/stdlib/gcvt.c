#define _GNU_SOURCE
#include <stdlib.h>
#include <stdio.h>

char *gcvt(double x, int n, char *b)
{
	sprintf(b, "%.*g", n, x);
	return b;
}
