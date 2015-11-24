/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "os.hpp"
#include "util.hpp"

#include <unistd.h>
#include <errno.h>

void os_spawn_process(const char *exe, ZigList<const char *> &args, bool detached) {
    pid_t pid = fork();
    if (pid == -1)
        zig_panic("fork failed");
    if (pid != 0)
        return;
    if (detached) {
        if (setsid() == -1)
            zig_panic("process detach failed");
    }

    const char **argv = allocate<const char *>(args.length + 2);
    argv[0] = exe;
    argv[args.length + 1] = nullptr;
    for (int i = 0; i < args.length; i += 1) {
        argv[i + 1] = args.at(i);
    }
    execvp(exe, const_cast<char * const *>(argv));
    zig_panic("execvp failed: %s", strerror(errno));
}
