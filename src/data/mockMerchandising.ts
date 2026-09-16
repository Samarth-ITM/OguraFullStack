export interface PlpTemplate {
  banner: string;
  bannerLabel: string;
  chips: string[];
  insert12: { eyebrow: string; title: string; body: string; cta: string; to: string } | null;
  insert36: { eyebrow: string; title: string; body: string; cta: string; to: string } | null;
}

const insert = (eyebrow: string, title: string, body: string, cta: string, to: string) => ({
  eyebrow,
  title,
  body,
  cta,
  to,
});

export const PLP_TEMPLATES: Record<string, PlpTemplate> = {
  shop: {
    banner: "The OGURA Selection",
    bannerLabel: "plp.shop.hero",
    chips: [],
    insert12: insert("Launchpad", "Emerging designers to watch", "New labels joining OGURA with small, considered first runs.", "Discover new labels", "/launchpad"),
    insert36: insert("Service", "Made to Order", "Start from a reference or a product and shape it with the studio.", "How it works", "/made-to-order"),
  },
  clothing: {
    banner: "Modern Forms",
    bannerLabel: "plp.clothing.hero",
    chips: ["dresses", "tops-and-upperwear", "co-ord-sets", "bottomwear"],
    insert12: insert("Editorial", "Distinctive by Design", "Silhouettes built around construction rather than trend.", "Explore the edit", "/collections/corset-tops"),
    insert36: insert("Studio", "Made by one studio", "One label, one point of view, one complete wardrobe.", "Meet the studio", "/brands"),
  },
  ethnicwear: {
    banner: "A New Language of Festive",
    bannerLabel: "plp.ethnicwear.hero",
    chips: ["sarees", "lehengas", "sets", "dresses-and-gowns"],
    insert12: insert("Craft", "Detail, up close", "Surface work, drape and finishing from independent ateliers.", "See festive edit", "/occasion/festive"),
    insert36: insert("Service", "Made to Order", "Occasion pieces adapted to your measurements and date.", "Start a request", "/made-to-order/request"),
  },
  footwear: {
    banner: "The Finishing Step",
    bannerLabel: "plp.footwear.hero",
    chips: ["heels", "sneakers", "mules", "ankle-boots", "sandals"],
    insert12: insert("Service", "Customised footwear", "Heel height, colour and fit adjusted to you.", "Start your request", "/made-to-order/request?intent=footwear"),
    insert36: null,
  },
  accessories: {
    banner: "The Finishing Touch",
    bannerLabel: "plp.accessories.hero",
    chips: ["bags"],
    insert12: insert("Label", "One accessory label, up close", "Small-run bags made in limited quantities.", "View the label", "/brands"),
    insert36: null,
  },
  dresses: {
    banner: "Dresses for Every Direction",
    bannerLabel: "plp.dresses.hero",
    chips: [],
    insert12: insert("Styling", "Occasion dressing", "How to choose a dress for the evening you actually have.", "Shop occasions", "/occasions"),
    insert36: insert("Guide", "Silhouettes", "Understanding shape before you choose a size.", "Explore shapes", "/women/clothing/dresses"),
  },
  "tops-and-upperwear": {
    banner: "The New Upperwear",
    bannerLabel: "plp.tops.hero",
    chips: [],
    insert12: insert("Design", "Statement construction", "Corsetry, panelling and structure in everyday tops.", "See corset tops", "/collections/corset-tops"),
    insert36: insert("Styling", "Complete the look", "Pair upperwear with bottoms from the same studios.", "Shop bottomwear", "/women/clothing/bottomwear"),
  },
  "co-ord-sets": {
    banner: "Together by Design",
    bannerLabel: "plp.coord.hero",
    chips: [],
    insert12: insert("Styling", "Two ways to wear", "Sets designed to separate as easily as they pair.", "Shop co-ords", "/collections/co-ord-sets"),
    insert36: null,
  },
  bottomwear: {
    banner: "The Foundation Edit",
    bannerLabel: "plp.bottomwear.hero",
    chips: [],
    insert12: insert("Guide", "Proportion and fit", "Rise, length and drape explained simply.", "Read the guide", "/help"),
    insert36: null,
  },
  lehengas: {
    banner: "Celebration, Reframed",
    bannerLabel: "plp.lehengas.hero",
    chips: [],
    insert12: insert("Craft", "Detail and construction", "Surface work seen close, without embellishment claims.", "Festive edit", "/occasion/festive"),
    insert36: null,
  },
  sarees: {
    banner: "The Saree Edit",
    bannerLabel: "plp.sarees.hero",
    chips: [],
    insert12: insert("Styling", "Drape notes", "Fabric behaviour and drape, described plainly.", "Wedding guest", "/occasion/wedding-guest"),
    insert36: null,
  },
  bags: {
    banner: "Carry the Story",
    bannerLabel: "plp.bags.hero",
    chips: [],
    insert12: insert("Material", "Material and details", "Hardware, lining and finishing on small-run bags.", "Shop accessories", "/women/accessories"),
    insert36: null,
  },
};

export const DEFAULT_TEMPLATE: PlpTemplate = {
  banner: "The OGURA Selection",
  bannerLabel: "plp.default.hero",
  chips: [],
  insert12: insert("Launchpad", "Emerging designers to watch", "New labels joining OGURA with small first runs.", "Discover new labels", "/launchpad"),
  insert36: null,
};
