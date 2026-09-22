(with-lev-event-loop (*ev-loop*)
  ;; delay between tests
  (sleep 2.0)
  (format t "~&~% >> STARTING NON-GET HTTP(S) TESTS~%~%")

  (test-request "remote-http-request-post-0" *ev-loop*
    200
    (format nil "{~%  \"args\": {}, ~%  \"data\": \"\", ~%  \"files\": {}, ~%  \"form\": {~%    \"blahblahblah\": \"\"~%  }, ~%  \"headers\": {~%    \"Boring\": \"things\", ~%    \"Content-Length\": \"12\", ~%    \"Content-Type\": \"application/x-www-form-urlencoded\", ~%    \"Fooing\": \"Baring\", ~%    \"Host\": \"httpbin.org\",")
    (format nil "  \"url\": \"http://httpbin.org/post\"~%}~%")
    nil
    "http://httpbin.org/post"
    :method :post
    :headers #(:fooing "Baring"
               :boring "things"
               :content-type "application/x-www-form-urlencoded")
    :body "blahblahblah")

  (test-request "remote-http-request-post-1" *ev-loop*
    200
    (format nil "{~%  \"args\": {}, ~%  \"data\": \"blahblahblah\", ~%  \"files\": {}, ~%  \"form\": {}, ~%  \"headers\": {~%    \"Boring\": \"things\", ~%    \"Content-Length\": \"12\", ~%    \"Fooing\": \"Baring\", ~%    \"Host\": \"httpbin.org\",")
    (format nil "  \"url\": \"http://httpbin.org/post\"~%}~%")
    nil
    "http://httpbin.org/post"
    :method :post
    :headers #(:fooing "Baring"
               :boring "things")
    :body "blahblahblah")

  (test-request "remote-httpS-request-post-0" *ev-loop*
    200
    (format nil "{~%  \"args\": {}, ~%  \"data\": \"\", ~%  \"files\": {}, ~%  \"form\": {~%    \"blahblahblah\": \"\"~%  }, ~%  \"headers\": {~%    \"Boring\": \"things\", ~%    \"Content-Length\": \"12\", ~%    \"Content-Type\": \"application/x-www-form-urlencoded\", ~%    \"Fooing\": \"Baring\", ~%    \"Host\": \"httpbin.org\",")
    (format nil "  \"url\": \"https://httpbin.org/post\"~%}~%")
    nil
    "https://httpbin.org/post"
    :method :post
    :headers #(:fooing "Baring"
               :boring "things"
               :content-type "application/x-www-form-urlencoded")
    :body "blahblahblah")

  (test-request "remote-http-request-patch-0" *ev-loop*
    200
    (format nil "{~%  \"args\": {}, ~%  \"data\": \"\", ~%  \"files\": {}, ~%  \"form\": {~%    \"blahblahblah\": \"\"~%  }, ~%  \"headers\": {~%    \"Boring\": \"things\", ~%    \"Content-Length\": \"12\", ~%    \"Content-Type\": \"application/x-www-form-urlencoded\", ~%    \"Fooing\": \"Baring\", ~%    \"Host\": \"httpbin.org\",")
    (format nil "  \"url\": \"http://httpbin.org/patch\"~%}~%")
    nil
    "http://httpbin.org/patch"
    :method :patch
    :headers #(:fooing "Baring"
               :boring "things"
               :content-type "application/x-www-form-urlencoded")
    :body "blahblahblah")

  (test-request "remote-http-request-patch-1" *ev-loop*
    200
    (format nil "{~%  \"args\": {}, ~%  \"data\": \"\", ~%  \"files\": {}, ~%  \"form\": {~%    \"blahblahblah\": \"jim\"~%  }, ~%  \"headers\": {~%    \"Boring\": \"things\", ~%    \"Content-Length\": \"16\", ~%    \"Content-Type\": \"application/x-www-form-urlencoded\", ~%    \"Fooing\": \"Baring\", ~%    \"Host\": \"httpbin.org\",")
    (format nil "  \"url\": \"http://httpbin.org/patch\"~%}~%")
    nil
    "http://httpbin.org/patch"
    :method :patch
    :headers #(:fooing "Baring"
               :boring "things"
               :content-type "application/x-www-form-urlencoded")
    :body "blahblahblah=jim")

  (test-request "remote-http-request-patch-2" *ev-loop*
    200
    (format nil "{~%  \"args\": {}, ~%  \"data\": \"blahblahblah=jim\", ~%  \"files\": {}, ~%  \"form\": {}, ~%  \"headers\": {~%    \"Boring\": \"things\", ~%    \"Content-Length\": \"16\", ~%    \"Content-Type\": \"application/json\", ~%    \"Fooing\": \"Baring\", ~%    \"Host\": \"httpbin.org\",")
    (format nil "  \"url\": \"http://httpbin.org/patch\"~%}~%")
    nil
    "http://httpbin.org/patch"
    :method :patch
    :headers #(:fooing "Baring"
               :boring "things"
               :content-type "application/json")
    :body "blahblahblah=jim")

  (test-request "remote-http-request-patch-3" *ev-loop*
    200
    (format nil "{~%  \"args\": {}, ~%  \"data\": \"{\\\"blahblahblah\\\": \\\"jim\\\", \\\"morning\\\": 18}\", ~%  \"files\": {}, ~%  \"form\": {}, ~%  \"headers\": {~%    \"Boring\": \"things\", ~%    \"Content-Length\": \"38\", ~%    \"Content-Type\": \"application/json\", ~%    \"Fooing\": \"Baring\", ~%    \"Host\": \"httpbin.org\",")
    (format nil "  \"url\": \"http://httpbin.org/patch\"~%}~%")
    nil
    "http://httpbin.org/patch"
    :method :patch
    :headers #(:fooing "Baring"
               :boring "things"
               :content-type "application/json")
    :body "{\"blahblahblah\": \"jim\", \"morning\": 18}")
)
