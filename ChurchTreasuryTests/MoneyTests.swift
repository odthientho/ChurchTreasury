import Testing
@testable import ChurchTreasury

struct MoneyTests {
    @Test func parsesPlainDollars() {
        #expect(Money.parseCents("1234") == 123400)
    }

    @Test func parsesDollarsAndCents() {
        #expect(Money.parseCents("1234.56") == 123456)
    }

    @Test func parsesCommasAndSymbol() {
        #expect(Money.parseCents("$1,234.56") == 123456)
    }

    @Test func parsesSingleFractionDigit() {
        #expect(Money.parseCents("0.5") == 50)
        #expect(Money.parseCents(".5") == 50)
    }

    @Test func parsesNegativeForms() {
        #expect(Money.parseCents("-25.00") == -2500)
        #expect(Money.parseCents("(25.00)") == -2500)
    }

    @Test func rejectsInvalidInput() {
        #expect(Money.parseCents("") == nil)
        #expect(Money.parseCents("abc") == nil)
        #expect(Money.parseCents("1.2.3") == nil)
        #expect(Money.parseCents("12.345") == nil)
    }

    @Test func formatsCurrency() {
        #expect(Money.format(123456).contains("1,234.56"))
    }
}
