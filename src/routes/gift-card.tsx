import { createFileRoute } from "@tanstack/react-router";
import { StaticPage } from "@/components/layout/StaticPage";

export const Route = createFileRoute("/gift-card")({
  head: () => ({
    meta: [
      { title: "Gift cards — OGURA" },
      { name: "description", content: "A considered way to let someone choose their own OGURA piece." },
      { property: "og:title", content: "Gift cards — OGURA" },
      { property: "og:description", content: "A considered way to let someone choose their own OGURA piece." },
    ],
  }),
  component: Page,
});

const SECTIONS = [
  {
    "heading": "Denominations",
    "body": "₹2,500, ₹5,000, ₹10,000 and ₹15,000 (illustrative)."
  },
  {
    "heading": "Delivery",
    "body": "Sent by email with a personal message."
  },
  {
    "heading": "Validity",
    "body": "Twelve months from purchase."
  },
  {
    "heading": "Prototype note",
    "body": "Gift cards cannot be purchased in this demo build."
  }
];

function Page() {
  return (
    <StaticPage
      eyebrow="Gifting"
      title="Gift cards"
      intro="A considered way to let someone choose their own OGURA piece."
      sections={SECTIONS}
    />
  );
}
