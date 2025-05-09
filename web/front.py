import streamlit as st
import os
import requests # requests を追加してバックエンド API を呼び出す

# FastAPI バックエンド URL
BACKEND_BASE_URL = "http://34.133.158.81:12002" # あなたの実際のバックエンドURLに置き換えてください
BACKEND_VIDEO_URL_BASE = f"{BACKEND_BASE_URL}/videos"

# 関数：バックエンドからビデオリストを取得
def get_video_list_from_backend():
    try:
        response = requests.get(f"{BACKEND_VIDEO_URL_BASE}/list")
        response.raise_for_status() # リクエストが失敗した場合 HTTPError をスロー
        return response.json() # バックエンドはファイル名のリストを返す
    except requests.exceptions.RequestException as e:
        st.error(f"バックエンドからビデオリストを取得できませんでした: {e}")
        return []

st.set_page_config(layout="wide")
st.title("eduVideo-LLM Agent") # "视频播放器和网站浏览" -> "ビデオプレーヤーとウェブサイトブラウジング"

# session_state でビデオリストとオプションを初期化/取得
if 'video_files' not in st.session_state:
    st.session_state.video_files = get_video_list_from_backend()

if 'video_options' not in st.session_state or not st.session_state.video_options:
    if st.session_state.video_files:
        st.session_state.video_options = {
            os.path.splitext(video_filename)[0].replace("_", " ").replace("-", " ").title(): video_filename
            for video_filename in st.session_state.video_files
        }
    else:
        st.session_state.video_options = {}

col1, col2 = st.columns([3,1.5])

with col1:
    st.header("学習エリア")

    if not st.session_state.video_options:
        st.warning("没有可播放的视频。请检查后端视频目录或后端服务是否正常运行。")
    else:
        selected_video_title = st.selectbox(
            "映像教材を選択:",
            options=list(st.session_state.video_options.keys())
        )

        if selected_video_title:
            video_filename = st.session_state.video_options[selected_video_title]
            video_url = f"{BACKEND_VIDEO_URL_BASE}/{video_filename}"

            st.subheader(f"再生中: {selected_video_title}")
            st.video(video_url)

with col2:
    st.header("Video RAG")
    iframe_html = (
                                """<iframe
                                    src="http://34.133.158.81/chatbot/QsQtD5w0SeNFrcup"
                                    style="width: 100%; height: 100%; min-height: 700px"
                                    frameborder="0"
                                    allow="microphone">
                                </iframe>"""
                            )
    st.markdown(iframe_html, unsafe_allow_html=True)

