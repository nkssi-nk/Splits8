package com.nkssi.splits8.wear

import com.nkssi.splits8.shared.DoublesPlan
import com.nkssi.splits8.shared.Fm
import com.nkssi.splits8.shared.GoalSplit
import com.nkssi.splits8.shared.Seg
import com.nkssi.splits8.shared.SegKind
import com.nkssi.splits8.shared.Settings
import com.nkssi.splits8.shared.Station
import kotlin.math.roundToInt

// 빌드 27 (68-① · 86번): 워치에서 고르는 Full Sim 목표 완주 시간 (아이폰 WGoalPicker · WatchStore.watchGoal)

object WatchGoal {
    /** 고를 수 있는 분 (45분 ~ 3시간, 1분 단위 — 아이폰과 같음) */
    val minutes: List<Int> = (45..180).toList()

    /** 목표 완주 시간(초) → 16구간 목표 (폰과 같은 "balanced" 나누기) */
    fun split(goal: Int, s: Settings, best: List<Int>?): List<Int> =
        GoalSplit.split(goal, "balanced", s.goals, best, s.division, s.roxTarget)

    /** 고르기 화면을 열 때 처음 자리 (분): 고른 값 → 없으면 지금 16칸 합 + Roxzone 8번 */
    fun initialMinutes(watchGoal: Int?, simTargets: List<Int>, roxTarget: Int): Int {
        val cur = watchGoal ?: (simTargets.sum() + 8 * roxTarget)
        return (cur / 60.0).roundToInt().coerceIn(45, 180)
    }

    /**
     * 확인 화면에 보일 Full Sim 목표 (86번): 워치에서 고른 목표는 그 숫자 그대로.
     * 아니면 구간 목표 합 (Roxzone 을 안 켜서 순서에 없으면 Roxzone 8번 목표를 더함)
     */
    fun shown(watchGoal: Int?, seq: List<Seg>, roxTarget: Int): String {
        if (watchGoal != null) return Fm.t(watchGoal)
        val hasRox = seq.any { it.kind == SegKind.Rox }
        return Fm.t(seq.sumOf { it.target } + (if (hasRox) 0 else 8 * roxTarget))
    }
}

/**
 * 75번 (빌드 27): 운동 화면 스테이션 아래 줄에 붙일 더블 계획 한 줄. 예: "Me 150 → Jiho 150 · 7 turns"
 * 더블 디비전(키가 "dbl" 로 시작)이고 지금 구간이 스테이션이며 계획이 있을 때만. 아니면 null. 파트너 이름은 6글자까지
 */
fun doublesLine(seg: Seg, plan: DoublesPlan?, division: String): String? {
    if (plan == null || !division.startsWith("dbl") || seg.kind != SegKind.St) return null
    val i = Station.all.indexOfFirst { it.key == seg.icon }
    if (i < 0) return null
    val seq = plan.sequence(i)
    val first = seq.firstOrNull() ?: return null
    val me = wt("Me")
    val partner = plan.partnerShown.take(6)
    val firstName = if (first.me) me else partner
    val secondName = if (first.me) partner else me
    // 둘째 차례 양 (한 번에 끝나면 0) — 보통은 같은 양
    val secondAmount = if (seq.size > 1) seq[1].amount else 0.0
    val head = firstName + " " + DoublesPlan.num(first.amount) + " → " + secondName + " " + DoublesPlan.num(secondAmount)
    return head + " · " + wt("%lld turns", seq.size)
}
