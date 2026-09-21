# Purpose
 - Common Lisp asynchronous HTTP request client built for [libev](https://software.schmorp.de/pkg/libev.html) through [lev](https://github.com/fukamachi/lev)

## Usage
```lisp
(drch:request *lev-ev-loop-ptr* "http://lisp.org")
```

## Dedepencies
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
