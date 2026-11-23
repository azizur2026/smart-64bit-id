# SMART 64-Bit ID v1.42 — Industry Alignment Note

**Status:** Release Candidate 1 — cross-check in progress
**Status note:** Non-normative comparison and scope note. This is not a certification or claim of formal compliance with an external standard.

## 1. Design objective

SMART v1.42 separates a persistent identity core (Class + Engine + Local) from an upper representation/control area. Its allocation uniqueness coordinate is Engine + Local. Its routing selector is Class + Engine, resolved through the virtual-engine table. In v1.42 the Class field carries the encoded taxonomy value and each Engine is bound to exactly one Class, with multiple Engines permitted to share a Class. This is a particular architectural choice, not a universal replacement for other identifier designs.

## 2. Comparison dimensions

When comparing identifier systems, evaluate at least:

- whether generation requires synchronized wall-clock time;

- whether numeric order approximates creation time;

- how uniqueness is coordinated across allocation domains;

- how an allocator recovers after crash, restore, failover, or ownership transfer;

- whether the format exposes shard, class, or role metadata;

- how identifiers are stored and indexed in the target database;

- how profile/version evolution is handled;

- how the system retains retired identifiers and their permanently consumed coordinates; and

- whether the design supports the application's privacy and security requirements.

SMART v1.42 does not encode time and does not promise chronological ordering. Its allocation-safety model depends on authoritative Engine namespaces and non-reusing Local allocation. Timestamp-based and random identifiers make different trade-offs; the right choice depends on workload and system constraints.

## 3. No unsupported superiority claim

The specification does not establish that SMART is faster, more scalable, more secure, or more storage-efficient than every alternative. Any such claim needs a defined workload, controlled methodology, baseline, raw results, and reproducible conditions. Database measurements do not automatically establish allocator or distributed-routing performance. The cost of coordinate permanence and retired-record retention is a real operational cost and should be included in any comparison.

## 4. Security alignment

An identifier format is distinct from authentication and authorization. Applications should not treat possession of an identifier as proof of identity or permission. Cryptographic protections and key management are outside the SMART v1.42 format. In v1.42 the Class field directly exposes the entity category; applications with confidentiality requirements should account for that in their security design.

## 5. Version boundaries

The v1.4, v1.41, and v1.42 profiles are not interchangeable. In particular, v1.4 uses bits 50–57 as Region; v1.41 uses bits 50–53 as a zero Class-marker and bits 54–57 as Reserved; v1.42 uses bits 50–53 as the encoded Class and bits 54–57 as Reserved. A decoder must select the profile before interpreting these bits.

Under normal validation, mutual invalidity between v1.41 and v1.42 produces rejection at profile identification: a v1.42 identifier read under v1.41 rules has Revision 0010, which is not v1.41; a v1.41 identifier read under v1.42 rules has Revision 0001, which is not v1.42. If the fields were force-interpreted under the other profile's field rules, additional field-level incompatibilities would also appear — a v1.42 identifier's Class-marker bits would be nonzero under v1.41 rules, and a v1.41 identifier's encoded Class would be 0000 under v1.42 rules. The field-level observation is informative; profile selection is the decisive rejection.

## 6. Identifier-lifecycle alignment

SMART v1.42's retirement model is consistent with established identifier-lifecycle practice. GS1 requires that an allocated GTIN SHALL NOT be reallocated to another trade item; the earlier four-year non-reuse period has been deprecated, with only narrow exceptions for items never produced and withdrawn items reintroduced unchanged. NIST SP 800-53 IA-4 requires organizations to prevent reuse of identifiers for an organization-defined period. ISO 8000-115:2024 specifies identifier syntax and resolution principles while explicitly leaving the methods of creation and resolution outside its scope. SMART v1.42 follows the same direction: a retired coordinate is consumed permanently, with no release point. See BIBLIOGRAPHY.md.

## 7. Research boundary

Historical benchmark notes outside this package document their own test conditions and limitations. They are not evidence of v1.42 performance unless a new study explicitly defines and tests the v1.42 profile.
