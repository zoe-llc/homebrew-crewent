# 3環境 distribution canary と stable promotion

## Ownership

canary と promotion workflow の正本は private `zoe-llc/crewent-distribution`。public Tap は Formula と credential-free metadata だけを保持し、workflow secret、private artifact、package write permission を持たない。

## Current state

0.1.1 は次を完了している。

- exact source Release と 3 target bottle build / public GHCR publish
- macOS ARM64、Linux x86_64、Linux ARM64 の anonymous manifest / blob / install lifecycle canary
- activation authorization の検証
- public Tap PR #16 の merge と stable Formula validation

dedicated Product A/B/C canary は別の製品機能 gate として PENDING / UNVERIFIED のまま。Homebrew 配布の PASS へ読み替えず、Homebrew promotion を block する同一 gate にも戻さない。

## Next release

1. private automation が新しい exact version / source SHA / authorization SHA から 3 bottle を build する。
2. publisher identity で package visibility `public`、manifest identity、3 blob digest を read back する。
3. candidate PR の exact head を使い、GitHub / GHCR credential を unset した 3 target canary を実行する。
4. activation record は public Tap / GHCR の匿名到達性、3 target lifecycle、rollback window を検証する。
5. local Tap contract test と必要な validation が green の場合だけ、人が stable PR merge を判断する。

workflow は PR を merge しない。別 run、別 candidate、別 SHA の artifact で代替せず、既存 GHCR version tag を上書きしない。

rollback は [Rollback](rollback.md) に従い、Release assetやbottleを削除しない。
