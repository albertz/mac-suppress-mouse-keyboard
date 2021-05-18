# Suppress mouse & keyboard events on MacOSX

Catches all events (mouse, keyboard, everything),
and either consumes them (locked state)
or passes them through (unlocked state).
The locked state can be switched by the magic keyboard sequences
"lock31337" for locking, or "unlock" for unlocking.
(Remember this before you run the binary!)

## Installation

    clang -o event-trap.bin event-trap.m -framework Cocoa

## Usage

    sudo ./event-trap.bin

## References and related work

Related is also kiosk-mode.

* [Installation up 4evr](https://github.com/laserpilot/Installation_Up_4evr)
* [filmothek-mavericks-kiosk](https://github.com/tschiemer/filmothek-kiosk-osx)
* [Safe Exam Browser for macOS and iOS](https://github.com/SafeExamBrowser/seb-mac)
* [Cat-proofing a MacBook keyboard](https://www.mackungfu.org/cat-proofing-a-macbook-keyboard)

(In my case, I needed to baby-proof my Mac.)
