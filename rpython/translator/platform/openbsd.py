"""Support for OpenBSD."""

import os

from rpython.translator.platform.bsd import BSD

class OpenBSD(BSD):
    DEFAULT_CC = "cc"
    name = "openbsd"

    link_flags = os.environ.get("LDFLAGS", "").split() + ['-pthread']
    cflags = ['-O3', '-pthread', '-fomit-frame-pointer', '-D_BSD_SOURCE'
             ] + os.environ.get("CFLAGS", "").split()

    def _libs(self, libraries):
        libraries=set(libraries + ("intl", "iconv"))
        return ['-l%s' % lib for lib in libraries if lib not in ["crypt", "dl", "rt"]]

    def makefile_link_flags(self):
        # On OpenBSD, we need to build the final binary with the link flags
        # below. However, if we modify self.link_flags to include these, the
        # various platform check binaries that RPython builds end up with these
        # flags: since these binaries are generally located on /tmp -- which
        # isn't a wxallowed file system -- that gives rise to "permission
        # denied" errors, which kill the build.
        return list(self.link_flags) + ["-Wl,-z,wxneeded"]

class OpenBSD_64(OpenBSD):
    shared_only = ('-fPIC',)
