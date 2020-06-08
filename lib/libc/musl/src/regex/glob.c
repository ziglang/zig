#define _BSD_SOURCE
#include <glob.h>
#include <fnmatch.h>
#include <sys/stat.h>
#include <dirent.h>
#include <limits.h>
#include <string.h>
#include <stdlib.h>
#include <errno.h>
#include <stddef.h>
#include <unistd.h>
#include <pwd.h>

struct match
{
	struct match *next;
	char name[];
};

static int append(struct match **tail, const char *name, size_t len, int mark)
{
	struct match *new = malloc(sizeof(struct match) + len + 2);
	if (!new) return -1;
	(*tail)->next = new;
	new->next = NULL;
	memcpy(new->name, name, len+1);
	if (mark && len && name[len-1]!='/') {
		new->name[len] = '/';
		new->name[len+1] = 0;
	}
	*tail = new;
	return 0;
}

static int do_glob(char *buf, size_t pos, int type, char *pat, int flags, int (*errfunc)(const char *path, int err), struct match **tail)
{
	/* If GLOB_MARK is unused, we don't care about type. */
	if (!type && !(flags & GLOB_MARK)) type = DT_REG;

	/* Special-case the remaining pattern being all slashes, in
	 * which case we can use caller-passed type if it's a dir. */
	if (*pat && type!=DT_DIR) type = 0;
	while (pos+1 < PATH_MAX && *pat=='/') buf[pos++] = *pat++;

	/* Consume maximal [escaped-]literal prefix of pattern, copying
	 * and un-escaping it to the running buffer as we go. */
	ptrdiff_t i=0, j=0;
	int in_bracket = 0, overflow = 0;
	for (; pat[i]!='*' && pat[i]!='?' && (!in_bracket || pat[i]!=']'); i++) {
		if (!pat[i]) {
			if (overflow) return 0;
			pat += i;
			pos += j;
			i = j = 0;
			break;
		} else if (pat[i] == '[') {
			in_bracket = 1;
		} else if (pat[i] == '\\' && !(flags & GLOB_NOESCAPE)) {
			/* Backslashes inside a bracket are (at least by
			 * our interpretation) non-special, so if next
			 * char is ']' we have a complete expression. */
			if (in_bracket && pat[i+1]==']') break;
			/* Unpaired final backslash never matches. */
			if (!pat[i+1]) return 0;
			i++;
		}
		if (pat[i] == '/') {
			if (overflow) return 0;
			in_bracket = 0;
			pat += i+1;
			i = -1;
			pos += j+1;
			j = -1;
		}
		/* Only store a character if it fits in the buffer, but if
		 * a potential bracket expression is open, the overflow
		 * must be remembered and handled later only if the bracket
		 * is unterminated (and thereby a literal), so as not to
		 * disallow long bracket expressions with short matches. */
		if (pos+(j+1) < PATH_MAX) {
			buf[pos+j++] = pat[i];
		} else if (in_bracket) {
			overflow = 1;
		} else {
			return 0;
		}
		/* If we consume any new components, the caller-passed type
		 * or dummy type from above is no longer valid. */
		type = 0;
	}
	buf[pos] = 0;
	if (!*pat) {
		/* If we consumed any components above, or if GLOB_MARK is
		 * requested and we don't yet know if the match is a dir,
		 * we must confirm the file exists and/or determine its type.
		 *
		 * If marking dirs, symlink type is inconclusive; we need the
		 * type for the symlink target, and therefore must try stat
		 * first unless type is known not to be a symlink. Otherwise,
		 * or if that fails, use lstat for determining existence to
		 * avoid false negatives in the case of broken symlinks. */
		struct stat st;
		if ((flags & GLOB_MARK) && (!type||type==DT_LNK) && !stat(buf, &st)) {
			if (S_ISDIR(st.st_mode)) type = DT_DIR;
			else type = DT_REG;
		}
		if (!type && lstat(buf, &st)) {
			if (errno!=ENOENT && (errfunc(buf, errno) || (flags & GLOB_ERR)))
				return GLOB_ABORTED;
			return 0;
		}
		if (append(tail, buf, pos, (flags & GLOB_MARK) && type==DT_DIR))
			return GLOB_NOSPACE;
		return 0;
	}
	char *p2 = strchr(pat, '/'), saved_sep = '/';
	/* Check if the '/' was escaped and, if so, remove the escape char
	 * so that it will not be unpaired when passed to fnmatch. */
	if (p2 && !(flags & GLOB_NOESCAPE)) {
		char *p;
		for (p=p2; p>pat && p[-1]=='\\'; p--);
		if ((p2-p)%2) {
			p2--;
			saved_sep = '\\';
		}
	}
	DIR *dir = opendir(pos ? buf : ".");
	if (!dir) {
		if (errfunc(buf, errno) || (flags & GLOB_ERR))
			return GLOB_ABORTED;
		return 0;
	}
	int old_errno = errno;
	struct dirent *de;
	while (errno=0, de=readdir(dir)) {
		/* Quickly skip non-directories when there's pattern left. */
		if (p2 && de->d_type && de->d_type!=DT_DIR && de->d_type!=DT_LNK)
			continue;

		size_t l = strlen(de->d_name);
		if (l >= PATH_MAX-pos) continue;

		if (p2) *p2 = 0;

		int fnm_flags= ((flags & GLOB_NOESCAPE) ? FNM_NOESCAPE : 0)
			| ((!(flags & GLOB_PERIOD)) ? FNM_PERIOD : 0);

		if (fnmatch(pat, de->d_name, fnm_flags))
			continue;

		/* With GLOB_PERIOD, don't allow matching . or .. unless
		 * fnmatch would match them with FNM_PERIOD rules in effect. */
		if (p2 && (flags & GLOB_PERIOD) && de->d_name[0]=='.'
		    && (!de->d_name[1] || de->d_name[1]=='.' && !de->d_name[2])
		    && fnmatch(pat, de->d_name, fnm_flags | FNM_PERIOD))
			continue;

		memcpy(buf+pos, de->d_name, l+1);
		if (p2) *p2 = saved_sep;
		int r = do_glob(buf, pos+l, de->d_type, p2 ? p2 : "", flags, errfunc, tail);
		if (r) {
			closedir(dir);
			return r;
		}
	}
	int readerr = errno;
	if (p2) *p2 = saved_sep;
	closedir(dir);
	if (readerr && (errfunc(buf, errno) || (flags & GLOB_ERR)))
		return GLOB_ABORTED;
	errno = old_errno;
	return 0;
}

static int ignore_err(const char *path, int err)
{
	return 0;
}

static void freelist(struct match *head)
{
	struct match *match, *next;
	for (match=head->next; match; match=next) {
		next = match->next;
		free(match);
	}
}

static int sort(const void *a, const void *b)
{
	return strcmp(*(const char **)a, *(const char **)b);
}

static int expand_tilde(char **pat, char *buf, size_t *pos)
{
	char *p = *pat + 1;
	size_t i = 0;

	char delim, *name_end = __strchrnul(p, '/');
	if ((delim = *name_end)) *name_end++ = 0;
	*pat = name_end;

	char *home = *p ? NULL : getenv("HOME");
	if (!home) {
		struct passwd pw, *res;
		switch (*p ? getpwnam_r(p, &pw, buf, PATH_MAX, &res)
			   : getpwuid_r(getuid(), &pw, buf, PATH_MAX, &res)) {
		case ENOMEM:
			return GLOB_NOSPACE;
		case 0:
			if (!res)
		default:
				return GLOB_NOMATCH;
		}
		home = pw.pw_dir;
	}
	while (i < PATH_MAX - 2 && *home)
		buf[i++] = *home++;
	if (*home)
		return GLOB_NOMATCH;
	if ((buf[i] = delim))
		buf[++i] = 0;
	*pos = i;
	return 0;
}

int glob(const char *restrict pat, int flags, int (*errfunc)(const char *path, int err), glob_t *restrict g)
{
	struct match head = { .next = NULL }, *tail = &head;
	size_t cnt, i;
	size_t offs = (flags & GLOB_DOOFFS) ? g->gl_offs : 0;
	int error = 0;
	char buf[PATH_MAX];
	
	if (!errfunc) errfunc = ignore_err;

	if (!(flags & GLOB_APPEND)) {
		g->gl_offs = offs;
		g->gl_pathc = 0;
		g->gl_pathv = NULL;
	}

	if (*pat) {
		char *p = strdup(pat);
		if (!p) return GLOB_NOSPACE;
		buf[0] = 0;
		size_t pos = 0;
		char *s = p;
		if ((flags & (GLOB_TILDE | GLOB_TILDE_CHECK)) && *p == '~')
			error = expand_tilde(&s, buf, &pos);
		if (!error)
			error = do_glob(buf, pos, 0, s, flags, errfunc, &tail);
		free(p);
	}

	if (error == GLOB_NOSPACE) {
		freelist(&head);
		return error;
	}
	
	for (cnt=0, tail=head.next; tail; tail=tail->next, cnt++);
	if (!cnt) {
		if (flags & GLOB_NOCHECK) {
			tail = &head;
			if (append(&tail, pat, strlen(pat), 0))
				return GLOB_NOSPACE;
			cnt++;
		} else
			return GLOB_NOMATCH;
	}

	if (flags & GLOB_APPEND) {
		char **pathv = realloc(g->gl_pathv, (offs + g->gl_pathc + cnt + 1) * sizeof(char *));
		if (!pathv) {
			freelist(&head);
			return GLOB_NOSPACE;
		}
		g->gl_pathv = pathv;
		offs += g->gl_pathc;
	} else {
		g->gl_pathv = malloc((offs + cnt + 1) * sizeof(char *));
		if (!g->gl_pathv) {
			freelist(&head);
			return GLOB_NOSPACE;
		}
		for (i=0; i<offs; i++)
			g->gl_pathv[i] = NULL;
	}
	for (i=0, tail=head.next; i<cnt; tail=tail->next, i++)
		g->gl_pathv[offs + i] = tail->name;
	g->gl_pathv[offs + i] = NULL;
	g->gl_pathc += cnt;

	if (!(flags & GLOB_NOSORT))
		qsort(g->gl_pathv+offs, cnt, sizeof(char *), sort);
	
	return error;
}

void globfree(glob_t *g)
{
	size_t i;
	for (i=0; i<g->gl_pathc; i++)
		free(g->gl_pathv[g->gl_offs + i] - offsetof(struct match, name));
	free(g->gl_pathv);
	g->gl_pathc = 0;
	g->gl_pathv = NULL;
}

weak_alias(glob, glob64);
weak_alias(globfree, globfree64);
