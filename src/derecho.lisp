(in-package #:derecho)

;; TODO: add TLS/HTTPS support
;;       add non-GET HTTP request method support
;;       add SSE/streaming response callback support

(cffi:defcfun ("recv" --recv) :ssize
  (fd :int) (buf :pointer) (len :size) (flags :int))

(cffi:defcfun ("send" --send) :ssize
  (fd :int) (buf :pointer) (len :size) (flags :int))

(cffi:defcfun ("close" --close) :int
  (fd :int))

(cffi:defcfun ("fcntl" --fcntl) :int
  (fd :int) (cmd :int) (arg :int))

(declaim (ftype (function (fixnum) fixnum) set-non-blocking))
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
  (parser #'(lambda (data-in &key start end) (declare (ignore data-in start end)))
    :type function)
  (write-buffer (make-array 0 :element-type '(unsigned-byte 8))
    :type (simple-array (unsigned-byte 8) (*)))
  (write-pos 0
    :type fixnum)
  (raw-read-buffer (cffi:null-pointer)
    :type cffi:foreign-pointer)
  (read-buffer (make-array (+RESPONSE_BUFFER_SIZE+) :element-type '(unsigned-byte 8))
    :type (simple-array (unsigned-byte 8) (*)))
  (response-body (make-array 0 :element-type '(unsigned-byte 8) :adjustable t :fill-pointer 0)
    :type (vector (unsigned-byte 8)))
  (on-res-fn #'(lambda (status-in body-in) (declare (ignore status-in body-in)))
    :type function))

(declaim (ftype (function (http-client)
                  fixnum)
                free-http-client))
(defun free-http-client (client-in)
  (declare (optimize (speed 3) (safety 1))
           (type http-client client-in))
  (let ((io-watcher-in (http-client-io-watcher client-in))
        (ev-loop-in (http-client-ev-loop client-in))
        (raw-read-buffer-in (http-client-raw-read-buffer client-in)))
    (declare (type cffi:foreign-pointer io-watcher-in
                                        ev-loop-in
                                        raw-read-buffer-in))
    (lev:ev-io-stop ev-loop-in io-watcher-in)
    (remhash (cffi:pointer-address io-watcher-in)
             *http-clients*)
    (cffi:foreign-free io-watcher-in)
    (cffi:foreign-free raw-read-buffer-in)
    (--close (http-client-fd client-in)))
)


(cffi:defcallback client-io-cb :void ((ev-loop-in :pointer) (io-watcher-in :pointer) (events-in :int))
  ;; do things whenever an event occurs
  (let ((client-in (gethash (cffi:pointer-address io-watcher-in)
                            *http-clients*)))
    (declare (type (or null http-client) client-in))
    (when client-in
      (let ((fd-in (http-client-fd client-in)))
        (declare (type fixnum fd-in))

        ;; if `event-in` is a write event
        (unless (zerop (logand events-in lev:+ev-write+))
          (let* ((write-buffer-in (http-client-write-buffer client-in))
                 (write-pos-in (http-client-write-pos client-in))
                 (writable-len-left-in (- (length write-buffer-in)
                                          write-pos-in)))
            (declare (type (simple-array (unsigned-byte 8) (*)) write-buffer-in)
                     (type fixnum write-pos-in
                                  writable-len-left-in))
            ;; sends the write-buffer data from `write-pos-in` to the end of `write-buffer-in`
            (cffi:with-pointer-to-vector-data (write-buffer-ptr write-buffer-in)
              (let ((send-res (--send fd-in (cffi:inc-pointer write-buffer-ptr write-pos-in) writable-len-left-in 0)))
                (declare (type fixnum send-res))
                (cond
                  ;; handle sending error
                  ((< send-res 0)
                    (format t "~& [derecho] >> Error occurred while writing to socket~%")
                    (free-http-client client-in))
                  ;; all data was sent
                  ;;   switch `io-watcher-in` from listening to write events to listening to read events
                  ((= send-res writable-len-left-in)
                    (lev:ev-io-stop ev-loop-in io-watcher-in)
                    (lev:ev-io-init io-watcher-in 'client-io-cb fd-in lev:+ev-read+)
                    (lev:ev-io-start ev-loop-in io-watcher-in))
                  ;; not all data was sent (number of bytes written are stored in `send-res`)
                  (t
                    (incf (http-client-write-pos client-in)
                          send-res)))))))

        ;; if `event-in` is a read event
        (unless (zerop (logand events-in lev:+ev-read+))
          (let* ((raw-read-buffer-in (http-client-raw-read-buffer client-in))
                 (recv-res (--recv fd-in raw-read-buffer-in (+RESPONSE_BUFFER_SIZE+) 0)))
            (declare (type cffi:foreign-pointer raw-read-buffer-in)
                     (type fixnum recv-res))
            (cond
              ;; handle error on receiving
              ((< recv-res 0)
                (format t "~& [derecho] >> Error occurred while receiving from socket ~%")
                (free-http-client client-in))
              ;; connection has been closed
              ((= recv-res 0)
                (free-http-client client-in))
              ;; some data has been received
              ;;   copy the C array into a CL simple-array and run the HTTP parser callback on it
              (t
                (let ((read-buffer-in (http-client-read-buffer client-in)))
                  (declare (type (simple-array (unsigned-byte 8) (*)) read-buffer-in))
                  (cffi:with-pointer-to-vector-data (read-buffer-in-ptr read-buffer-in)
                    (cffi:foreign-funcall "memcpy"
                                          :pointer read-buffer-in-ptr
                                          :pointer raw-read-buffer-in
                                          :size (+RESPONSE_BUFFER_SIZE+)
                                          :pointer))
                  (funcall (http-client-parser client-in)
                           read-buffer-in
                           :start 0
                           :end recv-res)))))))))
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
           (usock (usocket:socket-connect
                    (if host-colon-pos
                      (subseq host-in 0 host-colon-pos)
                      host-in)
                    port-in :element-type '(unsigned-byte 8)))
           (fd (get-usocket-fd usock))
           (io-watcher (cffi:foreign-alloc '(:struct lev:ev-io)))
           (req-bytes (build-http-request-bytes host-in path-in))
           (client (make-http-client :fd fd
                                     :ev-loop ev-loop-in
                                     :io-watcher io-watcher
                                     :write-buffer req-bytes
                                     :raw-read-buffer (cffi:foreign-alloc :unsigned-char :count (+RESPONSE_BUFFER_SIZE+))
                                     :on-res-fn on-res))
           (http-res-state (fast-http:make-http-response)))
      (declare ;(type usocket:usocket usock)
               (type fixnum fd)
               (type cffi:foreign-pointer io-watcher)
               (type (simple-array (unsigned-byte 8) (*)) req-bytes))

      (set-non-blocking fd)

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
