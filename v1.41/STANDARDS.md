# SMART 64-Bit ID — Standards and Cryptography

**Standards Note v1.4**
**Date:** 2026-10-04
**Copyright:** © 2026 MD. AZIZUR RAHMAN
**Project:** SMART 64-Bit ID
**Organization:** SAMARA

---

## 1. Purpose

This document defines the standards boundary for cryptographic mechanisms used with SMART 64-Bit ID.

SMART ID itself defines an identifier structure and routing model.

It does not define a proprietary cryptographic algorithm.

Where cryptographic protection is used, the implementation is responsible for selecting and deploying appropriate mechanisms according to applicable standards and security requirements.

---

## 2. Cryptography Is an Implementation Boundary

SMART ID separates:

```text id="9yq7v2"
SMART ID
   │
   ├── Identity structure
   ├── Engine routing
   ├── Local identity
   └── Lifecycle metadata
            │
            ▼
     Application Security
            │
            ├── Authentication
            ├── Authorization
            ├── Integrity
            ├── Key management
            └── Cryptographic processing
```

The cryptographic layer does not redefine the SMART ID identity structure.

---

## 3. Format-Preserving Encryption

Format-preserving encryption (FPE) may be used when an implementation needs to provide a protected external representation while preserving a specified identifier format.

FPE is an optional implementation layer.

SMART ID does not require every deployment to use FPE.

Where FPE is used, it must be implemented using an appropriate standardized or otherwise approved cryptographic mechanism for the applicable environment.

---

## 4. Standards Requirement

SMART ID implementations that use format-preserving encryption and related cryptographic mechanisms **MUST use such mechanisms in accordance with applicable internationally recognized and approved cryptographic standards and their current authoritative revisions**.

This requirement applies to the implementation and deployment.

It does not mean that SMART ID itself is a certified cryptographic product.

---

## 5. No Proprietary Cryptographic Algorithm

SMART ID does not define or require a proprietary cryptographic algorithm.

The project intentionally leaves algorithm selection to the implementation subject to applicable standards, security requirements, and jurisdiction.

This separation allows cryptographic technologies to evolve without requiring the SMART ID identifier format itself to define a proprietary cryptographic primitive.

---

## 6. FPE Is Not Authentication

FPE transforms or protects representation of data.

It does not establish who is operating a system or requesting an identifier.

Therefore:

> **FPE must not be treated as authentication.**

An implementation must use an appropriate authentication mechanism where authentication is required.

---

## 7. FPE Is Not Authorization

Possession of a valid-looking public identifier does not establish permission to access the associated resource.

Therefore:

> **FPE must not be treated as authorization.**

Authorization must be enforced independently by the application or service.

---

## 8. FPE Is Not Integrity Protection

A cryptographic representation mechanism should not automatically be assumed to provide the integrity guarantees required by an application.

Where tamper detection or message integrity is required, the implementation must use an appropriate integrity mechanism.

SMART ID does not define such a mechanism.

---

## 9. Key Management

Cryptographic security depends substantially on key management.

Implementations using FPE or other cryptographic mechanisms are responsible for:

* secure key generation;
* secure key storage;
* access control;
* key rotation;
* key lifecycle management;
* compromise response;
* backup and recovery procedures; and
* appropriate separation of duties.

SMART ID does not define a key-management architecture.

---

## 10. Key Separation

Where multiple cryptographic purposes are used, implementations should consider appropriate key separation.

For example, keys used for public-ID transformation should not automatically be reused for unrelated security functions.

The exact key hierarchy and derivation strategy are implementation-specific and should follow applicable security standards and organizational policy.

---

## 11. Cryptographic Libraries

Implementations should use mature and appropriately maintained cryptographic libraries rather than implementing cryptographic primitives from scratch.

Library selection should consider:

* security history;
* maintenance status;
* supported algorithms;
* standards support;
* platform compatibility;
* vulnerability management; and
* applicable certification or validation requirements.

SMART ID does not mandate a particular cryptographic library.

---

## 12. Approved Algorithms and Mechanisms

The appropriate cryptographic mechanism depends on:

* jurisdiction;
* application;
* threat model;
* regulatory requirements;
* data sensitivity;
* interoperability requirements; and
* applicable standards.

Accordingly, SMART ID does not permanently prescribe one algorithm in this specification.

Implementations should select mechanisms that are currently recognized and approved for the intended environment.

---

## 13. International Standards Wording

The normative requirement is intentionally standards-agnostic:

> **SMART ID implementations MUST use format-preserving encryption and related cryptographic mechanisms in accordance with applicable internationally recognized and approved cryptographic standards and their current authoritative revisions.**

This wording avoids claiming that one named algorithm, library, certification program, or jurisdiction is universally applicable.

---

## 14. Certification Boundary

SMART ID v1.4 is not itself a cryptographic certification.

A project document referencing cryptographic standards does not establish certification.

Formal certification or validation depends on factors such as:

* the exact algorithm;
* implementation;
* library;
* configuration;
* hardware or execution environment;
* key management;
* testing;
* certification authority;
* jurisdiction; and
* applicable certification scheme.

Therefore the project must not claim that SMART ID itself is certified merely because an implementation uses a recognized cryptographic mechanism.

---

## 15. Security Architecture

Cryptographic protection should be considered one part of a broader security architecture.

A complete deployment may require:

* identity and access management;
* authentication;
* authorization;
* secure transport;
* data-at-rest protection;
* integrity controls;
* audit logging;
* key management;
* monitoring;
* incident response; and
* operational security controls.

SMART ID provides none of these automatically.

---

## 16. Public-ID Architecture

Where a deployment uses an internal SMART ID and a separate public identifier, the conceptual relationship may be:

```text id="z4t6h2"
Internal SMART ID
       │
       ▼
Public-ID transformation
       │
       ▼
External identifier
```

The public representation should be treated as an application-layer representation.

Routing may occur using the internal SMART ID after the appropriate application-level transformation or lookup.

The public representation does not change the underlying SMART ID semantics.

---

## 17. Security Boundary for Routing

SMART ID routing is an architectural function, not a security authorization decision.

The Engine field identifies the routing namespace.

An implementation must not assume that knowledge of an Engine or Local ID grants permission to access the associated record.

Routing and authorization are separate concerns.

---

## 18. Integrity and Validation

Implementations may validate SMART ID structure before accepting an identifier.

Validation may include:

* 64-bit format validation;
* Version validation;
* Reserved-bit validation;
* field extraction;
* range validation; and
* application-level consistency checks.

A validation failure should prevent invalid input from being processed as a valid SMART ID.

SMART ID does not define a checksum field.

---

## 19. No Checksum Requirement

SMART ID v1.4 does not reserve a checksum field.

The 64-bit layout is fixed.

If an application requires corruption detection, it may use an external integrity mechanism.

Examples include:

* authenticated transport;
* database integrity;
* message authentication;
* application-level signatures; or
* another appropriate mechanism.

These mechanisms are outside the SMART ID identifier format.

---

## 20. Serialization Security

SMART IDs should be serialized as strings in JSON and similar APIs when numeric precision cannot be guaranteed.

This avoids accidental conversion through a runtime numeric representation that cannot represent all 64-bit integers exactly.

Serialization correctness is an interoperability and data-integrity concern.

---

## 21. Secret Handling

Implementations must not expose cryptographic secrets through:

* public identifiers;
* logs;
* URLs;
* source repositories;
* configuration committed to version control;
* error messages; or
* public documentation.

Secret handling belongs to the deployment security architecture.

---

## 22. Logging

Applications using public identifiers should consider whether identifiers may expose sensitive operational information.

Logging policy should account for:

* identifier sensitivity;
* access controls;
* retention;
* redaction requirements;
* regulatory obligations; and
* incident-response needs.

SMART ID does not prescribe a logging policy.

---

## 23. Threat Model

The security requirements of an implementation depend on its threat model.

Possible threats include:

* unauthorized identifier discovery;
* identifier enumeration;
* unauthorized database access;
* compromised application credentials;
* compromised cryptographic keys;
* stale allocator access;
* malicious or accidental modification;
* replay;
* data leakage; and
* infrastructure compromise.

SMART ID addresses identifier structure and allocation integrity but does not independently solve these broader threats.

---

## 24. FPE and Enumeration

FPE may reduce exposure of the internal identifier representation in some public-ID designs.

However, cryptographic transformation does not by itself establish authorization.

Applications should therefore enforce access controls independently of whether a public identifier is encrypted or obfuscated.

---

## 25. Key Rotation

Cryptographic keys may require rotation according to organizational policy, threat assessment, or applicable standards.

Key rotation must be designed so that valid existing public identifiers remain manageable where required.

If multiple key generations must coexist, the implementation should define an appropriate key-versioning or migration strategy.

SMART ID does not consume additional identifier bits for this purpose.

---

## 26. Cryptographic Failure

If a required cryptographic operation fails, the application should fail the affected operation rather than silently fall back to an insecure or incompatible mechanism.

A cryptographic failure must not result in:

* plaintext secret exposure;
* unauthorized identifier acceptance;
* silent downgrade to an unapproved mechanism; or
* corrupted public-ID mappings.

---

## 27. Algorithm Agility

Because cryptographic standards evolve, implementations should maintain sufficient algorithm agility to replace mechanisms when required by:

* security developments;
* standards updates;
* vulnerabilities;
* regulatory changes;
* certification requirements; or
* organizational policy.

Algorithm agility must not alter the SMART ID v1.4 identity layout.

---

## 28. Implementation Responsibility

The implementation owner is responsible for determining:

* applicable standards;
* appropriate algorithms;
* approved libraries;
* key-management controls;
* deployment configuration;
* certification requirements;
* jurisdictional requirements; and
* security testing.

SMART ID provides the boundary within which these decisions are made.

---

## 29. Standards Updates

The phrase "current authoritative revisions" means that implementations should consult the authoritative source for the applicable standard rather than relying indefinitely on obsolete revisions.

Where a deployment is subject to a specific regulatory or contractual requirement, that requirement may impose additional constraints.

---

## 30. What SMART ID Does Not Claim

SMART ID v1.4 does not claim:

* proprietary cryptographic superiority;
* automatic authentication;
* automatic authorization;
* automatic confidentiality;
* automatic integrity protection;
* automatic compliance certification;
* universal regulatory compliance;
* a particular cryptographic algorithm for every deployment; or
* that FPE alone provides complete application security.

---

## 31. Summary

The SMART ID cryptographic boundary is intentionally simple:

**SMART ID defines identity and routing.**

**The application defines security policy.**

**The cryptographic implementation follows applicable recognized standards.**

**The deployment owner is responsible for keys, configuration, certification, and operational security.**

This separation keeps SMART ID v1.4 technically stable while allowing implementations to adopt appropriate cryptographic mechanisms as standards and security requirements evolve.
