import express from "express";
import cors from "cors";
import fs from "fs";
import path from "path";
import cron from "node-cron";
import admin from "firebase-admin";

const {
  SPOTIFY_CLIENT_ID, SPOTIFY_CLIENT_SECRET, ALLOW_ORIGIN="*",
  FCM_SERVICE_ACCOUNT_JSON, FCM_TOPIC, CRON_SCHEDULE, SHOW_ID,
  DATA_PATH=".data/last.json", PORT=3000,
} = process.env;

if (!SPOTIFY_CLIENT_ID || !SPOTIFY_CLIENT_SECRET) {
  console.error("❌ Defina SPOTIFY_CLIENT_ID/SECRET");
  process.exit(1);
}

const app = express();
app.use(cors({ origin: ALLOW_ORIGIN }));

let appToken=null, appTokenExp=0;
async function getAppToken() {
  const now = Math.floor(Date.now()/1000);
  if (appToken && now < appTokenExp-60) return appToken;
  const auth = Buffer.from(`${SPOTIFY_CLIENT_ID}:${SPOTIFY_CLIENT_SECRET}`).toString("base64");
  const res = await fetch("https://accounts.spotify.com/api/token", {
    method:"POST",
    headers:{ Authorization:`Basic ${auth}`, "Content-Type":"application/x-www-form-urlencoded" },
    body:"grant_type=client_credentials"
  });
  if (!res.ok) throw new Error(`Token error: ${res.status} ${await res.text()}`);
  const data = await res.json();
  appToken = data.access_token; appTokenExp = Math.floor(Date.now()/1000) + data.expires_in;
  return appToken;
}

async function listAllEpisodes(showId, market="BR") {
  const token = await getAppToken();
  let items = [], url = `https://api.spotify.com/v1/shows/${showId}/episodes?limit=50&market=${market}`;
  while (url) {
    const res = await fetch(url, { headers: { Authorization:`Bearer ${token}` } });
    if (!res.ok) throw new Error(`Spotify error: ${res.status} ${await res.text()}`);
    const page = await res.json();
    items.push(...page.items); url = page.next;
  }
  return items.map(e => ({
    id:e.id, name:e.name, description:e.description, release_date:e.release_date,
    duration_ms:e.duration_ms, external_url:e.external_urls?.spotify,
    images:e.images, audio_preview_url:e.audio_preview_url
  })).sort((a,b)=>(b.release_date||"").localeCompare(a.release_date||""));
}

app.get("/health", (_,res)=>res.json({ok:true,ts:Date.now()}));

app.get("/spotify/shows/:id/episodes", async (req,res)=>{
  try {
    const items = await listAllEpisodes(req.params.id, req.query.market || "BR");
    res.set("Cache-Control","public, max-age=300");
    res.json({count:items.length, items});
  } catch(e) { res.status(500).json({error:e.message}); }
});

/* Push opcional (FCM) com cron — preencha as envs para habilitar */
if (FCM_SERVICE_ACCOUNT_JSON && FCM_TOPIC && CRON_SCHEDULE && SHOW_ID) {
  try {
    admin.initializeApp({ credential: admin.credential.cert(JSON.parse(FCM_SERVICE_ACCOUNT_JSON)) });
    console.log("✅ FCM habilitado");
  } catch(e) { console.error("⚠️  FCM_SERVICE_ACCOUNT_JSON inválido:", e.message); }
  function readLast() {
    try {
      if (!fs.existsSync(path.dirname(DATA_PATH))) fs.mkdirSync(path.dirname(DATA_PATH), { recursive:true });
      if (!fs.existsSync(DATA_PATH)) return { lastEpisodeId:null };
      return JSON.parse(fs.readFileSync(DATA_PATH, "utf-8"));
    } catch { return { lastEpisodeId:null }; }
  }
  function writeLast(obj) {
    try {
      if (!fs.existsSync(path.dirname(DATA_PATH))) fs.mkdirSync(path.dirname(DATA_PATH), { recursive:true });
      fs.writeFileSync(DATA_PATH, JSON.stringify(obj), "utf-8");
    } catch {}
  }
  cron.schedule(CRON_SCHEDULE, async ()=>{
    try {
      const eps = await listAllEpisodes(SHOW_ID, "BR");
      if (!eps.length) return;
      const newest = eps[0];
      const data = readLast();
      if (newest.id && data.lastEpisodeId !== newest.id) {
        await admin.messaging().send({
          topic: FCM_TOPIC,
          notification: { title: "Novo episódio", body: newest.name },
          data: { route: "/podcast", episodeId: newest.id, externalUrl: newest.external_url || "" },
        });
        writeLast({ lastEpisodeId: newest.id, ts: Date.now() });
        console.log("🔔 Notificação enviada:", newest.name);
      }
    } catch(e){ console.error("cron error:", e.message); }
  });
}

app.listen(PORT, ()=>console.log(`🚀 Proxy on http://localhost:${PORT}`));
