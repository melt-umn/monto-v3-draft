+++
title = "Monto Version 3 Specification, Draft 2"
+++

# TODOs

 - Document configuration
   - Stateful or stateless config in the client protocol?

# Abstract

This specification describes an improved iteration of the Monto protocol for Disintegrated Development Environments {{% ref monto %}}.
These improvements allow for simpler implementations for Clients.
They also make it feasible to have multiple Clients sharing a single Service, and for Services to be operated over the Internet (rather than on the local network or on a single machine).

# 1. Conventions and Terminology

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be interpreted as described in RFC 2119.

Other terms used in this specification are as follows.

Client
: An IDE, text editor, or other software directly controlled by the end user.

Broker
: A per-user piece of software that manages communication between Clients and Services.

Service
: A piece of software that receives Products from a Broker, and uses them to produce other Products in response.

Message
: A single JSON value sent as an HTTP request or response body.

Product
: Structured data sent between Clients, Brokers, and Services.

Client Protocol
: The protocol used to communicate between Clients and Brokers.

Service Protocol
: The protocol used to communicate between Brokers and Services.

Monto Protocols
: The Client Protocol and Service Protocol.

# 2. Introduction

Monto makes it easy to interface the information provided by a language's compiler with various editors, without the compiler developer needing to implement language support for each editor.
Unfortunately, the native APIs of various popular editors vary widely with respect to how well they support the features required by Monto, namely the ability to bind to ØMQ {{% ref zeromq %}} and the relatively large amount of client-side "bookkeeping" to be done.

This document suggests changes to the Monto Protocols which are focused on removing the ZeroMQ requirement and simplifying the protocol that the client has to support as much as possible.
As these changes are not backwards compatible with existing Clients and Services, these changes are collectively known as Monto Version 3.

# 3. Protocol Overview

The Monto Protocols are built on top of HTTP/2 {{% ref rfc7540 %}}, with each request being a POST request to a special Monto endpoint.
Both request and response bodies are JSON {{% ref rfc7159 %}}.
This allows for the reuse of the many technologies that are capable of debugging this relatively common protocol combination, such as mitmproxy {{% ref mitmproxy %}}, Postman {{% ref postman %}}, and others.
Furthermore, almost every mainstream programming language supports HTTP and JSON, meaning the wide variety of client programming languages (e.g. CoffeeScript, Emacs Lisp, Java, Python, etc.) can all interoperate with it.

Both the Client Protocol and Service Protocol are versioned according to Semantic Versioning {{% ref semver %}}.
This document describes Client Protocol version 3.0.0 and Service Protocol version 3.0.0.

Unless specified otherwise, a Message is serialized as JSON and sent with a Content-Type of `application/json`.

## 3.1. Common Messages

These Messages are shared by both the Client Protocol and the Service Protocol.

Messages are documented with JSON Schema {{% ref jsonschema %}}.

The schemas are also present in the "schemas" directory, which should accompany this document.

{{% draft02-message 3 1 1 Identifier %}}
{{% draft02-message 3 1 2 NamespacedName %}}
{{% draft02-message 3 1 3 Product %}}
{{% draft02-message 3 1 4 ProductDescriptor %}}
{{% draft02-message 3 1 5 ProductIdentifier %}}
{{% draft02-message 3 1 6 ProductName %}}
{{% draft02-message 3 1 7 ProtocolVersion %}}
{{% draft02-message 3 1 8 SoftwareVersion %}}

# 4. The Client Protocol

The Client Protocol dictates communication between Clients and Brokers.

## 4.1. Connection Initiation

A Client SHALL initiate a connection to a Broker either when it starts, or when Monto capabilities are requested.
Although Monto can operate over connections on any port, Clients SHOULD default to connecting to port 28888 on the current machine, and Brokers SHOULD default to serving on that port.
Clients and Brokers SHOULD be able to connect to and serve on other ports, if configured to do so.

Upon initiating a connection to a Broker, a Client MUST attempt to use an HTTP/2 connection if the Client supports HTTP/2.
If the Client does not, it SHALL use the same protocol, but over HTTP/1.1 {{% ref rfc7230 %}} instead.
If a Client is using HTTP/1.1, it MAY open multiple connections to the server in order to have multiple requests "in flight" at the same time.

## 4.2. Version Negotiation

After the HTTP connection is established, the Client SHALL make a POST request to the `/monto/version` path, with a [`ClientNegotiation`](#4-5-1-clientnegotiation) Message as the body.
The Broker SHALL check that it is compatible with the Client.
The Broker SHALL respond with a [`ClientBrokerNegotiation`](#4-5-2-clientbrokernegotiation) Message.
If the Broker is compatible with the Client, this response SHALL have an HTTP Status of 200.
If the Broker determines itself to not be compatible with the Client, the response SHALL instead have an HTTP Status of 400.

If the HTTP Status is 200, the Client SHALL check that it is compatible with the Broker.
If the HTTP Status is not 200 or the Client and Broker are not compatible as determined by the Client, the Client SHOULD inform the user and MUST not attempt further interaction.

Compatibility between versions of the Client Protocol SHALL be determined using the Semantic Versioning rules.
Additionally, a Client MAY reject a Broker that is known to not follow this specification correctly, and vice versa.

All further requests to the Broker MUST have a `Monto-Version` HTTP header with the version of the Client Protocol negotiated stored as a `MAJOR.MINOR.PATCH` string.
For example, to declare that version 3.0.0 of the Client Protocol is in use, the header `Monto-Version: 3.0.0` would be sent.

If the intersection of the `extensions` field of the [`ClientNegotiation`](#4-5-1-clientnegotiation) and [`ClientBrokerNegotiation`](#4-5-2-clientbrokernegotiation) Messages is nonempty, the corresponding extensions SHALL be considered to be enabled by both the Client and the Broker.
The semantics of an extension being enabled are left to that extension.
All non-namespaced extensions are documented in the [Client Protocol Extensions](#4-6-client-protocol-extensions) section below.

If a non-zero number of extensions are enabled, all requests from the Client to the Broker and all responses from the Broker to the Client MUST have `Monto-Extension` HTTP headers for each extension.
For example, if the extensions `com.acme/foo` and `org.example/bar` are enabled, the headers `Monto-Extension: com.acme/foo` and `Monto-Extension: org.example/bar` would be sent.

## 4.3. Sending Products

When the user makes a change to a file that is not reflected by the file system, the Client SHOULD send the corresponding Product to the Broker.

To send a Product from the Client to the Broker, the Client SHALL make a PUT request to the `/monto/broker/[product-type]` path, where `[product-type]` corresponds to the type of Product being sent.
This is usually [`source`](#6-4-source) for a typical editor, although structural editors may send a different product type.
Additionally, the query string portion of the request URI MUST have a `path` key whose value is the path of the file that was sent.
A Client that knows the language the file is in SHOULD also add a `language` key whose value is the language of the file.

The body of the request SHALL be the Product being sent, with a `Content-Type` of `application/json`.
As a special case, if the Product being sent is a [`source`](#6-4-source) Product, the `Content-Type` MAY be `text/plain`.
In that case, the body of the request SHALL be the literal content of the [`source`](#6-4-source) Product.

If the `language` query parameter is not present, the Broker SHOULD attempt to detect it.
If it cannot be detected, the Broker MUST respond with an HTTP Status of 400 and a [`BrokerPutError`](#4-5-3-brokerputerror) Message with the `no_language` type as the body.
Otherwise, the Broker MUST respond with an HTTP Status of 204 and an empty body.

## 4.4. Requesting Products

A Client SHALL request Products by making a GET request to the `/monto/[service-id]/[product-type]` path, where `[product-type]` corresponds to the type of of Product being requested.
Additionally, the query string portion of the request URI MUST have `path` and `language` keys corresponding to the path and language corresponding to the Product being requested.

If the Service given by `[service-id]` does not exist, the Broker SHALL respond with an HTTP Status of 400 and a [`BrokerGetError`](#4-5-4-brokergeterror) Message with the `no_such_service` type as the body.

If the Product named by `[product-type]` is not exposed by the Service given by `[service-id]`, the Broker SHALL respond with an HTTP Status of 400 and a [`BrokerGetError`](#4-5-4-brokergeterror) Message with the `no_such_product` type as the body.

If the Product can be successfully computed, the Broker MUST respond with an HTTP Status of 200 and the Product as the body.
If the Product cannot be computed due to an error from a Service, the Broker MUST respond with an HTTP Status of 502 and a [`BrokerGetError`](#4-5-4-brokergeterror) Message with the `service_error` type as the body.
If the Product cannot be computed due to an error when connecting to a Service, the Broker MUST respond with an HTTP Status of 502 and a [`BrokerGetError`](#4-5-4-brokergeterror) Message with the `service_connect_error` type as the body.
If the Product cannot be computed due to an internal error, the Broker MUST respond with an HTTP Status of 500 and a [`BrokerGetError`](#4-5-4-brokergeterror) Message as the body.

## 4.5. Client Protocol Messages

{{% draft02-message 4 5 1 ClientNegotiation %}}
{{% draft02-message 4 5 2 ClientBrokerNegotiation %}}
{{% draft02-message 4 5 3 BrokerPutError %}}
{{% draft02-message 4 5 4 BrokerGetError %}}

## 4.6. Client Protocol Extensions

Currently, there are no built-in extensions defined for the Client Protocol.
However, a Client or Broker MAY support arbitrary extensions whose names are in the form of the [`NamespacedName`](#3-1-2-namespacedname) above.
These extensions are vendor-specific, and thus not specified here.

# 5. The Service Protocol

The Service Protocol dictates communication between Brokers and Services.

## 5.1. Connection Initiation

A Broker SHALL initiate a connection to the Services requested by the user when it starts.
Brokers MUST be able to connect to a Service on any port, and Services MUST be able to serve on any port.

Brokers MUST first attempt to use HTTP/2, and MAY support HTTP/1.1 as well.
Services SHOULD support HTTP/2 if at all possible, as the pipelining it allows is more useful than for the Client Protocol, as it is more likely that there are several in-flight requests at once.

## 5.2. Version Negotiation

After the HTTP connection is established, the Broker SHALL make a POST request to the `/monto/version` path, with a [`ServiceBrokerNegotiation`](#5-4-1-servicebrokernegotiation) Message as the body.
The Service SHALL check that it is compatible with the Broker.
The Service SHALL respond with a [`ServiceNegotiation`](#5-4-2-servicenegotiation) Message.
If the Service is compatible with the Broker, this response SHALL have an HTTP Status of 200.
If the Service and Broker are not compatible, the response SHALL instead have an HTTP Status of 409.

If the HTTP Status is 200, the Broker SHALL check that it is compatible with the Service.
If the HTTP Status is not 200 or the Broker and Service are not compatible as determined by the Broker, the Broker MUST close the connection.
In this situation, the Broker SHOULD log this event, and MAY choose to ignore the Service's existence.

Compatibility between versions of the Service Protocol SHALL be determined using the Semantic Versioning rules.
Additionally, a Broker MAY reject a Service that is known to not follow this specification correctly, and vice versa.

If the intersection of the `extensions` field of the `ServiceBrokerNegotiation` and `ServiceNegotiation` Messages is nonempty, the corresponding extensions MUST be considered to be enabled by both the Client and the Broker.
The semantics of an extension being enabled are left to that extension.
All non-namespaced extensions are documented in the [Service Protocol Extensions](#5-6-service-protocol-extensions) section below.

If a non-zero number of extensions are enabled, all requests from the Broker to the Service and all responses from the Service to the Broker MUST have a `Monto-Extensions` HTTP header with a space-separated list of the enabled extensions, sorted lexicographically.
For example, if the extensions `com.acme/foo` and `org.example/bar` are enabled, the header would read `Monto-Extensions: com.acme/foo org.example/bar`.
The header MAY be present with an empty value when no extensions are enabled.

## 5.3. Requesting Products

The broker SHALL request a Product from a Service by making a POST request to the `/monto/service` path, with a [`BrokerRequest`](#5-4-3-brokerrequest) as the body.

If the `BrokerRequest` Message contains a request for a Product which the Service does not expose, the Service MUST respond with an HTTP Status of 400 with the `ProductIdentifier` of the failed `BrokerRequest` as the body.

If the Service is unable to create the requested Product from the Products present in the `BrokerRequest`, the Service MUST respond with an HTTP Status of 500 and a `ServiceErrors` Message using the `ServiceErrorUnmetDependency` variant as the body.

If the Service encounters some other error, the Service MUST respond with an HTTP Status of 500 and a `ServiceErrors` Message using the `ServiceErrorOther` variant as the body.

Otherwise, the Service MUST respond with an HTTP Status of 200 and a [`ServiceProduct`](#5-4-5-serviceproduct) Message containing the requested Product as the Body.

## 5.4. Service Protocol Messages

{{% draft02-message 5 4 1 ServiceBrokerNegotiation %}}
{{% draft02-message 5 4 2 ServiceNegotiation %}}
{{% draft02-message 5 4 3 BrokerRequest %}}
{{% draft02-message 5 4 4 ServiceErrors %}}
{{% draft02-message 5 4 5 ServiceProduct %}}
{{% draft02-message 5 4 6 ServiceNotice %}}

## 5.5. Optimizations

The naïve Broker dependency-resolution algorithm is rather inefficient, and can be optimized in several ways.

### 5.5.1. Caching the Dependency Graph

Typically, a source file's current dependencies are very similar to its past dependencies.
This can be taken advantage of by caching the dependencies of a specific Product and requesting its dependencies before requesting the final Product.
This potentially could result in more work being done that needed (as a no-longer needed dependency is still computed).
Most edit actions don't affect the dependency graph, though, so this approach is efficient in the general case.

### 5.5.2. Inferring Dependencies

The semantics specified here intentionally do not specify in what order the Broker should query Services to obtain a Product.
This allows a Broker to attempt to infer the dependencies a particular Product will have.
Although no heuristics are described here, they could in principle be developed and applied.

## 5.6. Service Protocol Extensions

Currently, there are no built-in extensions defined for the Service Protocol.
However, a Broker or Service MAY support arbitrary extensions whose names are in the form of the `NamespacedName` above.

# 6. Products

Some fields are in common between most Product types.
The main two are `startByte` and `endByte`.
They represent the start and end of a selection of text from the corresponding source code.
`startByte` is inclusive, while `endByte` is exclusive.
The usage of "byte" in their names is significant -- these MUST be the the byte indexes, rather than the character indexes.

{{% draft02-product 6 1 directory %}}
{{% draft02-product 6 2 errors %}}
{{% draft02-product 6 3 highlighting %}}
{{% draft02-product 6 4 source %}}

# 7. Security Considerations

## 7.1. Remote Access To Local Files

The Broker sends arbitrary files to Services, which may be running on a different machine.
A malicious Service could therefore request a sensitive file (for example, `~/.ssh/id_rsa`).
As a result, a Broker MAY claim such a file does not exist.

Furthermore, a security-conscious user MAY run the Broker in a virtual machine or container, only giving access to user files in specific directories.

## 7.2. Encrypted Transport

HTTP/2 optionally supports TLS encryption.
Most HTTP/2 implementations require encryption, so Clients, Brokers, and Services SHOULD support TLS encryption.
Due to the relative difficulty of obtaining a TLS certificate for a local Service, Clients SHOULD support connecting to a Broker that does not support TLS or uses a self-signed certificate.

# 8. Further Work

## 8.1. Binary Encoding instead of JSON

A speed boost could potentially be gained by using CBOR {{% ref rfc7049 %}}, MessagePack {{% ref msgpack %}} or a similar format instead of JSON.
This could be added as a simple protocol extension.

## 8.2. Asynchronous Communication

Re-adding support for asynchronous communication between Clients and Brokers as a protocol extension could be implemented as a protocol extension either by polling, which is relatively efficient in HTTP/2, or with a chunked response in HTTP/1.1.

## 8.3. Commands

Previous versions of Monto supported arbitrary commands being run by the Service, for example, renaming a function everywhere it appears (in all files).
This is difficult to do while allowing Services to be run on remote machines.
It could be achieved by allowing Services to request file writes in addition to reads, but would probably require a large amount of overhead, and come with its own security risks.

## 8.4. Stateful Services

Some services inherently have state, such as debuggers.
Unfortunately, this model does not translate well to the Monto Version 3 Protocol -- services may be shared with multiple brokers over the network.
A possible solution would be to use a "state token," a unique identifier for each session.

## 8.5. Caching Products

Most projects' dependencies contains more source code than the projects themselves -- the dependencies' source code is unlikely to change, and it is wasteful to send it over the network with each request.
A simple Service Protocol Extension that remedies this problem would be a caching mechanism, in which the Broker would send an opaque identifier (e.g. a SHA-256 hash) for the dependencies instead of the dependencies themselves.
A Service could then either use a cached copy, if one exists, or fail with an error similar to the `ServiceErrorUnmetDependency` error if the dependency is not in the cache.

## 8.6. Incremental Product Transfer

The next step on the above would be to send all changes to files as deltas from a previous state.
This would greatly decrease the amount of network bandwidth required, and would be a relatively minor variation on the above.

## 8.7. Incremental Compilation

Once an incremental transfer system exists, full incremental compilation is easy to support.
A Service would only have to cache the last Product cooresponding to the input, and then could use it in the next compilation for that Product.

## 8.8. Flow Control

This would be a simple Client Protocol Extension adding a `flow_control` error possibility.
When the Broker detects that requests for Products are being sent faster than Services can fulfill them, it sends this error.

# 9. References

## 9.1. Normative References

{{< ref-citation jsonschema >}}
Wright, A., Ed., and H. Andrews, Ed., "JSON Schema: A Media Type for Describing JSON Documents", [draft-wright-json-schema-01](https://tools.ietf.org/html/draft-wright-json-schema-01), April 2017.
{{< /ref-citation >}}

{{< ref-citation mitmproxy >}}
"mitmproxy - home", [https://mitmproxy.org/](https://mitmproxy.org/).
{{< /ref-citation >}}

{{< ref-citation monto >}}
Keidel, S., Pfeiffer, W., and S. Erdweg., "The IDE Portability Problem and Its Solution in Monto", [doi:10.1145/2997364.2997368](http://dx.doi.org/10.1145/2997364.2997368), November 2016.
{{< /ref-citation >}}

{{< ref-citation msgpack >}}
Furuhashi, S., "MessagePack: It's like JSON, but fast and small.", [https://msgpack.org/](https://msgpack.org/).
{{< /ref-citation >}}

{{< ref-citation postman >}}
"Postman | Supercharge your API workflow", [https://www.getpostman.com/](https://www.getpostman.com/).
{{< /ref-citation >}}

{{< ref-citation rfc2119 >}}
Bradner, S., "Key words for use in RFCs to Indicate Requirement Levels", [BCP 14](https://tools.ietf.org/html/bcp14), [RFC 2119](https://tools.ietf.org/html/rfc2119), March 1997.
{{< /ref-citation >}}

{{< ref-citation rfc7049 >}}
Bormann, C., and P. Hoffman, "Concise Binary Object Representation (CBOR)", [RFC 7049](https://tools.ietf.org/html/rfc7049), October 2013.
{{< /ref-citation >}}

{{< ref-citation rfc7159 >}}
Bray, T., "The JavaScript Object Notation (JSON) Data Interchange Format", [RFC 7159](https://tools.ietf.org/html/rfc7159), March 2014.
{{< /ref-citation >}}

{{< ref-citation rfc7230 >}}
Fielding, R., Ed., and J. Reschke, Ed., "Hypertext Transfer Protocol (HTTP/1.1): Message Syntax and Routing", [RFC 7230](https://tools.ietf.org/html/rfc7230), June 2014.
{{< /ref-citation >}}

{{< ref-citation rfc7540 >}}
Belshe, M., Peon, R., and M. Thomson, Ed., "Hypertext Transfer Protocol Version 2 (HTTP/2)", [RFC 7540](https://tools.ietf.org/html/rfc7540), May 2015.
{{< /ref-citation >}}

{{< ref-citation semver >}}
"Semantic Versioning 2.0.0", [http://semver.org/spec/v2.0.0.html](http://semver.org/spec/v2.0.0.html).
{{< /ref-citation >}}

{{< ref-citation zeromq >}}
"Distributed Messaging - zeromq", [http://zeromq.org/](http://zeromq.org/).
{{< /ref-citation >}}
