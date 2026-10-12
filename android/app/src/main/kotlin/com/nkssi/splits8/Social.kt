package com.nkssi.splits8

import kotlinx.serialization.Serializable

// 서버(Supabase)에서 받는 친구 · 순위표 모양 — 아이폰 Supabase.swift 와 같은 칸 이름

/** 순위표 한 줄 (leaderboard 함수 결과) */
@Serializable
data class LBRow(
    val user_id: String,
    val nickname: String,
    val division: String,
    val avatar_url: String? = null,
    val t: Int,
) {
    val id: String get() = user_id
}

/** 친구 요청 (받은 것 incoming / 보낸 것) */
data class FriendReq(
    val id: String,
    val name: String,
    val div: String,
    val avatarUrl: String?,
    val incoming: Boolean,
)
