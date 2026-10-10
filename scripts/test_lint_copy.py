import json
import os
import tempfile
import unittest

from lint_copy import scan


def unit(value, state="translated"):
    return {"stringUnit": {"state": state, "value": value}}


def write_catalog(strings):
    f = tempfile.NamedTemporaryFile("w", suffix=".xcstrings", delete=False)
    json.dump({"sourceLanguage": "en", "version": "1.0", "strings": strings}, f, ensure_ascii=False)
    f.close()
    return f.name


def catalog(strings):
    """Complete entries: English value equals the key (as in the app catalog), Korean from `strings`."""
    return write_catalog({key: {"localizations": {"en": unit(key), "ko": unit(ko)}} for key, ko in strings.items()})


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
        self.assertEqual(len(self.run_scan({"Cheat day": "자유식"})), 1)

    def test_burn_with_an_amount_is_compensation_framing(self):
        for phrase in ["Burn 200 kcal", "Burned 150 calories", "Burning 80 cal", "burns 300 Calories today"]:
            with self.subTest(phrase=phrase):
                self.assertEqual(len(self.run_scan({phrase: "중립"})), 1)

    def test_burn_without_an_amount_is_not_flagged(self):
        self.assertEqual(self.run_scan({"Burn rate": "소모율", "Burn 3 candles": "초 3개"}), [])

    def test_before_and_after_variants(self):
        for phrase in ["Before and after", "before/after photos", "Before & after", "Before / After"]:
            with self.subTest(phrase=phrase):
                self.assertEqual(len(self.run_scan({phrase: "중립"})), 1)

    def test_works_off_device_is_not_work_off_compensation(self):
        self.assertEqual(self.run_scan({"Works off-device": "기기 없이도 작동해요", "Offline mode": "오프라인"}), [])

    def test_work_off_followed_by_punctuation_is_still_flagged(self):
        for phrase in ["Work it off.", "Burn it off!", "Work off, then rest"]:
            with self.subTest(phrase=phrase):
                self.assertEqual(len(self.run_scan({phrase: "중립"})), 1)

    # Completeness: every key needs translated, non-empty en and ko values.
    def scan_entries(self, entries):
        p = write_catalog(entries)
        self.paths = [p]
        return scan(p)

    def test_complete_entry_passes(self):
        self.assertEqual(self.scan_entries({"Hello": {"localizations": {"en": unit("Hello"), "ko": unit("안녕하세요")}}}), [])

    def test_missing_korean_is_reported(self):
        found = self.scan_entries({"Hello": {"localizations": {"en": unit("Hello")}}})
        self.assertEqual(len(found), 1)
        self.assertIn("ko", found[0][2])

    def test_missing_english_is_reported(self):
        found = self.scan_entries({"Hello": {"localizations": {"ko": unit("안녕하세요")}}})
        self.assertEqual(len(found), 1)
        self.assertIn("en", found[0][2])

    def test_entry_without_localizations_is_reported_for_both_languages(self):
        self.assertEqual(len(self.scan_entries({"Hello": {}})), 2)

    def test_untranslated_state_is_reported(self):
        for state in ["new", "needs_review", "stale"]:
            with self.subTest(state=state):
                found = self.scan_entries({"Hello": {"localizations": {"en": unit("Hello"), "ko": unit("안녕", state)}}})
                self.assertEqual(len(found), 1)

    def test_empty_or_blank_value_is_reported(self):
        for value in ["", "   "]:
            with self.subTest(value=value):
                found = self.scan_entries({"Hello": {"localizations": {"en": unit("Hello"), "ko": unit(value)}}})
                self.assertEqual(len(found), 1)


if __name__ == "__main__":
    unittest.main()
