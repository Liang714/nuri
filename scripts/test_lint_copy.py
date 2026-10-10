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
        for phrase in ["Burn 200 kcal", "Burned 150 calories", "Burning 80 cal", "burns 300 Calories today",
                       "Burn 1,200 calories", "Burnt 200 kcal", "burn 200 cals", "Burn 1.5 kcals"]:
            with self.subTest(phrase=phrase):
                self.assertEqual(len(self.run_scan({phrase: "중립"})), 1)

    def test_burn_without_an_amount_is_not_flagged(self):
        self.assertEqual(self.run_scan({"Burn rate": "소모율", "Burn 3 candles": "초 3개", "Burn 2 calendars": "달력 2개"}), [])

    def test_before_and_after_variants(self):
        for phrase in ["Before and after", "before/after photos", "Before & after", "Before / After", "Before-and-after", "Before - and - after"]:
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

    def test_should_translate_false_entry_is_not_flagged(self):
        entries = {
            "Nuri": {"shouldTranslate": False},
            "© Nuri": {"shouldTranslate": False, "localizations": {"en": unit("© Nuri")}},
        }
        self.assertEqual(self.scan_entries(entries), [])

    def test_should_translate_false_entry_still_gets_the_banned_copy_scan(self):
        found = self.scan_entries({"Cheat day": {"shouldTranslate": False}})
        self.assertEqual(len(found), 1)
        self.assertNotIn("incomplete", found[0][2])

    def test_should_translate_true_entry_is_still_checked(self):
        self.assertEqual(len(self.scan_entries({"Hello": {"shouldTranslate": True}})), 2)

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

    # Variations (plural, device) can nest; an entry is translated when every leaf string unit is.
    @staticmethod
    def plural(**cases):
        return {"variations": {"plural": {name: unit(value, state) for name, (value, state) in cases.items()}}}

    def test_plural_variations_with_translated_leaves_pass(self):
        entry = {"localizations": {"en": self.plural(one=("%lld item", "translated"), other=("%lld items", "translated")),
                                   "ko": self.plural(other=("%lld개", "translated"))}}
        self.assertEqual(self.scan_entries({"%lld items": entry}), [])

    def test_nested_variations_with_translated_leaves_pass(self):
        en = {"variations": {"device": {"iphone": self.plural(one=("%lld meal", "translated"), other=("%lld meals", "translated")),
                                        "other": unit("%lld meals")}}}
        ko = {"variations": {"device": {"iphone": self.plural(other=("식사 %lld개", "translated")),
                                        "other": unit("식사 %lld개")}}}
        self.assertEqual(self.scan_entries({"%lld meals": {"localizations": {"en": en, "ko": ko}}}), [])

    def test_nested_variations_with_an_untranslated_leaf_are_reported(self):
        en = {"variations": {"device": {"iphone": self.plural(other=("%lld meals", "translated"))}}}
        ko = {"variations": {"device": {"iphone": self.plural(one=("식사 %lld개", "translated"), other=("식사 %lld개", "new"))}}}
        found = self.scan_entries({"%lld meals": {"localizations": {"en": en, "ko": ko}}})
        self.assertEqual(len(found), 1)
        self.assertIn("ko", found[0][2])

    def test_variation_case_without_any_text_is_reported(self):
        en = {"variations": {"plural": {"one": {}, "other": unit("%lld items")}}}
        ko = self.plural(other=("%lld개", "translated"))
        found = self.scan_entries({"%lld items": {"localizations": {"en": en, "ko": ko}}})
        self.assertEqual(len(found), 1)
        self.assertIn("en", found[0][2])

    def test_banned_copy_inside_nested_variations_is_found(self):
        en = {"variations": {"device": {"iphone": self.plural(other=("Burn 200 kcal", "translated"))}}}
        ko = {"variations": {"device": {"iphone": self.plural(other=("중립", "translated"))}}}
        found = self.scan_entries({"Calories": {"localizations": {"en": en, "ko": ko}}})
        self.assertEqual(len(found), 1)
        self.assertNotIn("incomplete", found[0][2])


if __name__ == "__main__":
    unittest.main()
