(require :uiop)
(require :asdf)
(load "~/quicklisp/setup.lisp")

;; TODO: benchmark against Carrier and Dexador on single threaded performance

(let ((cur-dir-path (uiop:pathname-directory-pathname *load-truename*)))
  (push cur-dir-path asdf:*central-registry*)

  (defparameter cl-user::*derecho-response-buffer-size* 4096)

  (ql:quickload :derecho)
  ;; (asdf:load-system :derecho)
  (load (uiop:subpathname cur-dir-path "test/test-util.lisp"))

  (load (uiop:subpathname cur-dir-path "test/tests/general-util.lisp"))
  (load (uiop:subpathname cur-dir-path "test/tests/get-http.lisp"))

  (cond
    ((not (boundp '*failed-test-names*))
      (format t "~&Couldn't retrieve *failed-test-names*~%"))
    ((null (symbol-value '*failed-test-names*))
      (format t "~&[32mall passed[0m~%"))
    (t
      (format t "~&[31mSOME FAILED[0m: ~A~%" (symbol-value '*failed-test-names*)))))
