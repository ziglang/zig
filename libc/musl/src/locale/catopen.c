#include <nl_types.h>
#include <errno.h>

nl_catd catopen (const char *name, int oflag)
{
	errno = EOPNOTSUPP;
	return (nl_catd)-1;
}
