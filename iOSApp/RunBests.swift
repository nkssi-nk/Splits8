import Foundation

// MARK: - 64번 · 러닝 기록: 정해진 거리 최고 기록(PB) · 거리 · 평균 페이스 대비
//
// 트레이닝 전체 시간 PB 는 의미가 없어서 안 셈(빨리 끝내면 PB 가 되므로).
// 러닝은 1 km · 5 km · 10 km · 하프 · 풀 거리마다 가장 빠른 기록을 셈.
// 긴 러닝 안에서 가장 빠른 연속 구간도 인정 (예: 20 km 안의 가장 빠른 5 km).

enum RunPB {
    /// (거리 m, 화면 이름)
    static let distances: [(m: Double, label: String)] = [
        (1000, "1 KM"), (5000, "5 KM"), (10000, "10 KM"), (21097.5, "HALF"), (42195, "MARATHON"),
    ]
    /// 이보다 빠른 페이스(1 km 2:30 미만)는 잘못 잰 기록으로 보고 뺌
    static let minPace: Double = 150

    /// 빌드 27: PB 알약 글자 ("5K PB" 등). 기록 목록 · 기록 화면 · 끝 카드 · 공유 카드
    static func pbName(_ m: Double) -> String {
        if m >= 42000 { return "FULL PB" }
        if m >= 21000 { return "HALF PB" }
        if m >= 10000 { return "10K PB" }
        if m >= 5000 { return "5K PB" }
        return "1KM PB"
    }
}

extension Record {
    /// 러닝 구간들 (거리 m, 시간 초) 순서대로
    var runLegs: [(m: Double, t: Int)] {
        let runs: [SegResult] = segs.filter { $0.kind == .run }
        let times: [Int] = runs.map(\.time).sorted()
        let median: Int = times.isEmpty ? 0 : times[times.count / 2]
        // 거리를 못 잰 구간(GPS 없음)은 계획 거리로 봄. 단, 중간에 끝낸 짧은 마지막 구간(시간이 보통 구간의 60% 미만)은 뺌
        return runs.compactMap { s in
            if let d = s.dist { return (d, s.time) }
            if Double(s.time) < Double(median) * 0.6 { return nil }
            return (runMeters(s.detail), s.time)
        }
    }

    /// 달린 거리 합계 (m)
    var runDistance: Double { runLegs.reduce(0) { $0 + $1.m } }

    /// 완주한 1 km 구간의 평균 페이스(초/km). 마지막 짧은 구간(0.5 km 미만)은 뺌
    var avgKmPace: Int? {
        let legs = runLegs.filter { $0.m >= 500 }
        let m: Double = legs.reduce(0) { $0 + $1.m }
        guard m > 0 else { return nil }
        let t: Double = Double(legs.reduce(0) { $0 + $1.t })
        return Int((t / m * 1000).rounded())
    }

    /// 이 기록 안에서 거리 D 를 가장 빨리 달린 시간(초). 구간 경계에서 시작하는 연속 구간 중 가장 빠른 것.
    /// 마지막 구간은 그 구간 페이스로 나눠 계산 (예: 5 km = 4 km + 다섯째 구간의 1 km 만큼)
    func bestEffort(_ D: Double) -> Int? {
        let legs = runLegs
        guard runDistance + 1 >= D, !legs.isEmpty else { return nil }
        var best: Double = .infinity
        for i in legs.indices {
            var m: Double = 0, t: Double = 0
            var j = i
            while j < legs.count && m < D {
                let leg = legs[j]
                let need: Double = D - m
                if leg.m <= need + 0.5 {
                    m += leg.m; t += Double(leg.t)
                } else {
                    t += Double(leg.t) * need / max(1, leg.m)
                    m = D
                }
                j += 1
            }
            if m + 1 >= D { best = min(best, t) }
        }
        guard best.isFinite, best / D * 1000 >= RunPB.minPace else { return nil }
        return Int(best.rounded())
    }
}

extension Store {
    /// 이 러닝 기록이 최고 기록인 거리들 (같은 거리를 뛴 러닝 기록이 2개 이상일 때만 PB 로 셈)
    func runPBs(_ r: Record) -> [Double] {
        guard r.isRunKind, r.counts else { return [] }
        let table: [Double: (best: Int, n: Int)] = runBestTable()
        return RunPB.distances.compactMap { d in
            guard let mine = r.bestEffort(d.m), let b = table[d.m], b.n >= 2, mine <= b.best else { return nil }
            return d.m
        }
    }

    /// 빌드 27: 러닝 기록의 PB 이름 — PB 인 거리 중 가장 긴 것 ("5K PB"). 러닝 PB 가 아니면 nil
    func runPBLabel(_ r: Record) -> String? {
        guard let m = runPBs(r).max() else { return nil }
        return RunPB.pbName(m)
    }

    /// 빌드 27: 홈 프로필 카드용 — 러닝 PB 중 가장 긴 거리 (거리 m, 시간 초). 같은 거리를 2번 이상 뛰었을 때만
    func longestRunPB() -> (m: Double, time: Int)? {
        let table: [Double: (best: Int, n: Int)] = runBestTable()
        for d in RunPB.distances.reversed() {
            if let b = table[d.m], b.n >= 2 { return (d.m, b.best) }
        }
        return nil
    }

    /// 거리별 (가장 빠른 시간, 그 거리를 뛴 기록 수). 목록을 그릴 때마다 다시 세지 않게 기록이 바뀔 때만 계산
    private func runBestTable() -> [Double: (best: Int, n: Int)] {
        let runs: [Record] = records.filter { $0.mode == .training && $0.isRunKind && $0.counts }
        let key: String = "\(records.count)|" + runs.map { "\($0.id)" }.joined(separator: ",")
        if let c = runBestCache, c.key == key { return c.table }
        var t: [Double: (best: Int, n: Int)] = [:]
        for d in RunPB.distances {
            let all: [Int] = runs.compactMap { $0.bestEffort(d.m) }
            if let b = all.min() { t[d.m] = (b, all.count) }
        }
        runBestCache = (key, t)
        return t
    }
}

/// runBestTable 저장 (Store 는 다른 파일이라 여기 둠, 메인 스레드에서만 씀)
private var runBestCache: (key: String, table: [Double: (best: Int, n: Int)])?

