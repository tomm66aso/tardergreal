// api/create-checkout.js
// Crea una sessione Stripe Checkout e reindirizza l'utente al pagamento
// Uso: await fetch('/api/create-checkout', { method:'POST', body: JSON.stringify({ priceId, userId }) })

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).end();

  const { priceId, userId, userEmail } = req.body || {};
  if (!priceId || !userId) return res.status(400).json({ error: 'priceId e userId obbligatori' });

  try {
    const stripe = (await import('stripe')).default(process.env.STRIPE_SECRET_KEY);

    const session = await stripe.checkout.sessions.create({
      mode: 'subscription',
      payment_method_types: ['card'],
      customer_email: userEmail,
      line_items: [{ price: priceId, quantity: 1 }],
      success_url: `${process.env.SITE_URL}/dashboard.html?upgraded=1`,
      cancel_url: `${process.env.SITE_URL}/abbonamento.html?cancelled=1`,
      metadata: {
        supabase_user_id: userId,
        price_id: priceId,
      },
    });

    return res.json({ url: session.url });
  } catch (err) {
    console.error('Checkout error:', err);
    return res.status(500).json({ error: err.message });
  }
}
