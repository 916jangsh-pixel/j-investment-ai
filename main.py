import os
from datetime import datetime
import uuid

import pandas as pd
import streamlit as st
from PIL import Image

st.set_page_config(page_title="J.Investment AI", layout="wide")

JOURNAL_CSV_FILE = "channel_image_data.csv"
GOAL_CSV_FILE = "compound_goal_data.csv"
GOAL_SETTING_FILE = "compound_goal_setting.csv"
IMAGE_DIR = "uploaded_images"

os.makedirs(IMAGE_DIR, exist_ok=True)

RESULT_OPTIONS = ["미확인", "성공", "실패", "본절", "관망"]
DIRECTION_OPTIONS = ["LONG", "SHORT", "BOTH", "관망"]
CHANNEL_OPTIONS = ["상승채널", "하락채널", "박스권", "수렴채널", "확산채널", "기타"]
STATUS_OPTIONS = ["채널 내부", "상단 이탈 직전", "하단 이탈 직전", "상단 이탈 완료", "하단 이탈 완료", "이탈 후 되돌림", "기타"]


def load_journal_data():
    if os.path.exists(JOURNAL_CSV_FILE):
        df = pd.read_csv(JOURNAL_CSV_FILE)
        if "id" not in df.columns:
            df["id"] = [str(uuid.uuid4()) for _ in range(len(df))]
            df.to_csv(JOURNAL_CSV_FILE, index=False, encoding="utf-8-sig")
        return df
    return pd.DataFrame()


def save_journal_data(df):
    df.to_csv(JOURNAL_CSV_FILE, index=False, encoding="utf-8-sig")


def load_goal_data():
    if os.path.exists(GOAL_CSV_FILE):
        return pd.read_csv(GOAL_CSV_FILE)
    return pd.DataFrame()


def save_goal_data(df):
    df.to_csv(GOAL_CSV_FILE, index=False, encoding="utf-8-sig")


def load_goal_setting():
    if os.path.exists(GOAL_SETTING_FILE):
        df = pd.read_csv(GOAL_SETTING_FILE)
        if not df.empty:
            return df.iloc[-1].to_dict()

    return {
        "start_amount": 1200000,
        "add_amount": 0,
        "period_count": 49,
        "period_unit": "일",
        "target_rate": 15.0,
    }


def save_goal_setting(setting):
    pd.DataFrame([setting]).to_csv(GOAL_SETTING_FILE, index=False, encoding="utf-8-sig")


st.title("📊 J.Investment AI - 매매일지 & AI 데이터 수집툴")

tabs = st.tabs([
    "📷 새 매매일지 저장",
    "📚 매매일지 불러오기/수정",
    "💰 복리 목표 계산",
    "📊 간단 통계"
])

# =========================
# 1. 새 매매일지 저장
# =========================
with tabs[0]:
    col_left, col_right = st.columns([2, 1])

    with col_left:
        st.subheader("트레이딩뷰 이미지 업로드")

        uploaded_file = st.file_uploader(
            "트레이딩뷰 캡처 이미지를 업로드하세요",
            type=["png", "jpg", "jpeg"]
        )

        if uploaded_file is not None:
            image = Image.open(uploaded_file)
            st.image(image, caption="업로드 이미지 미리보기", use_container_width=True)

    with col_right:
        st.subheader("기록 입력")

        symbol = st.text_input("종목", value="BTCUSDT")
        timeframe = st.selectbox("시간봉", ["1m", "5m", "15m", "30m", "1h", "4h", "1d"])
        channel_type = st.selectbox("채널 종류", CHANNEL_OPTIONS)
        expected_direction = st.selectbox("예상 방향", DIRECTION_OPTIONS)
        confidence = st.slider("신뢰도", 0, 100, 50, 5)
        breakout_status = st.selectbox("현재 상태", STATUS_OPTIONS)
        result_status = st.selectbox("결과", RESULT_OPTIONS)
        memo = st.text_area("메모", placeholder="예: 상승채널 이탈 후 롱 예상, RSI 과매도, 거래량 증가 등")

        if uploaded_file is not None:
            if st.button("💾 매매일지 저장", type="primary"):
                now = datetime.now()
                record_id = str(uuid.uuid4())

                ext = uploaded_file.name.split(".")[-1].lower()
                safe_symbol = symbol.upper().replace("/", "_").replace(" ", "")
                image_filename = f"{now.strftime('%Y%m%d_%H%M%S')}_{safe_symbol}_{timeframe}_{record_id[:8]}.{ext}"
                image_path = os.path.join(IMAGE_DIR, image_filename)

                with open(image_path, "wb") as f:
                    f.write(uploaded_file.getbuffer())

                row = {
                    "id": record_id,
                    "created_at": now.strftime("%Y-%m-%d %H:%M:%S"),
                    "symbol": safe_symbol,
                    "timeframe": timeframe,
                    "channel_type": channel_type,
                    "expected_direction": expected_direction,
                    "confidence": confidence,
                    "breakout_status": breakout_status,
                    "result_status": result_status,
                    "memo": memo,
                    "image_path": image_path,
                    "original_filename": uploaded_file.name,
                    "updated_at": now.strftime("%Y-%m-%d %H:%M:%S")
                }

                df = load_journal_data()
                df = pd.concat([df, pd.DataFrame([row])], ignore_index=True)
                save_journal_data(df)

                st.success("매매일지 저장 완료!")

# =========================
# 2. 매매일지 불러오기/수정
# =========================
with tabs[1]:
    df = load_journal_data()

    if df.empty:
        st.info("아직 저장된 매매일지가 없습니다.")
    else:
        st.subheader("매매일지 검색")

        col_filter1, col_filter2, col_filter3 = st.columns(3)

        with col_filter1:
            symbol_filter = st.text_input("종목 검색", value="")

        with col_filter2:
            result_filter = st.selectbox("결과 필터", ["전체"] + RESULT_OPTIONS)

        with col_filter3:
            direction_filter = st.selectbox("방향 필터", ["전체"] + DIRECTION_OPTIONS)

        filtered_df = df.copy()

        if symbol_filter.strip():
            filtered_df = filtered_df[
                filtered_df["symbol"].astype(str).str.contains(symbol_filter.upper(), case=False, na=False)
            ]

        if result_filter != "전체":
            filtered_df = filtered_df[filtered_df["result_status"] == result_filter]

        if direction_filter != "전체":
            filtered_df = filtered_df[filtered_df["expected_direction"] == direction_filter]

        if filtered_df.empty:
            st.warning("검색 조건에 맞는 데이터가 없습니다.")
        else:
            filtered_df = filtered_df.copy()
            filtered_df["선택명"] = (
                filtered_df["created_at"].astype(str)
                + " | "
                + filtered_df["symbol"].astype(str)
                + " | "
                + filtered_df["timeframe"].astype(str)
                + " | "
                + filtered_df["channel_type"].astype(str)
                + " | "
                + filtered_df["expected_direction"].astype(str)
                + " | "
                + filtered_df["result_status"].astype(str)
            )

            selected_label = st.selectbox(
                "수정/확인할 데이터를 선택하세요",
                filtered_df["선택명"].tolist()
            )

            selected_index = filtered_df[filtered_df["선택명"] == selected_label].index[0]
            selected = df.loc[selected_index]

            col_img, col_edit = st.columns([2, 1])

            with col_img:
                st.subheader("저장된 이미지")

                image_path = selected.get("image_path", "")

                if isinstance(image_path, str) and os.path.exists(image_path):
                    st.image(image_path, use_container_width=True)
                else:
                    st.warning("이미지 파일을 찾을 수 없습니다.")
                    st.write(image_path)

            with col_edit:
                st.subheader("데이터 수정")

                new_result = st.selectbox(
                    "결과 수정",
                    RESULT_OPTIONS,
                    index=RESULT_OPTIONS.index(selected["result_status"]) if selected["result_status"] in RESULT_OPTIONS else 0
                )

                new_direction = st.selectbox(
                    "예상 방향 수정",
                    DIRECTION_OPTIONS,
                    index=DIRECTION_OPTIONS.index(selected["expected_direction"]) if selected["expected_direction"] in DIRECTION_OPTIONS else 0
                )

                new_channel_type = st.selectbox(
                    "채널 종류 수정",
                    CHANNEL_OPTIONS,
                    index=CHANNEL_OPTIONS.index(selected["channel_type"]) if selected["channel_type"] in CHANNEL_OPTIONS else 0
                )

                new_confidence = st.slider(
                    "신뢰도 수정",
                    0,
                    100,
                    int(selected["confidence"]) if not pd.isna(selected["confidence"]) else 50,
                    5
                )

                new_breakout = st.selectbox(
                    "현재 상태 수정",
                    STATUS_OPTIONS,
                    index=STATUS_OPTIONS.index(selected["breakout_status"]) if selected["breakout_status"] in STATUS_OPTIONS else 0
                )

                new_memo = st.text_area(
                    "메모 수정",
                    value=str(selected["memo"]) if not pd.isna(selected["memo"]) else "",
                    height=180
                )

                if st.button("✅ 수정 저장", type="primary"):
                    df.at[selected_index, "result_status"] = new_result
                    df.at[selected_index, "expected_direction"] = new_direction
                    df.at[selected_index, "channel_type"] = new_channel_type
                    df.at[selected_index, "confidence"] = new_confidence
                    df.at[selected_index, "breakout_status"] = new_breakout
                    df.at[selected_index, "memo"] = new_memo
                    df.at[selected_index, "updated_at"] = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

                    save_journal_data(df)

                    st.success("수정 완료!")
                    st.rerun()

                if st.button("🗑️ 선택 데이터 삭제"):
                    df = df.drop(index=selected_index).reset_index(drop=True)
                    save_journal_data(df)
                    st.success("삭제 완료!")
                    st.rerun()

            st.subheader("최근 저장 데이터")
            st.dataframe(df.tail(20), use_container_width=True)

            st.download_button(
                "📥 매매일지 CSV 다운로드",
                data=df.to_csv(index=False, encoding="utf-8-sig"),
                file_name="channel_image_data.csv",
                mime="text/csv"
            )

# =========================
# 3. 복리 목표 계산
# =========================
with tabs[2]:
    st.subheader("💰 복리 목표 계산기")

    saved_setting = load_goal_setting()

    st.write("목표 설정을 저장하면 다음에 앱을 다시 열어도 같은 목표값을 불러옵니다.")

    col1, col2 = st.columns(2)

    with col1:
        start_amount = st.number_input(
            "초기 투자 원금",
            min_value=0,
            value=int(saved_setting.get("start_amount", 1200000)),
            step=10000
        )

        add_amount = st.number_input(
            "매 회차 추가 납입금",
            min_value=0,
            value=int(saved_setting.get("add_amount", 0)),
            step=10000
        )

    with col2:
        period_count = st.number_input(
            "계산 기간",
            min_value=1,
            value=int(saved_setting.get("period_count", 49)),
            step=1
        )

        target_rate = st.number_input(
            "목표 수익률",
            min_value=0.0,
            value=float(saved_setting.get("target_rate", 15.0)),
            step=0.1
        )

    period_options = ["일", "주", "월"]
    saved_period_unit = saved_setting.get("period_unit", "일")

    period_unit = st.selectbox(
        "기간 단위",
        period_options,
        index=period_options.index(saved_period_unit) if saved_period_unit in period_options else 0
    )

    if st.button("⚙️ 목표 설정 저장/수정", type="primary"):
        setting = {
            "created_at": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "start_amount": start_amount,
            "add_amount": add_amount,
            "period_count": period_count,
            "period_unit": period_unit,
            "target_rate": target_rate
        }

        save_goal_setting(setting)
        st.success("목표 설정이 저장/수정되었습니다.")
        st.rerun()

    st.divider()

    rows = []
    total_invested = start_amount
    asset = start_amount

    for i in range(1, int(period_count) + 1):
        if i > 1:
            asset += add_amount
            total_invested += add_amount

        profit = asset * (target_rate / 100)
        asset_after = asset + profit
        cumulative_profit = asset_after - total_invested
        return_rate = (cumulative_profit / total_invested * 100) if total_invested > 0 else 0

        rows.append({
            "회차": f"{i}{period_unit}",
            "총 투자원금": round(total_invested),
            "해당 회차 목표수익": round(profit),
            "누적 목표수익": round(cumulative_profit),
            "목표 자산": round(asset_after),
            "누적 수익률": round(return_rate, 2)
        })

        asset = asset_after

    goal_df = pd.DataFrame(rows)

    final_asset = goal_df.iloc[-1]["목표 자산"]
    final_rate = goal_df.iloc[-1]["누적 수익률"]

    c1, c2, c3 = st.columns(3)

    with c1:
        st.metric("최종 목표 자산", f"{final_asset:,.0f} 원")

    with c2:
        st.metric("총 투자 원금", f"{total_invested:,.0f} 원")

    with c3:
        st.metric("누적 목표 수익률", f"{final_rate:,.2f}%")

    st.line_chart(goal_df.set_index("회차")[["목표 자산", "총 투자원금"]])

    st.subheader("목표 계산표")
    st.dataframe(goal_df, use_container_width=True)

    st.divider()

    st.subheader("📌 실제 자산 업데이트")

    actual_round = st.number_input(
        "현재 회차",
        min_value=1,
        max_value=int(period_count),
        value=1,
        step=1
    )

    actual_asset = st.number_input(
        "현재 실제 자산",
        min_value=0,
        value=start_amount,
        step=10000
    )

    target_asset_now = goal_df.iloc[int(actual_round) - 1]["목표 자산"]
    gap = actual_asset - target_asset_now
    achievement = (actual_asset / target_asset_now * 100) if target_asset_now > 0 else 0

    c4, c5, c6 = st.columns(3)

    with c4:
        st.metric("현재 회차 목표 자산", f"{target_asset_now:,.0f} 원")

    with c5:
        st.metric("실제 자산", f"{actual_asset:,.0f} 원")

    with c6:
        st.metric("달성률", f"{achievement:.2f}%")

    st.write(f"목표 대비 차이: **{gap:,.0f} 원**")

    memo_goal = st.text_area(
        "목표 메모",
        placeholder="예: 오늘 목표 미달, 무리한 진입 금지, 손절 기준 준수"
    )

    if st.button("💾 실제 자산 기록 저장"):
        save_row = {
            "created_at": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "start_amount": start_amount,
            "add_amount": add_amount,
            "period_count": period_count,
            "period_unit": period_unit,
            "target_rate": target_rate,
            "actual_round": actual_round,
            "target_asset": target_asset_now,
            "actual_asset": actual_asset,
            "gap": gap,
            "achievement": achievement,
            "memo": memo_goal
        }

        goal_saved_df = load_goal_data()
        goal_saved_df = pd.concat([goal_saved_df, pd.DataFrame([save_row])], ignore_index=True)
        save_goal_data(goal_saved_df)

        st.success("실제 자산 기록 저장 완료!")

    saved_goal_df = load_goal_data()

    if not saved_goal_df.empty:
        st.subheader("저장된 실제 자산 기록")
        st.dataframe(saved_goal_df.tail(20), use_container_width=True)

        st.download_button(
            "📥 목표 기록 CSV 다운로드",
            data=saved_goal_df.to_csv(index=False, encoding="utf-8-sig"),
            file_name="compound_goal_data.csv",
            mime="text/csv"
        )

# =========================
# 4. 간단 통계
# =========================
with tabs[3]:
    st.subheader("📊 매매일지 간단 통계")

    df = load_journal_data()

    if df.empty:
        st.info("아직 통계를 계산할 매매일지가 없습니다.")
    else:
        total_count = len(df)
        success_count = len(df[df["result_status"] == "성공"])
        fail_count = len(df[df["result_status"] == "실패"])
        breakeven_count = len(df[df["result_status"] == "본절"])

        checked_count = success_count + fail_count + breakeven_count
        win_rate = (success_count / checked_count * 100) if checked_count > 0 else 0

        c1, c2, c3, c4 = st.columns(4)

        with c1:
            st.metric("전체 기록", f"{total_count}개")

        with c2:
            st.metric("성공", f"{success_count}개")

        with c3:
            st.metric("실패", f"{fail_count}개")

        with c4:
            st.metric("승률", f"{win_rate:.2f}%")

        st.subheader("결과별 개수")
        st.bar_chart(df["result_status"].value_counts())

        st.subheader("채널 종류별 개수")
        st.bar_chart(df["channel_type"].value_counts())

        st.subheader("방향별 개수")
        st.bar_chart(df["expected_direction"].value_counts())