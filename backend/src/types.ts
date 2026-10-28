import { z } from "zod";

/**
 * POST /api/profile/photo
 * Multipart fields: file (decodable JPEG/PNG, <= 5 MiB, <= 16 million pixels
 * and <= 8192 pixels per side), consent (literal "true").
 * Images are resized to <= 1024 pixels per side and re-encoded without metadata.
 * Abuse limits: 10 attempts/client/10 minutes; process-wide UTC-day quota of
 * 100 file attempts and 100 MiB (failed attempts still count); 4 concurrent requests.
 * Limits are in memory and reset on process restart; not a distributed quota.
 * Limit errors use HTTP 429; oversized bodies/files use HTTP 413.
 * Success: { data: ProfilePhotoUploadResponse }.
 * Errors: { error: { message: string, code: string } }.
 * Only the photo is forwarded to Vibecode Storage; no profile fields are sent.
 * The backend does not persist photos or profile data. The app stores the URL locally.
 */
export const PROFILE_PHOTO_MAX_BYTES = 5 * 1024 * 1024;
export const profilePhotoConsentSchema = z.literal("true");
export const profilePhotoUploadResponseSchema = z.object({
  url: z.url().refine((value) => {
    const url = new URL(value);
    return url.protocol === "https:" &&
      (url.hostname === "staticfiles.net" || url.hostname.endsWith(".staticfiles.net"));
  }, "Expected a secure Vibecode CDN URL"),
});
export type ProfilePhotoUploadResponse = z.infer<typeof profilePhotoUploadResponseSchema>;
