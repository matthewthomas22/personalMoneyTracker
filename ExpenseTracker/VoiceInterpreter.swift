import Foundation

struct VoiceInterpretation: Equatable {
    var amount: Int64?
    var expenseDescription: String?
    var sourceID: UUID?
    var channel: String?
    var date: Date?
    var unresolvedSource: String?
    var issues: [String] = []

    var isComplete: Bool {
        amount != nil && expenseDescription != nil && sourceID != nil && channel != nil && date != nil && issues.isEmpty
    }
}

/// Deliberately bounded grammar: unsupported wording becomes a draft, never a guessed expense.
enum VoiceInterpreter {
    static func interpret(_ transcript: String, sources: [PaymentSource], now: Date = Date(),
                          calendar: Calendar = .current) -> VoiceInterpretation {
        var result = VoiceInterpretation()
        // A follow-up belongs to the same capture, but is not part of the previous payment source's name.
        let followUpBoundary = "capturefollowupboundary"
        var text = PaymentSourceRules.key(transcript.replacingOccurrences(of: "\n", with: " \(followUpBoundary) "))
        guard !text.isEmpty else {
            result.issues = ["No text was captured. Type an expense or record again."]
            return result
        }
        if !matches(#"[-+−]\s*\d|\b(minus|negative|negatif|plus|quantity|purchases)\b"#, in: text).isEmpty {
            result.issues.append("Confirm one positive whole rupiah total for one purchase.")
        }
        if !matches(#"\b(around|roughly|approximately|kira|antara|between|refund|kembalian|discount|diskon)\b|kurang lebih"#, in: text).isEmpty {
            result.issues.append("Confirm the exact purchase amount and details.")
        }
        let datePhrases: [(String, Int)] = [("day before yesterday", -2), ("dua hari lalu", -2),
                                           ("yesterday", -1), ("kemarin", -1), ("today", 0), ("hari ini", 0)]
        var offsets: [Int] = []
        for (phrase, offset) in datePhrases where contains(phrase, in: text) {
            offsets.append(offset)
            text = removing(phrase, from: text)
        }
        let unsupportedDate = #"\b(tomorrow|besok|lusa|last|ago|minggu|bulan|tanggal|monday|tuesday|wednesday|thursday|friday|saturday|sunday|senin|selasa|rabu|kamis|jumat|sabtu|minggu|january|february|march|april|may|june|july|august|september|october|november|december|januari|februari|maret|mei|juni|juli|agustus|oktober|desember)\b|\d+[/-]\d+"#
        if Set(offsets).count > 1 || matches(unsupportedDate, in: text).count > 0 {
            result.issues.append("Choose the expense date explicitly.")
        } else {
            result.date = calendar.date(byAdding: .day, value: offsets.first ?? 0, to: calendar.startOfDay(for: now))
        }

        let channels: [(String, String)] = [("qris", "QRIS"), ("cash", "Cash"), ("tunai", "Cash"),
            ("transfer", "Transfer"), ("debit card", "Debit card"), ("kartu debit", "Debit card"),
            ("credit card", "Credit card"), ("kartu kredit", "Credit card")]
        var foundChannels = Set<String>()
        var paymentStart: String.Index?
        for (phrase, channel) in channels {
            for range in matches("\\b" + NSRegularExpression.escapedPattern(for: phrase) + "\\b", in: text) {
                foundChannels.insert(channel)
                if let start = Range(range, in: text)?.lowerBound, paymentStart == nil || start < paymentStart! { paymentStart = start }
            }
        }
        if foundChannels.count == 1 { result.channel = foundChannels.first }
        if foundChannels.count > 1 { result.issues.append("Which single payment channel was used?") }
        for range in matches(#"\b(pakai|menggunakan|using|paid with|paid by|pay with|via|with)\b"#, in: text) {
            if let start = Range(range, in: text)?.lowerBound, paymentStart == nil || start < paymentStart! { paymentStart = start }
        }
        if let paymentStart {
            var payment = String(text[paymentStart...])
            text = String(text[..<paymentStart])
            for (phrase, _) in channels { payment = removing(phrase, from: payment) }
            payment = payment.replacingOccurrences(of: #"\b(pakai|menggunakan|using|paid|pay|with|by|via|through|dengan|lewat|dan|and)\b"#, with: " ", options: .regularExpression)
            var parts = payment.components(separatedBy: followUpBoundary).map(cleaned)
            payment = parts.removeFirst()
            if payment.isEmpty, !parts.isEmpty { payment = parts.removeFirst() }
            if !parts.isEmpty {
                let followUp = parts.joined(separator: " ")
                for source in sources where ([source.name] + source.aliases).contains(where: { contains(PaymentSourceRules.key($0), in: followUp) }) {
                    result.issues.append("Confirm one payment source for this purchase: \(source.name).")
                }
                text += " " + followUp
            }
            payment = cleaned(payment)
            if payment.isEmpty, result.channel == "Cash" { payment = "cash" }
            if !payment.isEmpty {
                do {
                    if let source = try PaymentSourceRules.resolve(payment, in: sources) { result.sourceID = source.id }
                    else { result.unresolvedSource = payment }
                } catch { result.issues.append(error.localizedDescription) }
            }
        }

        let words = "nol|zero|satu|one|dua|two|tiga|three|empat|four|lima|five|enam|six|tujuh|seven|delapan|eight|sembilan|nine|sepuluh|sebelas|dua belas|tiga belas|empat belas|lima belas|enam belas|tujuh belas|delapan belas|sembilan belas|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|thirty|forty|fifty|sixty|seventy|eighty|ninety|puluh|belas|hundred|ratus|seratus|thousand|ribu|seribu|million|juta"
        let number = "(?:\\d[\\d.,]*|(?:" + words + ")(?:[ -]+(?:" + words + "))*)"
        let pattern = "\\b(?:rp\\s*)?" + number + "(?:\\s*(?:ribu|thousand|juta|million|k))?(?:\\s*(?:rupiah|idr))?\\b"
        let ranges = matches(pattern, in: text)
        var amounts: [Int64] = []
        for range in ranges {
            guard let swiftRange = Range(range, in: text) else { continue }
            let phrase = String(text[swiftRange])
            let markedWords = phrase.hasPrefix("rp") || !matches(#"\b(rupiah|idr|ribu|thousand|juta|million|seribu|k)\b"#, in: phrase).isEmpty
            let amountContext = !matches(#"\b(for|seharga|harga|amount|jumlah|total)\s*$"#, in: String(text[..<swiftRange.lowerBound])).isEmpty
            if !markedWords && !amountContext {
                result.issues.append("Say the amount with rupiah, ribu, or thousand to distinguish it from item quantities.")
            }
            if let amount = parseAmount(phrase) { amounts.append(amount) }
            else { result.issues.append("Confirm the whole rupiah amount.") }
        }
        if amounts.count == 1 { result.amount = amounts[0] }
        if amounts.count > 1 {
            let clearCombination = contains("dan", in: text) || contains("and", in: text)
            let uncertainty = matches(#"\b(total|jumlah|atau|or|maybe|mungkin|sekitar|about|change|kembalian|discount|diskon)\b"#, in: text).count > 0
            if clearCombination && !uncertainty {
                var sum: Int64 = 0
                for amount in amounts {
                    let next = sum.addingReportingOverflow(amount)
                    if next.overflow { result.issues.append("Amount exceeds the supported range."); break }
                    sum = next.partialValue
                }
                if result.issues.isEmpty { result.amount = sum }
            } else { result.issues.append("Confirm one total for this purchase.") }
        }
        if matches(#"\b(atau|or|maybe|mungkin|sekitar|about)\b"#, in: text).count > 0 {
            result.issues.append("Confirm the uncertain purchase details.")
        }
        for range in ranges.reversed() { if let r = Range(range, in: text) { text.replaceSubrange(r, with: " ") } }
        text = removing(followUpBoundary, from: text)
        text = text.replacingOccurrences(of: #"\b(i|bought|buy|purchased|spent|beli|membeli|for|seharga|harga|sebesar|rp|rupiah|idr)\b"#, with: " ", options: .regularExpression)
        let description = cleaned(text)
        if !description.isEmpty && description != "dan" && description != "and" { result.expenseDescription = description }
        return result
    }

    private static func matches(_ pattern: String, in text: String) -> [NSRange] {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        return expression.matches(in: text, range: NSRange(text.startIndex..., in: text)).map(\.range)
    }
    private static func contains(_ phrase: String, in text: String) -> Bool {
        !matches("\\b" + NSRegularExpression.escapedPattern(for: phrase) + "\\b", in: text).isEmpty
    }
    private static func removing(_ phrase: String, from text: String) -> String {
        text.replacingOccurrences(of: "\\b" + NSRegularExpression.escapedPattern(for: phrase) + "\\b", with: " ", options: .regularExpression)
    }
    private static func cleaned(_ text: String) -> String {
        PaymentSourceRules.cleaned(text.replacingOccurrences(of: #"[,;:!?]"#, with: " ", options: .regularExpression))
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
    }

    private static func parseAmount(_ phrase: String) -> Int64? {
        var text = phrase.replacingOccurrences(of: #"^rp\s*|\b(rupiah|idr)\b"#, with: "", options: .regularExpression)
        text = PaymentSourceRules.cleaned(text).replacingOccurrences(of: "-", with: " ")
        let units: [String: Int64] = ["ribu": 1000, "thousand": 1000, "k": 1000, "juta": 1000000, "million": 1000000]
        var multiplier: Int64 = 1
        for (unit, value) in units where text.first?.isNumber == true && text.hasSuffix(unit) {
            multiplier = value
            text = String(text.dropLast(unit.count)).trimmingCharacters(in: .whitespaces)
            break
        }
        if text.first?.isNumber == true {
            // Grouped whole rupiah only; ambiguous decimal notation requires clarification.
            guard text.range(of: #"^(\d+|\d{1,3}([.,]\d{3})+)$"#, options: .regularExpression) != nil else { return nil }
            let digits = text.filter(\.isNumber)
            guard let value = Int64(digits), value > 0 else { return nil }
            let product = value.multipliedReportingOverflow(by: multiplier)
            return product.overflow ? nil : product.partialValue
        }
        let values: [String: Int64] = ["nol":0,"zero":0,"satu":1,"one":1,"dua":2,"two":2,"tiga":3,"three":3,"empat":4,"four":4,"lima":5,"five":5,"enam":6,"six":6,"tujuh":7,"seven":7,"delapan":8,"eight":8,"sembilan":9,"nine":9,"sepuluh":10,"ten":10,"sebelas":11,"eleven":11,"twelve":12,"thirteen":13,"fourteen":14,"fifteen":15,"sixteen":16,"seventeen":17,"eighteen":18,"nineteen":19,"twenty":20,"thirty":30,"forty":40,"fifty":50,"sixty":60,"seventy":70,"eighty":80,"ninety":90]
        func small(_ tokens: [String]) -> Int64? {
            guard !tokens.isEmpty else { return 0 }
            if tokens.count == 1 { return values[tokens[0]] }
            if let hundred = tokens.firstIndex(where: { $0 == "hundred" || $0 == "ratus" }) {
                guard hundred == 1, let prefix = values[tokens[0]], (1...9).contains(prefix),
                      let rest = small(Array(tokens.dropFirst(2))), rest < 100 else { return nil }
                return prefix * 100 + rest
            }
            if tokens.count == 2, let first = values[tokens[0]] {
                if tokens[1] == "belas", (2...9).contains(first) { return 10 + first }
                if tokens[1] == "puluh", (2...9).contains(first) { return first * 10 }
                if first >= 20, first % 10 == 0, let last = values[tokens[1]], (1...9).contains(last) { return first + last }
            }
            if tokens.count == 3, let first = values[tokens[0]], (2...9).contains(first),
               tokens[1] == "puluh", let last = values[tokens[2]], (1...9).contains(last) { return first * 10 + last }
            return nil
        }
        text = text.replacingOccurrences(of: "seratus", with: "satu ratus").replacingOccurrences(of: "seribu", with: "satu ribu")
        var chunk: [String] = []
        var total: Int64 = 0
        var lastScale = Int64.max
        for token in text.split(separator: " ").map(String.init) {
            if let scale = units[token] {
                guard scale < lastScale, let value = small(chunk), value > 0 else { return nil }
                total += value * scale
                chunk = []
                lastScale = scale
            } else { chunk.append(token) }
        }
        guard let tail = small(chunk) else { return nil }
        let value = total + tail
        return value > 0 ? value : nil
    }
}
