#!/usr/bin/env python3

"""
Verify the versions.json file that describes the valid downloads.
- all the files should be valid
- the other fields should have valid values
- the pypy_version should be in the repo tags

By default will download https://buildbot.pypy.org/pypy/versions.json parse it, and
check against the files in https://downloads.python.org/pypy/
Can be run as check_versions.py <filename>, in which case it will check the files in
https://buildbot.pypy.org/pypy/
"""

import json
from urllib import request, error
import sys


def assert_equal(a, b):
    if a != b:
        raise ValueError(f"'{a}' != '{b}'")


def assert_different(a, b):
    if a == b:
        raise ValueError(f"'{a}' == '{b}'")


def assert_in(a, b):
    if a not in b:
        raise ValueError(f"'{a}' not in '{b}'")


pypy_versions = {
                 '7.3.8': {'python_version': ['3.9.10', '3.8.12', '3.7.12', '2.7.18'],
                           'date': '2022-02-19',
                          },
                 '7.3.8rc2': {'python_version': ['3.9.10', '3.8.12', '3.7.12', '2.7.18'],
                           'date': '2022-02-11',
                          },
                 '7.3.8rc1': {'python_version': ['3.9.10', '3.8.12', '3.7.12', '2.7.18'],
                           'date': '2022-01-26',
                          },
                 '7.3.7': {'python_version': ['3.8.12', '3.7.12'],
                           'date': '2021-10-25',
                          },
                 '7.3.6': {'python_version': ['3.8.12', '3.7.12', '2.7.18'],
                           'date': '2021-10-17',
                          },
                 '7.3.6rc3': {'python_version': ['3.8.12', '3.7.12', '2.7.18'],
                           'date': '2021-10-12',
                          },
                 '7.3.6rc2': {'python_version': ['3.8.12', '3.7.12', '2.7.18'],
                           'date': '2021-10-06',
                          },
                 '7.3.6rc1': {'python_version': ['3.8.12', '3.7.12', '2.7.18'],
                           'date': '2021-09-13',
                          },
                 '7.3.5': {'python_version': ['3.7.10', '2.7.18'],
                           'date': '2021-05-23',
                          },
                 '7.3.5rc3': {'python_version': ['3.7.10', '2.7.18'],
                           'date': '2021-05-19',
                          },
                 '7.3.5rc2': {'python_version': ['3.7.10', '2.7.18'],
                           'date': '2021-05-05',
                          },
                 '7.3.5rc1': {'python_version': ['3.7.10', '2.7.18'],
                           'date': '2021-05-02',
                          },
                 '7.3.4': {'python_version': ['3.7.10', '2.7.18'],
                           'date': '2021-04-08',
                          },
                 '7.3.4rc2': {'python_version': ['3.7.10', '2.7.18'],
                           'date': '2021-04-04',
                          },
                 '7.3.4rc1': {'python_version': ['3.7.10', '2.7.18'],
                           'date': '2021-03-19',
                          },
                 '7.3.3': {'python_version': ['3.7.9', '3.6.12', '2.7.18'],
                           'date': '2020-11-21',
                          },
                 '7.3.3rc1': {'python_version': ['3.6.12'],
                           'date': '2020-11-11',
                          },
                 '7.3.2': {'python_version': ['3.7.9', '3.6.9', '2.7.13'],
                           'date': '2020-09-25',
                          },
                'nightly': {'python_version': ['2.7', '3.6', '3.7', '3.8', '3.9']},
                }


def create_latest_versions(v):
    """Create a dictionary with key of cpython_version and value of the latest
    pypy version for that cpython"""
    ret = {}
    for pypy_ver, vv in v.items():
        if 'rc' in pypy_ver:
            # skip release candidates
            continue
        for pv in vv['python_version']:
            # for nightlies, we rely on python_version being major.minor while
            # for releases python_version is major.minor.patch
            if pv not in ret or (
                    vv['date'] > v[ret[pv]]['date']):
                ret[pv] = pypy_ver
    return ret


latest_pypys = create_latest_versions(pypy_versions)

arches = ['aarch64', 'i686', 'x64', 'x86', 'darwin', 's390x']
platforms = ['linux', 'win32', 'win64', 'darwin']
arch_map={('aarch64', 'linux'): 'aarch64',
          ('i686', 'linux'): 'linux32',
          ('x64', 'linux'): 'linux64',
          ('s390x', 'linux'): 's390x',
          ('x86', 'win32'): 'win32',
          ('x64', 'win64'): 'win64',
          ('x64', 'darwin'): 'osx64',
         }


def check_versions(data, url, verbose=0):
    for d in data:
        if verbose > 0:
            print(f"checking {d['pypy_version']} {d['python_version']}")
        assert_in(d['pypy_version'], pypy_versions)
        v = pypy_versions[d['pypy_version']]
        assert_in(d['python_version'], v['python_version'])
        if ('rc' in d['pypy_version'] or 'nightly' in d['pypy_version']):
            assert d['stable'] is False
        else:
            assert d['stable'] is True
        if d['pypy_version'] == 'nightly':
            assert d['latest_pypy'] is False
        elif d['latest_pypy'] is True:
            assert_equal(latest_pypys[d['python_version']], d['pypy_version'])
        else:
            try:
                assert_different(latest_pypys[d['python_version']], d['pypy_version'])
            except KeyError:
                assert 'rc' in d['pypy_version']
        if 'date' in d:
            assert_equal(d['date'], v['date'])
        for f in d['files']:
            download_url = f['download_url']
            if verbose > 0:
                print(f'     checking {download_url}', end='')
            if 'rc' not in d['pypy_version']:
                assert_in(f['filename'], download_url)
                assert_in(d['pypy_version'], download_url)
            assert_in(f['arch'], arches)
            assert_in(f['platform'], platforms)
            arch_plat = arch_map[(f['arch'], f['platform'])]
            if d['pypy_version'] == 'nightly':
                if arch_plat == 'linux32':
                    # the nightly builds have a quirk in the linux32 file name
                    arch_plat = 'linux'
                assert_in(arch_plat, download_url)
            else:
                assert_in(arch_plat, download_url)
                assert_in('.'.join(d['python_version'].split('.')[:2]), download_url)
                if url:
                    download_url = '/'.join((url, download_url.rsplit('/', 1)[1]))
            try:
                r = request.urlopen(download_url)
            except error.HTTPError as e:
                raise ValueError(f"could not open {f['download_url']}") from None
            assert_equal(r.getcode(), 200)
            if verbose > 0:
                print(f' ok')
        if verbose > 0:
            print(f"{d['pypy_version']} {d['python_version']} ok")

if __name__ == '__main__':
    if len(sys.argv) > 1:
        print(f'checking local file "{sys.argv[1]}"')
        with open(sys.argv[1]) as fid:
            data = json.loads(fid.read())
        check_versions(data, 'https://buildbot.pypy.org/pypy', verbose=1)
    else:
        print('downloading versions.json')
        response = request.urlopen('https://buildbot.pypy.org/pypy/versions.json')
        assert_equal(response.getcode(), 200)
        data = json.loads(response.read())
        check_versions(data, None, verbose=1)
    print('ok')
