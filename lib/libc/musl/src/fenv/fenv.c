#include <fenv.h>

/* Dummy functions for archs lacking fenv implementation */

int feclearexcept(int mask)
{
	return 0;
}

int feraiseexcept(int mask)
{
	return 0;
}

int fetestexcept(int mask)
{
	return 0;
}

int fegetround(void)
{
	return FE_TONEAREST;
}

int __fesetround(int r)
{
	return 0;
}

int fegetenv(fenv_t *envp)
{
	return 0;
}

int fesetenv(const fenv_t *envp)
{
	return 0;
}
