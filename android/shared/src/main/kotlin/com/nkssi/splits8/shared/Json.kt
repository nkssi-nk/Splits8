package com.nkssi.splits8.shared

import kotlinx.serialization.KSerializer
import kotlinx.serialization.descriptors.PrimitiveKind
import kotlinx.serialization.descriptors.PrimitiveSerialDescriptor
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import kotlinx.serialization.json.Json
import java.time.Instant
import java.time.OffsetDateTime
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit
import kotlin.math.floor

/**
 * 아이폰 JSONStore 와 같은 모양:
 * - 날짜는 ISO 8601 초 단위 "2026-10-12T08:00:00Z" (아이폰 .iso8601 은 소수 초를 못 읽음)
 * - 값이 없는(null) 칸은 아예 안 씀 (아이폰 Codable 과 같음)
 * - 모르는 칸은 무시 (새 버전 아이폰 백업도 읽히게)
 */
val SplitsJson: Json = Json {
    encodeDefaults = true
    explicitNulls = false
    ignoreUnknownKeys = true
    coerceInputValues = true
}

object InstantIso : KSerializer<Instant> {
    override val descriptor: SerialDescriptor = PrimitiveSerialDescriptor("Instant", PrimitiveKind.STRING)

    override fun serialize(encoder: Encoder, value: Instant) {
        encoder.encodeString(DateTimeFormatter.ISO_INSTANT.format(value.truncatedTo(ChronoUnit.SECONDS)))
    }

    override fun deserialize(decoder: Decoder): Instant {
        val s = decoder.decodeString()
        return runCatching { Instant.parse(s) }
            .getOrElse { OffsetDateTime.parse(s, DateTimeFormatter.ISO_OFFSET_DATE_TIME).toInstant() }
    }
}

/** 스위프트 .rounded() 와 같은 반올림 (0.5 는 0 에서 먼 쪽). 코틀린 round() 는 짝수 쪽이라 다름 */
fun Double.r(): Int = if (this >= 0) floor(this + 0.5).toInt() else -floor(-this + 0.5).toInt()

/** 아이폰 UUID().uuidString 과 같은 대문자 UUID */
fun newId(): String = java.util.UUID.randomUUID().toString().uppercase()
