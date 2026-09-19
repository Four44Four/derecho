(with-lev-event-loop (*ev-loop* nil)
  (test-request "request-get-0" *ev-loop*
    200
    (format nil "{~%  \"args\": {}, ~%  \"headers\": {~%    \"Host\": \"httpbin.org\",")
    (format nil "  \"url\": \"http://httpbin.org/get\"~%}~%")
    "http://httpbin.org/get")
)
