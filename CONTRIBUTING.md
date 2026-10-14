# Contributing

Contributions that make the library safer, clearer, more reliable, or more
useful offline are welcome.

Before opening a pull request:

1. Explain the problem and the intended user impact.
2. Keep the interface usable on a 390-pixel-wide phone.
3. Use public, redistributable, or clearly licensed content sources.
4. Do not add medical, electrical, structural, or nuclear instructions without
   authoritative sourcing and an appropriate warning.
5. Run Python syntax checks and `bash -n` on modified scripts.
6. Test the portal without internet.
7. Never commit passwords, API tokens, personal plans, or downloaded archives.

Large `.zim`, `.pmtiles`, `.img`, and downloaded PDF files do not belong in the
Git repository. Add sources to the manifests and let the installer download and
verify them.
