#!/usr/bin/env python
"""
Parse and display the traces produced by pypy-c-jit when PYPYLOG is set.
"""

import sys
import optparse
from rpython.tool import logparser
from rpython.jit.tool.oparser import parse

def main(loopfile, options):
    print 'Loading file:'
    log = logparser.parse_log_file(loopfile)
    loops, summary = consider_category(log, options, "jit-log-opt-")
    if not options.quiet:
        for loop in loops:
            loop.show()

    if options.summary:
        print
        print 'Summary:'
        print_summary(summary)

    if options.diff:
        # non-optimized loops and summary
        nloops, nsummary = consider_category(log, options, "jit-log-noopt-")
        print
        print 'Summary of optimized-away operations'
        print
        diff = {}
        keys = set(summary.keys()).union(set(nsummary))
        for key in keys:
            before = nsummary.get(key, 0)
            after = summary.get(key, 0)
            diff[key] = (before-after, before, after)
        print_diff(diff)

def consider_category(log, options, category):
    loops = logparser.extract_category(log, category)
    if options.loopnum is None:
        input_loops = loops
    else:
        input_loops = [loops[options.loopnum]]
    loops = [parse(inp, no_namespace=True, nonstrict=True)
             for inp in input_loops]
    summary = {}
    for loop in loops:
        summary = loop.summary(summary)
    return loops, summary
        

def print_summary(summary):
    ops = [(summary[key], key) for key in summary]
    ops.sort(reverse=True)
    for n, key in ops:
        print '%5d' % n, key

def print_diff(diff):
    ops = [(d, before, after, key) for key, (d, before, after) in diff.iteritems()]
    ops.sort(reverse=True)
    tot_before = 0
    tot_after = 0
    for d, before, after, key in ops:
        tot_before += before
        tot_after += after
        print '%5d - %5d = %5d     ' % (before, after, d), key
    print '-' * 50
    print '%5d - %5d = %5d     ' % (tot_before, tot_after, tot_before-tot_after), 'TOTAL'

if __name__ == '__main__':
    parser = optparse.OptionParser(usage="%prog loopfile [options]")
    parser.add_option('-n', '--loopnum', dest='loopnum', default=-1, metavar='N', type=int,
                      help='show the loop number N [default: last]')
    parser.add_option('-a', '--all', dest='loopnum', action='store_const', const=None,
                      help='show all loops in the file')
    parser.add_option('-s', '--summary', dest='summary', action='store_true', default=False,
                      help='print a summary of the operations in the loop(s)')
    parser.add_option('-d', '--diff', dest='diff', action='store_true', default=False,
                      help='print the difference between non-optimized and optimized operations in the loop(s)')
    parser.add_option('-q', '--quiet', dest='quiet', action='store_true', default=False,
                      help='do not show the graphical representation of the loop')
    
    options, args = parser.parse_args()
    if len(args) != 1:
        parser.print_help()
        sys.exit(2)

    main(args[0], options)
