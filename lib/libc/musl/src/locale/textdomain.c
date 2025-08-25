#include <libintl.h>
#include <string.h>
#include <stdlib.h>
#include <errno.h>
#include <limits.h>

static char *current_domain;

char *__gettextdomain()
{
	return current_domain ? current_domain : "messages";
}

char *textdomain(const char *domainname)
{
	if (!domainname) return __gettextdomain();

	size_t domlen = strlen(domainname);
	if (domlen > NAME_MAX) {
		errno = EINVAL;
		return 0;
	}

	if (!current_domain) {
		current_domain = malloc(NAME_MAX+1);
		if (!current_domain) return 0;
	}

	memcpy(current_domain, domainname, domlen+1);

	return current_domain;
}

char *gettext(const char *msgid)
{
	return dgettext(0, msgid);
}

char *ngettext(const char *msgid1, const char *msgid2, unsigned long int n)
{
	return dngettext(0, msgid1, msgid2, n);
}
