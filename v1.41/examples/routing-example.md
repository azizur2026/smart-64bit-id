# SMART 64-Bit ID v1.41 — Routing Example

**Non-normative example.**

Given the illustrative identifier `0x0C00000540000007` from the [generation example](generation-example.md):

1. Decode and validate Version/Revision before interpreting profile-dependent fields.
2. Confirm Version `0`, Revision `0001` selects v1.41.
3. Extract Reserved; reject the identifier as v1.41 if the value is nonzero.
4. Extract bits 50–53 and confirm the v1.41 Class-marker is `0000`. This marker is not the effective Class.
5. Extract Engine = `42` and route to the logical Engine 42 namespace.
6. Extract Local = `7` and perform the namespace-local lookup.
7. When the effective Class is needed, obtain it from the authoritative Class-property record associated with Engine `42` and Local `7`. Reject an invalid effective Class according to the normative specification.
8. Apply application-level authentication and authorization separately; the identifier is not proof of permission.

```text
0x0C00000540000007
         |
         +-- profile: Version 0 / Revision 1
         +-- Class-marker: 0000
         +-- Engine: 42 --> Engine 42 namespace
         +-- Local: 7 ----> lookup inside Engine 42
                             |
                             +--> effective Class: authoritative property record
```

The router does not use Class as its current normative routing selector. If Engine 42 is unavailable, SMART does not encode a successor Engine; resolution and availability behavior belong to the surrounding system.
