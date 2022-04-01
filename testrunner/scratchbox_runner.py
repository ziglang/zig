
""" This is a very hackish runner for cross compilation toolchain scratchbox.
Later on we might come out with some general solution
"""

import os

def args_for_scratchbox(cwd, args):
    return ['/scratchbox/login', '-d', str(cwd)] + args

def run_scratchbox(args, cwd, out, timeout=None):
    return run(args_for_scratchbox(cwd, args), cwd, out, timeout)

def dry_run_scratchbox(args, cwd, out, timeout=None):
    return dry_run(args_for_scratchbox(cwd, args), cwd, out, timeout)

if __name__ == '__main__':
    import runner
    # XXX hack hack hack
    dry_run = runner.dry_run
    run = runner.run

    runner.dry_run = dry_run_scratchbox
    runner.run = run_scratchbox

    import sys
    runner.main(sys.argv)
