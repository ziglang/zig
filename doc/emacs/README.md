To use this emacs syntax file, add this to your emacs configuration file:

```emacs
(add-to-list 'load-path "/path/to/zig/doc/emacs/")
(autoload 'zig-mode "zig-mode" nil t)
(add-to-list 'auto-mode-alist '("\\.zig\\'" . zig-mode))
```
