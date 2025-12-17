//
//  URLPrivacySanitizer.swift
//  CalendarNotes
//
//  Created by GPT-5 Codex on 12/11/25.
//

import Foundation

struct URLPrivacySanitizer {
    private static let trackingParameters: Set<String> = [
        "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content",
        "utm_id", "utm_name", "utm_reader", "utm_viz_id", "utm_pubreferrer",
        "gclid", "dclid", "fbclid", "mc_cid", "mc_eid", "mkt_tok",
        "msclkid", "s_cid", "igshid", "vero_conv", "vero_id",
        "guccounter", "pk_campaign", "pk_source", "pk_medium",
        "spm", "yclid", "_openstat", "sb_referer", "soc_src",
        "soc_trk", "elqTrackId", "elqTrack", "elq", "ref",
        "sr_share", "sr_source", "src", "ncid", "icid", "rb_clickid",
        "ttclid", "twclid", "fb_action_ids", "fb_action_types", "campaignid",
        "adgroupid", "adid", "creative", "keyword", "matchtype",
        "placement", "targetid", "device", "dv",
        "_hsenc", "_hsmi", "hsa_acc", "hsa_cam", "hsa_grp", "hsa_ad",
        "hsa_src", "hsa_tgt", "hsa_kw", "hsa_mt", "hsa_net", "hsa_ver"
    ]

    static func sanitized(_ string: String) -> String {
        guard let url = URL(string: string) else { return string }
        return sanitize(url).absoluteString
    }

    static func sanitize(_ url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }

        if var queryItems = components.queryItems, !queryItems.isEmpty {
            queryItems.removeAll { item in
                trackingParameters.contains(item.name.lowercased()) || (item.name.lowercased().hasPrefix("utm_") && item.name.count > 4)
            }
            components.queryItems = queryItems.isEmpty ? nil : queryItems
        }

        if let fragment = components.fragment, fragment.contains("=") {
            let filteredPairs = fragment
                .split(separator: "&")
                .filter { segment in
                    let key = segment.split(separator: "=").first?.lowercased() ?? ""
                    guard !key.isEmpty else { return true }
                    return !trackingParameters.contains(String(key)) && !key.hasPrefix("utm_")
                }
            components.fragment = filteredPairs.isEmpty ? nil : filteredPairs.joined(separator: "&")
        }

        return components.url ?? url
    }
}
