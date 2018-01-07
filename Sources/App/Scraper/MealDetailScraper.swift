import Foundation
import SwiftSoup
import Regex

final class MealDetailScraper {
    static func extractTitle(from doc: Document) -> String {
        return (try? doc.getElementById("speiseplanessentext").flatMap { try $0.text() } ?? "") ?? ""
    }

    static func extractPrices(from doc: Document) -> (students: Double?, employees: Double?, isSoldOut: Bool) {
        let prices = (try? doc.getElementById("preise")?.text() ?? "") ?? ""
        guard !prices.contains("ausverkauft") else {
            return (nil, nil, true)
        }
        let digitsRegex = Regex("(\\d.,?\\s?\\d.)")
        let digits = digitsRegex.allMatches(in: prices).map { $0.captures[0] }

        let studentsPriceStr = digits.first??.replacingOccurrences(of: ",", with: ".")
        let employeePriceStr = digits.last??.replacingOccurrences(of: ",", with: ".")

        let studentsPrice = Double(studentsPriceStr ?? "")
        let employeePrice = Double(employeePriceStr ?? "")
        return (studentsPrice ?? 0, employeePrice ?? 0, false)
    }

    static func extractImageURL(from doc: Document) -> String? {
        guard let img = (try? doc.select("#essenbild img").attr("src")), !img.isEmpty else { return nil }
        guard !img.contains("noimage.png") else { return nil }
        return "https:\(img)".replacingOccurrences(of: "thumbs/", with: "")
    }

    private static func extractInfoHeaders(from doc: Document) -> [InfoSection] {
        guard let infos = try? doc.select("#speiseplandetailsrechts>h2") else { return [] }
        return infos.map { InfoSection(string: (try? $0.text()) ?? "") }
    }

    private static func extractInfos(at section: InfoSection, from doc: Document) -> [String] {
        let infoSections = extractInfoHeaders(from: doc)
        guard let secIdx = infoSections.index(of: section) else { return [] }
        let sectionIdx = Int(secIdx)

        guard let infos = try? doc.getElementsByClass("speiseplaninfos") else { return [] }
        let sectionBlock = infos.get(sectionIdx)
        guard let listItems = try? sectionBlock.select("li") else { return [] }
        guard let values = try? listItems.map({ try $0.text() }) else { return [] }
        return values
    }

    static func extractInformation(from doc: Document) -> [String] {
        return extractInfos(at: .information, from: doc)
    }

    static func extractAdditives(from doc: Document) -> [String] {
        return extractInfos(at: .additives, from: doc)
    }

    static func extractAllergens(from doc: Document) -> [String] {
        return extractInfos(at: .allergens, from: doc)
    }

    public static func scrape(document: Document, fromCanteen canteen: String, onDate date: ISODate, url: String) -> Meal {
        let title = MealDetailScraper.extractTitle(from: document)
        let (studentPrice, employeePrice, isSoldOut) = MealDetailScraper.extractPrices(from: document)
        let imgURL = MealDetailScraper.extractImageURL(from: document)

        let information = MealDetailScraper.extractInformation(from: document)
        let additives = MealDetailScraper.extractAdditives(from: document)
        let allergens = MealDetailScraper.extractAllergens(from: document)

        return Meal(title: title, canteen: canteen, date: date, isSoldOut: isSoldOut, studentPrice: studentPrice, employeePrice: employeePrice, image: imgURL, detailURL: url, information: information, additives: additives, allergens: allergens)
    }
}

private enum InfoSection: String {
    case information = "informationen"
    case additives = "zusatzstoffe"
    case allergens = "allergene"
    case unknown // placeholder for other possible section headers

    init(string: String) {
        let str = string.lowercased()
        if str.contains(InfoSection.information.rawValue) {
            self = .information
            return
        } else if str.contains(InfoSection.additives.rawValue) {
            self = .additives
            return
        } else if str.contains(InfoSection.allergens.rawValue) {
            self = .allergens
            return
        }
        self = .unknown
    }
}
