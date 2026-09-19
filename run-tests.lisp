(require :uiop)
(require :asdf)
(load "~/quicklisp/setup.lisp")

;; TODO: benchmark against Carrier and Dexador on single threaded performance

(let ((cur-dir-path (uiop:pathname-directory-pathname *load-truename*)))
  (push cur-dir-path asdf:*central-registry*)
  (ql:quickload :derecho)
  ;; (asdf:load-system :derecho)
  (load (uiop:subpathname cur-dir-path "test/test-util.lisp"))

  (load (uiop:subpathname cur-dir-path "test/tests/general-util.lisp"))
  (load (uiop:subpathname cur-dir-path "test/tests/get-http.lisp")))
