(in-package #:derecho)

;; You can define these before `defsystem` in your .asd file via `defparameter`:
;;   `cl-user::*derecho-response-buffer-size*` -> number of bytes that a response buffer gets allocated per request
;;                                                default: 8192
;;   `cl-user::*derecho-ssl-cipher-name*` -> OpenSSL cipher name to use in HTTPS requests
;;                                           default: "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:CHACHA20-POLY1305-SHA256"
;;   `cl-user::*derecho-ssl-ctx-opts-mask*` -> OpenSSL context options bitmask
;;                                             default: "#x20000" (only `SSL_OP_NO_COMPRESSION` is set)

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defparameter *response-buffer-size*
    (let ((user-supplied-val (find-symbol "*DERECHO-RESPONSE-BUFFER-SIZE*" :cl-user)))
      (if (and user-supplied-val
               (boundp user-supplied-val))
        (symbol-value user-supplied-val)
        8192))))
(defmacro +RESPONSE_BUFFER_SIZE+ ()
  *response-buffer-size*)

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defparameter *ssl-cipher-name*
    (let ((user-supplied-val (find-symbol "*DERECHO-SSL-CIPHER-NAME*" :cl-user)))
      (if (and user-supplied-val
               (boundp user-supplied-val))
        (symbol-value user-supplied-val)
        "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:CHACHA20-POLY1305-SHA256"))))
(defmacro +SSL_CIPHER_NAME+ ()
  *ssl-cipher-name*)

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defparameter *ssl-ctx-opts-mask*
    (let ((user-supplied-val (find-symbol "*DERECHO-SSL-CTX-OPTS-MASK*" :cl-user)))
      (if (and user-supplied-val
               (boundp user-supplied-val))
        (symbol-value user-supplied-val)
        #x20000))))
(defmacro +SSL_CTX_OPTS_MASK+ ()
  *ssl-ctx-opts-mask*)
