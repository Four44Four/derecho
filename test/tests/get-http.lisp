(let ((any-requests-done nil))
  (with-lev-event-loop (*ev-loop*)
    ;; delay between tests
    (sleep 2.0)

    (dotimes (i 20)
      (test-request "request-get-0" *ev-loop*
        200
        (format nil "{~%  \"args\": {}, ~%  \"headers\": {~%    \"Host\": \"httpbin.org\",")
        (format nil "  \"url\": \"http://httpbin.org/get\"~%}~%")
        "http://httpbin.org/get"
        #'(lambda ()
          (setf any-requests-done t))))

    (let ((delayed-flag nil))
      (format t "~& >> Starting fake work...~%")
      (sleep 5.0)
      (format t "~& >> Finished fake work...~%")
      (setf delayed-flag t)
      (test-cond "work-after-is-done-first" (and (not any-requests-done)
                                                 delayed-flag)))

    ;; TODO: test throughput exceeding thread count
  ))
