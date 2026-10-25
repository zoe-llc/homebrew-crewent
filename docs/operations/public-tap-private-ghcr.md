# Public Tap / private GHCR access（廃止済み境界）

この文書名が示す private GHCR 境界は 2026-10-25 に廃止された。匿名 Homebrew install のため、`ghcr.io/zoe-llc/crewent/crewent` は public である。

現在の install、short name、公開範囲は [Homebrew installation](homebrew-installation.md) を参照する。

維持する境界は、public Tap に repository secret、package write permission、private source credential、protected build artifact、mutation workflow を置かないことである。private distribution automation が public bottle の publish と anonymous canary を所有する。
