import { SimplePool } from "https://esm.sh/nostr-tools@2.10.4";

export function createPool() {
  return new SimplePool();
}

export async function fetchProfile(pool, pubkey, relays) {
  const events = await pool.querySync(relays, {
    kinds: [0],
    authors: [pubkey],
    limit: 1,
  });
  if (!events.length) return null;
  const latest = events.reduce((a, b) => (b.created_at > a.created_at ? b : a));
  try {
    return JSON.parse(latest.content);
  } catch {
    return null;
  }
}

export async function fetchNotes(pool, pubkey, relays, limit = 20) {
  const events = await pool.querySync(relays, {
    kinds: [1],
    authors: [pubkey],
    limit,
  });
  return events.sort((a, b) => b.created_at - a.created_at);
}

// Single-level replies only (NIP-10 "reply" marker) — not full threading.
export async function fetchReplies(pool, noteIds, relays) {
  if (!noteIds.length) return [];
  const events = await pool.querySync(relays, {
    kinds: [1],
    "#e": noteIds,
  });
  return events.sort((a, b) => a.created_at - b.created_at);
}

export function publishEvent(pool, event, relays) {
  return Promise.allSettled(pool.publish(relays, event));
}
