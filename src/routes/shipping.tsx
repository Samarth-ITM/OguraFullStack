import { createFileRoute } from "@tanstack/react-router";
import { StaticPage } from "@/components/layout/StaticPage";

export const Route = createFileRoute("/shipping")({
  head: () => ({
    meta: [
      { title: "Shipping & delivery — OGURA" },
      { name: "description", content: "How OGURA parcels reach you, and what to expect once your order is confirmed." },
      { property: "og:title", content: "Shipping & delivery — OGURA" },
      { property: "og:description", content: "How OGURA parcels reach you, and what to expect once your order is confirmed." },
    ],
  }),
  component: Page,
});

const SECTIONS = [
  {
    "heading": "Standard",
    "body": "Delivered in 4 to 7 working days across India. Free above ₹2,999."
  },
  {
    "heading": "Express",
    "body": "Delivered in 2 to 4 working days in serviceable metros."
  },
  {
    "heading": "Made to order",
    "body": "Crafted after you order, typically dispatched in 10 to 21 days."
  },
  {
    "heading": "International",
    "body": "Not available in this prototype build."
  }
];

function Page() {
  return (
    <StaticPage
      eyebrow="Shipping"
      title="Shipping & delivery"
      intro="How OGURA parcels reach you, and what to expect once your order is confirmed."
      sections={SECTIONS}
    />
  );
}
