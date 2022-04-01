import os, sys
from rpython.tool.version import get_repo_version_info, _get_hg_archive_version

def test_hg_archival_version(tmpdir):
    def version_for(name, items):
        path = tmpdir.join(name)
        path.write('\n'.join(('%s: %s' % (tag,value) for tag,value in items)))
        return _get_hg_archive_version(str(path))

    assert version_for('release',
                       (('tag', 'release-123'),
                        ('tag', 'ignore-me'),
                        ('node', '000'),
                       ),
                      ) == ('release-123', '000')
    assert version_for('somebranch',
                       (('node', '000'),
                        ('branch', 'something'),
                       ),
                      ) == ('something', '000')


def test_get_repo_version_info():
    assert get_repo_version_info(None)
    assert get_repo_version_info(os.devnull) == ('?', '?')
    assert get_repo_version_info(sys.executable) == ('?', '?')
