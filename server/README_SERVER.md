# Proxy Spotify (Client Credentials)

Protege o Client Secret e expõe o endpoint para o app listar episódios.

## Rodar local
1) `cp .env.example .env` e preencha `SPOTIFY_CLIENT_ID/SECRET`
2) `npm install`
3) `npm run start`
4) Teste: `GET http://localhost:3000/spotify/shows/36pSkw1EtZgTnNrXmJcNPm/episodes?market=BR`

## Deploy
Use Render/Railway/EC2. Para push (cron + FCM), preencha as variáveis do `.env`.
