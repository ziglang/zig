#! /usr/bin/env python
"""
Usage: memusage.py [-o filename] command [args...]

Runs a subprocess, and measure its RSS (resident set size) every second.
At the end, print the maximum RSS measured, and some statistics.

Also writes "filename", reporting every second the RSS.  If filename is not
given, the output is written to "memusage.log"
"""

import sys, os, re, time

def parse_args():
    args = sys.argv[1:]
    if args[0] == '-o':
        args.pop(0)
        outname = args.pop(0)
    else:
        outname = 'memusage.log'
    args[0] # make sure there is at least one argument left
    return outname, args

try:
    outname, args = parse_args()
except IndexError:
    print >> sys.stderr, __doc__.strip()
    sys.exit(2)

childpid = os.fork()
if childpid == 0:
    os.execvp(args[0], args)
    sys.exit(1)

r = re.compile("VmRSS:\s*(\d+)")

filename = '/proc/%d/status' % childpid
rss_max = 0
rss_sum = 0
rss_count = 0

f = open(outname, 'w', 0)
while os.waitpid(childpid, os.WNOHANG)[0] == 0:
    g = open(filename)
    s = g.read()
    g.close()
    match = r.search(s)
    if not match:     # VmRSS is missing if the process just finished
        break
    rss = int(match.group(1))
    print >> f, rss
    if rss > rss_max: rss_max = rss
    rss_sum += rss
    rss_count += 1
    time.sleep(1)
f.close()

if rss_count > 0:
    print
    print 'Memory usage:'
    print '\tmaximum RSS: %10d kb' % rss_max
    print '\tmean RSS:    %10d kb' % (rss_sum / rss_count)
    print '\trun time:    %10d s' % rss_count
