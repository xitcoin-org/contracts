"""Regression checks for audit input coverage in a disposable Git repository."""
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


class ManifestTests(unittest.TestCase):
    def test_campaign_inputs_and_no_overwrite(self):
        source = Path(__file__).resolve().parents[1] / 'scripts/audit-manifest.py'
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            paths = ['contracts/Vault.sol', 'test/foundry/Vault.t.sol',
                     'test/echidna/campaign.yaml', 'test/legacy.js', 'test/check.py',
                     'audits/specs/Vault.spec', 'audits/specs/Vault.conf',
                     '.github/workflows/audit.yml', 'foundry.toml', '.nvmrc',
                     'package.json', 'package-lock.json', 'hardhat.config.js']
            for name in paths:
                p = root / name
                p.parent.mkdir(parents=True, exist_ok=True)
                p.write_text('synthetic audit input\n')
            (root / 'scripts').mkdir()
            shutil.copyfile(source, root / 'scripts/audit-manifest.py')
            subprocess.run(['git', 'init', '-q', str(root)], check=True)
            subprocess.run(['git', '-C', str(root), 'add', '.'], check=True)
            subprocess.run(['git', '-C', str(root), '-c', 'user.name=Audit Test',
                            '-c', 'user.email=audit@example.invalid', 'commit', '-qm', 'fixture'], check=True)
            def generate(name):
                return subprocess.run(['python3', str(root / 'scripts/audit-manifest.py'),
                                       '--output', str(root / name)], capture_output=True)
            self.assertEqual(generate('first.json').returncode, 0)
            first = json.loads((root / 'first.json').read_text())
            self.assertTrue(set(paths).issubset(first['inputs']))
            (root / 'test/foundry/Vault.t.sol').write_text('changed campaign\n')
            self.assertEqual(generate('second.json').returncode, 0)
            second = json.loads((root / 'second.json').read_text())
            self.assertNotEqual(first['inputs']['test/foundry/Vault.t.sol']['sha256'],
                                second['inputs']['test/foundry/Vault.t.sol']['sha256'])
            before = (root / 'first.json').read_bytes()
            self.assertNotEqual(generate('first.json').returncode, 0)
            self.assertEqual((root / 'first.json').read_bytes(), before)
            (root / 'linked.json').symlink_to(root / 'first.json')
            self.assertNotEqual(generate('linked.json').returncode, 0)
            self.assertEqual((root / 'first.json').read_bytes(), before)
            (root / 'test/linked.sol').symlink_to(root / 'contracts/Vault.sol')
            self.assertNotEqual(generate('symlink-input.json').returncode, 0)


if __name__ == '__main__':
    unittest.main()
