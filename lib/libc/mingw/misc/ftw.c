/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */

#include <stdlib.h>
#include <unistd.h>
#include <malloc.h>
#include <string.h>
#include <errno.h>
#include <limits.h>
#include <fcntl.h>
#include <sys/param.h>
#include <sys/stat.h>
#include <dirent.h>
#include <ftw.h>

#ifdef IMPL_FTW64
#define stat stat64
#define nftw nftw64
#define ftw ftw64
#endif

typedef struct dir_data_t {
  DIR *h;
  char *buf;
} dir_data_t;

typedef struct node_t {
  struct node_t *l, *r;
  unsigned int colored : 1;
} node_t;

typedef struct ctx_t {
  node_t *objs;
  dir_data_t **dirs;
  char *buf;
  struct FTW ftw;
  int (*fcb) (const char *, const struct stat *, int , struct FTW *);
  size_t cur_dir, msz_dir, buf_sz;
  int flags;
  dev_t dev;
} ctx_t;

static int add_object (ctx_t *);
static int do_dir (ctx_t *, struct stat *, dir_data_t *);
static int do_entity (ctx_t *, dir_data_t *, const char *, size_t);
static int do_it (const char *, int, void *, int, int);

static int open_directory (ctx_t *, dir_data_t *);

static void
prepare_for_insert (int forced, node_t **bp, node_t **pp1, node_t **pp2, int p1_c, int p2_c)
{
  node_t *p1, *p2, **rp, **lp, *b = *bp;

  rp = &(*bp)->r;
  lp = &(*bp)->l;

  if (!forced && ((*lp) == NULL || (*lp)->colored == 0 || (*rp) == NULL || (*rp)->colored == 0))
    return;

  b->colored = 1;

  if (*rp)
    (*rp)->colored = 0;

  if (*lp)
    (*lp)->colored = 0;

  if (!pp1 || (*pp1)->colored == 0)
    return;

  p1 = *pp1;
  p2 = *pp2;

  if ((p1_c > 0) == (p2_c > 0))
    {
      *pp2 = *pp1;
      p1->colored = 0;
      p2->colored = 1;
      *(p1_c < 0 ? &p2->l : &p2->r) = (p1_c < 0 ? p1->r : p1->l);
      *(p1_c < 0 ? &p1->r : &p1->l) = p2;
      return;
    }

  b->colored = 0;
  p1->colored = p2->colored = 1;
  *(p1_c < 0 ? &p1->l : &p1->r) = (p1_c < 0 ? *rp : *lp);
  *(p1_c < 0 ? rp : lp) = p1;
  *(p1_c < 0 ? &p2->r : &p2->l) = (p1_c < 0 ? *lp : *rp);
  *(p1_c < 0 ? lp : rp) = p2;
  *pp2 = b;
}

static int
add_object (ctx_t *ctx)
{
  node_t **bp, **np, *b, *n, **pp1 = NULL, **pp2 = NULL;
  int c = 0, p1_c = 0, p2_c = 0;

  if (ctx->objs)
    ctx->objs->colored = 0;

  np = bp = &ctx->objs;

  if (ctx->objs != NULL)
    {
      c = 1;

      do
	{
	  b = *bp;
	  prepare_for_insert (0, bp, pp1, pp2, p1_c, p2_c);
	  np = &b->r;

	  if (*np == NULL)
	    break;

	  pp2 = pp1;
	  p2_c = p1_c;
	  pp1 = bp;
	  p1_c = 1;
	  bp = np;
	}
      while (*np != NULL);
    }

  if (!(n = (node_t *) malloc (sizeof (node_t))))
    return -1;

  *np = n;
  n->l = n->r = NULL;
  n->colored = 1;

  if (np != bp)
    prepare_for_insert (1, np, bp, pp1, c, p1_c);

  return 0;
}

static int
open_directory (ctx_t *ctx, dir_data_t *dirp)
{
  DIR *st;
  struct dirent *d;
  char *buf, *h;
  size_t cur_sz, buf_sz, sz;
  int sv_e, ret = 0;

  if (ctx->dirs[ctx->cur_dir] != NULL)
    {
      if (!(buf = malloc (1024)))
	return -1;

      st = ctx->dirs[ctx->cur_dir]->h;

      buf_sz = 1024;
      cur_sz = 0;

      while ((d = readdir (st)) != NULL)
	{
	  sz = strlen (d->d_name);

	  if ((cur_sz + sz + 2) >= buf_sz)
	    {
	      buf_sz += ((2 * sz) < 1024 ? 1024 : (2 * sz));
	      if (!(h = (char *) realloc (buf, buf_sz)))
		{
		  sv_e = errno;
		  free (buf);
		  errno =  (sv_e);

		  return -1;
		}

	      buf = h;
	    }

	  *((char *) memcpy (buf + cur_sz, d->d_name, sz) + sz) = 0;
	  cur_sz += sz + 1;
	}

      buf[cur_sz++] = 0;

      ctx->dirs[ctx->cur_dir]->buf = realloc (buf, cur_sz);

      if (ctx->dirs[ctx->cur_dir]->buf == NULL)
	{
	  sv_e = errno;
	  free (buf);
	  errno = sv_e;
	  ret = -1;
	}
      else
	{
	  closedir (st);

	  ctx->dirs[ctx->cur_dir]->h = NULL;
	  ctx->dirs[ctx->cur_dir] = NULL;
	}
    }

  if (!ret)
    {
      dirp->h = opendir (ctx->buf);

      if (dirp->h == NULL)
	ret = -1;
      else
	{
	  dirp->buf = NULL;
	  ctx->dirs[ctx->cur_dir] = dirp;
	  ctx->cur_dir += 1;

	  if (ctx->cur_dir == ctx->msz_dir)
	    ctx->cur_dir = 0;
	}
    }

  return ret;
}


static int
do_entity (ctx_t *ctx, dir_data_t *dir, const char *name, size_t namlen)
{
  struct stat st;
  char *h;
  size_t cnt_sz;
  int ret = 0, flag = 0;

  if (name[0] == '.' && (name[1] == 0 || (name[1] == '.' && name[2] == 0)))
    return 0;

  cnt_sz = ctx->ftw.base + namlen + 2;

  if (ctx->buf_sz < cnt_sz)
    {
      ctx->buf_sz = cnt_sz * 2;
      
      if (!(h = (char *) realloc (ctx->buf, ctx->buf_sz)))
	return -1;

      ctx->buf = h;
    }

  *((char *) memcpy (ctx->buf + ctx->ftw.base, name, namlen) + namlen) = 0;

  name = ctx->buf;

  if (stat (name, &st) < 0)
    {
      if (errno != EACCES && errno != ENOENT)
	ret = -1;
      else
	flag = FTW_NS;

      if (!(ctx->flags & FTW_PHYS))
	stat (name, &st);
    }
  else
    flag = (S_ISDIR (st.st_mode) ? FTW_D : FTW_F);

  if (!ret && (flag == FTW_NS || !(ctx->flags & FTW_MOUNT) || st.st_dev == ctx->dev))
    {
      if (flag == FTW_D)
	{
	  if ((ctx->flags & FTW_PHYS) || !(ret = add_object (ctx)))
	    ret = do_dir (ctx, &st, dir);
	}
      else
	ret = (*ctx->fcb) (ctx->buf, &st, flag, &ctx->ftw);
    }

  if ((ctx->flags & FTW_ACTIONRETVAL) && ret == FTW_SKIP_SUBTREE)
    ret = 0;

  return ret;
}


static int
do_dir (ctx_t *ctx, struct stat *st, __UNUSED_PARAM(dir_data_t *old_dir))
{
  dir_data_t dir;
  struct dirent *d;
  char *startp, *runp, *endp;
  int sv_e, ret, previous_base = ctx->ftw.base;

  if ((ret = open_directory (ctx, &dir)) != 0)
    {
      if (errno == EACCES)
	ret = (*ctx->fcb) (ctx->buf, st, FTW_DNR, &ctx->ftw);

      return ret;
    }

  if (!(ctx->flags & FTW_DEPTH) && (ret = (*ctx->fcb) (ctx->buf, st, FTW_D, &ctx->ftw)) != 0)
    {
      sv_e = errno;
      closedir (dir.h);
      errno = sv_e;

      if (ctx->cur_dir-- == 0)
	ctx->cur_dir = ctx->msz_dir - 1;

      ctx->dirs[ctx->cur_dir] = NULL;

      return ret;
    }

  ctx->ftw.level += 1;
  startp = memchr (ctx->buf, 0, 1024);

  if (startp[-1] != '/')
    *startp++ = '/';

  ctx->ftw.base = (startp - ctx->buf);

  while (dir.h != NULL && (d = readdir (dir.h)) != NULL
         && !(ret = do_entity (ctx, &dir, d->d_name, strlen (d->d_name))))
      ;

  if (dir.h != NULL)
    {
      sv_e = errno;
      closedir (dir.h);
      errno = sv_e;

      if (ctx->cur_dir-- == 0)
	ctx->cur_dir = ctx->msz_dir - 1;

      ctx->dirs[ctx->cur_dir] = NULL;
    }
  else
    {
      runp = dir.buf;

      while (!ret && *runp != 0)
	{
	  endp = strchr (runp, 0);
	  ret = do_entity (ctx, &dir, runp, endp - runp);
	  runp = endp + 1;
	}

      sv_e = errno;
      free (dir.buf);
      errno = sv_e;
    }

  if ((ctx->flags & FTW_ACTIONRETVAL) && ret == FTW_SKIP_SIBLINGS)
    ret = 0;

  ctx->buf[ctx->ftw.base - 1] = 0;
  ctx->ftw.level -= 1;
  ctx->ftw.base = previous_base;

  if (!ret && (ctx->flags & FTW_DEPTH))
    ret = (*ctx->fcb) (ctx->buf, st, FTW_DP, &ctx->ftw);

  return ret;
}

static void
free_objs (node_t *r)
{
  if (r->l)
    free_objs (r->l);

  if (r->r)
    free_objs (r->r);

  free (r);
}

static int
do_it (const char *dir, __UNUSED_PARAM(int is_nftw), void *fcb, int descriptors, int flags)
{
  struct ctx_t ctx;
  struct stat st;
  int ret = 0;
  int sv_e;
  char *cp;

  if (dir[0] == 0)
  {
    errno =  (ENOENT);
    return -1;
  }

  ctx.msz_dir = descriptors < 1 ? 1 : descriptors;
  ctx.cur_dir = 0;
  ctx.dirs = (dir_data_t **) alloca (ctx.msz_dir * sizeof (dir_data_t *));
  memset (ctx.dirs, 0, ctx.msz_dir * sizeof (dir_data_t *));

  ctx.buf_sz = 2 * strlen (dir);

  if (ctx.buf_sz <= 1024)
    ctx.buf_sz = 1024;

  ctx.buf = (char *) malloc (ctx.buf_sz);

  if (ctx.buf == NULL)
    return -1;

  cp = strcpy (ctx.buf, dir) + strlen (dir);

  while (cp > (ctx.buf + 1) && cp[-1] == '/')
    --cp;

  *cp = 0;

  while (cp > ctx.buf && cp[-1] != '/')
    --cp;

  ctx.ftw.level = 0;
  ctx.ftw.base = cp - ctx.buf;
  ctx.flags = flags;
  ctx.fcb = (int (*) (const char *, const struct stat *, int , struct FTW *)) fcb;
  ctx.objs = NULL;

  if (!ret)
    {
      if (stat (ctx.buf, &st) < 0)
	ret = -1;
      else if (S_ISDIR (st.st_mode))
	{
	  ctx.dev = st.st_dev;

	  if (!(flags & FTW_PHYS))
	    ret = add_object (&ctx);

	  if (!ret)
	    ret = do_dir (&ctx, &st, NULL);
	}
      else
	ret = (*ctx.fcb) (ctx.buf, &st, FTW_F, &ctx.ftw);

      if ((flags & FTW_ACTIONRETVAL) && (ret == FTW_SKIP_SUBTREE || ret == FTW_SKIP_SIBLINGS))
	ret = 0;
    }

  sv_e = errno;
  if (ctx.objs)
    free_objs (ctx.objs);
  free (ctx.buf);
  errno =  (sv_e);

  return ret;
}

int
ftw (const char *path, int (*fcb) (const char *, const struct stat *, int), int descriptors)
{
  return do_it (path, 0, fcb, descriptors, 0);
}

int
nftw (const char *path, int (*fcb) (const char *, const struct stat *, int , struct FTW *), int descriptors, int flags)
{
  return do_it (path, 1, fcb, descriptors, flags);
}
