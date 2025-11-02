import Foundation
import Combine

class EventViewModel: ObservableObject {
    @Published var events: [FatsomaEvent] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func loadEvents() {
        isLoading = true
        errorMessage = nil

        APIService.shared.fetchEvents { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false

                switch result {
                case .success(let events):
                    self?.events = events
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func searchEvents(query: String) {
        isLoading = true
        errorMessage = nil

        APIService.shared.searchEvents(query: query) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false

                switch result {
                case .success(let events):
                    self?.events = events
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func refreshData() {
        APIService.shared.refreshEvents { result in
            // Optionally reload events after refresh
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.loadEvents()
            }
        }
    }
}
