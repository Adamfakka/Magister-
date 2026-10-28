import { afterEach, expect, spyOn, test } from "bun:test";
import sharp from "sharp";
import type { Hono } from "hono";
import { PROFILE_PHOTO_MAX_BYTES } from "../types";

async function errorCode(response: Response): Promise<string> {
  return (await response.json() as { error: { code: string } }).error.code;
}

let generation = 0;
const restorers: Array<() => void> = [];
afterEach(() => { for (const restore of restorers.splice(0)) restore(); });
async function freshRouter(): Promise<Hono> {
  return (await import(`./profile-photo.ts?test=${generation++}`)).profilePhotoRouter;
}
function multipart(bytes: Uint8Array, type = "image/jpeg", consent = "true") {
  const form = new FormData();
  form.append("consent", consent);
  form.append("file", new File([new Uint8Array(bytes)], "original.jpg", { type }));
  return { method: "POST", body: form };
}
function request(router: Hono, init: RequestInit, client = "192.0.2.1") {
  return router.request("https://example.test/", init, {
    server: { requestIP: () => ({ address: client, family: "IPv4", port: 12345 }) },
  });
}
function mockStorage(inspect?: (file: File) => Promise<void>) {
  let calls = 0;
  const mock = spyOn(globalThis, "fetch").mockImplementation(Object.assign(async (_input: Parameters<typeof fetch>[0], init?: Parameters<typeof fetch>[1]) => {
    calls++;
    const file = (init!.body as FormData).get("file") as File;
    await inspect?.(file);
    return Response.json({ file: { url: "https://files.staticfiles.net/test-profile.jpg" } });
  }, { preconnect: globalThis.fetch.preconnect }));
  restorers.push(() => mock.mockRestore());
  return () => calls;
}
async function jpeg(width = 20, height = 20) {
  return sharp({ create: { width, height, channels: 3, background: "#336699" } }).jpeg().toBuffer();
}

test("valid JPEG/PNG uploads are resized, metadata-free JPEGs with the same response contract", async () => {
  const router = await freshRouter();
  const calls = mockStorage(async (file) => {
    expect(file.name).toBe("profile-photo.jpg");
    expect(file.type).toBe("image/jpeg");
    const metadata = await sharp(Buffer.from(await file.arrayBuffer())).metadata();
    expect(metadata.format).toBe("jpeg");
    expect(Math.max(metadata.width!, metadata.height!)).toBeLessThanOrEqual(1024);
    expect(metadata.exif).toBeUndefined();
    expect(metadata.xmp).toBeUndefined();
    expect(metadata.iptc).toBeUndefined();
    expect(metadata.icc).toBeUndefined();
  });
  for (const format of ["jpeg", "png"] as const) {
    const input = await sharp({ create: { width: 1400, height: 1200, channels: 3, background: "#336699" } })
      .withExif({ IFD0: { Artist: "Private test metadata" } }).toFormat(format).toBuffer();
    expect((await sharp(input).metadata()).exif).toBeDefined();
    const response = await request(router, multipart(input, `image/${format}`));
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ data: { url: "https://files.staticfiles.net/test-profile.jpg" } });
  }
  expect(calls()).toBe(2);
});

test("tiny signatures, truncated images, disguised unsupported formats and excessive dimensions never reach storage", async () => {
  const router = await freshRouter();
  const calls = mockStorage();
  const tooWide = await jpeg(8193, 1);
  const tooManyPixels = await jpeg(4100, 4100);
  const inputs = [
    multipart(new Uint8Array([255, 216, 255])),
    multipart(new Uint8Array([137, 80, 78, 71, 13, 10, 26, 10]), "image/png"),
    multipart((await jpeg()).subarray(0, 80)),
    multipart(await sharp({ create: { width: 20, height: 20, channels: 3, background: "red" } }).gif().toBuffer()),
    multipart(tooWide),
    multipart(tooManyPixels),
  ];
  for (const input of inputs) {
    const response = await request(router, input);
    expect(response.status).toBe(415);
    expect(await errorCode(response)).toBe("UNSUPPORTED_PHOTO");
  }
  expect(calls()).toBe(0);
});

test("missing consent and malformed multipart are rejected", async () => {
  const router = await freshRouter();
  const calls = mockStorage();
  expect((await request(router, multipart(await jpeg(), "image/jpeg", "false"))).status).toBe(400);
  const response = await request(router, { method: "POST", headers: { "Content-Type": "multipart/form-data" }, body: "invalid" });
  expect(await errorCode(response)).toBe("INVALID_MULTIPART");
  expect(calls()).toBe(0);
});

test("oversized files and declared oversized bodies return 413", async () => {
  const router = await freshRouter();
  const calls = mockStorage();
  for (const input of [
    multipart(new Uint8Array(PROFILE_PHOTO_MAX_BYTES + 1)),
    { method: "POST", headers: { "Content-Length": String(PROFILE_PHOTO_MAX_BYTES + 65537) }, body: "x" },
  ]) {
    const response = await request(router, input);
    expect(response.status).toBe(413);
    expect(await errorCode(response)).toBe("PHOTO_TOO_LARGE");
  }
  expect(calls()).toBe(0);
});

test("oversized streams without Content-Length are cancelled and return 413", async () => {
  const router = await freshRouter();
  const calls = mockStorage();
  let cancelled = false;
  const stream = new ReadableStream<Uint8Array>({
    pull(controller) { controller.enqueue(new Uint8Array(1024 * 1024)); },
    cancel() { cancelled = true; },
  });
  const response = await request(router, { method: "POST", headers: { "Content-Type": "multipart/form-data; boundary=test" }, body: stream });
  expect(response.status).toBe(413);
  expect(await errorCode(response)).toBe("PHOTO_TOO_LARGE");
  expect(cancelled).toBe(true);
  expect(calls()).toBe(0);
});

test("valid streamed multipart uploads are accepted without Content-Length", async () => {
  const router = await freshRouter();
  const calls = mockStorage();
  const serialized = new Request("https://example.test/", multipart(await jpeg()));
  const headers = new Headers(serialized.headers);
  headers.delete("content-length");
  const response = await request(router, { method: "POST", headers, body: serialized.body });
  expect(response.status).toBe(200);
  expect(calls()).toBe(1);
});

test("understated Content-Length cannot bypass the actual streamed byte limit", async () => {
  const router = await freshRouter();
  const stream = new ReadableStream<Uint8Array>({
    pull(controller) { controller.enqueue(new Uint8Array(1024 * 1024)); },
  });
  const response = await request(router, { method: "POST", headers: { "Content-Length": "1" }, body: stream });
  expect(response.status).toBe(413);
  expect(await errorCode(response)).toBe("PHOTO_TOO_LARGE");
});

test("BodyLimitError remains a 413 rather than INVALID_MULTIPART", async () => {
  const router = await freshRouter();
  const stream = new ReadableStream({ start(controller) { controller.error(Object.assign(new Error("large"), { name: "BodyLimitError" })); } });
  const response = await request(router, { method: "POST", body: stream });
  expect(response.status).toBe(413);
  expect(await errorCode(response)).toBe("PHOTO_TOO_LARGE");
});

test("forwarded headers cannot bypass per-client attempt limits", async () => {
  const router = await freshRouter();
  for (let i = 0; i < 11; i++) {
    const response = await request(router, { method: "POST", headers: { "X-Forwarded-For": `198.51.100.${i}` }, body: "invalid" });
    expect(response.status).toBe(i === 10 ? 429 : 400);
    if (i === 10) {
      expect(await errorCode(response)).toBe("PHOTO_RATE_LIMITED");
      expect(Number(response.headers.get("Retry-After"))).toBeGreaterThan(0);
    }
  }
});

test("process-wide daily upload quota covers different clients and failed attempts", async () => {
  const router = await freshRouter();
  const calls = mockStorage();
  const invalid = new Uint8Array([255, 216, 255]);
  for (let i = 0; i < 101; i++) {
    const response = await request(router, multipart(invalid), `192.0.2.${Math.floor(i / 10)}`);
    expect(response.status).toBe(i === 100 ? 429 : 415);
    if (i === 100) expect(await errorCode(response)).toBe("PHOTO_DAILY_LIMIT");
  }
  expect(calls()).toBe(0);
});

test("process-wide daily byte quota covers different clients and failed attempts", async () => {
  const router = await freshRouter();
  const calls = mockStorage();
  const invalid = new Uint8Array(PROFILE_PHOTO_MAX_BYTES);
  for (let i = 0; i < 21; i++) {
    const response = await request(router, multipart(invalid), `192.0.2.${Math.floor(i / 10)}`);
    expect(response.status).toBe(i === 20 ? 429 : 415);
    if (i === 20) expect(await errorCode(response)).toBe("PHOTO_DAILY_LIMIT");
  }
  expect(calls()).toBe(0);
});

test("only four requests may occupy decoder/storage slots at once", async () => {
  const router = await freshRouter();
  let release!: () => void;
  let ready!: () => void;
  const gate = new Promise<void>((resolve) => { release = resolve; });
  const entered = new Promise<void>((resolve) => { ready = resolve; });
  let count = 0;
  mockStorage(async () => { count++; if (count === 4) ready(); await gate; });
  const image = await jpeg();
  const pending = Array.from({ length: 4 }, (_, i) => request(router, multipart(image), `client-${i}`));
  await entered;
  try {
    const response = await request(router, multipart(image), "fifth-client");
    expect(response.status).toBe(429);
    expect(await errorCode(response)).toBe("PHOTO_BUSY");
  } finally { release(); }
  for (const response of await Promise.all(pending)) expect(response.status).toBe(200);
  expect((await request(router, multipart(image), "sixth-client")).status).toBe(200);
});

test("per-client limiter refuses new buckets instead of growing beyond its bound", async () => {
  const router = await freshRouter();
  for (let i = 0; i < 2049; i++) {
    const response = await request(router, { method: "POST", body: "invalid" }, `client-${i}`);
    expect(response.status).toBe(i === 2048 ? 429 : 400);
  }
});
