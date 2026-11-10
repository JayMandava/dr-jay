import CoreLocation
import Foundation
import Observation

/// One-shot, opt-in weather lookup. Coordinates never leave memory except for
/// the rounded coordinates sent directly to Open-Meteo on an explicit refresh.
@MainActor
@Observable
final class SurroundingsWeatherService: NSObject, @preconcurrency CLLocationManagerDelegate {
    private(set) var snapshot: SurroundingsWeather?
    private(set) var isLoading = false
    private(set) var statusMessage: String?
    private(set) var enabled = false

    @ObservationIgnored private let makeLocationManager: @MainActor () -> CLLocationManager
    @ObservationIgnored private var locationManager: CLLocationManager?
    @ObservationIgnored private var fetchTask: Task<Void, Never>?
    @ObservationIgnored private var timeoutTask: Task<Void, Never>?
    @ObservationIgnored private var expiryTask: Task<Void, Never>?
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var awaitingLocation = false
    private static let cacheLifetime: TimeInterval = 30 * 60

    init(makeLocationManager: @escaping @MainActor () -> CLLocationManager = { CLLocationManager() }) {
        self.makeLocationManager = makeLocationManager
        super.init()
    }

    func setEnabled(_ enabled: Bool) {
        guard self.enabled != enabled else { return }
        self.enabled = enabled
        cancelPendingWork()
        if !enabled {
            snapshot = nil
            expiryTask?.cancel()
            expiryTask = nil
            statusMessage = nil
        } else {
            statusMessage = "Tap Check Weather to share your approximate location with Open-Meteo."
        }
    }

    func refresh() {
        guard enabled, !isLoading else { return }
        if let snapshot, snapshot.isUsable(at: .now) {
            statusMessage = "Using weather fetched within the last 30 minutes."
            return
        }
        snapshot = nil
        cancelPendingWork()
        isLoading = true
        statusMessage = "Waiting for location permission…"
        let requestGeneration = generation
        // A new manager per request also fences queued delegate callbacks from
        // a previous request, including disable/re-enable cycles.
        let manager = makeLocationManager()
        locationManager = manager
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        timeoutTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(45)) } catch { return }
            guard let self, self.enabled, self.generation == requestGeneration else { return }
            self.finishWithError("Location took too long. Check location permission in Settings, then tap Check Weather.")
        }
        handleAuthorization(manager)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard enabled, isLoading, manager === locationManager else { return }
        handleAuthorization(manager)
    }

    private func handleAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            guard !awaitingLocation else { return }
            awaitingLocation = true
            statusMessage = "Finding your approximate location…"
            manager.requestLocation()
        case .denied, .restricted:
            finishWithError("Location access is unavailable. Enable location for this app in Settings, then tap Check Weather.")
        @unknown default:
            finishWithError("Location is unavailable. Try Check Weather again.")
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard enabled, isLoading, awaitingLocation, manager === locationManager else { return }
        guard let location = locations.last(where: {
            $0.horizontalAccuracy >= 0 && abs($0.timestamp.timeIntervalSinceNow) < 5 * 60
                && CLLocationCoordinate2DIsValid($0.coordinate)
        }) else {
            finishWithError("A recent location was unavailable. Try Check Weather again.")
            return
        }
        let latitude = (location.coordinate.latitude * 10).rounded() / 10
        let longitude = (location.coordinate.longitude * 10).rounded() / 10
        releaseLocationManager()
        timeoutTask?.cancel()
        timeoutTask = nil
        fetchWeather(latitude: latitude, longitude: longitude, requestGeneration: generation)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard enabled, isLoading, manager === locationManager else { return }
        finishWithError("Could not find your location. Check Location Services and try Check Weather again.")
    }

    private func fetchWeather(latitude: Double, longitude: Double, requestGeneration: UUID) {
        statusMessage = "Fetching current weather…"
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,apparent_temperature,relative_humidity_2m,weather_code"),
            URLQueryItem(name: "temperature_unit", value: "celsius"),
            URLQueryItem(name: "timeformat", value: "unixtime"),
            URLQueryItem(name: "timezone", value: "GMT")
        ]
        guard let url = components.url else {
            finishWithError("Weather could not be requested. Try again later.")
            return
        }
        fetchTask = Task { [weak self] in
            let configuration = URLSessionConfiguration.ephemeral
            configuration.urlCache = nil
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            configuration.timeoutIntervalForRequest = 15
            configuration.timeoutIntervalForResource = 20
            let session = URLSession(configuration: configuration)
            defer { session.invalidateAndCancel() }
            do {
                let (data, response) = try await session.data(from: url)
                try Task.checkCancellation()
                guard let self, self.enabled, self.generation == requestGeneration else { return }
                guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
                    self.finishWithError("Weather service is unavailable. Try Check Weather later.")
                    return
                }
                let current = try JSONDecoder().decode(WeatherResponse.self, from: data).current
                let now = Date()
                let sourceAge = now.timeIntervalSince1970 - current.time
                guard current.temperature.isFinite, (-90...60).contains(current.temperature),
                      current.apparentTemperature.isFinite, (-100...80).contains(current.apparentTemperature),
                      current.humidity.isFinite, (0...100).contains(current.humidity),
                      Self.validWeatherCodes.contains(current.weatherCode),
                      current.time.isFinite, (-600...7200).contains(sourceAge) else {
                    self.finishWithError("Weather data was outdated or incomplete. Try Check Weather later.")
                    return
                }
                self.snapshot = SurroundingsWeather(
                    temperatureC: current.temperature,
                    apparentTemperatureC: current.apparentTemperature,
                    humidityPercent: current.humidity,
                    weatherCode: current.weatherCode,
                    observedAt: now,
                    region: SurroundingsRegion(latitude: latitude, longitude: longitude)
                )
                self.isLoading = false
                self.statusMessage = "Weather from Open-Meteo for your approximate area."
                self.fetchTask = nil
                self.expiryTask?.cancel()
                self.expiryTask = Task { [weak self] in
                    do { try await Task.sleep(for: .seconds(Self.cacheLifetime)) } catch { return }
                    guard let self, self.enabled, self.generation == requestGeneration else { return }
                    self.snapshot = nil
                    self.statusMessage = "Weather has expired. Tap Check Weather for an update."
                }
            } catch {
                guard !Task.isCancelled, let self, self.enabled,
                      self.generation == requestGeneration else { return }
                self.finishWithError("Could not load weather. Check your internet connection and tap Check Weather.")
            }
        }
    }

    private func finishWithError(_ message: String) {
        cancelPendingWork()
        statusMessage = message
    }

    private func releaseLocationManager() {
        locationManager?.stopUpdatingLocation()
        locationManager?.delegate = nil
        locationManager = nil
        awaitingLocation = false
    }

    private func cancelPendingWork() {
        generation = UUID()
        fetchTask?.cancel()
        fetchTask = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        releaseLocationManager()
        isLoading = false
    }

    private static let validWeatherCodes: Set<Int> = [
        0, 1, 2, 3, 45, 48, 51, 53, 55, 56, 57, 61, 63, 65,
        66, 67, 71, 73, 75, 77, 80, 81, 82, 85, 86, 95, 96, 99
    ]

    private struct WeatherResponse: Decodable {
        let current: Current
        struct Current: Decodable {
            let temperature: Double
            let apparentTemperature: Double
            let humidity: Double
            let weatherCode: Int
            let time: Double
            enum CodingKeys: String, CodingKey {
                case temperature = "temperature_2m"
                case apparentTemperature = "apparent_temperature"
                case humidity = "relative_humidity_2m"
                case weatherCode = "weather_code"
                case time
            }
        }
    }
}
