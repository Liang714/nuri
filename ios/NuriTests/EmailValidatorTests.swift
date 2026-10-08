import Testing
@testable import Nuri

@Suite struct EmailValidatorTests {
    @Test(arguments: ["you@example.com", "a@b.co", "  you@example.com  ", "first.last+tag@sub.example.org"])
    func plausible(_ text: String) { #expect(EmailValidator.isPlausible(text)) }

    @Test(arguments: ["", "no-at.com", "a@b", "a@.com", "a b@c.com", "a@@b.com", "@example.com", "a@b.c"])
    func notPlausible(_ text: String) { #expect(!EmailValidator.isPlausible(text)) }
}
