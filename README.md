# Purpose
 - Common Lisp asynchronous HTTP request client built for [libev](https://software.schmorp.de/pkg/libev.html) through [lev](https://github.com/fukamachi/lev)

## Usage
 - Entire body at once
```lisp
(drch:request *lev-ev-loop-ptr* "http://lisp.org"
              :method :get
              :on-status #'(lambda (status-in)
                           (format t "Response status: ~D~%" status-in))
              :on-header #'(lambda (name-in value-in)
                           (format t "Found response header name and value: ~A :: ~A~%" name-in value-in))
              :on-body #'(lambda (body-in)
                         (format t "Full response body: ~A~%" body-in)))
```
 - Response body in chunks
```lisp
(drch:request *lev-ev-loop-ptr* "http://lisp.org"
              :method :get
              :no-collect-body-p t
              :on-status #'(lambda (status-in)
                           (format t "Response status: ~D~%" status-in))
              :on-header #'(lambda (name-in value-in)
                           (format t "Found response header name and value: ~A :: ~A~%" name-in value-in))
              :on-chunk #'(lambda (byte-buffer-in start-pos-in end-pos-in)
                          (format t "Received response body chunk: ~A~%" (babel:octets-to-string byte-buffer-in
                                                                                                 :start start-pos-in :end end-pos-in))))
```
 - With body and custom headers
```lisp
(drch:request *lev-ev-loop-ptr* "http://my-database.com/insert"
              :method :post
              :no-collect-body-p t
              :on-status #'(lambda (status-in)
                           (format t "Response status: ~D~%" status-in))
              :on-header #'(lambda (name-in value-in)
                           (format t "Found response header name and value: ~A :: ~A~%" name-in value-in))
              :headers #(:content-type "application/json"
                         :connection "close")
              :body "{\"username\": \"John Lisp\", \"Age\": 67, \"password\": \"1234567890zxcvbnm\"}")
```
 - Request body in chunks
```lisp
(let ((data-frame (make-array 30))
      (k 0))
  ;; 30 rows of 1,000,000 random bytes
  (dotimes (i (length data-frame))
    (let ((row (make-array 1000000 :element-type '(unsigned-byte 8))))
      (dotimes (j (length row))
        (setf (aref row j) (random 256)))
      (setf (aref data-frame i) row)))

  (drch:request *lev-ev-loop-ptr* "http://my-database.com/insert"
                :method :post
                :no-collect-body-p t
                :on-status #'(lambda (status-in)
                             (format t "Response status: ~D~%" status-in))
                :on-header #'(lambda (name-in value-in)
                             (format t "Found response header name and value: ~A :: ~A~%" name-in value-in))
                :headers #(:content-type "application/octet-stream"
                           :connection "close")
                :body #'(lambda ()
                        (multiple-value-prog1 (values (aref data-frame k) 
                                                      (= k (1- (length data-frame))))
                          (incf k)))))
```

## External dedepencies
 - [libev](https://software.schmorp.de/pkg/libev.html)
    - Arch Linux: `sudo pacman -S libev`
    - Ubuntu/Debian: `sudo apt install libev-dev`
    - MacOS: `brew install libev`
    - FreeBSD: `pkg install libev`
 - [OpenSSL](https://openssl-library.org/)
    - Arch Linux: `sudo pacman -S openssl pkgconf base-devel`
    - Ubuntu/Debian: `sudo apt install libssl-dev`
    - MacOS: `brew install openssl`
    - FreeBSD: `pkg install openssl`

## Run lint
 - `sbcl --script lint.lisp`

## Run tests
 - `sbcl --script run-tests.lisp`
