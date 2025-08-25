#include <unistd.h>
#include <stdarg.h>

int execle(const char *path, const char *argv0, ...)
{
	int argc;
	va_list ap;
	va_start(ap, argv0);
	for (argc=1; va_arg(ap, const char *); argc++);
	va_end(ap);
	{
		int i;
		char *argv[argc+1];
		char **envp;
		va_start(ap, argv0);
		argv[0] = (char *)argv0;
		for (i=1; i<=argc; i++)
			argv[i] = va_arg(ap, char *);
		envp = va_arg(ap, char **);
		va_end(ap);
		return execve(path, argv, envp);
	}
}
