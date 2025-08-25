#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <spawn.h>
#include "stdio_impl.h"
#include "syscall.h"

extern char **__environ;

FILE *popen(const char *cmd, const char *mode)
{
	int p[2], op, e;
	pid_t pid;
	FILE *f;
	posix_spawn_file_actions_t fa;

	if (*mode == 'r') {
		op = 0;
	} else if (*mode == 'w') {
		op = 1;
	} else {
		errno = EINVAL;
		return 0;
	}
	
	if (pipe2(p, O_CLOEXEC)) return NULL;
	f = fdopen(p[op], mode);
	if (!f) {
		__syscall(SYS_close, p[0]);
		__syscall(SYS_close, p[1]);
		return NULL;
	}

	e = ENOMEM;
	if (!posix_spawn_file_actions_init(&fa)) {
		for (FILE *l = *__ofl_lock(); l; l=l->next)
			if (l->pipe_pid && posix_spawn_file_actions_addclose(&fa, l->fd))
				goto fail;
		if (!posix_spawn_file_actions_adddup2(&fa, p[1-op], 1-op)) {
			if (!(e = posix_spawn(&pid, "/bin/sh", &fa, 0,
			    (char *[]){ "sh", "-c", (char *)cmd, 0 }, __environ))) {
				posix_spawn_file_actions_destroy(&fa);
				f->pipe_pid = pid;
				if (!strchr(mode, 'e'))
					fcntl(p[op], F_SETFD, 0);
				__syscall(SYS_close, p[1-op]);
				__ofl_unlock();
				return f;
			}
		}
fail:
		__ofl_unlock();
		posix_spawn_file_actions_destroy(&fa);
	}
	fclose(f);
	__syscall(SYS_close, p[1-op]);

	errno = e;
	return 0;
}
