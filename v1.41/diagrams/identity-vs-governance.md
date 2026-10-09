# SMART 64-Bit ID v1.41 — Identity Core and Control Area

**Explanatory diagram; see [SPECIFICATION.md](../SPECIFICATION.md).**

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                           SMART ID — 64 bits                                │
├───────────────────────────────────────────────────────────────┬─────────────┤
│                 54-bit Identity Core                          │ Upper 10    │
│                                                               │ bits        │
│  Class (4) + Engine (21) + Local (29)                          │             │
│                                                               │ Version (1) │
│  Persistent identity                                           │ Revision(4) │
│                                                               │ Role (1)    │
│                                                               │ Reserved(4)│
└───────────────────────────────────────────────────────────────┴─────────────┘
```

The drawing groups the upper bits by function, not by physical order. In actual bit order from MSB to LSB they are Version, Revision, Role, Reserved, Class, Engine, Local.

- Identity Core is stable for an allocated identity.
- Role is physically in the upper 10 bits but semantically immutable for that identity.
- Reserved bits must be zero in v1.41.
- Class is immutable and does not split the Engine + Local allocation namespace.
- Version and Revision select the profile; do not interpret profile-dependent bits until the profile is selected.
