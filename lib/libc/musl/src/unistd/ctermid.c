#include <stdio.h>
#include <string.h>

char *ctermid(char *s)
{
	return s ? strcpy(s, "/dev/tty") : "/dev/tty";
}
