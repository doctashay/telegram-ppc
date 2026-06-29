# PPCPorts TDLib PPC Runtime

These dylibs are a repo-local copy of the PPCPorts TDLib runtime from the
PowerPC Mac test host at `10.0.0.98`. CI uses this copy for the PPC slice so
the release pipeline does not depend on `/opt/local` or on rebuilding TDLib in
the Darwin cross image.

Source package:

- `tdlib @1.8.65_0` from PPCPorts
- TDLib commit `a8f21f5230172634becc1739050ef23ecd6ea291`
- PPCPorts big-endian patch applied

Files:

| File | Source path on `.98` | SHA-256 |
| --- | --- | --- |
| `lib/libtdjson.dylib` | `/opt/local/lib/libtdjson.1.8.65.dylib` | `d0f226fe4557c2ebe87286b19a202b69c45da04d26be1d7c9e9036ad7354acd7` |
| `lib/libMacportsLegacySupport.dylib` | `/opt/local/lib/libMacportsLegacySupport.dylib` | `15f166a8535be6702860d1f56ff3d7b43fbbbfb81ca41f2f1791b3f64e2e8671` |
| `lib/libssl.3.dylib` | `/opt/local/libexec/openssl3/lib/libssl.3.dylib` | `5cf1fdbbab8093931eba7f9641fb0a67598197ef3c220f0cb4525853688720c1` |
| `lib/libcrypto.3.dylib` | `/opt/local/libexec/openssl3/lib/libcrypto.3.dylib` | `09779949c36b267e149ea4c7c8ed118c02a043fe9d0b4f8934b71cf445035c9e` |
| `lib/libz.1.dylib` | `/opt/local/lib/libz.1.3.2.dylib` | `b45990edc6d2d2ccd57e55646a0c62b29de54920c931c21dfd3c8a12fa484b35` |
| `lib/libatomic.1.dylib` | `/opt/local/lib/libgcc/libatomic.1.dylib` | `732f64d6de5e853d8d55f7b2d8c778f77c2369bd9b84e63a9885d71c9acbcd37` |
| `lib/libstdc++.6.dylib` | `/opt/local/lib/libgcc/libstdc++.6.dylib` | `6ac2fc45f2b509c388cff6e166d9a191ed00224051da0ececb39d13ce683246b` |
| `lib/libgcc_s.1.1.dylib` | `/opt/local/lib/libgcc/libgcc_s.1.1.dylib` | `3761b6f1253d061f98b643da9a663c7c466fe86ea086542dca25ed427392d7c1` |
| `lib/libiconv.2.dylib` | `/opt/local/lib/libiconv.2.dylib` | `6a4102e4bd0e5bfb8101666d6fd4f2bb28d81f3fce02b00937bd898bbf17b7c5` |
