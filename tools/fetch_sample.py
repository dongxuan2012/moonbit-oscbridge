"""Fetch the pinned public input into a new directory (CC BY 4.0; see notices)."""
from pathlib import Path
import argparse
import hashlib
import json
import shutil
import tempfile
import urllib.request

import py7zr

ARCHIVE_SHA = '33a9fae8e21446b40a3099e6ffa733b679af4f3df4d4ce90aa4b06aeddf45ff8'
URL = 'https://ndownloader.figshare.com/files/60073955'
RECORD = 'Labeled_raw_v1.1/4bbe281f8abafac243fafb0a0c2f047c'
EXPECTED = {
    '.cfg': '656bc0a07bb4c422bd4bd3e14fd607dfd668fe8d0362c28c4c95e73096f36de2',
    '.dat': 'e968ea9567684117d189e74dec622bf417ead6f2611105a82a6f6c5029185253',
}


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('destination', type=Path, help='new directory; parent must already exist')
    parser.add_argument('--archive', type=Path, help='reuse this unchanged local archive instead of downloading')
    args = parser.parse_args()
    destination = args.destination.absolute()
    # Deliberately refuse reuse: inputs from a previous run are not silently mixed.
    destination.mkdir(exist_ok=False)
    archive = args.archive.absolute() if args.archive else destination / 'Labeled_raw_v1.1.7z'
    if not args.archive:
        temporary = destination / 'download.partial'
        size = 0
        with urllib.request.urlopen(URL, timeout=60) as response, temporary.open('xb') as target:
            while block := response.read(1024 * 1024):
                size += len(block)
                if size > 100_000_000:
                    raise ValueError('download exceeds pinned archive size allowance')
                target.write(block)
        if sha(temporary) != ARCHIVE_SHA:
            raise ValueError('archive hash mismatch; partial file retained for inspection')
        temporary.rename(archive)
    if sha(archive) != ARCHIVE_SHA:
        raise ValueError('archive hash mismatch; extraction was not attempted')
    # The archive is hash-pinned before extraction. Only the two fixed paths are requested.
    scratch = Path(tempfile.mkdtemp(prefix='extract-', dir=destination))
    targets = [RECORD + ext for ext in EXPECTED]
    with py7zr.SevenZipFile(archive, 'r') as source:
        if not set(targets) <= set(source.getnames()):
            raise ValueError('pinned sample missing from archive')
        source.extract(path=scratch, targets=targets)
    result = {}
    for extension, digest in EXPECTED.items():
        extracted = scratch / (RECORD + extension)
        if not extracted.resolve().is_relative_to(scratch.resolve()) or sha(extracted) != digest:
            raise ValueError('extracted sample hash mismatch')
        result[extension] = extracted
    for extension, source in result.items():
        target = destination / ('sample' + extension)
        with source.open('rb') as incoming, target.open('xb') as outgoing:
            shutil.copyfileobj(incoming, outgoing)
    # Keep extraction material: this helper does not recursively remove any path.
    receipt = {
        'result': 'PASS', 'archive': str(archive), 'archiveSha256': ARCHIVE_SHA,
        'doi': '10.6084/m9.figshare.28465427.v6', 'license': 'CC BY 4.0',
        'record': RECORD,
        'samples': {ext: {'path': str(destination / ('sample' + ext)), 'sha256': digest}
                    for ext, digest in EXPECTED.items()},
        'note': 'Public anonymized record; no event diagnosis or UTC claim. See THIRD-PARTY-NOTICES.md.',
    }
    (destination / 'SOURCE-RECEIPT.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(receipt, indent=2))


if __name__ == '__main__':
    main()
