#-quicklisp
  (load "~/quicklisp/setup.lisp")

(ql:quickload '(:bordeaux-threads :wookie :cl-async))

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

(bt:make-thread
  #'(lambda ()
    (cl-async:start-event-loop
      #'(lambda ()
        (wookie:start-server (make-instance 'wookie:listener :port 8080))
        (format t "~&TESTING SERVER STARTED~%")))))
