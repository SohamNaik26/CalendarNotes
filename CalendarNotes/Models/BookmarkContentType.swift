import Foundation

enum BookmarkContentType: String, CaseIterable, Codable, Sendable {
    case article
    case video
    case pdf
    case image
    case social
    case product
    case repository
    case recipe
    case unknown
}

struct BookmarkContentMetadata: Codable, Sendable {
    var article: ArticleMetadata?
    var video: VideoMetadata?
    var pdf: PDFMetadata?
    var image: ImageMetadata?
    var social: SocialMetadata?
    var product: ProductMetadata?
    var repository: RepositoryMetadata?
    var recipe: RecipeMetadata?
    
    var primaryThumbnailURL: URL? {
        if let url = video?.thumbnailURL { return url }
        if let url = image?.remoteURL { return url }
        if let url = product?.imageURL { return url }
        if let url = social?.mediaURL { return url }
        if let url = repository?.openGraphImageURL { return url }
        return article?.heroImageURL
    }
}

extension BookmarkContentMetadata {
    struct ArticleMetadata: Codable, Sendable {
        var author: String?
        var publication: String?
        var publishDate: Date?
        var heroImageURL: URL?
        var estimatedReadTimeMinutes: Int?
    }
    
    struct VideoMetadata: Codable, Sendable {
        var duration: TimeInterval?
        var thumbnailURL: URL?
        var embedURL: URL?
        var channelName: String?
        var uploadDate: Date?
        var downloadURL: URL?
        var isLiveStream: Bool
        
        init(
            duration: TimeInterval? = nil,
            thumbnailURL: URL? = nil,
            embedURL: URL? = nil,
            channelName: String? = nil,
            uploadDate: Date? = nil,
            downloadURL: URL? = nil,
            isLiveStream: Bool = false
        ) {
            self.duration = duration
            self.thumbnailURL = thumbnailURL
            self.embedURL = embedURL
            self.channelName = channelName
            self.uploadDate = uploadDate
            self.downloadURL = downloadURL
            self.isLiveStream = isLiveStream
        }
    }
    
    struct PDFMetadata: Codable, Sendable {
        var pageCount: Int?
        var fileSizeBytes: Int64?
        var author: String?
        var subject: String?
        var keywords: [String]?
        var allowsAnnotations: Bool
        var hasOCRText: Bool
        var extractedTextPreview: String?
        
        init(
            pageCount: Int? = nil,
            fileSizeBytes: Int64? = nil,
            author: String? = nil,
            subject: String? = nil,
            keywords: [String]? = nil,
            allowsAnnotations: Bool = true,
            hasOCRText: Bool = false,
            extractedTextPreview: String? = nil
        ) {
            self.pageCount = pageCount
            self.fileSizeBytes = fileSizeBytes
            self.author = author
            self.subject = subject
            self.keywords = keywords
            self.allowsAnnotations = allowsAnnotations
            self.hasOCRText = hasOCRText
            self.extractedTextPreview = extractedTextPreview
        }
    }
    
    struct ImageMetadata: Codable, Sendable {
        var width: Int?
        var height: Int?
        var fileSizeBytes: Int64?
        var format: String?
        var colorProfile: String?
        var remoteURL: URL?
    }
    
    struct SocialMetadata: Codable, Sendable {
        var platform: String?
        var authorHandle: String?
        var likeCount: Int?
        var repostCount: Int?
        var commentCount: Int?
        var mediaURL: URL?
        var timestamp: Date?
    }
    
    struct ProductMetadata: Codable, Sendable {
        var price: Decimal?
        var currencyCode: String?
        var availability: String?
        var rating: Double?
        var reviewCount: Int?
        var imageURL: URL?
        var sku: String?
    }
    
    struct RepositoryMetadata: Codable, Sendable {
        var stars: Int?
        var forks: Int?
        var issues: Int?
        var language: String?
        var license: String?
        var lastUpdated: Date?
        var openGraphImageURL: URL?
    }
    
    struct RecipeMetadata: Codable, Sendable {
        var ingredients: [String]
        var cookTimeMinutes: Int?
        var prepTimeMinutes: Int?
        var totalTimeMinutes: Int? {
            if let cook = cookTimeMinutes, let prep = prepTimeMinutes { return cook + prep }
            return cookTimeMinutes ?? prepTimeMinutes
        }
        var servings: Int?
        var cuisine: String?
        
        init(
            ingredients: [String] = [],
            cookTimeMinutes: Int? = nil,
            prepTimeMinutes: Int? = nil,
            servings: Int? = nil,
            cuisine: String? = nil
        ) {
            self.ingredients = ingredients
            self.cookTimeMinutes = cookTimeMinutes
            self.prepTimeMinutes = prepTimeMinutes
            self.servings = servings
            self.cuisine = cuisine
        }
    }
}

extension BookmarkContentMetadata {
    static func empty(for type: BookmarkContentType) -> BookmarkContentMetadata {
        var metadata = BookmarkContentMetadata()
        switch type {
        case .article:
            metadata.article = ArticleMetadata()
        case .video:
            metadata.video = VideoMetadata()
        case .pdf:
            metadata.pdf = PDFMetadata()
        case .image:
            metadata.image = ImageMetadata()
        case .social:
            metadata.social = SocialMetadata()
        case .product:
            metadata.product = ProductMetadata()
        case .repository:
            metadata.repository = RepositoryMetadata()
        case .recipe:
            metadata.recipe = RecipeMetadata()
        case .unknown:
            break
        }
        return metadata
    }
}
