+++
title = "Monto Version 3 Specification, Draft 1"
+++

# TODOs

 - What error should the broker return if a service dies during a request?
 - What if the service can't be reached at all?
   - Hard failure or soft?

# Abstract

This specification describes an improved iteration of the Monto protocol for Disintegrated Development Environments {{% ref monto %}}. These improvements allow for simpler implementations for Clients. They also make it feasible to have multiple Clients sharing a single Service.

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
: A single JSON value sent as an HTTP request or response.

Product
: Structured data sent between Clients, Brokers, and Services.

Client Protocol
: The protocol used to communicate between Clients and Brokers.

Service Protocol
: The protocol used to communicate between Brokers and Services.

Monto Protocols
: The Client Protocol and Service Protocol.

# 2. Introduction

Monto makes it easy to interface the information provided by a language's compiler with various editors, without the compiler developer needing to implement language support for each editor. Unfortunately, the native APIs of various popular editors vary widely with respect to how well they support the features required by Monto, namely the ability to bind to ØMQ {{% ref zeromq %}} and the relatively large amount of client-side "bookkeeping" to be done.

This document suggests changes to the Monto Protocols which are focused on removing the ZeroMQ requirement and simplifying the protocol that the client has to support as much as possible. As these changes are not backwards compatible with existing Clients and Services, these changes are collectively known as Monto Version 3.

# 3. Protocol Overview

The Monto Protocols are built on top of HTTP/2 {{% ref rfc7540 %}}, with each request being a POST request to a special Monto endpoint. Both request and response bodies are JSON {{% ref rfc7159 %}}. This allows for the reuse of the many technologies that are capable of debugging this relatively common protocol combination, such as mitmproxy {{% ref mitmproxy %}}, Postman {{% ref postman %}}, and others. Furthermore, almost every mainstream programming language supports HTTP and JSON, meaning the wide variety of client programming languages (e.g. CoffeeScript, Emacs Lisp, Java, Python, etc.) can all interoperate with it.

Both the Client Protocol and Service Protocol are versioned according to Semantic Versioning {{% ref semver %}}. This document describes Client Protocol version 3.0.0 and Service Protocol version 3.0.0.

Unless specified otherwise, a Message is serialized as JSON and sent with a Content-Type of `application/json`.

## 3.1. Common Messages

These Messages are shared by both the Client Protocol and the Service Protocol.

Messages are documented with JSON Schema {{% ref jsonschema %}}.

The schemas are also present in the "schemas" directory, which should accompany this document.

{{% draft01-message 3 1 1 Identifier %}}
{{% draft01-message 3 1 1 MontoVersion %}}
{{% draft01-message 3 1 1 NamespacedName %}}
{{% draft01-message 3 1 1 Product %}}
{{% draft01-message 3 1 1 ProductName %}}

# 4. The Client Protocol

The Client Protocol dictates communication between Clients and Brokers.

## 4.1. Connection Initiation

A Client SHALL initiate a connection to a Broker either when it starts, or when Monto capabilities are requested. Although Monto can operate over connections on any port, Clients SHOULD default to connecting to port 28888 on the current machine, and Brokers SHOULD default to serving on that port. Clients and Brokers SHOULD be able to connect to and serve on other ports, if configured to do so.

Upon initiating a connection to a Broker, a Client MUST attempt to use an HTTP/2 connection if the Client supports HTTP/2. If the Client does not, it SHALL use the same protocol, but over HTTP/1.1 {{% ref rfc7230 %}} instead. If a Client is using HTTP/1.1, it MAY open multiple connections to the server in order to have multiple requests "in flight" at the same time.

## 4.2. Version Negotiation

After the HTTP connection is established, the Client SHALL make a POST request to the `/monto/version` path, with a [`ClientNegotiation`](#4-5-1-clientnegotiation) Message as the body. The Broker SHALL check that it is compatible with the Client. The Broker SHALL respond with a [`ClientBrokerNegotiation`](#4-5-2-clientbrokernegotiation) Message. If the Broker is compatible with the Client, this response SHALL have an HTTP Status of 200. If the Broker and Client are not compatible, the response SHALL instead have an HTTP Status of 409.

If the HTTP Status is 200, the Client SHALL check that it is compatible with the Broker. If the HTTP Status is not 200 or the Client and Broker are not compatible as determined by the Client, the Client SHOULD inform the user and MUST close the connection.

Compatibility between versions of the Client Protocol SHALL be determined using the Semantic Versioning rules. Additionally, a Client MAY reject a Broker that is known to not follow this specification correctly, and vice versa.

If the intersection of the `extensions` field of the `ClientNegotiation` and `ClientBrokerNegotiation` Messages is nonempty, the corresponding extensions MUST be considered to be enabled by both the Client and the Broker. The semantics of an extension being enabled are left to that extension. All non-namespaced extensions are documented in the [Client Protocol Extensions](#4-6-client-protocol-extensions) section below.
 
## 4.3. Requesting Products

A Client SHALL request Products by making a POST request to the `/monto/products` path, with a [`ClientRequest`](#4-5-3-clientrequest) Message as the body.

If the `ClientRequest` Message contains requests for Products which a Service does not expose, or a request for Products from a Service that does not exist, the Broker SHALL respond with an HTTP Status of 400 and the [`ClientSingleRequest`](#4-5-4-clientsinglerequest) Message corresponding to the illegal request as the body.

Otherwise, the Broker SHALL respond with an HTTP Status of 200 and a [`BrokerResponse`](#4-5-5-brokerresponse) Message as the body. Each member of the `BrokerResponse` Message corresponds to one of the requests from the `ClientRequest` Message. No particular order is enforced; a Client MUST be able to handle a `BrokerResponse` Message whose elements have a different order from the requests in the `ClientRequest` Message.

When a Service responds to the Broker with an HTTP Status of 200, the corresponding BrokerSingleResponse MUST be a `BrokerProductResponse`. Conversely, when the Service responds to the Broker with a [`ServiceError`](TODO), the BrokerSingleResponse MUST be a `BrokerErrorResponse`. If another error occurs while retrieving the Product, the BrokerSingleResponse MUST be a `BrokerErrorResponse`. The `"value"` field SHOULD state that the error came from the Broker rather than the Service.

## 4.5. Client Protocol Messages

{{% draft01-message 4 5 1 ClientNegotiation %}}
{{% draft01-message 4 5 2 ClientBrokerNegotiation %}}
{{% draft01-message 4 5 3 ClientRequest %}}
{{% draft01-message 4 5 4 ClientSingleRequest %}}
{{% draft01-message 4 5 5 BrokerResponse %}}

## 4.6. Client Protocol Extensions

Once extensions have been thought through, documented, and have a reference implementation, they can be submitted to become un-namespaced, and will appear in this section.

# 5. The Service Protocol

The Service Protocol dictates communication between Brokers and Services.

## 5.1. Connection Initiation

A Broker SHALL initiate a connection to the Services requested by the user when it starts. Brokers MUST be able to connect to a Service on any port, and Services MUST be able to serve on any port.

Brokers MUST first attempt to use HTTP/2, and MAY support HTTP/1.1 as well. Services SHOULD support HTTP/2 if at all possible, as the pipelining it allows is more useful than for the Client Protocol, as it is more likely that there are several in-flight requests at once.

## 5.2. Version Negotiation

After the HTTP connection is established, the Broker SHALL make a POST request to the `/monto/version` path, with a [`BrokerVersion`](#421-brokerversion) Message as the body. The Service SHALL check that it is compatible with the Broker. The Service SHALL respond with a [`ServiceVersion`](#431-serviceversion) Message. If the Service is compatible with the Broker, this response SHALL have an HTTP Status of 200. If the Service and Broker are not compatible, the response SHALL instead have an HTTP Status of 409.

If the HTTP Status is 200, the Broker SHALL check that it is compatible with the Service. If the HTTP Status is not 200 or the Broker and Service are not compatible as determined by the Broker, the Broker SHOULD inform the user and MUST close the connection.

Compatibility between versions of the Service Protocol SHALL be determined using the Semantic Versioning rules. Additionally, a Broker MAY reject a Service that is known to not follow this specification correctly, and vice versa.

## 5.3. Requesting Products

To request Products, the Broker SHALL send a [`BrokerRequest`](#424-brokerrequest) Message to the appropriate Service. If the Service requires additional input Products to create the requested Product, it SHALL respond with a [`ServiceDependency`](#432-servicedependency) Message and an HTTP Status of 400. If the Service encountered another error (for example, a syntax error when requesting an outline), it SHALL respond with an HTTP status of 500 and a [`ServiceError`](#433-serviceerror) Message. If the requested Product was successfully created, it SHALL be returned directly (i.e. encoded as itself in JSON) with an HTTP status of 200.

## 5.4. Caching

TODO

## 5.5. Service Protocol Messages

{{% draft01-message 5 5 1 ServiceNegotiation %}}
{{% draft01-message 5 5 2 ServiceBrokerNegotiation %}}

## 5.6. Service Protocol Extensions

Once extensions have been thought through, documented, and have a reference implementation, they can be submitted to become un-namespaced, and will appear in this section.

# 6. Products

TODO

# 7. Security Considerations

## 7.1. Remote Access To Local Files

The Broker sends arbitrary files to Services, which may be running on a different machine. A malicious Service could therefore request a sensitive file (for example, `~/.ssh/id_rsa`). As a result, a Broker MAY claim such a file does not exist.

Furthermore, a security-conscious user MAY run the Broker in a virtual machine or container, only giving access to user files in specific directories.

## 7.2. Encrypted Transport

HTTP/2 optionally supports TLS encryption. Most HTTP/2 implementations require encryption, so Clients, Brokers, and Services MAY support TLS encryption. Due to the relative difficulty of obtaining a TLS certificate for a local Service, Clients MUST support connecting to a Broker that does not support TLS.

# 8. Further Work

## 8.1. Binary Encoding instead of JSON

A speed boost could potentially be gained by using CBOR {{% ref rfc7049 %}}, MessagePack {{% ref msgpack %}} or a similar format instead of JSON. This could be added in a backwards-compatible way by using the existing Content-Type negotiation mechanisms in HTTP if desired.

## 8.2. Asynchronous Communication

Re-adding support for asynchronous communication between Clients and Brokers as a protocol extension would be a desirable goal. This could be implemented either by polling, which is relatively efficient in HTTP/2, or with a chunked response in HTTP/1.1.

## 8.3. Commands

Previous versions of Monto supported arbitrary commands being run by the Service, for example, renaming a function everywhere it appears (in all files). This is difficult to do while allowing Services to be run on remote machines. It could be achieved by allowing Services to request file writes in addition to reads, but would probably require a large amount of overhead, and come with its own security risks.

## 8.4. Stateful Services

Some services inherently have state, such as debuggers. Unfortunately, this model does not translate well to the Monto Version 3 Protocol -- services may be shared with multiple brokers over the network. A possible solution would be to use a "state token," a unique identifier for each session.

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
