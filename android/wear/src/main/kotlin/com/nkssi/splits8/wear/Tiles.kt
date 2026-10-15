package com.nkssi.splits8.wear

import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import androidx.wear.watchface.complications.data.ComplicationData
import androidx.wear.watchface.complications.data.ComplicationType
import androidx.wear.watchface.complications.data.MonochromaticImage
import androidx.wear.watchface.complications.data.PlainComplicationText
import androidx.wear.watchface.complications.data.ShortTextComplicationData
import androidx.wear.watchface.complications.datasource.ComplicationDataSourceUpdateRequester
import androidx.wear.watchface.complications.datasource.ComplicationRequest
import androidx.wear.watchface.complications.datasource.SuspendingComplicationDataSourceService
import com.nkssi.splits8.shared.WidgetSnap
import java.time.Instant

/**
 * 시계 화면 칸: 다음 대회 D-day (아이폰 워치 컴플리케이션과 같은 내용).
 * 폰에서 대회를 바꾸면(묶음이 오면) 새로 그림. 누르면 앱이 열림.
 */
object Tiles {
    /** "D-12" / "D-DAY" / 대회 없으면 "–" */
    fun dday(now: Instant = Instant.now()): String {
        val ev = WatchStore.settings.event
        if (!ev.isSet) return "–"
        val d = WidgetSnap(raceName = ev.name, raceDate = ev.date).daysLeft(now) ?: return "–"
        return if (d == 0) "D-DAY" else "D-$d"
    }

    fun refresh(context: Context?) {
        val c = context ?: return
        if (WatchStore.demo) return
        runCatching {
            ComplicationDataSourceUpdateRequester.create(c, ComponentName(c, RaceComplicationService::class.java)).requestUpdateAll()
        }
    }
}

class RaceComplicationService : SuspendingComplicationDataSourceService() {
    override fun getPreviewData(type: ComplicationType): ComplicationData? =
        if (type == ComplicationType.SHORT_TEXT) data("D-12") else null

    override suspend fun onComplicationRequest(request: ComplicationRequest): ComplicationData? {
        WatchStore.init(applicationContext)
        if (request.complicationType != ComplicationType.SHORT_TEXT) return null
        return data(Tiles.dday())
    }

    private fun data(text: String): ComplicationData {
        val open = PendingIntent.getActivity(this, 0, Intent(this, WearActivity::class.java), PendingIntent.FLAG_IMMUTABLE)
        return ShortTextComplicationData.Builder(PlainComplicationText.Builder(text).build(), PlainComplicationText.Builder("Race").build())
            .setMonochromaticImage(MonochromaticImage.Builder(android.graphics.drawable.Icon.createWithResource(this, R.drawable.i_race)).build())
            .setTapAction(open)
            .build()
    }
}
