import Foundation
import RxSwift
import TSCBasic
import TuistCore
import TuistSupport

enum CacheLocalStorageError: FatalError, Equatable {
    case xcframeworkNotFound(hash: String)

    var type: ErrorType {
        switch self {
        case .xcframeworkNotFound: return .abort
        }
    }

    var description: String {
        switch self {
        case let .xcframeworkNotFound(hash):
            return "xcframework with hash '\(hash)' not found in the local cache"
        }
    }
}

public final class CacheLocalStorage: CacheStoring {
    // MARK: - Attributes

    private let cacheDirectory: AbsolutePath

    // MARK: - Init

    public convenience init() {
        self.init(cacheDirectory: Environment.shared.xcframeworksCacheDirectory)
    }

    init(cacheDirectory: AbsolutePath) {
        self.cacheDirectory = cacheDirectory
    }

    // MARK: - CacheStoring

    public func exists(hash: String) -> Single<Bool> {
        Single.create { (completed) -> Disposable in
            completed(.success(FileHandler.shared.glob(self.cacheDirectory, glob: "\(hash)/*").count != 0))
            return Disposables.create()
        }
    }

    public func fetch(hash: String) -> Single<AbsolutePath> {
        Single.create { (completed) -> Disposable in
            if let path = FileHandler.shared.glob(self.cacheDirectory, glob: "\(hash)/*").first {
                completed(.success(path))
            } else {
                completed(.error(CacheLocalStorageError.xcframeworkNotFound(hash: hash)))
            }
            return Disposables.create()
        }
    }

    public func store(hash: String, xcframeworkPath: AbsolutePath) -> Completable {
        let copy = Completable.create { (completed) -> Disposable in
            let hashFolder = self.cacheDirectory.appending(component: hash)
            let destinationPath = hashFolder.appending(component: xcframeworkPath.basename)

            do {
                if !FileHandler.shared.exists(hashFolder) {
                    try FileHandler.shared.createFolder(hashFolder)
                }
                if FileHandler.shared.exists(destinationPath) {
                    try FileHandler.shared.delete(destinationPath)
                }

                try FileHandler.shared.copy(from: xcframeworkPath, to: destinationPath)

            } catch {
                completed(.error(error))
                return Disposables.create()
            }
            completed(.completed)
            return Disposables.create()
        }

        return createCacheDirectory().concat(copy)
    }

    // MARK: - Fileprivate

    fileprivate func createCacheDirectory() -> Completable {
        Completable.create { (completed) -> Disposable in
            do {
                if !FileHandler.shared.exists(self.cacheDirectory) {
                    try FileHandler.shared.createFolder(self.cacheDirectory)
                }
            } catch {
                completed(.error(error))
                return Disposables.create()
            }
            completed(.completed)
            return Disposables.create()
        }
    }
}
