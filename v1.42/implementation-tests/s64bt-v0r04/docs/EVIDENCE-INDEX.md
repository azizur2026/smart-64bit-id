# S64BT v0.r04 - Evidence Index

S64BT Package Version: 0
S64BT Package Revision: 04
S64BT Package Date: Nov 14, 2026

This document lists every file in the package with its size, hash, and role.
This file (EVIDENCE-INDEX.md) is purely hand-written, not **generated** automatically during test.

Manifest SHA-256: 395d4c4172b890a2117d4e8ffb6cd0ba121c378263f22a2a3611be414642ed3e

## 1. Package files (harness + test sources + docs + integrity)

Hashes reflect the current publication state, which post-dates the recorded run (2026-11-15T11:25:15Z). Recorded-run hashes are in the frozen evidence manifest and `META-*.txt`.

| Path | Size (bytes) | SHA-256 | Role |
|---|---:|---|---|
| `s64bt.config` | 589 | `33196471f40e7281081bc67c05f1597719913a8165d8d1876ddfa2f30797029a` | configuration |
| `lib.sh` | 10421 | `fdb941a0d0de7b3225b24515d9925b04d6e96e41b3be078dd45d22d7baed85d9` | shared library |
| `00-prep-fresh-tree.sh` | 2555 | `1f25d8858e2f1e5f29282a17e2ee2e37442b9f49a6deaa59e8d4e1fcf39e09e2` | runner |
| `01-run-dry.sh` | 5673 | `f1a98ea4a8a9e2c389475c7a705c023d1afc6f8c28733d0906c51e8c32bd4e44` | runner |
| `02-run-fast-tests.sh` | 5484 | `b63c7ff048168960b57cd18a90784a91a21b6696c26e528d56dae200828a17fa` | runner |
| `03-run-ct07.sh` | 5482 | `4b29b7e253939b076b54e05517fe4ff6b7b2f5c9c2471a1878ac91f621f58011` | runner |
| `04-run-ct08-verify.sh` | 2319 | `93675da0254c46da2bc382df06ad344b902f088ebb243cfa408dce2e7c82aa0b` | runner |
| `05-run-final-manifest.sh` | 7015 | `18d5ddf8db684398730585847ae120c512337c45ff1ef51ed966c96b2098bb38` | runner |
| `README.md` | 5435 | `705a36f612934dea563c02e4445a27ce6d73866fe562d797b3a71c392c95a0ca` | documentation |
| `docs/LIMITATIONS.md` | 7261 | `70a82307bba25e7a04d774c4863d25215b2840a9b7a09696575f22cce00d54f0` | documentation |
| `docs/VERIFICATION-NOTE.md` | 6654 | `fab697e0cef9b5f3c78bd165a9c9dc2435c69677e93d82d35c0ecf3f475831a4` | documentation |
| `docs/TEST-PROCEDURE.md` | 9529 | `4f632cc73f570a038ebfbc79f10f260684de12cf0210fc48c0629882d42d91f7` | documentation |
| `gcc/db-schema.sql` | 2492 | `b8308801efdb39eede8753ab4331684da79de630adfcdc804bfb489694f1f401` | test source or schema |
| `gcc/CT-07-disposable-schema.sql` | 1412 | `bba8382a40dddb3543daf0958380f67ce5a29d0e40909ba32878702bac89968f` | test source or schema |
| `gcc/CT-01-bit-encoding.c` | 5972 | `602beed9500f11a870dbd7593098c199255a0b298f2a995ac8fb0c8f2c9a4913` | test source or schema |
| `gcc/CT-02-local-id-boundary.c` | 1791 | `8c72399874a7312e1db7c33c4f12bb5fe3c62115f75037a6159a41065f88448a` | test source or schema |
| `gcc/CT-03-engine-uniqueness.sql` | 2412 | `93f3ed7de0a9c3422407434a067a06066b84e506a5c075a29bcdfb9ef6d27589` | test source or schema |
| `gcc/CT-04-cross-engine-isolation.sql` | 2632 | `1cb03d85bbe9c26bd71a3550f7f95016a2217ab8cf3cd5dd75db27e29279e889` | test source or schema |
| `gcc/CT-05-profile-validation.c` | 3430 | `5711dbfae204c60c27a60a107edfa3dc1fe796cffed76279beb225bcc0b76096` | test source or schema |
| `gcc/CT-06-class-consistency.sql` | 3899 | `84bddf3d06863f96fd9613a4662203a6bb4208ff9bea8805f3fe225060f6282c` | test source or schema |
| `gcc/CT-07-concurrent-allocation.c` | 14099 | `a2b4bb0186a0c5d1478fa020adadc8c7016361f51bbf9b940f848c3b3ef3b861` | test source or schema |
| `gcc/CT-08-persistence.sh` | 3698 | `670e758fed1521a5104b54fe6722a897f5f2e8e8ed4847719ea9e3c101f9c5f8` | test source or schema |

## 2. Evidence files (recorded run)

Evidence root: `gcc/evidence/`
Total evidence files: 31

| Path | Size (bytes) | SHA-256 |
|---|---:|---|
| `gcc/evidence/BATCH/EVIDENCE-MANIFEST-20261115T112515Z.txt` | 7363 | `395d4c4172b890a2117d4e8ffb6cd0ba121c378263f22a2a3611be414642ed3e` |
| `gcc/evidence/BATCH/META-ct07.txt` | 2212 | `87a59db3e9902e9a12c0fd3f2a0ddddc44304cc5c9d05cc4920b088931f51f3c` |
| `gcc/evidence/BATCH/META-ct08.txt` | 2212 | `9b9b22cdadc747db7c8d247d7276eadd02b3b082771810a066999ba3a1653ac3` |
| `gcc/evidence/BATCH/META-fast.txt` | 2212 | `87a59db3e9902e9a12c0fd3f2a0ddddc44304cc5c9d05cc4920b088931f51f3c` |
| `gcc/evidence/BATCH/META-final.txt` | 446 | `1effa0b6050ecbe9e700f0603b3584f7f6ed8254ea652852abf3c94c7683094f` |
| `gcc/evidence/BATCH/run-ct07-20261115T110043Z.log` | 351 | `120e58b95aa424f334f4824d3602ff01fabc861419a6c8a2b247cede80fd8059` |
| `gcc/evidence/BATCH/run-ct08-20261115T112515Z.log` | 135 | `c120d883060fc84ba174f54884dff7aab670075ae54963feabd031261ae39554` |
| `gcc/evidence/BATCH/run-fast-20261115T110042Z.log` | 323 | `597aaf14ab3395d26812d2281210d2274316875756589432fe5d18bbe0587383` |
| `gcc/evidence/BATCH/summary-ct07.txt` | 207 | `ab792ff246575cb9fe6c4dc5671643d32da535563a6d97b9f570f6dfb1f87808` |
| `gcc/evidence/BATCH/summary-ct08.txt` | 204 | `333c695e792842dc2fa3b245c71847dd78094f79fc4efdfff1c44d2f2ef4cabe` |
| `gcc/evidence/BATCH/summary-fast.txt` | 323 | `597aaf14ab3395d26812d2281210d2274316875756589432fe5d18bbe0587383` |
| `gcc/evidence/BATCH/summary-final.txt` | 180 | `7b22b7904bcf5c27dfe15b80d04af74845c94a362a54734a315eeda0b6363cfb` |
| `gcc/evidence/CT-01/compile.log` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `gcc/evidence/CT-01/run.log` | 783 | `2706b5022cb97d2183faa3b6a12930edff8dcbaa1dda61a0bc555538073612ea` |
| `gcc/evidence/CT-02/compile.log` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `gcc/evidence/CT-02/run.log` | 435 | `b77d8c6f51a08f027ce3ef795094f81fc84afbc98388677c41b7bc5b474c4949` |
| `gcc/evidence/CT-03/CT-03-run.sql` | 2412 | `81255e5855353204238d4b1e5e2e39a6dee7374082d64956536235d42549f392` |
| `gcc/evidence/CT-03/run.log` | 154 | `e49f585e7f675daefd0c917b9174743a10500fa92d93ed533dfd849a9cc3fe6b` |
| `gcc/evidence/CT-04/run.log` | 68 | `03c7f002b362ad7a347082d823385bc260905fd41a5f71b566c7108bed0f28f8` |
| `gcc/evidence/CT-05/compile.log` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `gcc/evidence/CT-05/run.log` | 2225 | `e45948e296362d4d28b5afed2a8f13d009d352890ef8731d1576de03a925c273` |
| `gcc/evidence/CT-06/CT-06-run.sql` | 3659 | `16cf9ae74332ef29b7ad7c56d04322da81ca7ebebe0a817a22095cf7cc2f9b65` |
| `gcc/evidence/CT-06/run.log` | 38 | `d95fc502ab912bedc27eba678390dd3581f32741e6a20834635d998161bd6d74` |
| `gcc/evidence/CT-07/compile.log` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `gcc/evidence/CT-07/database-setup.log` | 287 | `e25e07824cf521cce94987c364cdf4f517278e8fb38dc63bc74edb981bb85926` |
| `gcc/evidence/CT-07/engine-id.txt` | 65 | `c6406b3bac0e9e9d920f4dc2c6b2d82a77a563a116d2352422b424dc7c5b45d1` |
| `gcc/evidence/CT-07/run.log` | 582 | `51f836dd28db9fd30136f5965d04f544a5407d4304da2530b764c3a156afde45` |
| `gcc/evidence/CT-08/baseline-command.log` | 118 | `7727ad3b693b59487c5161deb0aa3ffd16832b58b3b7e30e9997bd5453126fc5` |
| `gcc/evidence/CT-08/baseline.txt` | 164 | `68e77ecbfe2bcf9fb58099a187c39f4a096ece25c0971c34f552c35f320e3866` |
| `gcc/evidence/CT-08/recovery-results.txt` | 165 | `cc4ee7ccda311670424f10ac580511537b03263a37987a33a1a97a4c0f4cf32a` |
| `gcc/evidence/CT-08/verify-command.log` | 55 | `80aa6458fc40cdc23ba8fe72757f9fc4520fbbe8c9e14fe65f07b2cc1610fa31` |

## 3. Evidence manifest

`gcc/evidence/BATCH/EVIDENCE-MANIFEST-20261115T112515Z.txt`
SHA-256: `395d4c4172b890a2117d4e8ffb6cd0ba121c378263f22a2a3611be414642ed3e`

The manifest lists each evidence file with path, size, sha256, and mtime.

## 4. How to verify

```
cd ~/Desktop/AI_works/smart-64bit-id/v1.42/implementation-tests/s64bt-v0r04
sha256sum -c SHA256SUMS.txt
```

All files must report `OK`.

## 5. Reading order

1. `README.md` - front door
2. `docs/VERIFICATION-NOTE.md` - the claim
3. `docs/LIMITATIONS.md` - what is not claimed
4. `docs/TEST-PROCEDURE.md` - how each gate works
5. `docs/EVIDENCE-INDEX.md` - this file

Each evidence file under `gcc/evidence/CT-*/` supports the corresponding gate in `docs/TEST-PROCEDURE.md`.
