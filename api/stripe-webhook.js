// api/stripe-webhook.js
// Riceve gli eventi Stripe e aggiorna i piani utente su Supabase
// In Stripe Dashboard: Webhooks â†’ Add endpoint â†’ https://tuosito.vercel.app/api/stripe-webhook
// Events: checkout.session.completed, customer.subscription.updated, customer.subscription.deleted

export const config = { api: { bodyParser: false } };

async function getRawBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on('data', chunk => chunks.push(chunk));
    req.on('end', () => resolve(Buffer.concat(chunks)));
    req.on('error', reject);
  });
}

const PLAN_MAP = {
  // Mappa i price_id Stripe ai piani TraderGuardians
  // Sostituisci con i tuoi price_id reali da Stripe Dashboard
  'price_starter_monthly':  'starter',
  'price_pro_monthly':      'pro',
  'price_elite_monthly':    'elite',
  'price_starter_yearly':   'starter',
  'price_pro_yearly':       'pro',
  'price_elite_yearly':     'elite',
};

export default async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).end();

  const rawBody = await getRawBody(req);
  const sig = req.headers['stripe-signature'];
  const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;

  let event;
  try {
    const stripe = (await import('stripe')).default(process.env.STRIPE_SECRET_KEY);
    event = stripe.webhooks.constructEvent(rawBody, sig, webhookSecret);
  } catch (err) {
    console.error('Webhook signature error:', err.message);
    return res.status(400).json({ error: err.message });
  }

  const { createClient } = await import('@supabase/supabase-js');
  const sb = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_KEY);

  try {
    switch (event.type) {

      case 'checkout.session.completed': {
        const session = event.data.object;
        const customerId = session.customer;
        const subscriptionId = session.subscription;
        const userId = session.metadata?.supabase_user_id;
        const priceId = session.metadata?.price_id;
        const plan = PLAN_MAP[priceId] || 'starter';

        if (userId) {
          await sb.from('users').update({
            stripe_customer_id: customerId,
            stripe_subscription_id: subscriptionId,
            plan,
            plan_status: 'active',
            updated_at: new Date().toISOString(),
          }).eq('id', userId);
        }
        break;
      }

      case 'customer.subscription.updated': {
        const sub = event.data.object;
        const priceId = sub.items?.data?.[0]?.price?.id;
        const plan = PLAN_MAP[priceId] || 'starter';
        const status = sub.status === 'active' ? 'active' : sub.status;

        await sb.from('users').update({
          plan,
          plan_status: status,
          updated_at: new Date().toISOString(),
        }).eq('stripe_subscription_id', sub.id);
        break;
      }

      case 'customer.subscription.deleted': {
        const sub = event.data.object;
        await sb.from('users').update({
          plan: 'starter',
          plan_status: 'cancelled',
          stripe_subscription_id: null,
          updated_at: new Date().toISOString(),
        }).eq('stripe_subscription_id', sub.id);
        break;
      }

      case 'invoice.payment_failed': {
        const invoice = event.data.object;
        await sb.from('users').update({
          plan_status: 'past_due',
          updated_at: new Date().toISOString(),
        }).eq('stripe_customer_id', invoice.customer);
        break;
      }
    }

    // Salva evento nel log
    await sb.from('stripe_events').upsert({
      stripe_event_id: event.id,
      event_type: event.type,
      payload: event,
      processed: true,
    }, { onConflict: 'stripe_event_id' });

    return res.json({ received: true });
  } catch (err) {
    console.error('Webhook processing error:', err);
    return res.status(500).json({ error: err.message });
  }
}
