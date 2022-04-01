"""
For branches that have been closed but still have a dangling head
in 'hg heads --topo --closed', force them to join with the branch
called 'closed-branch'.  It reduces the number of heads.
"""

import os
import sys
import commands

if not os.path.isdir('.hg'):
    print 'Must run this script from the top-level directory.'
    sys.exit(1)

def heads():
    result = commands.getoutput(
        "hg heads --topo --closed --template '{node|short}:{branches}:{extras}\n'")
    result = result.splitlines(False)
    result = [s.split(':', 2) for s in result]
    for line in result:
        if len(line) != 3:
            raise ValueError("'result' contains: %r" % line)
    result = [(head, branch or 'default') for (head, branch, extra) in result
                if branch != 'closed-branches' and 'close=1' in extra]
    return result


closed_heads = heads()

if not closed_heads:
    print >> sys.stderr, 'no dangling closed heads.'
    sys.exit()

# ____________________________________________________________

closed_heads.reverse()

for head, branch in closed_heads:
    print '\t', head, '\t', branch
print
print 'The %d branches listed above will be merged to "closed-branches".' % (
    len(closed_heads),)
print 'You need to run this script in a clean working copy where you'
print 'don''t mind all files being removed.'
print
if raw_input('Continue? [y/n] ').upper() != 'Y':
    sys.exit(1)

# ____________________________________________________________

def do(cmd):
    print cmd
    err = os.system(cmd)
    if err != 0:
        print '*** error %r' % (err,)
        sys.exit(1)

print '*** switching to closed branches *** '
do("hg up --clean closed-branches")
do("hg --config extensions.purge= purge --all")

for head, branch in closed_heads:
    print
    print '***** %s ***** %s *****' % (branch, head)
    do("hg debugsetparents closed-branches %s" % head)
    do("hg ci -m'Merge closed head %s on branch %s'" % (head, branch))

print
do("hg ci --close-branch -m're-close this branch'")
do("hg up default")
