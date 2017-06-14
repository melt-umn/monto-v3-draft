+++
title = "Differences"
+++

The Monto Version 3 protocol differs from Version 2 in several ways.

# HTTP/2 instead of ZeroMQ

ZeroMQ requires FFI, which is difficult in some editors and requires an
additional dependency in all. For example, to implement
[monto-mode](https://github.com/melt-umn/monto-mode), a Monto major mode
for emacs, the author needed to depend on
[elisp-ffi](https://github.com/skeeto/elisp-ffi), a package that provides
FFI for Emacs by spawning a subprocess and communicating with a custom
protocol over pipes. Needless to say, this is horrible and inefficient.
Emacs is a pathological case for this specific issue, due to its lack of
native support for FFI. It is still inconvenient to need to bind to ZeroMQ
from JavaScript, to use the example of Atom and/or Visual Studio Code.

Additionally, HTTP requests have a single, authoritative response. This
allows the client to wait for that single response and know that it
represents all requested information about the resource sent to the
broker. With ZeroMQ, it becomes a requirement to listen indefinitely for
an eventual response from a service that happens to be lagging behind.

The downside of waiting for a single response containing all the
information requested is that the time to get products becomes the
worst-case time. This is mitigated by making requests pull-based instead
of push-based.

# Stateless Services (Config not stored in the service)

The overhead is assumed to be negligible. In reality, it'll probably
amount to a few hundred bytes at most, which should take well under
a millisecond on any modern network. In exchange, it makes it feasible for
multiple brokers to be connected to a single service, and for services to
be much more easily written as pure functions.

If overhead becomes a serious problem, HTTP compression could probably be
used to minimize it.

# Pull-based instead of push-based

In Monto v2 (push-based), when a file is changed, it gets sent to the
broker, and the broker then walks the graph "forwards", trying to get
every possible product from the network of services.

In Monto v3 (pull-based), the client sends a list of products it wants to
the broker, which then walks the graph "backwards" to figure out how to
make all of them from the source code.

This makes predicting the responses the client will get much simpler, and
allows for greater granularity. This also mitigates the increase in
response time from the server, as only the products which are needed in
the short-term (e.g. highlighting) are requested immediately, while ones
that take longer (e.g. in-depth error checking) can be delayed until
requested.

# Broker handles file access

The original Monto spec doesn't (as far as I can tell) specify whether
services are allowed to perform direct filesystem access or not. For many
languages (including C), dynamic dependencies are insufficient to express
the search model the language uses for dependency resolution.

The service sending requests to the broker is done so that services can be
run on a different machine. The caching mechanism should lower the
overhead to a single roundtrip.

# Commands not implemented

I can't find a good way to reconcile "service might be on a different
machine" and "commands can perform arbitrary tasks" without having the
broker expose something quite like a *writable* filesystem to the service,
which feels hackish, inefficient, and insecure.

# Broker connects to a service

This is mainly to allow services to be shared. A downside is that setting
up Monto is no longer "zero-configuration," as the broker needs to be
informed where the services are.

This could be mitigated by using a service discovery protocol such as
mDNS, although the amount of work that would be required seems too high to
be worth pursuing in the short term.
