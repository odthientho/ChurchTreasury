import Foundation

/// Text in the shape PDFKit extracts from Chase checking statements.
enum SampleStatements {
    /// Spans Dec 2025 -> Jan 2026; all five sections; totals consistent.
    static let yearBoundary = """
    JPMorgan Chase Bank, N.A.
    P O Box 182051
    Columbus, OH 43218-2051

    December 01, 2025 through January 05, 2026

    Account Number: 000000123456789

    CHECKING SUMMARY
    Chase Total Business Checking
    Beginning Balance $10,000.00
    Deposits and Additions 5,432.10
    Checks Paid -1,200.00
    ATM & Debit Card Withdrawals -150.25
    Electronic Withdrawals -800.55
    Fees -25.00
    Ending Balance $13,256.30

    DEPOSITS AND ADDITIONS
    DATE DESCRIPTION AMOUNT
    12/07 Deposit 1234567890 2,432.10
    12/14 Deposit 987654321 1,500.00
    01/04 Deposit 555443322 1,500.00
    Total Deposits and Additions $5,432.10

    CHECKS PAID
    CHECK NO. DATE PAID AMOUNT
    1101 ^ 12/10 $700.00
    1102 * 12/18 500.00
    Total Checks Paid $1,200.00

    ATM & DEBIT CARD WITHDRAWALS
    DATE DESCRIPTION AMOUNT
    12/20 Card Purchase 12/19 Home Depot #123 Anaheim CA Card 1234 150.25
    Total ATM & Debit Card Withdrawals $150.25

    ELECTRONIC WITHDRAWALS
    DATE DESCRIPTION AMOUNT
    12/15 Zelle Payment To Electric Co 800.55
    Total Electronic Withdrawals $800.55

    FEES
    DATE DESCRIPTION AMOUNT
    12/31 Monthly Service Fee 25.00
    Total Fees $25.00

    IN CASE OF ERRORS OR QUESTIONS ABOUT YOUR ELECTRONIC FUNDS TRANSFERS
    """

    /// Same statement but with rows merged onto single lines, as PDFKit
    /// sometimes extracts them. Must parse to the same transactions.
    static let mergedRows = """
    December 01, 2025 through January 05, 2026
    Beginning Balance $10,000.00
    Ending Balance $13,256.30
    DEPOSITS AND ADDITIONS
    12/07 Deposit 1234567890 2,432.10 12/14 Deposit 987654321 1,500.00 01/04 Deposit 555443322 1,500.00 Total Deposits and Additions $5,432.10
    CHECKS PAID
    1101 ^ 12/10 $700.00 1102 * 12/18 500.00 Total Checks Paid $1,200.00
    ATM & DEBIT CARD WITHDRAWALS
    12/20 Card Purchase 12/19 Home Depot #123 Anaheim CA Card 1234 150.25 Total ATM & Debit Card Withdrawals $150.25
    ELECTRONIC WITHDRAWALS
    12/15 Zelle Payment To Electric Co 800.55 Total Electronic Withdrawals $800.55
    FEES
    12/31 Monthly Service Fee 25.00 Total Fees $25.00
    """

    /// A malformed row inside DEPOSITS (garbled amount) must produce a warning,
    /// and the resulting totals mismatch must produce a second warning.
    static let malformedLine = """
    March 01, 2026 through March 31, 2026

    Beginning Balance $1,000.00
    Ending Balance $1,700.00

    DEPOSITS AND ADDITIONS
    DATE DESCRIPTION AMOUNT
    03/02 Deposit 111 300.00
    03/09 Deposit garbled OCR text 2OO.OO
    03/16 Deposit 222 200.00
    Total Deposits and Additions $700.00
    """
}
