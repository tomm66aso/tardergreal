export default async function handler(req, res) {
  const secret = process.env.CRON_SECRET;
  if (secret && req.headers['authorization'] !== `Bearer ${secret}`) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  const { createClient } = await import('@supabase/supabase-js');
  const sb = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_KEY);
  const apiKey = process.env.GEMINI_API_KEY;
  const today = new Date().toISOString().split('T')[0];
  const results = [];

  const categories = ['forex', 'commodities', 'crypto', 'stocks', 'bonds'];

  for (const cat of categories) {
    try {
      const prompt = `Oggi Ã¨ ${today}. Cerca notizie finanziarie su: ${cat}. Rispondi SOLO JSON senza backtick:
{"news":[{"title":"...","summary":"...","source":"Reuters","published_at":"1 ora fa","impact":"high|medium|low","direction":"bullish|bearish|neutral","affected_assets":["..."],"short_term_impact":"...","medium_term_impact":"...","featured":true}],"ai_summary":"...","market_mood":"risk-on|risk-off|mixed","impact_scores":{"${cat}":75},"key_events_today":[{"time":"09:30","event":"...","impact":"h","color":"#ff4d6a"}]}
Max 6 notizie. Solo ultime 24h. In italiano.`;

      const r = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${apiKey}`,
        { method: 'POST', headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ contents: [{ parts: [{ text: prompt }] }], tools: [{ googleSearch: {} }], generationConfig: { temperature: 0.2, maxOutputTokens: 2000 } }) }
      );
      const d = await r.json();
      const text = d.candidates?.[0]?.content?.parts?.[0]?.text || '{}';
      const parsed = JSON.parse(text.replace(/```json\s*/gi, '').replace(/```\s*/gi, '').trim());

      await sb.from('market_data_snapshots').upsert(
        { tab_id: `news_${cat}`, data: parsed, updated_at: new Date().toISOString() },
        { onConflict: 'tab_id' }
      );
      results.push({ cat, status: 'ok' });
    } catch (e) {
      results.push({ cat, status: 'error', error: e.message });
    }
  }

  // Genera anche segnali del giorno
  try {
    const prompt = `Oggi ${today}. Cerca prezzi e analisi live con web search. Genera 4 segnali operativi REALISTICI. Solo JSON senza backtick:
{"signals":[{"asset":"XAU/USD","asset_category":"commodities","direction":"long","conviction":8,"entry_price":"5160","stop_loss":"5148","target_1":"5185","target_1_note":"Chiudi 50% a BE","target_2":"5200","target_2_note":"Target finale","condition":"Supporto 5160 su 15min","key_levels":["5148","5160","5200"],"news_events":["..."],"session_risks":["..."],"analysis":"...","plan":"pro"}]}`;

    const r = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${apiKey}`,
      { method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ contents: [{ parts: [{ text: prompt }] }], tools: [{ googleSearch: {} }], generationConfig: { temperature: 0.2, maxOutputTokens: 2000 } }) }
    );
    const d = await r.json();
    const text = d.candidates?.[0]?.content?.parts?.[0]?.text || '{}';
    const parsed = JSON.parse(text.replace(/```json\s*/gi, '').replace(/```\s*/gi, '').trim());

    if (parsed.signals?.length) {
      await sb.from('operative_signals').insert(
        parsed.signals.map(s => ({ ...s, status: 'active', valid_for_date: today }))
      );
      results.push({ cat: 'signals', status: 'ok', count: parsed.signals.length });
    }
  } catch (e) {
    results.push({ cat: 'signals', status: 'error', error: e.message });
  }

  return res.json({ success: true, timestamp: new Date().toISOString(), results });
}
