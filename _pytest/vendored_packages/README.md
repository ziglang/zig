This directory vendors the `pluggy` module.

For a more detailed discussion for the reasons to vendoring this 
package, please see [this issue](https://github.com/pytest-dev/pytest/issues/944).

To update the current version, execute:

```
$ pip install -U pluggy==<version> --no-compile --target=_pytest/vendored_packages
```

And commit the modified files. The `pluggy-<version>.dist-info` directory 
created by `pip` should be ignored.
