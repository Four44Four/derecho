(with-lev-event-loop (*ev-loop*)
  ;; delay between tests
  (sleep 2.0)
  ;; (let ((start-time (get-internal-real-time)))
    (format t "~&~% >> STARTING HTTPS TESTS~%~%")
    ;; (drch:request *ev-loop* "https://httpbin.org/get" :on-res #'(lambda (status-in res-in) (declare (ignore status-in res-in)) (format t "~&WHAT: ~F~%" (/ (- (get-internal-real-time) start-time) internal-time-units-per-second)))))

  (dotimes (i 20)
    (test-request (format nil "remote-httpS-request-get-~D" i) *ev-loop*
      200
      (format nil "{~%  \"args\": {}, ~%  \"headers\": {~%    \"Host\": \"httpbin.org\",")
      (format nil "  \"url\": \"https://httpbin.org/get\"~%}~%")
      `#(("Date" . "")
         ("Content-type" . "application/json")
         ("Content-length" . "200")
         ("Connection" . "keep-alive")
         ("Server" . "gunicorn")
         ("Access-Control-Allow-Origin" . "*")
         ("Access-Control-Allow-Credentials" . "true"))
      "https://httpbin.org/get"))
)
