import streamlit as st
import google.generativeai as genai

# Konfigurasi halaman
st.set_page_config(page_title="Nexzan AI Modding Hub", page_icon="🚀")
st.title("🚀 Nexzan AI Modding Hub")

# Mengambil API Key dari Secrets
try:
    api_key = st.secrets["GOOGLE_API_KEY"]
    genai.configure(api_key=api_key)
    # Kita gunakan model yang paling dasar agar tidak error NotFound
    model = genai.GenerativeModel('gemini-1.5-flash')
except Exception as e:
    st.error("API Key belum diset di Streamlit Secrets! Silakan atur di menu Settings.")
    st.stop()

# Riwayat chat
if "messages" not in st.session_state:
    st.session_state.messages = []

for message in st.session_state.messages:
    with st.chat_message(message["role"]):
        st.markdown(message["content"])

# Input chat
if prompt := st.chat_input("Tanya mod Minecraft..."):
    st.session_state.messages.append({"role": "user", "content": prompt})
    with st.chat_message("user"):
        st.markdown(prompt)

    with st.chat_message("assistant"):
        try:
            response = model.generate_content(prompt)
            st.markdown(response.text)
            st.session_state.messages.append({"role": "assistant", "content": response.text})
        except Exception as e:
            st.error(f"Terjadi kesalahan saat memproses: {e}")
