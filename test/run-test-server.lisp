#-quicklisp
  (load "~/quicklisp/setup.lisp")

(ql:quickload '(:bordeaux-threads :wookie :cl-async :quri))

(wookie:defroute (:get "/slow-response") (req-in res-out)
  (cl-async:with-delay (5.0)
    (wookie:send-response res-out
      :status 200
      :headers '(:content-type "text/plain")
      :body "asdfghjkl...zxcvbnm")))

(defun do-chunked-response (delay-secs-in req-in res-out)
  (let ((res-strm (wookie:start-response res-out
                    :status 200
                    :headers '(:content-type "text/event-stream"
                               :cache-control "no-cache"
                               :connection "keep-alive")))
        (i 0)
        (interval nil))
    (setf interval (cl-async:interval
                     #'(lambda ()
                       (if (< i 10)
                         (progn
                           (write-sequence (babel:string-to-octets (format nil "bruh moment: ~D" (+ 89 i))
                                                                   :encoding :utf-8)
                                           res-strm)
                           (force-output res-strm)
                           (incf i))
                         (progn
                           (cl-async:remove-interval interval)
                           (wookie:finish-response res-out))))
                     :time delay-secs-in)))
)

(wookie:defroute (:get "/chunked-response") (req-in res-out)
  (do-chunked-response 0.5 req-in res-out)
)

(wookie:defroute (:get "/chunked-response-slower") (req-in res-out)
  (do-chunked-response 2.0 req-in res-out)
)

(wookie:defroute (:get "/chunked-response-faster") (req-in res-out)
  (do-chunked-response 0.1 req-in res-out)
)

(wookie:add-hook :body-chunk
  #'(lambda (req-in chunk-in start-in end-in finished-p)
      (declare (ignore ;chunk-in start-in end-in
                 finished-p))
      (when (string= (quri:uri-path (wookie:request-uri req-in))
                                    "/chunked-request")
        ;; (format t "~& ??? ~A~%" (babel:octets-to-string chunk-in :start start-in :end end-in :encoding :utf-8))
        (let ((cur-chunk-count (or (wookie:plugin-request-data :chunk-count req-in)
                                   0)))
          (setf (wookie:plugin-request-data :chunk-count req-in)
                (1+ cur-chunk-count))
          (setf (wookie:plugin-request-data :finished-chunks req-in)
                finished-p)))))

(wookie:defroute (:post "/chunked-request") (req-in res-out)
  (let ((chunks-count-in (or (wookie:plugin-request-data :chunk-count req-in)
                             0)))
    (format t "~& [wookie] >> Received ~D chunks~%" chunks-count-in)
    (wookie:send-response res-out
      :status 200
      :headers '(:content-type "text-plain")
      :body (format nil "qwerty....hjkl: ~D" chunks-count-in)))
)

(bt:make-thread
  #'(lambda ()
    ;; for some reason wookie/woo don't have the ability to disable request body accumulatio over chunked requests
    (setf wookie::*max-body-size* (* 50 1024 1024))
    (cl-async:start-event-loop
      #'(lambda ()
        (wookie:start-server (make-instance 'wookie:listener :port 8080))
        (format t "~&TESTING SERVER STARTED~%")))))
