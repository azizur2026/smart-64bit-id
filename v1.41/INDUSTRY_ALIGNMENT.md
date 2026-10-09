# SMART 64-Bit ID v1.41 — Industry Alignment Note

**Status:** Non-normative comparison and scope note. This is not a certification or claim of formal compliance with an external standard.

## 1. Design objective

SMART v1.41 separates a persistent identity core (`Class + Engine + Local`) from an upper representation/control area. Its allocation uniqueness coordinate is `Engine + Local`, and its current routing selector is Engine. This is a particular architectural choice, not a universal replacement for other identifier designs.

## 2. Comparison dimensions

When comparing identifier systems, evaluate at least:

- whether generation requires synchronized wall-clock time;
- whether numeric order approximates creation time;
- how uniqueness is coordinated across allocation domains;
- how an allocator recovers after crash, restore, failover, or ownership transfer;
- whether the format exposes shard, class, or role metadata;
- how identifiers are stored and indexed in the target database;
- how profile/version evolution is handled; and
- whether the design supports the application's privacy and security requirements.

SMART v1.41 does not encode time and does not promise chronological ordering. Its allocation-safety model depends on authoritative Engine namespaces and non-reusing Local allocation. Timestamp-based and random identifiers make different trade-offs; the right choice depends on workload and system constraints.

## 3. No unsupported superiority claim

The specification does not establish that SMART is faster, more scalable, more secure, or more storage-efficient than every alternative. Any such claim needs a defined workload, controlled methodology, baseline, raw results, and reproducible conditions. Database measurements do not automatically establish allocator or distributed-routing performance.

## 4. Security alignment

An identifier format is distinct from authentication and authorization. Applications should not treat possession of an identifier as proof of identity or permission. Cryptographic protections and key management are outside the SMART v1.41 format.

## 5. Version boundaries

The v1.4 and v1.41 profiles are not interchangeable. In particular, v1.4 uses bits 50–57 as Region, whereas v1.41 uses bits 50–53 as Class and bits 54–57 as Reserved. A decoder must select the profile before interpreting these bits.

## 6. Research boundary

Historical benchmark notes in `../research/v1.4/` document their own test conditions and limitations. They are not evidence of v1.41 performance unless a new study explicitly defines and tests the v1.41 profile.
