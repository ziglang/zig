#include <shadow.h>
#include <stdio.h>

#define NUM(n) ((n) == -1 ? 0 : -1), ((n) == -1 ? 0 : (n))
#define STR(s) ((s) ? (s) : "")

int putspent(const struct spwd *sp, FILE *f)
{
	return fprintf(f, "%s:%s:%.*ld:%.*ld:%.*ld:%.*ld:%.*ld:%.*ld:%.*lu\n",
		STR(sp->sp_namp), STR(sp->sp_pwdp), NUM(sp->sp_lstchg),
		NUM(sp->sp_min), NUM(sp->sp_max), NUM(sp->sp_warn),
		NUM(sp->sp_inact), NUM(sp->sp_expire), NUM(sp->sp_flag)) < 0 ? -1 : 0;
}
