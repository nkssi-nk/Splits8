package com.nkssi.splits8.shared

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class GoalSplitTest {
    @Test fun benchAtBandEqualsTable() {
        // 표의 시간대와 딱 같은 목표 → 표 숫자 그대로
        for (d in Division.all) {
            for (row in HyroxBench.table(d.key)) {
                val (run, st) = HyroxBench.bench(d.key, row.band * 60)
                assertEquals(row.run, run)
                assertEquals(row.st, st)
                assertEquals(row.rox, HyroxBench.roxTotal(d.key, row.band * 60))
            }
        }
    }

    @Test fun benchInterpolates() {
        // Open Men 72:30 = 70분 줄과 75분 줄 사이 반 → run (259+276)/2 = 267.5 → 268
        assertEquals(268, HyroxBench.bench("Open Men", 72 * 60 + 30).first)
        // 범위 밖은 시간 비율로 늘림: 50분 = 60분 줄 × 5/6
        assertEquals((226 * 50 / 60.0).r(), HyroxBench.bench("openM", 50 * 60).first)
    }

    @Test fun roxEach() {
        // Open Men 80분: 374 / 8 = 46.75 → 5초 단위 45
        assertEquals(45, HyroxBench.roxEach(80 * 60, "openM"))
        // 아주 빠르면 최소 20초, 아주 느리면 최대 120초
        assertTrue(HyroxBench.roxEach(20 * 60, "openM") >= 20)
        assertEquals(120, HyroxBench.roxEach(600 * 60, "openM"))
    }

    @Test fun splitSumsAndSteps() {
        for (d in Division.all) {
            for (min in listOf(50, 61, 72, 85, 99, 120, 150, 180)) {
                for (style in GoalSplit.styles) {
                    val total = min * 60
                    val rox = HyroxBench.roxEach(total, d.key)
                    val out = GoalSplit.split(total, style, Defaults.goals, null, d.key, rox)
                    val target = (maxOf(480, total - 8 * rox) / 5.0).r() * 5
                    assertEquals("$d $min $style", 16, out.size)
                    assertEquals("$d $min $style", target, out.sum())
                    assertTrue(out.all { it >= 30 && it % 5 == 0 })
                }
            }
        }
    }

    @Test fun runnerFasterRuns() {
        val bal = GoalSplit.split(80 * 60, "balanced", Defaults.goals, null)
        val run = GoalSplit.split(80 * 60, "runner", Defaults.goals, null)
        assertTrue(run.filterIndexed { i, _ -> i % 2 == 0 }.sum() < bal.filterIndexed { i, _ -> i % 2 == 0 }.sum())
    }

    @Test fun byPace() {
        // 1.2.3: 목표 1:20 · 페이스 5:00 → 러닝 8 × 300 = 40:00, 남은 40:00 을 스테이션 · Roxzone 에 나눔
        val total = 80 * 60
        for (d in Division.all) for (style in GoalSplit.styles) {
            val rox = HyroxBench.roxEach(total, d.key)
            val r = GoalSplit.byPace(total, 300, style, Defaults.goals, null, d.key, rox)!!
            assertEquals(16, r.goals.size)
            assertTrue(r.goals.filterIndexed { i, _ -> i % 2 == 0 }.all { it == 300 })
            assertEquals(2400, r.runSum)
            assertTrue(r.goals.filterIndexed { i, _ -> i % 2 == 1 }.all { it >= 30 && it % 5 == 0 })
            assertTrue(r.rox in 20..120)
            // 합계는 5초 반올림 안
            assertTrue("${d.key} $style ${r.runSum + r.stSum + r.roxSum}", kotlin.math.abs(r.runSum + r.stSum + r.roxSum - total) <= 5)
        }
        // 러닝만으로 목표를 넘으면 null
        assertEquals(null, GoalSplit.byPace(40 * 60, 300, "balanced", Defaults.goals, null, "openM", 30))
        assertEquals(null, GoalSplit.byPace(46 * 60, 300, "balanced", Defaults.goals, null, "openM", 30))      // 남은 6분 < 최소 6:40
        // 기본 페이스 = 지금 방식의 러닝 평균 (5초 단위)
        val p = GoalSplit.defaultPace(total, "balanced", Defaults.goals, null, "openM", HyroxBench.roxEach(total, "openM"))
        assertEquals(0, p % 5)
        assertEquals(GoalSplit.roundPace(GoalSplit.runAvg(GoalSplit.split(total, "balanced", Defaults.goals, null, "openM", HyroxBench.roxEach(total, "openM")))!!), p)
        // 저장된 목표 평균 (예전 저장값)
        assertEquals(270, GoalSplit.runAvg(Defaults.goals))
        assertEquals(null, GoalSplit.runAvg(listOf(1, 2, 3)))
    }
}
