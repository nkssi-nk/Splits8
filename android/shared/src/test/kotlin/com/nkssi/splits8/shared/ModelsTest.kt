package com.nkssi.splits8.shared

import org.junit.Assert.assertEquals
import org.junit.Test

/** 아이폰과 같은 값이 나오는지 확인 */
class ModelsTest {
    @Test fun divisionByKeyOrName() {
        assertEquals("Open Women", Division.of("openW").name)
        assertEquals("openW", Division.of("Open Women").key)
        assertEquals("openM", Division.of("unknown").key)
        assertEquals(9, Division.all.size)
    }

    @Test fun stationDetail() {
        val d = Division.of("dblX")
        assertEquals("50M · 152KG", Station.of("sledPush")!!.detail(d))
        assertEquals("100 REPS · 6KG · shared", Station.of("wallBalls")!!.detail(d))
        assertEquals("Push 152 · Pull 103 · FC 2×24 · SB 20 · WB 6KG", d.spec)
    }
}
