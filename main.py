import os
from datetime import datetime
import uuid

import pandas as pd
import streamlit as st
from PIL import Image

st.set_page_config(page_title="ChannelAI Journal", layout="wide")

CSV_FILE = "channel_image_data.csv"
IMAGE_DIR = "uploaded_images"

os.makedirs(IMAGE_DIR, exist_ok=True)

RESULT_OPTIONS = ["미확인", "성공", "실패", "본절", "관망"]
DIRECTION_OPTIONS = ["LONG", "SHORT", "BOTH", "관망"]
CHANNEL_OPTIONS = ["상승채널", "하락채널", "박스권", "수렴채널", "확산채널", "기타"]
STATUS_OPTIONS = [
    "채널 내부",
    "상단 이탈 직전",
    "하단 이탈 직전",
    "상단 이탈 완료",
    "하단 이탈 완료",
    "이탈 후 되돌림",
    "기타"
]

st.title("📊 ChannelAI - 매매일지 & AI 데이터 수집툴")

def load_data():
    if os.path.exists(CSV_FILE):
        df = pd.read_csv(CSV_FILE)
        if "id" not in df.columns:
            df["id"] = [str(uuid.uuid4()) for _ in range(len(df))]
            df.to_csv(CSV_FILE, index=False, encoding="utf-8-sig")
        return df
    return pd.DataFrame()

def save_data(df):
    df.to_csv(CSV_FILE, index=False, encoding="utf-8-sig")

tabs = st.tabs(["📷 새 데이터 저장", "📚 저장 데이터 불러오기/수정"])

# =========================
# 새 데이터 저장
# =========================
with tabs[0]:
    col_left, col_right = st.columns([2, 1])

    with col_left:
        uploaded_file = st.file_uploader(
            "트레이딩뷰 캡처 이미지 업로드",
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
        memo = st.text_area("메모")

        if uploaded_file is not None:
            if st.button("💾 저장하기", type="primary"):
                now = datetime.now()
                record_id = str(uuid.uuid4())

                ext = uploaded_file.name.split(".")[-1].lower()
                image_filename = f"{now.strftime('%Y%m%d_%H%M%S')}_{symbol}_{timeframe}_{record_id[:8]}.{ext}"
                image_path = os.path.join(IMAGE_DIR, image_filename)

                with open(image_path, "wb") as f:
                    f.write(uploaded_file.getbuffer())

                row = {
                    "id": record_id,
                    "created_at": now.strftime("%Y-%m-%d %H:%M:%S"),
                    "symbol": symbol.upper(),
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

                df = load_data()
                df = pd.concat([df, pd.DataFrame([row])], ignore_index=True)
                save_data(df)

                st.success("저장 완료!")

# =========================
# 저장 데이터 불러오기/수정
# =========================
with tabs[1]:
    df = load_data()

    if df.empty:
        st.info("아직 저장된 데이터가 없습니다.")
    else:
        st.subheader("저장된 데이터 목록")

        df_display = df.copy()
        df_display["선택명"] = (
            df_display["created_at"].astype(str)
            + " | "
            + df_display["symbol"].astype(str)
            + " | "
            + df_display["timeframe"].astype(str)
            + " | "
            + df_display["channel_type"].astype(str)
            + " | "
            + df_display["result_status"].astype(str)
        )

        selected_label = st.selectbox(
            "수정/확인할 데이터를 선택하세요",
            df_display["선택명"].tolist()
        )

        selected_index = df_display[df_display["선택명"] == selected_label].index[0]
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

                save_data(df)

                st.success("수정 완료!")
                st.rerun()

        st.subheader("전체 저장 데이터")
        st.dataframe(df.tail(10), use_container_width=True)

        st.download_button(
            "📥 CSV 다운로드",
            data=df.to_csv(index=False, encoding="utf-8-sig"),
            file_name="channel_image_data.csv",
            mime="text/csv"
        )