#!/usr/bin/env pypy

# Post-process log files to make them diff-able.
#
# When you get errors caused by revdb.py getting out of sync with the
# original log file, recompile the program (e.g. pypy-c) by editing
# revdb_include.h, enabling the "#if 0" (at least the first one,
# possibly the second one too).  This prints locations to stderr of
# all the EMITs.  Then create the log file by redirecting stderr to
# "log.err1", and then run revdb.py by redirecting stderr to
# "log.err2" (typically, entering the "c" command to continue to the
# end).  Then diff them both after applying this filter:
#
#  diff -u <(cat log.err1 | .../rpython/translator/revdb/pplog.py)     \
#          <(cat log.err2 | .../rpython/translator/revdb/pplog.py) | less


import sys, re

r_hide_tail = re.compile(r"revdb[.]c:\d+: ([0-9a-f]+)")

r_remove = re.compile(r"\w+[.]c:\d+: obj 92233720368|"
                      r"PID \d+ starting, log file disabled|"
                      r"\[")


def post_process(fin, fout):
    for line in fin:
        match = r_hide_tail.match(line)
        if match:
            line = 'revdb.c:after pplog.py: %s\n' % ('#' * len(match.group(1)),)
        elif r_remove.match(line):
            continue
        fout.write(line)


if __name__ == '__main__':
    post_process(sys.stdin, sys.stdout)
