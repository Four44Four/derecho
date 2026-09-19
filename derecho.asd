(defsystem #:derecho
  :description "Single-threaded libev/lev asynchronous HTTP client"
  :version "0.1.0"
  :author "Me"
  :license "MIT"
  ;; :depends-on (#:lev #:fast-http #:quri #:cffi #:cl+ssl)
  :depends-on (:cffi :lev :usocket :fast-http :fast-io :babel)
  :serial t
  :components ((:file "package")
               (:module "src"
                :serial t
                :components ((:file "util")
                             (:file "derecho")
                             ;(:file "conditions")
                             ;(:file "socket")
                             ;(:file "tls")
                             ;(:file "request")
                             ;(:file "client")
                              ))))
