//
//  BookmarkService.swift
//  CalendarNotes
//
//  Provides bookmark metadata fetching, favicon/image caching, import/export,
//  QR generation, URL validation, duplicate detection, and tag suggestions.
//

import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
import PDFKit
typealias CNImage = NSImage
#else
import UIKit
import PDFKit
typealias CNImage = UIImage
#endif

struct BookmarkPageMetadata: Codable, Sendable {
    let title: String?
    let description: String?
    let imageURL: URL?
    let faviconURL: URL?
    let keywords: [String]
    let suggestedTags: [String]
    let htmlSnippet: String?
    let contentType: BookmarkContentType
    let contentSubtype: String?
    let contentMetadata: BookmarkContentMetadata?
    let mimeType: String?
    let finalURL: URL?
    
    init(
        title: String?,
        description: String?,
        imageURL: URL?,
        faviconURL: URL?,
        keywords: [String],
        suggestedTags: [String],
        htmlSnippet: String?,
        contentType: BookmarkContentType,
        contentSubtype: String? = nil,
        contentMetadata: BookmarkContentMetadata? = nil,
        mimeType: String? = nil,
        finalURL: URL?
    ) {
        self.title = title
        self.description = description
        self.imageURL = imageURL
        self.faviconURL = faviconURL
        self.keywords = keywords
        self.suggestedTags = suggestedTags
        self.htmlSnippet = htmlSnippet
        self.contentType = contentType
        self.contentSubtype = contentSubtype
        self.contentMetadata = contentMetadata
        self.mimeType = mimeType
        self.finalURL = finalURL
    }
    
    private enum CodingKeys: String, CodingKey {
        case title
        case description
        case imageURL
        case faviconURL
        case keywords
        case suggestedTags
        case htmlSnippet
        case contentType
        case contentSubtype
        case contentMetadata
        case mimeType
        case finalURL
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        imageURL = try container.decodeIfPresent(URL.self, forKey: .imageURL)
        faviconURL = try container.decodeIfPresent(URL.self, forKey: .faviconURL)
        keywords = try container.decodeIfPresent([String].self, forKey: .keywords) ?? []
        suggestedTags = try container.decodeIfPresent([String].self, forKey: .suggestedTags) ?? []
        htmlSnippet = try container.decodeIfPresent(String.self, forKey: .htmlSnippet)
        contentType = try container.decodeIfPresent(BookmarkContentType.self, forKey: .contentType) ?? .unknown
        contentSubtype = try container.decodeIfPresent(String.self, forKey: .contentSubtype)
        contentMetadata = try container.decodeIfPresent(BookmarkContentMetadata.self, forKey: .contentMetadata)
        mimeType = try container.decodeIfPresent(String.self, forKey: .mimeType)
        finalURL = try container.decodeIfPresent(URL.self, forKey: .finalURL)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(imageURL, forKey: .imageURL)
        try container.encodeIfPresent(faviconURL, forKey: .faviconURL)
        try container.encode(keywords, forKey: .keywords)
        try container.encode(suggestedTags, forKey: .suggestedTags)
        try container.encodeIfPresent(htmlSnippet, forKey: .htmlSnippet)
        try container.encode(contentType, forKey: .contentType)
        try container.encodeIfPresent(contentSubtype, forKey: .contentSubtype)
        try container.encodeIfPresent(contentMetadata, forKey: .contentMetadata)
        try container.encodeIfPresent(mimeType, forKey: .mimeType)
        try container.encodeIfPresent(finalURL, forKey: .finalURL)
    }
}


struct BookmarkCacheUsage: Sendable {
    let faviconBytes: Int64
    let previewBytes: Int64
    let metadataBytes: Int64
    var totalBytes: Int64 { faviconBytes + previewBytes + metadataBytes }
}

@MainActor
final class BookmarkService {
    static let shared = BookmarkService()
    
    typealias PageMetadata = BookmarkPageMetadata
    
    private struct LoadedResource {
        let data: Data
        let finalURL: URL
        let response: HTTPURLResponse
        let html: String?
        
        var mimeType: String? { response.mimeType?.lowercased() }
    }
    
    private struct ContentAnalysis {
        let type: BookmarkContentType
        let subtype: String?
        let metadata: BookmarkContentMetadata?
        let keywordHints: [String]
        
        static let unknown = ContentAnalysis(type: .unknown, subtype: nil, metadata: nil, keywordHints: [])
    }
    
    private final class MetadataCacheBox: NSObject {
        let value: BookmarkPageMetadata
        let expiry: Date
        
        init(value: BookmarkPageMetadata, ttl: TimeInterval) {
            self.value = value
            self.expiry = Date().addingTimeInterval(ttl)
        }
        
        var isExpired: Bool { Date() > expiry }
    }
    
    private let coreDataManager = CoreDataManager.shared
    private let urlSession: URLSession
    private let metadataCache = NSCache<NSURL, MetadataCacheBox>()
    private let faviconMemoryCache = NSCache<NSString, NSData>()
    private let previewMemoryCache = NSCache<NSString, NSData>()
    private let diskQueue = DispatchQueue(label: "com.calendarnotes.bookmarkservice.diskcache", qos: .utility)
    private let metadataCacheTTL: TimeInterval = 60 * 30
    private let performanceMonitor = PerformanceMonitor.shared
    private let isoDateFormatter: ISO8601DateFormatter
    
    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        self.urlSession = URLSession(configuration: configuration)
        
        metadataCache.countLimit = 256
        faviconMemoryCache.countLimit = 256
        previewMemoryCache.countLimit = 128
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.isoDateFormatter = dateFormatter
        
        createCacheDirectoriesIfNeeded()
    }
    
    // MARK: - Metadata
    
    func fetchMetadata(for url: URL) async throws -> BookmarkPageMetadata {
        if let cached = cachedMetadata(for: url) {
            return cached
        }
        
        let resource = try await loadResource(url)
        let html = resource.html
        let meta = html.map(parseMeta) ?? [:]
        let finalURL = resource.finalURL
        
        let primaryTitle = meta["og:title"] ?? meta["twitter:title"] ?? meta["title"]
        let title = (primaryTitle?.isEmpty ?? true) ? readableTitle(from: finalURL) : primaryTitle
        let description = meta["og:description"] ?? meta["twitter:description"] ?? meta["description"]
        
        var imageURL = URL(string: meta["og:image"] ?? meta["twitter:image"] ?? "")
        let faviconURL = (html.flatMap { resolveFavicon(inHTML: $0, pageURL: finalURL) } ?? defaultFavicon(for: finalURL))
        let analysis = await analyzeContent(resource: resource, meta: meta)
        if imageURL == nil {
            imageURL = analysis.metadata?.primaryThumbnailURL
        }
        
        var textSources: [String] = []
        if let title { textSources.append(title) }
        if let description { textSources.append(description) }
        if let html { textSources.append(extractBodyText(from: html)) }
        if let pdfText = analysis.metadata?.pdf?.extractedTextPreview { textSources.append(pdfText) }
        if let ingredients = analysis.metadata?.recipe?.ingredients, !ingredients.isEmpty {
            textSources.append(ingredients.joined(separator: " "))
        }
        let baseKeywords = Self.keywords(from: textSources.joined(separator: " "))
        let keywords = mergeKeywords(base: baseKeywords, hints: analysis.keywordHints)
        var tags: [String] = []
        appendUnique(analysis.type.rawValue, to: &tags)
        appendUnique(analysis.subtype, to: &tags)
        analysis.keywordHints.forEach { appendUnique($0, to: &tags) }
        keywords.prefix(5).forEach { appendUnique($0, to: &tags) }
        let snippet = html.flatMap { summarizeHTML($0) } ?? analysis.metadata?.pdf?.extractedTextPreview
        
        let metadata = BookmarkPageMetadata(
            title: title,
            description: description,
            imageURL: imageURL,
            faviconURL: faviconURL,
            keywords: keywords,
            suggestedTags: tags,
            htmlSnippet: snippet,
            contentType: analysis.type,
            contentSubtype: analysis.subtype,
            contentMetadata: analysis.metadata,
            mimeType: resource.mimeType,
            finalURL: finalURL
        )
        cacheMetadata(metadata, for: finalURL)
        return metadata
    }
    
    private func mergeKeywords(base: [String], hints: [String]) -> [String] {
        var seen = Set<String>()
        var combined: [String] = []
        for word in hints + base {
            let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let lower = trimmed.lowercased()
            if seen.insert(lower).inserted {
                combined.append(trimmed)
            }
        }
        return combined
    }
    
    private func appendUnique(_ value: String?, to array: inout [String]) {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return }
        let lower = value.lowercased()
        if !array.contains(where: { $0.lowercased() == lower }) {
            array.append(value)
        }
    }
    
    private func summarizeHTML(_ html: String) -> String {
        let body = extractBodyText(from: html)
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 240 else { return trimmed }
        let endIndex = trimmed.index(trimmed.startIndex, offsetBy: min(240, trimmed.count))
        return String(trimmed[..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func analyzeContent(resource: LoadedResource, meta: [String: String]) async -> ContentAnalysis {
        let mimeType = resource.mimeType ?? ""
        let url = resource.finalURL
        let html = resource.html
        let jsonLD = html.map(extractJSONLDDictionaries) ?? []
        
        if isPDFResource(url: url, mimeType: mimeType) {
            return analyzePDF(resource: resource, meta: meta)
        }
        if isImageResource(url: url, mimeType: mimeType) {
            return analyzeImage(resource: resource)
        }
        if isVideoResource(url: url, mimeType: mimeType, meta: meta, jsonLD: jsonLD) {
            return analyzeVideo(resource: resource, meta: meta, jsonLD: jsonLD)
        }
        if isRepositoryResource(url: url) {
            return await analyzeRepository(resource: resource, meta: meta)
        }
        if isRecipeResource(meta: meta, jsonLD: jsonLD) {
            return analyzeRecipe(resource: resource, meta: meta, jsonLD: jsonLD)
        }
        if isProductResource(meta: meta, jsonLD: jsonLD) {
            return analyzeProduct(resource: resource, meta: meta, jsonLD: jsonLD)
        }
        if isSocialResource(url: url) {
            return analyzeSocial(resource: resource, meta: meta)
        }
        return analyzeArticle(resource: resource, meta: meta, html: html)
    }
    
    private func isPDFResource(url: URL, mimeType: String) -> Bool {
        if mimeType.contains("pdf") { return true }
        let ext = url.pathExtension.lowercased()
        return ext == "pdf"
    }
    
    private func isImageResource(url: URL, mimeType: String) -> Bool {
        if mimeType.hasPrefix("image/") { return true }
        let ext = url.pathExtension.lowercased()
        return ["png","jpg","jpeg","gif","webp","heic","heif","tiff","bmp","svg"].contains(ext)
    }
    
    private func isVideoResource(url: URL, mimeType: String, meta: [String: String], jsonLD: [[String: Any]]) -> Bool {
        if mimeType.hasPrefix("video/") { return true }
        if let type = meta["og:type"], type.localizedCaseInsensitiveContains("video") { return true }
        if let card = meta["twitter:card"], card == "player" { return true }
        if videoProvider(for: url) != nil { return true }
        return jsonLD.contains { hasType($0, matching: "VideoObject") }
    }
    
    private func isRepositoryResource(url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host.contains("github.com") && url.pathComponents.count >= 3
    }
    
    private func isRecipeResource(meta: [String: String], jsonLD: [[String: Any]]) -> Bool {
        if let type = meta["og:type"], type.localizedCaseInsensitiveContains("recipe") { return true }
        return jsonLD.contains { hasType($0, matching: "Recipe") }
    }
    
    private func isProductResource(meta: [String: String], jsonLD: [[String: Any]]) -> Bool {
        if let type = meta["og:type"], type.localizedCaseInsensitiveContains("product") { return true }
        if meta["product:price:amount"] != nil { return true }
        return jsonLD.contains { hasType($0, matching: "Product") }
    }
    
    private func isSocialResource(url: URL) -> Bool {
        socialPlatform(for: url) != nil
    }
    
    private func analyzePDF(resource: LoadedResource, meta: [String: String]) -> ContentAnalysis {
        #if canImport(PDFKit)
        if let document = PDFDocument(data: resource.data) {
            let attributes = document.documentAttributes ?? [:]
            let author = attributes[PDFDocumentAttribute.authorAttribute] as? String
            let subject = attributes[PDFDocumentAttribute.subjectAttribute] as? String
            let rawKeywords = attributes[PDFDocumentAttribute.keywordsAttribute]
            let keywords = coerceStringArray(rawKeywords).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            let text = (document.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let snippet = text.isEmpty ? nil : String(text.prefix(2000))
            let pdf = BookmarkContentMetadata.PDFMetadata(
                pageCount: document.pageCount > 0 ? document.pageCount : nil,
                fileSizeBytes: Int64(resource.data.count),
                author: author,
                subject: subject,
                keywords: keywords.isEmpty ? nil : keywords,
                allowsAnnotations: !document.isLocked,
                hasOCRText: !text.isEmpty,
                extractedTextPreview: snippet
            )
            let hints = ["pdf","document"] + keywords.map { $0.lowercased() }
            return ContentAnalysis(type: .pdf, subtype: "PDF", metadata: metadata(pdf: pdf), keywordHints: hints)
        }
        #endif
        let fallback = BookmarkContentMetadata.PDFMetadata(
            pageCount: nil,
            fileSizeBytes: Int64(resource.data.count),
            allowsAnnotations: true,
            hasOCRText: false
        )
        return ContentAnalysis(type: .pdf, subtype: "PDF", metadata: metadata(pdf: fallback), keywordHints: ["pdf","document"])
    }
    
    private func analyzeImage(resource: LoadedResource) -> ContentAnalysis {
        var width: Int?
        var height: Int?
        var format: String?
        var colorProfile: String?
        if let mime = resource.mimeType, mime.hasPrefix("image/") {
            format = mime.replacingOccurrences(of: "image/", with: "").uppercased()
        }
        if let source = CGImageSourceCreateWithData(resource.data as CFData, nil),
           let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] {
            if let w = properties[kCGImagePropertyPixelWidth] as? NSNumber { width = w.intValue }
            if let h = properties[kCGImagePropertyPixelHeight] as? NSNumber { height = h.intValue }
            if let model = properties[kCGImagePropertyColorModel] as? NSString {
                colorProfile = model as String
            }
            if format == nil, let type = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any],
               let model = type[kCGImagePropertyTIFFModel] as? NSString {
                format = model as String
            }
        }
        let image = BookmarkContentMetadata.ImageMetadata(
            width: width,
            height: height,
            fileSizeBytes: Int64(resource.data.count),
            format: format,
            colorProfile: colorProfile,
            remoteURL: resource.finalURL
        )
        var hints = ["image", "photo"]
        if let format { hints.append(format.lowercased()) }
        if let profile = colorProfile { hints.append(profile.lowercased()) }
        return ContentAnalysis(type: .image, subtype: format, metadata: metadata(image: image), keywordHints: hints)
    }
    
    private func analyzeVideo(resource: LoadedResource, meta: [String: String], jsonLD: [[String: Any]]) -> ContentAnalysis {
        let url = resource.finalURL
        let provider = videoProvider(for: url)
        var duration = parseDurationValue(meta["og:video:duration"] ?? meta["video:duration"] ?? meta["duration"])
        if duration == nil {
            duration = extractDurationFromJSONLD(jsonLD)
        }
        if duration == nil, let html = resource.html {
            duration = extractDurationFromHTMLMeta(html)
        }
        if duration == nil, resource.mimeType?.hasPrefix("video/") == true {
            duration = nil
        }
        var thumbnail = safeURL(from: meta["og:image"] ?? meta["twitter:image"])
        if thumbnail == nil {
            thumbnail = extractFirstImageURL(from: jsonLD)
        }
        let embed = safeURL(from: meta["og:video:url"] ?? meta["og:video"] ?? meta["twitter:player"]) ?? url
        var uploadDate = parseDate(meta["video:release_date"] ?? meta["upload_date"] ?? meta["article:published_time"])
        if uploadDate == nil {
            uploadDate = extractDateFromJSONLD(jsonLD, keys: ["uploadDate", "datePublished"])
        }
        let downloadURL: URL? = resource.mimeType?.hasPrefix("video/") == true ? url : safeURL(from: meta["og:video:secure_url"] ?? meta["og:video:url"])
        let channel = meta["video:channel"] ?? meta["og:site_name"] ?? provider
        let isLive = (meta["og:video:live_broadcast"]?.lowercased() == "true") || (meta["og:video:tag"]?.localizedCaseInsensitiveContains("live") == true)
        let video = BookmarkContentMetadata.VideoMetadata(
            duration: duration,
            thumbnailURL: thumbnail,
            embedURL: embed,
            channelName: channel,
            uploadDate: uploadDate,
            downloadURL: downloadURL,
            isLiveStream: isLive
        )
        var hints = ["video"]
        if let provider { hints.append(provider.lowercased()) }
        if let channel { hints.append(channel.lowercased()) }
        return ContentAnalysis(type: .video, subtype: provider, metadata: metadata(video: video), keywordHints: hints)
    }
    
    private func analyzeRepository(resource: LoadedResource, meta: [String: String]) async -> ContentAnalysis {
        let pathComponents = resource.finalURL.path.split(separator: "/").map(String.init)
        guard pathComponents.count >= 2 else {
            var repoMeta = BookmarkContentMetadata.RepositoryMetadata()
            repoMeta.openGraphImageURL = safeURL(from: meta["og:image"])
            return ContentAnalysis(type: .repository, subtype: nil, metadata: metadata(repository: repoMeta), keywordHints: ["repository", "github"])
        }
        let owner = pathComponents[0]
        let name = pathComponents[1]
        var repoMeta = await fetchGitHubRepositoryMetadata(owner: owner, name: name) ?? BookmarkContentMetadata.RepositoryMetadata()
        if repoMeta.openGraphImageURL == nil {
            repoMeta.openGraphImageURL = safeURL(from: meta["og:image"])
        }
        var hints = ["repository", "github", owner.lowercased(), name.lowercased()]
        if let language = repoMeta.language { hints.append(language.lowercased()) }
        if let license = repoMeta.license { hints.append(license.lowercased()) }
        return ContentAnalysis(type: .repository, subtype: repoMeta.language, metadata: metadata(repository: repoMeta), keywordHints: hints)
    }
    
    private func analyzeRecipe(resource: LoadedResource, meta: [String: String], jsonLD: [[String: Any]]) -> ContentAnalysis {
        let recipeDict = jsonLD.first { hasType($0, matching: "Recipe") }
        let ingredients = recipeDict.flatMap { coerceStringArray($0["recipeIngredient"] ?? $0["ingredients"]) } ?? []
        let cookSeconds = parseDurationValue(recipeDict?["cookTime"]) ?? parseDurationValue(recipeDict?["totalTime"]) ?? parseDurationValue(meta["totalTime"])
        let prepSeconds = parseDurationValue(recipeDict?["prepTime"]) ?? parseDurationValue(meta["prepTime"])
        let cookMinutes = durationMinutes(from: cookSeconds)
        let prepMinutes = durationMinutes(from: prepSeconds)
        let cuisine = (recipeDict?["recipeCuisine"] as? String) ?? (recipeDict?["cuisine"] as? String)
        let servings = firstInteger(in: (recipeDict?["recipeYield"] as? String) ?? (meta["recipeYield"]))
        var recipe = BookmarkContentMetadata.RecipeMetadata(
            ingredients: ingredients,
            cookTimeMinutes: cookMinutes,
            prepTimeMinutes: prepMinutes,
            servings: servings,
            cuisine: cuisine
        )
        if recipe.ingredients.isEmpty, let description = meta["description"] {
            recipe.ingredients = description.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }.filter { !$0.isEmpty }
        }
        var hints = ["recipe", "cooking"]
        if let cuisine { hints.append(cuisine.lowercased()) }
        return ContentAnalysis(type: .recipe, subtype: cuisine, metadata: metadata(recipe: recipe), keywordHints: hints)
    }
    
    private func analyzeProduct(resource: LoadedResource, meta: [String: String], jsonLD: [[String: Any]]) -> ContentAnalysis {
        var price = parseDecimal(meta["product:price:amount"])
        var currency = meta["product:price:currency"]
        var availability = meta["product:availability"]
        var rating: Double?
        var reviewCount: Int?
        var imageURL = safeURL(from: meta["og:image"])
        for dict in jsonLD where hasType(dict, matching: "Product") {
            if price == nil, let offers = dict["offers"] as? [String: Any] {
                price = parseDecimal(offers["price"])
                if currency == nil { currency = offers["priceCurrency"] as? String }
                if availability == nil { availability = offers["availability"] as? String }
            }
            if rating == nil, let aggregate = dict["aggregateRating"] as? [String: Any] {
                rating = (aggregate["ratingValue"] as? NSNumber)?.doubleValue ?? Double(aggregate["ratingValue"] as? String ?? "")
                reviewCount = (aggregate["reviewCount"] as? NSNumber)?.intValue ?? firstInteger(in: aggregate["reviewCount"] as? String)
            }
            if imageURL == nil { imageURL = extractFirstURL(from: dict["image"]) }
        }
        let product = BookmarkContentMetadata.ProductMetadata(
            price: price,
            currencyCode: currency,
            availability: availability,
            rating: rating,
            reviewCount: reviewCount,
            imageURL: imageURL,
            sku: meta["product:retailer_item_id"]
        )
        var hints = ["product", "shopping"]
        if let currency { hints.append(currency.lowercased()) }
        if let availability { hints.append(availability.lowercased()) }
        return ContentAnalysis(type: .product, subtype: currency, metadata: metadata(product: product), keywordHints: hints)
    }
    
    private func analyzeSocial(resource: LoadedResource, meta: [String: String]) -> ContentAnalysis {
        let platform = socialPlatform(for: resource.finalURL)
        let author = meta["twitter:creator"] ?? meta["og:site_name"] ?? meta["profile:username"]
        let mediaURL = safeURL(from: meta["og:image"] ?? meta["twitter:image"])
        let timestamp = parseDate(meta["article:published_time"] ?? meta["og:updated_time"])
        let social = BookmarkContentMetadata.SocialMetadata(
            platform: platform,
            authorHandle: author,
            likeCount: firstInteger(in: meta["likes"]),
            repostCount: firstInteger(in: meta["shares"]),
            commentCount: firstInteger(in: meta["comments"]),
            mediaURL: mediaURL,
            timestamp: timestamp
        )
        var hints = ["social", "post"]
        if let platform { hints.append(platform.lowercased()) }
        if let author { hints.append(author.lowercased()) }
        return ContentAnalysis(type: .social, subtype: platform, metadata: metadata(social: social), keywordHints: hints)
    }
    
    private func analyzeArticle(resource: LoadedResource, meta: [String: String], html: String?) -> ContentAnalysis {
        let publication = meta["og:site_name"] ?? meta["twitter:site"]
        let author = meta["article:author"] ?? meta["author"] ?? meta["byline"]
        let publishDate = parseDate(meta["article:published_time"] ?? meta["date"])
        let heroImage = safeURL(from: meta["og:image"] ?? meta["twitter:image"])
        var estimatedRead: Int?
        if let html {
            let words = extractBodyText(from: html).split { !$0.isLetter }
            if !words.isEmpty {
                let estimate = Int(round(Double(words.count) / 200.0))
                estimatedRead = max(estimate, 1)
            }
        }
        let article = BookmarkContentMetadata.ArticleMetadata(
            author: author,
            publication: publication,
            publishDate: publishDate,
            heroImageURL: heroImage,
            estimatedReadTimeMinutes: estimatedRead
        )
        var hints = ["article"]
        if let publication { hints.append(publication.lowercased()) }
        if let author { hints.append(author.lowercased()) }
        return ContentAnalysis(type: .article, subtype: publication, metadata: metadata(article: article), keywordHints: hints)
    }
    
    private func metadata(article: BookmarkContentMetadata.ArticleMetadata) -> BookmarkContentMetadata {
        BookmarkContentMetadata(article: article, video: nil, pdf: nil, image: nil, social: nil, product: nil, repository: nil, recipe: nil)
    }
    
    private func metadata(video: BookmarkContentMetadata.VideoMetadata) -> BookmarkContentMetadata {
        BookmarkContentMetadata(article: nil, video: video, pdf: nil, image: nil, social: nil, product: nil, repository: nil, recipe: nil)
    }
    
    private func metadata(pdf: BookmarkContentMetadata.PDFMetadata) -> BookmarkContentMetadata {
        BookmarkContentMetadata(article: nil, video: nil, pdf: pdf, image: nil, social: nil, product: nil, repository: nil, recipe: nil)
    }
    
    private func metadata(image: BookmarkContentMetadata.ImageMetadata) -> BookmarkContentMetadata {
        BookmarkContentMetadata(article: nil, video: nil, pdf: nil, image: image, social: nil, product: nil, repository: nil, recipe: nil)
    }
    
    private func metadata(social: BookmarkContentMetadata.SocialMetadata) -> BookmarkContentMetadata {
        BookmarkContentMetadata(article: nil, video: nil, pdf: nil, image: nil, social: social, product: nil, repository: nil, recipe: nil)
    }
    
    private func metadata(product: BookmarkContentMetadata.ProductMetadata) -> BookmarkContentMetadata {
        BookmarkContentMetadata(article: nil, video: nil, pdf: nil, image: nil, social: nil, product: product, repository: nil, recipe: nil)
    }
    
    private func metadata(repository: BookmarkContentMetadata.RepositoryMetadata) -> BookmarkContentMetadata {
        BookmarkContentMetadata(article: nil, video: nil, pdf: nil, image: nil, social: nil, product: nil, repository: repository, recipe: nil)
    }
    
    private func metadata(recipe: BookmarkContentMetadata.RecipeMetadata) -> BookmarkContentMetadata {
        BookmarkContentMetadata(article: nil, video: nil, pdf: nil, image: nil, social: nil, product: nil, repository: nil, recipe: recipe)
    }
    
    private func coerceStringArray(_ value: Any?) -> [String] {
        if let array = value as? [String] { return array }
        if let string = value as? String { return [string] }
        if let array = value as? [Any] { return array.compactMap { $0 as? String } }
        return []
    }
    
    private func extractJSONLDDictionaries(from html: String) -> [[String: Any]] {
        var results: [[String: Any]] = []
        let pattern = "<script[^>]*type=\\\"application/ld\\+json\\\"[^>]*>(.*?)</script>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else { return results }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        regex.enumerateMatches(in: html, options: [], range: range) { match, _, _ in
            guard let match, match.numberOfRanges >= 2, let scriptRange = Range(match.range(at: 1), in: html) else { return }
            let snippet = String(html[scriptRange])
            guard let data = snippet.data(using: .utf8) else { return }
            guard let json = try? JSONSerialization.jsonObject(with: data) else { return }
            if let dict = json as? [String: Any] {
                results.append(dict)
            } else if let array = json as? [[String: Any]] {
                results.append(contentsOf: array)
            } else if let array = json as? [Any] {
                for case let dict as [String: Any] in array {
                    results.append(dict)
                }
            }
        }
        return results
    }
    
    private func hasType(_ dict: [String: Any], matching target: String) -> Bool {
        guard let rawType = dict["@type"] else { return false }
        if let string = rawType as? String {
            return string.caseInsensitiveCompare(target) == .orderedSame
        }
        if let array = rawType as? [Any] {
            return array.contains { (value) -> Bool in
                guard let string = value as? String else { return false }
                return string.caseInsensitiveCompare(target) == .orderedSame
            }
        }
        return false
    }
    
    private func safeURL(from value: String?) -> URL? {
        guard let value = value, !value.isEmpty else { return nil }
        return URL(string: value)
    }
    
    private func extractFirstURL(from value: Any?) -> URL? {
        if let string = value as? String { return URL(string: string) }
        if let array = value as? [Any] {
            for item in array {
                if let url = extractFirstURL(from: item) { return url }
            }
        }
        return nil
    }
    
    private func extractFirstImageURL(from jsonLD: [[String: Any]]) -> URL? {
        for dict in jsonLD {
            if let url = extractFirstURL(from: dict["image"]) {
                return url
            }
        }
        return nil
    }
    
    private func parseDurationValue(_ value: Any?) -> TimeInterval? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return nil }
            if let seconds = Double(trimmed) { return seconds }
            if let iso = parseISODuration(trimmed) { return iso }
            if let clock = parseClockDuration(trimmed) { return clock }
            if let symbolic = parseSymbolDuration(trimmed) { return symbolic }
            let stripped = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "sS"))
            if stripped != trimmed, let seconds = Double(stripped) { return seconds }
        }
        return nil
    }
    
    private func parseClockDuration(_ string: String) -> TimeInterval? {
        let parts = string.split(separator: ":")
        guard parts.count == 2 || parts.count == 3 else { return nil }
        let numbers = parts.compactMap { Double($0) }
        guard numbers.count == parts.count else { return nil }
        if numbers.count == 2 {
            return numbers[0] * 60 + numbers[1]
        }
        return numbers[0] * 3_600 + numbers[1] * 60 + numbers[2]
    }
    
    private func parseSymbolDuration(_ string: String) -> TimeInterval? {
        var total: Double = 0
        var buffer = ""
        let lower = string.lowercased()
        for character in lower {
            if character.isNumber || character == "." {
                buffer.append(character)
                continue
            }
            guard let amount = Double(buffer) else {
                buffer.removeAll()
                continue
            }
            switch character {
            case "h":
                total += amount * 3_600
            case "m":
                total += amount * 60
            case "s":
                total += amount
            default:
                break
            }
            buffer.removeAll()
        }
        return total > 0 ? total : nil
    }
    
    private func parseISODuration(_ string: String) -> TimeInterval? {
        let upper = string.uppercased()
        guard upper.first == "P" else { return nil }
        var total: Double = 0
        var buffer = ""
        var inTimeSection = false
        for character in upper.dropFirst() {
            if character == "T" {
                inTimeSection = true
                continue
            }
            if character.isNumber || character == "." {
                buffer.append(character)
                continue
            }
            guard let amount = Double(buffer) else {
                buffer.removeAll()
                continue
            }
            switch character {
            case "Y":
                total += amount * 31_557_600 // average year in seconds
            case "M":
                if inTimeSection {
                    total += amount * 60
                } else {
                    total += amount * 2_629_800 // approximate month (30.44 days)
                }
            case "W":
                total += amount * 604_800
            case "D":
                total += amount * 86_400
            case "H":
                total += amount * 3_600
            case "S":
                total += amount
            default:
                break
            }
            buffer.removeAll()
        }
        return total > 0 ? total : nil
    }
    
    private func extractDurationFromJSONLD(_ jsonLD: [[String: Any]]) -> TimeInterval? {
        for dict in jsonLD where hasType(dict, matching: "VideoObject") {
            if let duration = parseDurationValue(dict["duration"] ?? dict["contentDuration"]) {
                return duration
            }
        }
        return nil
    }
    
    private func extractDurationFromHTMLMeta(_ html: String) -> TimeInterval? {
        let pattern = #""duration"\s*:\s*"([^"]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        guard let match = regex.firstMatch(in: html, options: [], range: range), match.numberOfRanges >= 2,
              let durationRange = Range(match.range(at: 1), in: html) else { return nil }
        let value = String(html[durationRange])
        return parseDurationValue(value)
    }
    
    private func durationMinutes(from seconds: TimeInterval?) -> Int? {
        guard let seconds else { return nil }
        return Int(round(seconds / 60.0))
    }
    
    private func parseDate(_ raw: String?) -> Date? {
        guard let raw = raw, !raw.isEmpty else { return nil }
        return isoDateFormatter.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
    }
    
    private func extractDateFromJSONLD(_ jsonLD: [[String: Any]], keys: [String]) -> Date? {
        for dict in jsonLD {
            for key in keys {
                if let value = dict[key] as? String, let date = parseDate(value) {
                    return date
                }
            }
        }
        return nil
    }
    
    private func firstInteger(in raw: String?) -> Int? {
        guard let raw = raw else { return nil }
        let digits = raw.compactMap { $0.isNumber ? $0 : nil }
        guard !digits.isEmpty else { return nil }
        return Int(String(digits))
    }
    
    private func parseDecimal(_ value: Any?) -> Decimal? {
        switch value {
        case let decimal as Decimal:
            return decimal
        case let number as NSNumber:
            return number.decimalValue
        case let string as String:
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return Decimal(string: trimmed)
        default:
            return nil
        }
    }
    
    private func socialPlatform(for url: URL) -> String? {
        guard let host = url.host?.lowercased() else { return nil }
        if host.contains("twitter.com") || host.contains("x.com") { return "Twitter" }
        if host.contains("instagram.com") { return "Instagram" }
        if host.contains("facebook.com") || host.contains("fb.com") { return "Facebook" }
        if host.contains("threads.net") { return "Threads" }
        if host.contains("tiktok.com") { return "TikTok" }
        if host.contains("linkedin.com") { return "LinkedIn" }
        if host.contains("reddit.com") { return "Reddit" }
        if host.contains("mastodon") { return "Mastodon" }
        if host.contains("bsky.app") || host.contains("bluesky") { return "Bluesky" }
        return nil
    }
    
    private func videoProvider(for url: URL) -> String? {
        guard let host = url.host?.lowercased() else { return nil }
        if host.contains("youtube.com") || host.contains("youtu.be") { return "YouTube" }
        if host.contains("vimeo.com") { return "Vimeo" }
        if host.contains("dailymotion.com") { return "Dailymotion" }
        if host.contains("twitch.tv") { return "Twitch" }
        if host.contains("loom.com") { return "Loom" }
        return nil
    }
    
    private func fetchGitHubRepositoryMetadata(owner: String, name: String) async -> BookmarkContentMetadata.RepositoryMetadata? {
        guard let apiURL = URL(string: "https://api.github.com/repos/\(owner)/\(name)") else { return nil }
        var request = URLRequest(url: apiURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("CalendarNotesApp/1.0", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<400).contains(http.statusCode) else { return nil }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let repo = try decoder.decode(GitHubRepositoryResponse.self, from: data)
            return BookmarkContentMetadata.RepositoryMetadata(
                stars: repo.stargazersCount,
                forks: repo.forksCount,
                issues: repo.openIssuesCount,
                language: repo.language,
                license: repo.license?.name,
                lastUpdated: repo.pushedAt ?? repo.updatedAt,
                openGraphImageURL: URL(string: repo.owner.avatarURL ?? "")
            )
        } catch {
            return nil
        }
    }
    
    func validate(url: URL) async -> Bool {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 10
        do {
            let (_, response) = try await urlSession.data(for: request)
            if let http = response as? HTTPURLResponse { return (200..<400).contains(http.statusCode) }
            return true
        } catch { return false }
    }
    
    func isDuplicate(url: URL) -> Bool {
        do {
            let items = try coreDataManager.fetchBookmarks(searchText: url.absoluteString, limit: 5)
            return items.contains(where: { ($0.url ?? "").caseInsensitiveCompare(url.absoluteString) == .orderedSame })
        } catch { return false }
    }
    
    // MARK: - Caching
    
    func cacheFavicon(from url: URL, for host: String) async -> URL? {
        do {
            let (data, _) = try await urlSession.data(from: url)
            faviconMemoryCache.setObject(data as NSData, forKey: host as NSString)
            performanceMonitor.recordCacheHit(for: "bookmark.favicon.memory")
            return try save(data: data, named: "favicon_\(host).ico", in: .favicons)
        } catch {
            performanceMonitor.recordCacheMiss(for: "bookmark.favicon.memory")
            return nil
        }
    }
    
    func cachedFavicon(for host: String) -> Data? {
        if let memory = faviconMemoryCache.object(forKey: host as NSString) {
            performanceMonitor.recordCacheHit(for: "bookmark.favicon.memory")
            return memory as Data
        }
        let filename = "favicon_\(host).ico"
        let path = nonisolatedCacheURL(for: .favicons).appendingPathComponent(filename)
        if let data = try? Data(contentsOf: path) {
            faviconMemoryCache.setObject(data as NSData, forKey: host as NSString)
            performanceMonitor.recordCacheHit(for: "bookmark.favicon.disk")
            return data
        }
        performanceMonitor.recordCacheMiss(for: "bookmark.favicon.disk")
        return nil
    }
    
    func cachePreviewImage(from url: URL, maxSize: CGFloat = 800) async -> (fileURL: URL, fileName: String)? {
        do {
            let (data, _) = try await urlSession.data(from: url)
            guard let processed = Self.processImageData(data, maxDimension: maxSize) else { return nil }
            let filename = "preview_\(UUID().uuidString).\(processed.extension)"
            previewMemoryCache.setObject(processed.data as NSData, forKey: filename as NSString)
            let fileURL = try save(data: processed.data, named: filename, in: .previews)
            return (fileURL, filename)
        } catch {
            return nil
        }
    }
    
    func cachedPreview(named fileName: String) -> Data? {
        if let memory = previewMemoryCache.object(forKey: fileName as NSString) {
            performanceMonitor.recordCacheHit(for: "bookmark.preview.memory")
            return memory as Data
        }
        let path = nonisolatedCacheURL(for: .previews).appendingPathComponent(fileName)
        if let data = try? Data(contentsOf: path) {
            previewMemoryCache.setObject(data as NSData, forKey: fileName as NSString)
            performanceMonitor.recordCacheHit(for: "bookmark.preview.disk")
            return data
        }
        performanceMonitor.recordCacheMiss(for: "bookmark.preview.disk")
        return nil
    }
    
    func clearCaches() {
        metadataCache.removeAllObjects()
        faviconMemoryCache.removeAllObjects()
        previewMemoryCache.removeAllObjects()
        
        diskQueue.async {
            for dir in [CacheDirectory.favicons, .previews, .exports, .metadata] {
                let folder = self.nonisolatedCacheURL(for: dir)
                let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
                files.forEach { try? FileManager.default.removeItem(at: $0) }
            }
        }
    }

    func clearImageCaches() {
        faviconMemoryCache.removeAllObjects()
        previewMemoryCache.removeAllObjects()
        diskQueue.async {
            self.removeAllFiles(in: [.favicons, .previews])
        }
    }
    
    func applyPreviewRetention(policy: BookmarkPreviewRetentionPolicy) {
        guard case .days(let days) = policy else { return }
        let cutoff = Date().addingTimeInterval(-Double(days) * 86_400.0)
        diskQueue.async {
            self.removeFiles(olderThan: cutoff, in: .previews)
        }
        let predicate = NSPredicate(format: "(lastOpenedDate < %@) OR (lastOpenedDate == nil)", cutoff as NSDate)
        Task { @MainActor in
            try? CoreDataManager.shared.batchUpdate(
                entityName: "Bookmark",
                propertiesToUpdate: ["previewImage": NSNull(), "favicon": NSNull()],
                predicate: predicate
            )
        }
    }
    
    func cacheUsage() async -> BookmarkCacheUsage {
        await withCheckedContinuation { continuation in
            diskQueue.async {
                let favicons = self.directorySize(at: self.nonisolatedCacheURL(for: .favicons))
                let previews = self.directorySize(at: self.nonisolatedCacheURL(for: .previews))
                let metadata = self.directorySize(at: self.nonisolatedCacheURL(for: .metadata))
                continuation.resume(returning: BookmarkCacheUsage(faviconBytes: favicons, previewBytes: previews, metadataBytes: metadata))
            }
        }
    }

    // MARK: - Export
    
    func exportBookmarksAsHTML(_ bookmarks: [Bookmark]) throws -> URL {
        var html = "<DL><p>\n"
        for b in bookmarks {
            let url = b.url ?? ""
            let title = (b.title ?? url).replacingOccurrences(of: "\"", with: "&quot;")
            html += "<DT><A HREF=\"\(url)\">\(title)</A>\n"
        }
        html += "</DL><p>\n"
        let data = Data(html.utf8)
        return try saveExport(data: data, name: "bookmarks.html")
    }
    
    func exportBookmarksAsJSON(_ bookmarks: [Bookmark]) throws -> URL {
        struct JSONB: Codable { let url: String; let title: String?; let tags: [String] }
        let payload = bookmarks.map { JSONB(url: $0.url ?? "", title: $0.title, tags: $0.decodedTags) }
        let data = try JSONEncoder().encode(payload)
        return try saveExport(data: data, name: "bookmarks.json")
    }
    
    func exportBookmarksAsCSV(_ bookmarks: [Bookmark]) throws -> URL {
        var rows = ["url,title,tags"]
        for b in bookmarks {
            let url = b.url?.replacingOccurrences(of: ",", with: " ") ?? ""
            let title = (b.title ?? "").replacingOccurrences(of: ",", with: " ")
            let tags = b.decodedTags.joined(separator: "|")
            rows.append("\(url),\(title),\(tags)")
        }
        let data = Data(rows.joined(separator: "\n").utf8)
        return try saveExport(data: data, name: "bookmarks.csv")
    }
    
    // MARK: - Import
    
    struct ImportedBookmark { let url: String; let title: String?; let tags: [String] }
    
    func importFromChromeJSON(data: Data) throws -> [ImportedBookmark] {
        struct Node: Codable { let type: String?; let name: String?; let url: String?; let children: [Node]? }
        struct Root: Codable { let roots: [String: Node] }
        let root = try JSONDecoder().decode(Root.self, from: data)
        var result: [ImportedBookmark] = []
        func walk(_ node: Node, folder: [String]) {
            if (node.type == "url"), let url = node.url {
                result.append(.init(url: url, title: node.name, tags: folder))
            }
            node.children?.forEach { child in
                walk(child, folder: folder + (node.type == "folder" ? [node.name ?? ""] : []))
            }
        }
        for (_, node) in root.roots {
            walk(node, folder: [])
        }
        return result
    }
    
    func importFromHTML(data: Data) -> [ImportedBookmark] {
        guard let html = String(data: data, encoding: .utf8) else { return [] }
        let pattern = #"<A[^>]*HREF=\"([^\"]+)\"[^>]*>(.*?)</A>"#
        let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        let matches = regex?.matches(in: html, range: NSRange(html.startIndex..., in: html)) ?? []
        return matches.compactMap { match in
            guard let r1 = Range(match.range(at: 1), in: html) else { return nil }
            let url = String(html[r1])
            let title: String? = {
                if let range = Range(match.range(at: 2), in: html) {
                    return String(html[range])
                }
                return nil
            }()
            return ImportedBookmark(url: url, title: title, tags: [])
        }
    }
    
    // MARK: - QR
    
    func generateQRCode(for string: String) -> Data? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(Data(string.utf8), forKey: "inputMessage")
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 6, y: 6)) else { return nil }
        #if os(macOS)
        let rep = NSBitmapImageRep(ciImage: output)
        return rep.representation(using: .png, properties: [:])
        #else
        let cgImage = context.createCGImage(output, from: output.extent)
        let ui = UIImage(cgImage: cgImage!)
        return ui.pngData()
        #endif
    }
    
    // MARK: - Internals
    
    private func loadResource(_ url: URL) async throws -> LoadedResource {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<400).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let finalURL = http.url ?? url
        let html = string(from: data, response: http)
        return LoadedResource(data: data, finalURL: finalURL, response: http, html: html)
    }
    
    private func string(from data: Data, response: HTTPURLResponse) -> String? {
        if let encodingName = response.textEncodingName,
           let encoding = String.Encoding(ianaCharsetName: encodingName),
           let text = String(data: data, encoding: encoding) {
            return text
        }
        if let text = String(data: data, encoding: .utf8) {
            return text
        }
        if let text = String(data: data, encoding: .isoLatin1) {
            return text
        }
        return nil
    }
    
    private func parseMeta(from html: String) -> [String: String] {
        var result: [String: String] = [:]
        let patterns = [
            #"<meta[^>]*property=\"([^\"]+)\"[^>]*content=\"([^\"]*)\"[^>]*>"#,
            #"<meta[^>]*name=\"([^\"]+)\"[^>]*content=\"([^\"]*)\"[^>]*>"#
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
                for match in matches {
                    if let r1 = Range(match.range(at: 1), in: html),
                       let r2 = Range(match.range(at: 2), in: html) {
                        let key = String(html[r1]).lowercased()
                        let value = String(html[r2])
                        result[key] = value
                    }
                }
            }
        }
        if result["title"] == nil,
           let title = Self.firstCapture(in: html, pattern: #"<title[^>]*>(.*?)</title>"#, group: 1) {
            result["title"] = title
        }
        return result
    }
    
    private func resolveFavicon(inHTML html: String, pageURL: URL) -> URL? {
        let pattern = #"<link[^>]*(rel=\"(?:icon|shortcut icon)\"|rel='(?:icon|shortcut icon)')[^>]*href=\"([^\"]+)\"[^>]*>"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
           let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
           let hrefRange = Range(match.range(at: 2), in: html) {
            let href = String(html[hrefRange])
            return URL(string: href, relativeTo: pageURL)?.absoluteURL
        }
        return nil
    }
    
    private func defaultFavicon(for url: URL) -> URL? {
        guard let host = url.host else { return nil }
        var comps = URLComponents()
        comps.scheme = url.scheme ?? "https"
        comps.host = host
        comps.path = "/favicon.ico"
        return comps.url
    }
    
    private static func firstCapture(in text: String, pattern: String, group: Int) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        guard let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        guard let range = Range(match.range(at: group), in: text) else { return nil }
        return String(text[range])
    }
    
    private func extractBodyText(from html: String) -> String {
        let withoutScripts = html.replacingOccurrences(of: #"<script[\s\S]*?</script>"#, with: "", options: .regularExpression)
        let withoutStyles = withoutScripts.replacingOccurrences(of: #"<style[\s\S]*?</style>"#, with: "", options: .regularExpression)
        return withoutStyles.replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
    }
    
    private func cachedMetadata(for url: URL) -> BookmarkPageMetadata? {
        let key = url as NSURL
        if let entry = metadataCache.object(forKey: key) {
            if entry.isExpired {
                metadataCache.removeObject(forKey: key)
                performanceMonitor.recordCacheMiss(for: "bookmark.metadata.memory")
            } else {
                performanceMonitor.recordCacheHit(for: "bookmark.metadata.memory")
                return entry.value
            }
        }
        
        let diskURL = nonisolatedCacheURL(for: .metadata).appendingPathComponent(metadataFilename(for: url))
        if let data = try? Data(contentsOf: diskURL),
           let decoded = try? JSONDecoder().decode(BookmarkPageMetadata.self, from: data) {
            performanceMonitor.recordCacheHit(for: "bookmark.metadata.disk")
            cacheMetadata(decoded, for: url)
            return decoded
        }
        
        performanceMonitor.recordCacheMiss(for: "bookmark.metadata.disk")
        return nil
    }
    
    private func cacheMetadata(_ metadata: BookmarkPageMetadata, for url: URL) {
        metadataCache.setObject(MetadataCacheBox(value: metadata, ttl: metadataCacheTTL), forKey: url as NSURL)
        guard let encoded = try? JSONEncoder().encode(metadata) else { return }
        let path = nonisolatedCacheURL(for: .metadata).appendingPathComponent(metadataFilename(for: url))
        diskQueue.async {
            try? encoded.write(to: path, options: .atomic)
        }
    }
    
    nonisolated private func metadataFilename(for url: URL) -> String {
        let host = url.host ?? "unknown"
        let hex = url.absoluteString.data(using: .utf8)?.map { String(format: "%02x", $0) }.joined() ?? UUID().uuidString
        let trimmed = String(hex.prefix(48))
        return "metadata_\(host)_\(trimmed).json"
    }
    
    private static func processImageData(_ data: Data, maxDimension: CGFloat) -> (data: Data, extension: String)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(maxDimension),
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        
        let outputData = NSMutableData()
        if #available(iOS 14.0, macOS 11.0, *),
           let webPType = UTType.webP.identifier as CFString? {
            if let destination = CGImageDestinationCreateWithData(outputData as CFMutableData, webPType, 1, nil) {
                CGImageDestinationAddImage(destination, cgImage, [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
                if CGImageDestinationFinalize(destination) {
                    return (outputData as Data, "webp")
                }
                outputData.setData(Data())
            }
        }
        
        guard let jpegDestination = CGImageDestinationCreateWithData(outputData as CFMutableData, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(jpegDestination, cgImage, [kCGImageDestinationLossyCompressionQuality: 0.82] as CFDictionary)
        CGImageDestinationFinalize(jpegDestination)
        return (outputData as Data, "jpg")
    }
    
    private enum CacheDirectory: String { case favicons = "Favicons", previews = "Previews", exports = "Exports", metadata = "Metadata" }
    
    private func createCacheDirectoriesIfNeeded() {
        for dir in [CacheDirectory.favicons, .previews, .exports, .metadata] {
            _ = try? FileManager.default.createDirectory(at: nonisolatedCacheURL(for: dir), withIntermediateDirectories: true)
        }
    }
    
    nonisolated private func nonisolatedCacheURL(for dir: CacheDirectory) -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("CalendarNotesCache", isDirectory: true)
            .appendingPathComponent(dir.rawValue, isDirectory: true)
    }


    nonisolated private func removeAllFiles(in directories: [CacheDirectory]) {
        for dir in directories {
            removeFiles(in: dir)
        }
    }
    
    nonisolated private func removeFiles(in directory: CacheDirectory) {
        let folder = nonisolatedCacheURL(for: directory)
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        files.forEach { try? FileManager.default.removeItem(at: $0) }
    }
    
    nonisolated private func removeFiles(olderThan cutoff: Date, in directory: CacheDirectory) {
        let folder = nonisolatedCacheURL(for: directory)
        let enumerator = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles])
        while let fileURL = enumerator?.nextObject() as? URL {
            if let values = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]),
               let modified = values.contentModificationDate,
               modified < cutoff {
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
    }
    
    nonisolated private func directorySize(at url: URL) -> Int64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey], options: [.skipsHiddenFiles]) else {
            return 0
        }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]), values.isRegularFile == true else {
                continue
            }
            total += Int64(values.fileSize ?? 0)
        }
        return total
    }

    private func save(data: Data, named: String, in dir: CacheDirectory) throws -> URL {
        let url = nonisolatedCacheURL(for: dir).appendingPathComponent(named)
        try data.write(to: url, options: .atomic)
        return url
    }
    
    private func saveExport(data: Data, name: String) throws -> URL {
        let url = nonisolatedCacheURL(for: .exports).appendingPathComponent(name)
        try data.write(to: url, options: .atomic)
        return url
    }
    
    private func readableTitle(from url: URL) -> String {
        var host = url.host?.replacingOccurrences(of: "www.", with: "") ?? url.absoluteString
        host = host.split(separator: ".").first.map(String.init) ?? host
        let path = url.deletingPathExtension().lastPathComponent
        if path.isEmpty || path == "/" { return host.capitalized }
        return path
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
    
    private static func keywords(from text: String) -> [String] {
        let lowered = text.lowercased()
        let words = lowered.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count > 2 }
        let stop: Set<String> = ["the","and","for","you","with","that","this","from","are","was","were","your","have","has","not","but","about","into","out","over","under","between","their","they","them","can","will","just","like","what","when","where","which","why","how"]
        var counts: [String: Int] = [:]
        for word in words where !stop.contains(word) {
            counts[word, default: 0] += 1
        }
        return counts.sorted { $0.value > $1.value }.map { $0.key }
    }
}

private extension String.Encoding {
    init?(ianaCharsetName: String) {
        let cfEncoding = CFStringConvertIANACharSetNameToEncoding(ianaCharsetName as CFString)
        guard cfEncoding != kCFStringEncodingInvalidId else { return nil }
        let rawValue = CFStringConvertEncodingToNSStringEncoding(cfEncoding)
        self.init(rawValue: rawValue)
    }
}

private struct GitHubRepositoryResponse: Decodable {
    let stargazersCount: Int
    let forksCount: Int
    let openIssuesCount: Int
    let language: String?
    let pushedAt: Date?
    let updatedAt: Date?
    let license: License?
    let owner: Owner
    
    private enum CodingKeys: String, CodingKey {
        case stargazersCount = "stargazers_count"
        case forksCount = "forks_count"
        case openIssuesCount = "open_issues_count"
        case language
        case pushedAt = "pushed_at"
        case updatedAt = "updated_at"
        case license
        case owner
    }
    
    struct License: Decodable {
        let name: String?
    }
    
    struct Owner: Decodable {
        let avatarURL: String?
        let htmlURL: String?
        
        private enum CodingKeys: String, CodingKey {
            case avatarURL = "avatar_url"
            case htmlURL = "html_url"
        }
    }
}

