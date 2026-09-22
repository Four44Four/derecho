(in-package #:derecho)

;; TODO: add threadsafe global socket cache to impl connection pooling
;;         - opt-in to try and reuse a cached socket
;;         - opt-in to try and cache the resulting socket
;;         - sockets will be pruned from socket cache when:
;;            - response includes `Connection: close`
;;            - writing to the socket fails (socket's file descriptor is closed/broken)
;;               - try and open a new socket + cache it if specified
;;            - socket cache size exceeds capacity (default 128) (LRU socket is pruned on addition of a new one)
;;         - sockets CANNOT be used across event loops:
;;            - connections can only reuse cached sockets from the same event loop and can only leave cached sockets for their own event loop
;;       add request chaining async macro
;;         - allow for looping over the same request via recursion (test for tail-calling optimizations)

(declaim (ftype (function (fixnum)
                  fixnum)
                 set-non-blocking))
(defun set-non-blocking (fd-in)
  (declare (optimize (speed 3) (safety 1))
           (type fixnum fd-in))
  #+linux (--fcntl fd-in 4 2048)
  #+darwin (--fcntl fd-in 4 4)
  #- (or linux darwin) (--fcntl fd 4 4)) ; Fallback for compilation


;; <io-watcher-pointer-addr, http-client>
(defvar *http-clients* (make-hash-table :test #'eql))

(defstruct http-client
  (fd 0
    :type fixnum)
  (ev-loop (cffi:null-pointer)
    :type cffi:foreign-pointer)
  (io-watcher (cffi:null-pointer)
    :type cffi:foreign-pointer)
  (tls-handshaking-p nil
    :type boolean)
  (ssl-handle nil
    :type (or null cffi:foreign-pointer))
  (res-state nil
    :type (or null fast-http:http-response))
  (parser-callbacks nil
    :type (or null fast-http::callbacks))
  (chunk-body-writer-fn nil
    :type (or null (function () (values (simple-array (unsigned-byte 8) (*)) boolean))))
  (body-chunk-state :header
    :type (member :header :body :footer :last-body :last-footer :close-header :close-footer :terminate))
  (cur-body-chunk nil
    :type (or null (simple-array (unsigned-byte 8) (*))))
  (write-buffer (make-array 0 :element-type '(unsigned-byte 8))
    :type (simple-array (unsigned-byte 8) (*)))
  (write-pos 0
    :type fixnum)
  (read-buffer (make-array (+RESPONSE_BUFFER_SIZE+) :element-type '(unsigned-byte 8))
    :type (simple-array (unsigned-byte 8) (*)))
  (response-body (make-array 0 :element-type '(unsigned-byte 8) :adjustable t :fill-pointer 0)
    :type (vector (unsigned-byte 8))))

(declaim (ftype (function (http-client)
                  (eql t))
                free-http-client))
(defun free-http-client (client-in)
  (declare (optimize (speed 3) (safety 1))
           (type http-client client-in))
  (let ((io-watcher-in (http-client-io-watcher client-in))
        (ev-loop-in (http-client-ev-loop client-in))
        (ssl-handle-in (http-client-ssl-handle client-in)))
    (declare (type cffi:foreign-pointer io-watcher-in
                                        ev-loop-in)
             (type (or null cffi:foreign-pointer) ssl-handle-in))
    (lev:ev-io-stop ev-loop-in io-watcher-in)
    (remhash (cffi:pointer-address io-watcher-in)
             *http-clients*)
    (cffi:foreign-free io-watcher-in)

    (when ssl-handle-in
      (--ssl-shutdown ssl-handle-in)
      (--ssl-free ssl-handle-in))
    (--close (http-client-fd client-in))

    t)
)

(declaim (ftype (function (cffi:foreign-pointer cffi:foreign-pointer fixnum fixnum)
                  (eql t))
                change-lev-io-watcher-mode))
(defun change-lev-io-watcher-mode (ev-loop-in io-watcher-in fd-in listen-mode-in)
  (declare (optimize (speed 3) (safety 0))
           (type cffi:foreign-pointer ev-loop-in
                                      io-watcher-in)
           (type fixnum fd-in
                        listen-mode-in))
  (lev:ev-io-stop ev-loop-in io-watcher-in)
  (lev:ev-io-init io-watcher-in 'client-io-cb fd-in listen-mode-in)
  (lev:ev-io-start ev-loop-in io-watcher-in)
  t
)

(declaim (ftype (function (string http-client)
                  (eql t))
                 abort-request))
(defun abort-request (reason-str-in http-client-in)
  (declare (optimize (speed 3) (safety 0))
           (type string reason-str-in)
           (type http-client http-client-in))
  (format *error-output* "~& [derecho] >> ~A~%" reason-str-in)
  (free-http-client http-client-in)
)

(cffi:defcallback client-io-cb :void ((ev-loop-in :pointer) (io-watcher-in :pointer) (events-in :int))
  ;; do things whenever an event occurs
  (let ((client-in (gethash (cffi:pointer-address io-watcher-in)
                            *http-clients*)))
    (declare (type (or null http-client) client-in))
    (when client-in
      (let ((fd-in (http-client-fd client-in))
            (ssl-handle-in (http-client-ssl-handle client-in)))
        (declare (type fixnum fd-in)
                 (type (or null cffi:foreign-pointer) ssl-handle-in))

          (if (http-client-tls-handshaking-p client-in)
            ;; handle tls handshaking
            (let ((ssl-connect-res (--ssl-connect ssl-handle-in)))
              (if (= 1 ssl-connect-res)
                ;; successful handshake -> start writing request
                (progn
                  (setf (http-client-tls-handshaking-p client-in)
                        nil)
                  (change-lev-io-watcher-mode ev-loop-in io-watcher-in fd-in lev:+ev-write+))
                ;; handle failed handshake
                (let ((ssl-err (--ssl-get-error ssl-handle-in ssl-connect-res)))
                  (cond
                    ((= ssl-err +ssl-error-want-read+)
                      (change-lev-io-watcher-mode ev-loop-in io-watcher-in fd-in lev:+ev-read+))
                    ((= ssl-err +ssl-error-want-write+)
                      (change-lev-io-watcher-mode ev-loop-in io-watcher-in fd-in lev:+ev-write+))
                    (t
                      (abort-request "Error occurred while doing TLS handshake" client-in))))))

          (progn
            ;; if `event-in` is a write event
            (unless (zerop (logand events-in lev:+ev-write+))
              (let* ((write-buffer-in (http-client-write-buffer client-in))
                     (write-pos-in (http-client-write-pos client-in))
                     (writable-len-left-in (- (length write-buffer-in)
                                              write-pos-in)))
                (declare (type (simple-array (unsigned-byte 8) (*)) write-buffer-in)
                         (type fixnum write-pos-in
                                      writable-len-left-in))
                ;; sends as much write-buffer data from `write-pos-in` to the end of `write-buffer-in` as possible
                (cffi:with-pointer-to-vector-data (write-buffer-ptr write-buffer-in)
                  (let ((bytes-sent (if ssl-handle-in
                                       (--ssl-write ssl-handle-in (cffi:inc-pointer write-buffer-ptr write-pos-in) writable-len-left-in)
                                       (--send fd-in (cffi:inc-pointer write-buffer-ptr write-pos-in) writable-len-left-in 0))))
                    ;; (format t "~& <<<< ~D :: ~A~%" bytes-sent (babel:octets-to-string write-buffer-in :start write-pos-in :end (min (length write-buffer-in) (+ write-pos-in 20)) :encoding :utf-8))
                    (if (>= bytes-sent 0)
                      ;; data was sent -> move up the write position
                      (incf (http-client-write-pos client-in)
                            bytes-sent)
                      ;; sending error occurred
                      (if ssl-handle-in
                        ;; ssl
                        (let ((ssl-err (--ssl-get-error ssl-handle-in bytes-sent)))
                          (cond
                            ((= ssl-err +ssl-error-want-read+)
                              (change-lev-io-watcher-mode ev-loop-in io-watcher-in fd-in lev:+ev-read+))
                            ((= ssl-err +ssl-error-want-write+)
                              (change-lev-io-watcher-mode ev-loop-in io-watcher-in fd-in lev:+ev-write+))
                            (t
                              (abort-request "Error occurred while writing to socket" client-in))))
                        ;; non-ssl
                        (let ((err (get-errno)))
                          (unless (or (= err +eagain+) (= err +ewouldblock+))
                            (abort-request "Error occurred while writing to socket" client-in)))))))

                ;; do things once each buffer is finished writing
                (when (= (length write-buffer-in)
                         (http-client-write-pos client-in))
                  (let ((chunk-body-writer-fn-in (http-client-chunk-body-writer-fn client-in))
                        (body-chunk-state-in (http-client-body-chunk-state client-in)))
                    (declare (type (or null (function () (values (simple-array (unsigned-byte 8) (*)) boolean))) chunk-body-writer-fn-in)
                             (type (member :header :body :footer :last-body :last-footer :close-header :close-footer :terminate) body-chunk-state-in))
                    (if (or (null chunk-body-writer-fn-in)
                            (eq body-chunk-state-in :terminate))
                      ;; either theres no chunk body writer function OR all body chunks are done writing
                      ;;   -> switch `io-watcher-in` from listening to write events to listening to read events
                      (change-lev-io-watcher-mode ev-loop-in io-watcher-in fd-in lev:+ev-read+)
                      ;; if all writer-buffer bytes are written and `client-in`'s `chunk-body-writer-fn` is non-`nil`
                      ;;   -> run body chunk write-buffer swapping state machine
                      (progn
                        (case body-chunk-state-in
                          (:header
                            (multiple-value-bind (body-chunk-in final-body-chunk-p)
                                (funcall chunk-body-writer-fn-in)
                              (setf (http-client-write-buffer client-in)
                                    (get-body-chunk-header body-chunk-in))
                              (setf (http-client-cur-body-chunk client-in)
                                    body-chunk-in)
                              (if final-body-chunk-p
                                (setf (http-client-body-chunk-state client-in)
                                      :last-body)
                                (setf (http-client-body-chunk-state client-in)
                                      :body))))
                          (:close-header
                            (setf (http-client-write-buffer client-in)
                                  #.(coerce #(48 13 10) '(simple-array (unsigned-byte 8) (3))))
                            (setf (http-client-body-chunk-state client-in)
                                  :close-footer))
                          (:body
                            (setf (http-client-write-buffer client-in)
                                  (http-client-cur-body-chunk client-in))
                            (setf (http-client-body-chunk-state client-in)
                                  :footer))
                          (:last-body
                            (setf (http-client-write-buffer client-in)
                                  (http-client-cur-body-chunk client-in))
                            (setf (http-client-body-chunk-state client-in)
                                  :last-footer))
                          (:footer
                            (setf (http-client-write-buffer client-in)
                                  #.(coerce #(13 10) '(simple-array (unsigned-byte 8) (2))))
                            (setf (http-client-body-chunk-state client-in)
                                  :header))
                          (:last-footer
                            (setf (http-client-write-buffer client-in)
                                  #.(coerce #(13 10) '(simple-array (unsigned-byte 8) (2))))
                            (setf (http-client-body-chunk-state client-in)
                                  :close-header))
                          (:close-footer
                            (setf (http-client-write-buffer client-in)
                                  #.(coerce #(13 10) '(simple-array (unsigned-byte 8) (2))))
                            (setf (http-client-body-chunk-state client-in)
                                  :terminate)))
                        (setf (http-client-write-pos client-in)
                              0)))))))

            ;; if `event-in` is a read event
            (unless (zerop (logand events-in lev:+ev-read+))
              (let* ((read-buffer-in (http-client-read-buffer client-in))
                     (bytes-read (if ssl-handle-in
                                   ;; ssl -> read from the ssl handle
                                   (cffi:with-pointer-to-vector-data (read-buffer-ptr read-buffer-in)
                                     (--ssl-read ssl-handle-in read-buffer-ptr (+RESPONSE_BUFFER_SIZE+)))
                                   ;; non-ssl -> manually call `--recv`
                                   (cffi:with-pointer-to-vector-data (read-buffer-ptr read-buffer-in)
                                     (--recv fd-in read-buffer-ptr (+RESPONSE_BUFFER_SIZE+) 0)))))
                (declare (type (simple-array (unsigned-byte 8) (*)) read-buffer-in)
                         (type fixnum bytes-read))
                (cond
                  ;; handle error on receiving
                  ((< bytes-read 0)
                    (abort-request "Error occurred while receiving from socket" client-in))
                  ;; connection has been closed
                  ((= bytes-read 0)
                    (free-http-client client-in))
                  ;; some data has been received -> run the HTTP parser callback on the read-buffer
                  (t
                    (fast-http:parse-response (http-client-res-state client-in)
                                              (http-client-parser-callbacks client-in)
                                              read-buffer-in
                                              :start 0
                                              :end bytes-read))))))))))
)

;; send a HTTP request to `url-str-in` within the context of event loop `ev-loop-in`
;; returns `t`
;; `method` can be any HTTP method like `:get`, `:post`, `:put`, `:patch`, `:delete`, etc...
;; `on-body` can be `nil` or a function that takes in `body-string-in`,
;;   called when the entire response body finishes,
;;   with the entire response collected
;;   also see `no-collect-body-p`
;; `on-chunk` can be `nil` or a function that takes in `response-buffer-in`, `start-pos-in` and `end-pos-in`
;;   called when each chunk is received
;;   `response-buffer-in` is a raw array of bytes and is only valid up to before `end-pos-in`
;; `on-status` can be `nil` or a function that takes in `status-in`
;;   called when the response status is received
;; `on-header` can be `nil` or a funciton that takes in `name-in value-in`
;;   called when a header is parsed
;; `no-collect-body-p` is a boolean
;;   prevents collecting of each response body chunk into a vector for `on-body`
;;   this being set to a non-`nil` value will cause `on-body` to not be called
;; `headers` can be either `nil` if omitted or an array of alternating `<header-as-keyword-sym>` and `<header-value-as-string>`
;; `body` can be a string for single body request
;;   or a no-arg function which returns 2 multiple values
;;     first value is the a simple-array of bytes of current body chunk payload to send
;;     second value is the boolean of whether this is the final chunk or not
;;   (defaults to `""` if `body` keyword arg is omitted)
(declaim (ftype (function (cffi:foreign-pointer string
                            &key (:on-body (or null (function (string) *)))
                                 (:on-chunk (or null (function ((simple-array (unsigned-byte 8) (*)) fixnum fixnum) *)))
                                 (:on-status (or null (function (fixnum) *)))
                                 (:on-header (or null (function (string string) *)))
                                 (:no-collect-body-p boolean)
                                 (:method keyword)
                                 (:headers (or null (simple-array (or keyword string) (*))))
                                 (:body (or string (function () (values (simple-array (unsigned-byte 8) (*)) boolean)))))
                  (eql t))
                request))
(defun request (ev-loop-in url-str-in &key on-body on-chunk on-status on-header no-collect-body-p
                                           (method :get) headers (body ""))
  (declare (optimize (speed 3) (safety 1))
           (type cffi:foreign-pointer ev-loop-in)
           (type string url-str-in)
           (type (or null (function (string) *)) on-body)
           (type (or null (function ((simple-array (unsigned-byte 8) (*)) fixnum fixnum) *)) on-chunk)
           (type (or null (function (fixnum) *)) on-status)
           (type (or null (function (string string) *)) on-header)
           (type boolean no-collect-body-p)
           (type keyword method)
           (type (or null (simple-array (or keyword string) (*))) headers)
           (type (or string (function () (values (simple-array (unsigned-byte 8) (*)) boolean))) body))
  (multiple-value-bind (host-in path-in port-in)
      (parse-url url-str-in)
    (declare (type string host-in
                          path-in)
             (type fixnum port-in))

    (let* ((host-colon-pos (position #\: host-in :test #'char=))
           (fd (get-usocket-fd (usocket:socket-connect
                                 (if host-colon-pos
                                   (subseq host-in 0 host-colon-pos)
                                   host-in)
                                 port-in :element-type '(unsigned-byte 8))))
           (tls-p (eq :https (http-url-p url-str-in)))
           (ssl-handle (when tls-p
                         (--ssl-new *global-ssl-ctx*)))
           (io-watcher (cffi:foreign-alloc '(:struct lev:ev-io)))
           (req-bytes (build-http-request-bytes method host-in path-in headers (if (stringp body) body :chunked)))
           (http-res-state (fast-http:make-http-response))
           (client (make-http-client :fd fd
                                     :ev-loop ev-loop-in
                                     :io-watcher io-watcher
                                     :tls-handshaking-p tls-p
                                     :ssl-handle ssl-handle
                                     :write-buffer req-bytes
                                     :res-state http-res-state
                                     :chunk-body-writer-fn (unless (stringp body) body)))
           (cur-header-name nil)
           (callbacks (fast-http:make-callbacks
                        :first-line (and on-status
                                         #'(lambda (res-in)
                                           (declare (optimize (speed 3) (safety 1))
                                                    (ignore res-in))
                                           (funcall on-status (fast-http:http-status http-res-state))))
                        :header-field #'(lambda (res-in data-in start-pos-in end-pos-in)
                                        (declare (optimize (speed 3) (safety 1))
                                                 (ignore res-in)
                                                 (type (simple-array (unsigned-byte 8) (*)) data-in)
                                                 (type fixnum start-pos-in
                                                              end-pos-in))
                                        (setf cur-header-name (babel:octets-to-string data-in :start start-pos-in :end end-pos-in)))
                        :header-value #'(lambda (res-in data-in start-pos-in end-pos-in)
                                        (declare (optimize (speed 3) (safety 1))
                                                 (ignore res-in)
                                                 (type (simple-array (unsigned-byte 8) (*)) data-in)
                                                 (type fixnum start-pos-in
                                                              end-pos-in))
                                        (when cur-header-name
                                          (funcall on-header cur-header-name (babel:octets-to-string data-in :start start-pos-in :end end-pos-in))
                                          (setf cur-header-name nil)))
                        :body #'(lambda (res-in data-in start-pos-in end-pos-in)
                                (declare (optimize (speed 3) (safety 1))
                                         (ignore res-in)
                                         (type (simple-array (unsigned-byte 8) (*)) data-in)
                                         (type fixnum start-pos-in
                                                      end-pos-in))
                                (when on-chunk
                                  (funcall on-chunk data-in start-pos-in end-pos-in))

                                (unless no-collect-body-p
                                  ;; append `data-in` into the client's response-body
                                  (let* ((client-res-body (http-client-response-body client))
                                         (prev-res-body-len (length client-res-body))
                                         (new-res-body-len (+ prev-res-body-len (- end-pos-in start-pos-in))))
                                    (declare (type (vector (unsigned-byte 8)) client-res-body)
                                             (type fixnum prev-res-body-len
                                                          new-res-body-len))
                                    ;; expand `client-res-body` and keep the fill-pointer at its new end
                                    (adjust-array client-res-body new-res-body-len :fill-pointer t)
                                    ;; copy the specified portion of `data-in` into `client-res-body`
                                    ;;   starting from `client-res-body`'s `prev-res-body-len` index
                                    (replace client-res-body data-in
                                             :start1 prev-res-body-len
                                             :start2 start-pos-in
                                             :end2 end-pos-in))))
                        :message-complete #'(lambda (res-in)
                                            (declare (optimize (speed 3) (safety 1))
                                                     (ignore res-in))
                                            ;; call `on-body` with the full response of the request
                                            (when (and on-body (not no-collect-body-p))
                                              (funcall on-body
                                                       (babel:octets-to-string (http-client-response-body client) :encoding :utf-8)))
                                            (free-http-client client)))))
      (declare (type fixnum fd)
               (type boolean tls-p)
               (type (or null cffi:foreign-pointer) ssl-handle)
               (type cffi:foreign-pointer io-watcher)
               (type (simple-array (unsigned-byte 8) (*)) req-bytes)
               (type (or null string) cur-header-name))

      (set-non-blocking fd)

      (when tls-p
        (--ssl-set-fd ssl-handle fd)
        (--ssl-set-tls-sni ssl-handle host-in))

      (setf (http-client-parser-callbacks client)
            callbacks)

      (setf (gethash (cffi:pointer-address io-watcher) *http-clients*)
            client)

      ;; start the io-watcher while only listening to write events
      (lev:ev-io-init io-watcher 'client-io-cb fd lev:+ev-write+)
      (lev:ev-io-start ev-loop-in io-watcher)

      t))
)
