#define START "_start"
#define _dlstart_c _start_c
#include "../ldso/dlstart.c"

int main();
weak void _init();
weak void _fini();
int __libc_start_main(int (*)(), int, char **,
	void (*)(), void(*)(), void(*)());

hidden void __dls2(unsigned char *base, size_t *sp)
{
	__libc_start_main(main, *sp, (void *)(sp+1), _init, _fini, 0);
}
