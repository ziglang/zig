(provide 'pypytrace-mode)
(eval-when-compile
  (require 'generic-x)
  (require 'hi-lock)
  (require 'compile)
  (require 'cus-edit))

(defun set-truncate-lines ()
  (setq truncate-lines t))

(defun pypytrace-beginning-of-defun ()
  (search-backward "{")
  (beginning-of-line))

(defun pypytrace-end-of-defun ()
  (search-forward "}")
  (end-of-line))


;; to generate the list of keywords:
;; from rpython.jit.metainterp import resoperation
;; print ' '.join(sorted('"%s"' % op.lower() for op in resoperation.opname.values() if not op.startswith('GUARD')))



(define-generic-mode 
  'pypytrace-mode                   ;; name of the mode to create
  nil
  '("arraylen_gc" "call" "call_assembler" "call_loopinvariant" "call_may_force" "call_pure" "call_release_gil" "cast_float_to_int" "cast_int_to_float" "cond_call_gc_wb" "copystrcontent" "copyunicodecontent" "debug_merge_point" "finish" "float_abs" "float_add" "float_eq" "float_ge" "float_gt" "float_le" "float_lt" "float_mul" "float_ne" "float_neg" "float_sub" "float_truediv" "force_token" "getarrayitem_gc" "getarrayitem_gc_pure" "getarrayitem_raw" "getfield_gc" "getfield_gc_pure" "getfield_raw" "getfield_raw_pure" "int_add" "int_add_ovf" "int_and" "int_eq" "int_floordiv" "int_ge" "int_gt" "int_invert" "int_is_true" "int_is_zero" "int_le" "int_lshift" "int_lt" "int_mod" "int_mul" "int_mul_ovf" "int_ne" "int_neg" "int_or" "int_rshift" "int_sub" "int_sub_ovf" "int_xor" "jit_debug" "jump" "new" "new_array" "new_with_vtable" "newstr" "newunicode" "ptr_eq" "ptr_ne" "quasiimmut_field" "read_timestamp" "same_as" "setarrayitem_gc" "setarrayitem_raw" "setfield_gc" "setfield_raw" "strgetitem" "strlen" "strsetitem" "uint_floordiv" "uint_ge" "uint_gt" "uint_le" "uint_lt" "uint_rshift" "unicodegetitem" "unicodelen" "unicodesetitem" "virtual_ref" "virtual_ref_finish") ;; keywords
  '( ;; additional regexps
    ("^# Loop.*" . 'hi-blue)
    ("\\[.*\\]" . 'font-lock-comment-face) ;; comment out argument lists
    ("guard_[a-z_]*" . 'widget-button-pressed)
    ("\\(ptr\\|p\\)[0-9][0-9]*" . 'font-lock-variable-name-face)
    ("i[0-9][0-9]*" . 'custom-button-pressed-unraised)
    ("\\(descr=<.*FieldDescr \\)\\([^ ]*\\.\\)\\([^ ]*\\)\\( .*>\\)"
     (1 'font-lock-comment-face)
     (2 'font-lock-variable-name-face)
     (3 'escape-glyph)
     (4 'font-lock-comment-face))
    ("<.*FieldDescr \\([^ ]*\\)" (1 'font-lock-variable-name-face))
    ;; comment out debug_merge_point, but then highlight specific part of it
    ("^debug_merge_point.*" . font-lock-comment-face)
    ("^\\(debug_merge_point\\).*code object\\(.*\\). file \\('.*'\\). \\(line .*\\)> \\(.*\\)"
     (1 'compilation-warning t)
     (2 'escape-glyph t)
     (3 'font-lock-string-face t)
     (4 'escape-glyph t)
     (5 'custom-variable-tag t)))
  '("\\.trace$")
  '(set-truncate-lines
    (lambda ()
      (set (make-local-variable 'beginning-of-defun-function)
           'pypytrace-beginning-of-defun)
      (set (make-local-variable 'end-of-defun-function) 'pypytrace-end-of-defun))
    )
  "A mode for pypy traces files")

;; debug helpers
;; (switch-to-buffer-other-window "strslice2.trace")
;; (pypytrace-mode)

