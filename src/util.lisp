(in-package #:derecho)

;; returns `:http` if `url-string-in` starts with "http://"
;;         or `:https` if `url-string-in` starts with "https://"
;;         or `nil` if neither
(declaim (inline http-url-p)
         (ftype (function (string)
                  (member :https :http nil))
                http-url-p))
(defun http-url-p (url-string-in)
  (declare (optimize (speed 3) (safety 0) (debug 0))
           (type string url-string-in))
  (let ((len (length url-string-in)))
    (declare (type fixnum len))
    (and (>= len 7)
         (char= #\h (char url-string-in 0))
         (char= #\t (char url-string-in 1))
         (char= #\t (char url-string-in 2))
         (char= #\p (char url-string-in 3))
         (if (char= #\s (char url-string-in 4))
           ;; handle "https://"
           (and (>= len 8)
                (char= #\: (char url-string-in 5))
                (char= #\/ (char url-string-in 6))
                (char= #\/ (char url-string-in 7))
                :https)
           ;; handle "http://"
           (and (char= #\: (char url-string-in 4))
                (char= #\/ (char url-string-in 5))
                (char= #\/ (char url-string-in 6))
                :http))))
)

;; `url-string-in` must start with `http://` or `https://`
;; returns `(values <host-str> <path-str> <port-num>)`
;;   `<host-str>` should always be between the `://` and the next `:` or `/`
;;     Includes any explicit port number
;;   `<path-str>` should be everything past the `<port-num>` if it exists, or else everything past `<host-str>`
;;     Includes the leading `/`
;;     Will be `"/"` if there is no third `/`
;;   `<port-num>` should be between the second `:` and end-of-string or third `/`
;;     If there is no second `:`:
;;       If the `url-string` starts with `http://`:
;;         `<port-num>` will be `80`
;;       Else:
;;         `<port-num>` will be `443`
(declaim (ftype (function (string)
                  (values string string fixnum &optional))
                parse-url))
(defun parse-url (url-string-in)
  (declare (optimize (speed 3) (safety 1))
           (type string url-string-in))
  (let ((http-url-p-res (http-url-p url-string-in)))
    (declare (type (member :https :http nil) http-url-p-res))
    (unless http-url-p-res
      (error "`url-string-in` does not start with `http://` or `https://`"))
    (let* (;; skips the "://"
           (host-start-pos (if (eq :http http-url-p-res)
                             7
                             8))
           ;; finds the first `/` after the start of the host
           (post-scheme-slash-pos (position #\/ url-string-in :start host-start-pos :test #'char=))
           (second-colon-pos (position #\: url-string-in :start host-start-pos :end post-scheme-slash-pos :test #'char=))
           (host-str (subseq url-string-in host-start-pos post-scheme-slash-pos))
           (path-str (if post-scheme-slash-pos
                       (subseq url-string-in post-scheme-slash-pos)
                       "/")))
      (declare (type fixnum host-start-pos)
               (type (or null fixnum) post-scheme-slash-pos
                                      second-colon-pos)
               (type string host-str
                            path-str))
      (if second-colon-pos
        ;; explicit port
        (values host-str
                path-str
                (parse-integer url-string-in :start (1+ second-colon-pos) :end post-scheme-slash-pos))
        ;; implicit port
        (values host-str
                path-str
                (if (eq :http http-url-p-res)
                  80
                  443)))))
)

;; (alexandria:define-constant +GET_BYTE_ARRAY+ (coerce #(71 69 84 32)
;;                                                      '(simple-array (unsigned-byte 8) (*)))
;;                                              :test #'equalp)
;; (alexandria:define-constant +REQ_LINE_ARRAY+ (coerce #(32 72 84 84 80 47 49 46 49 13 10 72 111 115 116 58 32)
;;                                                      '(simple-array (unsigned-byte 8) (*)))
;;                                              :test #'equalp)
;; (alexandria:define-constant +CONN_CLOSE_ARRAY+ (coerce #(13 10 67 111 110 110 101 99 116 105 111 110 58 32 99 108 111 115 101 13 10 13 10)
;;                                                        '(simple-array (unsigned-byte 8) (*)))
;;                                              :test #'equalp)

;; returns a byte array of the HTTP 1.1 request payload
;; `method-keyword-sym-in` can be any HTTP method like `:get`, `:post`, `:put`, `:patch`, `:delete`, etc...
;; `headers-array-in` can be either `nil` if omitted or an array of alternating `<header-as-keyword-sym>` and `<header-value-as-string>`
;; `body-in` is a string or the keyword `:chunked`
(declaim (inline build-http-request-bytes)
         (ftype (function (keyword string string (or null (simple-array (or keyword string) (*))) (or string (eql :chunked)))
                  (simple-array (unsigned-byte 8) (*)))
                build-http-request-bytes))
(defun build-http-request-bytes (method-keyword-sym-in host-str-in path-str-in headers-array-in body-in)
  (declare (optimize (speed 3) (safety 1))
           (type keyword method-keyword-sym-in)
           (type string host-str-in
                        path-str-in)
           (type (or null (simple-array (or keyword string) (*))) headers-array-in)
           (type (or string (eql :chunked)) body-in))
  (fast-io:with-fast-output (buffer-out :vector)
    (fast-io:fast-write-sequence (babel:string-to-octets (symbol-name method-keyword-sym-in)) buffer-out)
    (fast-io:fast-write-sequence #.(babel:string-to-octets " ") buffer-out)
    (fast-io:fast-write-sequence (babel:string-to-octets path-str-in) buffer-out)
    (fast-io:fast-write-sequence #.(babel:string-to-octets (format nil " HTTP/1.1~C~CHost: " #\Return #\Linefeed)) buffer-out)
    (fast-io:fast-write-sequence (babel:string-to-octets host-str-in) buffer-out)
    (fast-io:fast-write-sequence #.(babel:string-to-octets (format nil "~C~C" #\Return #\Linefeed)) buffer-out)
    ;; headers (truncate length down to the lower even number using `logand` trick)
    (loop for i from 0 below (logand (length headers-array-in) -2) by 2
          do (progn
               ;; note: the default parsing of keyword symbols will be capitalized
               ;;       i.e. `:content-type` -> `"CONTENT-TYPE"`
               (fast-io:fast-write-sequence (babel:string-to-octets (symbol-name (aref headers-array-in i))) buffer-out)
               (fast-io:fast-write-sequence #.(babel:string-to-octets ": ") buffer-out)
               (fast-io:fast-write-sequence (babel:string-to-octets (aref headers-array-in (1+ i))) buffer-out)
               (fast-io:fast-write-sequence #.(babel:string-to-octets (format nil "~C~C" #\Return #\Linefeed)) buffer-out)))
    (let ((valid-str-body (and (stringp body-in)
                               (not (zerop (length body-in))))))
      ;; auto generate chunked header if body is `:chunked`
      (when (eq body-in :chunked)
        (fast-io:fast-write-sequence #.(babel:string-to-octets "transfer-encoding: chunked") buffer-out)
        (fast-io:fast-write-sequence #.(babel:string-to-octets (format nil "~C~C" #\Return #\Linefeed)) buffer-out))
      ;; auto generate content-length if body as a string exists
      (when valid-str-body
        (fast-io:fast-write-sequence #.(babel:string-to-octets "content-length: ") buffer-out)
        (fast-io:fast-write-sequence (babel:string-to-octets (write-to-string (length body-in))) buffer-out)
        (fast-io:fast-write-sequence #.(babel:string-to-octets (format nil "~C~C" #\Return #\Linefeed)) buffer-out))
      ;; headers delimiter
      (fast-io:fast-write-sequence #.(babel:string-to-octets (format nil "~C~C" #\Return #\Linefeed)) buffer-out)
      (when valid-str-body
        (fast-io:fast-write-sequence (babel:string-to-octets body-in) buffer-out))))
)

(declaim (inline get-usocket-fd)
         (ftype (function (usocket:usocket)
                  fixnum)
                get-usocket-fd))
(defun get-usocket-fd (usock-in)
  (declare (optimize (speed 3) (safety 1))
           (type usocket:usocket usock-in))
  (let ((raw-socket (usocket:socket usock-in)))
    #+sbcl
      (locally
        (declare (type sb-bsd-sockets:socket raw-socket))
        (the fixnum
             (sb-bsd-sockets:socket-file-descriptor raw-socket)))
    #+ccl
      (the fixnum
           (ccl:socket-device raw-socket))
    #+ecl
      (the fixnum
           (si:socket-file-descriptor raw-socket))
    #+lispworks
      (the fixnum
           (comm::socket-stream-socket raw-socket))
    #+allegro
      (the fixnum
           (socket:socket-handle raw-socket))
    #+clisp
      (the fixnum
           (car (ext:stream-handles raw-socket)))
    #-(or sbcl ccl ecl lispworks allegro clisp)
      (error "Unsupported CL implementation for `get-usocket-fd`"))
)

;; returns the chunk header for a byte array body chunk `body-chunk-in` in the format "<length-in-hex>\r\n" as a byte array
(declaim (ftype (function ((simple-array (unsigned-byte 8) (*)))
                  (simple-array (unsigned-byte 8) (*)))
                get-body-chunk-header))
(defun get-body-chunk-header (body-chunk-in)
  (declare (optimize (speed 3) (safety 0) (debug 0))
           (type (simple-array (unsigned-byte 8) (*)) body-chunk-in))
  (let* ((body-length-in (length body-chunk-in))
         (hex-digits-count (max 1 (ceiling (integer-length body-length-in) 4)))
         (ret-arr (make-array (+ hex-digits-count 2) :element-type '(unsigned-byte 8))))
    (declare (type fixnum body-length-in
                          hex-digits-count)
             (type (simple-array (unsigned-byte 8) (*)) ret-arr))
    (loop for i from (1- hex-digits-count) downto 0
          for bit-i from 0 by 4
          do (let ((cur-nibble (ldb (byte 4 bit-i) body-length-in)))
               (setf (aref ret-arr i)
                     (char-code (schar "0123456789ABCDEF" cur-nibble)))))
    ;; append CR and LF bytes
    (setf (aref ret-arr hex-digits-count)
          13)
    (setf (aref ret-arr (1+ hex-digits-count))
          10)
    ret-arr)
)
