#-quicklisp
  (load "~/quicklisp/setup.lisp")

(ql:quickload '(:bordeaux-threads :wookie :cl-async))

(wookie:defroute (:get "/slow-response") (req-in res-out)
  (cl-async:with-delay (5.0)
    (wookie:send-response res-out
      :status 200
      :headers '(:content-type "text/plain")
      :body "asdfghjkl...zxcvbnm")))

(bt:make-thread
  #'(lambda ()
    (cl-async:start-event-loop
      #'(lambda ()
        (wookie:start-server (make-instance 'wookie:listener :port 8080))
        (format t "~&TESTING SERVER STARTED~%")))))
