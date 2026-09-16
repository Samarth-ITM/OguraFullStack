// TEMPORARY_DRIVE_MEDIA — migrate approved originals to owned storage before production.
import {
  productMediaManifest,
  type ProductImageRecord,
  type ProductMediaRecord,
} from "@/data/generated/productMedia";

const bySlug = new Map<string, ProductMediaRecord>();
const byUuid = new Map<string, ProductMediaRecord>();
for (const record of Object.values(productMediaManifest.records)) {
  bySlug.set(record.productSlug, record);
  byUuid.set(record.productId, record);
}

/** Internal-only list; never surfaced to customers. */
export const lowFileSizeWarnings: string[] = Object.values(productMediaManifest.records)
  .flatMap((r) => r.images)
  .filter((i) => i.qualityGate === "REVIEW_LOW_FILE_SIZE")
  .map((i) => i.imageId);

const failedUrls = new Set<string>();

export function markImageFailed(image: { imageId: string; sourceProductId: string; url: string }): void {
  if (failedUrls.has(image.url)) return;
  failedUrls.add(image.url);
  console.warn(`[TEMPORARY_DRIVE_MEDIA] image unavailable: ${image.sourceProductId} / ${image.imageId}`);
}

export function hasImageFailed(url: string): boolean {
  return failedUrls.has(url);
}

export function getProductMedia(sourceProductId: string): ProductMediaRecord | null {
  return (
    productMediaManifest.records[sourceProductId] ??
    byUuid.get(sourceProductId) ??
    bySlug.get(sourceProductId) ??
    null
  );
}

export function getProductGallery(sourceProductId: string): ProductImageRecord[] {
  return getProductMedia(sourceProductId)?.images ?? [];
}

export function getPrimaryImage(sourceProductId: string): ProductImageRecord | null {
  const images = getProductGallery(sourceProductId);
  return images.find((i) => i.isPrimary) ?? images[0] ?? null;
}

export function getSecondaryImage(sourceProductId: string): ProductImageRecord | null {
  const images = getProductGallery(sourceProductId);
  const primary = getPrimaryImage(sourceProductId);
  return images.find((i) => i.imageId !== primary?.imageId) ?? null;
}

export const productMediaRepository = {
  getProductMedia,
  getPrimaryImage,
  getProductGallery,
};

/**
 * TEMPORARY_DRIVE_MEDIA — migrate approved originals to owned storage before production.
 * The mapped `uc?export=view` links redirect to an HTML download page and cannot be rendered
 * by an <img> tag. This derives a renderable URL from the exact same Drive file id — no new
 * files, hosts or third-party image sources are introduced.
 */
export function renderableUrl(image: { url: string }): string {
  const id = /[?&]id=([^&]+)/.exec(image.url)?.[1];
  if (!id) return image.url;
  return `https://drive.google.com/thumbnail?id=${id}&sz=w1200`;
}
