import Foundation
import Carbon

final class GlobalHotKeyManager {
    static let shared = GlobalHotKeyManager()

    private let hotKeyID = EventHotKeyID(signature: OSType(0x43424C4B), id: 1)
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var action: (() -> Void)?

    private init() {}

    func register(action: @escaping () -> Void) throws {
        self.action = action
        guard hotKeyRef == nil else { return }

        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let eventHandlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, eventRef, userData in
                guard let userData else { return OSStatus(eventNotHandledErr) }
                let manager = Unmanaged<GlobalHotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                return manager.handleHotKeyEvent(eventRef)
            },
            1,
            &eventSpec,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )
        guard eventHandlerStatus == noErr else {
            throw GlobalHotKeyError.eventHandlerInstallFailed(eventHandlerStatus)
        }

        let registerStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_L),
            UInt32(cmdKey | shiftKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard registerStatus == noErr else {
            if let eventHandlerRef {
                RemoveEventHandler(eventHandlerRef)
                self.eventHandlerRef = nil
            }
            throw GlobalHotKeyError.hotKeyRegisterFailed(registerStatus)
        }
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    private func handleHotKeyEvent(_ eventRef: EventRef?) -> OSStatus {
        guard let eventRef else { return OSStatus(eventNotHandledErr) }

        var pressedHotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            eventRef,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &pressedHotKeyID
        )
        guard status == noErr else { return status }
        guard pressedHotKeyID.signature == hotKeyID.signature, pressedHotKeyID.id == hotKeyID.id else {
            return OSStatus(eventNotHandledErr)
        }

        action?()
        return noErr
    }

    deinit {
        unregister()
    }
}

enum GlobalHotKeyError: LocalizedError {
    case eventHandlerInstallFailed(OSStatus)
    case hotKeyRegisterFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .eventHandlerInstallFailed(let status):
            return "快捷键事件监听注册失败: \(status)"
        case .hotKeyRegisterFailed(let status):
            return "快捷键注册失败: \(status)"
        }
    }
}
