import Foundation
import CoreLocation

/// 운동한 곳의 동네 이름 ("성수동, 서울"). 위치를 한 번만 잡고 이름으로 바꿈. 좌표는 저장하지 않음.
final class PlaceLookup: NSObject, CLLocationManagerDelegate {
    private var manager: CLLocationManager?
    private let geocoder = CLGeocoder()
    private var done: ((String?) -> Void)?

    /// 지금 위치 한 번 → 동네 이름 (권한 없거나 실패하면 nil)
    func fetch(_ completion: @escaping (String?) -> Void) {
        done = completion
        let m = CLLocationManager()
        m.delegate = self
        m.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager = m
        switch m.authorizationStatus {
        case .denied, .restricted: finish(nil)
        case .notDetermined: m.requestWhenInUseAuthorization()
        default: m.requestLocation()
        }
    }

    /// 이미 있는 위치 → 동네 이름
    func name(for loc: CLLocation, _ completion: @escaping (String?) -> Void) {
        done = completion
        geocoder.reverseGeocodeLocation(loc) { [weak self] marks, _ in
            self?.finish(marks?.first.flatMap(PlaceLookup.label))
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard done != nil else { return }
        switch manager.authorizationStatus {
        case .denied, .restricted: finish(nil)
        case .notDetermined: break
        default: manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last, done != nil else { return }
        manager.delegate = nil
        geocoder.reverseGeocodeLocation(loc) { [weak self] marks, _ in
            self?.finish(marks?.first.flatMap(PlaceLookup.label))
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) { finish(nil) }

    private func finish(_ s: String?) {
        let d = done
        done = nil
        manager?.delegate = nil
        manager = nil
        DispatchQueue.main.async { d?(s) }
    }

    /// 동(subLocality) + 시(locality, 없으면 도). "서울특별시" → "서울"
    static func label(_ p: CLPlacemark) -> String? {
        let city: String? = (p.locality ?? p.administrativeArea).map(short)
        let parts: [String] = [p.subLocality, city].compactMap { $0 }.filter { !$0.isEmpty }
        var uniq: [String] = []
        for x in parts where !uniq.contains(x) { uniq.append(x) }
        return uniq.isEmpty ? nil : uniq.joined(separator: ", ")
    }

    private static func short(_ s: String) -> String {
        var t = s
        for suf in ["특별자치시", "특별자치도", "특별시", "광역시"] where t.hasSuffix(suf) {
            t = String(t.dropLast(suf.count))
            break
        }
        return t
    }
}
