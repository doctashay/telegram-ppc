#!/usr/bin/env python3
import hashlib
from pathlib import Path
import sys
import tarfile
import urllib.request


SOURCES = (
    ("Csu-Csu-58", ".tar.gz",
     "https://codeload.github.com/apple-oss-distributions/Csu/tar.gz/refs/tags/Csu-58",
     "868defae7abb4cba7fc7d0246d6f70764016993d719659f6c880089d2a1edd91"),
    ("MacOSX10.4u.sdk", ".tar.xz",
     "https://github.com/phracker/MacOSX-SDKs/releases/download/11.3/MacOSX10.4u.sdk.tar.xz",
     "d28276ce6b0f14af30f3bfdc171f8ef4033652da593578568f8be189506c1021"),
    ("gcc-14-branch-gcc-14.2-darwin-r2", ".tar.gz",
     "https://codeload.github.com/iains/gcc-14-branch/tar.gz/refs/tags/gcc-14.2-darwin-r2",
     "23c2a1b2ce01e9d51948339869453229173c6889758137e7e517b545ae8bfc02"),
    ("openssl-1.1.1w", ".tar.gz",
     "https://github.com/openssl/openssl/releases/download/OpenSSL_1_1_1w/openssl-1.1.1w.tar.gz",
     "cf3098950cb4d853ad95c0841f1f9c6d3dc102dccfcacd521d93925208b76ac8"),
    ("zlib-1.3.1", ".tar.gz", "https://zlib.net/fossils/zlib-1.3.1.tar.gz",
     "9a93b2b7dfdac77ceba5a558a580e74667dd6fede4585b91eefb60f03b72df23"),
    ("curl-8.13.0", ".tar.xz", "https://curl.se/download/curl-8.13.0.tar.xz",
     "4a093979a3c2d02de2fbc00549a32771007f2e78032c6faa5ecd2f7a9e152025"),
    ("ffmpeg-8.0", ".tar.xz", "https://ffmpeg.org/releases/ffmpeg-8.0.tar.xz",
     "b2751fccb6cc4c77708113cd78b561059b6fa904b24162fa0be2d60273d27b8e"),
    ("td-a8f21f5230172634becc1739050ef23ecd6ea291", ".tar.gz",
     "https://codeload.github.com/tdlib/td/tar.gz/a8f21f5230172634becc1739050ef23ecd6ea291",
     "6ce3c64a811391d6d6c6f179cfd11ea8b4c72b701185e838eb8e854bebf7495b"),
)


def digest(path):
    with path.open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def fetch(root):
    cache = root / "downloads"
    source_root = root / "src"
    cache.mkdir(parents=True, exist_ok=True)
    source_root.mkdir(parents=True, exist_ok=True)
    for name, extension, url, checksum in SOURCES:
        archive = cache / (name + extension)
        if not archive.exists() or digest(archive) != checksum:
            temporary = archive.with_suffix(archive.suffix + ".tmp")
            print("Downloading", url, flush=True)
            with urllib.request.urlopen(url, timeout=120) as response, temporary.open("wb") as output:
                while block := response.read(1024 * 1024):
                    output.write(block)
            if digest(temporary) != checksum:
                raise RuntimeError(f"Source checksum mismatch: {url}")
            temporary.replace(archive)
        if not (source_root / name / ".sailplane-source").exists():
            def source_filter(member, destination):
                if name.endswith(".sdk") and member.issym() and member.linkname.startswith("/"):
                    # Host-only Java and local framework links are not SDK inputs.
                    return None
                return tarfile.data_filter(member, destination)

            with tarfile.open(archive) as source:
                source.extractall(source_root, filter=source_filter)
            (source_root / name / ".sailplane-source").touch()


if __name__ == "__main__":
    fetch(Path(sys.argv[1]).resolve())
