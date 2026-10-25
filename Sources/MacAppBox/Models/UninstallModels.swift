import Foundation

struct UninstallItem: Identifiable, Hashable {
    let id: String
    let url: URL
    let title: String
    let category: String
    let byteSize: Int64
    let isRequired: Bool

    init(
        url: URL,
        title: String,
        category: String,
        byteSize: Int64,
        isRequired: Bool = false
    ) {
        self.id = url.path
        self.url = url
        self.title = title
        self.category = category
        self.byteSize = byteSize
        self.isRequired = isRequired
    }
}
