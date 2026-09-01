import Foundation

final class FileWatcher {
    private var source: DispatchSourceFileSystemObject?
    private let onChange: () -> Void

    init(onChange: @escaping () -> Void) {
        self.onChange = onChange
    }

    func watch(path: String) {
        stop()
        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            self?.onChange()
        }
        source.setCancelHandler {
            close(fd)
        }
        source.resume()
        self.source = source
    }

    func stop() {
        source?.cancel()
        source = nil
    }

    deinit {
        stop()
    }
}
