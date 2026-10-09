# SMART 64-Bit ID v1.41 — Routing Flow

**Explanatory diagram; normative routing is defined in [SPECIFICATION.md](../SPECIFICATION.md).**

```text
               64-bit SMART ID
                      │
                      ▼
             Select/validate profile
                      │
                      ▼
              Extract Engine (29–49)
                      │
                      ▼
             Route to Engine namespace
                      │
                      ▼
               Extract Local (0–28)
                      │
                      ▼
             Lookup within that Engine
                      │
                      ▼
                    Entity
```

Class is not the current normative routing selector. `Class + Engine` as a future higher-level shard key is deferred and must not be treated as a v1.41 routing requirement. Allocation uniqueness is enforced over Engine + Local, not by Class.
