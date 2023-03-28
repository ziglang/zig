glibc headers are slightly patched for backwards compatibility. This is not
good, because it requires to maintain our patchset whlist upgrading glibc.

Until universal headers are real and this file can be removed, these commits
need to be cherry-picked in the future glibc header upgrades:

- 39083c31a550ed80f369f60d35791e98904b8096
- a89813ef282c092a9caf699731c7faaf485acabe
