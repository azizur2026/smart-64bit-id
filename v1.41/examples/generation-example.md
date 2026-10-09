# SMART 64-Bit ID v1.41 — Generation Example

**Non-normative example.** The normative requirements are in [SPECIFICATION.md](../SPECIFICATION.md).

## 1. Preconditions

Assume a system has assigned Engine `42` to the namespace in question and its authoritative allocator has successfully allocated Local `7` without reuse. The example uses Class `0001` (Human), Role `1` (self-representing), Reserved `0000`, Revision `0001`, and Version `0`.

This is an illustrative test vector, not a globally reserved identity. A real implementation must use its own valid Engine assignment and authoritative Local allocator.

## 2. Field values

| Field | Value | Bits |
|---|---:|---|
| Local | 7 | `00000000000000000000000000111` (29 bits) |
| Engine | 42 | `00000000000000000101010` (21 bits) |
| Class | Human | `0001` |
| Reserved | zero | `0000` |
| Role | self-representing | `1` |
| Revision | v1.41 | `0001` |
| Version | v1 family | `0` |

Assemble by shifting each field to its specified position:

```text
ID = (Version  << 63)
   | (Revision << 59)
   | (Role     << 58)
   | (Reserved << 54)
   | (Class    << 50)
   | (Engine   << 29)
   | Local
```

For this vector, the resulting unsigned 64-bit value is:

```text
Hex:        0x0C04000540000007
Decimal:    865817050910556167
Big-endian: 0C 04 00 05 40 00 00 07
```

Decoding returns Local `7`, Engine `42`, Class `1`, Reserved `0`, Role `1`, Revision `1`, Version `0`.

## 3. Allocation safety

The bit assembly step does not make allocation safe by itself. Local must first be returned by the authoritative allocator for Engine 42. If safe uniqueness and non-reuse cannot be established, the implementation must fail the allocation rather than invent or reuse a Local value.
