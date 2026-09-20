(defvar *failed-test-names* '())

(defun test-cond (test-name-in test-cond-in)
  (if test-cond-in
    (format t "~&~A: [32mpassed[0m~%" test-name-in)
    (progn
      (format t "~&~A: [31mFAILED[0m~%" test-name-in)
      (push test-name-in *failed-test-names*)))
)

(defun test-eq (test-name-in test-val-expected test-val-actual)
  (if (eq test-val-expected test-val-actual)
    (format t "~&~A: [32mpassed[0m~%" test-name-in)
    (progn
      (format t "~&~A: [31mFAILED[0m, Actually: ~A~%" test-name-in test-val-actual)
      (push test-name-in *failed-test-names*)))
)

(defun test-list (test-name-in comparators-in test-vals-expected test-vals-actual)
  (if (and (= (length test-vals-expected)
              (length test-vals-actual)
              (length comparators-in))
           (every #'(lambda (cur-comparator cur-expected cur-actual)
                    (funcall cur-comparator cur-expected cur-actual))
             comparators-in
             test-vals-expected
             test-vals-actual))
    (format t "~&~A: [32mpassed[0m~%" test-name-in)
    (progn
      (format t "~&~A: [31mFAILED[0m, Actually: ~A~%" test-name-in test-vals-actual)
      (push test-name-in *failed-test-names*)))
)

(defun test-simple-array (test-name-in elem-equal-pred-in test-array-expected test-array-actual)
  (if (and (= (length test-array-expected) (length test-array-actual))
           (every #'(lambda (cur-elem-expected cur-elem-actual)
                    (funcall elem-equal-pred-in cur-elem-expected cur-elem-actual))
             test-array-expected
             test-array-actual))
    (format t "~&~A: [32mpassed[0m~%" test-name-in)
    (progn
      (format t "~&~A: [31mFAILED[0m, Actually: ~A~%" test-name-in test-array-actual)
      (push test-name-in *failed-test-names*)))
)

(defun test-usocket-fd (test-name-in)
  (let ((server-socket nil)
        (client-socket nil)
        (passed-test-p nil))
    (handler-case
      (unwind-protect
        (progn
          (setf server-socket (usocket:socket-listen "127.0.0.1" 0 :element-type '(unsigned-byte 8)))
          (let ((port (usocket:get-local-port server-socket)))
            (setf client-socket (usocket:socket-connect "127.0.0.1" port :element-type '(unsigned-byte 8)))
            (let ((fd (drch::get-usocket-fd client-socket)))
              (when (and (typep fd 'fixnum)
                         ;; check if not stdin/out/err descriptors
                         (> fd 2)
                         ;; 3 as fcntl `cmd` param (F_GETFL) returns non-error
                         (>= (drch::--fcntl fd 3 0)
                             0))
                (setf passed-test-p t)))))
        ;; clean up sockets
        (when client-socket
          (usocket:socket-close client-socket))
        (when server-socket
          (usocket:socket-close server-socket)))
      (error (error-in)
        (format t "~&Error occurred while testing socket: ~A~%" error-in)
        (setf passed-test-p nil)))

    (if passed-test-p
      (format t "~&~A: [32mpassed[0m~%" test-name-in)
      (progn
        (format t "~&~A: [31mFAILED[0m~%" test-name-in)
        (push test-name-in *failed-test-names*))))
)

;; remember to run this inside of a lev event loop
(defun test-request (test-name-in ev-loop-in
                     res-status-num-expected
                     res-body-str-prefix-expected res-body-str-suffix-expected
                     url-str-in
                     &optional on-res-callback)
  (drch:request ev-loop-in url-str-in
    :on-res #'(lambda (status-in response-str-in)
              (when on-res-callback
                (funcall on-res-callback))
              (cond
                ((/= status-in res-status-num-expected)
                  (format t "~&~A: [31mFAILED[0m, Status code actually: ~D~%" test-name-in status-in)
                  (push test-name-in *failed-test-names*))
                ((> (length res-body-str-prefix-expected)
                    (length response-str-in))
                  (format t "~&~A: [31mFAILED[0m, Response prefix actually (response too short): `~A`~%" test-name-in response-str-in)
                  (push test-name-in *failed-test-names*))
                ((not (uiop:string-prefix-p res-body-str-prefix-expected response-str-in))
                  (format t "~&~A: [31mFAILED[0m, Response prefix actually: `~A`~%" test-name-in (subseq response-str-in 0 (length res-body-str-prefix-expected)))
                  (push test-name-in *failed-test-names*))
                ((> (length res-body-str-suffix-expected)
                    (length response-str-in))
                  (format t "~&~A: [31mFAILED[0m, Response suffix actually (response too short): `~A`~%" test-name-in response-str-in)
                  (push test-name-in *failed-test-names*))
                ((not (uiop:string-suffix-p response-str-in res-body-str-suffix-expected))
                  (format t "~&~A: [31mFAILED[0m, Response suffix actually: `~A`~%" test-name-in (subseq response-str-in (- (length response-str-in) (length res-body-str-suffix-expected))))
                  (push test-name-in *failed-test-names*))
                (t
                  (format t "~&~A: [32mpassed[0m~%" test-name-in)))))
)

(defmacro with-lev-event-loop ((ev-loop-sym-name &optional cleanup-form-in) &rest body-in)
  `(let ((,ev-loop-sym-name (lev:ev-loop-new 0)))
     (unwind-protect
       (progn
         ,@body-in
         (lev:ev-run ,ev-loop-sym-name 0))
       ,cleanup-form-in
       (cffi:foreign-free ,ev-loop-sym-name)))
)
