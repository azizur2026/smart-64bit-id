# SMART 64-Bit ID v1.41 — Generation Example

**Non-normative example.** The normative requirements are in [SPECIFICATION.md](../SPECIFICATION.md).

## 1. Preconditions

Assume the authoritative allocator has allocated Local `7` in Engine `42` without reuse. The authoritative Class-property record associated with Engine `42` and Local `7` identifies the effective Class as `0001` (Human).

For v1.41, bits 50–53 are the fixed Class-marker `0000`. They do not encode the effective Class. Reserved bits 54–57 are also `0000`. Role is `1` (self-representing), Revision is `0001`, and Version is `0`.

This is an illustrative test vector, not a globally reserved identity.

## 2. Encoded field values

| Field | Value | Bits |
|---|---:|---|
| Local | 7 | `00000000000000000000000000111` (29 bits) |
| Engine | 42 | `00000000000000000101010` (21 bits) |
| Class-marker | zero | `0000` |
| Reserved | zero | `0000` |
| Role | self-representing | `1` |
| Revision | v1.41 | `0001` |
| Version | v1 family | `0` |

Assemble the encoded identifier:

```text
ID = (Version       << 63)
   | (Revision      << 59)
   | (Role          << 58)
   | (Reserved      << 54)
   | (Class-marker  << 50)
   | (Engine        << 29)
   | Local
```

For this vector, the resulting unsigned 64-bit value is:

```text
Hex:        0x0C00000540000007
Decimal:    864691151003713543
Big-endian: 0C 00 00 05 40 00 00 07
```

Decoding returns Local `7`, Engine `42`, Class-marker `0`, Reserved `0`, Role `1`, Revision `1`, and Version `0`. The effective Class is `0001` (Human), obtained separately from the authoritative Class-property record associated with Engine `42` and Local `7`.

## 3. Allocation safety

The bit assembly step does not make allocation safe by itself. Local must first be returned by the authoritative allocator for Engine `42`. If safe uniqueness and non-reuse cannot be established, the implementation must fail the allocation rather than invent or reuse a Local value.
