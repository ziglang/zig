
// includes commented out to make sure the symbols come from the precompiled header.
//#include "includeA.h"
//#include "includeB.h"

#ifndef A_INCLUDED
#error "pch not included"
#endif
#ifndef B_INCLUDED
#error "pch not included"
#endif

int main(int argc, char *argv[])
{
	real a = -0.123;

	if (argc > 1) {
		std::cout << "abs(" << a << ")=" << fabs(a) << "\n";
	}

	return EXIT_SUCCESS;
}

