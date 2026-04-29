# Contador+ Server (Proxy Spotify)

Backend Node.js para proteger credenciais e expor endpoints consumidos pelo app.

## Objetivo
- Ocultar `SPOTIFY_CLIENT_SECRET` no servidor.
- Expor endpoint de episódios para consumo do cliente.

## Execução local
1. Criar configuração local:
   - `cp .env.example .env`
2. Preencher variáveis obrigatórias:
   - `SPOTIFY_CLIENT_ID`
   - `SPOTIFY_CLIENT_SECRET`
3. Instalar dependências:
   - `npm install`
4. Iniciar servidor:
   - `npm run start`

## Teste rápido
- `GET http://localhost:3000/spotify/shows/36pSkw1EtZgTnNrXmJcNPm/episodes?market=BR`

## Deploy
Pode ser publicado em Render, Railway, EC2 ou similar.

Para funcionalidades com push/cron/FCM, configure todas as variáveis do `.env` usadas nesses fluxos.
