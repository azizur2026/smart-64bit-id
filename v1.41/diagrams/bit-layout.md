# SMART 64-Bit ID v1.41 — Bit Layout

**Explanatory diagram; normative definitions are in [../SPECIFICATION.md](../SPECIFICATION.md).**

```text
MSB                                                           LSB
┌─────────┬──────────┬──────┬──────────┬─────────┬─────────┬─────────┐
│ Version │ Revision │ Role │ Reserved │  Class  │ Engine  │  Local  │
│ 1 bit   │ 4 bits   │1 bit │ 4 bits   │ 4 bits  │21 bits  │ 29 bits │
├─────────┼──────────┼──────┼──────────┼─────────┼─────────┼─────────┤
│   63    │  62–59   │  58  │  57–54   │  53–50  │  49–29  │  28–0   │
└─────────┴──────────┴──────┴──────────┴─────────┴─────────┴─────────┘
```

Field ranges, stated without relying on drawing alignment:

| Field | Bits | Width | v1.41 constraint |
|---|---:|---:|---|
| Local | 0–28 | 29 | `0` is valid |
| Engine | 29–49 | 21 | Namespace/routing identifier |
| Class | 50–53 | 4 | `0000` invalid for allocated ID |
| Reserved | 54–57 | 4 | Must be `0000` |
| Role | 58 | 1 | `0` dependent, `1` self-representing |
| Revision | 59–62 | 4 | `0001` for v1.41 |
| Version | 63 | 1 | `0` for v1.41 |

The 54-bit Identity Core is `Class + Engine + Local`. The upper 10 bits are the representation/control area; Role remains semantically immutable for an allocated identity.
