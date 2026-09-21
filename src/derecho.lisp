(in-package #:derecho)

;; TODO: add non-GET HTTP request method support
;;       add SSE/streaming response callback support
;;       add threadsafe global socket cache to impl connection pooling
;;         - opt-in to try and reuse a cached socket
;;         - opt-in to try and cache the resulting socket
;;         - sockets will be pruned from socket cache when:
;;            - response includes `Connection: close`
;;            - writing to the socket fails (socket's file descriptor is closed/broken)
;;               - try and open a new socket + cache it if specified
;;            - socket cache size exceeds capacity (default 128) (LRU socket is pruned on addition of a new one)
;;         - sockets CANNOT be used across event loops:
;;            - connections can only reuse cached sockets from the same event loop and can only leave cached sockets for their own event loop

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
  (parser #'(lambda (data-in &key start end) (declare (ignore data-in start end)))
    :type function)
  (write-buffer (make-array 0 :element-type '(unsigned-byte 8))
    :type (simple-array (unsigned-byte 8) (*)))
  (write-pos 0
    :type fixnum)
  (read-buffer (make-array (+RESPONSE_BUFFER_SIZE+) :element-type '(unsigned-byte 8))
    :type (simple-array (unsigned-byte 8) (*)))
  (response-body (make-array 0 :element-type '(unsigned-byte 8) :adjustable t :fill-pointer 0)
    :type (vector (unsigned-byte 8)))
  (on-res-fn #'(lambda (status-in body-in) (declare (ignore status-in body-in)))
    :type function))

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
                (let ((ssl-error (--ssl-get-error ssl-handle-in ssl-connect-res)))
                  (cond
                    ((= ssl-error +ssl-error-want-read+)
                      (change-lev-io-watcher-mode ev-loop-in io-watcher-in fd-in lev:+ev-read+))
                    ((= ssl-error +ssl-error-want-write+)
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
                    (if (>= bytes-sent 0)
                      ;; data was sent -> move up the write position
                      (incf (http-client-write-pos client-in)
                            bytes-sent)
                      ;; sending error occurred
                      (abort-request "Error occurred while writing to socket" client-in))))

                ;; if all bytes are written -> switch `io-watcher-in` from listening to write events to listening to read events
                (when (= (length write-buffer-in)
                         (http-client-write-pos client-in))
                  (change-lev-io-watcher-mode ev-loop-in io-watcher-in fd-in lev:+ev-read+))))

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
                    (funcall (http-client-parser client-in)
                             read-buffer-in
                             :start 0
                             :end bytes-read))))))))))
)

;; send a HTTP request to `url-str-in` within the context of event loop `ev-loop-in`
;; returns `t`
;; `on-res` should be a function that takes in `status-in` and `response-string-in`
(declaim (ftype (function (cffi:foreign-pointer string &key (:on-res (function (fixnum string) *)))
                  (eql t))
                request))
(defun request (ev-loop-in url-str-in &key on-res)
  (declare (optimize (speed 3) (safety 1))
           (type cffi:foreign-pointer ev-loop-in)
           (type string url-str-in)
           (type function on-res))
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
           (req-bytes (build-http-request-bytes host-in path-in))
           (client (make-http-client :fd fd
                                     :ev-loop ev-loop-in
                                     :io-watcher io-watcher
                                     :tls-handshaking-p tls-p
                                     :ssl-handle ssl-handle
                                     :write-buffer req-bytes
                                     :on-res-fn on-res))
           (http-res-state (fast-http:make-http-response)))
      (declare (type fixnum fd)
               (type boolean tls-p)
               (type (or null cffi:foreign-pointer) ssl-handle)
               (type cffi:foreign-pointer io-watcher)
               (type (simple-array (unsigned-byte 8) (*)) req-bytes))

      (set-non-blocking fd)

      (when tls-p
        (--ssl-set-fd ssl-handle fd)
        (--ssl-set-tls-sni ssl-handle host-in))

      (setf (http-client-parser client)
            (fast-http:make-parser http-res-state
              :body-callback #'(lambda (data-in start-in end-in)
                               (declare (type (simple-array (unsigned-byte 8) (*)) data-in)
                                        (type fixnum start-in
                                                     end-in))
                               ;; append `data-in` into the client's response-body
                               (let* ((client-res-body (http-client-response-body client))
                                      (prev-res-body-len (length client-res-body))
                                      (new-res-body-len (+ prev-res-body-len (- end-in start-in))))
                                 (declare (type (vector (unsigned-byte 8)) client-res-body)
                                          (type fixnum prev-res-body-len
                                                       new-res-body-len))
                                 ;; expand `client-res-body` and keep the fill-pointer at its new end
                                 (adjust-array client-res-body new-res-body-len :fill-pointer t)
                                 ;; copy the specified portion of `data-in` into `client-res-body`
                                 ;;   starting from `client-res-body`'s `prev-res-body-len` index
                                 (replace client-res-body data-in
                                          :start1 prev-res-body-len
                                          :start2 start-in
                                          :end2 end-in)))
              :finish-callback #'(lambda ()
                                 ;; call `on-res` with the full response of the request
                                 (funcall (http-client-on-res-fn client)
                                          (fast-http:http-status http-res-state)
                                          (babel:octets-to-string (http-client-response-body client) :encoding :utf-8))
                                 (free-http-client client))))

      (setf (gethash (cffi:pointer-address io-watcher) *http-clients*)
            client)

      ;; start the io-watcher while only listening to write events
      (lev:ev-io-init io-watcher 'client-io-cb fd lev:+ev-write+)
      (lev:ev-io-start ev-loop-in io-watcher)

      t))
)
