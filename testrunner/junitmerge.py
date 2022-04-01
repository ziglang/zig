"""
simple scrpt for junitxml file merging
"""

from lxml.etree import parse, Element, tostring
from collections import defaultdict
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('--out')
parser.add_argument('path', nargs='...')

opts = parser.parse_args()

files = []

for path in opts.path:
    files.append(parse(path))


accum = defaultdict(int)
children = []

for item in files:
    root = item.getroot()
    for key, value in root.attrib.items():
        if not value:
            continue
        value = float(value) if '.' in value else int(value)
        accum[key] += value
    children.extend(root)




assert len(children) == sum(accum[x] for x in 'tests errors skips'.split())

children.sort(key=lambda x:(x.attrib['classname'], x.attrib['name']))



new = Element('testsuite', dict((k, str(v)) for k, v in accum.items()))
new.extend(children)

data = tostring(new)

with open(opts.out, 'w') as fp:
    fp.write(data)

