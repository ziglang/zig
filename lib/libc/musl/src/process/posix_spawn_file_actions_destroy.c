#include <spawn.h>
#include <stdlib.h>
#include "fdop.h"

int posix_spawn_file_actions_destroy(posix_spawn_file_actions_t *fa)
{
	struct fdop *op = fa->__actions, *next;
	while (op) {
		next = op->next;
		free(op);
		op = next;
	}
	return 0;
}
