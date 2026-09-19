# Purpose
 - Common Lisp asynchronous HTTP request client built for [libev](https://software.schmorp.de/pkg/libev.html) through [lev](https://github.com/fukamachi/lev)

# Usage
```lisp
(drch:request *lev-ev-loop-ptr* "http://lisp.org")
```

# Run lint
 - `sbcl --script lint.lisp`

# Run tests
 - `sbcl --script run-tests.lisp`
