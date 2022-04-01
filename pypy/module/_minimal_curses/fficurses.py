""" The ffi for rpython
"""

from rpython.rtyper.lltypesystem import rffi, lltype
from rpython.rtyper.tool import rffi_platform
from rpython.translator.tool.cbuild import ExternalCompilationInfo

def try_cflags():
    yield ExternalCompilationInfo(includes=['curses.h', 'term.h'])
    yield ExternalCompilationInfo(includes=['curses.h', 'term.h'],
                                  include_dirs=['/usr/include/ncurses'])
    yield ExternalCompilationInfo(includes=['curses.h', 'term.h'],
                                  include_dirs=['/usr/include/ncursesw'])
    yield ExternalCompilationInfo(includes=['ncurses/curses.h',
                                            'ncurses/term.h'])

def try_ldflags():
    yield ExternalCompilationInfo(libraries=['curses', 'tinfo'])
    yield ExternalCompilationInfo(libraries=['curses'])
    yield ExternalCompilationInfo(libraries=['ncurses', 'tinfo'])
    yield ExternalCompilationInfo(libraries=['ncurses'])
    yield ExternalCompilationInfo(libraries=['ncurses'],
                                  library_dirs=['/usr/lib64'])
    yield ExternalCompilationInfo(libraries=['ncursesw'],
                                  library_dirs=['/usr/lib64'])

def try_tools():
    try:
        yield ExternalCompilationInfo.from_config_tool("ncursesw6-config")
    except Exception:
        pass
    try:
        yield ExternalCompilationInfo.from_config_tool("ncurses5-config")
    except Exception:
        pass
    try:
        yield ExternalCompilationInfo.from_pkg_config("ncursesw")
    except Exception:
        pass
    try:
        yield ExternalCompilationInfo.from_pkg_config("ncursesw")
    except Exception:
        pass

def try_eci():
    for eci in try_tools():
        yield eci.merge(ExternalCompilationInfo(includes=['curses.h',
                                                          'term.h']))
    for eci1 in try_cflags():
        for eci2 in try_ldflags():
            yield eci1.merge(eci2)

def guess_eci():
    for eci in try_eci():
        class CConfig:
            _compilation_info_ = eci
            HAS = rffi_platform.Has("setupterm")
        if rffi_platform.configure(CConfig)['HAS']:
            return eci
    raise ImportError("failed to guess where ncurses is installed. "
                      "You might need to install libncurses5-dev or similar.")

eci = guess_eci()


# We should not use this 'eci' directly because it causes the #include
# of term.h to appear in all generated C sources, and term.h contains a
# poisonous quantity of #defines for common lower-case names like
# 'buttons' or 'lines' (!!!).  It is basically dangerous to include
# term.h in any C source file that may contain unrelated source code.

include_lines = '\n'.join(['#include <%s>' % _incl for _incl in eci.includes])
eci = eci.copy_without('includes')


eci = eci.merge(ExternalCompilationInfo(
   post_include_bits=[
        "RPY_EXTERN int rpy_curses_setupterm(char *, int, int *);\n"
        "RPY_EXTERN char *rpy_curses_tigetstr(char *);\n"
        "RPY_EXTERN char *rpy_curses_tparm(char *, int, int, int, int,"
        " int, int, int, int, int);"
        ],
    separate_module_sources=["""

%(include_lines)s

RPY_EXTERN
int rpy_curses_setupterm(char *t, int fd, int *errret) {
    return setupterm(t, fd, errret);
}

RPY_EXTERN
char *rpy_curses_tigetstr(char *capname)
{
    char *res = tigetstr(capname);
    if (res == (char *)-1)
        res = NULL;
    return res;
}

RPY_EXTERN
char *rpy_curses_tparm(char *str, int x0, int x1, int x2, int x3,
                       int x4, int x5, int x6, int x7, int x8)
{
    return tparm(str, x0, x1, x2, x3, x4, x5, x6, x7, x8);
}

""" % globals()]))


setupterm = rffi.llexternal(
    "rpy_curses_setupterm", [rffi.CCHARP, rffi.INT, rffi.INTP],
                            rffi.INT, compilation_info=eci)

rpy_curses_tigetstr = rffi.llexternal(
    "rpy_curses_tigetstr", [rffi.CCHARP], rffi.CCHARP,
    compilation_info=eci)

rpy_curses_tparm = rffi.llexternal(
    "rpy_curses_tparm", [rffi.CCHARP, rffi.INT, rffi.INT, rffi.INT, rffi.INT,
                         rffi.INT, rffi.INT, rffi.INT, rffi.INT, rffi.INT],
    rffi.CCHARP,
    compilation_info=eci)
