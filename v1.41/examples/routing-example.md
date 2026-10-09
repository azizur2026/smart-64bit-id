# SMART 64-Bit ID v1.41 — Routing Example

**Non-normative example.**

Given the illustrative identifier `0x0C04000540000007` from the [generation example](generation-example.md):

1. Decode and validate Version/Revision before interpreting profile-dependent fields.
2. Confirm Version `0`, Revision `0001` selects v1.41.
3. Extract Reserved; reject the identifier as v1.41 if the value is nonzero.
4. Extract Class; reject Class `0000` for an allocated identifier.
5. Extract Engine = `42` and route to the logical Engine 42 namespace.
6. Extract Local = `7` and perform the namespace-local lookup.
7. Apply application-level authentication and authorization separately; the identifier is not proof of permission.

```text
0x0C04000540000007
          │
          ├── profile: Version 0 / Revision 1
          ├── Engine: 42 ──► Engine 42 namespace
          └── Local: 7 ─────► lookup inside Engine 42
```

The router does not use Class as its current normative routing selector. If Engine 42 is unavailable, SMART does not encode a successor Engine; resolution and availability behavior belong to the surrounding system.
