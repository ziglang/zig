#define _GNU_SOURCE
#include <stdio.h>
#include <netdb.h>

void herror(const char *msg)
{
	fprintf(stderr, "%s%s%s", msg?msg:"", msg?": ":"", hstrerror(h_errno));
}
