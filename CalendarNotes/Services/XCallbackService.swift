//
//  XCallbackService.swift
//  CalendarNotes
//

import Foundation

#if os(macOS)
import AppKit
#else
import UIKit
#endif

@MainActor
enum XCallbackService {
    static func handleSuccess(_ context: DeepLinkRouter.XCallbackContext, data: [String: String]) async {
        guard let url = context.success else { return }
        await open(url: url, with: data, context: context)
    }

    static func handleError(_ context: DeepLinkRouter.XCallbackContext, error: Error) async {
        guard let url = context.error else { return }
        var payload: [String: String] = [
            "result": "error",
            "message": error.localizedDescription
        ]

        if let nsError = error as NSError? {
            payload["code"] = String(nsError.code)
            payload["domain"] = nsError.domain
        }

        await open(url: url, with: payload, context: context)
    }

    static func handleCancel(_ context: DeepLinkRouter.XCallbackContext) async {
        guard let url = context.cancel else { return }
        await open(url: url, with: ["result": "cancel"], context: context)
    }

    private static func open(url: URL, with payload: [String: String], context: DeepLinkRouter.XCallbackContext) async {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }

        var items = components.queryItems ?? []

        for (key, value) in payload {
            items.append(URLQueryItem(name: key, value: value))
        }

        if let state = context.state {
            items.append(URLQueryItem(name: "x-state", value: state))
        }

        if let source = context.source {
            items.append(URLQueryItem(name: "x-source", value: source))
        }

        components.queryItems = items

        guard let finalURL = components.url else { return }

        #if os(macOS)
        NSWorkspace.shared.open(finalURL)
        #else
        await UIApplication.shared.open(finalURL)
        #endif
    }
}

