---
layout: rfc
title: "Monto Version 3 Specification, Draft 1"
---

# TODOs

 - What should the service error format be?
 - What error should the broker return if a service dies during a request?
 - What if the service can't be reached at all?
   - Hard failure or soft?

# Abstract

This specification describes an improved iteration of the Monto protocol
for Disintegrated Development Environments ([\[MONTO\]](#monto)). These
improvements allow for simpler implementations for Clients. They also make
it feasible to have multiple Clients sharing a single Service.

# 1. Conventions and Terminology

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT",
"SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this
document are to be interpreted as described in RFC 2119.

Other terms used in this specification are as follows.

Client
: An IDE, text editor, or other software directly controlled by the end
user.

Broker
: A per-user piece of software that manages communication between Clients
and Services.

Service
: A piece of software that receives Products from a Broker, and uses them
to produce other Products in response.

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

Monto makes it easy to interface the information provided by a language's
compiler with various editors, without the compiler developer needing to
implement language support for each editor. Unfortunately, the native APIs
of various popular editors vary widely with respect to how well they
support the features required by Monto, namely the ability to bind to ØMQ
([\[ZEROMQ\]](#zeromq)) and the relatively large amount of client-side
"bookkeeping" to be done.

This document suggests changes to the Monto Protocols which are focused on
removing the ZeroMQ requirement and simplifying the protocol that the client
has to support as much as possible. As these changes are not backwards
compatible with existing Clients and Services, these changes are
collectively known as Monto Version 3.

# 3. Protocol Overview

The Monto Protocols are built on top of HTTP/2 ([\[RFC7540\]](#rfc7540)),
with each request being a POST request to a special Monto endpoint. Both
request and response bodies are JSON ([\[RFC7159\]](#rfc7159)). This
allows for the reuse of the many technologies that are capable of
debugging this relatively common protocol combination, such as mitmproxy
([\[MITMPROXY\]](#mitmproxy)), Postman ([\[POSTMAN\]](#postman)), and
others. Furthermore, almost every mainstream programming language supports
HTTP and JSON, meaning the wide variety of client programming languages
(e.g. CoffeeScript, Emacs Lisp, Java, Python, etc.) can all interoperate
with it.

Both the Client Protocol and Service Protocol are versioned according to
Semantic Versioning ([\[SEMVER\]](#semver)). This document describes
Client Protocol version 3.0.0 and Service Protocol version 3.0.0.

Unless specified otherwise, a Message is serialized as JSON and sent with
a Content-Type of `application/json`.

## 3.1. The Client Protocol

The Client Protocol dictates communication between Clients and Brokers.

### 3.1.1. Connection Initiation

A Client SHALL initiate a connection to a Broker either when it starts, or
when Monto capabilities are requested. Although Monto can operate over
connections on any port, Clients SHOULD default to connecting to port
28888 on the current machine, and Brokers SHOULD default to serving on
that port. Clients and Brokers SHOULD be able to connect to and serve on
other ports, if configured to do so.

Upon initiating a connection to a Broker, a Client MUST attempt to use an
HTTP/2 connection if the Client supports HTTP/2. If the Client does not,
it SHALL use the same protocol, but over HTTP/1.1 instead. If a Client is
using HTTP/1.1, it MAY open multiple connections to the server in order
to have multiple requests "in flight" at the same time.

### 3.1.2. Version Negotiation

After the HTTP connection is established, the Client SHALL make a POST
request to the `/monto/version` path, with
a [`ClientVersion`](#411-clientversion) Message as the body. The Broker
SHALL check that it is compatible with the Client. The Broker SHALL
respond with a [`BrokerVersion`](#421-brokerversion) Message. If the
Broker is compatible with the Client, this response SHALL have an HTTP
Status of 200. If the Broker and Client are not compatible, the response
SHALL instead have an HTTP Status of 409.

If the HTTP Status is 200, the Client SHALL check that it is compatible
with the Broker. If the HTTP Status is not 200 or the Client and Broker
are not compatible as determined by the Client, the Client SHOULD inform
the user and MUST close the connection.

Compatibility between versions of the Client Protocol SHALL be determined
using the Semantic Versioning rules. Additionally, a Client MAY reject
a Broker that is known to not follow this specification correctly, and
vice versa.

### 3.1.3. Service Discovery

To perform Service discovery, the Client SHALL make a GET request to the
`/monto/services` path. The Broker SHALL respond with an HTTP Status of
200 and a [`BrokerServiceList`](#422-brokerservicelist) Message,
corresponding to the Services connected to the Broker.

### 3.1.4. Requesting Products

A Client SHALL request Products by making a POST request to the
`/monto/products` path, with a [`ClientRequest`](#412-clientrequest)
Message as the body.

For the purposes of dependency resolution, the "source" field of the
`ClientRequest` is a "source" product.

The Broker SHALL then acquire the appropriate Products, and respond with
an HTTP Status of 200 and a [`BrokerResponse`](#423-brokerresponse)
Message as the body.

TODO Document failure case, including request for files, cursor position, etc.
from client.

## 3.2. The Service Protocol

The Service Protocol dictates communication between Brokers and Services.

### 3.2.1. Connection Initiation

A Broker SHALL initiate a connection to the Services requested by the user
when it starts. Brokers MUST be able to connect to a Service on any port,
and Services MUST be able to serve on any port.

Brokers MUST first attempt to use HTTP/2, and MAY support HTTP/1.1 as
well. Services SHOULD support HTTP/2 if at all possible, as the pipelining
it allows is more useful than for the Client Protocol, as it is more
likely that there are several in-flight requests at once.

### 3.2.2. Version Negotiation

After the HTTP connection is established, the Broker SHALL make a POST
request to the `/monto/version` path, with
a [`BrokerVersion`](#421-brokerversion) Message as the body. The Service
SHALL check that it is compatible with the Broker. The Service SHALL
respond with a [`ServiceVersion`](#431-serviceversion) Message. If the
Service is compatible with the Broker, this response SHALL have an HTTP
Status of 200. If the Service and Broker are not compatible, the response
SHALL instead have an HTTP Status of 409.

If the HTTP Status is 200, the Broker SHALL check that it is compatible
with the Service. If the HTTP Status is not 200 or the Broker and Service
are not compatible as determined by the Broker, the Broker SHOULD inform
the user and MUST close the connection.

Compatibility between versions of the Service Protocol SHALL be determined
using the Semantic Versioning rules. Additionally, a Broker MAY reject
a Service that is known to not follow this specification correctly, and
vice versa.

### 3.2.3. Requesting Products

To request Products, the Broker SHALL send
a [`BrokerRequest`](#424-brokerrequest) Message to the appropriate
Service. If the Service requires additional input Products to create the
requested Product, it SHALL respond with
a [`ServiceDependency`](#432-servicedependency) Message and an HTTP Status
of 400. If the Service encountered another error (for example, a syntax
error when requesting an outline), it SHALL respond with an HTTP status of
500 and a [`ServiceError`](#433-serviceerror) Message. If the requested
Product was successfully created, it SHALL be returned directly (i.e.
encoded as itself in JSON) with an HTTP status of 200.

### 3.2.4. Caching

TODO

# 4. Messages

Messages are documented with JSON Schema ([\[JSONSCHEMA\]](#json-schema)).

## 4.1. Client Messages

### 4.1.1. `ClientVersion`

#### 4.1.1.1. Schema

```json
{% include schemas/ClientVersion.json %}
```

#### 4.1.1.2. Example

```json
{
	"monto": {
		"major": 3,
		"minor": 0,
		"patch": 0
	},
	"client": {
		"name": "Foo Client",
		"vendor": "ACME Inc.",
		"major": 0,
		"minor": 1,
		"patch": 0
	}
}
```

### 4.1.2. `ClientRequest`

#### 4.1.2.1. Schema

```json
{% include schemas/ClientRequest.json %}
```

#### 4.1.2.2. Example

```json
{
	"path": "/home/example/foo/bar.c",
	"request": [
		{
			"service": "com.example.quux",
			"product": "highlighting"
		},
		{
			"service": "com.example.quux",
			"product": "outline"
		},
		{
			"service": "com.example.xyzzy",
			"product": "errors"
		},
		{
			"service": "com.example.spam",
			"product": "com.example.spam/eggs"
		}
	]
}
```

## 4.2. Broker Messages

### 4.2.1. `BrokerVersion`

#### 4.2.1.1. Schema

```json
{% include schemas/BrokerVersion.json %}
```

#### 4.2.1.2. Example

```json
{
	"monto": {
		"major": 3,
		"minor": 0,
		"patch": 0
	},
	"broker": {
		"name": "Foo Broker",
		"vendor": "ACME Inc.",
		"major": 0,
		"minor": 1,
		"patch": 0
	}
}
```

### 4.2.2. `BrokerServiceList`

#### 4.2.2.1. Schema

```json
{% include schemas/BrokerServiceList.json %}
```

#### 4.2.2.2. Example

```json
[
	{
		"id": "com.example.quux",
		"name": "Quux as a Service",
		"vendor": "Example Vendor",
		"products": [
			"highlighting",
			"outline"
		],
		"config": {
			"type": "object",
			"properties": {
				"Debugging Symbols": { "type": "boolean" },
				"Include Path": {
					"type": "array",
					"items": { "type": "string" }
				},
				"Optimization Level": {
					"type": "integer",
					"minimum": 0,
					"maximum": 3
				}
			}
		}
	}
]
```

### 4.2.3. `BrokerResponse`

#### 4.2.3.1. Schema

```json
TODO
```

#### 4.2.3.2. Example

```json
TODO
```

## 4.3. Service Messages

### 4.3.1. `ServiceVersion`

#### 4.3.1.1. Schema

```json
{% include schemas/ServiceVersion.json %}
```

#### 4.3.1.2. Example

```json
TODO
```

# 5. Products

TODO

# 6. Security Considerations

## 6.1. Remote Access To Local Files

The Broker sends arbitrary files to Services, which may be running on
a different machine. A malicious Service could therefore request
a sensitive file (for example, `~/.ssh/id_rsa`). As a result, a Broker MAY
claim such a file does not exist.

Furthermore, a security-concious user MAY run the Broker in a virtual
machine or container, only giving access to user files in specific
directories.

## 6.2. Encrypted Transport

HTTP/2 optionally supports TLS encryption. Most HTTP/2 implementations
require encryption, so Clients, Brokers, and Services MAY support TLS
encryption. Due to the relative difficulty of obtaining a TLS certificate
for a local Service, Clients MUST support connecting to a Broker that does
not support TLS.

# 7. Further Work

## 7.1. Binary Encoding instead of JSON

A speed boost could potentially be gained by using CBOR
([\[RFC7049\]](#rfc7049)), MessagePack
([\[MSGPACK\]](http://msgpack.org/)) or a similar format instead of JSON.
This could be added in a backwards-compatible way by using the existing
Content-Type negotiation mechanisms in HTTP if desired.

## 7.2. Asynchronous Communication

Re-adding support for asynchronous communication between Clients and
Brokers on an opt-in basis would be a desirable goal. This could be
implemented either by polling, which is relatively efficient in HTTP/2, or
with a chunked response in HTTP/1.1.

## 7.3. Commands

Previous versions of Monto supported arbitrary commands being run by the
Service, for example, renaming a function everywhere it appears (in all
files). This is difficult to do while allowing Services to be run on
remote machines. It could be achieved by allowing Services to request file
writes in addition to reads, but would probably require a large amount of
overhead, and come with its own security risks.

# 8. References

## 8.1. Normative References

[](){:name="json-schema"}
[JSONSCHEMA]: Wright, A., Ed., and H. Andrews, Ed., "JSON Schema: A Media
Type for Describing JSON Documents",
[draft-wright-json-schema-01](https://tools.ietf.org/html/draft-wright-json-schema-01),
April 2017.

[](){:name="mitmproxy"}
[MITMPROXY]: "mitmproxy - home",
[https://mitmproxy.org/](https://mitmproxy.org/).

[](){:name="monto"}
[MONTO]: Keidel, S., Pfeiffer, W., and S. Erdweg., "The IDE Portability
Problem and Its Solution in Monto",
[doi:10.1145/2997364.2997368](http://dx.doi.org/10.1145/2997364.2997368),
November 2016.

[](){:name="msgpack"}
[MSGPACK]: Furuhashi, S., "MessagePack: It's like JSON, but fast and
small.", [https://msgpack.org/](https://msgpack.org/).

[](){:name="postman"}
[POSTMAN]: "Postman | Supercharge your API workflow",
[https://www.getpostman.com/](https://www.getpostman.com/).

[](){:name="rfc2119"}
[RFC2119]: Bradner, S., "Key words for use in RFCs to Indicate Requirement
Levels", [BCP 14](https://tools.ietf.org/html/bcp14), [RFC
2119](https://tools.ietf.org/html/rfc2119), March 1997.

[](){:name="rfc7049"}
[RFC7049]: Bormann, C., and P. Hoffman, "Concise Binary Object
Representation (CBOR)", [RFC 7049](https://tools.ietf.org/html/rfc7049),
October 2013.

[](){:name="rfc7159"}
[RFC7159]: Bray, T., "The JavaScript Object Notation (JSON) Data
Interchange Format", [RFC 7159](https://tools.ietf.org/html/rfc7159),
March 2014.

[](){:name="rfc7540"}
[RFC7540]: Belshe, M., Peon, R., and M. Thomson, Ed., "Hypertext Transfer
Protocol Version 2 (HTTP/2)", [RFC
7540](https://tools.ietf.org/html/rfc7540), May 2015.

[](){:name="semver"}
[SEMVER]: "Semantic Versioning 2.0.0",
[http://semver.org/spec/v2.0.0.html](http://semver.org/spec/v2.0.0.html).

[](){:name="zeromq"}
[ZEROMQ]: "Distributed Messaging - zeromq",
[http://zeromq.org/](http://zeromq.org/).
