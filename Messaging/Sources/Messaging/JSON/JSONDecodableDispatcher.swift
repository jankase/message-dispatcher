//
//  JSONDecodableDispatcher.swift
//  
//
//  Created by Alexey Rogatkin on 16.12.2022.
//

import Foundation

public final class JSONDecodableDispatcher: DecodableDispatcher, DecodableDispatcherConnector {

    private let decoder: JSONDecoder
    private var handlers: [any Handler] = []

    public init(decoder: JSONDecoder) {
        self.decoder = decoder
    }

    public func register<X>(handler: X) where X: Handler, X.Message: Decodable {
        handlers.append(handler)
    }

    public func handle(incomingMessage: Data) -> DecodableDispatcherStatus {
        var notFoundResult: (message: Decodable, errors: [(any Handler, Error)])?
        for handler in handlers {
            switch handle(incomingMessage: incomingMessage, handler: handler) {
            case .handled(let message, let handler):
                return .handled(message: message, by: handler)
            case let .handlerNotFound(message, errors):
                notFoundResult = (message: message, errors: errors)
            default:
                continue
            }
        }
        if let notFoundResult = notFoundResult {
            return .handlerNotFound(message: notFoundResult.message, errors: notFoundResult.errors)
        } else {
            return .messageNotSupported
        }
    }

    private func handle<X>(incomingMessage: Data, handler: X) -> DecodableDispatcherStatus where X: Handler {
        do {
            // I don't like these force casts, but I don't know how to avoid them
            // register method accepts only handlers with Decodable messages so it could not cause any problems
            let decodableMessageType = X.Message.self as! Decodable.Type
            let message = try decoder.decode(decodableMessageType, from: incomingMessage)
            do {
                try handler.handle(message: message as! X.Message)
                return .handled(message: message, by: handler)
            } catch {
                return .handlerNotFound(message: message, errors: [(handler, error)])
            }
        } catch {
            return .messageNotSupported
        }
    }
}
