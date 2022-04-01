#!/usr/bin/env python
""" Convert logfile (from jit-log-opt and jit-backend) to json format.
Usage:

logparser2json.py <logfile.log> <outfile.json>
"""

import os
import sys
import json
from rpython.tool.jitlogparser.parser import import_log, parse_log_counts
from rpython.tool.logparser import extract_category
from rpython.tool.jitlogparser.storage import LoopStorage

def mangle_descr(descr):
    if descr.startswith('TargetToken('):
        return descr[len('TargetToken('):-1]
    if descr.startswith('<Guard'):
        return 'bridge-' + str(int(descr[len('<Guard0x'):-1], 16))
    if descr.startswith('<Loop'):
        return 'entry-' + descr[len('<Loop'):-1]
    return descr.replace(" ", '-')

def create_loop_dict(loops):
    d = {}
    for loop in loops:
        d[mangle_descr(loop.descr)] = loop
    return d

def main(progname, logfilename, outfilename):
    storage = LoopStorage(extrapath=os.path.dirname(progname))
    log, loops = import_log(logfilename)
    parse_log_counts(extract_category(log, 'jit-backend-count'), loops)
    storage.loops = [loop for loop in loops
                     if not loop.descr.startswith('bridge')]
    storage.loop_dict = create_loop_dict(loops)
    json.dump([loop.force_asm().as_json() for loop in storage.loops],
              open(outfilename, "w"), indent=4)

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print __doc__
        sys.exit(1)
    main(sys.argv[0], sys.argv[1], sys.argv[2])
