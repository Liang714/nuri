import json
import os
import tempfile
import unittest

from lint_copy import scan


def catalog(strings):
    data = {"sourceLanguage": "en", "version": "1.0", "strings": {
        key: {"localizations": {"ko": {"stringUnit": {"state": "translated", "value": ko}}}} for key, ko in strings.items()
    }}
    f = tempfile.NamedTemporaryFile("w", suffix=".xcstrings", delete=False)
    json.dump(data, f, ensure_ascii=False)
    f.close()
    return f.name


class LintCopyTests(unittest.TestCase):
    def tearDown(self):
        for p in getattr(self, "paths", []):
            os.unlink(p)

    def run_scan(self, strings):
        p = catalog(strings)
        self.paths = [p]
        return scan(p)

    def test_clean_copy_passes(self):
        self.assertEqual(self.run_scan({"Add food": "음식 추가", "A guide, not a limit.": "한도가 아니라 가이드예요."}), [])

    def test_english_banned_phrases(self):
        found = self.run_scan({"Burn it off with a run": "달리기", "Cheat day": "자유식", "Guilt-free snack": "간식"})
        self.assertEqual(len(found), 3)

    def test_korean_banned_phrases(self):
        found = self.run_scan({"Snack": "죄책감 없는 간식"})
        self.assertEqual(len(found), 1)

    def test_word_boundaries(self):
        # "learn" and "Earnings" must not trip the "earn" rule
        self.assertEqual(self.run_scan({"Learn more": "더 알아보기"}), [])


if __name__ == "__main__":
    unittest.main()
