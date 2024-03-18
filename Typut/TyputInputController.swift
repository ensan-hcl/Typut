//
//  TyputInputController.swift
//  TyputInputController
//
//  Created by ensan on 2021/09/07.
//

import Cocoa
import InputMethodKit

enum UserAction {
    case input(String)
    case delete
    case enter
    case tab
    case space
    case escape
    case unknown
    case navigation(NavigationDirection)

    enum NavigationDirection {
        case up, down, right, left
    }
}

enum ClientAction {
    case ignore
    case showCandidateWindow
    case hideCandidateWindow
    case appendToMarkedText(String)
    case commitMarkedText
    case submitSelectedCandidate
    case insertText(String)
    case removeLastMarkedText
    case forwardToCandidateWindow(NSEvent)
}

enum InputState {
    case none
    case composing
    case selecting

    mutating func event(_ event: NSEvent!, userAction: UserAction) -> ClientAction {
        // input with command modifier should be just ignored
        if event.modifierFlags.contains(.command) {
            return .ignore
        }
        switch self {
        case .none:
            switch userAction {
            case .input(let string):
                self = .composing
                return .appendToMarkedText(string)
            case .enter, .tab, .space, .unknown, .navigation, .escape, .delete:
                return .ignore
            }
        case .composing:
            switch userAction {
            case .input(let string):
                return .appendToMarkedText(string)
            case .space:
                return .appendToMarkedText(" ")
            case .delete:
                return .removeLastMarkedText
            case .enter:
                self = .none
                return .commitMarkedText
            case .tab:
                self = .selecting
                return .showCandidateWindow
            case .unknown, .navigation, .escape:
                return .ignore
            }
        case .selecting:
            switch userAction {
            case .input(let string):
                self = .composing
                return .appendToMarkedText(string)
            case .space:
                self = .composing
                return .appendToMarkedText(" ")
            case .tab:
                return .showCandidateWindow
            case .enter:
                self = .none
                return .submitSelectedCandidate
            case .delete:
                self = .composing
                return .removeLastMarkedText
            case .navigation:
                return .forwardToCandidateWindow(event)
            case .unknown, .escape:
                return .ignore
            }
        }
    }
}

@objc(TyputInputController)
class TyputInputController: IMKInputController {
    private var composingText: [String] = []
    private var selectedCandidate: String? = nil
    private var inputState: InputState = .none
    private var candidatesWindow: IMKCandidates = IMKCandidates()

    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        self.candidatesWindow = IMKCandidates(server: server, panelType: kIMKSingleColumnScrollingCandidatePanel)
        super.init(server: server, delegate: delegate, client: inputClient)
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        // get client to insert
        guard let client = sender as? IMKTextInput else {
            return false
        }
        let clientAction = switch event.keyCode {
        case 36: // Enter
            self.inputState.event(event, userAction: .enter)
        case 48: // Tab
            self.inputState.event(event, userAction: .tab)
        case 49: // Space
            self.inputState.event(event, userAction: .space)
        case 51: // Delete
            self.inputState.event(event, userAction: .delete)
        case 53: // Escape
            self.inputState.event(event, userAction: .escape)
        case 123: // Left
            self.inputState.event(event, userAction: .navigation(.left))
        case 124: // Right
            self.inputState.event(event, userAction: .navigation(.right))
        case 125: // Down
            self.inputState.event(event, userAction: .navigation(.down))
        case 126: // Up
            self.inputState.event(event, userAction: .navigation(.up))
        case 102: // Lang1
            self.inputState.event(event, userAction: .unknown)
        default:
            if let text = event.characters, text.allSatisfy({ $0.isLetter || $0.isNumber || $0.isPunctuation }) {
                self.inputState.event(event, userAction: .input(text))
            } else {
                self.inputState.event(event, userAction: .input(event.keyCode.description))
            }
        }
        return self.handleClientAction(clientAction, client: client)
    }

    func handleClientAction(_ clientAction: ClientAction, client: IMKTextInput) -> Bool {
        // return only false
        switch clientAction {
        case .showCandidateWindow:
            self.candidatesWindow.update()
            self.candidatesWindow.show()
            // MARK: this is required to move the window front of the spotlight panel
            self.candidatesWindow.perform(Selector(("setWindowLevel:")), with: NSWindow.Level.modalPanel)
        case .hideCandidateWindow:
            self.candidatesWindow.hide()
        case .appendToMarkedText(let string):
            self.candidatesWindow.hide()
            self.composingText.append(string)
            client.setMarkedText(
                self.composingText.joined(),
                selectionRange: .notFound,
                replacementRange: .notFound
            )
        case .commitMarkedText:
            client.insertText(self.composingText.joined(), replacementRange: .notFound)
            self.composingText.removeAll()
            self.candidatesWindow.hide()
        case .submitSelectedCandidate:
            client.insertText(self.selectedCandidate ?? self.composingText.joined(), replacementRange: .notFound)
            self.selectedCandidate = nil
            self.composingText.removeAll()
            self.candidatesWindow.hide()
        case .insertText(let string):
            client.insertText(string, replacementRange: .notFound)
        case .removeLastMarkedText:
            self.candidatesWindow.hide()
            _ = self.composingText.popLast()
            client.setMarkedText(
                self.composingText.joined(),
                selectionRange: .notFound,
                replacementRange: .notFound
            )
            if self.composingText.isEmpty {
                self.inputState = .none
            }
        case .ignore:
            return false
        case .forwardToCandidateWindow(let event):
            self.candidatesWindow.interpretKeyEvents([event])
        }
        return true
    }

    /// function to provide candidates
    /// - returns: `[String]`
    override func candidates(_ sender: Any!) -> [Any]! {
        let base = composingText.joined()
        let simples = [
            base.capitalized,
            base.lowercased(),
            base.uppercased()
        ].filter { $0 != base }
        return [base] + simples + TypographyCandidate.typographicalCandidates(base)
    }

    override func candidateSelected(_ candidateString: NSAttributedString!) {
        self.selectedCandidate = candidateString.string
    }

    override func candidateSelectionChanged(_ candidateString: NSAttributedString!) {
        self.selectedCandidate = candidateString.string
    }
}
