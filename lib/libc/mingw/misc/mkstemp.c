#define _CRT_RAND_S
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <io.h>
#include <errno.h>
#include <share.h>
#include <fcntl.h>
#include <sys/stat.h>

/*
    The mkstemp() function generates a unique temporary filename from template,
    creates and opens the file, and returns an open file descriptor for the
    file.

    The template may be any file name with at least six trailing Xs, for example
    /tmp/temp.XXXXXXXX. The trailing Xs are replaced with a unique digit and
    letter combination that makes the file name unique. Since it will be
    modified, template must not be a string constant, but should be declared as
    a character array.

    The file is created with permissions 0600, that is, read plus write for
    owner only. The returned file descriptor provides both read and write access
    to the file.
 */
int __cdecl mkstemp (char *template_name)
{
    int i, j, fd, len, index;
    unsigned int r;

    /* These are the (62) characters used in temporary filenames. */
    static const char letters[] = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";

    /* The last six characters of template must be "XXXXXX" */
    if (template_name == NULL || (len = strlen (template_name)) < 6
            || memcmp (template_name + (len - 6), "XXXXXX", 6)) {
        errno = EINVAL;
        return -1;
    }

    /* User may supply more than six trailing Xs */
    for (index = len - 6; index > 0 && template_name[index - 1] == 'X'; index--);

    /*
        Like OpenBSD, mkstemp() will try at least 2 ** 31 combinations before
        giving up.
     */
    for (i = 0; i >= 0; i++) {
        for(j = index; j < len; j++) {
            if (rand_s(&r))
                r = rand();
            template_name[j] = letters[r % 62];
        }
        fd = _sopen(template_name,
                _O_RDWR | _O_CREAT | _O_EXCL | _O_BINARY,
                _SH_DENYNO, _S_IREAD | _S_IWRITE);
        if (fd != -1) return fd;
        if (fd == -1 && errno != EEXIST) return -1;
    }

    return -1;
}

#if 0
int main (int argc, char *argv[])
{
    int i, fd;

    for (i = 0; i < 10; i++) {
        char template_name[] = { "temp_XXXXXX" };
        fd = mkstemp (template_name);
        if (fd >= 0) {
            fprintf (stderr, "fd=%d, name=%s\n", fd, template_name);
            _close (fd);
        } else {
            fprintf (stderr, "errno=%d\n", errno);
        }
    }

    for (i = 0; i < 10; i++) {
        char template_name[] = { "temp_XXXXXXXX" };
        fd = mkstemp (template_name);
        if (fd >= 0) {
            fprintf (stderr, "fd=%d, name=%s\n", fd, template_name);
            _close (fd);
        } else {
            fprintf (stderr, "errno=%d\n", errno);
        }
    }

    return 0;
}
#endif
