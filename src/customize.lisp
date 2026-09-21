(in-package #:derecho)

;; You can define these before `defsystem` in your .asd file via `defparameter`:
;;   `cl-user::*derecho-response-buffer-size*` -> number of bytes that a response buffer gets allocated per request
;;                                                default: 8192
;;   `cl-user::*derecho-ssl-cipher-name*` -> OpenSSL cipher name to use in HTTPS requests
;;                                           default: "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:CHACHA20-POLY1305-SHA256"
;;   `cl-user::*derecho-ssl-ctx-opts-mask*` -> OpenSSL context options bitmask
;;                                             default: "#x20000" (only `SSL_OP_NO_COMPRESSION` is set)

(defmacro defcustom (public-sym-str src-macro-sym-name internal-src-sym-name default-value)
  `(progn
     (eval-when (:compile-toplevel :load-toplevel :execute)
       (defparameter ,internal-src-sym-name
         (let ((user-supplied-val (find-symbol ,public-sym-str :cl-user)))
           (if (and user-supplied-val
                    (boundp user-supplied-val))
             (symbol-value user-supplied-val)
             ,default-value))))
     (defmacro ,src-macro-sym-name ()
       ,internal-src-sym-name))
)

(defcustom "*DERECHO-RESPONSE-BUFFER-SIZE*" +RESPONSE_BUFFER_SIZE+ *response-buffer-size*
           8192)

(defcustom "*DERECHO-SSL-CIPHER-NAME*" +SSL_CIPHER_NAME+ *ssl-cipher-name*
           "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:CHACHA20-POLY1305-SHA256")

(defcustom "*DERECHO-SSL-CTX-OPTS-MASK*" +SSL_CTX_OPTS_MASK+ *ssl-ctx-opts-mask*
           #x20000)
