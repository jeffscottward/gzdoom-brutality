# Release sources

The release files in this folder are local copies. Git does not track them (see `.gitignore`). This file records where each file came from and its SHA-256 hash.

| File | Source | SHA-256 |
|---|---|---|
| `Project_Brutality-0.4.1.pk3` | Official GitHub repository [pa1nki113r/Project_Brutality](https://github.com/pa1nki113r/Project_Brutality), release tag `0.4.1` (commit `0ce1a6efee2a39b01d2d7fb7abe500e4e66db308`, published 2026-03-14). The release has no binary assets. The project README says to download the repository as a zip. This pk3 is `git archive --format=zip 0.4.1` of that tag. | `a5cb582432819a4bc75f49d770cb096c04118c0b8a817062e78a5f5bdaa7c67e` |
| `freedoom-0.13.0.zip` | [freedoom/freedoom release v0.13.0](https://github.com/freedoom/freedoom/releases/tag/v0.13.0). Contains `freedoom1.wad` and `freedoom2.wad`. | `3f9b264f3e3ce503b4fb7f6bdcb1f419d93c7b546f4df3e874dd878db9688f59` |
| `freedm-0.13.0.zip` | Same Freedoom release. Contains `freedm.wad` (deathmatch maps). | `b420f13508ef745d7b38e83d15e55e0fc0b09d9a503c96741cddd9773d43f7c9` |

Both Freedoom zip hashes match `freedoom-0.13.0-CHECKSUM` from the same release. The `.sig` files are the release's detached signatures; they were downloaded but not verified, because the signing key is not in the local keyring.

## Licenses and IWAD rule

- Freedoom and FreeDM: modified BSD license; free to redistribute.
- Project Brutality: see the upstream repository and its credits (`DetailedCredits.txt` in the pk3).
- Only Freedoom IWADs are used. No commercial Doom IWAD was downloaded. No `*.wad` file from the user was found on omarchy-rig on 2026-10-02 (searched `/` to depth 4).

## Rebuild the Project Brutality pk3

```sh
git clone --depth 1 --branch 0.4.1 https://github.com/pa1nki113r/Project_Brutality.git .work/pb-0.4.1
git -C .work/pb-0.4.1 archive --format=zip -o ../../releases/Project_Brutality-0.4.1.pk3 0.4.1
```
