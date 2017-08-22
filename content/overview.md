+++
title = "Overview, Justifications, and FAQs"
+++

**Note**: This document has some overlap with the [Differences]({{< relref "differences.md" >}}) document; read that too.

# Overview of Monto 3

Monto 3 is split into two "subprotocols," the Client Protocol and the Service Protocol.
This is done so that changes and extensions can be made to each one individually.

For example, adding [multi-user caching for services]({{< relref "draft02/index.md#8-5-caching-products" >}}) to the specification requires no differences in the Client Protocol, so it does not require bumping the Client Protocol version number.
Old clients would therefore still work with these changes.

## Client Protocol

Once the client is connected to the broker (see the [spec]({{< relref "draft02/index.md#4-1-connection-initiation" >}})), there are two operations that can be performed: send a product to the broker and request a product from the broker.

These have the approximate type signatures:

```haskell
-- The name of a type of product. Other than CustomProduct, these are given in
-- the spec.
data ProductName
  = Directory
  | Errors
  | Highlighting
  | Source
  | CustomProduct Identifier

-- The name of a programming language.
type Language = String

-- A single product.
type Product = Product a
  { name :: ProductName
  , language :: Language
  , path :: String
  , contents :: a
  }

sendProduct :: Product a -> ()
requestProduct :: ProductName Language String -> Either BrokerGetError a
```

The envisioned usage is something like this:

 - Whenever the user edits the file, the Client sends the Source Product representing the file to the Broker.
 - Whenever an updated product is needed, the Client requests it from the Broker.

## Service Protocol

In the Service Protocol, the Broker "calls into" the Service.

The service therefore has to expose the functions:

```haskell
-- A product that can contain any sort of contents.
type GenericProduct = Product Json

-- A list of the supported (ProductName, Language) combinations to request.
functions :: [(ProductName, Language)]

-- Non-error messages sent by the service.
data Notice
  = UnusedDependency ProductName Language FilePath

-- Errors from the service.
data Error
  = UnmetDependency ProductName Language FilePath
  | Other String

-- Runs a specific function.
request :: ProductName -- The name of the requested product.
        -> Language -- The language of the requested product.
		-> FilePath -- The path the product is requested for.
		-> [GenericProduct] -- The dependencies provided by the Broker.
		-> (Either [Error] (Product a), [Notice])
```

The Broker then handles resolving dependencies, etc.

# Justifications / FAQs

## Why have synchronous RPCs instead of asynchronous messages?

 - It's hard to error-handle the lack of a response
   - The most reasonable method is to put a cap on the amount of time allowed to be spent waiting for a response
   - However, this creates the issue that a slow response is equivalent to a failing one
   - Some errors (e.g. service is misconfigured) should **not** be silent!
 - Only the needed products are computed
   - Since the products wanted are explicitly requested, expensive but infrequently-wanted products (e.g. unit test coverage) are not computed every change.
 - Service discovery is easy
   - The Broker simply sends the Client what amounts to a list of type signatures, so the client knows what to expect ahead of time
 - A lot simpler to implement
   - `curl "http://localhost:28888/monto/com.example.service/errors?path=/projects/foo/bar.c&language=c"` is all you need to request a product
 - No ZeroMQ needed
   - If you want a rant, ask me about connecting to ZeroMQ from Emacs Lisp
   - ZeroMQ seems to not handle version-compatibility between different versions of itself?
   - Has two different Java bindings, which seem to speak different versions of the protocol
   - In more practical terms, it's another dependency.

## Why have a (literally!) 20-page spec instead of a common-sense document?

> If you don't start with a spec, every piece of code you write is a patch.
>
> -- Leslie Lamport

Basically, it should be possible to implement Monto without reading a single line of code outside of the spec.
And if you want an overview, that's in this document.

## Why HTTP? Why not *x* instead?

(See [here]({{< relref "differences.md#http-2-instead-of-zeromq" >}}) for the specific case of *x* = ZeroMQ)

If you're reading this document, your computer already has an HTTP client installed.
A large variety of high-quality HTTP clients and services are available in many languages, and there are a great many tools to work with HTTP (Postman, Wireshark, mitmproxy, etc.).

If services are on localhost, the transport protocol is essentially negligible unless it becomes a bottleneck.
HTTP is well-enough known and used that a large number of highly optimized, high-quality implementations are available, so it will almost definitely not be the bottleneck.
If the service is on the network, HTTP is an even better choice, as some networks block non-HTTP requests.
Furthermore, HTTPS is a high-quality, well-known, already-implemented solution to security for service communication on the network.
