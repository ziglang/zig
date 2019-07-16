#include <libintl.h>
#include <string.h>
#include <strings.h>
#include <errno.h>

char *bind_textdomain_codeset(const char *domainname, const char *codeset)
{
	if (codeset && strcasecmp(codeset, "UTF-8"))
		errno = EINVAL;
	return NULL;
}
