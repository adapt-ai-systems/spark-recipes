#!/usr/bin/env python3
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

import scrub
from scrub import scan_text

TERMS = ["synthetic-deny-term", "tailfixture"]


class ScrubTest(unittest.TestCase):
    def test_private_ip_blocks(self):
        fixture = "HEAD=192.168." + "255.254\n"
        self.assertTrue(scan_text("plant", fixture.encode(), TERMS))

    def test_documentation_placeholder_passes(self):
        self.assertEqual(scan_text("example", b"HEAD_IP=HEAD_IP\nRANK_IPS=RANK_IPS\n", TERMS), [])

    def test_email_blocks(self):
        fixture = "test" + "@example.invalid\n"
        self.assertTrue(scan_text("plant", fixture.encode(), TERMS))

    def test_pulse_id_blocks_even_when_constructed(self):
        fixture = "id=" + "0" * 32 + "\n"
        self.assertTrue(scan_text("plant", fixture.encode(), TERMS))

    def test_private_alias_and_person_terms_block(self):
        self.assertTrue(scan_text("plant", b"tailfixture synthetic-deny-term", TERMS))

    def test_internal_url_blocks(self):
        self.assertTrue(scan_text("plant", b"http://fixture-dashboard." + b"local:8726/", TERMS))

    def test_non_utf8_binary_blocks(self):
        self.assertTrue(scan_text("plant", bytes([255, 216, 255]), TERMS))

    def test_bearer_blocks(self):
        fixture = "Authorization: Bearer " + "syntheticvalue123\n"
        self.assertTrue(scan_text("plant", fixture.encode(), TERMS))

    def test_password_assignment_blocks(self):
        fixture = "SWITCH_ADMIN_PASS=" + "abcDEF123!\n"
        self.assertTrue(scan_text("plant", fixture.encode(), TERMS))

    def test_hf_token_blocks(self):
        fixture = "hf_" + "abcdefghijklmnopqrst\n"
        self.assertTrue(scan_text("plant", fixture.encode(), TERMS))

    def test_missing_private_denylist_fails_closed(self):
        old = os.environ.get("SPARK_RECIPES_DENYLIST_FILE")
        try:
            os.environ["SPARK_RECIPES_DENYLIST_FILE"] = "/tmp/synthetic-missing-denylist-file"
            with self.assertRaises(RuntimeError):
                scrub.load_private_terms()
        finally:
            if old is None:
                os.environ.pop("SPARK_RECIPES_DENYLIST_FILE", None)
            else:
                os.environ["SPARK_RECIPES_DENYLIST_FILE"] = old

    def test_staged_blob_blocks_after_worktree_delete(self):
        with tempfile.TemporaryDirectory() as td:
            repo = Path(td)
            subprocess.run(["git", "-C", td, "init", "-q"], check=True)
            sample = repo / "plant.txt"
            sample.write_text("HEAD=" + "192.168." + "255.254\n")
            subprocess.run(["git", "-C", td, "add", "plant.txt"], check=True)
            sample.unlink()
            old = scrub.ROOT
            try:
                scrub.ROOT = repo
                blobs = scrub.staged_blobs()
            finally:
                scrub.ROOT = old
            self.assertTrue(any(scan_text(name, data, TERMS) for name, data in blobs))

    def test_annotated_tag_message_blocks(self):
        with tempfile.TemporaryDirectory() as td:
            subprocess.run(["git", "-C", td, "init", "-q"], check=True)
            subprocess.run(["git", "-C", td, "-c", "user.name=Fixture", "-c", "user.email=none", "commit", "-q", "--allow-empty", "-m", "root"], check=True)
            msg = "synthetic tag " + "192.168." + "255.254"
            subprocess.run(["git", "-C", td, "-c", "user.name=Fixture", "-c", "user.email=none", "tag", "-a", "fixture", "-m", msg], check=True)
            old = scrub.ROOT
            try:
                scrub.ROOT = Path(td)
                objects = scrub.metadata_objects()
            finally:
                scrub.ROOT = old
            self.assertTrue(any(name.startswith("tag:") and scan_text(name, data, TERMS) for name, data in objects))


if __name__ == "__main__":
    unittest.main()
