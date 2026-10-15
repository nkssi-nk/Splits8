package com.nkssi.splits8.shared

// 폰 ↔ 갤럭시 워치 주고받는 내용 (아이폰 WatchConnectivity 와 같은 역할, 안드로이드는 Wearable Data Layer).
//
// 폰 → 워치: DataItem "/ctx"  — 설정 · 트레이닝 · 비교 기준 (아이폰 updateApplicationContext 와 같음, 마지막 것만 남음)
// 워치 → 폰: DataItem "/record/<id>" — 끝난 기록 하나. 폰이 받아서 저장한 뒤 그 DataItem 을 지움 = "받았다" 확인.
//            워치는 지워진 것을 보고 보관함(w_pending.json)에서 뺌. 연결이 끊겨 있어도 DataItem 은 다시 이어지면 저절로 감.
// 운동 중: 메시지 "/live" — LivePacket (워치 → 폰 상태, 폰 → 워치 단추)

object WatchWire {
    /** DataItem 안의 글자 칸 이름 */
    const val KEY = "json"

    fun recordPath(id: String) = SyncKey.record + "/" + id
    fun isRecordPath(path: String?) = path != null && path.startsWith(SyncKey.record + "/")
    fun recordId(path: String): String = path.removePrefix(SyncKey.record + "/")

    fun ctxJson(c: WatchContext): String = SplitsJson.encodeToString(WatchContext.serializer(), c)
    fun ctx(json: String?): WatchContext? =
        json?.let { runCatching { SplitsJson.decodeFromString(WatchContext.serializer(), it) }.getOrNull() }

    fun recordJson(r: Record): String = SplitsJson.encodeToString(Record.serializer(), r)
    fun record(json: String?): Record? =
        json?.let { runCatching { SplitsJson.decodeFromString(Record.serializer(), it) }.getOrNull() }

    /**
     * 워치에 보낼 묶음 (아이폰 Store.pushToWatch 와 같은 내용).
     * 친구는 구간 16개가 있을 때만, 최고 · 마지막 기록은 정상 기록만.
     */
    fun context(settings: Settings, programs: List<Program>, friend: Friend?, book: RecordBook): WatchContext {
        val best = book.simBest
        val pft = book.pftBest
        return WatchContext(
            settings = settings, programs = programs,
            friend = friend?.takeIf { it.hasSplits },
            simBest = best?.splits16, simBestTotal = best?.total,
            segBests = book.segBests,
            pftBest = pft?.pftSplits, pftBestTotal = pft?.total,
            simLast = book.simLast?.splits16,
        )
    }
}
