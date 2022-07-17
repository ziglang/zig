#include <libintl.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <limits.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <ctype.h>
#include "locale_impl.h"
#include "atomic.h"
#include "pleval.h"
#include "lock.h"
#include "fork_impl.h"

#define malloc __libc_malloc
#define calloc __libc_calloc
#define realloc undef
#define free undef

struct binding {
	struct binding *next;
	int dirlen;
	volatile int active;
	char *domainname;
	char *dirname;
	char buf[];
};

static void *volatile bindings;

static char *gettextdir(const char *domainname, size_t *dirlen)
{
	struct binding *p;
	for (p=bindings; p; p=p->next) {
		if (!strcmp(p->domainname, domainname) && p->active) {
			*dirlen = p->dirlen;
			return (char *)p->dirname;
		}
	}
	return 0;
}

static volatile int lock[1];
volatile int *const __gettext_lockptr = lock;

char *bindtextdomain(const char *domainname, const char *dirname)
{
	struct binding *p, *q;

	if (!domainname) return 0;
	if (!dirname) return gettextdir(domainname, &(size_t){0});

	size_t domlen = strnlen(domainname, NAME_MAX+1);
	size_t dirlen = strnlen(dirname, PATH_MAX);
	if (domlen > NAME_MAX || dirlen >= PATH_MAX) {
		errno = EINVAL;
		return 0;
	}

	LOCK(lock);

	for (p=bindings; p; p=p->next) {
		if (!strcmp(p->domainname, domainname) &&
		    !strcmp(p->dirname, dirname)) {
			break;
		}
	}

	if (!p) {
		p = calloc(sizeof *p + domlen + dirlen + 2, 1);
		if (!p) {
			UNLOCK(lock);
			return 0;
		}
		p->next = bindings;
		p->dirlen = dirlen;
		p->domainname = p->buf;
		p->dirname = p->buf + domlen + 1;
		memcpy(p->domainname, domainname, domlen+1);
		memcpy(p->dirname, dirname, dirlen+1);
		a_cas_p(&bindings, bindings, p);
	}

	a_store(&p->active, 1);

	for (q=bindings; q; q=q->next) {
		if (!strcmp(q->domainname, domainname) && q != p)
			a_store(&q->active, 0);
	}

	UNLOCK(lock);
	
	return (char *)p->dirname;
}

static const char catnames[][12] = {
	"LC_CTYPE",
	"LC_NUMERIC",
	"LC_TIME",
	"LC_COLLATE",
	"LC_MONETARY",
	"LC_MESSAGES",
};

static const char catlens[] = { 8, 10, 7, 10, 11, 11 };

struct msgcat {
	struct msgcat *next;
	const void *map;
	size_t map_size;
	const char *plural_rule;
	int nplurals;
	struct binding *binding;
	const struct __locale_map *lm;
	int cat;
};

static char *dummy_gettextdomain()
{
	return "messages";
}

weak_alias(dummy_gettextdomain, __gettextdomain);

char *dcngettext(const char *domainname, const char *msgid1, const char *msgid2, unsigned long int n, int category)
{
	static struct msgcat *volatile cats;
	struct msgcat *p;
	struct __locale_struct *loc = CURRENT_LOCALE;
	const struct __locale_map *lm;
	size_t domlen;
	struct binding *q;
	int old_errno = errno;

	/* match gnu gettext behaviour */
	if (!msgid1) goto notrans;

	if ((unsigned)category >= LC_ALL) goto notrans;

	if (!domainname) domainname = __gettextdomain();

	domlen = strnlen(domainname, NAME_MAX+1);
	if (domlen > NAME_MAX) goto notrans;

	for (q=bindings; q; q=q->next)
		if (!strcmp(q->domainname, domainname) && q->active)
			break;
	if (!q) goto notrans;

	lm = loc->cat[category];
	if (!lm) {
notrans:
		errno = old_errno;
		return (char *) ((n == 1) ? msgid1 : msgid2);
	}

	for (p=cats; p; p=p->next)
		if (p->binding == q && p->lm == lm && p->cat == category)
			break;

	if (!p) {
		const char *dirname, *locname, *catname, *modname, *locp;
		size_t dirlen, loclen, catlen, modlen, alt_modlen;
		void *old_cats;
		size_t map_size;

		dirname = q->dirname;
		locname = lm->name;
		catname = catnames[category];

		dirlen = q->dirlen;
		loclen = strlen(locname);
		catlen = catlens[category];

		/* Logically split @mod suffix from locale name. */
		modname = memchr(locname, '@', loclen);
		if (!modname) modname = locname + loclen;
		alt_modlen = modlen = loclen - (modname-locname);
		loclen = modname-locname;

		/* Drop .charset identifier; it is not used. */
		const char *csp = memchr(locname, '.', loclen);
		if (csp) loclen = csp-locname;

		char name[dirlen+1 + loclen+modlen+1 + catlen+1 + domlen+3 + 1];
		const void *map;

		for (;;) {
			snprintf(name, sizeof name, "%s/%.*s%.*s/%s/%s.mo\0",
				dirname, (int)loclen, locname,
				(int)alt_modlen, modname, catname, domainname);
			if (map = __map_file(name, &map_size)) break;

			/* Try dropping @mod, _YY, then both. */
			if (alt_modlen) {
				alt_modlen = 0;
			} else if ((locp = memchr(locname, '_', loclen))) {
				loclen = locp-locname;
				alt_modlen = modlen;
			} else {
				break;
			}
		}
		if (!map) goto notrans;

		p = calloc(sizeof *p, 1);
		if (!p) {
			__munmap((void *)map, map_size);
			goto notrans;
		}
		p->cat = category;
		p->binding = q;
		p->lm = lm;
		p->map = map;
		p->map_size = map_size;

		const char *rule = "n!=1;";
		unsigned long np = 2;
		const char *r = __mo_lookup(p->map, p->map_size, "");
		char *z;
		while (r && strncmp(r, "Plural-Forms:", 13)) {
			z = strchr(r, '\n');
			r = z ? z+1 : 0;
		}
		if (r) {
			r += 13;
			while (isspace(*r)) r++;
			if (!strncmp(r, "nplurals=", 9)) {
				np = strtoul(r+9, &z, 10);
				r = z;
			}
			while (*r && *r != ';') r++;
			if (*r) {
				r++;
				while (isspace(*r)) r++;
				if (!strncmp(r, "plural=", 7))
					rule = r+7;
			}
		}
		p->nplurals = np;
		p->plural_rule = rule;

		do {
			old_cats = cats;
			p->next = old_cats;
		} while (a_cas_p(&cats, old_cats, p) != old_cats);
	}

	const char *trans = __mo_lookup(p->map, p->map_size, msgid1);
	if (!trans) goto notrans;

	/* Non-plural-processing gettext forms pass a null pointer as
	 * msgid2 to request that dcngettext suppress plural processing. */

	if (msgid2 && p->nplurals) {
		unsigned long plural = __pleval(p->plural_rule, n);
		if (plural > p->nplurals) goto notrans;
		while (plural--) {
			size_t rem = p->map_size - (trans - (char *)p->map);
			size_t l = strnlen(trans, rem);
			if (l+1 >= rem)
				goto notrans;
			trans += l+1;
		}
	}
	errno = old_errno;
	return (char *)trans;
}

char *dcgettext(const char *domainname, const char *msgid, int category)
{
	return dcngettext(domainname, msgid, 0, 1, category);
}

char *dngettext(const char *domainname, const char *msgid1, const char *msgid2, unsigned long int n)
{
	return dcngettext(domainname, msgid1, msgid2, n, LC_MESSAGES);
}

char *dgettext(const char *domainname, const char *msgid)
{
	return dcngettext(domainname, msgid, 0, 1, LC_MESSAGES);
}
