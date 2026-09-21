(in-package #:derecho)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; socket stuff
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(cffi:defcfun ("recv" --recv) :ssize
  (fd :int) (buf :pointer) (len :size) (flags :int))

(cffi:defcfun ("send" --send) :ssize
  (fd :int) (buf :pointer) (len :size) (flags :int))

(cffi:defcfun ("close" --close) :int
  (fd :int))

(cffi:defcfun ("fcntl" --fcntl) :int
  (fd :int) (cmd :int) (arg :int))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ssl stuff
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(cffi:define-foreign-library libcrypto
  (:unix (:or "libcrypto.so.3" "libcrypto.so.1.1" "libcrypto.so"))
  (:darwin (:or "libcrypto.dylib" "libcrypto.3.dylib"))
  (t (:default "libcrypto")))
(cffi:use-foreign-library libcrypto)

(cffi:define-foreign-library libssl
  (:unix (:or "libssl.so.3" "libssl.so.1.1" "libssl.so"))
  (:darwin (:or "libssl.dylib" "libssl.3.dylib"))
  (t (:default "libssl")))
(cffi:use-foreign-library libssl)

(cffi:defcfun ("SSL_write" --ssl-write) :int
  (ssl :pointer) (buf :pointer) (num :int))

(cffi:defcfun ("SSL_read" --ssl-read) :int
  (ssl :pointer) (buf :pointer) (num :int))

(cffi:defcfun ("SSL_shutdown" --ssl-shutdown) :int
  (ssl :pointer))

(cffi:defcfun ("SSL_free" --ssl-free) :void
  (ssl :pointer))

(cffi:defcfun ("SSL_get_error" --ssl-get-error) :int
  (ssl :pointer) (ret :int))

(cffi:defcfun ("TLS_method" --tls-method) :pointer)

(cffi:defcfun ("SSL_CTX_new" --ssl-ctx-new) :pointer
  (method :pointer))

(cffi:defcfun ("SSL_new" --ssl-new) :pointer
  (ssl-ctx :pointer))

(cffi:defcfun ("SSL_set_fd" --ssl-set-fd) :int
  (ssl :pointer) (fd :int))

(cffi:defcfun ("SSL_ctrl" --ssl-ctrl) :long
  (ssl :pointer) (cmd :int) (larg :long) (parg :pointer))

(cffi:defcfun ("SSL_connect" --ssl-connect) :int
  (ssl :pointer))

(cffi:defcfun ("SSL_CTX_set_cipher_list" --ssl-ctx-set-cipher-list) :int
  (ssl-ctx :pointer) (str :string))

(cffi:defcfun ("SSL_CTX_set_options" --ssl-ctx-set-options) :unsigned-long
  (ssl-ctx :pointer) (options :unsigned-long))

(declaim (ftype (function (cffi:foreign-pointer string)
                  (eql t))
                --ssl-set-tls-sni))
(defun --ssl-set-tls-sni (ssl-handle-in host-name-in)
  (declare (optimize (speed 3) (safety 1))
           (type cffi:foreign-pointer ssl-handle-in)
           (type string host-name-in))
  (cffi:with-foreign-string (host-name-ptr host-name-in)
    (--ssl-ctrl ssl-handle-in 55 0 host-name-ptr))
  t
)

(defconstant +ssl-error-want-read+ 2)
(defconstant +ssl-error-want-write+ 3)

(defvar *global-ssl-ctx*
        (let ((ssl-ctx (--ssl-ctx-new (--tls-method))))
          (--ssl-ctx-set-cipher-list ssl-ctx (+SSL_CIPHER_NAME+))
          (--ssl-ctx-set-options ssl-ctx (+SSL_CTX_OPTS_MASK+))
          ssl-ctx))
