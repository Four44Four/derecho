# Purpose
 - Common Lisp asynchronous HTTP request client built for [libev](https://software.schmorp.de/pkg/libev.html) through [lev](https://github.com/fukamachi/lev)

## Dedepencies
 - [libev](https://software.schmorp.de/pkg/libev.html)
    - Arch Linux: `sudo pacman -S libev`
    - Ubuntu/Debian: `sudo apt install libev-dev`
    - MacOS: `brew install libev`
    - FreeBSD: `pkg install libev`

## Usage
```lisp
(drch:request *lev-ev-loop-ptr* "http://lisp.org")
```

## Run lint
 - `sbcl --script lint.lisp`

## Run tests
 - `sbcl --script run-tests.lisp`
