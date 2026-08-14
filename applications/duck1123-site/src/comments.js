import { signEvent } from "./auth.js";
import { publishEvent } from "./nostr.js";

function formatTime(ts) {
  return new Date(ts * 1000).toLocaleString();
}

function renderReply(reply) {
  const el = document.createElement("div");
  el.className = "reply";

  const content = document.createElement("div");
  content.textContent = reply.content;

  const meta = document.createElement("div");
  meta.className = "meta";
  meta.textContent = `${reply.pubkey.slice(0, 8)}… · ${formatTime(reply.created_at)}`;

  el.append(content, meta);
  return el;
}

export function renderReplies(container, replies) {
  container.innerHTML = "";
  if (!replies.length) return;
  const wrap = document.createElement("div");
  wrap.className = "replies";
  for (const reply of replies) wrap.append(renderReply(reply));
  container.append(wrap);
}

export function renderReplyForm({ pool, relays, note, ownerPubkey, myPubkey, onPublished }) {
  const form = document.createElement("form");
  form.className = "reply-form";

  const textarea = document.createElement("textarea");
  textarea.placeholder = "Reply…";
  textarea.required = true;

  const button = document.createElement("button");
  button.type = "submit";
  button.textContent = "Post";

  form.append(textarea, button);

  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    const content = textarea.value.trim();
    if (!content) return;

    button.disabled = true;
    button.textContent = "Posting…";

    try {
      const relay = relays[0] ?? "";
      const unsigned = {
        kind: 1,
        pubkey: myPubkey,
        created_at: Math.floor(Date.now() / 1000),
        tags: [
          ["e", note.id, relay, "reply"],
          ["p", ownerPubkey],
        ],
        content,
      };
      const signed = await signEvent(unsigned);
      await publishEvent(pool, signed, relays);
      textarea.value = "";
      onPublished?.(signed);
    } catch (err) {
      alert(`Failed to post reply: ${err.message ?? err}`);
    } finally {
      button.disabled = false;
      button.textContent = "Post";
    }
  });

  return form;
}
