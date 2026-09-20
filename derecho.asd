(defsystem #:derecho
  :description "Single-threaded libev/lev asynchronous HTTP client"
  :version "0.1.0"
  :author "Me"
  :license "MIT"
  :depends-on (:cffi :lev :usocket :fast-http :fast-io :babel :alexandria)
  :serial t
  :components ((:file "package")
               (:module "src"
                :serial t
                :components ((:file "customize")
                             (:file "util")
                             (:file "derecho")))))
