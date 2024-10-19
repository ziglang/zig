
// includes commented out to make sure the symbols come from the precompiled header.
//#include "include_a.h"
//#include "include_b.h"

#ifndef A_INCLUDED
#error "pch not included"
#endif
#ifndef B_INCLUDED
#error "pch not included"
#endif

extern int func(real a, bool cond);

int main(int argc, char *argv[])
{
	real a = 0.123;
	return func(a, (argc > 1));
}
