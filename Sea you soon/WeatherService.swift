//
//  WeatherService.swift
//  Sea you soon
//
//  Current weather at the ship's position via Open-Meteo. English descriptions.
//

import Foundation

@Observable
class WeatherService {
    var temperature: Double?
    var weatherCode: Int?

    private var lastFetchedCoords: String?

    /// WMO weather code to SF Symbol + English description
    var weatherInfo: (icon: String, description: String)? {
        guard let code = weatherCode else { return nil }
        return Self.weatherDescription(for: code)
    }

    func fetch(latitude: Double, longitude: Double) async {
        let coordKey = "\(latitude),\(longitude)"
        guard coordKey != lastFetchedCoords else { return }

        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(latitude)&longitude=\(longitude)&current=temperature_2m,weather_code"
        guard let url = URL(string: urlString) else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
            await MainActor.run {
                self.temperature = response.current.temperature_2m
                self.weatherCode = response.current.weather_code
                self.lastFetchedCoords = coordKey
            }
        } catch {
            print("Weather fetch failed: \(error.localizedDescription)")
        }
    }

    private static func weatherDescription(for code: Int) -> (icon: String, description: String) {
        switch code {
        case 0: return ("sun.max.fill", "Clear")
        case 1: return ("sun.min.fill", "Mainly clear")
        case 2: return ("cloud.sun.fill", "Partly cloudy")
        case 3: return ("cloud.fill", "Overcast")
        case 45, 48: return ("cloud.fog.fill", "Fog")
        case 51, 53, 55: return ("cloud.drizzle.fill", "Drizzle")
        case 56, 57: return ("cloud.sleet.fill", "Freezing drizzle")
        case 61, 63, 65: return ("cloud.rain.fill", "Rain")
        case 66, 67: return ("cloud.sleet.fill", "Freezing rain")
        case 71, 73, 75: return ("cloud.snow.fill", "Snow")
        case 77: return ("cloud.snow.fill", "Snow grains")
        case 80, 81, 82: return ("cloud.heavyrain.fill", "Rain showers")
        case 85, 86: return ("cloud.snow.fill", "Snow showers")
        case 95: return ("cloud.bolt.fill", "Thunderstorm")
        case 96, 99: return ("cloud.bolt.rain.fill", "Thunderstorm with hail")
        default: return ("cloud.fill", "Cloudy")
        }
    }
}

private struct OpenMeteoResponse: Codable {
    let current: CurrentWeather

    struct CurrentWeather: Codable {
        let temperature_2m: Double
        let weather_code: Int
    }
}
