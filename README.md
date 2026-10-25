# homebrew-crewent

Crewent CLI の public Homebrew Tap です。2026-10-25 現在、Formula と public GHCR bottle を匿名で配布しています。

## Install

GitHub account、Organization membership、PAT は不要です。

```sh
brew install zoe-llc/crewent/crewent
crewent --version
```

現在の stable version は `0.1.1`、対応 target は Apple Silicon macOS、Linux x86_64、Linux ARM64 です。Intel macOS と Windows は現在の bottle 対象外です。

Tap を登録済みの環境では短い名前も使えます。

```sh
brew tap zoe-llc/crewent
brew install crewent
```

fresh environment で最初から `brew install crewent` だけを使うには、Formula の `homebrew/core` 採用が必要です。現在の custom Tap は fully-qualified command が初回の正式な install coordinate です。詳細は [Homebrew installation](docs/operations/homebrew-installation.md) を参照してください。

## Public boundary

- public: この Tap の Formula / verification metadata、GHCR の compiled bottle
- private: original TypeScript repository、Git history、distribution automation、private Release access
- license: public bottle は取得・閲覧・解析できますが、CLI は `UNLICENSED` のままであり、OSS 化や利用・改変・再配布許諾を意味しません

public bottle には readable compiled JavaScript が含まれます。source repository が private でも、compiled implementation を秘密として扱うことはできません。

この repository は Formula-only read surface です。repository secret、package write permission、protected build artifact、private App key、mutation workflow を持ちません。bottle build / publish、anonymous 3-target canary、candidate PR 作成は private `zoe-llc/crewent-distribution` が所有します。

## Local validation

```sh
find test Formula -name '*.rb' -print0 | xargs -0 -n1 ruby -c
for test_file in test/*_test.rb; do ruby -Itest "$test_file"; done
actionlint
! rg -n 'secrets\.|packages:|upload-artifact|download-artifact|pull_request_target' .github/workflows
git diff --check
```

- [Homebrew installation](docs/operations/homebrew-installation.md)
- [Canary and promotion](docs/operations/canary-and-promotion.md)
- [Consumer activation evidence](docs/verification/consumer-activation.md)
- [Rollback](docs/operations/rollback.md)
