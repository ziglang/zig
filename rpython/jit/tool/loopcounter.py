#!/usr/bin/env python
"""
Parse and display the traces produced by pypy-c-jit when PYPYLOG is set.
"""

import sys
import optparse
import re

def get_timestamp(line):
    match = re.match(r'\[([0-9a-f]*)\] .*', line)
    return int(match.group(1), 16)

def count_loops_and_bridges(log):
    loops = 0
    bridges = 0
    time0 = None
    lines = iter(log)
    for line in lines:
        if time0 is None and line.startswith('['):
            time0 = get_timestamp(line)
        if '{jit-mem-looptoken-' in line:
            time_now = get_timestamp(line) - time0
            text = lines.next()
            if text.startswith('allocating Loop #'):
                loops += 1
            elif text.startswith('allocating Bridge #'):
                bridges += 1
            elif text.startswith('freeing Loop #'):
                match = re.match('freeing Loop # .* with ([0-9]*) attached bridges\n', text)
                loops -=1
                bridges -= int(match.group(1))
            else:
                assert False, 'unknown line' % line
            total = loops+bridges
            yield (time_now, total, loops, bridges)

def main(logfile, options):
    print 'timestamp,total,loops,bridges'
    log = open(logfile)
    for timestamp, total, loops, bridges in count_loops_and_bridges(log):
        print '%d,%d,%d,%d' % (timestamp, total, loops, bridges)        

if __name__ == '__main__':
    parser = optparse.OptionParser(usage="%prog loopfile [options]")
    options, args = parser.parse_args()
    if len(args) != 1:
        parser.print_help()
        sys.exit(2)
    main(args[0], options)
