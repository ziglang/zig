from lxml.etree import parse
from collections import defaultdict
from os.path import join, exists
import argparse
parser = argparse.ArgumentParser()
parser.add_argument('junitxml')
parser.add_argument('fileroot')

opts = parser.parse_args()

xml = parse(opts.junitxml)
root = xml.getroot()


bugstarts = 'interpreter', 'tool', 'module'
def findfile(root, classname):
    if not classname:
        return
    parts = classname.split('.')
    
    #pytest bug workaround
    first = parts[0]
    for start in bugstarts:
        if first.startswith(start) and \
           first != start and \
           first[len(start)] != '.':
            parts[0] = start
            parts.insert(1, 'py'+first[len(start):])

    while parts:
        path = join(root, *parts) + '.py'
        if exists(path):
            return join(*parts) + '.py'
        parts.pop()

accum = defaultdict(list)
garbageitems = []

for item in root:
    filename = findfile(opts.fileroot, item.attrib['classname'])
    accum[filename].append(float(item.attrib['time']))
    if filename is None:
        garbageitems.append(item)




garbage = accum.pop(None, [])
if garbage:
    print 'garbage', sum(garbage), len(garbage)

for key in sorted(accum):
    value = accum[key]
    print key, sum(value), len(value)

print '-'*30

for item in garbageitems:
    print item.attrib
