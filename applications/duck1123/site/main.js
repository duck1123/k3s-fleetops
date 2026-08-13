import { CONFIG } from "./config.js";
import { createPool, fetchProfile, fetchNotes, fetchReplies } from "./nostr.js";
import { hasExtension, login } from "./auth.js";
import { renderReplies, renderReplyForm } from "./comments.js";

const pool = createPool();
let myPubkey = null;

const profileEl = document.getElementById("profile");
const notesEl = document.getElementById("notes");
const loginBtn = document.getElementById("login-btn");
const authStatus = document.getElementById("auth-status");

function renderProfile(profile) {
  profileEl.innerHTML = "";
  if (!profile) {
    profileEl.innerHTML = '<p class="error">Could not load profile from configured relays.</p>';
    return;
  }

  if (profile.picture) {
    const img = document.createElement("img");
    img.className = "avatar";
    img.src = profile.picture;
    img.alt = profile.name ?? "avatar";
    profileEl.append(img);
  }

  const info = document.createElement("div");

  const h1 = document.createElement("h1");
  h1.textContent = profile.display_name || profile.name || `${CONFIG.pubkey.slice(0, 8)}…`;
  info.append(h1);

  if (profile.about) {
    const about = document.createElement("p");
    about.className = "about";
    about.textContent = profile.about;
    info.append(about);
  }

  if (profile.nip05) {
    const nip05 = document.createElement("p");
    nip05.className = "nip05";
    nip05.textContent = profile.nip05;
    info.append(nip05);
  }

  profileEl.append(info);
}

function renderNote(note) {
  const el = document.createElement("article");
  el.className = "note";

  const content = document.createElement("div");
  content.className = "content";
  content.textContent = note.content;

  const meta = document.createElement("div");
  meta.className = "meta";
  meta.textContent = new Date(note.created_at * 1000).toLocaleString();

  const repliesContainer = document.createElement("div");

  el.append(content, meta, repliesContainer);

  if (myPubkey) {
    const form = renderReplyForm({
      pool,
      relays: CONFIG.relays,
      note,
      ownerPubkey: CONFIG.pubkey,
      myPubkey,
      onPublished: async () => {
        const replies = await fetchReplies(pool, [note.id], CONFIG.relays);
        renderReplies(repliesContainer, replies);
      },
    });
    el.append(form);
  }

  fetchReplies(pool, [note.id], CONFIG.relays).then((replies) => {
    renderReplies(repliesContainer, replies);
  });

  return el;
}

async function renderNotes() {
  notesEl.innerHTML = '<p class="loading">Loading notes…</p>';
  const notes = await fetchNotes(pool, CONFIG.pubkey, CONFIG.relays);
  notesEl.innerHTML = "";
  if (!notes.length) {
    notesEl.innerHTML = '<p class="error">No notes found on the configured relays.</p>';
    return;
  }
  for (const note of notes) {
    notesEl.append(renderNote(note));
  }
}

function updateAuthUI() {
  if (myPubkey) {
    loginBtn.style.display = "none";
    authStatus.textContent = `Logged in as ${myPubkey.slice(0, 8)}…`;
  } else if (!hasExtension()) {
    loginBtn.disabled = true;
    loginBtn.textContent = "No Nostr extension found";
  } else {
    loginBtn.style.display = "inline-block";
    authStatus.textContent = "";
  }
}

loginBtn.addEventListener("click", async () => {
  try {
    myPubkey = await login();
    updateAuthUI();
    await renderNotes();
  } catch (err) {
    alert(err.message ?? String(err));
  }
});

updateAuthUI();
fetchProfile(pool, CONFIG.pubkey, CONFIG.relays).then(renderProfile);
renderNotes();
