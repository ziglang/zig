#include <spawn.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include "fdop.h"

int posix_spawn_file_actions_addchdir_np(posix_spawn_file_actions_t *restrict fa, const char *restrict path)
{
	struct fdop *op = malloc(sizeof *op + strlen(path) + 1);
	if (!op) return ENOMEM;
	op->cmd = FDOP_CHDIR;
	op->fd = -1;
	strcpy(op->path, path);
	if ((op->next = fa->__actions)) op->next->prev = op;
	op->prev = 0;
	fa->__actions = op;
	return 0;
}
