import streamlit as st
import google.generativeai as genai

# Konfigurasi halaman
st.set_page_config(page_title="Nexzan AI Modding Hub", page_icon="🚀")
st.title("🚀 Nexzan AI Modding Hub")

# Setup API
try:
    api_key = st.secrets["GOOGLE_API_KEY"]
    genai.configure(api_key=api_key)
    
    # Menggunakan model yang sudah terbukti tersedia di list kamu
    model = genai.GenerativeModel('gemini-2.0-flash')
except Exception as e:
    st.error(f"Error konfigurasi: {e}")
    st.stop()

# Inisialisasi riwayat chat
if "messages" not in st.session_state:
    st.session_state.messages = []

# Menampilkan chat yang sudah ada
for message in st.session_state.messages:
    with st.chat_message(message["role"]):
        st.markdown(message["content"])

# Input dari user
if prompt := st.chat_input("Tanya mod Minecraft..."):
    # Simpan chat user
    st.session_state.messages.append({"role": "user", "content": prompt})
    with st.chat_message("user"):
        st.markdown(prompt)

    # Proses AI
    with st.chat_message("assistant"):
        try:
            response = model.generate_content(prompt)
            st.markdown(response.text)
            # Simpan chat asisten
            st.session_state.messages.append({"role": "assistant", "content": response.text})
        except Exception as e:
            st.error(f"Terjadi kesalahan saat memproses: {e}")
