(in-package #:derecho)

;; You can define these before `defsystem` in your .asd file via `defparameter`:
;;   `cl-user::*derecho-response-buffer-size*` -> number of bytes that a response buffer gets allocated per request

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defparameter *response-buffer-size*
    (let ((user-supplied-val (find-symbol "*DERECHO-RESPONSE-BUFFER-SIZE*" :cl-user)))
      (if (and user-supplied-val
               (boundp user-supplied-val))
        (symbol-value user-supplied-val)
        8192))))
(defmacro +RESPONSE_BUFFER_SIZE+ ()
  *response-buffer-size*)
