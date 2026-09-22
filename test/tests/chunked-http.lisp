(with-lev-event-loop (*ev-loop*)
  ;; delay between tests
  (sleep 2.0)
  (format t "~&~% >> STARTING CHUNKED HTTP RES TESTS~%~%")

  (test-request-chunked "local-http-request-chunked-0" *ev-loop*
    200
    `#("bruh moment: 89"
       "bruh moment: 90"
       "bruh moment: 91"
       "bruh moment: 92"
       "bruh moment: 93"
       "bruh moment: 94"
       "bruh moment: 95"
       "bruh moment: 96"
       "bruh moment: 97"
       "bruh moment: 98")
    `#(("Server" . "Wookie")
       ("Content-Type" . "text/event-stream")
       ("Cache-Control" . "no-cache")
       ("Connection" . "keep-alive")
       ("Transfer-Encoding" . "chunked"))
    "http://localhost:8080/chunked-response")

  (test-request-chunked "local-http-request-chunked-1" *ev-loop*
    200
    `#("bruh moment: 89"
       "bruh moment: 90"
       "bruh moment: 91"
       "bruh moment: 92"
       "bruh moment: 93"
       "bruh moment: 94"
       "bruh moment: 95"
       "bruh moment: 96"
       "bruh moment: 97"
       "bruh moment: 98")
    `#(("Server" . "Wookie")
       ("Content-Type" . "text/event-stream")
       ("Cache-Control" . "no-cache")
       ("Connection" . "keep-alive")
       ("Transfer-Encoding" . "chunked"))
    "http://localhost:8080/chunked-response-slower")

  (test-request-chunked "local-http-request-chunked-1" *ev-loop*
    200
    `#("bruh moment: 89"
       "bruh moment: 90"
       "bruh moment: 91"
       "bruh moment: 92"
       "bruh moment: 93"
       "bruh moment: 94"
       "bruh moment: 95"
       "bruh moment: 96"
       "bruh moment: 97"
       "bruh moment: 98")
    `#(("Server" . "Wookie")
       ("Content-Type" . "text/event-stream")
       ("Cache-Control" . "no-cache")
       ("Connection" . "keep-alive")
       ("Transfer-Encoding" . "chunked"))
    "http://localhost:8080/chunked-response-faster")
)
