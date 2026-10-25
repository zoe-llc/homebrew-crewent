# Homebrew installation

## Current public install

2026-10-25 現在、supported target では credential なしで install できる。

```sh
brew install zoe-llc/crewent/crewent
crewent --version
crewent --help
```

Homebrew は public Tap `zoe-llc/homebrew-crewent` と public GHCR package `ghcr.io/zoe-llc/crewent/crewent` を利用する。stable version は `0.1.1`。

対応 target:

- Apple Silicon macOS
- Linux x86_64
- Linux ARM64

Intel macOS と Windows は未対応。

## Short name

Tap を一度登録した環境では、bare Formula name を使える。

```sh
brew tap zoe-llc/crewent
brew install crewent
```

custom Tap の初回 one-command install は `brew install <user>/<repository>/<formula>` であり、Tap 登録後に `brew install <formula>` を使える（Homebrew [Installing a tap](https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap#installing)）。

fresh environment で `brew install crewent` だけを使うには `homebrew/core` への収録が必要になる。現在の CLI は `UNLICENSED`、original source は private、Formula は prebuilt bottle 必須なので、そのままでは core の公開 source / license 要件を満たさない（Homebrew [Acceptable Formulae](https://docs.brew.sh/Acceptable-Formulae#source-availability-and-licences)）。

core 採用へ進む場合は、公開ライセンスと source 公開を owner decision として確定し、source build 可能な Formula、`brew audit --new-formula`、`brew test-bot` を用意して `Homebrew/homebrew-core` へ PR を提出する。

## Public code boundary

original TypeScript repository と Git history は private のまま。一方、public bottle は `libexec/dist/crewent.js` などの readable compiled JavaScript と source path comment を含む。誰でも download、保存、解析できるため、compiled implementation を秘密とは扱わない。

public availability は OSS license を意味しない。同梱 `NOTICE` と `UNLICENSED` の条件は維持される。

## Upgrade and remove

```sh
brew update
brew upgrade crewent
brew uninstall crewent
```

完全に Tap を外す場合:

```sh
brew untap zoe-llc/crewent
```
