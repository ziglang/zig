#include <spawn.h>

int posix_spawn_file_actions_init(posix_spawn_file_actions_t *fa)
{
	fa->__actions = 0;
	return 0;
}
