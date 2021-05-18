#include <fenv.h>
#include <features.h>

#if __HAVE_68881__ || __mcffpu__

static unsigned getsr()
{
	unsigned v;
	__asm__ __volatile__ ("fmove.l %%fpsr,%0" : "=dm"(v));
	return v;
}

static void setsr(unsigned v)
{
	__asm__ __volatile__ ("fmove.l %0,%%fpsr" : : "dm"(v));
}

static unsigned getcr()
{
	unsigned v;
	__asm__ __volatile__ ("fmove.l %%fpcr,%0" : "=dm"(v));
	return v;
}

static void setcr(unsigned v)
{
	__asm__ __volatile__ ("fmove.l %0,%%fpcr" : : "dm"(v));
}

int feclearexcept(int mask)
{
	if (mask & ~FE_ALL_EXCEPT) return -1;
	setsr(getsr() & ~mask);
	return 0;
}

int feraiseexcept(int mask)
{
	if (mask & ~FE_ALL_EXCEPT) return -1;
	setsr(getsr() | mask);
	return 0;
}

int fetestexcept(int mask)
{
	return getsr() & mask;
}

int fegetround(void)
{
	return getcr() & FE_UPWARD;
}

hidden int __fesetround(int r)
{
	setcr((getcr() & ~FE_UPWARD) | r);
	return 0;
}

int fegetenv(fenv_t *envp)
{
	envp->__control_register = getcr();
	envp->__status_register = getsr();
	__asm__ __volatile__ ("fmove.l %%fpiar,%0"
		: "=dm"(envp->__instruction_address));
	return 0;
}

int fesetenv(const fenv_t *envp)
{
	static const fenv_t default_env = { 0 };
	if (envp == FE_DFL_ENV)
		envp = &default_env;
	setcr(envp->__control_register);
	setsr(envp->__status_register);
	__asm__ __volatile__ ("fmove.l %0,%%fpiar"
		: : "dm"(envp->__instruction_address));
	return 0;
}

#else

#include "../fenv.c"

#endif
