import { Hono } from "hono";
import { getConnInfo } from "hono/bun";
import sharp from "sharp";
import { z } from "zod";
import {
  PROFILE_PHOTO_MAX_BYTES,
  profilePhotoConsentSchema,
  profilePhotoUploadResponseSchema,
} from "../types";

const profilePhotoRouter = new Hono();
const storageResponseSchema = z.object({ file: profilePhotoUploadResponseSchema });
const RATE_WINDOW_MS = 10 * 60 * 1000;
const MAX_CLIENTS = 2048;
const MAX_DAILY_UPLOADS = 100;
const MAX_DAILY_BYTES = 100 * 1024 * 1024;
const MAX_BODY_BYTES = PROFILE_PHOTO_MAX_BYTES + 64 * 1024;
const clientAttempts = new Map<string, { count: number; expiresAt: number }>();
let quotaDay = "";
let dailyUploads = 0;
let dailyBytes = 0;
let inFlight = 0;

// Do not trust caller-controlled forwarding headers. Behind a reverse proxy,
// clients sharing that proxy share a bucket; global limits remain authoritative.
profilePhotoRouter.use("*", async (c, next) => {
  if (c.req.method !== "POST") return next();
  const now = Date.now();
  for (const [key, attempt] of clientAttempts) {
    if (attempt.expiresAt <= now) clientAttempts.delete(key);
  }
  let client = "unknown";
  try { client = getConnInfo(c).remote.address ?? client; } catch { /* Shared fallback, fail closed. */ }
  let attempt = clientAttempts.get(client);
  if (!attempt) {
    if (clientAttempts.size >= MAX_CLIENTS) {
      c.header("Retry-After", "600");
      return c.json({ error: { message: "De uploadservice is druk. Probeer het later opnieuw.", code: "PHOTO_RATE_LIMITED" } }, 429);
    }
    attempt = { count: 0, expiresAt: now + RATE_WINDOW_MS };
    clientAttempts.set(client, attempt);
  }
  if (attempt.count >= 10) {
    c.header("Retry-After", String(Math.ceil((attempt.expiresAt - now) / 1000)));
    return c.json({ error: { message: "Je hebt te vaak een foto verstuurd. Probeer het later opnieuw.", code: "PHOTO_RATE_LIMITED" } }, 429);
  }
  attempt.count += 1;
  if (inFlight >= 4) {
    c.header("Retry-After", "10");
    return c.json({ error: { message: "De uploadservice is druk. Probeer het later opnieuw.", code: "PHOTO_BUSY" } }, 429);
  }
  inFlight += 1;
  try { await next(); } finally { inFlight -= 1; }
});

profilePhotoRouter.post("/", async (c) => {
  const tooLarge = () => c.json({ error: { message: "Kies een foto van maximaal 5 MB.", code: "PHOTO_TOO_LARGE" } }, 413);
  let form: Awaited<ReturnType<Response["formData"]>>;
  try {
    // Enforce actual bytes even if Content-Length is absent or understated.
    // Buffer at most the limit; cancel the source before parsing an oversized body.
    const length = Number(c.req.header("content-length"));
    if (Number.isFinite(length) && length > MAX_BODY_BYTES) return tooLarge();
    const reader = c.req.raw.body?.getReader();
    if (!reader) {
      return c.json({ error: { message: "Selecteer eerst een foto.", code: "PHOTO_REQUIRED" } }, 400);
    }
    const chunks: Uint8Array[] = [];
    let size = 0;
    let timeout: ReturnType<typeof setTimeout>;
    const deadline = new Promise<never>((_, reject) => {
      timeout = setTimeout(() => {
        reject(Object.assign(new Error("Upload body timed out"), { name: "PhotoBodyTimeout" }));
        void reader.cancel().catch(() => {});
      }, 15_000);
    });
    try {
      while (true) {
        const { done, value } = await Promise.race([reader.read(), deadline]);
        if (done) break;
        size += value.byteLength;
        if (size > MAX_BODY_BYTES) {
          void reader.cancel().catch(() => {});
          return tooLarge();
        }
        chunks.push(value);
      }
    } finally { clearTimeout(timeout!); reader.releaseLock(); }
    const body = new Uint8Array(size);
    let offset = 0;
    for (const chunk of chunks) { body.set(chunk, offset); offset += chunk.byteLength; }
    form = await new Response(body, { headers: { "Content-Type": c.req.header("content-type") ?? "" } }).formData();
  } catch (error) {
    if (error instanceof Error && error.name === "BodyLimitError") return tooLarge();
    if (error instanceof Error && error.name === "PhotoBodyTimeout") {
      return c.json({ error: { message: "Het versturen van de foto duurde te lang. Probeer opnieuw.", code: "PHOTO_TIMEOUT" } }, 408);
    }
    return c.json({ error: { message: "De foto kon niet worden gelezen.", code: "INVALID_MULTIPART" } }, 400);
  }
  if (!profilePhotoConsentSchema.safeParse(form.get("consent")).success) {
    return c.json({ error: { message: "Geef eerst toestemming om deze foto te uploaden.", code: "PHOTO_CONSENT_REQUIRED" } }, 400);
  }
  const file = form.get("file");
  if (!(file instanceof File) || file.size === 0) {
    return c.json({ error: { message: "Selecteer eerst een foto.", code: "PHOTO_REQUIRED" } }, 400);
  }
  if (file.size > PROFILE_PHOTO_MAX_BYTES) return tooLarge();
  if (file.type !== "image/jpeg" && file.type !== "image/png") {
    return c.json({ error: { message: "Kies een geldige JPG- of PNG-foto.", code: "UNSUPPORTED_PHOTO" } }, 415);
  }

  const day = new Date().toISOString().slice(0, 10);
  if (day !== quotaDay) { quotaDay = day; dailyUploads = 0; dailyBytes = 0; }
  const quotaExceeded = () => {
    const midnight = Date.parse(`${day}T00:00:00Z`) + 24 * 60 * 60 * 1000;
    c.header("Retry-After", String(Math.max(1, Math.ceil((midnight - Date.now()) / 1000))));
    return c.json({ error: { message: "De dagelijkse uploadlimiet is bereikt. Probeer het morgen opnieuw.", code: "PHOTO_DAILY_LIMIT" } }, 429);
  };
  // Reserve synchronously before any decoder/storage await. Failures retain the
  // reservation to prevent retries bypassing quotas after ambiguous storage errors.
  if (dailyUploads >= MAX_DAILY_UPLOADS || dailyBytes + file.size > MAX_DAILY_BYTES) return quotaExceeded();
  dailyUploads += 1;
  dailyBytes += file.size;

  let sanitized: Buffer;
  try {
    const input = Buffer.from(await file.arrayBuffer());
    const image = sharp(input, { limitInputPixels: 16_000_000, failOn: "warning", sequentialRead: true });
    const metadata = await image.metadata();
    // Decoded format is authoritative: Bun's multipart parser may infer the
    // File MIME type from its filename instead of the submitted Content-Type.
    if (!["jpeg", "png"].includes(metadata.format) || !metadata.width || !metadata.height ||
        metadata.width > 8192 || metadata.height > 8192 || (metadata.pages ?? 1) > 1) {
      throw new Error("Unsupported image dimensions or format");
    }
    // Sharp drops EXIF, GPS, XMP, IPTC and ICC metadata by default. Never opt
    // into keepMetadata/withMetadata, and never forward the caller's original bytes.
    sanitized = await image.rotate().resize({ width: 1024, height: 1024, fit: "inside", withoutEnlargement: true })
      .flatten({ background: "#ffffff" }).jpeg({ quality: 80 }).toBuffer();
  } catch {
    return c.json({ error: { message: "Kies een geldige JPG- of PNG-foto van maximaal 16 miljoen pixels.", code: "UNSUPPORTED_PHOTO" } }, 415);
  }
  if (sanitized.byteLength > PROFILE_PHOTO_MAX_BYTES) return tooLarge();
  // Count whichever is larger: received bytes or bytes actually sent to storage.
  const extraBytes = Math.max(0, sanitized.byteLength - file.size);
  if (dailyBytes + extraBytes > MAX_DAILY_BYTES) return quotaExceeded();
  dailyBytes += extraBytes;

  const storageForm = new FormData();
  storageForm.append("file", new File([new Uint8Array(sanitized)], "profile-photo.jpg", { type: "image/jpeg" }));
  console.log(`[ProfilePhoto] Uploading sanitized image (${sanitized.byteLength} bytes)`);
  try {
    const response = await fetch("https://storage.vibecodeapp.com/v1/files/upload", {
      method: "POST",
      body: storageForm,
      signal: AbortSignal.timeout(45_000),
    });
    if (!response.ok) {
      console.error(`[ProfilePhoto] Storage rejected upload: HTTP ${response.status}`);
      return c.json({ error: { message: "De foto kon niet worden geüpload. Probeer het later opnieuw.", code: "PHOTO_STORAGE_FAILED" } }, 502);
    }
    const result = storageResponseSchema.parse(await response.json());
    console.log("[ProfilePhoto] Upload completed; returning CDN reference only");
    return c.json({ data: result.file });
  } catch (error) {
    console.error("[ProfilePhoto] Storage upload failed:", error instanceof Error ? error.name : "Unknown error");
    return c.json({ error: { message: "De foto kon niet worden geüpload. Controleer je verbinding en probeer opnieuw.", code: "PHOTO_UPLOAD_FAILED" } }, 502);
  }
});

export { profilePhotoRouter };
