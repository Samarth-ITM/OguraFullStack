export interface ExploreTile {
  slotId: string;
  title: string;
  line: string;
  to: string;
}

export const EXPLORE_TILES: ExploreTile[] = [
  { slotId: "home.explore.made-to-order", title: "Made to Order", line: "Pieces created for you.", to: "/made-to-order" },
  { slotId: "home.explore.pinterest-finds", title: "Pinterest Finds", line: "Saved looks, shoppable here.", to: "/collections/under-3000" },
  { slotId: "home.explore.celebrity-fashion", title: "Celebrity Fashion", line: "Red-carpet shapes, indie labels.", to: "/occasion/party" },
  { slotId: "home.explore.festive-edit", title: "Festive Edit", line: "Celebration dressing, reframed.", to: "/occasion/festive" },
  { slotId: "home.explore.designer-curations", title: "Designer Curations", line: "Edits built by the designers.", to: "/designers" },
  { slotId: "home.explore.instagram-boutiques", title: "Instagram Boutiques", line: "Small labels worth following.", to: "/brands" },
];

export const PROMISE_ITEMS = [
  { title: "Curated independent labels", body: "Every label on OGURA is reviewed before it appears in the edit." },
  { title: "Secure checkout planned", body: "Payments are not connected in this prototype. Nothing is charged." },
  { title: "Customer support", body: "A support team will handle sizing, orders and returns at launch." },
  { title: "Made-to-order clarity", body: "Lead times and customisation limits are stated before you request." },
];

export const FOOTWEAR_SERVICES = [
  { slotId: "home.footwear.service.heel", title: "Custom Heel Height", line: "Choose a heel that works for the evening you have planned.", intent: "heel-height" },
  { slotId: "home.footwear.service.colour", title: "Colour Matching", line: "Match a pair to an outfit you already own.", intent: "colour-match" },
  { slotId: "home.footwear.service.fit", title: "Width & Fit Adjustment", line: "Small adjustments for a more comfortable fit.", intent: "fit" },
];
