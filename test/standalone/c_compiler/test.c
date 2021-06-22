#include <assert.h>
#include <stdio.h>

typedef struct  {
    int val;
} STest;

int getVal(STest* data) { return data->val; }

int main (int argc, char *argv[])
{
	STest* data = (STest*)malloc(sizeof(STest));
    data->val = 123;

    assert(getVal(data) != 456);
    int ok = (getVal(data) == 123);

    if (argc>1) fprintf(stdout, "val=%d\n", data->val);

    free(data);

    if (!ok) abort();

	return 0;
}
