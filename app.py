import streamlit as st
import google.generativeai as genai

st.title("Debug AI Key")

try:
    api_key = st.secrets["GOOGLE_API_KEY"]
    genai.configure(api_key=api_key)
    
    # Mencoba mendaftar model yang tersedia
    models = [m.name for m in genai.list_models() if 'generateContent' in m.supported_generation_methods]
    st.write("Model yang tersedia untuk API Key kamu:")
    st.write(models)
    
    # Mencoba pakai model pertama yang tersedia
    if models:
        model = genai.GenerativeModel(models[0])
        st.write(f"Mencoba menggunakan model: {models[0]}")
        response = model.generate_content("Halo")
        st.write("Berhasil! AI menjawab: " + response.text)
    else:
        st.error("Tidak ada model yang ditemukan untuk API Key ini.")
        
except Exception as e:
    st.error(f"Error detail: {e}")
