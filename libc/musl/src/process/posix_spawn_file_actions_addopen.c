#include <spawn.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include "fdop.h"

int posix_spawn_file_actions_addopen(posix_spawn_file_actions_t *restrict fa, int fd, const char *restrict path, int flags, mode_t mode)
{
	struct fdop *op = malloc(sizeof *op + strlen(path) + 1);
	if (!op) return ENOMEM;
	op->cmd = FDOP_OPEN;
	op->fd = fd;
	op->oflag = flags;
	op->mode = mode;
	strcpy(op->path, path);
	if ((op->next = fa->__actions)) op->next->prev = op;
	op->prev = 0;
	fa->__actions = op;
	return 0;
}
