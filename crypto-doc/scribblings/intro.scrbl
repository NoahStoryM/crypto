#lang scribble/doc
@(require scribble/manual
          scribble/basic
          scribble/eval
          racket/runtime-path
          (for-label racket/base
                     racket/contract
                     racket/match
                     racket/random
                     crypto
                     crypto/libcrypto))

@(define-runtime-path log-file "eval-logs/intro.rktd")
@(define the-eval (make-log-based-eval log-file 'replay))
@(the-eval '(require crypto crypto/libcrypto racket/match))

@title[#:tag "intro"]{Introduction to the Crypto Library}

Cryptography is not security. It is a tool that may be used in some
cases to achieve security goals.

This library is not a turn-key solution to security. It is a library
of low-level cryptographic operations---or, in other words, just
enough rope for the unwary to hang themselves.

This manual assumes that you already know to use the cryptographic
operations properly. Every operation has conditions that must be
satisfied for the operation's security properties to hold; they are
not always well-advertised in documentation or literature, and they
are sometimes revised as new weaknesses or attacks are
discovered. Aside from the occasional off-hand comment, this manual
does not discuss them at all. You are on your own.


@section[#:tag "intro-crypto"]{Cryptography Examples}

In order to use a cryptographic operation, you need an implementation
of it from a crypto provider. Implementations are managed through
crypto factories. This introduction will use the factory for libcrypto
(OpenSSL), since it is widely available and supports many useful
cryptographic operations. See @secref["factory"] for other crypto
providers.

@interaction[#:eval the-eval
(require crypto)
(require crypto/libcrypto)
]

You can configure this library with a ``search path'' of crypto
factories:

@interaction[#:eval the-eval
(crypto-factories (list libcrypto-factory))
]

That allows you to perform an operation by providing a crypto
algorithm specifier, which is automatically resolved to an
implementation using the factories in @racket[(crypto-factories)]. For
example, to compute a message digest, call the @racket[digest]
function with the name of the digest algorithm:

@interaction[#:eval the-eval
(digest 'sha1 "Hello world!")
]

Or, if you prefer, you can obtain an algorithm implementation
explicitly:

@interaction[#:eval the-eval
(define sha1-impl (get-digest 'sha1 libcrypto-factory))
(digest sha1-impl "Hello world!")
]

To encrypt using a symmetric cipher, call the @racket[encrypt]
function with a cipher specifier consisting of the name of the cipher
and the cipher mode (see @racket[cipher-spec?] for details).

@interaction[#:eval the-eval
(define skey #"VeryVerySecr3t!!")
(define iv (make-bytes (cipher-iv-size '(aes ctr)) 0))
(encrypt '(aes ctr) skey iv "Hello world!")
]

Of course, using an all-zero IV is usually a very bad idea. You can
generate a random IV of the right size (if a random IV is
appropriate), or you can get the IV size and construct one yourself:

@interaction[#:eval the-eval
(define iv (generate-cipher-iv '(aes ctr)))
iv
(cipher-iv-size '(aes ctr))
]

There are also functions to generate session keys, HMAC keys,
etc. These functions use @racket[crypto-random-bytes], a
cryptographically strong source of randomness.

When an @tech{authenticated encryption} (AEAD) cipher, such as
AES-GCM, is used with @racket[encrypt] or @racket[decrypt], the
authentication tag is automatically appended to (or taken from) the
end of the cipher text, respectively. AEAD ciphers also support
@emph{additionally authenticated data}, passed with the @racket[#:aad]
keyword.

@interaction[#:eval the-eval
(define key (generate-cipher-key '(aes gcm)))
(define iv (generate-cipher-iv '(aes gcm)))
(define ct (encrypt '(aes gcm) key iv #"Nevermore!" #:aad #"quoth the raven"))
(decrypt '(aes gcm) key iv ct #:aad #"quoth the raven")
]

If authentication fails at the end of decryption, an exception is
raised:

@interaction[#:eval the-eval
(decrypt '(aes gcm) key iv ct #:aad #"said the bird")
]

In addition to ``all-at-once'' operations like @racket[digest] and
@racket[encrypt], this library also supports algorithm contexts for
incremental computation.

@interaction[#:eval the-eval
(define sha1-ctx (make-digest-ctx 'sha1))
(digest-update sha1-ctx #"Hello ")
(digest-update sha1-ctx #"world!")
(digest-final sha1-ctx)
]

@section[#:tag "intro-pk"]{Public-Key Cryptography Examples}

Public-key (PK) cryptography uses keypairs consisting of public and
private keys. A keypair can be generated by calling
@racket[generate-private-key] with the desired PK cryptosystem and an
association list of key-generation options. The private key consists
of the whole keypair---both private and public components. A key
containing only the public components can be obtained with the
@racket[pk-key->public-only-key] function.

@interaction[#:eval the-eval
(define rsa-impl (get-pk 'rsa libcrypto-factory))
(define privkey (generate-private-key rsa-impl '((nbits 512))))
(define pubkey (pk-key->public-only-key privkey))
]

RSA keys support both signing and encryption. Other PK cryptosystems
may support different operations; for example, DSA supports signing
but not encryption, and DH only supports key agreement.

PK signature algorithms are limited in the amount of data they can
sign directly, so the message is first processed with a digest
function, then the digest is signed. The @racket[digest/sign] and
@racket[digest/verify] functions compute the digest automatically. The
private key signs, and the public key verifies.

@interaction[#:eval the-eval
(define sig (digest/sign privkey 'sha1 "Hello world!"))
(digest/verify pubkey 'sha1 "Hello world!" sig)
(digest/verify pubkey 'sha1 "Transfer $100" sig)
]

It is also possible to sign a precomputed digest. The digest algorithm
is still required as an argument, because some signature schemes include a
digest algorithm identifier.

@interaction[#:eval the-eval
(define dgst (digest 'sha1 "Hello world!"))
(define sig (pk-sign-digest privkey 'sha1 dgst))
(pk-verify-digest pubkey 'sha1 (digest 'sha1 "Hello world!") sig)
(pk-verify-digest pubkey 'sha1 (digest 'sha1 "Transfer $100") sig)
]

Encryption is similar, except that the public key encrypts, and the
private key decrypts.

@interaction[#:eval the-eval
(define skey #"VeryVerySecr3t!!")
(define e-skey (pk-encrypt pubkey skey))
(pk-decrypt privkey e-skey)
]

The other PK operation is key agreement, or shared secret
derivation. Two parties exchange public keys, and each party uses
their own private key together with their peer's public key to derive
a shared secret.

For additional examples, see the @tt{crypto/examples} directory
(@hyperlink["https://github.com/rmculpepper/crypto/tree/master/crypto-doc/examples"]{online here}).

@(close-eval the-eval)
