(test-eq "customize-0" 4096 (drch::+RESPONSE_BUFFER_SIZE+))

(test-eq "http-url-p-0" :http (drch::http-url-p "http://hi.org"))
(test-eq "http-url-p-1" nil (drch::http-url-p "http:/hi.org"))
(test-eq "http-url-p-2" :https (drch::http-url-p "https://hi.org"))
(test-eq "http-url-p-3" :https (drch::http-url-p "https://hi"))
(test-eq "http-url-p-4" :https (drch::http-url-p "https://"))
(test-eq "http-url-p-5" :http (drch::http-url-p "http://"))
(test-eq "http-url-p-6" nil (drch::http-url-p "http:/"))
(test-eq "http-url-p-7" nil (drch::http-url-p ""))
(test-eq "http-url-p-8" nil (drch::http-url-p "bongo"))

(test-list "parse-url-0" '(string= string= =)
           '("hi.org" "/" 80)
           (multiple-value-list (drch::parse-url "http://hi.org")))
(test-list "parse-url-1" '(string= string= =)
           '("hi.org" "/" 443)
           (multiple-value-list (drch::parse-url "https://hi.org/")))
(test-list "parse-url-2" '(string= string= =)
           '("hi.org" "/hello" 80)
           (multiple-value-list (drch::parse-url "http://hi.org/hello")))
(test-list "parse-url-3" '(string= string= =)
           '("hi.org" "/hello" 443)
           (multiple-value-list (drch::parse-url "https://hi.org/hello")))
(test-list "parse-url-4" '(string= string= =)
           '("hi.org:8080" "/hello" 8080)
           (multiple-value-list (drch::parse-url "https://hi.org:8080/hello")))
(test-list "parse-url-5" '(string= string= =)
           '("hi.org:8080" "/hello/hiiii" 8080)
           (multiple-value-list (drch::parse-url "https://hi.org:8080/hello/hiiii")))
(test-list "parse-url-6" '(string= string= =)
           '("hi.org:8080" "/hello/hiiii?something=something+else" 8080)
           (multiple-value-list (drch::parse-url "https://hi.org:8080/hello/hiiii?something=something+else")))
(test-list "parse-url-7" '(string= string= =)
           '("hi.org:8080" "/hello/hiiii?something=Hello%20World%21%20%402026" 8080)
           (multiple-value-list (drch::parse-url "https://hi.org:8080/hello/hiiii?something=Hello%20World%21%20%402026")))

(test-simple-array "build-http-request-bytes-0" #'=
                   #(71 69 84 32 47 32 72 84 84 80 47 49 46 49 13 10 72 111 115 116 58 32 104 105 46 111 114 103 13 10 13 10)
                   (drch::build-http-request-bytes :get "hi.org" "/" nil ""))
(test-simple-array "build-http-request-bytes-1" #'=
                   #(71 69 84 32 47 104 101 108 108 111 32 72 84 84 80 47 49 46 49 13 10 72 111 115 116 58 32 104 105 46 111 114 103 13 10 13 10)
                   (drch::build-http-request-bytes :get "hi.org" "/hello" nil ""))
(test-simple-array "build-http-request-bytes-2" #'=
                   #(71 69 84 32 47 104 101 108 108 111 32 72 84 84 80 47 49 46 49 13 10 72 111 115 116 58 32 104 105 46 111 114 103 58 56 48 56 48 13 10 13 10)
                   (drch::build-http-request-bytes :get "hi.org:8080" "/hello" nil ""))
(test-simple-array "build-http-request-bytes-3" #'=
                   #(71 69 84 32 47 104 101 108 108 111 47 104 105 105 105 105 32 72 84 84 80 47 49 46 49 13 10 72 111 115 116 58 32 104 105 46 111 114 103 58 56 48 56 48 13 10 13 10)
                   (drch::build-http-request-bytes :get "hi.org:8080" "/hello/hiiii" nil ""))
(test-simple-array "build-http-request-bytes-4" #'=
                   #(71 69 84 32 47 104 101 108 108 111 47 104 105 105 105 105 63 115 111 109 101 116 104 105 110 103 61 115 111 109 101 116 104 105 110 103 43 101 108 115 101 32 72 84 84 80 47 49 46 49 13 10 72 111 115 116 58 32 104 105 46 111 114 103 58 56 48 56 48 13 10 13 10)
                   (drch::build-http-request-bytes :get "hi.org:8080" "/hello/hiiii?something=something+else" nil ""))
(test-simple-array "build-http-request-bytes-5" #'=
                   #(71 69 84 32 47 104 101 108 108 111 47 104 105 105 105 105 63 115 111 109 101 116 104 105 110 103 61 72 101 108 108 111 37 50 48 87 111 114 108 100 37 50 49 37 50 48 37 52 48 50 48 50 54 32 72 84 84 80 47 49 46 49 13 10 72 111 115 116 58 32 104 105 46 111 114 103 58 56 48 56 48 13 10 13 10)
                   (drch::build-http-request-bytes :get "hi.org:8080" "/hello/hiiii?something=Hello%20World%21%20%402026" nil ""))
(test-simple-array "build-http-request-bytes-6" #'=
                   #(80 79 83 84 32 47 104 101 108 108 111 47 104 105 105 105 105 63 115 111 109 101 116 104 105 110 103 61 72 101 108 108 111 37 50 48 87 111 114 108 100 37 50 49 37 50 48 37 52 48 50 48 50 54 32 72 84 84 80 47 49 46 49 13 10 72 111 115 116 58 32 104 105 46 111 114 103 58 56 48 56 48 13 10 13 10)
                   (drch::build-http-request-bytes :post "hi.org:8080" "/hello/hiiii?something=Hello%20World%21%20%402026" nil ""))
(test-simple-array "build-http-request-bytes-7" #'=
                   #(80 79 83 84 32 47 104 101 108 108 111 47 104 105 105 105 105 63 115 111 109 101 116 104 105 110 103 61 72 101 108 108 111 37 50 48 87 111 114 108 100 37 50 49 37 50 48 37 52 48 50 48 50 54 32 72 84 84 80 47 49 46 49 13 10 72 111 115 116 58 32 104 105 46 111 114 103 58 56 48 56 48 13 10 67 79 78 84 69 78 84 45 84 89 80 69 58 32 97 112 112 108 105 99 97 116 105 111 110 47 106 115 111 110 13 10 13 10)
                   (drch::build-http-request-bytes :post "hi.org:8080" "/hello/hiiii?something=Hello%20World%21%20%402026" #(:content-type "application/json") ""))
(test-simple-array "build-http-request-bytes-8" #'=
                   #(80 79 83 84 32 47 104 101 108 108 111 47 104 105 105 105 105 63 115 111 109 101 116 104 105 110 103 61 72 101 108 108 111 37 50 48 87 111 114 108 100 37 50 49 37 50 48 37 52 48 50 48 50 54 32 72 84 84 80 47 49 46 49 13 10 72 111 115 116 58 32 104 105 46 111 114 103 58 56 48 56 48 13 10 67 79 78 84 69 78 84 45 84 89 80 69 58 32 97 112 112 108 105 99 97 116 105 111 110 47 106 115 111 110 13 10 76 85 71 78 85 84 58 32 98 105 103 32 116 104 105 110 103 115 13 10 13 10)
                   (drch::build-http-request-bytes :post "hi.org:8080" "/hello/hiiii?something=Hello%20World%21%20%402026" #(:content-type "application/json" :lugnut "big things") ""))
(test-simple-array "build-http-request-bytes-9" #'=
                   #(80 79 83 84 32 47 104 101 108 108 111 47 104 105 105 105 105 63 115 111 109 101 116 104 105 110 103 61 72 101 108 108 111 37 50 48 87 111 114 108 100 37 50 49 37 50 48 37 52 48 50 48 50 54 32 72 84 84 80 47 49 46 49 13 10 72 111 115 116 58 32 104 105 46 111 114 103 58 56 48 56 48 13 10 67 79 78 84 69 78 84 45 84 89 80 69 58 32 97 112 112 108 105 99 97 116 105 111 110 47 106 115 111 110 13 10 76 85 71 78 85 84 58 32 98 105 103 32 116 104 105 110 103 115 13 10 65 80 80 76 69 58 32 98 101 101 115 42 42 13 10 13 10)
                   (drch::build-http-request-bytes :post "hi.org:8080" "/hello/hiiii?something=Hello%20World%21%20%402026" #(:content-type "application/json" :lugnut "big things" :apple "bees**") ""))
(test-simple-array "build-http-request-bytes-10" #'=
                   #(80 79 83 84 32 47 104 101 108 108 111 47 104 105 105 105 105 63 115 111 109 101 116 104 105 110 103 61 72 101 108 108 111 37 50 48 87 111 114 108 100 37 50 49 37 50 48 37 52 48 50 48 50 54 32 72 84 84 80 47 49 46 49 13 10 72 111 115 116 58 32 104 105 46 111 114 103 58 56 48 56 48 13 10 67 79 78 84 69 78 84 45 84 89 80 69 58 32 97 112 112 108 105 99 97 116 105 111 110 47 106 115 111 110 13 10 76 85 71 78 85 84 58 32 98 105 103 32 116 104 105 110 103 115 13 10 65 80 80 76 69 58 32 98 101 101 115 42 42 13 10 13 10)
                   (drch::build-http-request-bytes :post "hi.org:8080" "/hello/hiiii?something=Hello%20World%21%20%402026" #(:content-type "application/json" :lugnut "big things" :apple "bees**" :ridge-head) ""))
(test-simple-array "build-http-request-bytes-11" #'=
                   #(80 79 83 84 32 47 104 101 108 108 111 47 104 105 105 105 105 63 115 111 109 101 116 104 105 110 103 61 72 101 108 108 111 37 50 48 87 111 114 108 100 37 50 49 37 50 48 37 52 48 50 48 50 54 32 72 84 84 80 47 49 46 49 13 10 72 111 115 116 58 32 104 105 46 111 114 103 58 56 48 56 48 13 10 67 79 78 84 69 78 84 45 84 89 80 69 58 32 97 112 112 108 105 99 97 116 105 111 110 47 106 115 111 110 13 10 76 85 71 78 85 84 58 32 98 105 103 32 116 104 105 110 103 115 13 10 65 80 80 76 69 58 32 98 101 101 115 42 42 13 10 99 111 110 116 101 110 116 45 108 101 110 103 116 104 58 32 51 54 13 10 13 10 123 34 98 105 103 103 101 114 34 58 32 34 98 101 116 116 101 114 34 44 32 34 115 116 114 111 110 103 101 114 34 58 32 57 48 125)
                   (drch::build-http-request-bytes :post "hi.org:8080" "/hello/hiiii?something=Hello%20World%21%20%402026" #(:content-type "application/json" :lugnut "big things" :apple "bees**") "{\"bigger\": \"better\", \"stronger\": 90}"))
(test-simple-array "build-http-request-bytes-12" #'=
                   #(80 65 84 67 72 32 47 104 101 108 108 111 47 104 105 105 105 105 63 115 111 109 101 116 104 105 110 103 61 72 101 108 108 111 37 50 48 87 111 114 108 100 37 50 49 37 50 48 37 52 48 50 48 50 54 32 72 84 84 80 47 49 46 49 13 10 72 111 115 116 58 32 104 105 46 111 114 103 58 56 48 56 48 13 10 67 79 78 84 69 78 84 45 84 89 80 69 58 32 97 112 112 108 105 99 97 116 105 111 110 47 106 115 111 110 13 10 76 85 71 78 85 84 58 32 98 105 103 32 116 104 105 110 103 115 13 10 65 80 80 76 69 58 32 98 101 101 115 42 42 13 10 116 114 97 110 115 102 101 114 45 101 110 99 111 100 105 110 103 58 32 99 104 117 110 107 101 100 13 10 13 10)
                   (drch::build-http-request-bytes :patch "hi.org:8080" "/hello/hiiii?something=Hello%20World%21%20%402026" #(:content-type "application/json" :lugnut "big things" :apple "bees**") :chunked))

(test-simple-array "get-body-chunk-header-0" #'=
                   #(67 13 10)
                   (drch::get-body-chunk-header "blahblahblah"))
(test-simple-array "get-body-chunk-header-1" #'=
                   #(50 48 13 10)
                   (drch::get-body-chunk-header "{\"grays\": \"anatomy\", \"my\": 2189}"))
(test-simple-array "get-body-chunk-header-2" #'=
                   #(48 13 10)
                   (drch::get-body-chunk-header ""))
(test-simple-array "get-body-chunk-header-3" #'=
                   #(49 66 55 13 10)
                   (drch::get-body-chunk-header "u2huwebweuegy7t62t712g727gwty1g 26bt1w621fw12w6f1w61t2gw b12t gw21w y1t2wgy12tw12huwg12w76261w6f215fe5rgdbhjasxnjs2uh2121uhy21g2g1672tw621t67g17gty21gwtf21w651256wr561er562t6w1tfft12f1yteft12ef6215e651e56re562wtg1ywg21ef162e5r215e6f12e6g12ety12gtwf62r52ef2t1gywgu2hw721te67fehasnasxkjanasnhbvdshbhjxbhjqwbdhqbdwqdwqjbwdqhjqdwjwqnhwjqbwhjwqbwhjqv1tge6g2e712ge6712getyb 2hjwnhw1bjh2evgh2veg1hvwg12hwb2hb12jwb21hwjb21whjb21gevh12evghe2v12hegv"))

(test-usocket-fd "get-usocket-fd-0")
