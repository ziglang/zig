This directory contains HPy tests. They are mainly divided into two
categories:

  - support: the testfiles in this directory are usually run at interp-level
    and check the behavior of various support/utility functions

  - vendored: the tests inside test/_vendored are copied unmodified from the
    main HPy repo, and are automatically converted to AppTest by the
    conftest. If you want to customize/skip these tests, read the comments
    inside conftest.py
