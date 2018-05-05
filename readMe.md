## UnfairPlay

#### A new approach at iOS app decryption

Electra is a modern jailbreak by Coolstar. One of the issues is that apps do not respect `DYLD_INSERT_LIBRARIES` unless some special calls are made. I attemped to "platformize" apps with this method, and it failed. I wrote this tool to use existing features of the jailbreak to load libraries into a target binary instead.

### Thanks to lordscotland

The decryption library used was written by lordscotland, and is available on his [dump](https://bitbucket.org/lordscotland/dump/src/master/decrypt.c) repository 
