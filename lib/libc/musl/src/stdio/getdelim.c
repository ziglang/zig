#include "stdio_impl.h"
#include <string.h>
#include <stdlib.h>
#include <inttypes.h>
#include <errno.h>

ssize_t getdelim(char **restrict s, size_t *restrict n, int delim, FILE *restrict f)
{
	char *tmp;
	unsigned char *z;
	size_t k;
	size_t i=0;
	int c;

	FLOCK(f);

	if (!n || !s) {
		f->mode |= f->mode-1;
		f->flags |= F_ERR;
		FUNLOCK(f);
		errno = EINVAL;
		return -1;
	}

	if (!*s) *n=0;

	for (;;) {
		if (f->rpos != f->rend) {
			z = memchr(f->rpos, delim, f->rend - f->rpos);
			k = z ? z - f->rpos + 1 : f->rend - f->rpos;
		} else {
			z = 0;
			k = 0;
		}
		if (i+k >= *n) {
			size_t m = i+k+2;
			if (!z && m < SIZE_MAX/4) m += m/2;
			tmp = realloc(*s, m);
			if (!tmp) {
				m = i+k+2;
				tmp = realloc(*s, m);
				if (!tmp) {
					/* Copy as much as fits and ensure no
					 * pushback remains in the FILE buf. */
					k = *n-i;
					memcpy(*s+i, f->rpos, k);
					f->rpos += k;
					f->mode |= f->mode-1;
					f->flags |= F_ERR;
					FUNLOCK(f);
					errno = ENOMEM;
					return -1;
				}
			}
			*s = tmp;
			*n = m;
		}
		memcpy(*s+i, f->rpos, k);
		f->rpos += k;
		i += k;
		if (z) break;
		if ((c = getc_unlocked(f)) == EOF) {
			if (!i || !feof(f)) {
				FUNLOCK(f);
				return -1;
			}
			break;
		}
		/* If the byte read by getc won't fit without growing the
		 * output buffer, push it back for next iteration. */
		if (i+1 >= *n) *--f->rpos = c;
		else if (((*s)[i++] = c) == delim) break;
	}
	(*s)[i] = 0;

	FUNLOCK(f);

	return i;
}

weak_alias(getdelim, __getdelim);
