import Foundation

/// Rich-text block content, shared by post bodies and team/rider bios.
///
/// `docs/API.md` describes the discriminator as `component`, but the running API emits
/// `type` — both are accepted here so the client survives either. Observed types in the
/// 2026 data are `paragraph` (HTML string) and `image`; anything else decodes to
/// `.unsupported` and renders nothing rather than failing the whole response.
enum ContentBlock: Decodable, Hashable, Sendable, Identifiable {
    case paragraph(html: String)
    case heading(text: String, level: Int)
    case image(ImageBlock)
    case unsupported

    var id: String {
        switch self {
        case .paragraph(let html): "p-\(html.hashValue)"
        case .heading(let text, let level): "h\(level)-\(text.hashValue)"
        case .image(let block): "img-\(block.id)"
        case .unsupported: "unsupported-\(UUID().uuidString)"
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type, component, content, text, level, caption, image, width, height, id
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = (try? c.decodeIfPresent(String.self, forKey: .type))
            ?? (try? c.decodeIfPresent(String.self, forKey: .component))
            ?? nil

        switch kind {
        case "paragraph", "text":
            let html = (try? c.decodeIfPresent(String.self, forKey: .content)) ?? nil
            self = .paragraph(html: html ?? "")
        case "heading":
            let text = ((try? c.decodeIfPresent(String.self, forKey: .text)) ?? nil)
                ?? ((try? c.decodeIfPresent(String.self, forKey: .content)) ?? nil)
                ?? ""
            let level = ((try? c.decodeIfPresent(Int.self, forKey: .level)) ?? nil) ?? 2
            self = .heading(text: text, level: level)
        case "image":
            guard let image = (try? c.decodeIfPresent(ImageSet.self, forKey: .image)) ?? nil else {
                self = .unsupported
                return
            }
            self = .image(ImageBlock(
                id: ((try? c.decodeIfPresent(Int.self, forKey: .id)) ?? nil)
                    ?? image.bestFull?.absoluteString.hashValue ?? 0,
                image: image,
                width: (try? c.decodeIfPresent(Int.self, forKey: .width)) ?? nil,
                height: (try? c.decodeIfPresent(Int.self, forKey: .height)) ?? nil,
                caption: (try? c.decodeIfPresent(String.self, forKey: .caption)) ?? nil
            ))
        default:
            self = .unsupported
        }
    }
}

/// An inline image inside block content. Now carries the same `{thumb, card, hero, full}`
/// map as every other image field, so the client no longer builds Cloudinary URLs itself.
struct ImageBlock: Hashable, Sendable {
    let id: Int
    let image: ImageSet
    let width: Int?
    let height: Int?
    let caption: String?

    /// Used to reserve the right box before the image loads, avoiding a layout jump.
    var aspectRatio: Double? {
        guard let width, let height, height > 0 else { return nil }
        return Double(width) / Double(height)
    }

    var url: URL? { image.bestFull }
}
