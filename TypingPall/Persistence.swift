import CoreData

final class PersistenceController: ObservableObject {
    private static let model = NSPersistentContainer(name: "TypingPall").managedObjectModel
    static let shared = PersistenceController()
    static let preview = PersistenceController(inMemory: true)

    let container: NSPersistentContainer
    @Published private(set) var loadError: String?
    @Published private(set) var isReady = false

    init(inMemory: Bool = false, storeURL: URL? = nil) {
        // Preserve the existing model, store name and location for existing users.
        container = NSPersistentContainer(name: "TypingPall", managedObjectModel: Self.model)
        if let description = container.persistentStoreDescriptions.first {
            if inMemory { description.type = NSInMemoryStoreType }
            if let storeURL { description.url = storeURL }
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
        }
        loadStore()
    }

    func loadStore() {
        loadError = nil
        container.loadPersistentStores { [weak self] _, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.loadError = error.map { "Your saved scripts could not be opened. Your data has not been deleted. \($0.localizedDescription)" }
                self.isReady = error == nil
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
