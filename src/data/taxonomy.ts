import type { Category, Collection } from "@/domain/catalog";

export const PRICE_BANDS = [
  { value: "discovery-price", label: "₹1,111 – ₹1,499", short: "Discovery Price", min: 1111, max: 1499 },
  { value: "accessible-designer", label: "₹1,500 – ₹1,999", short: "Accessible Designer", min: 1500, max: 1999 },
  { value: "contemporary-core", label: "₹2,000 – ₹2,499", short: "Contemporary Core", min: 2000, max: 2499 },
  { value: "statement-core", label: "₹2,500 – ₹2,999", short: "Statement Core", min: 2500, max: 2999 },
  { value: "elevated-edit", label: "₹3,000 – ₹4,999", short: "Elevated Edit", min: 3000, max: 4999 },
  { value: "premium-designer", label: "₹5,000 – ₹7,499", short: "Premium Designer", min: 5000, max: 7499 },
  { value: "signature-designer", label: "₹7,500 – ₹9,999", short: "Signature Designer", min: 7500, max: 9999 },
  { value: "prestige-occasion", label: "₹10,000 – ₹15,000", short: "Prestige / Occasion", min: 10000, max: 15000 },
] as const;

export const PRICE_MIN = 1111;
export const PRICE_MAX = 15000;

export const CATEGORIES: Category[] = [
  {
    slug: "clothing",
    name: "Clothing",
    children: [
      { slug: "dresses", name: "Dresses" },
      { slug: "tops-and-upperwear", name: "Tops & Upperwear" },
      { slug: "co-ord-sets", name: "Co-ord Sets" },
      { slug: "bottomwear", name: "Bottomwear" },
      { slug: "jumpsuits-and-playsuits", name: "Jumpsuits & Playsuits" },
    ],
  },
  {
    slug: "ethnicwear",
    name: "Ethnicwear",
    children: [
      { slug: "sarees", name: "Sarees" },
      { slug: "lehengas", name: "Lehengas" },
      { slug: "sets", name: "Sets" },
      { slug: "dresses-and-gowns", name: "Dresses & Gowns" },
    ],
  },
  {
    slug: "footwear",
    name: "Footwear",
    children: [
      { slug: "heels", name: "Heels" },
      { slug: "sneakers", name: "Sneakers" },
      { slug: "mules", name: "Mules" },
      { slug: "ankle-boots", name: "Ankle Boots" },
      { slug: "knee-high-boots", name: "Knee-High Boots" },
      { slug: "sandals", name: "Sandals" },
    ],
  },
  {
    slug: "accessories",
    name: "Accessories",
    children: [{ slug: "bags", name: "Bags" }],
  },
];

export const CATEGORY_BY_SLUG = new Map(CATEGORIES.map((c) => [c.slug, c]));

export const SUBCATEGORY_NAME_BY_SLUG = new Map<string, string>(
  CATEGORIES.flatMap((c) => c.children.map((ch) => [ch.slug, ch.name] as [string, string])),
);

export const CATEGORY_NAME_BY_SLUG = new Map(CATEGORIES.map((c) => [c.slug, c.name]));

export const SLUG_BY_CATEGORY_NAME = new Map(CATEGORIES.map((c) => [c.name, c.slug]));
export const SLUG_BY_SUBCATEGORY_NAME = new Map(
  CATEGORIES.flatMap((c) => c.children.map((ch) => [ch.name, ch.slug] as [string, string])),
);

export const OCCASIONS = [
  { slug: "wedding-guest", name: "Wedding Guest" },
  { slug: "festive", name: "Festive" },
  { slug: "party", name: "Party" },
  { slug: "brunch", name: "Brunch" },
  { slug: "date-night", name: "Date Night" },
  { slug: "vacation", name: "Vacation" },
  { slug: "work", name: "Work" },
  { slug: "casual", name: "Casual" },
];

export const PRICE_COLLECTIONS: Collection[] = [
  {
    slug: "under-2000",
    title: "Under ₹2,000",
    description: "Designer pieces that stay under two thousand rupees.",
    kind: "price",
    minPrice: 1111,
    maxPrice: 1999,
  },
  {
    slug: "under-3000",
    title: "Under ₹3,000",
    description: "The core OGURA assortment — the widest edit on the platform.",
    kind: "price",
    minPrice: 1111,
    maxPrice: 2999,
  },
  {
    slug: "3000-to-4999",
    title: "₹3,000 – ₹4,999",
    description: "Elevated everyday design with more considered construction.",
    kind: "price",
    minPrice: 3000,
    maxPrice: 4999,
  },
  {
    slug: "5000-to-9999",
    title: "₹5,000 – ₹9,999",
    description: "Premium and signature designer pieces.",
    kind: "price",
    minPrice: 5000,
    maxPrice: 9999,
  },
  {
    slug: "10000-to-15000",
    title: "₹10,000 – ₹15,000",
    description: "Occasion and prestige pieces from independent labels.",
    kind: "price",
    minPrice: 10000,
    maxPrice: 15000,
  },
];

export const STYLE_COLLECTIONS: Collection[] = [
  {
    slug: "corset-tops",
    title: "Corset Tops",
    description: "Structured upperwear built around the waist.",
    kind: "style",
    productTypes: ["Corset Tops", "Corsets", "Bustiers"],
  },
  {
    slug: "co-ord-sets",
    title: "Co-ord Sets",
    description: "Two pieces designed to be worn as one.",
    kind: "style",
    subcategories: ["Co-ord Sets"],
  },
  {
    slug: "wrap-tops",
    title: "Wrap Tops",
    description: "Soft construction, adjustable fit.",
    kind: "style",
    productTypes: ["Wrap Tops"],
  },
  {
    slug: "cut-out-dresses",
    title: "Cut-Out Dresses",
    description: "Negative space used as a design device.",
    kind: "style",
    productTypes: ["Cut-Out Dresses", "Cutout Dresses"],
  },
  {
    slug: "sheer-sets",
    title: "Sheer Sets",
    description: "Layered transparency, considered coverage.",
    kind: "style",
    productTypes: ["Sheer Sets", "Sheer Tops"],
  },
  {
    slug: "resortwear",
    title: "Resortwear",
    description: "Warm-weather dressing from independent labels.",
    kind: "style",
    productTypes: ["Resort Dresses", "Kaftans", "Coverups"],
  },
  {
    slug: "indo-western-sets",
    title: "Indo-Western Sets",
    description: "Ethnic detail in a contemporary cut.",
    kind: "style",
    productTypes: ["Indo-Western Sets", "Indo Western Sets"],
  },
];

export const ALL_COLLECTIONS = [...PRICE_COLLECTIONS, ...STYLE_COLLECTIONS];
export const COLLECTION_BY_SLUG = new Map(ALL_COLLECTIONS.map((c) => [c.slug, c]));
