(with-lev-event-loop (*ev-loop*)
  ;; delay between tests
  (sleep 2.0)
  (format t "~&~% >> STARTING CHUNKED HTTP REQ TESTS~%~%")

  (test-request-chunked-write "local-http-request-chunked-write-0" *ev-loop*
    200
    "qwerty..."
    "hjkl: 7"
    #(("Server" . "Wookie")
      ("Content-Length" . "17")
      ("Content-Type" . "text-plain"))
    "http://localhost:8080/chunked-request"
    :method :post
    :headers #(:content-type "text/plain")
    :body-chunks (map 'vector
                      #'(lambda (e)
                        (babel:string-to-octets e :encoding :utf-8))
                      #("jnaksnjanasjkabshjhjadbhsjbadjs"
                        "u12hui2"
                        "as9u2189u12j2iw"
                        "asiuansiusa8as"
                        "asjij2kmkldsnjsa"
                        "bobber")))

  (test-request-chunked-write "local-http-request-chunked-write-1" *ev-loop*
    200
    "qwerty..."
    "hjkl: 2"
    #(("Server" . "Wookie")
      ("Content-Length" . "17")
      ("Content-Type" . "text-plain"))
    "http://localhost:8080/chunked-request"
    :method :post
    :headers #(:content-type "text/plain")
    :body-chunks `#(,(babel:string-to-octets "p" :encoding :utf-8)))

  (let ((data-frame (make-array 30)))
    (dotimes (i (length data-frame))
      (let ((row (make-array 1000000 :element-type '(unsigned-byte 8))))
        (dotimes (j (length row))
          (setf (aref row j) (random 256)))
        (setf (aref data-frame i) row)))

    (test-request-chunked-write "local-http-request-chunked-write-2" *ev-loop*
      200
      "qwerty....hjkl: "
      ""
      #(("Server" . "Wookie")
        ("Content-Length" . "19")
        ("Content-Type" . "text-plain"))
      "http://localhost:8080/chunked-request"
      :method :post
      :headers #(:content-type "text/plain")
      :body-chunks data-frame))
)
