(let ((any-requests-done nil))
  (with-lev-event-loop (*ev-loop*)
    ;; delay between tests
    (sleep 2.0)
    (format t "~&~% >> STARTING HTTP TESTS~%~%")

    (dotimes (i 20)
      (test-request (format nil "remote-http-request-get-~D" i) *ev-loop*
        200
        (format nil "{~%  \"args\": {}, ~%  \"headers\": {~%    \"Host\": \"httpbin.org\",")
        (format nil "  \"url\": \"http://httpbin.org/get\"~%}~%")
        "http://httpbin.org/get"
        :on-res #'(lambda ()
                  (setf any-requests-done t))))

    (let ((delayed-flag nil))
      (format t "~& >> Starting fake work...~%")
      (sleep 5.0)
      (format t "~& >> Finished fake work...~%")
      (setf delayed-flag t)
      (test-cond "work-after-is-done-first" (and (not any-requests-done)
                                                 delayed-flag)))

    (dotimes (i 20)
      (test-request (format nil "remote-http-request-get-~D" (+ 20 i)) *ev-loop*
        200
        (format nil "{~%  \"args\": {}, ~%  \"headers\": {~%    \"Host\": \"httpbin.org\",")
        (format nil "  \"url\": \"http://httpbin.org/get\"~%}~%")
        "http://httpbin.org/get"
        :on-res #'(lambda ()
                  (setf any-requests-done t))))

    ;; TESTING SERVER SHOULD HAVE STARTED BY NOW

    (format t "~& >> Starting slow requests...~%")
    (dotimes (i 20)
      (test-request (format nil "local-http-slow-request-get-~D" i) *ev-loop*
        200
        "asdfghjkl"
        "zxcvbnm"
        "http://localhost:8080/slow-response"))
    (format t "~& >> Sent all slow requests~%")

  ))
