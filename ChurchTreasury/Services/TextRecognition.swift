import Vision

/// The shared on-device text-recognition request used by every scan flow in
/// the app — checks, envelopes, and the weekly-report import.
///
/// `.accurate` is Vision's neural recognizer: it reads **handwriting** as well
/// as printed text. There is no separate "handwriting mode" — `.accurate` is
/// what enables handwriting recognition (`.fast` is print-only and meant for
/// live video). Handwriting is inherently lower-confidence and messier than
/// print, which is exactly why every scan flow in this app ends in an editable
/// review screen before anything is saved — the OCR is a starting point, never
/// the final word.
///
/// Languages are English + Vietnamese so a Vietnamese church's donor names
/// (often written with diacritics) read as well as the English column headers,
/// dollar amounts, and check numbers. English is listed first because the form
/// template, amounts, and check numbers are all Latin/ASCII; Vietnamese is the
/// fallback the recognizer leans on for accented names.
enum TextRecognition {

    static func makeRequest(usesLanguageCorrection: Bool) -> RecognizeTextRequest {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = [
            Locale.Language(identifier: "en-US"),
            Locale.Language(identifier: "vi-VN"),
        ]
        // Off for names/amounts/check numbers (correction "fixes" a surname
        // into a dictionary word); callers reading prose can opt back in.
        request.usesLanguageCorrection = usesLanguageCorrection
        return request
    }
}
