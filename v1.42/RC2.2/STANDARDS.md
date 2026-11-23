# SMART 64-Bit ID v1.42 — Serialization and Security Boundary

**Status:** Release Candidate 2.2 (RC2.2) — Finalized 2026-11-23
**Profile:** Version 0, Revision 0010
**Status note:** Implementation guidance, except where a requirement is explicitly attributed to the
normative specification.

## 1. Canonical binary representation

The v1.42 canonical binary representation is an unsigned 64-bit integer in big-endian (network byte
order). Bit 0 is the least-significant bit; bit 63 is the most-significant bit. Implementations using
signed host-language integer types must preserve the same unsigned value and extract fields with
logical, not arithmetic, right shifts.

Do not serialize using host byte order where canonical interoperability is required. Do not convert
to a signed value if that changes comparisons, numerical values, or extraction.

## 2. Field extraction

Field masks, applied to an unsigned 64-bit value with logical shifts:

    Local    = ID & 0x1FFFFFFF
    Engine   = (ID >> 29) & 0x1FFFFF
    Class    = (ID >> 50) & 0x0F
    Reserved = (ID >> 54) & 0x0F
    Role     = (ID >> 58) & 0x01
    Revision = (ID >> 59) & 0x0F
    Version  = (ID >> 63) & 0x01

Validate the profile before interpreting profile-dependent fields. For v1.42, reject nonzero
Reserved bits, encoded Class `0000`, and encoded Class `1001`–`1111`. Verify that the encoded Class
agrees with the authoritative Class-property record; disagreement is a hard stop.

Bit 54 remains Reserved; do not interpret it as part of Class. Revision `0000` is obsolete: an
identifier carrying it is rejected as an unsupported profile.

Both Role values are valid. `S64-E010 ROLE_INVALID` is an operation-level error, not a
field-validation error; do not reject an identifier merely because it carries Role 0 or Role 1.

Within the input-format stage, formatting is validated before length: a malformed input that is also
the wrong length reports `S64-E011`, not `S64-E001`.

Profile provenance is validated separately from field values. An identity's recorded profile is
compared with the profile of the generation epoch in which it was allocated, not with the engine's
current profile. The comparison is `S64-E030`; an implementation must not rewrite a recorded profile
to satisfy it.

## 3. Identifier is not authentication

A SMART ID is an identifier, not a secret, credential, authenticator, or proof of identity.
Possession or presentation of a SMART ID alone must not be treated as evidence of authorization or
authenticity. Applications must enforce authentication and authorization independently.

v1.42 defines no proprietary cryptographic algorithm, signature scheme, format-preserving
encryption, key-management system, or authentication protocol. Any such mechanism belongs to the
surrounding application and requires independent design and review.

Network and hardware addresses stored alongside a Virtual Engine are locators. A matching MAC or IP
address is not evidence that a host is the expected host.

## 4. Privacy and observability

A structured identifier reveals its encoded Class, Engine, Role, Version, and Revision to anyone able
to inspect it. Do not assume that bit packing hides these values.

In v1.42 the Class field directly exposes the entity category. This is a deliberate design property,
not a side effect. Applications with confidentiality requirements should treat the Class value as
observable and account for it in their privacy assessment. Changing the representation to obscure it
must not violate the identity, Class, and Role stability rules.

## 5. Attestation and audit assurance

Where an implementation uses QDH, two assurances rest on the surrounding system rather than on the
identifier format:

- A hash-chained audit trail provides tamper-evidence. Non-repudiation against a privileged database
  attacker additionally requires periodic external anchoring of root hashes. Without anchoring, the
  claim must be reduced to tamper-evidence within the database trust boundary.

- Hardware attestation is only as strong as its trust roots. Validity windows, revocation freshness,
  single-use nonces, and an allowlisted measurement digest must all be enforced before an engine is
  reactivated. Attestation establishes platform state; it does not establish that the application
  running on that platform is trustworthy.

## 6. Scope of this note

This note claims no formal certification or compliance with a cryptographic or security standard.
The normative identifier, serialization, and QDH requirements are in `SPECIFICATION.md`,
`QDH-SPECIFICATION.md`, and `QDH-LOGGING-AND-LIFECYCLE.md`.
