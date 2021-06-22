#include <fenv.h>
#include <features.h>

static inline unsigned get_fpc(void)
{
	unsigned fpc;
	__asm__ __volatile__("efpc %0" : "=r"(fpc));
	return fpc;
}

static inline void set_fpc(unsigned fpc)
{
	__asm__ __volatile__("sfpc %0" :: "r"(fpc));
}

int feclearexcept(int mask)
{
	mask &= FE_ALL_EXCEPT;
	set_fpc(get_fpc() & ~mask);
	return 0;
}

int feraiseexcept(int mask)
{
	mask &= FE_ALL_EXCEPT;
	set_fpc(get_fpc() | mask);
	return 0;
}

int fetestexcept(int mask)
{
	return get_fpc() & mask & FE_ALL_EXCEPT;
}

int fegetround(void)
{
	return get_fpc() & 3;
}

hidden int __fesetround(int r)
{
	set_fpc(get_fpc() & ~3L | r);
	return 0;
}

int fegetenv(fenv_t *envp)
{
	*envp = get_fpc();
	return 0;
}

int fesetenv(const fenv_t *envp)
{
	set_fpc(envp != FE_DFL_ENV ? *envp : 0);
	return 0;
}
