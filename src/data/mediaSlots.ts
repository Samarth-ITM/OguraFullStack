import type { MediaSlot } from "@/domain/catalog";

export const RATIOS = {
  hero: { ratio: "16 / 9", desktop: "1920×1080", mobile: "1080×1350" },
  heroMobile: { ratio: "4 / 5", desktop: "1080×1350", mobile: "1080×1350" },
  banner: { ratio: "2.4 / 1", desktop: "1920×800", mobile: "1080×1350" },
  bannerShallow: { ratio: "3 / 1", desktop: "1920×640", mobile: "1280×720" },
  editorial: { ratio: "4 / 5", desktop: "1200×1500", mobile: "1200×1500" },
  product: { ratio: "3 / 4", desktop: "1200×1600", mobile: "1200×1600" },
  portrait: { ratio: "4 / 5", desktop: "1200×1500", mobile: "1200×1500" },
  tile: { ratio: "4 / 5", desktop: "1200×1500", mobile: "1200×1500" },
  review: { ratio: "1 / 1", desktop: "1000×1000", mobile: "1000×1000" },
} as const;

export type RatioKey = keyof typeof RATIOS;

export function makeSlot(
  slotId: string,
  role: MediaSlot["role"],
  ratioKey: RatioKey,
  alt: string,
  entityId?: string,
): MediaSlot {
  const r = RATIOS[ratioKey];
  const slot: MediaSlot = { slotId, role, ratio: r.ratio, desktop: r.desktop, mobile: r.mobile, alt };
  if (entityId) slot.entityId = entityId;
  return slot;
}

const APPAREL_ANGLES = ["front", "alternate", "back", "side", "detail", "styled"];
const BAG_ANGLES = ["primary", "alternate", "back", "interior", "detail"];
const FOOTWEAR_ANGLES = ["primary", "side", "top", "back", "sole"];

export function galleryAngles(category: string, subcategory: string): string[] {
  if (category === "Footwear") return FOOTWEAR_ANGLES;
  if (subcategory === "Bags") return BAG_ANGLES;
  return APPAREL_ANGLES;
}

export function productSlots(productId: string, category: string, subcategory: string, title: string): MediaSlot[] {
  return galleryAngles(category, subcategory).map((angle) =>
    makeSlot(`product.${productId}.${angle}`, "product", "product", `${title} — ${angle} view`, productId),
  );
}
