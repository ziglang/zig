#include <spawn.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include "fdop.h"

int posix_spawn_file_actions_addfchdir_np(posix_spawn_file_actions_t *fa, int fd)
{
	if (fd < 0) return EBADF;
	struct fdop *op = malloc(sizeof *op);
	if (!op) return ENOMEM;
	op->cmd = FDOP_FCHDIR;
	op->fd = fd;
	if ((op->next = fa->__actions)) op->next->prev = op;
	op->prev = 0;
	fa->__actions = op;
	return 0;
}
