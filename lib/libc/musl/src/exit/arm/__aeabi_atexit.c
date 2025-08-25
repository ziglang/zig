int __cxa_atexit(void (*func)(void *), void *arg, void *dso);

int __aeabi_atexit (void *obj, void (*func) (void *), void *d)
{
	return __cxa_atexit (func, obj, d);
}
