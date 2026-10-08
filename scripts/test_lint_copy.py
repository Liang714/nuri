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

    def test_english_inflections_and_exercise_as_compensation(self):
        for phrase in ["Cheated on lunch", "Burned off", "Work off dinner", "Log your meals"]:
            with self.subTest(phrase=phrase):
                self.assertEqual(len(self.run_scan({phrase: "중립"})), 1)

    def test_korean_phrases_tolerate_spacing(self):
        for phrase in ["보상운동", "살빼기", "다이어트에 실패", "나쁜 음식", "정크푸드", "칼로리를 태워요", "운동으로 만회"]:
            with self.subTest(phrase=phrase):
                self.assertEqual(len(self.run_scan({"Snack": phrase})), 1)

    def test_add_meals_passes(self):
        self.assertEqual(self.run_scan({"Add meals": "식사 추가"}), [])

    def test_key_equal_to_english_value_is_reported_once(self):
        data = {"sourceLanguage": "en", "version": "1.0", "strings": {
            "Cheat day": {"localizations": {
                "en": {"stringUnit": {"state": "translated", "value": "Cheat day"}},
                "ko": {"stringUnit": {"state": "translated", "value": "자유식"}},
            }}
        }}
        f = tempfile.NamedTemporaryFile("w", suffix=".xcstrings", delete=False)
        json.dump(data, f, ensure_ascii=False)
        f.close()
        self.paths = [f.name]
        self.assertEqual(len(scan(f.name)), 1)


if __name__ == "__main__":
    unittest.main()
