# Public Homebrew consumer activation evidence

## 判定

2026-10-25: **PASS**。

`cli-v0.1.1` と同一 identity の public GHCR bottle を、GitHub / GHCR credential なしで install できる。public Tap PR #16 は main SHA `3225c8e22abf13b3702433d6703be176ce543620` として merge 済み。

## Evidence

- bottle build / publish run: `40167142836` — success
- anonymous macOS ARM64 / Linux x86_64 / Linux ARM64 lifecycle canary run: `40170841752` — success
- public Tap validation run: `40171812892` — success
- stable consumer: `brew install zoe-llc/crewent/crewent`、`crewent --version` = `0.1.1`、`crewent --help` — PASS

| target | bottle SHA-256 |
| --- | --- |
| `arm64_sequoia` | `7ecfeccdf77715a621be551fe134ce5e84319152b6b907a262f568d7da6b6f69` |
| `arm64_linux` | `175e73777ffff4382f8d125d747fd30362972719d480c61d08a6de250da63ed0` |
| `x86_64_linux` | `466c8ded34b33377e103a588aca01319c9bbdbb4d959e8bea59079a543006951` |

## Scope

- Product A/B/C canary は別 gateであり、PENDING / UNVERIFIED。
- Intel macOS と Windows は未対応。
- original TypeScript repository は private。ただし public bottle の compiled JavaScript は誰でも取得・解析できる。
- fresh environment の bare `brew install crewent` は未提供。Tap 登録済みなら `brew install crewent` を利用できる。
