#include <windows.h>
#include "lib.h"

int wmain(int argc, wchar_t *argv[]) {
	if (!verify(argc, argv)) return 1;
	return 0;
}