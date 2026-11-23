# SMART 64-Bit ID v1.42 — Serialization and Security Boundary

**Status:** Release Candidate 1 — cross-check in progress
**Status note:** Implementation guidance, except where a requirement is explicitly attributed to the normative specification.

## 1. Canonical binary representation

The v1.42 canonical binary representation is an unsigned 64-bit integer encoded in big-endian (network byte order). Bit 0 is the least-significant bit; bit 63 is the most-significant bit. Implementations using signed host-language integer types must preserve the same unsigned 64-bit value and extract fields with equivalent unsigned/logical-shift semantics.

Do not serialize the identifier using host byte order if canonical SMART binary interoperability is required. Do not silently convert to a signed value if that changes comparisons, numerical values, or extraction.

## 2. Field extraction

```text
Local    = ID & 0x1FFFFFFF
Engine   = (ID >> 29) & 0x1FFFFF
Class    = (ID >> 50) & 0x0F
Reserved = (ID >> 54) & 0x0F
Role     = (ID >> 58) & 0x01
Revision = (ID >> 59) & 0x0F
Version  = (ID >> 63) & 0x01
```

Validate the selected profile before interpreting profile-dependent fields. For v1.42, reject nonzero Reserved bits, encoded Class 0000, and encoded Class 1001–1111 in an allocated identifier. Verify that the encoded Class agrees with the authoritative Class-property record; disagreement is a hard stop. Bit 54 remains Reserved in v1.42; do not interpret it as part of Class.

Both Role values are valid in v1.42. S64-E010 ROLE_INVALID is an operation-level error (attempting to change Role in place), not a field-validation error; do not reject an identifier merely because it carries Role 0 or Role 1.

Within the input-format stage, formatting is validated before length: a malformed input that is also the wrong length reports S64-E011 MALFORMED_INPUT, not S64-E001 INVALID_LENGTH.

## 3. Identifier is not authentication

A SMART ID is an identifier, not a secret, credential, authenticator, or proof of identity. As conservative security guidance, possession or presentation of a SMART ID alone should not be treated as evidence of authorization or authenticity. Applications should enforce authentication and authorization independently.

SMART v1.42 does not define a proprietary cryptographic algorithm, a cryptographic signature scheme, format-preserving encryption, a key-management system, or an authentication protocol. Any such mechanism belongs to the surrounding application and requires independent design and review.

## 4. Privacy and observability

A structured identifier can reveal its encoded Class, Engine, Role, Version, and Revision values to anyone able to inspect it. Do not assume that bit packing hides these values. If an application has privacy or confidentiality requirements, assess them separately; changing the representation must not violate the identity, Class, and Role stability rules.

In v1.42, the Class field directly exposes the entity category. This is a deliberate design property of the profile, not a side effect. Applications with confidentiality requirements should treat the Class value as observable and account for that in their privacy assessment.

## 5. Scope of this note

This note does not claim formal certification or compliance with a cryptographic or security standard. The normative identifier and serialization requirements are in SPECIFICATION.md.
