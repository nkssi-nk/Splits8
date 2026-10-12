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
}
