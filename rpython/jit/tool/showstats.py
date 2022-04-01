#!/usr/bin/env python
from __future__ import division

import sys
from rpython.tool import logparser
from rpython.jit.tool.oparser import parse
from rpython.jit.metainterp.resoperation import rop

def main(argv):
    log = logparser.parse_log_file(argv[0])
    parts = logparser.extract_category(log, "jit-log-opt-")
    for i, oplist in enumerate(parts):
        loop = parse(oplist, no_namespace=True, nonstrict=True)
        num_ops = 0
        num_dmp = 0
        num_guards = 0
        for op in loop.operations:
            if op.getopnum() == rop.DEBUG_MERGE_POINT:
                num_dmp += 1
            else:
                num_ops += 1
            if op.is_guard():
                num_guards += 1
        if num_dmp == 0:
            print "Loop #%d, length: %d, opcodes: %d, guards: %d" % (i, num_ops, num_dmp, num_guards)
        else:
            print "Loop #%d, length: %d, opcodes: %d, guards: %d, %f" % (i, num_ops, num_dmp, num_guards, num_ops/num_dmp)

if __name__ == '__main__':
    main(sys.argv[1:])
